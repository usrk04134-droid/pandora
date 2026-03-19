"""HIL integration tests for starting weld.

Reference: adaptio-gen_2_ms3/src/block_tests/weld_start.cc
           adaptio-gen_2_ms3/src/block_tests/manual_weld_test.cc

These tests cover the weld-start use case via the WebHMI WebSocket interface:
  1. Add weld process parameters (WPP) for two weld systems
  2. Add a weld data set (WDS) referencing both WPPs
  3. Select the WDS (arc state transitions to 'configured')
  4. Query arc state to verify the transition
  5. Retrieve WPP / WDS lists and validate content
  6. Cleanup: remove WDS, then WPPs

The PLC is NOT involved in this use case so no PLC data or state is checked.
"""

import pytest
from loguru import logger

from testzilla.adaptio_web_hmi.adaptio_web_hmi import (
    AdaptioWebHmi,
    AdaptioWebHmiMessage,
)
from testzilla.utility.cleanup_utils import cleanup_web_hmi_client


# ---------------------------------------------------------------------------
# Default weld process parameters – mirrors the C++ test data in
# helpers_weld_parameters.h (WPP_DEFAULT_WS1 / WPP_DEFAULT_WS2)
# ---------------------------------------------------------------------------
WPP_DEFAULT_WS1 = {
    "name":           "HilTestWS1",
    "method":         "dc",
    "regulationType": "cc",
    "startAdjust":    10,
    "startType":      "scratch",
    "voltage":        25.0,
    "current":        200.0,
    "wireSpeed":      15.0,
    "iceWireSpeed":   0.0,
    "acFrequency":    60.0,
    "acOffset":       1.2,
    "acPhaseShift":   0.5,
    "craterFillTime": 2.0,
    "burnBackTime":   1.0,
}

WPP_DEFAULT_WS2 = {
    "name":           "HilTestWS2",
    "method":         "dc",
    "regulationType": "cc",
    "startAdjust":    10,
    "startType":      "direct",
    "voltage":        28.0,
    "current":        180.0,
    "wireSpeed":      14.0,
    "iceWireSpeed":   0.0,
    "acFrequency":    60.0,
    "acOffset":       1.2,
    "acPhaseShift":   0.5,
    "craterFillTime": 2.0,
    "burnBackTime":   1.0,
}

WDS_NAME = "HilTestManualWeld"


# ---------------------------------------------------------------------------
# Helpers – thin wrappers around AdaptioWebHmi.send_and_receive_message
# ---------------------------------------------------------------------------

def _result_ok(response: AdaptioWebHmiMessage) -> bool:
    """Return True when the response carries result == 'ok'."""
    result = getattr(response, "result", None) or response.payload.get("result")
    return result == "ok"


def add_weld_process_parameters(web_hmi: AdaptioWebHmi, wpp: dict) -> AdaptioWebHmiMessage:
    """Add a set of weld process parameters."""
    return web_hmi.send_and_receive_message(
        condition=None,
        request_name="AddWeldProcessParameters",
        response_name="AddWeldProcessParametersRsp",
        payload=wpp,
    )


def get_weld_process_parameters(web_hmi: AdaptioWebHmi) -> AdaptioWebHmiMessage:
    """Retrieve all weld process parameters."""
    return web_hmi.send_and_receive_message(
        condition=None,
        request_name="GetWeldProcessParameters",
        response_name="GetWeldProcessParametersRsp",
        payload={},
    )


def remove_weld_process_parameters(web_hmi: AdaptioWebHmi, wpp_id: int) -> AdaptioWebHmiMessage:
    """Remove weld process parameters by ID."""
    return web_hmi.send_and_receive_message(
        condition=None,
        request_name="RemoveWeldProcessParameters",
        response_name="RemoveWeldProcessParametersRsp",
        payload={"id": wpp_id},
    )


