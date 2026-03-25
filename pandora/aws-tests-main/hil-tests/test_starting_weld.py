"""HIL test cases for starting weld -- weld data handling and arc state.

Covers adding weld process parameters, creating and selecting weld data sets,
and verifying arc state transitions through the manual weld state machine:

    IDLE → CONFIGURED (after SelectWeldDataSet)
         → READY      (when power sources report READY_TO_START)
         → STARTING   (after start button)
         → ACTIVE     (when at least one power source is ARCING)

    Stop sequence:
    ACTIVE → READY    (after stop button + power sources stop arcing)

The PLC-dependent transitions (CONFIGURED→READY, READY→STARTING, etc.)
work in two modes:

    **PLC mode** – helpers write PLC addresses directly to drive state
    transitions.  Fast and deterministic.

    **Simulation mode** – when PLC is unavailable, Adaptio's built-in
    simulation controller auto-progresses power source states and fires
    the start button after ``AUTO_START_DELAY`` (30 s).  The tests simply
    wait for each ``ArcState`` push with a longer timeout.

Reference:
    - sysfun-welddata-handling.md (use-case specification)
    - adaptio-gen_2_ms3/src/main/weld_control/src/manual_weld.cc
    - adaptio-gen_2_ms3/src/block_tests/manual_weld_test.cc
    - adaptio-gen_2_ms3/src/controller/simulation/simulation.cc
"""

import time

import pytest
from loguru import logger

from conftest import (
    delete_adaptio_database,
    add_weld_data_set,
    add_weld_process_parameters,
    get_weld_data_sets,
    get_weld_process_parameters,
    get_weld_process_parameters_config,
    receive_arc_state,
    reset_plc_weld_signals,
    select_weld_data_set,
    simulate_arcing,
    simulate_arcing_stopped,
    simulate_power_sources_ready,
    simulate_weld_start,
    simulate_weld_stop,
    subscribe_arc_state,
)
from managers import AdaptioManager
from testzilla.adaptio_web_hmi.adaptio_web_hmi import AdaptioWebHmi
from testzilla.plc.plc_json_rpc import PlcJsonRpc

# Simulation AUTO_START_DELAY is 30 s; use generous retry count so that
# receive_arc_state can wait long enough for the simulation to progress.
_SIM_MAX_RETRIES = 60


def _find_wpp_ids(web_hmi: AdaptioWebHmi, ws1_name: str, ws2_name: str) -> dict | None:
    wpp_list = get_weld_process_parameters(web_hmi)
    if not wpp_list:
        return None

    ws1_wpp_id = None
    ws2_wpp_id = None
    for wpp in wpp_list:
        if isinstance(wpp, dict):
            wpp_id = wpp.get("id") or wpp.get("wppId") or wpp.get("Id")
            wpp_name = wpp.get("name") or wpp.get("Name")

            if wpp_name == ws1_name:
                ws1_wpp_id = wpp_id
            elif wpp_name == ws2_name:
                ws2_wpp_id = wpp_id

    if ws1_wpp_id is not None and ws2_wpp_id is not None:
        return {"ws1_wpp_id": ws1_wpp_id, "ws2_wpp_id": ws2_wpp_id}
    return None

def _find_wds_id(web_hmi: AdaptioWebHmi, wds_name: str) -> int | None:
    wds_list = get_weld_data_sets(web_hmi)
    if not wds_list:
        return None

    for wds in wds_list:
        if isinstance(wds, dict):
            wds_id = wds.get("id") or wds.get("wdsId") or wds.get("Id")
            wds_name_val = wds.get("name") or wds.get("Name")

            if wds_name_val == wds_name:
                return wds_id
    return None


@pytest.fixture(name="weld_process_parameters_setup")
def weld_process_parameters_setup_fixture(web_hmi: AdaptioWebHmi, adaptio_manager: AdaptioManager, request: pytest.FixtureRequest):
    db_path = request.config.ADAPTIO_USER_CONFIG_PATH / request.config.ADAPTIO_DB
    success = delete_adaptio_database(adaptio_manager, db_path)
    if not success:
        pytest.skip("Skipping test: failed to clean database before setup")

    ws1_config = get_weld_process_parameters_config("ws1")
    ws2_config = get_weld_process_parameters_config("ws2")

    if not add_weld_process_parameters(web_hmi, **ws1_config):
        pytest.skip("Skipping test: failed to add weld process parameters for WS1")
    if not add_weld_process_parameters(web_hmi, **ws2_config):
        pytest.skip("Skipping test: failed to add weld process parameters for WS2")

    wpp_ids = _find_wpp_ids(web_hmi, ws1_config["name"], ws2_config["name"])
    if wpp_ids is None:
        pytest.skip("Skipping test: could not retrieve WPP IDs after adding")

    logger.info(f"WPP IDs: ws1={wpp_ids['ws1_wpp_id']}, ws2={wpp_ids['ws2_wpp_id']}")
    return wpp_ids


