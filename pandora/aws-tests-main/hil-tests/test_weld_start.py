"""HIL test cases for weld data handling and starting a manual weld.

Covers the weld data handling use case for Gen 2:
- Adding weld process parameters (WPP) for each weld system (WS1, WS2)
- Creating a weld data set (WDS) that references the WPPs
- Selecting the weld data set to configure the system for manual welding

The PLC is not involved in this use case; all interactions go through the WebHMI
WebSocket API (AdaptioWebHmi).

Reference: sysfun-welddata-handling.md
"""

from concurrent.futures import ThreadPoolExecutor
from concurrent.futures import TimeoutError as FutureTimeout
from typing import Iterator

import pytest
from loguru import logger
from pydantic_core import ValidationError as PydanticCoreValidationError

from testzilla.adaptio_web_hmi.adaptio_web_hmi import AdaptioWebHmi as AdaptioWebHmiClient
from testzilla.utility.cleanup_utils import cleanup_web_hmi_client

# ---------------------------------------------------------------------------
# Default weld process parameters mirroring Gen 2 block-test defaults
# (helpers_weld_parameters.h: WPP_DEFAULT_WS1 / WPP_DEFAULT_WS2)
# ---------------------------------------------------------------------------

WPP_DEFAULT_WS1 = {
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

WPP_DEFAULT_WS2 = {
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
# Thread-safe helpers (same pattern used in test_webhmi.py)
# ---------------------------------------------------------------------------


def _run_adaptio_send(uri: str, request_name: str, response_name: str, payload: dict, condition=None):
    """Create an Adaptio client in-thread, send/receive one message, then close.

    Creating the client inside the worker thread ensures that
    WebSocketClientSync creates its own event loop instead of capturing a
    running loop from the test thread (which causes ``run_until_complete`` to
    raise "event loop is already running").
    """
    client = AdaptioWebHmiClient(uri=uri)
    try:
        return client.send_and_receive_message(
            condition=condition,
            request_name=request_name,
            response_name=response_name,
            payload=payload,
        )
    except PydanticCoreValidationError as exc:
        # Handle failure responses that don't match the expected schema
        # (e.g., missing 'payload' field).  Return the raw dict so callers
        # can inspect the "result" field.
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


def _run_sync_in_thread(func, *args, timeout=None, **kwargs):
    """Run a blocking function in a separate thread and return its result."""
    with ThreadPoolExecutor(max_workers=1) as executor:
        future = executor.submit(func, *args, **kwargs)
        try:
            return future.result(timeout=timeout)
        except FutureTimeout:
            future.cancel()
            raise TimeoutError("Operation timed out")


def _extract_result(response) -> str | None:
    """Extract the 'result' string from an Adaptio WebHMI response."""
    if isinstance(response, dict):
        return response.get("result") or response.get("payload", {}).get("result")
    return getattr(response, "result", None) or (
        response.payload.get("result") if hasattr(response, "payload") else None
    )


def _extract_id(response) -> int | None:
    """Extract the 'id' integer from an Adaptio WebHMI response payload."""
    if isinstance(response, dict):
        return response.get("id") or response.get("payload", {}).get("id")
    if hasattr(response, "payload"):
        return response.payload.get("id")
    return None


# ---------------------------------------------------------------------------
# Function-scoped fixtures
# ---------------------------------------------------------------------------


@pytest.fixture(name="weld_process_parameters_setup", scope="function")
def weld_process_parameters_setup_fixture(request: pytest.FixtureRequest) -> Iterator[tuple[int, int]]:
    """Function-scoped fixture: add WPP for WS1 and WS2; yield their IDs; clean up afterwards.

    Yields:
        Tuple ``(wpp_id_ws1, wpp_id_ws2)`` with the IDs assigned by Adaptio.
    """
    uri = request.config.WEB_HMI_URI
    wpp_ids: list[int] = []

    for wpp, label in [(WPP_DEFAULT_WS1, "WS1"), (WPP_DEFAULT_WS2, "WS2")]:
        try:
            response = _run_sync_in_thread(
                _run_adaptio_send,
                uri,
                request_name="AddWeldProcessParameters",
                response_name="AddWeldProcessParametersRsp",
                payload=wpp,
                timeout=10,
            )
            result = _extract_result(response)
            if result != "ok":
                pytest.skip(f"Could not add WPP for {label}: result={result}")
            wpp_id = _extract_id(response)
            if wpp_id is None:
                pytest.skip(f"No ID returned when adding WPP for {label}")
            logger.info(f"WPP {label} added with id={wpp_id}")
            wpp_ids.append(wpp_id)
        except TimeoutError:
            logger.exception(f"Timeout adding WPP for {label}")
            pytest.skip(f"Timeout adding WPP for {label}")

    yield wpp_ids[0], wpp_ids[1]

    # Cleanup: remove WPPs that were created
    for wpp_id in wpp_ids:
        try:
            _run_sync_in_thread(
                _run_adaptio_send,
                uri,
                request_name="RemoveWeldProcessParameters",
                response_name="RemoveWeldProcessParametersRsp",
                payload={"id": wpp_id},
                timeout=10,
            )
            logger.debug(f"Removed WPP with id={wpp_id}")
        except TimeoutError:
            logger.warning(f"Timeout removing WPP with id={wpp_id}")


@pytest.fixture(name="weld_data_set_setup", scope="function")
def weld_data_set_setup_fixture(
    request: pytest.FixtureRequest,
    weld_process_parameters_setup: tuple[int, int],
) -> Iterator[int]:
    """Function-scoped fixture: add a WDS referencing both WPPs; yield the WDS ID; clean up afterwards.

    Depends on ``weld_process_parameters_setup`` fixture.

    Yields:
        WDS ID assigned by Adaptio.
    """
    uri = request.config.WEB_HMI_URI
    wpp_id_ws1, wpp_id_ws2 = weld_process_parameters_setup
    wds_id: int | None = None

    try:
        response = _run_sync_in_thread(
            _run_adaptio_send,
            uri,
            request_name="AddWeldDataSet",
            response_name="AddWeldDataSetRsp",
            payload={"name": "ManualWeld", "ws1WppId": wpp_id_ws1, "ws2WppId": wpp_id_ws2},
            timeout=10,
        )
        result = _extract_result(response)
        if result != "ok":
            pytest.skip(f"Could not add weld data set: result={result}")
        wds_id = _extract_id(response)
        if wds_id is None:
            pytest.skip("No ID returned when adding weld data set")
        logger.info(f"Weld data set added with id={wds_id}")
    except TimeoutError:
        logger.exception("Timeout adding weld data set")
        pytest.skip("Timeout adding weld data set")

    yield wds_id

    # Cleanup: remove WDS that was created
    try:
        _run_sync_in_thread(
            _run_adaptio_send,
            uri,
            request_name="RemoveWeldDataSet",
            response_name="RemoveWeldDataSetRsp",
            payload={"id": wds_id},
            timeout=10,
        )
        logger.debug(f"Removed weld data set with id={wds_id}")
    except TimeoutError:
        logger.warning(f"Timeout removing weld data set with id={wds_id}")


# ---------------------------------------------------------------------------
# Test suite
# ---------------------------------------------------------------------------


class TestManualWeldStart:
    """HIL test suite for manual weld data handling (Gen 2, no PLC).

    These tests cover the weld data handling use case described in
    sysfun-welddata-handling.md:

    1. Add weld process parameters (WPP) for each weld system (WS1/WS2).
    2. Add a weld data set (WDS) that references the WPPs.
    3. Select the weld data set so the system is configured for manual welding.

    The PLC is not involved; all communication uses the WebHMI WebSocket API.
    """

    # ------------------------------------------------------------------
    # Individual-step tests
    # ------------------------------------------------------------------

    def test_add_weld_process_parameters_ws1(self, request: pytest.FixtureRequest) -> None:
        """Adding WPP for WS1 via WebHMI returns a success response.

        Sends an AddWeldProcessParameters message for weld system 1 and
        verifies that Adaptio responds with result "ok".
        """
        logger.info("Testing AddWeldProcessParameters for WS1")
        try:
            response = _run_sync_in_thread(
                _run_adaptio_send,
                request.config.WEB_HMI_URI,
                request_name="AddWeldProcessParameters",
                response_name="AddWeldProcessParametersRsp",
                payload=WPP_DEFAULT_WS1,
                timeout=10,
            )
            logger.debug(f"Response: {response}")
            result = _extract_result(response)
            assert result == "ok", f"Expected result 'ok', got: {result!r}"
            logger.info("WPP for WS1 added successfully")
        except TimeoutError:
            logger.exception("Timeout adding WPP for WS1")
            pytest.fail("Timed out waiting for AddWeldProcessParametersRsp (WS1)")

    def test_add_weld_process_parameters_ws2(self, request: pytest.FixtureRequest) -> None:
        """Adding WPP for WS2 via WebHMI returns a success response.

        Sends an AddWeldProcessParameters message for weld system 2 and
        verifies that Adaptio responds with result "ok".
        """
        logger.info("Testing AddWeldProcessParameters for WS2")
        try:
            response = _run_sync_in_thread(
                _run_adaptio_send,
                request.config.WEB_HMI_URI,
                request_name="AddWeldProcessParameters",
                response_name="AddWeldProcessParametersRsp",
                payload=WPP_DEFAULT_WS2,
                timeout=10,
            )
            logger.debug(f"Response: {response}")
            result = _extract_result(response)
            assert result == "ok", f"Expected result 'ok', got: {result!r}"
            logger.info("WPP for WS2 added successfully")
        except TimeoutError:
            logger.exception("Timeout adding WPP for WS2")
            pytest.fail("Timed out waiting for AddWeldProcessParametersRsp (WS2)")

    @pytest.mark.usefixtures("weld_process_parameters_setup")
    def test_add_weld_data_set(
        self,
        request: pytest.FixtureRequest,
        weld_process_parameters_setup: tuple[int, int],
    ) -> None:
        """Adding a WDS that references WS1 and WS2 WPPs returns a success response.

        Requires both WPPs to be present (provided by weld_process_parameters_setup
        fixture).  Sends an AddWeldDataSet message and verifies result "ok".
        """
        wpp_id_ws1, wpp_id_ws2 = weld_process_parameters_setup
        logger.info(f"Testing AddWeldDataSet (ws1WppId={wpp_id_ws1}, ws2WppId={wpp_id_ws2})")
        try:
            response = _run_sync_in_thread(
                _run_adaptio_send,
                request.config.WEB_HMI_URI,
                request_name="AddWeldDataSet",
                response_name="AddWeldDataSetRsp",
                payload={"name": "ManualWeld", "ws1WppId": wpp_id_ws1, "ws2WppId": wpp_id_ws2},
                timeout=10,
            )
            logger.debug(f"Response: {response}")
            result = _extract_result(response)
            assert result == "ok", f"Expected result 'ok', got: {result!r}"
            wds_id = _extract_id(response)
            logger.info(f"Weld data set added successfully with id={wds_id}")
        except TimeoutError:
            logger.exception("Timeout adding weld data set")
            pytest.fail("Timed out waiting for AddWeldDataSetRsp")

    def test_select_weld_data_set(
        self,
        request: pytest.FixtureRequest,
        weld_data_set_setup: int,
    ) -> None:
        """Selecting an existing WDS via WebHMI returns a success response.

        Requires a weld data set to exist (provided by weld_data_set_setup
        fixture).  Sends a SelectWeldDataSet message and verifies result "ok".
        """
        wds_id = weld_data_set_setup
        logger.info(f"Testing SelectWeldDataSet (id={wds_id})")
        try:
            response = _run_sync_in_thread(
                _run_adaptio_send,
                request.config.WEB_HMI_URI,
                request_name="SelectWeldDataSet",
                response_name="SelectWeldDataSetRsp",
                payload={"id": wds_id},
                timeout=10,
            )
            logger.debug(f"Response: {response}")
            result = _extract_result(response)
            assert result == "ok", f"Expected result 'ok', got: {result!r}"
            logger.info(f"Weld data set id={wds_id} selected successfully")
        except TimeoutError:
            logger.exception(f"Timeout selecting weld data set id={wds_id}")
            pytest.fail("Timed out waiting for SelectWeldDataSetRsp")

    # ------------------------------------------------------------------
    # End-to-end flow test
    # ------------------------------------------------------------------

    def test_full_manual_weld_setup(self, request: pytest.FixtureRequest) -> None:
        """End-to-end manual weld data setup flow completes successfully.

        Validates the full sequence required before a manual weld can be started:

        1. Add weld process parameters for WS1 (voltage=25 V, current=200 A).
        2. Add weld process parameters for WS2 (voltage=28 V, current=180 A).
        3. Add a weld data set referencing both WPPs.
        4. Select the weld data set.

        Each step must return result "ok".  The PLC is not involved.
        """
        uri = request.config.WEB_HMI_URI
        logger.info("Testing full manual weld setup flow")

        try:
            # Step 1 – Add WPP for WS1
            logger.info("Step 1: Adding WPP for WS1")
            wpp1_response = _run_sync_in_thread(
                _run_adaptio_send,
                uri,
                request_name="AddWeldProcessParameters",
                response_name="AddWeldProcessParametersRsp",
                payload=WPP_DEFAULT_WS1,
                timeout=10,
            )
            wpp1_result = _extract_result(wpp1_response)
            assert wpp1_result == "ok", f"Failed to add WPP for WS1: {wpp1_result!r}"
            wpp1_id = _extract_id(wpp1_response)
            logger.info(f"WPP WS1 added with id={wpp1_id}")

            # Step 2 – Add WPP for WS2
            logger.info("Step 2: Adding WPP for WS2")
            wpp2_response = _run_sync_in_thread(
                _run_adaptio_send,
                uri,
                request_name="AddWeldProcessParameters",
                response_name="AddWeldProcessParametersRsp",
                payload=WPP_DEFAULT_WS2,
                timeout=10,
            )
            wpp2_result = _extract_result(wpp2_response)
            assert wpp2_result == "ok", f"Failed to add WPP for WS2: {wpp2_result!r}"
            wpp2_id = _extract_id(wpp2_response)
            logger.info(f"WPP WS2 added with id={wpp2_id}")

            # Step 3 – Add WDS
            logger.info("Step 3: Adding weld data set")
            wds_response = _run_sync_in_thread(
                _run_adaptio_send,
                uri,
                request_name="AddWeldDataSet",
                response_name="AddWeldDataSetRsp",
                payload={"name": "ManualWeld", "ws1WppId": wpp1_id, "ws2WppId": wpp2_id},
                timeout=10,
            )
            wds_result = _extract_result(wds_response)
            assert wds_result == "ok", f"Failed to add weld data set: {wds_result!r}"
            wds_id = _extract_id(wds_response)
            logger.info(f"Weld data set added with id={wds_id}")

            # Step 4 – Select WDS
            logger.info("Step 4: Selecting weld data set")
            select_response = _run_sync_in_thread(
                _run_adaptio_send,
                uri,
                request_name="SelectWeldDataSet",
                response_name="SelectWeldDataSetRsp",
                payload={"id": wds_id},
                timeout=10,
            )
            select_result = _extract_result(select_response)
            assert select_result == "ok", f"Failed to select weld data set: {select_result!r}"
            logger.info("Full manual weld setup completed successfully")

        except TimeoutError:
            logger.exception("Timeout during full manual weld setup")
            pytest.fail("Timed out during full manual weld setup flow")

    # ------------------------------------------------------------------
    # Negative / validation tests
    # ------------------------------------------------------------------

    def test_add_weld_data_set_with_invalid_wpp_id_fails(self, request: pytest.FixtureRequest) -> None:
        """Adding a WDS with a non-existent WPP ID returns a failure response.

        Sends an AddWeldDataSet message referencing WPP IDs that do not exist
        and verifies that Adaptio responds with result "fail".
        """
        logger.info("Testing AddWeldDataSet with invalid WPP IDs")
        try:
            response = _run_sync_in_thread(
                _run_adaptio_send,
                request.config.WEB_HMI_URI,
                request_name="AddWeldDataSet",
                response_name="AddWeldDataSetRsp",
                payload={"name": "InvalidWeld", "ws1WppId": 99999, "ws2WppId": 99998},
                timeout=10,
            )
            logger.debug(f"Response: {response}")
            result = _extract_result(response)
            assert result == "fail", f"Expected result 'fail' for invalid WPP IDs, got: {result!r}"
            logger.info("Correctly received 'fail' for invalid WPP IDs")
        except TimeoutError:
            logger.exception("Timeout when testing invalid WPP IDs")
            pytest.fail("Timed out waiting for AddWeldDataSetRsp (invalid IDs)")

    def test_select_nonexistent_weld_data_set_fails(self, request: pytest.FixtureRequest) -> None:
        """Selecting a WDS with a non-existent ID returns a failure response.

        Sends a SelectWeldDataSet message with an ID that does not exist and
        verifies that Adaptio responds with result "fail".
        """
        logger.info("Testing SelectWeldDataSet with non-existent ID")
        try:
            response = _run_sync_in_thread(
                _run_adaptio_send,
                request.config.WEB_HMI_URI,
                request_name="SelectWeldDataSet",
                response_name="SelectWeldDataSetRsp",
                payload={"id": 99999},
                timeout=10,
            )
            logger.debug(f"Response: {response}")
            result = _extract_result(response)
            assert result == "fail", f"Expected result 'fail' for non-existent WDS, got: {result!r}"
            logger.info("Correctly received 'fail' for non-existent WDS")
        except TimeoutError:
            logger.exception("Timeout when testing non-existent WDS selection")
            pytest.fail("Timed out waiting for SelectWeldDataSetRsp (non-existent ID)")