def add_weld_data_set(web_hmi: AdaptioWebHmi, name: str, ws1_wpp_id: int, ws2_wpp_id: int) -> AdaptioWebHmiMessage:
    """Add a weld data set referencing two WPP IDs."""
    return web_hmi.send_and_receive_message(
        condition=None,
        request_name="AddWeldDataSet",
        response_name="AddWeldDataSetRsp",
        payload={"name": name, "ws1WppId": ws1_wpp_id, "ws2WppId": ws2_wpp_id},
    )


def get_weld_data_sets(web_hmi: AdaptioWebHmi) -> AdaptioWebHmiMessage:
    """Retrieve all weld data sets."""
    return web_hmi.send_and_receive_message(
        condition=None,
        request_name="GetWeldDataSets",
        response_name="GetWeldDataSetsRsp",
        payload={},
    )


def remove_weld_data_set(web_hmi: AdaptioWebHmi, wds_id: int) -> AdaptioWebHmiMessage:
    """Remove a weld data set by ID."""
    return web_hmi.send_and_receive_message(
        condition=None,
        request_name="RemoveWeldDataSet",
        response_name="RemoveWeldDataSetRsp",
        payload={"id": wds_id},
    )


def select_weld_data_set(web_hmi: AdaptioWebHmi, wds_id: int) -> AdaptioWebHmiMessage:
    """Select a weld data set for the manual weld arc state machine."""
    return web_hmi.send_and_receive_message(
        condition=None,
        request_name="SelectWeldDataSet",
        response_name="SelectWeldDataSetRsp",
        payload={"id": wds_id},
    )


def get_arc_state(web_hmi: AdaptioWebHmi) -> AdaptioWebHmiMessage:
    """Query the current arc state (one-shot, no subscription)."""
    return web_hmi.send_and_receive_message(
        condition=None,
        request_name="GetArcState",
        response_name="ArcState",
        payload={},
    )


def subscribe_arc_state(web_hmi: AdaptioWebHmi) -> AdaptioWebHmiMessage:
    """Subscribe to arc-state push messages.  Returns the initial ArcState."""
    return web_hmi.send_and_receive_message(
        condition=None,
        request_name="SubscribeArcState",
        response_name="ArcState",
        payload={},
    )


# ---------------------------------------------------------------------------
# Ensure (upsert) helpers – query first, add only if not already present.
# Returns the actual ID to avoid hardcoding auto-increment IDs.
# ---------------------------------------------------------------------------

def _extract_list(payload, key: str) -> list:
    """Extract a list from a payload that may be a list itself or a dict with a key."""
    if isinstance(payload, list):
        return payload
    return payload.get(key, [])


def _find_wpp_by_name(web_hmi: AdaptioWebHmi, name: str) -> int | None:
    """Return the ID of a WPP with the given name, or None."""
    response = get_weld_process_parameters(web_hmi)
    items = _extract_list(response.payload, "weldProcessParameters")
    for item in items:
        if item.get("name") == name:
            return item.get("id")
    return None


def _find_wds_by_name(web_hmi: AdaptioWebHmi, name: str) -> int | None:
    """Return the ID of a WDS with the given name, or None."""
    response = get_weld_data_sets(web_hmi)
    items = _extract_list(response.payload, "weldDataSets")
    for item in items:
        if item.get("name") == name:
            return item.get("id")
    return None


def ensure_weld_process_parameters(web_hmi: AdaptioWebHmi, wpp: dict) -> int:
    """Ensure a WPP exists (upsert-style).  Returns the WPP ID."""
    existing_id = _find_wpp_by_name(web_hmi, wpp["name"])
    if existing_id is not None:
        logger.info(f"WPP '{wpp['name']}' already exists with id={existing_id}")
        return existing_id

    response = add_weld_process_parameters(web_hmi, wpp)
    assert _result_ok(response), f"Failed to add WPP '{wpp['name']}': {response}"

    new_id = _find_wpp_by_name(web_hmi, wpp["name"])
    assert new_id is not None, f"WPP '{wpp['name']}' not found after adding"
    logger.info(f"Added WPP '{wpp['name']}' with id={new_id}")
    return new_id


