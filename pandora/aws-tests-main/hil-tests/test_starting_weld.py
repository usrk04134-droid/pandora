"""HIL test cases for starting weld – weld data handling and arc state.

Covers CRUD operations for Weld Process Parameters (WPP) and Weld Data Sets
(WDS), arc-state subscription / query, weld-data-set selection, and
database-recreation scenarios.

Reference:
    - sysfun-welddata-handling.md (use-case specification)
    - adaptio-gen_2_ms3/src/block_tests/manual_weld_test.cc (unit-level arc
      state machine tests)
    - adaptio-gen_2_ms3/src/block_tests/weld_start.cc (manual weld start)
"""

import json
from typing import Any

import pytest
from loguru import logger

from testzilla.adaptio_web_hmi.adaptio_web_hmi import (
    AdaptioWebHmi,
    AdaptioWebHmiMessage,
)
from testzilla.utility.cleanup_utils import cleanup_web_hmi_client


# ---------------------------------------------------------------------------
# Raw websocket message helpers
# ---------------------------------------------------------------------------

def send_message(web_hmi: AdaptioWebHmi, name: str, payload: dict | None = None) -> None:
    """Send a JSON message over the websocket."""
    msg = AdaptioWebHmiMessage(name=name, payload=payload or {})
    web_hmi.send_message(msg)


def receive_by_name(web_hmi: AdaptioWebHmi, name: str, max_retries: int = 10) -> dict:
    """Receive the next message matching *name* and return it as a plain dict.

    Using raw ``json.loads`` instead of ``AdaptioWebHmiMessage`` avoids
    Pydantic validation failures when the server response contains a list
    payload or omits the ``payload`` key on failure.
    """
    web_hmi.connect()
    for _ in range(max_retries):
        raw = web_hmi.ws_client.receive_message()
        data = json.loads(raw)
        if data.get("name") == name:
            return data
    raise TimeoutError(f"Did not receive '{name}' within {max_retries} attempts")


def send_and_receive(
    web_hmi: AdaptioWebHmi,
    request_name: str,
    response_name: str,
    payload: dict | None = None,
    max_retries: int = 10,
) -> dict:
    """Send a request and wait for the matching response (as a raw dict)."""
    send_message(web_hmi, request_name, payload)
    return receive_by_name(web_hmi, response_name, max_retries=max_retries)


# ---------------------------------------------------------------------------
# Default weld process parameter payloads (mirror C++ block-test data)
# ---------------------------------------------------------------------------

WPP_DEFAULT_WS1: dict[str, Any] = {
    "name": "ManualWS1",
    "method": "dc",
    "regulationType": "cc",
    "startAdjust": 10,
    "startType": "scratch",
    "voltage": 25.0,
    "current": 200.0,
    "wireSpeed": 15.0,
    "iceWireSpeed": 0.0,
    "acFrequency": 60.0,
    "acOffset": 1.2,
    "acPhaseShift": 0.5,
    "craterFillTime": 2.0,
    "burnBackTime": 1.0,
}

WPP_DEFAULT_WS2: dict[str, Any] = {
    "name": "ManualWS2",
    "method": "dc",
    "regulationType": "cc",
    "startAdjust": 10,
    "startType": "direct",
    "voltage": 28.0,
    "current": 180.0,
    "wireSpeed": 14.0,
    "iceWireSpeed": 0.0,
    "acFrequency": 60.0,
    "acOffset": 1.2,
    "acPhaseShift": 0.5,
    "craterFillTime": 2.0,
    "burnBackTime": 1.0,
}

# ---------------------------------------------------------------------------
# CRUD helper functions
# ---------------------------------------------------------------------------


def get_weld_process_parameters(web_hmi: AdaptioWebHmi) -> list[dict]:
    """Return the list of stored weld process parameters."""
    rsp = send_and_receive(web_hmi, "GetWeldProcessParameters", "GetWeldProcessParametersRsp")
    return rsp.get("payload", [])