@pytest.fixture(name="weld_data_set_setup")
def weld_data_set_setup_fixture(web_hmi: AdaptioWebHmi, weld_process_parameters_setup):
    wpp_ids = weld_process_parameters_setup
    if not add_weld_data_set(
        web_hmi,
        name="ManualWeld",
        ws1_wpp_id=wpp_ids["ws1_wpp_id"],
        ws2_wpp_id=wpp_ids["ws2_wpp_id"],
    ):
        pytest.skip("Skipping test: failed to add weld data set")

    wds_id = _find_wds_id(web_hmi, "ManualWeld")
    if wds_id is None:
        pytest.skip("Skipping test: could not retrieve WDS ID after adding")

    logger.info(f"WDS ID: {wds_id}")
    return {"wds_id": wds_id, **wpp_ids}


class TestStartingWeld:
    """Test suite for starting weld via the adaptio module.

    Covers the manual weld use case: adding weld process parameters,
    creating and selecting weld data sets, and verifying arc state transitions
    through the full state machine.

    Tests that involve PLC-driven transitions accept a ``plc_or_none``
    fixture.  When PLC is available the helpers drive state via PLC
    addresses; when not, the tests fall back to simulation mode which
    auto-progresses power source states and fires the start button after
    a 30 s delay.
    """

    @pytest.mark.gen2
    def test_add_weld_process_parameters(self, web_hmi: AdaptioWebHmi, adaptio_manager: AdaptioManager, request: pytest.FixtureRequest):
        db_path = request.config.ADAPTIO_USER_CONFIG_PATH / request.config.ADAPTIO_DB
        success = delete_adaptio_database(adaptio_manager, db_path)
        assert success, "Database deletion and restart should succeed"

        ws1_config = get_weld_process_parameters_config("ws1")
        ws2_config = get_weld_process_parameters_config("ws2")

        result_ws1 = add_weld_process_parameters(web_hmi, **ws1_config)
        assert result_ws1, "Adding weld process parameters for WS1 should succeed"

        result_ws2 = add_weld_process_parameters(web_hmi, **ws2_config)
        assert result_ws2, "Adding weld process parameters for WS2 should succeed"

    @pytest.mark.gen2
    def test_add_weld_data_set(self, web_hmi: AdaptioWebHmi, weld_process_parameters_setup):
        wpp_ids = weld_process_parameters_setup
        result = add_weld_data_set(
            web_hmi,
            name="ManualWeld",
            ws1_wpp_id=wpp_ids["ws1_wpp_id"],
            ws2_wpp_id=wpp_ids["ws2_wpp_id"],
        )
        assert result, "Adding weld data set should succeed"

    @pytest.mark.gen2
    def test_get_weld_data_sets(self, web_hmi: AdaptioWebHmi, weld_data_set_setup):
        weld_data_sets = get_weld_data_sets(web_hmi)
        assert weld_data_sets is not None, "GetWeldDataSets should return a response"
        logger.info(f"Retrieved weld data sets: {weld_data_sets}")

    @pytest.mark.gen2
    def test_arc_state_idle_on_subscribe(self, web_hmi: AdaptioWebHmi):
        state = subscribe_arc_state(web_hmi)
        if state is None:
            pytest.skip("Skipping test: device does not support SubscribeArcState")
        logger.info(f"Initial arc state: {state}")
        assert state == "idle", f"Initial arc state should be 'idle', got '{state}'"

    @pytest.mark.gen2
    def test_select_weld_data_set(self, web_hmi: AdaptioWebHmi, weld_data_set_setup):
        wds_id = weld_data_set_setup["wds_id"]
        result = select_weld_data_set(web_hmi, weld_data_set_id=wds_id)
        assert result, "Selecting weld data set should succeed"

    @pytest.mark.gen2
    def test_arc_state_transitions_to_configured(self, web_hmi: AdaptioWebHmi, weld_data_set_setup):
        # Subscribe to arc state updates
        initial_state = subscribe_arc_state(web_hmi)
        if initial_state is None:
            pytest.skip("Skipping test: device does not support SubscribeArcState")
        logger.info(f"Initial arc state: {initial_state}")

        # Select the weld data set - this should trigger a state transition
        wds_id = weld_data_set_setup["wds_id"]
        result = select_weld_data_set(web_hmi, weld_data_set_id=wds_id)
        assert result, "Selecting weld data set should succeed"

        # If initial state was already 'configured' (from a previous selection),
        # no transition message will be sent. Otherwise, expect 'configured'.
        if initial_state != "configured":
            state = receive_arc_state(web_hmi)
            assert state is not None, "Should receive arc state update after selection"
            logger.info(f"Arc state after selection: {state}")
            assert state == "configured", f"Arc state should transition to 'configured', got '{state}'"

    @pytest.mark.gen2
    def test_arc_state_ready_after_power_sources_ready(
        self, web_hmi: AdaptioWebHmi, plc_or_none, weld_data_set_setup
    ):
        """CONFIGURED → READY when both power sources report READY_TO_START.

        With PLC: sets ReadyToStart flags explicitly.
        Without PLC (simulation): the simulation controller automatically
        sets power sources to READY_TO_START when weld system settings are
        written (after SelectWeldDataSet).  The test waits with a longer
        timeout for the transition.
        """
        plc = plc_or_none
        if plc is not None:
            try:
                reset_plc_weld_signals(plc)
            except Exception as exc:
                logger.debug(f"reset_plc_weld_signals failed (non-fatal): {exc}")

        # Subscribe and select WDS to reach CONFIGURED
        initial_state = subscribe_arc_state(web_hmi)
        if initial_state is None:
            pytest.skip("Skipping test: device does not support SubscribeArcState")

        wds_id = weld_data_set_setup["wds_id"]
        result = select_weld_data_set(web_hmi, weld_data_set_id=wds_id)
        assert result, "Selecting weld data set should succeed"

        # Consume CONFIGURED push if needed
        if initial_state != "configured":
            state = receive_arc_state(web_hmi)
            assert state == "configured", f"Expected 'configured', got '{state}'"

        if plc is not None:
            # PLC mode: explicitly set power sources ready
            assert simulate_power_sources_ready(plc), "Setting power sources ready should succeed"
            time.sleep(0.5)  # allow PLC→Adaptio propagation
            retries = 10
        else:
            # Simulation mode: power sources auto-ready on WritePowerSourceOutput
            logger.info("No PLC – waiting for simulation to set power sources ready")
            retries = _SIM_MAX_RETRIES

        state = receive_arc_state(web_hmi, max_retries=retries)
        assert state is not None, "Should receive arc state update after power sources ready"
        logger.info(f"Arc state after power sources ready: {state}")
        assert state == "ready", f"Arc state should transition to 'ready', got '{state}'"

    @pytest.mark.gen2
    def test_arc_state_starting_after_start_button(
        self, web_hmi: AdaptioWebHmi, plc_or_none, weld_data_set_setup
    ):
        """READY → STARTING when the start button is pressed.

        With PLC: sends Start signal via PLC address.
        Without PLC (simulation): the simulation auto-fires start after
        AUTO_START_DELAY (30 s).  The test waits with a longer timeout.
        """
        plc = plc_or_none
        if plc is not None:
            try:
                reset_plc_weld_signals(plc)
            except Exception as exc:
                logger.debug(f"reset_plc_weld_signals failed (non-fatal): {exc}")

        # Subscribe and drive to READY
        initial_state = subscribe_arc_state(web_hmi)
        if initial_state is None:
            pytest.skip("Skipping test: device does not support SubscribeArcState")

        wds_id = weld_data_set_setup["wds_id"]
        result = select_weld_data_set(web_hmi, weld_data_set_id=wds_id)
        assert result, "Selecting weld data set should succeed"

        if initial_state != "configured":
            receive_arc_state(web_hmi)  # consume CONFIGURED

        if plc is not None:
            assert simulate_power_sources_ready(plc), "Power sources ready should succeed"
            time.sleep(0.5)
        state = receive_arc_state(web_hmi, max_retries=_SIM_MAX_RETRIES)
        assert state == "ready", f"Expected 'ready', got '{state}'"

        if plc is not None:
            # PLC mode: press start via PLC → STARTING
            assert simulate_weld_start(plc), "Weld start should succeed"
            time.sleep(0.5)  # allow PLC→Adaptio propagation
            retries = 10
        else:
            # Simulation mode: auto-start fires after ~30 s delay
            logger.info("No PLC – waiting for simulation auto-start (up to ~35 s)")
            retries = _SIM_MAX_RETRIES

        state = receive_arc_state(web_hmi, max_retries=retries)
        assert state is not None, "Should receive arc state update after start"
        logger.info(f"Arc state after start: {state}")
        assert state == "starting", f"Arc state should transition to 'starting', got '{state}'"

    @pytest.mark.gen2
    def test_arc_state_active_after_arcing(
        self, web_hmi: AdaptioWebHmi, plc_or_none, weld_data_set_setup
    ):
        """STARTING → ACTIVE when a power source reports ARCING.

        With PLC: sets PS1 Arcing flag explicitly.
        Without PLC (simulation): the simulation controller automatically
        transitions power sources to ARCING when the start command is
        received.
        """
        plc = plc_or_none
        if plc is not None:
            try:
                reset_plc_weld_signals(plc)
            except Exception as exc:
                logger.debug(f"reset_plc_weld_signals failed (non-fatal): {exc}")

        # Subscribe and drive to STARTING
        initial_state = subscribe_arc_state(web_hmi)
        if initial_state is None:
            pytest.skip("Skipping test: device does not support SubscribeArcState")

        wds_id = weld_data_set_setup["wds_id"]
        result = select_weld_data_set(web_hmi, weld_data_set_id=wds_id)
        assert result, "Selecting weld data set should succeed"

        if initial_state != "configured":
            receive_arc_state(web_hmi)  # consume CONFIGURED

        if plc is not None:
            assert simulate_power_sources_ready(plc), "Power sources ready should succeed"
            time.sleep(0.5)
        receive_arc_state(web_hmi, max_retries=_SIM_MAX_RETRIES)  # consume READY

        if plc is not None:
            assert simulate_weld_start(plc), "Weld start should succeed"
            time.sleep(0.5)
        receive_arc_state(web_hmi, max_retries=_SIM_MAX_RETRIES)  # consume STARTING

        if plc is not None:
            # PLC mode: power source 1 starts arcing → ACTIVE
            assert simulate_arcing(plc), "Simulate arcing should succeed"
            time.sleep(0.5)  # allow PLC→Adaptio propagation
            retries = 10
        else:
            # Simulation mode: arcing auto-starts after start command
            logger.info("No PLC – waiting for simulation to begin arcing")
            retries = _SIM_MAX_RETRIES

        state = receive_arc_state(web_hmi, max_retries=retries)
        assert state is not None, "Should receive arc state update after arcing"
        logger.info(f"Arc state after arcing: {state}")
        assert state == "active", f"Arc state should transition to 'active', got '{state}'"

    @pytest.mark.gen2
    def test_arc_state_ready_after_stop(
        self, web_hmi: AdaptioWebHmi, plc_or_none, weld_data_set_setup
    ):
        """ACTIVE → READY when stop is pressed and arcing ceases.

        This test requires PLC to explicitly send the stop command and
        clear arcing flags.  When PLC is unavailable the test is skipped
        because the simulation does not auto-stop.
        """
        plc = plc_or_none
        if plc is None:
            pytest.skip("Stop sequence requires PLC – skipping in simulation mode")

        try:
            reset_plc_weld_signals(plc)
        except Exception as exc:
            logger.debug(f"reset_plc_weld_signals failed (non-fatal): {exc}")

        # Subscribe and drive to ACTIVE
        initial_state = subscribe_arc_state(web_hmi)
        if initial_state is None:
            pytest.skip("Skipping test: device does not support SubscribeArcState")

        wds_id = weld_data_set_setup["wds_id"]
        result = select_weld_data_set(web_hmi, weld_data_set_id=wds_id)
        assert result, "Selecting weld data set should succeed"

        if initial_state != "configured":
            receive_arc_state(web_hmi)  # consume CONFIGURED

        assert simulate_power_sources_ready(plc), "Power sources ready should succeed"
        time.sleep(0.5)
        receive_arc_state(web_hmi)  # consume READY

        assert simulate_weld_start(plc), "Weld start should succeed"
        time.sleep(0.5)
        receive_arc_state(web_hmi)  # consume STARTING

        assert simulate_arcing(plc), "Simulate arcing should succeed"
        time.sleep(0.5)
        state = receive_arc_state(web_hmi)
        assert state == "active", f"Expected 'active', got '{state}'"

        # Stop the weld
        assert simulate_weld_stop(plc), "Weld stop should succeed"
        time.sleep(0.5)

        # Clear arcing on power source → READY
        assert simulate_arcing_stopped(plc), "Clearing arcing should succeed"
        time.sleep(0.5)

        state = receive_arc_state(web_hmi)
        assert state is not None, "Should receive arc state update after stop"
        logger.info(f"Arc state after stop: {state}")
        assert state == "ready", f"Arc state should transition to 'ready', got '{state}'"