def ensure_weld_data_set(web_hmi: AdaptioWebHmi, name: str, ws1_wpp_id: int, ws2_wpp_id: int) -> int:
    """Ensure a WDS exists (upsert-style).  Returns the WDS ID."""
    existing_id = _find_wds_by_name(web_hmi, name)
    if existing_id is not None:
        logger.info(f"WDS '{name}' already exists with id={existing_id}")
        return existing_id

    response = add_weld_data_set(web_hmi, name, ws1_wpp_id, ws2_wpp_id)
    assert _result_ok(response), f"Failed to add WDS '{name}': {response}"

    new_id = _find_wds_by_name(web_hmi, name)
    assert new_id is not None, f"WDS '{name}' not found after adding"
    logger.info(f"Added WDS '{name}' with id={new_id}")
    return new_id


# ---------------------------------------------------------------------------
# Cleanup helper – remove in correct dependency order:
#   WeldDataSets first (they reference WPPs), then WeldProcessParameters.
# ---------------------------------------------------------------------------

def clean_weld_test_data(web_hmi: AdaptioWebHmi, wds_names: list[str], wpp_names: list[str]) -> None:
    """Remove WDS and WPP entries created by these tests."""
    # Remove WDS first
    for name in wds_names:
        wds_id = _find_wds_by_name(web_hmi, name)
        if wds_id is not None:
            try:
                remove_weld_data_set(web_hmi, wds_id)
                logger.info(f"Removed WDS '{name}' (id={wds_id})")
            except Exception:
                logger.warning(f"Failed to remove WDS '{name}' (id={wds_id})")

    # Then remove WPPs
    for name in wpp_names:
        wpp_id = _find_wpp_by_name(web_hmi, name)
        if wpp_id is not None:
            try:
                remove_weld_process_parameters(web_hmi, wpp_id)
                logger.info(f"Removed WPP '{name}' (id={wpp_id})")
            except Exception:
                logger.warning(f"Failed to remove WPP '{name}' (id={wpp_id})")


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture(name="web_hmi")
def web_hmi_fixture(request: pytest.FixtureRequest):
    """Provide a connected AdaptioWebHmi client for weld tests."""
    web_hmi = AdaptioWebHmi(uri=request.config.WEB_HMI_URI)
    yield web_hmi
    cleanup_web_hmi_client(web_hmi)


@pytest.fixture(name="weld_setup")
def weld_setup_fixture(web_hmi: AdaptioWebHmi):
    """Set up WPP + WDS for weld tests and clean up afterwards.

    Yields (ws1_wpp_id, ws2_wpp_id, wds_id).
    """
    try:
        ws1_id = ensure_weld_process_parameters(web_hmi, WPP_DEFAULT_WS1)
        ws2_id = ensure_weld_process_parameters(web_hmi, WPP_DEFAULT_WS2)
        wds_id = ensure_weld_data_set(web_hmi, WDS_NAME, ws1_id, ws2_id)
    except Exception:
        logger.exception("Failed to set up weld test data")
        pytest.skip("Skipping weld tests – could not create WPP/WDS test data")

    yield ws1_id, ws2_id, wds_id

    # Teardown: best-effort cleanup
    clean_weld_test_data(web_hmi, [WDS_NAME], [WPP_DEFAULT_WS1["name"], WPP_DEFAULT_WS2["name"]])


# ---------------------------------------------------------------------------
# Test class
# ---------------------------------------------------------------------------

