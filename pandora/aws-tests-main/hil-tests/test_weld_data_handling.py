"""HIL test cases for weld data handling (Weld Process Parameters and Weld Data Sets)."""

import pytest
from loguru import logger
from concurrent.futures import ThreadPoolExecutor, TimeoutError as FutureTimeout

from testzilla.adaptio_web_hmi.adaptio_web_hmi import AdaptioWebHmi as AdaptioWebHmiClient
from testzilla.utility.cleanup_utils import cleanup_web_hmi_client
from pydantic_core import ValidationError as PydanticCoreValidationError

DEFAULT_TIMEOUT = 30


def run_sync_in_thread(func, *args, timeout=None, **kwargs):
    """Run a blocking function in a separate thread and return its result."""
    with ThreadPoolExecutor(max_workers=1) as ex:
        fut = ex.submit(func, *args, **kwargs)
        try:
            return fut.result(timeout=timeout)
        except FutureTimeout:
            fut.cancel()
            raise TimeoutError("Operation timed out")


def _call_adaptio(uri, method_name, **kwargs):
    """Create an AdaptioWebHmiClient, call the given method, then close it."""
    client = AdaptioWebHmiClient(uri=uri)
    try:
        method = getattr(client, method_name)
        return method(**kwargs)
    except PydanticCoreValidationError as exc:
        raw_input = None
        for err in exc.errors():
            if "input" in err:
                raw_input = err["input"]
                break
        if raw_input is not None:
            logger.warning(f"Received failure response: {raw_input}")
            return raw_input
        raise
    finally:
        cleanup_web_hmi_client(client)


def _get_result(response):
    """Extract 'result' field from an Adaptio response (object or dict)."""
    if isinstance(response, dict):
        return response.get("result")
    return getattr(response, "result", None) or (
        response.payload.get("result") if hasattr(response, "payload") else None
    )


def _get_payload(response):
    """Extract payload dict from an Adaptio response (object or dict)."""
    if isinstance(response, dict):
        return response
    return response.payload if hasattr(response, "payload") else {}