def add_weld_process_parameters(web_hmi: AdaptioWebHmi, params: dict) -> dict:
    """Add a weld process parameter set.  Returns the full response dict."""
    return send_and_receive(web_hmi, "AddWeldProcessParameters", "AddWeldProcessParametersRsp", params)


def update_weld_process_parameters(web_hmi: AdaptioWebHmi, wpp_id: int, params: dict) -> dict:
    """Update a weld process parameter set.  Returns the full response dict."""
    payload = {**params, "id": wpp_id}
    return send_and_receive(web_hmi, "UpdateWeldProcessParameters", "UpdateWeldProcessParametersRsp", payload)


def remove_weld_process_parameters(web_hmi: AdaptioWebHmi, wpp_id: int) -> dict:
    """Remove a weld process parameter set.  Returns the full response dict."""
    return send_and_receive(
        web_hmi, "RemoveWeldProcessParameters", "RemoveWeldProcessParametersRsp", {"id": wpp_id}
    )


def get_weld_data_sets(web_hmi: AdaptioWebHmi) -> list[dict]:
    """Return the list of stored weld data sets."""
    rsp = send_and_receive(web_hmi, "GetWeldDataSets", "GetWeldDataSetsRsp")
    return rsp.get("payload", [])


def add_weld_data_set(web_hmi: AdaptioWebHmi, name: str, ws1_wpp_id: int, ws2_wpp_id: int) -> dict:
    """Add a weld data set.  Returns the full response dict."""
    payload = {"name": name, "ws1WppId": ws1_wpp_id, "ws2WppId": ws2_wpp_id}
    return send_and_receive(web_hmi, "AddWeldDataSet", "AddWeldDataSetRsp", payload)


def update_weld_data_set(
    web_hmi: AdaptioWebHmi, wds_id: int, name: str, ws1_wpp_id: int, ws2_wpp_id: int
) -> dict:
    """Update a weld data set.  Returns the full response dict."""
    payload = {"id": wds_id, "name": name, "ws1WppId": ws1_wpp_id, "ws2WppId": ws2_wpp_id}
    return send_and_receive(web_hmi, "UpdateWeldDataSet", "UpdateWeldDataSetRsp", payload)


def remove_weld_data_set(web_hmi: AdaptioWebHmi, wds_id: int) -> dict:
    """Remove a weld data set.  Returns the full response dict."""
    return send_and_receive(web_hmi, "RemoveWeldDataSet", "RemoveWeldDataSetRsp", {"id": wds_id})


def select_weld_data_set(web_hmi: AdaptioWebHmi, wds_id: int) -> dict:
    """Select a weld data set.  Returns the full response dict."""
    return send_and_receive(web_hmi, "SelectWeldDataSet", "SelectWeldDataSetRsp", {"id": wds_id})


def get_weld_programs(web_hmi: AdaptioWebHmi) -> list[dict]:
    """Return the list of stored weld programs."""
    rsp = send_and_receive(web_hmi, "GetWeldPrograms", "GetWeldProgramsRsp")
    return rsp.get("payload", [])


def remove_weld_program(web_hmi: AdaptioWebHmi, prog_id: int) -> dict:
    """Remove a weld program.  Returns the full response dict."""
    return send_and_receive(web_hmi, "RemoveWeldProgram", "RemoveWeldProgramRsp", {"id": prog_id})


# ---------------------------------------------------------------------------
# Clean-up helpers
# ---------------------------------------------------------------------------

def clean_weld_data(web_hmi: AdaptioWebHmi) -> None:
    """Remove **all** weld programs, weld data sets, and weld process parameters.

    Removal order matters:
      WeldPrograms → WeldDataSets → WeldProcessParameters
    The adaptio module prevents removal of a WDS used by a program and of a
    WPP used by a WDS.
    """
    # 1. Remove weld programs
    for prog in get_weld_programs(web_hmi):
        prog_id = prog.get("id")
        if prog_id is not None:
            rsp = remove_weld_program(web_hmi, prog_id)
            logger.debug(f"Removed WeldProgram id={prog_id}: {rsp.get('result')}")

    # 2. Remove weld data sets
    for wds in get_weld_data_sets(web_hmi):
        wds_id = wds.get("id")
        if wds_id is not None:
            rsp = remove_weld_data_set(web_hmi, wds_id)
            logger.debug(f"Removed WDS id={wds_id}: {rsp.get('result')}")

    # 3. Remove weld process parameters
    for wpp in get_weld_process_parameters(web_hmi):
        wpp_id = wpp.get("id")
        if wpp_id is not None:
            rsp = remove_weld_process_parameters(web_hmi, wpp_id)
            logger.debug(f"Removed WPP id={wpp_id}: {rsp.get('result')}")


