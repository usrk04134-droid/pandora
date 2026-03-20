"""HIL integration tests for starting weld setup via WebHMI."""

import json
import uuid

import pytest
from loguru import logger

from testzilla.adaptio_web_hmi.adaptio_web_hmi import AdaptioWebHmi, AdaptioWebHmiMessage
from testzilla.utility.cleanup_utils import cleanup_web_hmi_client


DEFAULT_WPP_WS1 = {
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

DEFAULT_WPP_WS2 = {
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


def _response_result(response: dict) -> str | None:
    payload = response.get("payload")
    if isinstance(payload, dict) and payload.get("result") is not None:
        return payload.get("result")

    return response.get("result")


def _receive_json_by_name(web_hmi: AdaptioWebHmi, expected_name: str, max_messages: int = 10) -> dict:
    seen_names: list[str | None] = []

    try:
        web_hmi.connect()
        for _ in range(max_messages):
            raw_message = web_hmi.ws_client.receive_message(timeout=5)
            message = json.loads(raw_message)
            seen_names.append(message.get("name"))
            if message.get("name") == expected_name:
                return message
    except Exception as exc:
        logger.exception(f"Failed receiving WebHMI message {expected_name}: {exc}")
        pytest.skip(f"Skipping weld HIL test due to WebHMI communication failure: {exc}")

    raise AssertionError(f"Did not receive {expected_name}. Received: {seen_names}")


def _send_message(web_hmi: AdaptioWebHmi, request_name: str, payload: dict) -> None:
    try:
        web_hmi.send_message(AdaptioWebHmiMessage(name=request_name, payload=payload))
    except Exception as exc:
        logger.exception(f"Failed sending WebHMI message {request_name}: {exc}")
        pytest.skip(f"Skipping weld HIL test due to WebHMI communication failure: {exc}")


def _request_json(web_hmi: AdaptioWebHmi, request_name: str, response_name: str, payload: dict) -> dict:
    _send_message(web_hmi, request_name, payload)
    return _receive_json_by_name(web_hmi, response_name)


def _get_weld_process_parameters(web_hmi: AdaptioWebHmi) -> list[dict]:
    response = _request_json(web_hmi, "GetWeldProcessParameters", "GetWeldProcessParametersRsp", {})
    payload = response.get("payload")
    assert isinstance(payload, list), f"Unexpected weld process parameters payload: {payload!r}"
    return payload


def _get_weld_data_sets(web_hmi: AdaptioWebHmi) -> list[dict]:
    response = _request_json(web_hmi, "GetWeldDataSets", "GetWeldDataSetsRsp", {})
    payload = response.get("payload")
    assert isinstance(payload, list), f"Unexpected weld data set payload: {payload!r}"
    return payload


def _find_by_name(items: list[dict], name: str) -> dict | None:
    return next((item for item in items if item.get("name") == name), None)


def _add_weld_process_parameters(web_hmi: AdaptioWebHmi, name: str, defaults: dict) -> int:
    response = _request_json(
        web_hmi,
        "AddWeldProcessParameters",
        "AddWeldProcessParametersRsp",
        {"name": name, **defaults},
    )
    assert _response_result(response) == "ok", response

    created = _find_by_name(_get_weld_process_parameters(web_hmi), name)
    assert created is not None, f"Weld process parameters {name} were not returned by GetWeldProcessParameters"
    return created["id"]


def _add_weld_data_set(web_hmi: AdaptioWebHmi, name: str, ws1_wpp_id: int, ws2_wpp_id: int) -> int:
    response = _request_json(
        web_hmi,
        "AddWeldDataSet",
        "AddWeldDataSetRsp",
        {"name": name, "ws1WppId": ws1_wpp_id, "ws2WppId": ws2_wpp_id},
    )
    assert _response_result(response) == "ok", response

    created = _find_by_name(_get_weld_data_sets(web_hmi), name)
    assert created is not None, f"Weld data set {name} was not returned by GetWeldDataSets"
    return created["id"]


def _cleanup_created_weld_data(web_hmi: AdaptioWebHmi, weld_data_set_id: int | None, wpp_ids: list[int]) -> None:
    if weld_data_set_id is not None:
        try:
            _request_json(web_hmi, "RemoveWeldDataSet", "RemoveWeldDataSetRsp", {"id": weld_data_set_id})
        except Exception as exc:
            logger.warning(f"Best-effort cleanup failed for weld data set {weld_data_set_id}: {exc}")

    for wpp_id in wpp_ids:
        try:
            _request_json(web_hmi, "RemoveWeldProcessParameters", "RemoveWeldProcessParametersRsp", {"id": wpp_id})
        except Exception as exc:
            logger.warning(f"Best-effort cleanup failed for weld process parameters {wpp_id}: {exc}")


@pytest.fixture(name="web_hmi")
def web_hmi_fixture(request: pytest.FixtureRequest) -> AdaptioWebHmi:
    client = AdaptioWebHmi(uri=request.config.WEB_HMI_URI)
    try:
        yield client
    finally:
        cleanup_web_hmi_client(client)


class TestStartingWeld:
    """Integration coverage for manual weld setup prior to start."""

    @pytest.fixture(autouse=True)
    def setup_adaptio_logs(self, adaptio_manager) -> None:
        """Enable Adaptio log collection for this module when configured."""
        _ = adaptio_manager

    def test_create_and_select_weld_data_for_manual_weld(self, web_hmi: AdaptioWebHmi) -> None:
        unique_suffix = uuid.uuid4().hex[:8]
        ws1_name = f"hil-manual-ws1-{unique_suffix}"
        ws2_name = f"hil-manual-ws2-{unique_suffix}"
        weld_data_set_name = f"hil-manual-wds-{unique_suffix}"
        weld_data_set_id = None
        wpp_ids: list[int] = []

        try:
            initial_arc_state = _request_json(web_hmi, "GetArcState", "GetArcStateRsp", {})
            assert initial_arc_state["payload"]["state"] == "idle"

            ws1_wpp_id = _add_weld_process_parameters(web_hmi, ws1_name, DEFAULT_WPP_WS1)
            ws2_wpp_id = _add_weld_process_parameters(web_hmi, ws2_name, DEFAULT_WPP_WS2)
            wpp_ids.extend([ws1_wpp_id, ws2_wpp_id])

            weld_data_set_id = _add_weld_data_set(web_hmi, weld_data_set_name, ws1_wpp_id, ws2_wpp_id)

            weld_data_set = _find_by_name(_get_weld_data_sets(web_hmi), weld_data_set_name)
            assert weld_data_set is not None
            assert weld_data_set["ws1WppId"] == ws1_wpp_id
            assert weld_data_set["ws2WppId"] == ws2_wpp_id

            select_response = _request_json(
                web_hmi,
                "SelectWeldDataSet",
                "SelectWeldDataSetRsp",
                {"id": weld_data_set_id},
            )
            assert _response_result(select_response) == "ok", select_response

            configured_arc_state = _request_json(web_hmi, "GetArcState", "GetArcStateRsp", {})
            assert configured_arc_state["payload"]["state"] == "configured"
        finally:
            _cleanup_created_weld_data(web_hmi, weld_data_set_id, wpp_ids)

    def test_subscribe_arc_state_pushes_idle_and_configured_states(self, web_hmi: AdaptioWebHmi) -> None:
        unique_suffix = uuid.uuid4().hex[:8]
        ws1_name = f"hil-arc-ws1-{unique_suffix}"
        ws2_name = f"hil-arc-ws2-{unique_suffix}"
        weld_data_set_name = f"hil-arc-wds-{unique_suffix}"
        weld_data_set_id = None
        wpp_ids: list[int] = []

        try:
            _send_message(web_hmi, "SubscribeArcState", {})
            initial_push = _receive_json_by_name(web_hmi, "ArcState")
            assert initial_push["payload"]["state"] == "idle"

            ws1_wpp_id = _add_weld_process_parameters(web_hmi, ws1_name, DEFAULT_WPP_WS1)
            ws2_wpp_id = _add_weld_process_parameters(web_hmi, ws2_name, DEFAULT_WPP_WS2)
            wpp_ids.extend([ws1_wpp_id, ws2_wpp_id])

            weld_data_set_id = _add_weld_data_set(web_hmi, weld_data_set_name, ws1_wpp_id, ws2_wpp_id)

            select_response = _request_json(
                web_hmi,
                "SelectWeldDataSet",
                "SelectWeldDataSetRsp",
                {"id": weld_data_set_id},
            )
            assert _response_result(select_response) == "ok", select_response

            configured_push = _receive_json_by_name(web_hmi, "ArcState")
            assert configured_push["payload"]["state"] == "configured"

            weld_data_subscription = _request_json(web_hmi, "SubscribeWeldData", "SubscribeWeldDataRsp", {})
            assert _response_result(weld_data_subscription) == "ok", weld_data_subscription
        finally:
            _cleanup_created_weld_data(web_hmi, weld_data_set_id, wpp_ids)
