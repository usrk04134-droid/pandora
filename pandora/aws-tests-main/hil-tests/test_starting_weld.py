"""HIL test cases for starting weld -- weld data handling and arc state.

Covers adding weld process parameters, creating and selecting weld data sets,
and verifying arc state transitions through the manual weld state machine:

    IDLE → CONFIGURED (after SelectWeldDataSet)
         → READY      (when power sources report READY_TO_START)
         → STARTING   (after start button)
         → ACTIVE     (when at least one power source is ARCING)

    Stop sequence:
    ACTIVE → READY    (after stop button + power sources stop arcing)

PLC communication uses module-level ``PLC_ADDR_*`` constants defined in
``conftest.py``.  Every PLC-dependent test is marked ``@pytest.mark.plc_only``
and uses ``setup_plc`` directly.

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
    apply_arc_voltage,
    enable_bench_psu_output,
    get_weld_data_sets,
    get_weld_process_parameters,
    get_weld_process_parameters_config,
    read_power_source_status,
    receive_arc_state,
    remove_arc_voltage,
    reset_plc_weld_signals,
    select_weld_data_set,
    set_power_source_current,
    set_power_source_voltage,
    simulate_arcing,
    simulate_arcing_stopped,
    simulate_power_sources_ready,
    simulate_weld_start,
    simulate_weld_stop,
    subscribe_arc_state,
    wait_for_plc_value,
)
from managers import AdaptioManager
from testzilla.adaptio_web_hmi.adaptio_web_hmi import AdaptioWebHmi
from testzilla.plc.plc_json_rpc import PlcJsonRpc


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

    PLC-dependent tests follow the joint-tracking pattern: they accept
    ``setup_plc`` and ``addresses`` fixtures and are marked
    ``@pytest.mark.plc_only``.
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
    @pytest.mark.plc_only
    def test_arc_state_ready_after_power_sources_ready(
        self, web_hmi: AdaptioWebHmi, setup_plc: PlcJsonRpc, weld_data_set_setup
    ):
        """CONFIGURED → READY when both power sources report READY_TO_START."""
        plc = setup_plc
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

        # PLC mode: explicitly set power sources ready
        assert simulate_power_sources_ready(plc), "Setting power sources ready should succeed"
        time.sleep(0.5)  # allow PLC→Adaptio propagation

        state = receive_arc_state(web_hmi, max_retries=10)
        assert state is not None, "Should receive arc state update after power sources ready"
        logger.info(f"Arc state after power sources ready: {state}")
        assert state == "ready", f"Arc state should transition to 'ready', got '{state}'"

    @pytest.mark.gen2
    @pytest.mark.plc_only
    def test_arc_state_starting_after_start_button(
        self, web_hmi: AdaptioWebHmi, setup_plc: PlcJsonRpc, weld_data_set_setup
    ):
        """READY → STARTING when the start button is pressed."""
        plc = setup_plc
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

        assert simulate_power_sources_ready(plc), "Power sources ready should succeed"
        time.sleep(0.5)
        state = receive_arc_state(web_hmi)
        assert state == "ready", f"Expected 'ready', got '{state}'"

        # PLC mode: press start via PLC → STARTING
        assert simulate_weld_start(plc), "Weld start should succeed"
        time.sleep(0.5)  # allow PLC→Adaptio propagation

        state = receive_arc_state(web_hmi, max_retries=10)
        assert state is not None, "Should receive arc state update after start"
        logger.info(f"Arc state after start: {state}")
        assert state == "starting", f"Arc state should transition to 'starting', got '{state}'"

    @pytest.mark.gen2
    @pytest.mark.plc_only
    def test_arc_state_active_after_arcing(
        self, web_hmi: AdaptioWebHmi, setup_plc: PlcJsonRpc, bench_power_supply, weld_data_set_setup
    ):
        """STARTING → ACTIVE when a power source reports ARCING."""
        plc = setup_plc
        psu = bench_power_supply
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

        assert simulate_power_sources_ready(plc), "Power sources ready should succeed"
        time.sleep(0.5)
        receive_arc_state(web_hmi)  # consume READY

        assert simulate_weld_start(plc), "Weld start should succeed"
        time.sleep(0.5)
        receive_arc_state(web_hmi)  # consume STARTING

        # Bench PSU: apply arc voltage → ACTIVE
        assert simulate_arcing(psu), "Simulate arcing should succeed"
        time.sleep(0.5)  # allow hardware chain propagation

        state = receive_arc_state(web_hmi, max_retries=10)
        assert state is not None, "Should receive arc state update after arcing"
        logger.info(f"Arc state after arcing: {state}")
        assert state == "active", f"Arc state should transition to 'active', got '{state}'"

    @pytest.mark.gen2
    @pytest.mark.plc_only
    def test_arc_state_ready_after_stop(
        self, web_hmi: AdaptioWebHmi, setup_plc: PlcJsonRpc, bench_power_supply, weld_data_set_setup
    ):
        """ACTIVE → READY when stop is pressed and arcing ceases."""
        plc = setup_plc
        psu = bench_power_supply
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

        assert simulate_arcing(psu), "Simulate arcing should succeed"
        time.sleep(0.5)
        state = receive_arc_state(web_hmi)
        assert state == "active", f"Expected 'active', got '{state}'"

        # Stop the weld
        assert simulate_weld_stop(plc), "Weld stop should succeed"
        time.sleep(0.5)

        # Remove arc voltage → READY
        assert simulate_arcing_stopped(psu), "Clearing arcing should succeed"
        time.sleep(0.5)

        state = receive_arc_state(web_hmi)
        assert state is not None, "Should receive arc state update after stop"
        logger.info(f"Arc state after stop: {state}")
        assert state == "ready", f"Arc state should transition to 'ready', got '{state}'"

    @pytest.mark.gen2
    @pytest.mark.plc_only
    def test_bench_psu_set_voltage_current_and_check_status(
        self,
        web_hmi: AdaptioWebHmi,
        setup_plc: PlcJsonRpc,
        bench_power_supply,
        weld_data_set_setup,
    ):
        """Enable bench PSU, set voltage/current, trigger READY, and verify power source status."""
        plc = setup_plc
        try:
            reset_plc_weld_signals(plc)
        except Exception as exc:
            logger.debug(f"reset_plc_weld_signals failed (non-fatal): {exc}")

        # 1. Subscribe to arc state and select WDS → CONFIGURED
        initial_state = subscribe_arc_state(web_hmi)
        if initial_state is None:
            pytest.skip("Device does not support SubscribeArcState")

        wds_id = weld_data_set_setup["wds_id"]
        result = select_weld_data_set(web_hmi, weld_data_set_id=wds_id)
        assert result, "Selecting weld data set should succeed"

        if initial_state != "configured":
            state = receive_arc_state(web_hmi)
            assert state == "configured", f"Expected 'configured', got '{state}'"

        # 2. Enable bench PSU output with voltage and current
        assert enable_bench_psu_output(
            bench_power_supply, voltage=25.0, current=0.5, output=1
        ), "Bench PSU output should be enabled"

        # 3. Set PLC setpoint values for power source 1
        assert set_power_source_voltage(plc, voltage=25.0, ps=1), (
            "Setting PS1 voltage setpoint should succeed"
        )
        assert set_power_source_current(plc, current=0.5, ps=1), (
            "Setting PS1 current setpoint should succeed"
        )

        # 4. Signal both power sources READY via PLC → CONFIGURED → READY
        assert simulate_power_sources_ready(plc), (
            "Setting power sources ReadyToWeld should succeed"
        )
        time.sleep(1)  # allow PLC → Adaptio propagation

        state = receive_arc_state(web_hmi, max_retries=15)
        assert state is not None, "Should receive arc state update after power sources ready"
        logger.info(f"Arc state after power sources ready: {state}")
        assert state == "ready", f"Expected 'ready', got '{state}'"

        # 5. Read power source status and verify
        status = read_power_source_status(plc, ps=1)
        assert status is not None, "read_power_source_status should succeed"
        logger.info(f"Power source 1 status: {status}")

        assert status["ready_to_weld"] is True, (
            f"PS1 should be ready_to_weld, got {status['ready_to_weld']}"
        )
        assert status["error"] is not True, (
            f"PS1 should not be in error state, got {status['error']}"
        )