class TestWeldProcessParameters:
    """Test suite for weld process parameter CRUD operations (Adaptio WebHMI API)."""

    WPP_NAME = "test_wpp_hil"
    WPP_NAME_UPDATED = "test_wpp_hil_updated"

    WPP_PAYLOAD = {
        "name": WPP_NAME,
        "method": "dc",
        "regulationType": "cc",
        "startAdjust": 10,
        "startType": "scratch",
        "voltage": 24.5,
        "current": 150.0,
        "wireSpeed": 12.5,
        "iceWireSpeed": 0.0,
        "acFrequency": 60.0,
        "acOffset": 1.2,
        "acPhaseShift": 0.5,
        "craterFillTime": 2.0,
        "burnBackTime": 1.0,
    }

    def _cleanup_wpp_by_name(self, uri, name):
        """Helper to remove any WPP with the given name (best-effort cleanup)."""
        try:
            response = run_sync_in_thread(
                _call_adaptio, uri, "get_weld_process_parameters", timeout=DEFAULT_TIMEOUT
            )
            payload = _get_payload(response)
            entries = payload.get("weldProcessParameters", []) if isinstance(payload, dict) else []
            for entry in entries:
                if entry.get("name") == name:
                    run_sync_in_thread(
                        _call_adaptio, uri, "remove_weld_process_parameters",
                        id=entry["id"], timeout=DEFAULT_TIMEOUT,
                    )
        except Exception as exc:
            logger.warning(f"WPP cleanup for '{name}' failed: {exc}")

    @pytest.fixture(autouse=True)
    def cleanup_wpp(self, request):
        """Remove test WPP entries before and after each test to ensure a clean state."""
        uri = request.config.WEB_HMI_URI
        self._cleanup_wpp_by_name(uri, self.WPP_NAME)
        self._cleanup_wpp_by_name(uri, self.WPP_NAME_UPDATED)
        yield
        self._cleanup_wpp_by_name(uri, self.WPP_NAME)
        self._cleanup_wpp_by_name(uri, self.WPP_NAME_UPDATED)

    def test_add_weld_process_parameters(self, request):
        """Adding weld process parameters with valid data should succeed."""
        uri = request.config.WEB_HMI_URI

        response = run_sync_in_thread(
            _call_adaptio, uri, "add_weld_process_parameters",
            timeout=DEFAULT_TIMEOUT, **self.WPP_PAYLOAD
        )
        logger.debug(f"AddWeldProcessParameters response: {response}")

        result = _get_result(response)
        assert result == "ok", f"Expected 'ok' but got '{result}'"
        logger.info("AddWeldProcessParameters succeeded")

    def test_add_weld_process_parameters_duplicate_name_fails(self, request):
        """Adding weld process parameters with a duplicate name should fail."""
        uri = request.config.WEB_HMI_URI

        # First add should succeed
        first = run_sync_in_thread(
            _call_adaptio, uri, "add_weld_process_parameters",
            timeout=DEFAULT_TIMEOUT, **self.WPP_PAYLOAD
        )
        assert _get_result(first) == "ok", "Initial WPP creation failed unexpectedly"

        # Second add with same name should fail
        second = run_sync_in_thread(
            _call_adaptio, uri, "add_weld_process_parameters",
            timeout=DEFAULT_TIMEOUT, **self.WPP_PAYLOAD
        )
        logger.debug(f"Duplicate AddWeldProcessParameters response: {second}")

        result = _get_result(second)
        assert result != "ok", (
            f"Expected failure when adding WPP with duplicate name '{self.WPP_NAME}', "
            f"but got '{result}'"
        )
        logger.info("Duplicate WPP name correctly rejected")

    def test_get_weld_process_parameters(self, request):
        """GetWeldProcessParameters should return a list that includes the added entry."""
        uri = request.config.WEB_HMI_URI

        # Add a WPP first
        add_resp = run_sync_in_thread(
            _call_adaptio, uri, "add_weld_process_parameters",
            timeout=DEFAULT_TIMEOUT, **self.WPP_PAYLOAD
        )
        assert _get_result(add_resp) == "ok", "Pre-condition: WPP creation failed"

        response = run_sync_in_thread(
            _call_adaptio, uri, "get_weld_process_parameters", timeout=DEFAULT_TIMEOUT
        )
        logger.debug(f"GetWeldProcessParameters response: {response}")

        result = _get_result(response)
        assert result == "ok", f"Expected 'ok' but got '{result}'"

        payload = _get_payload(response)
        entries = payload.get("weldProcessParameters", [])
        assert isinstance(entries, list), "Expected 'weldProcessParameters' to be a list"

        names = [e.get("name") for e in entries]
        assert self.WPP_NAME in names, (
            f"Expected '{self.WPP_NAME}' in WPP list but got: {names}"
        )
        logger.info(f"GetWeldProcessParameters returned {len(entries)} entries including '{self.WPP_NAME}'")

    def test_update_weld_process_parameters(self, request):
        """UpdateWeldProcessParameters should update an existing entry successfully."""
        uri = request.config.WEB_HMI_URI

        # Add a WPP to update
        add_resp = run_sync_in_thread(
            _call_adaptio, uri, "add_weld_process_parameters",
            timeout=DEFAULT_TIMEOUT, **self.WPP_PAYLOAD
        )
        assert _get_result(add_resp) == "ok", "Pre-condition: WPP creation failed"

        # Get list to find the ID
        get_resp = run_sync_in_thread(
            _call_adaptio, uri, "get_weld_process_parameters", timeout=DEFAULT_TIMEOUT
        )
        assert _get_result(get_resp) == "ok", "Pre-condition: GetWeldProcessParameters failed"

        entries = _get_payload(get_resp).get("weldProcessParameters", [])
        wpp = next((e for e in entries if e.get("name") == self.WPP_NAME), None)
        assert wpp is not None, f"Pre-condition: WPP '{self.WPP_NAME}' not found in list"

        updated_payload = {**self.WPP_PAYLOAD, "id": wpp["id"], "name": self.WPP_NAME_UPDATED, "voltage": 26.0}
        response = run_sync_in_thread(
            _call_adaptio, uri, "update_weld_process_parameters",
            timeout=DEFAULT_TIMEOUT, **updated_payload
        )
        logger.debug(f"UpdateWeldProcessParameters response: {response}")

        result = _get_result(response)
        assert result == "ok", f"Expected 'ok' but got '{result}'"
        logger.info("UpdateWeldProcessParameters succeeded")

    def test_update_weld_process_parameters_nonexistent_id_fails(self, request):
        """UpdateWeldProcessParameters with a non-existent ID should fail."""
        uri = request.config.WEB_HMI_URI

        nonexistent_payload = {**self.WPP_PAYLOAD, "id": 999999}
        response = run_sync_in_thread(
            _call_adaptio, uri, "update_weld_process_parameters",
            timeout=DEFAULT_TIMEOUT, **nonexistent_payload
        )
        logger.debug(f"UpdateWeldProcessParameters (bad id) response: {response}")

        result = _get_result(response)
        assert result != "ok", (
            f"Expected failure when updating WPP with non-existent ID, but got '{result}'"
        )
        logger.info("UpdateWeldProcessParameters with non-existent ID correctly rejected")

    def test_remove_weld_process_parameters(self, request):
        """RemoveWeldProcessParameters should remove an existing entry successfully."""
        uri = request.config.WEB_HMI_URI

        # Add a WPP to remove
        add_resp = run_sync_in_thread(
            _call_adaptio, uri, "add_weld_process_parameters",
            timeout=DEFAULT_TIMEOUT, **self.WPP_PAYLOAD
        )
        assert _get_result(add_resp) == "ok", "Pre-condition: WPP creation failed"

        # Find the ID
        get_resp = run_sync_in_thread(
            _call_adaptio, uri, "get_weld_process_parameters", timeout=DEFAULT_TIMEOUT
        )
        entries = _get_payload(get_resp).get("weldProcessParameters", [])
        wpp = next((e for e in entries if e.get("name") == self.WPP_NAME), None)
        assert wpp is not None, f"Pre-condition: WPP '{self.WPP_NAME}' not found"

        response = run_sync_in_thread(
            _call_adaptio, uri, "remove_weld_process_parameters",
            timeout=DEFAULT_TIMEOUT, id=wpp["id"]
        )
        logger.debug(f"RemoveWeldProcessParameters response: {response}")

        result = _get_result(response)
        assert result == "ok", f"Expected 'ok' but got '{result}'"

        # Verify it was removed
        verify_resp = run_sync_in_thread(
            _call_adaptio, uri, "get_weld_process_parameters", timeout=DEFAULT_TIMEOUT
        )
        remaining = _get_payload(verify_resp).get("weldProcessParameters", [])
        names = [e.get("name") for e in remaining]
        assert self.WPP_NAME not in names, (
            f"WPP '{self.WPP_NAME}' still present after removal"
        )
        logger.info("RemoveWeldProcessParameters succeeded")