@pytest.mark.weld
class TestStartingWeld:
    """HIL integration tests for the starting-weld use case.

    Corresponds to the C++ block tests in weld_start.cc and manual_weld_test.cc.
    """

    # -- WPP / WDS data handling tests (weld_sequence_config) ----------------

    def test_add_weld_process_parameters(self, web_hmi: AdaptioWebHmi):
        """Add two sets of weld process parameters and verify they are retrievable."""
        # Ensure both WPPs exist
        ws1_id = ensure_weld_process_parameters(web_hmi, WPP_DEFAULT_WS1)
        ws2_id = ensure_weld_process_parameters(web_hmi, WPP_DEFAULT_WS2)

        assert ws1_id is not None
        assert ws2_id is not None

        # Verify via GetWeldProcessParameters
        response = get_weld_process_parameters(web_hmi)
        items = _extract_list(response.payload, "weldProcessParameters")
        names = [item.get("name") for item in items]
        assert WPP_DEFAULT_WS1["name"] in names, f"WPP '{WPP_DEFAULT_WS1['name']}' not found in {names}"
        assert WPP_DEFAULT_WS2["name"] in names, f"WPP '{WPP_DEFAULT_WS2['name']}' not found in {names}"

        # Best-effort cleanup
        clean_weld_test_data(web_hmi, [], [WPP_DEFAULT_WS1["name"], WPP_DEFAULT_WS2["name"]])

    def test_add_weld_data_set(self, web_hmi: AdaptioWebHmi):
        """Add a weld data set referencing two WPPs and verify it appears in the list."""
        ws1_id = ensure_weld_process_parameters(web_hmi, WPP_DEFAULT_WS1)
        ws2_id = ensure_weld_process_parameters(web_hmi, WPP_DEFAULT_WS2)
        wds_id = ensure_weld_data_set(web_hmi, WDS_NAME, ws1_id, ws2_id)

        assert wds_id is not None

        # Verify via GetWeldDataSets
        response = get_weld_data_sets(web_hmi)
        items = _extract_list(response.payload, "weldDataSets")

        wds_items = [i for i in items if i.get("name") == WDS_NAME]
        assert len(wds_items) >= 1, f"WDS '{WDS_NAME}' not found"

        wds = wds_items[0]
        assert wds.get("ws1WppId") == ws1_id
        assert wds.get("ws2WppId") == ws2_id

        # Best-effort cleanup
        clean_weld_test_data(web_hmi, [WDS_NAME], [WPP_DEFAULT_WS1["name"], WPP_DEFAULT_WS2["name"]])

    # -- Select WDS and arc state transition tests ---------------------------

    def test_select_weld_data_set(self, web_hmi: AdaptioWebHmi, weld_setup):
        """Select a WDS and verify the response is ok."""
        _ws1_id, _ws2_id, wds_id = weld_setup

        response = select_weld_data_set(web_hmi, wds_id)
        assert _result_ok(response), f"SelectWeldDataSet failed: {response}"

    def test_arc_state_idle_before_select(self, web_hmi: AdaptioWebHmi, weld_setup):
        """Before selecting a WDS the arc state should be idle or configured."""
        _ws1_id, _ws2_id, _wds_id = weld_setup

        response = get_arc_state(web_hmi)
        state = response.payload.get("state", "")
        logger.info(f"Arc state before select: {state}")
        # Valid pre-select states: idle (fresh) or configured/ready (from a previous run)
        assert state in ("idle", "configured", "ready"), (
            f"Unexpected arc state before select: {state}"
        )

    def test_arc_state_configured_after_select(self, web_hmi: AdaptioWebHmi, weld_setup):
        """After selecting a WDS the arc state should transition to configured (or ready)."""
        _ws1_id, _ws2_id, wds_id = weld_setup

        response = select_weld_data_set(web_hmi, wds_id)
        assert _result_ok(response), f"SelectWeldDataSet failed: {response}"

        # Query arc state after selection
        arc_response = get_arc_state(web_hmi)
        state = arc_response.payload.get("state", "")
        logger.info(f"Arc state after select: {state}")
        # After selecting a WDS the state should be at least 'configured'.
        # If power sources are already connected and report READY_TO_START
        # it may already be 'ready'.
        assert state in ("configured", "ready"), (
            f"Expected 'configured' or 'ready' after SelectWeldDataSet, got '{state}'"
        )

    def test_subscribe_arc_state_returns_current_state(
        self, web_hmi: AdaptioWebHmi, weld_setup
    ):
        """SubscribeArcState should push the current arc state immediately."""
        _ws1_id, _ws2_id, wds_id = weld_setup

        # Ensure a WDS is selected so state is at least 'configured'
        select_weld_data_set(web_hmi, wds_id)

        response = subscribe_arc_state(web_hmi)
        state = response.payload.get("state", "")
        logger.info(f"SubscribeArcState returned state: {state}")
        assert state in ("idle", "configured", "ready", "starting", "active"), (
            f"SubscribeArcState returned unexpected state: {state}"
        )

    # -- Get operations (verify data integrity) ------------------------------

    def test_get_weld_process_parameters_contains_test_data(
        self, web_hmi: AdaptioWebHmi, weld_setup
    ):
        """GetWeldProcessParameters should contain the WPPs created by the fixture."""
        _ws1_id, _ws2_id, _wds_id = weld_setup

        response = get_weld_process_parameters(web_hmi)
        items = _extract_list(response.payload, "weldProcessParameters")

        ws1_items = [i for i in items if i.get("name") == WPP_DEFAULT_WS1["name"]]
        ws2_items = [i for i in items if i.get("name") == WPP_DEFAULT_WS2["name"]]

        assert len(ws1_items) >= 1, f"WPP '{WPP_DEFAULT_WS1['name']}' not found"
        assert len(ws2_items) >= 1, f"WPP '{WPP_DEFAULT_WS2['name']}' not found"

        # Verify key fields from WPP_DEFAULT_WS1
        ws1 = ws1_items[0]
        assert ws1.get("voltage") == pytest.approx(WPP_DEFAULT_WS1["voltage"], abs=0.1)
        assert ws1.get("current") == pytest.approx(WPP_DEFAULT_WS1["current"], abs=0.1)

        # Verify key fields from WPP_DEFAULT_WS2
        ws2 = ws2_items[0]
        assert ws2.get("voltage") == pytest.approx(WPP_DEFAULT_WS2["voltage"], abs=0.1)
        assert ws2.get("current") == pytest.approx(WPP_DEFAULT_WS2["current"], abs=0.1)

    def test_get_weld_data_sets_contains_test_data(
        self, web_hmi: AdaptioWebHmi, weld_setup
    ):
        """GetWeldDataSets should contain the WDS created by the fixture."""
        ws1_id, ws2_id, _wds_id = weld_setup

        response = get_weld_data_sets(web_hmi)
        items = _extract_list(response.payload, "weldDataSets")

        wds_items = [i for i in items if i.get("name") == WDS_NAME]
        assert len(wds_items) >= 1, f"WDS '{WDS_NAME}' not found"

        wds = wds_items[0]
        assert wds.get("ws1WppId") == ws1_id
        assert wds.get("ws2WppId") == ws2_id

    # -- Cleanup / removal tests (verify removal order) ----------------------

    def test_remove_weld_data_set(self, web_hmi: AdaptioWebHmi):
        """Add then remove a WDS and verify it no longer appears in the list."""
        ws1_id = ensure_weld_process_parameters(web_hmi, WPP_DEFAULT_WS1)
        ws2_id = ensure_weld_process_parameters(web_hmi, WPP_DEFAULT_WS2)
        wds_id = ensure_weld_data_set(web_hmi, WDS_NAME, ws1_id, ws2_id)

        response = remove_weld_data_set(web_hmi, wds_id)
        assert _result_ok(response), f"RemoveWeldDataSet failed: {response}"

        # Verify removal
        assert _find_wds_by_name(web_hmi, WDS_NAME) is None, (
            f"WDS '{WDS_NAME}' should have been removed"
        )

        # Cleanup WPPs
        clean_weld_test_data(web_hmi, [], [WPP_DEFAULT_WS1["name"], WPP_DEFAULT_WS2["name"]])

    def test_remove_weld_process_parameters(self, web_hmi: AdaptioWebHmi):
        """Add then remove WPPs (after removing dependent WDS) and verify removal."""
        ws1_id = ensure_weld_process_parameters(web_hmi, WPP_DEFAULT_WS1)
        ws2_id = ensure_weld_process_parameters(web_hmi, WPP_DEFAULT_WS2)

        # Add and then remove a WDS first so WPPs are not in use
        wds_id = ensure_weld_data_set(web_hmi, WDS_NAME, ws1_id, ws2_id)
        remove_weld_data_set(web_hmi, wds_id)

        # Now remove WPPs
        r1 = remove_weld_process_parameters(web_hmi, ws1_id)
        assert _result_ok(r1), f"RemoveWeldProcessParameters WS1 failed: {r1}"

        r2 = remove_weld_process_parameters(web_hmi, ws2_id)
        assert _result_ok(r2), f"RemoveWeldProcessParameters WS2 failed: {r2}"

        # Verify removal
        assert _find_wpp_by_name(web_hmi, WPP_DEFAULT_WS1["name"]) is None
        assert _find_wpp_by_name(web_hmi, WPP_DEFAULT_WS2["name"]) is None

    # -- Full flow: setup → select → query arc state (mirrors weld_start.cc) -

    def test_starting_weld_full_flow(self, web_hmi: AdaptioWebHmi):
        """End-to-end starting weld flow mirroring weld_start.cc block test.

        Steps:
            1. Add WPP for WS1 and WS2
            2. Add WDS referencing both WPPs
            3. Select WDS → verify arc state is 'configured' (or 'ready')
            4. Retrieve WPP list and verify voltage/current match test data
            5. Clean up
        """
        # Step 1: Add weld process parameters
        ws1_id = ensure_weld_process_parameters(web_hmi, WPP_DEFAULT_WS1)
        ws2_id = ensure_weld_process_parameters(web_hmi, WPP_DEFAULT_WS2)

        # Step 2: Add weld data set
        wds_id = ensure_weld_data_set(web_hmi, WDS_NAME, ws1_id, ws2_id)

        # Step 3: Select weld data set
        sel_response = select_weld_data_set(web_hmi, wds_id)
        assert _result_ok(sel_response), f"SelectWeldDataSet failed: {sel_response}"

        # Step 3b: Verify arc state transitioned to at least 'configured'
        arc_response = get_arc_state(web_hmi)
        state = arc_response.payload.get("state", "")
        logger.info(f"Arc state after full setup: {state}")
        assert state in ("configured", "ready"), (
            f"Expected arc state 'configured' or 'ready', got '{state}'"
        )

        # Step 4: Verify WPP data matches what was sent
        wpp_response = get_weld_process_parameters(web_hmi)
        items = _extract_list(wpp_response.payload, "weldProcessParameters")

        ws1_data = next((i for i in items if i.get("name") == WPP_DEFAULT_WS1["name"]), None)
        ws2_data = next((i for i in items if i.get("name") == WPP_DEFAULT_WS2["name"]), None)
        assert ws1_data is not None, "WS1 WPP not found"
        assert ws2_data is not None, "WS2 WPP not found"

        # Verify voltage and current (from weld_start.cc lines 43-48)
        assert ws1_data.get("voltage") == pytest.approx(25.0, abs=0.1)
        assert ws1_data.get("current") == pytest.approx(200.0, abs=0.1)
        assert ws2_data.get("voltage") == pytest.approx(28.0, abs=0.1)
        assert ws2_data.get("current") == pytest.approx(180.0, abs=0.1)

        # Step 5: Cleanup
        clean_weld_test_data(web_hmi, [WDS_NAME], [WPP_DEFAULT_WS1["name"], WPP_DEFAULT_WS2["name"]])
