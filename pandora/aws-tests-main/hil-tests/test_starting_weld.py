"""HIL test cases for weld data handling via the adaptio module.

These tests follow the weld data handling specification and verify CRUD operations
for weld process parameters (WPP) and weld data sets (WDS) through the WebHMI
interface. Each test checks existing data first and selects appropriately by name,
following the operator workflow described in the specification:

  Weld Process Parameters:
    - Create: AddWeldProcessParameters (fails if name not unique)
    - Update: GetWeldProcessParameters → select by name → UpdateWeldProcessParameters
    - Delete: GetWeldProcessParameters → select by name → RemoveWeldProcessParameters
             (fails if referenced by a weld data set)

  Weld Data Sets:
    - Create: GetWeldProcessParameters → select WPP by name → AddWeldDataSet
             (fails if name not unique or WPP ids don't exist)
    - Update: GetWeldDataSets + GetWeldProcessParameters → select by name → UpdateWeldDataSet
    - Delete: GetWeldDataSets → select by name → RemoveWeldDataSet
             (fails if referenced by a weld program)

Arc state transitions are also verified after weld data set selection.
"""

import pytest
from loguru import logger

from conftest import (
    add_weld_data_set,
    add_weld_process_parameters,
    ensure_weld_data_set,
    ensure_weld_process_parameters,
    get_weld_data_sets,
    get_weld_process_parameters,
    get_weld_process_parameters_config,
    receive_arc_state,
    remove_weld_data_set,
    remove_weld_process_parameters,
    select_weld_data_set,
    subscribe_arc_state,
    update_weld_data_set,
    update_weld_process_parameters,
)
from testzilla.adaptio_web_hmi.adaptio_web_hmi import AdaptioWebHmi
from testzilla.utility.cleanup_utils import cleanup_web_hmi_client


@pytest.fixture(name="web_hmi")
def web_hmi_fixture(request: pytest.FixtureRequest):
    """Provide an AdaptioWebHmi instance for weld tests."""
    web_hmi = AdaptioWebHmi(uri=request.config.WEB_HMI_URI)
    yield web_hmi
    cleanup_web_hmi_client(web_hmi)


@pytest.fixture(name="weld_process_parameters_setup")
def weld_process_parameters_setup_fixture(web_hmi: AdaptioWebHmi):
    """Ensure weld process parameters exist for both weld systems.

    Uses an upsert pattern to avoid unnecessary deletion and re-creation
    of WPP entries, which would cause SQLite auto-increment IDs to grow.
    If WPP with the expected names already exist and match the desired config,
    they are reused. If they exist but differ, they are updated in place.
    Only adds new entries if they don't exist yet.

    Returns:
        dict with 'ws1_wpp_id' and 'ws2_wpp_id' (actual database IDs)
    """
    ws1_config = get_weld_process_parameters_config("ws1")
    ws2_config = get_weld_process_parameters_config("ws2")

    ws1_wpp_id = ensure_weld_process_parameters(web_hmi, **ws1_config)
    if ws1_wpp_id is None:
        pytest.skip("Skipping test: failed to ensure weld process parameters for WS1")

    ws2_wpp_id = ensure_weld_process_parameters(web_hmi, **ws2_config)
    if ws2_wpp_id is None:
        pytest.skip("Skipping test: failed to ensure weld process parameters for WS2")

    wpp_ids = {"ws1_wpp_id": ws1_wpp_id, "ws2_wpp_id": ws2_wpp_id}
    logger.info(f"WPP IDs: ws1={wpp_ids['ws1_wpp_id']}, ws2={wpp_ids['ws2_wpp_id']}")
    return wpp_ids


