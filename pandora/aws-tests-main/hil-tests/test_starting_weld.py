"""HIL test cases for starting weld via the adaptio module.

These tests verify the manual weld flow by interacting with the adaptio module
through the WebHMI interface. The flow covers:
  1. Adding weld process parameters (WPP) for two weld systems
  2. Creating a weld data set (WDS) linking the two WPPs
  3. Selecting the weld data set
  4. Verifying arc state transitions (IDLE -> CONFIGURED)

PLC interaction is not involved in these tests.
"""

import pytest
from loguru import logger

from conftest import (
    add_weld_data_set,
    add_weld_process_parameters,
    clean_weld_data,
    get_weld_data_sets,
    get_weld_process_parameters,
    get_weld_process_parameters_config,
    receive_arc_state,
    select_weld_data_set,
    subscribe_arc_state,
)
from testzilla.adaptio_web_hmi.adaptio_web_hmi import AdaptioWebHmi
from testzilla.utility.cleanup_utils import cleanup_web_hmi_client


def _find_wpp_ids(web_hmi: AdaptioWebHmi, ws1_name: str, ws2_name: str) -> dict | None:
    """Query the device for actual WPP IDs by name.

    After adding weld process parameters, their database IDs are auto-incremented
    and cannot be assumed to be 1 and 2. This helper queries the device for the
    actual IDs.

    Returns:
        dict with 'ws1_wpp_id' and 'ws2_wpp_id', or None if not found
    """
    wpp_list = get_weld_process_parameters(web_hmi)
    if not wpp_list:
        return None

    ws1_wpp_id = None
    ws2_wpp_id = None
    for wpp in wpp_list:
        if isinstance(wpp, dict):
            if wpp.get("name") == ws1_name:
                ws1_wpp_id = wpp.get("id")
            elif wpp.get("name") == ws2_name:
                ws2_wpp_id = wpp.get("id")

    if ws1_wpp_id is not None and ws2_wpp_id is not None:
        return {"ws1_wpp_id": ws1_wpp_id, "ws2_wpp_id": ws2_wpp_id}
    return None


def _find_wds_id(web_hmi: AdaptioWebHmi, wds_name: str) -> int | None:
    """Query the device for actual WDS ID by name.

    After adding a weld data set, its database ID is auto-incremented
    and cannot be assumed to be 1. This helper queries the device for
    the actual ID.

    Returns:
        WDS ID, or None if not found
    """
    wds_list = get_weld_data_sets(web_hmi)
    if not wds_list:
        return None

    for wds in wds_list:
        if isinstance(wds, dict) and wds.get("name") == wds_name:
            return wds.get("id")
    return None


@pytest.fixture(name="web_hmi")
def web_hmi_fixture(request: pytest.FixtureRequest):
    """Provide an AdaptioWebHmi instance for weld tests."""
    web_hmi = AdaptioWebHmi(uri=request.config.WEB_HMI_URI)
    yield web_hmi
    cleanup_web_hmi_client(web_hmi)


@pytest.fixture(name="weld_process_parameters_setup")
def weld_process_parameters_setup_fixture(web_hmi: AdaptioWebHmi):
    """Add weld process parameters for both weld systems.

    Reads WPP data from webhmi_data.yml and adds parameters for WS1 and WS2.
    Removes any existing weld data sets and weld process parameters first
    to avoid name conflicts from previous test runs.
    Skips tests if the adaptio module is not reachable.

    Returns:
        dict with 'ws1_wpp_id' and 'ws2_wpp_id' (actual database IDs)
    """
    clean_weld_data(web_hmi)

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
    """Add a weld data set linking WS1 and WS2 weld process parameters.

    Uses the actual WPP IDs from the device (not hardcoded) since database IDs
    auto-increment across test runs.

    Returns:
        dict with 'wds_id', 'ws1_wpp_id', and 'ws2_wpp_id' (actual database IDs)
    """
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

    def test_add_weld_process_parameters(self, web_hmi: AdaptioWebHmi):
        """Test adding weld process parameters for both weld systems.

        Verifies that WPP can be successfully added for WS1 and WS2
        using the parameters defined in webhmi_data.yml.
        Cleans up existing data first to avoid name conflicts.
        """
        clean_weld_data(web_hmi)

        ws1_config = get_weld_process_parameters_config("ws1")
        ws2_config = get_weld_process_parameters_config("ws2")

        result_ws1 = add_weld_process_parameters(web_hmi, **ws1_config)
        assert result_ws1, "Adding weld process parameters for WS1 should succeed"

        result_ws2 = add_weld_process_parameters(web_hmi, **ws2_config)
        assert result_ws2, "Adding weld process parameters for WS2 should succeed"

    def test_add_weld_data_set(self, web_hmi: AdaptioWebHmi, weld_process_parameters_setup):
        """Test adding a weld data set that links two weld process parameters.

        Requires WPPs to be added first (via weld_process_parameters_setup fixture).
        Uses actual WPP IDs from the device since they auto-increment.
        """
        wpp_ids = weld_process_parameters_setup
        result = add_weld_data_set(
            web_hmi,
            name="ManualWeld",
            ws1_wpp_id=wpp_ids["ws1_wpp_id"],
            ws2_wpp_id=wpp_ids["ws2_wpp_id"],
        )
        assert result, "Adding weld data set should succeed"

    def test_get_weld_data_sets(self, web_hmi: AdaptioWebHmi, weld_data_set_setup):
        """Test retrieving weld data sets after adding one.

        Verifies that GetWeldDataSets returns a non-empty response after
        a weld data set has been added.
        """
        weld_data_sets = get_weld_data_sets(web_hmi)
        assert weld_data_sets is not None, "GetWeldDataSets should return a response"
        logger.info(f"Retrieved weld data sets: {weld_data_sets}")

    def test_select_weld_data_set(self, web_hmi: AdaptioWebHmi, weld_data_set_setup):
        """Test selecting a weld data set.

        Verifies that SelectWeldDataSet succeeds for the created weld data set.
        This triggers the adaptio module to configure weld system settings
        and transition the arc state to CONFIGURED.
        """
        wds_id = weld_data_set_setup["wds_id"]
        result = select_weld_data_set(web_hmi, weld_data_set_id=wds_id)
        assert result, "Selecting weld data set should succeed"

    def test_arc_state_idle_on_subscribe(self, web_hmi: AdaptioWebHmi):
        """Test that subscribing to arc state returns IDLE as initial state.

        Before any weld data set is selected, the arc state should be IDLE.
        Skips if the device does not support SubscribeArcState (e.g. older firmware).
        """
        state = subscribe_arc_state(web_hmi)
        if state is None:
            pytest.skip("Skipping test: device does not support SubscribeArcState")
        logger.info(f"Initial arc state: {state}")
        assert state == "idle", f"Initial arc state should be 'idle', got '{state}'"

    def test_arc_state_transitions_to_configured(self, web_hmi: AdaptioWebHmi, weld_data_set_setup):
        """Test that selecting a weld data set transitions arc state to CONFIGURED.

        Flow:
          1. Subscribe to arc state (initial state should be IDLE or CONFIGURED)
          2. Select the weld data set
          3. Verify that the arc state transitions to 'configured'

        This verifies the adaptio module correctly processes the weld data set
        selection and updates the weld system settings.
        Skips if the device does not support SubscribeArcState (e.g. older firmware).
        """
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