def ensure_weld_process_parameters(web_hmi: AdaptioWebHmi, params: dict) -> int:
    """Ensure a WPP with the given *name* exists.  Returns its id.

    If a WPP with the same name already exists it is updated; otherwise a
    new one is added.  Using upsert avoids SQLite auto-increment ID growth
    across repeated test runs on a persistent device database.
    """
    existing = get_weld_process_parameters(web_hmi)
    for wpp in existing:
        if wpp.get("name") == params.get("name"):
            wpp_id = wpp["id"]
            update_weld_process_parameters(web_hmi, wpp_id, params)
            return wpp_id

    add_weld_process_parameters(web_hmi, params)
    updated = get_weld_process_parameters(web_hmi)
    for wpp in updated:
        if wpp.get("name") == params.get("name"):
            return wpp["id"]
    raise RuntimeError(f"Failed to ensure WPP with name={params.get('name')}")


def ensure_weld_data_set(
    web_hmi: AdaptioWebHmi, name: str, ws1_wpp_id: int, ws2_wpp_id: int
) -> int:
    """Ensure a WDS with the given *name* exists.  Returns its id."""
    existing = get_weld_data_sets(web_hmi)
    for wds in existing:
        if wds.get("name") == name:
            wds_id = wds["id"]
            update_weld_data_set(web_hmi, wds_id, name, ws1_wpp_id, ws2_wpp_id)
            return wds_id

    add_weld_data_set(web_hmi, name, ws1_wpp_id, ws2_wpp_id)
    updated = get_weld_data_sets(web_hmi)
    for wds in updated:
        if wds.get("name") == name:
            return wds["id"]
    raise RuntimeError(f"Failed to ensure WDS with name={name}")


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture(name="web_hmi")
def web_hmi_fixture(request: pytest.FixtureRequest):
    """Provide an AdaptioWebHmi client connected to the device."""
    uri = request.config.WEB_HMI_URI
    client = AdaptioWebHmi(uri=uri)
    try:
        client.connect()
    except Exception:
        pytest.skip("Could not connect to Adaptio WebHMI")

    yield client

    cleanup_web_hmi_client(client)


@pytest.fixture(name="clean_weld_state")
def clean_weld_state_fixture(web_hmi: AdaptioWebHmi):
    """Remove all weld data before and after the test."""
    try:
        clean_weld_data(web_hmi)
    except Exception:
        pytest.skip("Could not clean weld data")

    yield

    try:
        clean_weld_data(web_hmi)
    except Exception:
        logger.warning("Post-test weld data cleanup failed")


@pytest.fixture(name="seeded_weld_data")
def seeded_weld_data_fixture(web_hmi: AdaptioWebHmi, clean_weld_state):
    """Ensure two WPPs and one WDS exist.

    Returns:
        tuple[int, int, int]: (ws1_id, ws2_id, wds_id)
    """
    try:
        ws1_id = ensure_weld_process_parameters(web_hmi, WPP_DEFAULT_WS1)
        ws2_id = ensure_weld_process_parameters(web_hmi, WPP_DEFAULT_WS2)
        wds_id = ensure_weld_data_set(web_hmi, "TestWeld", ws1_id, ws2_id)
    except Exception:
        pytest.skip("Could not seed weld data")

    return ws1_id, ws2_id, wds_id


# ============================================================================
# Test Classes
# ============================================================================