class TestWeldDataSets:
    """Test suite for weld data set CRUD operations (Adaptio WebHMI API)."""

    WPP_NAME_WS1 = "test_wpp_ws1_hil"
    WPP_NAME_WS2 = "test_wpp_ws2_hil"
    WDS_NAME = "test_wds_hil"
    WDS_NAME_UPDATED = "test_wds_hil_updated"

    WPP_BASE = {
        "method": "dc",
        "regulationType": "cc",
        "startAdjust": 10,
        "startType": "scratch",
        "voltage": 24.5,
        "current": 150.0,
        "wireSpeed": 12.5,
        "iceWireSpeed": 0.0,
        "acFrequency": 60.0,
        "acOffset": 1.2,
        "acPhaseShift": 0.5,
        "craterFillTime": 2.0,
        "burnBackTime": 1.0,
    }

    def _get_wpp_id_by_name(self, uri, name):
        """Return the ID of a WPP entry with the given name, or None."""
        try:
            response = run_sync_in_thread(
                _call_adaptio, uri, "get_weld_process_parameters", timeout=DEFAULT_TIMEOUT
            )
            entries = _get_payload(response).get("weldProcessParameters", [])
            entry = next((e for e in entries if e.get("name") == name), None)
            return entry["id"] if entry else None
        except Exception as exc:
            logger.warning(f"Could not get WPP id for '{name}': {exc}")
            return None

    def _cleanup_wds_by_name(self, uri, name):
        """Remove any WDS with the given name (best-effort)."""
        try:
            response = run_sync_in_thread(
                _call_adaptio, uri, "get_weld_data_sets", timeout=DEFAULT_TIMEOUT
            )
            entries = _get_payload(response).get("weldDataSets", [])
            for entry in entries:
                if entry.get("name") == name:
                    run_sync_in_thread(
                        _call_adaptio, uri, "remove_weld_data_set",
                        id=entry["id"], timeout=DEFAULT_TIMEOUT,
                    )
        except Exception as exc:
            logger.warning(f"WDS cleanup for '{name}' failed: {exc}")

    def _cleanup_wpp_by_name(self, uri, name):
        """Remove any WPP with the given name (best-effort)."""
        try:
            response = run_sync_in_thread(
                _call_adaptio, uri, "get_weld_process_parameters", timeout=DEFAULT_TIMEOUT
            )
            entries = _get_payload(response).get("weldProcessParameters", [])
            for entry in entries:
                if entry.get("name") == name:
                    run_sync_in_thread(
                        _call_adaptio, uri, "remove_weld_process_parameters",
                        id=entry["id"], timeout=DEFAULT_TIMEOUT,
                    )
        except Exception as exc:
            logger.warning(f"WPP cleanup for '{name}' failed: {exc}")

    @pytest.fixture()
    def wpp_ids(self, request):
        """Create two WPP entries for WDS tests and clean up after."""
        uri = request.config.WEB_HMI_URI

        # Cleanup any leftover entries
        self._cleanup_wds_by_name(uri, self.WDS_NAME)
        self._cleanup_wds_by_name(uri, self.WDS_NAME_UPDATED)
        self._cleanup_wpp_by_name(uri, self.WPP_NAME_WS1)
        self._cleanup_wpp_by_name(uri, self.WPP_NAME_WS2)

        # Create WPP for ws1
        resp1 = run_sync_in_thread(
            _call_adaptio, uri, "add_weld_process_parameters",
            timeout=DEFAULT_TIMEOUT, **{**self.WPP_BASE, "name": self.WPP_NAME_WS1}
        )
        assert _get_result(resp1) == "ok", "Failed to create WPP ws1 for test setup"

        # Create WPP for ws2
        resp2 = run_sync_in_thread(
            _call_adaptio, uri, "add_weld_process_parameters",
            timeout=DEFAULT_TIMEOUT, **{**self.WPP_BASE, "name": self.WPP_NAME_WS2}
        )
        assert _get_result(resp2) == "ok", "Failed to create WPP ws2 for test setup"

        ws1_id = self._get_wpp_id_by_name(uri, self.WPP_NAME_WS1)
        ws2_id = self._get_wpp_id_by_name(uri, self.WPP_NAME_WS2)
        assert ws1_id is not None, "WPP ws1 not found after creation"
        assert ws2_id is not None, "WPP ws2 not found after creation"

        yield ws1_id, ws2_id

        # Teardown
        self._cleanup_wds_by_name(uri, self.WDS_NAME)
        self._cleanup_wds_by_name(uri, self.WDS_NAME_UPDATED)
        self._cleanup_wpp_by_name(uri, self.WPP_NAME_WS1)
        self._cleanup_wpp_by_name(uri, self.WPP_NAME_WS2)

    def test_add_weld_data_set(self, request, wpp_ids):
        """AddWeldDataSet with valid WPP IDs should succeed."""
        uri = request.config.WEB_HMI_URI
        ws1_id, ws2_id = wpp_ids

        response = run_sync_in_thread(
            _call_adaptio, uri, "add_weld_data_set",
            timeout=DEFAULT_TIMEOUT,
            name=self.WDS_NAME, ws1WppId=ws1_id, ws2WppId=ws2_id,
        )
        logger.debug(f"AddWeldDataSet response: {response}")

        result = _get_result(response)
        assert result == "ok", f"Expected 'ok' but got '{result}'"
        logger.info("AddWeldDataSet succeeded")

    def test_add_weld_data_set_duplicate_name_fails(self, request, wpp_ids):
        """AddWeldDataSet with a duplicate name should fail."""
        uri = request.config.WEB_HMI_URI
        ws1_id, ws2_id = wpp_ids

        first = run_sync_in_thread(
            _call_adaptio, uri, "add_weld_data_set",
            timeout=DEFAULT_TIMEOUT,
            name=self.WDS_NAME, ws1WppId=ws1_id, ws2WppId=ws2_id,
        )
        assert _get_result(first) == "ok", "Initial WDS creation failed unexpectedly"

        second = run_sync_in_thread(
            _call_adaptio, uri, "add_weld_data_set",
            timeout=DEFAULT_TIMEOUT,
            name=self.WDS_NAME, ws1WppId=ws1_id, ws2WppId=ws2_id,
        )
        logger.debug(f"Duplicate AddWeldDataSet response: {second}")

        result = _get_result(second)
        assert result != "ok", (
            f"Expected failure when adding WDS with duplicate name '{self.WDS_NAME}', "
            f"but got '{result}'"
        )
        logger.info("Duplicate WDS name correctly rejected")

    def test_add_weld_data_set_invalid_wpp_id_fails(self, request, wpp_ids):
        """AddWeldDataSet with non-existent WPP IDs should fail."""
        uri = request.config.WEB_HMI_URI

        response = run_sync_in_thread(
            _call_adaptio, uri, "add_weld_data_set",
            timeout=DEFAULT_TIMEOUT,
            name=self.WDS_NAME, ws1WppId=999998, ws2WppId=999999,
        )
        logger.debug(f"AddWeldDataSet (invalid WPP ids) response: {response}")

        result = _get_result(response)
        assert result != "ok", (
            f"Expected failure when adding WDS with non-existent WPP IDs, but got '{result}'"
        )
        logger.info("AddWeldDataSet with invalid WPP IDs correctly rejected")

    def test_get_weld_data_sets(self, request, wpp_ids):
        """GetWeldDataSets should return a list that includes the added entry."""
        uri = request.config.WEB_HMI_URI
        ws1_id, ws2_id = wpp_ids

        add_resp = run_sync_in_thread(
            _call_adaptio, uri, "add_weld_data_set",
            timeout=DEFAULT_TIMEOUT,
            name=self.WDS_NAME, ws1WppId=ws1_id, ws2WppId=ws2_id,
        )
        assert _get_result(add_resp) == "ok", "Pre-condition: WDS creation failed"

        response = run_sync_in_thread(
            _call_adaptio, uri, "get_weld_data_sets", timeout=DEFAULT_TIMEOUT
        )
        logger.debug(f"GetWeldDataSets response: {response}")

        result = _get_result(response)
        assert result == "ok", f"Expected 'ok' but got '{result}'"

        payload = _get_payload(response)
        entries = payload.get("weldDataSets", [])
        assert isinstance(entries, list), "Expected 'weldDataSets' to be a list"

        names = [e.get("name") for e in entries]
        assert self.WDS_NAME in names, (
            f"Expected '{self.WDS_NAME}' in WDS list but got: {names}"
        )
        logger.info(f"GetWeldDataSets returned {len(entries)} entries including '{self.WDS_NAME}'")

    def test_update_weld_data_set(self, request, wpp_ids):
        """UpdateWeldDataSet should update an existing entry successfully."""
        uri = request.config.WEB_HMI_URI
        ws1_id, ws2_id = wpp_ids

        add_resp = run_sync_in_thread(
            _call_adaptio, uri, "add_weld_data_set",
            timeout=DEFAULT_TIMEOUT,
            name=self.WDS_NAME, ws1WppId=ws1_id, ws2WppId=ws2_id,
        )
        assert _get_result(add_resp) == "ok", "Pre-condition: WDS creation failed"

        get_resp = run_sync_in_thread(
            _call_adaptio, uri, "get_weld_data_sets", timeout=DEFAULT_TIMEOUT
        )
        entries = _get_payload(get_resp).get("weldDataSets", [])
        wds = next((e for e in entries if e.get("name") == self.WDS_NAME), None)
        assert wds is not None, f"Pre-condition: WDS '{self.WDS_NAME}' not found"

        response = run_sync_in_thread(
            _call_adaptio, uri, "update_weld_data_set",
            timeout=DEFAULT_TIMEOUT,
            id=wds["id"], name=self.WDS_NAME_UPDATED, ws1WppId=ws2_id, ws2WppId=ws1_id,
        )
        logger.debug(f"UpdateWeldDataSet response: {response}")

        result = _get_result(response)
        assert result == "ok", f"Expected 'ok' but got '{result}'"
        logger.info("UpdateWeldDataSet succeeded")

    def test_update_weld_data_set_nonexistent_id_fails(self, request, wpp_ids):
        """UpdateWeldDataSet with a non-existent ID should fail."""
        uri = request.config.WEB_HMI_URI
        ws1_id, ws2_id = wpp_ids

        response = run_sync_in_thread(
            _call_adaptio, uri, "update_weld_data_set",
            timeout=DEFAULT_TIMEOUT,
            id=999999, name=self.WDS_NAME, ws1WppId=ws1_id, ws2WppId=ws2_id,
        )
        logger.debug(f"UpdateWeldDataSet (bad id) response: {response}")

        result = _get_result(response)
        assert result != "ok", (
            f"Expected failure when updating WDS with non-existent ID, but got '{result}'"
        )
        logger.info("UpdateWeldDataSet with non-existent ID correctly rejected")

    def test_remove_weld_data_set(self, request, wpp_ids):
        """RemoveWeldDataSet should remove an existing entry successfully."""
        uri = request.config.WEB_HMI_URI
        ws1_id, ws2_id = wpp_ids

        add_resp = run_sync_in_thread(
            _call_adaptio, uri, "add_weld_data_set",
            timeout=DEFAULT_TIMEOUT,
            name=self.WDS_NAME, ws1WppId=ws1_id, ws2WppId=ws2_id,
        )
        assert _get_result(add_resp) == "ok", "Pre-condition: WDS creation failed"

        get_resp = run_sync_in_thread(
            _call_adaptio, uri, "get_weld_data_sets", timeout=DEFAULT_TIMEOUT
        )
        entries = _get_payload(get_resp).get("weldDataSets", [])
        wds = next((e for e in entries if e.get("name") == self.WDS_NAME), None)
        assert wds is not None, f"Pre-condition: WDS '{self.WDS_NAME}' not found"

        response = run_sync_in_thread(
            _call_adaptio, uri, "remove_weld_data_set",
            timeout=DEFAULT_TIMEOUT, id=wds["id"]
        )
        logger.debug(f"RemoveWeldDataSet response: {response}")

        result = _get_result(response)
        assert result == "ok", f"Expected 'ok' but got '{result}'"

        verify_resp = run_sync_in_thread(
            _call_adaptio, uri, "get_weld_data_sets", timeout=DEFAULT_TIMEOUT
        )
        remaining = _get_payload(verify_resp).get("weldDataSets", [])
        names = [e.get("name") for e in remaining]
        assert self.WDS_NAME not in names, (
            f"WDS '{self.WDS_NAME}' still present after removal"
        )
        logger.info("RemoveWeldDataSet succeeded")

    def test_remove_weld_process_parameters_referenced_by_wds_fails(self, request, wpp_ids):
        """RemoveWeldProcessParameters should fail when the WPP is referenced by a WDS."""
        uri = request.config.WEB_HMI_URI
        ws1_id, ws2_id = wpp_ids

        # Create a WDS that references ws1_id
        add_wds = run_sync_in_thread(
            _call_adaptio, uri, "add_weld_data_set",
            timeout=DEFAULT_TIMEOUT,
            name=self.WDS_NAME, ws1WppId=ws1_id, ws2WppId=ws2_id,
        )
        assert _get_result(add_wds) == "ok", "Pre-condition: WDS creation failed"

        # Try to remove ws1 WPP while still referenced by a WDS
        response = run_sync_in_thread(
            _call_adaptio, uri, "remove_weld_process_parameters",
            timeout=DEFAULT_TIMEOUT, id=ws1_id
        )
        logger.debug(f"RemoveWeldProcessParameters (referenced) response: {response}")

        result = _get_result(response)
        assert result != "ok", (
            f"Expected failure when removing WPP referenced by a WDS, but got '{result}'"
        )
        logger.info("RemoveWeldProcessParameters correctly rejected when WPP is referenced by a WDS")