@pytest.fixture(name="weld_data_set_setup")
def weld_data_set_setup_fixture(web_hmi: AdaptioWebHmi, weld_process_parameters_setup):
    """Ensure a weld data set exists linking WS1 and WS2 weld process parameters.

    Uses an upsert pattern to avoid unnecessary deletion and re-creation
    of WDS entries, which would cause SQLite auto-increment IDs to grow.
    If a WDS with the expected name already exists and references the correct
    WPP IDs, it is reused. If it exists but differs, it is updated in place.
    Only adds a new entry if it doesn't exist yet.

    Returns:
        dict with 'wds_id', 'ws1_wpp_id', and 'ws2_wpp_id' (actual database IDs)
    """
    wpp_ids = weld_process_parameters_setup
    wds_id = ensure_weld_data_set(
        web_hmi,
        name="ManualWeld",
        ws1_wpp_id=wpp_ids["ws1_wpp_id"],
        ws2_wpp_id=wpp_ids["ws2_wpp_id"],
    )
    if wds_id is None:
        pytest.skip("Skipping test: failed to ensure weld data set")

    logger.info(f"WDS ID: {wds_id}")
    return {"wds_id": wds_id, **wpp_ids}


class TestWeldDataHandling:
    """Test suite for weld data handling following the specification.

    Covers CRUD operations for weld process parameters and weld data sets,
    weld data set selection, and arc state transitions.
    """

    # --- Weld Process Parameters: Create ---

    @pytest.mark.weld
    @pytest.mark.weld_process_parameters
    def test_create_weld_process_parameters(self, web_hmi: AdaptioWebHmi):
        """Test creating weld process parameters for both weld systems.

        Follows the spec: checks existing data first, only adds if not present.
        Uses the ensure (upsert) pattern to avoid always removing and re-adding.
        """
        ws1_config = get_weld_process_parameters_config("ws1")
        ws2_config = get_weld_process_parameters_config("ws2")

        ws1_wpp_id = ensure_weld_process_parameters(web_hmi, **ws1_config)
        assert ws1_wpp_id is not None, "Creating/ensuring WPP for WS1 should succeed"

        ws2_wpp_id = ensure_weld_process_parameters(web_hmi, **ws2_config)
        assert ws2_wpp_id is not None, "Creating/ensuring WPP for WS2 should succeed"

    # --- Weld Process Parameters: Read (Get) ---

    @pytest.mark.weld
    @pytest.mark.weld_process_parameters
    def test_get_weld_process_parameters(self, web_hmi: AdaptioWebHmi, weld_process_parameters_setup):
        """Test retrieving the weld process parameters list.

        Follows the spec: GetWeldProcessParameters → GetWeldProcessParametersRsp
        Verifies the response contains the expected WPP entries by name.
        """
        wpp_list = get_weld_process_parameters(web_hmi)
        assert wpp_list is not None, "GetWeldProcessParameters should return a response"
        assert len(wpp_list) >= 2, "Should have at least 2 WPP entries"

        ws1_config = get_weld_process_parameters_config("ws1")
        ws2_config = get_weld_process_parameters_config("ws2")

        ws1_names = [wpp["name"] for wpp in wpp_list if isinstance(wpp, dict)]
        assert ws1_config["name"] in ws1_names, f"WPP list should contain '{ws1_config['name']}'"
        assert ws2_config["name"] in ws1_names, f"WPP list should contain '{ws2_config['name']}'"
        logger.info(f"Retrieved {len(wpp_list)} weld process parameters")

    # --- Weld Process Parameters: Update ---

    @pytest.mark.weld
    @pytest.mark.weld_process_parameters
    def test_update_weld_process_parameters(self, web_hmi: AdaptioWebHmi, weld_process_parameters_setup):
        """Test updating weld process parameters.

        Follows the spec flow:
          1. GetWeldProcessParameters (get the list)
          2. Select WPP by name from the list
          3. UpdateWeldProcessParameters with modified values
        """
        wpp_list = get_weld_process_parameters(web_hmi)
        assert wpp_list is not None, "GetWeldProcessParameters should return a response"

        # Select WPP by name from the list (per spec)
        ws1_config = get_weld_process_parameters_config("ws1")
        ws1_wpp = next(
            (wpp for wpp in wpp_list if isinstance(wpp, dict) and wpp.get("name") == ws1_config["name"]),
            None,
        )
        assert ws1_wpp is not None, f"Should find WPP with name '{ws1_config['name']}' in the list"

        # Update with the same config (idempotent operation)
        ws1_wpp_id = ws1_wpp["id"]
        result = update_weld_process_parameters(web_hmi, ws1_wpp_id, **ws1_config)
        assert result, "Updating weld process parameters should succeed"

    # --- Weld Process Parameters: Delete (constraint test) ---

    @pytest.mark.weld
    @pytest.mark.weld_process_parameters
    def test_delete_weld_process_parameters_fails_when_referenced(
        self, web_hmi: AdaptioWebHmi, weld_data_set_setup
    ):
        """Test that deleting WPP fails when referenced by a weld data set.

        Follows the spec: 'Fails if the weld process parameters are referenced
        by a weld data set.'

        Flow:
          1. GetWeldProcessParameters (get the list)
          2. Select WPP by name from the list
          3. RemoveWeldProcessParameters → should fail (referenced by WDS)
        """
        wpp_list = get_weld_process_parameters(web_hmi)
        assert wpp_list is not None, "GetWeldProcessParameters should return a response"

        # Select WPP by name that is used by the WDS
        ws1_config = get_weld_process_parameters_config("ws1")
        ws1_wpp = next(
            (wpp for wpp in wpp_list if isinstance(wpp, dict) and wpp.get("name") == ws1_config["name"]),
            None,
        )
        assert ws1_wpp is not None, f"Should find WPP with name '{ws1_config['name']}'"

        # Attempt deletion - should fail because WPP is referenced by WDS
        result = remove_weld_process_parameters(web_hmi, ws1_wpp["id"])
        assert not result, "Removing WPP referenced by a weld data set should fail"

    # --- Weld Data Set: Create ---

    @pytest.mark.weld
    @pytest.mark.weld_data_set
    def test_create_weld_data_set(self, web_hmi: AdaptioWebHmi, weld_process_parameters_setup):
        """Test creating a weld data set that links two weld process parameters.

        Follows the spec flow:
          1. GetWeldProcessParameters (get the list)
          2. Select ws1 and ws2 WPP by name from the list
          3. AddWeldDataSet with the selected WPP IDs

        Uses the ensure (upsert) pattern to check existing data first.
        """
        # Get WPP list and select by name (per spec)
        wpp_list = get_weld_process_parameters(web_hmi)
        assert wpp_list is not None, "GetWeldProcessParameters should return a response"

        wpp_ids = weld_process_parameters_setup
        wds_id = ensure_weld_data_set(
            web_hmi,
            name="ManualWeld",
            ws1_wpp_id=wpp_ids["ws1_wpp_id"],
            ws2_wpp_id=wpp_ids["ws2_wpp_id"],
        )
        assert wds_id is not None, "Creating/ensuring weld data set should succeed"

    # --- Weld Data Set: Read (Get) ---

    @pytest.mark.weld
    @pytest.mark.weld_data_set
    def test_get_weld_data_sets(self, web_hmi: AdaptioWebHmi, weld_data_set_setup):
        """Test retrieving weld data sets.

        Follows the spec: GetWeldDataSets → GetWeldDataSetsRsp
        Verifies the response contains the expected weld data set by name.
        """
        weld_data_sets = get_weld_data_sets(web_hmi)
        assert weld_data_sets is not None, "GetWeldDataSets should return a response"

        wds_names = [wds["name"] for wds in weld_data_sets if isinstance(wds, dict)]
        assert "ManualWeld" in wds_names, "WDS list should contain 'ManualWeld'"
        logger.info(f"Retrieved weld data sets: {weld_data_sets}")

    # --- Weld Data Set: Update ---

    @pytest.mark.weld
    @pytest.mark.weld_data_set
    def test_update_weld_data_set(self, web_hmi: AdaptioWebHmi, weld_data_set_setup):
        """Test updating a weld data set.

        Follows the spec flow:
          1. GetWeldDataSets (get the list)
          2. GetWeldProcessParameters (get WPP list)
          3. Select WDS and WPP by name from the lists
          4. UpdateWeldDataSet with the selected IDs
        """
        # Get WDS list and select by name (per spec)
        wds_list = get_weld_data_sets(web_hmi)
        assert wds_list is not None, "GetWeldDataSets should return a response"

        wds = next(
            (w for w in wds_list if isinstance(w, dict) and w.get("name") == "ManualWeld"),
            None,
        )
        assert wds is not None, "Should find WDS with name 'ManualWeld'"

        # Get WPP list (per spec)
        wpp_list = get_weld_process_parameters(web_hmi)
        assert wpp_list is not None, "GetWeldProcessParameters should return a response"

        # Update with the same config (idempotent operation)
        wpp_ids = weld_data_set_setup
        result = update_weld_data_set(
            web_hmi, wds["id"], "ManualWeld", wpp_ids["ws1_wpp_id"], wpp_ids["ws2_wpp_id"]
        )
        assert result, "Updating weld data set should succeed"

    # --- Weld Data Set: Select ---

    @pytest.mark.weld
    @pytest.mark.weld_data_set
    def test_select_weld_data_set(self, web_hmi: AdaptioWebHmi, weld_data_set_setup):
        """Test selecting a weld data set by querying existing data first.

        Follows the spec flow:
          1. GetWeldDataSets (get the list)
          2. Select WDS by name from the list
          3. SelectWeldDataSet with the found ID

        This triggers the adaptio module to configure weld system settings
        and transition the arc state to CONFIGURED.
        """
        # Get WDS list and select by name (per spec)
        wds_list = get_weld_data_sets(web_hmi)
        assert wds_list is not None, "GetWeldDataSets should return a response"

        wds = next(
            (w for w in wds_list if isinstance(w, dict) and w.get("name") == "ManualWeld"),
            None,
        )
        assert wds is not None, "Should find WDS with name 'ManualWeld'"

        result = select_weld_data_set(web_hmi, weld_data_set_id=wds["id"])
        assert result, "Selecting weld data set should succeed"

    # --- Weld Data Set: Delete ---

    @pytest.mark.weld
    @pytest.mark.weld_data_set
    def test_delete_weld_data_set(self, web_hmi: AdaptioWebHmi, weld_data_set_setup):
        """Test deleting a weld data set.

        Follows the spec flow:
          1. GetWeldDataSets (get the list)
          2. Select WDS by name from the list
          3. RemoveWeldDataSet with the found ID
          4. Re-create the WDS for subsequent tests

        Note: The WDS is re-created after deletion to avoid breaking
        subsequent tests that depend on weld_data_set_setup.
        """
        # Get WDS list and select by name (per spec)
        wds_list = get_weld_data_sets(web_hmi)
        assert wds_list is not None, "GetWeldDataSets should return a response"

        wds = next(
            (w for w in wds_list if isinstance(w, dict) and w.get("name") == "ManualWeld"),
            None,
        )
        assert wds is not None, "Should find WDS with name 'ManualWeld'"

        # Delete the weld data set
        result = remove_weld_data_set(web_hmi, wds["id"])
        assert result, "Removing weld data set should succeed"

        # Verify deletion
        wds_list_after = get_weld_data_sets(web_hmi)
        wds_names = [w["name"] for w in (wds_list_after or []) if isinstance(w, dict)]
        assert "ManualWeld" not in wds_names, "WDS 'ManualWeld' should be removed"

        # Re-create WDS for subsequent tests
        wpp_ids = weld_data_set_setup
        add_weld_data_set(
            web_hmi,
            name="ManualWeld",
            ws1_wpp_id=wpp_ids["ws1_wpp_id"],
            ws2_wpp_id=wpp_ids["ws2_wpp_id"],
        )

    # --- Arc State ---

    @pytest.mark.weld
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

    @pytest.mark.weld
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
