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
from testzilla.utility.cleanup_utils import cleanup_web_hmi_client
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


@pytest.fixture(name="web_hmi")
def web_hmi_fixture(request: pytest.FixtureRequest):
    web_hmi = AdaptioWebHmi(uri=request.config.WEB_HMI_URI)
    yield web_hmi
    cleanup_web_hmi_client(web_hmi)


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
    creating and selecting weld data sets, and verifying arc state transitions.
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

        if initial_state != "configured":
            state = receive_arc_state(web_hmi)
            assert state is not None, "Should receive arc state update after selection"
            logger.info(f"Arc state after selection: {state}")
            assert state == "configured", f"Arc state should transition to 'configured', got '{state}'"
    
    @pytest.mark.gen2
    def test_arc_state_ready_after_power_sources_ready(
        self, web_hmi: AdaptioWebHmi, setup_plc: PlcJsonRpc, weld_data_set_setup
    ):
        try:
            reset_plc_weld_signals(setup_plc)
        except Exception:
            pass

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

        # Set both power sources to READY_TO_START via PLC
        assert simulate_power_sources_ready(setup_plc), "Setting power sources ready should succeed"
        time.sleep(0.5)  # allow PLC→Adaptio propagation

        state = receive_arc_state(web_hmi)
        assert state is not None, "Should receive arc state update after power sources ready"
        logger.info(f"Arc state after power sources ready: {state}")
        assert state == "ready", f"Arc state should transition to 'ready', got '{state}'"

    @pytest.mark.gen2
    def test_arc_state_starting_after_start_button(
        self, web_hmi: AdaptioWebHmi, setup_plc: PlcJsonRpc, weld_data_set_setup
    ):
        try:
            reset_plc_weld_signals(setup_plc)
        except Exception:
            pass

        # Subscribe and drive to READY
        initial_state = subscribe_arc_state(web_hmi)
        if initial_state is None:
            pytest.skip("Skipping test: device does not support SubscribeArcState")

        wds_id = weld_data_set_setup["wds_id"]
        result = select_weld_data_set(web_hmi, weld_data_set_id=wds_id)
        assert result, "Selecting weld data set should succeed"

        if initial_state != "configured":
            receive_arc_state(web_hmi)  # consume CONFIGURED

        assert simulate_power_sources_ready(setup_plc), "Power sources ready should succeed"
        time.sleep(0.5)
        state = receive_arc_state(web_hmi)
        assert state == "ready", f"Expected 'ready', got '{state}'"

        # Press start via PLC → STARTING
        assert simulate_weld_start(setup_plc), "Weld start should succeed"
        time.sleep(0.5)  # allow PLC→Adaptio propagation

        state = receive_arc_state(web_hmi)
        assert state is not None, "Should receive arc state update after start"
        logger.info(f"Arc state after start: {state}")
        assert state == "starting", f"Arc state should transition to 'starting', got '{state}'"

    @pytest.mark.gen2
    def test_arc_state_active_after_arcing(
        self, web_hmi: AdaptioWebHmi, setup_plc: PlcJsonRpc, weld_data_set_setup
    ):
        try:
            reset_plc_weld_signals(setup_plc)
        except Exception:
            pass

        # Subscribe and drive to STARTING
        initial_state = subscribe_arc_state(web_hmi)
        if initial_state is None:
            pytest.skip("Skipping test: device does not support SubscribeArcState")

        wds_id = weld_data_set_setup["wds_id"]
        result = select_weld_data_set(web_hmi, weld_data_set_id=wds_id)
        assert result, "Selecting weld data set should succeed"

        if initial_state != "configured":
            receive_arc_state(web_hmi)  # consume CONFIGURED

        assert simulate_power_sources_ready(setup_plc), "Power sources ready should succeed"
        time.sleep(0.5)
        receive_arc_state(web_hmi)  # consume READY

        assert simulate_weld_start(setup_plc), "Weld start should succeed"
        time.sleep(0.5)
        receive_arc_state(web_hmi)  # consume STARTING

        # Power source 1 starts arcing → ACTIVE
        assert simulate_arcing(setup_plc), "Simulate arcing should succeed"
        time.sleep(0.5)  # allow PLC→Adaptio propagation

        state = receive_arc_state(web_hmi)
        assert state is not None, "Should receive arc state update after arcing"
        logger.info(f"Arc state after arcing: {state}")
        assert state == "active", f"Arc state should transition to 'active', got '{state}'"

    @pytest.mark.gen2
    def test_arc_state_ready_after_stop(
        self, web_hmi: AdaptioWebHmi, setup_plc: PlcJsonRpc, weld_data_set_setup
    ):
        try:
            reset_plc_weld_signals(setup_plc)
        except Exception:
            pass

        # Subscribe and drive to ACTIVE
        initial_state = subscribe_arc_state(web_hmi)
        if initial_state is None:
            pytest.skip("Skipping test: device does not support SubscribeArcState")

        wds_id = weld_data_set_setup["wds_id"]
        result = select_weld_data_set(web_hmi, weld_data_set_id=wds_id)
        assert result, "Selecting weld data set should succeed"

        if initial_state != "configured":
            receive_arc_state(web_hmi)  # consume CONFIGURED

        assert simulate_power_sources_ready(setup_plc), "Power sources ready should succeed"
        time.sleep(0.5)
        receive_arc_state(web_hmi)  # consume READY

        assert simulate_weld_start(setup_plc), "Weld start should succeed"
        time.sleep(0.5)
        receive_arc_state(web_hmi)  # consume STARTING

        assert simulate_arcing(setup_plc), "Simulate arcing should succeed"
        time.sleep(0.5)
        state = receive_arc_state(web_hmi)
        assert state == "active", f"Expected 'active', got '{state}'"

        # Stop the weld
        assert simulate_weld_stop(setup_plc), "Weld stop should succeed"
        time.sleep(0.5)

        # Clear arcing on power source → READY
        assert simulate_arcing_stopped(setup_plc), "Clearing arcing should succeed"
        time.sleep(0.5)

        state = receive_arc_state(web_hmi)
        assert state is not None, "Should receive arc state update after stop"
        logger.info(f"Arc state after stop: {state}")
        assert state == "ready", f"Arc state should transition to 'ready', got '{state}'"