@pytest.mark.weld
@pytest.mark.weld_process_parameters
class TestWeldProcessParametersCRUD:
    """CRUD operations for Weld Process Parameters via WebHMI."""

    def test_get_weld_process_parameters_empty(self, web_hmi, clean_weld_state):
        """After cleanup the WPP list should be empty."""
        wpp_list = get_weld_process_parameters(web_hmi)
        assert isinstance(wpp_list, list)
        assert len(wpp_list) == 0

    def test_add_weld_process_parameters(self, web_hmi, clean_weld_state):
        """Add a single WPP and verify it appears in the list."""
        rsp = add_weld_process_parameters(web_hmi, WPP_DEFAULT_WS1)
        assert rsp.get("result") == "ok"

        wpp_list = get_weld_process_parameters(web_hmi)
        assert len(wpp_list) == 1
        assert wpp_list[0]["name"] == "ManualWS1"
        assert wpp_list[0]["voltage"] == pytest.approx(25.0)
        assert wpp_list[0]["current"] == pytest.approx(200.0)

    def test_add_multiple_weld_process_parameters(self, web_hmi, clean_weld_state):
        """Add two WPPs and verify both appear."""
        rsp1 = add_weld_process_parameters(web_hmi, WPP_DEFAULT_WS1)
        rsp2 = add_weld_process_parameters(web_hmi, WPP_DEFAULT_WS2)
        assert rsp1.get("result") == "ok"
        assert rsp2.get("result") == "ok"

        wpp_list = get_weld_process_parameters(web_hmi)
        assert len(wpp_list) == 2
        names = {w["name"] for w in wpp_list}
        assert names == {"ManualWS1", "ManualWS2"}

    def test_update_weld_process_parameters(self, web_hmi, clean_weld_state):
        """Add a WPP, update its voltage, and verify the change."""
        add_weld_process_parameters(web_hmi, WPP_DEFAULT_WS1)
        wpp_list = get_weld_process_parameters(web_hmi)
        wpp_id = wpp_list[0]["id"]

        updated = {**WPP_DEFAULT_WS1, "name": "UpdatedWS1", "voltage": 30.0}
        rsp = update_weld_process_parameters(web_hmi, wpp_id, updated)
        assert rsp.get("result") == "ok"

        wpp_list = get_weld_process_parameters(web_hmi)
        assert len(wpp_list) == 1
        assert wpp_list[0]["name"] == "UpdatedWS1"
        assert wpp_list[0]["voltage"] == pytest.approx(30.0)

    def test_remove_weld_process_parameters(self, web_hmi, clean_weld_state):
        """Add and then remove a WPP."""
        add_weld_process_parameters(web_hmi, WPP_DEFAULT_WS1)
        wpp_list = get_weld_process_parameters(web_hmi)
        wpp_id = wpp_list[0]["id"]

        rsp = remove_weld_process_parameters(web_hmi, wpp_id)
        assert rsp.get("result") == "ok"

        wpp_list = get_weld_process_parameters(web_hmi)
        assert len(wpp_list) == 0

    def test_remove_nonexistent_weld_process_parameters(self, web_hmi, clean_weld_state):
        """Removing a non-existent WPP should fail."""
        rsp = remove_weld_process_parameters(web_hmi, 99999)
        assert rsp.get("result") == "fail"


