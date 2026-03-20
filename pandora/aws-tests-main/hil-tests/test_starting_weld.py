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

import pytest
from loguru import logger

from conftest import (
    send_message,
    receive_by_name,
    send_and_receive,
    WPP_DEFAULT_WS1,
    WPP_DEFAULT_WS2,
    get_weld_process_parameters,
    add_weld_process_parameters,
    update_weld_process_parameters,
    remove_weld_process_parameters,
    get_weld_data_sets,
    add_weld_data_set,
    update_weld_data_set,
    remove_weld_data_set,
    select_weld_data_set,
    clean_weld_data,
)


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
    """Test CRUD operations after the database file has been deleted and
    recreated by restarting Adaptio.

    Adaptio uses ``SQLite::OPEN_CREATE`` in ``main.cc``, so when the
    ``data.db3`` file is missing at startup a fresh database is created
    automatically.  The ``ensure_fresh_db`` fixture (modelled after the
    ``update_adaptio_config`` pattern used in ``test_joint_tracking.py``)
    takes care of the stop → delete → start cycle and yields a connected
    ``AdaptioWebHmi`` client.
    """

    def test_add_wpp_after_db_recreation(self, ensure_fresh_db):
        """After deleting and recreating the database, adding WPPs must work."""
        web_hmi = ensure_fresh_db

        wpp_list = get_weld_process_parameters(web_hmi)
        assert isinstance(wpp_list, list)
        assert len(wpp_list) == 0

        rsp = add_weld_process_parameters(web_hmi, WPP_DEFAULT_WS1)
        assert rsp.get("result") == "ok"

        wpp_list = get_weld_process_parameters(web_hmi)
        assert len(wpp_list) == 1
        assert wpp_list[0]["name"] == "ManualWS1"

    def test_full_crud_cycle_after_db_recreation(self, ensure_fresh_db):
        """Full CRUD cycle on a freshly-created database: add → select → update → clean."""
        web_hmi = ensure_fresh_db

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

    def test_wds_cleanup_order_after_db_recreation(self, ensure_fresh_db):
        """On a fresh database, WDS must be removed before WPP."""
        web_hmi = ensure_fresh_db

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