@pytest.mark.weld
@pytest.mark.weld_data_set
class TestWeldDataSetCRUD:
    """CRUD operations for Weld Data Sets via WebHMI."""

    def test_get_weld_data_sets_empty(self, web_hmi, clean_weld_state):
        """After cleanup the WDS list should be empty."""
        wds_list = get_weld_data_sets(web_hmi)
        assert isinstance(wds_list, list)
        assert len(wds_list) == 0

    def test_add_weld_data_set(self, web_hmi, clean_weld_state):
        """Add two WPPs and one WDS referencing them."""
        rsp1 = add_weld_process_parameters(web_hmi, WPP_DEFAULT_WS1)
        rsp2 = add_weld_process_parameters(web_hmi, WPP_DEFAULT_WS2)
        assert rsp1.get("result") == "ok"
        assert rsp2.get("result") == "ok"

        wpp_list = get_weld_process_parameters(web_hmi)
        ws1_id = next(w["id"] for w in wpp_list if w["name"] == "ManualWS1")
        ws2_id = next(w["id"] for w in wpp_list if w["name"] == "ManualWS2")

        rsp = add_weld_data_set(web_hmi, "TestRoot", ws1_id, ws2_id)
        assert rsp.get("result") == "ok"

        wds_list = get_weld_data_sets(web_hmi)
        assert len(wds_list) == 1
        assert wds_list[0]["name"] == "TestRoot"
        assert wds_list[0]["ws1WppId"] == ws1_id
        assert wds_list[0]["ws2WppId"] == ws2_id

    def test_add_weld_data_set_with_invalid_wpp(self, web_hmi, clean_weld_state):
        """Adding a WDS with non-existent WPP ids should fail."""
        rsp = add_weld_data_set(web_hmi, "InvalidWDS", 99999, 99998)
        assert rsp.get("result") == "fail"

    def test_update_weld_data_set(self, web_hmi, clean_weld_state):
        """Add WPPs and a WDS, then update the WDS name and swap WPP refs."""
        add_weld_process_parameters(web_hmi, WPP_DEFAULT_WS1)
        add_weld_process_parameters(web_hmi, WPP_DEFAULT_WS2)
        wpp_list = get_weld_process_parameters(web_hmi)
        ws1_id = next(w["id"] for w in wpp_list if w["name"] == "ManualWS1")
        ws2_id = next(w["id"] for w in wpp_list if w["name"] == "ManualWS2")

        add_weld_data_set(web_hmi, "TestRoot", ws1_id, ws2_id)
        wds_list = get_weld_data_sets(web_hmi)
        wds_id = wds_list[0]["id"]

        rsp = update_weld_data_set(web_hmi, wds_id, "UpdatedRoot", ws2_id, ws1_id)
        assert rsp.get("result") == "ok"

        wds_list = get_weld_data_sets(web_hmi)
        assert len(wds_list) == 1
        assert wds_list[0]["name"] == "UpdatedRoot"

    def test_remove_weld_data_set(self, web_hmi, clean_weld_state):
        """Add and then remove a WDS."""
        add_weld_process_parameters(web_hmi, WPP_DEFAULT_WS1)
        add_weld_process_parameters(web_hmi, WPP_DEFAULT_WS2)
        wpp_list = get_weld_process_parameters(web_hmi)
        ws1_id = next(w["id"] for w in wpp_list if w["name"] == "ManualWS1")
        ws2_id = next(w["id"] for w in wpp_list if w["name"] == "ManualWS2")

        add_weld_data_set(web_hmi, "TestRoot", ws1_id, ws2_id)
        wds_list = get_weld_data_sets(web_hmi)
        wds_id = wds_list[0]["id"]

        rsp = remove_weld_data_set(web_hmi, wds_id)
        assert rsp.get("result") == "ok"

        wds_list = get_weld_data_sets(web_hmi)
        assert len(wds_list) == 0

    def test_remove_nonexistent_weld_data_set(self, web_hmi, clean_weld_state):
        """Removing a non-existent WDS should fail."""
        rsp = remove_weld_data_set(web_hmi, 99999)
        assert rsp.get("result") == "fail"

    def test_cannot_remove_wpp_used_by_wds(self, web_hmi, clean_weld_state):
        """A WPP referenced by a WDS cannot be removed."""
        add_weld_process_parameters(web_hmi, WPP_DEFAULT_WS1)
        add_weld_process_parameters(web_hmi, WPP_DEFAULT_WS2)
        wpp_list = get_weld_process_parameters(web_hmi)
        ws1_id = next(w["id"] for w in wpp_list if w["name"] == "ManualWS1")
        ws2_id = next(w["id"] for w in wpp_list if w["name"] == "ManualWS2")

        add_weld_data_set(web_hmi, "TestRoot", ws1_id, ws2_id)

        rsp = remove_weld_process_parameters(web_hmi, ws1_id)
        assert rsp.get("result") == "fail"

    def test_select_weld_data_set(self, web_hmi, clean_weld_state):
        """Select a WDS and verify success."""
        add_weld_process_parameters(web_hmi, WPP_DEFAULT_WS1)
        add_weld_process_parameters(web_hmi, WPP_DEFAULT_WS2)
        wpp_list = get_weld_process_parameters(web_hmi)
        ws1_id = next(w["id"] for w in wpp_list if w["name"] == "ManualWS1")
        ws2_id = next(w["id"] for w in wpp_list if w["name"] == "ManualWS2")

        add_weld_data_set(web_hmi, "TestRoot", ws1_id, ws2_id)
        wds_list = get_weld_data_sets(web_hmi)
        wds_id = wds_list[0]["id"]

        rsp = select_weld_data_set(web_hmi, wds_id)
        assert rsp.get("result") == "ok"

    def test_select_nonexistent_weld_data_set(self, web_hmi, clean_weld_state):
        """Selecting a non-existent WDS should fail."""
        rsp = select_weld_data_set(web_hmi, 99999)
        assert rsp.get("result") == "fail"


@pytest.mark.weld
class TestArcStateHandling:
    """Arc state subscription and transitions via WebHMI.

    The arc state machine is:
        IDLE → CONFIGURED (after SelectWeldDataSet)
             → READY      (when power sources report READY_TO_START)
             → STARTING   (after start button)
             → ACTIVE     (when at least one power source is ARCING)

    In the HIL test environment we can verify the first two transitions
    because they are triggered entirely through WebHMI messages.  The later
    transitions require physical button presses and real power-source
    hardware and are covered by block tests (manual_weld_test.cc).
    """

    def test_get_arc_state(self, web_hmi, clean_weld_state):
        """GetArcState should return the current arc state."""
        rsp = send_and_receive(web_hmi, "GetArcState", "GetArcStateRsp")
        assert rsp.get("result") == "ok"
        state = rsp.get("payload", {}).get("state")
        assert state is not None
        assert state in ("idle", "configured", "ready", "starting", "active")

    def test_subscribe_arc_state(self, web_hmi, clean_weld_state):
        """SubscribeArcState should push the current state immediately."""
        send_message(web_hmi, "SubscribeArcState")
        arc_state_msg = receive_by_name(web_hmi, "ArcState")
        state = arc_state_msg.get("payload", {}).get("state")
        assert state == "idle"

    def test_select_wds_transitions_arc_state_to_configured(self, web_hmi, seeded_weld_data):
        """After selecting a WDS the arc state should become 'configured'.

        If the real power sources happen to be in READY_TO_START the state
        may jump directly to 'ready'; both are accepted.
        """
        _, _, wds_id = seeded_weld_data

        # Subscribe to receive push notifications
        send_message(web_hmi, "SubscribeArcState")
        initial = receive_by_name(web_hmi, "ArcState")
        logger.info(f"Initial arc state: {initial}")

        # Select the weld data set → triggers CONFIGURED transition
        rsp = select_weld_data_set(web_hmi, wds_id)
        assert rsp.get("result") == "ok"

        # The device should push an ArcState update
        arc_state_msg = receive_by_name(web_hmi, "ArcState")
        state = arc_state_msg.get("payload", {}).get("state")
        assert state in ("configured", "ready"), (
            f"Expected 'configured' or 'ready', got '{state}'"
        )

    def test_select_nonexistent_wds_keeps_arc_state_idle(self, web_hmi, clean_weld_state):
        """Selecting a non-existent WDS should not change the arc state."""
        send_message(web_hmi, "SubscribeArcState")
        initial = receive_by_name(web_hmi, "ArcState")
        assert initial.get("payload", {}).get("state") == "idle"

        rsp = select_weld_data_set(web_hmi, 99999)
        assert rsp.get("result") == "fail"

        # Arc state should still be idle
        rsp = send_and_receive(web_hmi, "GetArcState", "GetArcStateRsp")
        assert rsp.get("payload", {}).get("state") == "idle"


@pytest.mark.weld
class TestWeldDataHandlingWithDatabaseRecreation:
    """Test CRUD operations with database clean-up (recreation) in between.

    This verifies that weld data can be fully removed and re-created within
    the same session, exercising the database write path repeatedly.
    """

    def test_add_wpp_clean_and_readd(self, web_hmi, clean_weld_state):
        """Add WPPs, clean the database, and re-add them."""
        # First round
        rsp = add_weld_process_parameters(web_hmi, WPP_DEFAULT_WS1)
        assert rsp.get("result") == "ok"
        wpp_list = get_weld_process_parameters(web_hmi)
        assert len(wpp_list) == 1

        # Clean
        clean_weld_data(web_hmi)
        wpp_list = get_weld_process_parameters(web_hmi)
        assert len(wpp_list) == 0

        # Re-add
        rsp = add_weld_process_parameters(web_hmi, WPP_DEFAULT_WS1)
        assert rsp.get("result") == "ok"
        wpp_list = get_weld_process_parameters(web_hmi)
        assert len(wpp_list) == 1
        assert wpp_list[0]["name"] == "ManualWS1"

    def test_full_crud_cycle_with_cleanup(self, web_hmi, clean_weld_state):
        """Full CRUD cycle: create → select → update → remove all → recreate."""
        # --- Create ---
        rsp1 = add_weld_process_parameters(web_hmi, WPP_DEFAULT_WS1)
        rsp2 = add_weld_process_parameters(web_hmi, WPP_DEFAULT_WS2)
        assert rsp1.get("result") == "ok"
        assert rsp2.get("result") == "ok"

        wpp_list = get_weld_process_parameters(web_hmi)
        ws1_id = next(w["id"] for w in wpp_list if w["name"] == "ManualWS1")
        ws2_id = next(w["id"] for w in wpp_list if w["name"] == "ManualWS2")

        rsp = add_weld_data_set(web_hmi, "CycleWDS", ws1_id, ws2_id)
        assert rsp.get("result") == "ok"

        wds_list = get_weld_data_sets(web_hmi)
        assert len(wds_list) == 1
        wds_id = wds_list[0]["id"]

        # --- Select ---
        rsp = select_weld_data_set(web_hmi, wds_id)
        assert rsp.get("result") == "ok"

        # --- Update ---
        rsp = update_weld_data_set(web_hmi, wds_id, "CycleWDS_v2", ws2_id, ws1_id)
        assert rsp.get("result") == "ok"
        wds_list = get_weld_data_sets(web_hmi)
        assert wds_list[0]["name"] == "CycleWDS_v2"

        # --- Clean all ---
        clean_weld_data(web_hmi)
        assert len(get_weld_data_sets(web_hmi)) == 0
        assert len(get_weld_process_parameters(web_hmi)) == 0

        # --- Recreate ---
        rsp = add_weld_process_parameters(web_hmi, WPP_DEFAULT_WS1)
        assert rsp.get("result") == "ok"
        wpp_list = get_weld_process_parameters(web_hmi)
        assert len(wpp_list) == 1
        assert wpp_list[0]["name"] == "ManualWS1"

    def test_wds_survives_wpp_cleanup_order(self, web_hmi, clean_weld_state):
        """Verify that WDS is removed before WPP during cleanup, and that
        attempting the wrong order fails gracefully.
        """
        add_weld_process_parameters(web_hmi, WPP_DEFAULT_WS1)
        add_weld_process_parameters(web_hmi, WPP_DEFAULT_WS2)
        wpp_list = get_weld_process_parameters(web_hmi)
        ws1_id = next(w["id"] for w in wpp_list if w["name"] == "ManualWS1")
        ws2_id = next(w["id"] for w in wpp_list if w["name"] == "ManualWS2")

        add_weld_data_set(web_hmi, "OrderTest", ws1_id, ws2_id)

        # Trying to remove WPP while WDS references it should fail
        rsp = remove_weld_process_parameters(web_hmi, ws1_id)
        assert rsp.get("result") == "fail"

        # Using the proper clean_weld_data order should succeed
        clean_weld_data(web_hmi)
        assert len(get_weld_data_sets(web_hmi)) == 0
        assert len(get_weld_process_parameters(web_hmi)) == 0
