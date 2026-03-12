import asyncio
import gc
import json
from unittest.mock import patch

import pytest
import websockets.exceptions as websocketsExc
from pydantic import ValidationError
from testzilla.adaptio_web_hmi.adaptio_web_hmi import (
    ActivityStatus,
    AdaptioWebHmi,
    AdaptioWebHmiMessage,
    MessageName,
    create_name_condition,
    validate_kwargs,
)
from websockets.frames import Close


class TestValidateKwargs:
    def test_missing_required_field(self):
        """Test validation error when required field is missing."""
        # Preparation
        fields = {
            "angle": (float, ...),
            "offset": (float, 0.0),
            "stickout": (int, 0),
        }

        kwargs = {
            "offset": (float, 0.0),
            "stickout": (int, 0),
        }

        # Execution and verification
        try:
            validate_kwargs(fields, **kwargs)
        except ValidationError:
            pass
        else:
            assert False, "ValidationError not raised"

    def test_invalid_field_type(self):
        """Test validation error with invalid field type."""
        # Preparation
        fields = {
            "angle": (float, ...),
            "offset": (float, 0.0),
            "stickout": (int, 0),
        }

        kwargs = {
            "angle": 1.0,
            "offset": 2.0,
            "stickout": 3.1,  # Invalid type
        }

        # Execution and verification
        try:
            validate_kwargs(fields, **kwargs)
        except ValidationError:
            pass
        else:
            assert False, "ValidationError not raised"

    def test_validate_kwargs_success(self):
        """Test successful validation of kwargs."""
        fields = {
            "angle": (float, 0.0),
            "offset": (float, 0.0),
            "stickout": (int, 0),
        }
        kwargs = {"angle": 1.5, "offset": 2.0, "stickout": 10}
        result = validate_kwargs(fields, **kwargs)
        assert result.angle == 1.5
        assert result.offset == 2.0
        assert result.stickout == 10

    def test_validate_kwargs_with_defaults(self):
        """Test validation using default values."""
        fields = {
            "angle": (float, 1.0),
            "offset": (float, 2.0),
            "stickout": (int, 5),
        }
        kwargs = {"angle": 3.0}  # Only provide angle, others should use defaults
        result = validate_kwargs(fields, **kwargs)
        assert result.angle == 3.0
        assert result.offset == 2.0
        assert result.stickout == 5

    def test_validate_kwargs_type_coercion(self):
        """Test type coercion in validation."""
        fields = {
            "angle": (float, 0.0),
            "stickout": (int, 0),
        }
        kwargs = {"angle": "1.5", "stickout": "10"}  # String inputs
        result = validate_kwargs(fields, **kwargs)
        assert result.angle == 1.5
        assert result.stickout == 10

    def test_validation_error_logging(self):
        """Test that validation errors are properly logged."""
        fields = {"required_field": (str, ...)}
        kwargs = {}  # Missing required field

        with patch("testzilla.adaptio_web_hmi.adaptio_web_hmi.logger") as mock_logger:
            with pytest.raises(ValidationError):
                validate_kwargs(fields, **kwargs)
            mock_logger.exception.assert_called_once_with("Kwargs validation error!")


class TestAdaptioWebHmiMessage:
    def test_adaptio_web_hmi_message_creation(self):
        """Test creating AdaptioWebHmiMessage with valid data."""
        message = AdaptioWebHmiMessage(name="TestMessage", payload={"key": "value"})
        assert message.name == "TestMessage"
        assert message.payload == {"key": "value"}

    def test_adaptio_web_hmi_message_str_conversion(self):
        """Test string conversion of AdaptioWebHmiMessage."""
        message = AdaptioWebHmiMessage(name="TestMessage", payload={"key": "value"})
        expected_json = '{"name":"TestMessage","payload":{"key":"value"},"result":null}'
        assert str(message) == expected_json

    def test_adaptio_web_hmi_message_empty_payload(self):
        """Test creating message with empty payload."""
        message = AdaptioWebHmiMessage(name="TestMessage", payload={})
        assert message.name == "TestMessage"
        assert message.payload == {}

    def test_adaptio_web_hmi_message_complex_payload(self):
        """Test creating message with complex nested payload."""
        payload = {"nested": {"key": "value"}, "list": [1, 2, 3], "number": 42.5, "bool": True}
        message = AdaptioWebHmiMessage(name="ComplexMessage", payload=payload)
        assert message.payload == payload


class TestCreateNameCondition:
    def test_create_name_condition_match(self):
        """Test name condition matching."""
        condition = create_name_condition("TestMessage")
        message_json = '{"name": "TestMessage", "payload": {}}'
        assert condition(message_json) is True

    def test_create_name_condition_no_match(self):
        """Test name condition not matching."""
        condition = create_name_condition("TestMessage")
        message_json = '{"name": "OtherMessage", "payload": {}}'
        assert condition(message_json) is False

    def test_create_name_condition_missing_name(self):
        """Test name condition with missing name field."""
        condition = create_name_condition("TestMessage")
        message_json = '{"payload": {}}'
        assert condition(message_json) is False

    def test_create_name_condition_invalid_json(self):
        """Test name condition with invalid JSON."""
        condition = create_name_condition("TestMessage")
        with pytest.raises(json.JSONDecodeError):
            condition("invalid json")


class TestAdaptioWebHmiInit:
    def test_adaptio_web_hmi_init(self, mock_websocket_client_sync):
        """Test AdaptioWebHmi initialization."""
        # Preparation

        # Execution
        client = AdaptioWebHmi(uri="ws://testserver")

        # Verification
        assert client.ws_client == mock_websocket_client_sync

    def test_adaptio_web_hmi_destructor(self, mock_websocket_client_sync):
        """Test AdaptioWebHmi destructor."""
        # Preparation
        client = AdaptioWebHmi(uri="ws://testserver")

        # Execution
        del client
        gc.collect()  # Force garbage collection

        # Verification
        mock_websocket_client_sync.close.assert_called_once()

    def test_destructor_with_missing_ws_client(self):
        """Test destructor when ws_client doesn't exist."""
        client = AdaptioWebHmi(uri="ws://testserver")
        # Simulate missing ws_client
        delattr(client, "ws_client")

        # Should not raise exception
        del client
        gc.collect()


class TestAdaptioWebHmiConnection:
    def test_connect_success_after_retry(self, mock_websocket_client_sync):
        """Test successful connection after retry."""
        # Preparation
        mock_websocket_client_sync.is_connected.side_effect = [False, False, True]
        mock_websocket_client_sync.connect.side_effect = [asyncio.TimeoutError, None]
        client = AdaptioWebHmi(uri="ws://testserver")

        # Execution
        client.connect()

        # Verification
        assert mock_websocket_client_sync.connect.call_count == 2

    def test_connect_exception_after_max_attempts(self, mock_websocket_client_sync):
        """Test connection exception after max attempts."""
        # Preparation
        mock_websocket_client_sync.is_connected.side_effect = [False, False, False, False]
        mock_websocket_client_sync.connect.side_effect = [
            asyncio.TimeoutError,
            asyncio.TimeoutError,
            asyncio.TimeoutError,
        ]
        client = AdaptioWebHmi(uri="ws://testserver")

        # Execution
        with pytest.raises(ConnectionError, match="Failed to connect to WebSocket after multiple attempts."):
            client.connect()

        # Verification
        assert mock_websocket_client_sync.connect.call_count == 3

    def test_connect_when_already_connected(self, mock_websocket_client_sync):
        """Test connect when already connected."""
        mock_websocket_client_sync.is_connected.return_value = True
        client = AdaptioWebHmi(uri="ws://testserver")

        client.connect()
        # Should not call connect on ws_client if already connected
        mock_websocket_client_sync.connect.assert_not_called()

    def test_connect_different_websocket_exceptions(self, mock_websocket_client_sync):
        """Test connect handling different websocket exceptions."""
        rcvd_close = Close(code=1000, reason="")
        sent_close = Close(code=1000, reason="")

        exception_instances = [
            websocketsExc.ConnectionClosedError(rcvd=rcvd_close, sent=sent_close, rcvd_then_sent=True),
            websocketsExc.InvalidURI(uri="ws://invalid", msg="Invalid WebSocket URI"),
        ]

        for exception in exception_instances:
            mock_websocket_client_sync.is_connected.side_effect = [False, False, True]
            mock_websocket_client_sync.connect.side_effect = [exception, None]
            client = AdaptioWebHmi(uri="ws://testserver")
            client.connect()
            assert mock_websocket_client_sync.connect.call_count >= 2

    def test_connect_with_custom_retries(self, mock_websocket_client_sync):
        """Test connect with custom retry settings."""
        mock_websocket_client_sync.is_connected.side_effect = [False] * 6
        mock_websocket_client_sync.connect.side_effect = [asyncio.TimeoutError] * 5
        client = AdaptioWebHmi(uri="ws://testserver")

        with pytest.raises(ConnectionError):
            client.connect(retries=5, retry_delay=0.1)

        assert mock_websocket_client_sync.connect.call_count == 5

    def test_close_method(self, mock_websocket_client_sync):
        """Test explicit close method."""
        client = AdaptioWebHmi(uri="ws://testserver")
        client.close()
        assert client._closed is True
        mock_websocket_client_sync.close.assert_called_once()

    def test_close_method_already_closed(self, mock_websocket_client_sync):
        """Test calling close on already closed client."""
        client = AdaptioWebHmi(uri="ws://testserver")
        client.close()
        client.close()  # Second call should not raise error
        mock_websocket_client_sync.close.assert_called_once()

    def test_close_method_exception_handling(self, mock_websocket_client_sync):
        """Test close method handles exceptions gracefully."""
        mock_websocket_client_sync.close.side_effect = RuntimeError("Connection error")
        client = AdaptioWebHmi(uri="ws://testserver")
        client.close()  # Should not raise exception
        assert client._closed is True

    def test_operations_after_close_raise_error(self, mock_websocket_client_sync):
        """Test that operations after close raise RuntimeError."""
        client = AdaptioWebHmi(uri="ws://testserver")
        client.close()

        with pytest.raises(RuntimeError, match="AdaptioWebHmi instance has been closed"):
            client.connect()
        with pytest.raises(RuntimeError, match="AdaptioWebHmi instance has been closed"):
            client.send_message(AdaptioWebHmiMessage(name="Test", payload={}))
        with pytest.raises(RuntimeError, match="AdaptioWebHmi instance has been closed"):
            client.receive_message()


class TestAdaptioWebHmiMessaging:
    def test_send_message(self, mock_websocket_client_sync):
        """Test sending a message."""
        # Preparation
        message = AdaptioWebHmiMessage(name="TestMessage", payload={"key": "value"})
        mock_websocket_client_sync.is_connected.side_effect = [False, True]

        # Execution
        client = AdaptioWebHmi(uri="ws://testserver")
        client.send_message(message)

        # Verification
        mock_websocket_client_sync.connect.assert_called_once()
        mock_websocket_client_sync.send_message.assert_called_once_with(
            '{"name":"TestMessage","payload":{"key":"value"},"result":null}'
        )

    def test_send_and_receive_message(self, mock_websocket_client_sync):
        """Test sending and receiving a message."""
        # Preparation
        mock_websocket_client_sync.receive_message.return_value = '{"name": "TestRsp", "payload": {}}'
        client = AdaptioWebHmi(uri="ws://testserver")

        # Execution
        result = client.send_and_receive_message(
            condition=None,
            request_name="TestReq",
            response_name="TestRsp",
            payload={"key": "value"},
        )

        # Verification
        mock_websocket_client_sync.send_message.assert_called_once_with('{"name":"TestReq","payload":{"key":"value"},"result":null}')
        mock_websocket_client_sync.receive_message.assert_called_once()
        assert result.name == "TestRsp"
        assert result.payload == {}

    def test_send_and_receive_message_with_condition(self, mock_websocket_client_sync):
        """Test sending and receiving with custom condition."""
        # Preparation
        mock_websocket_client_sync.receive_message.side_effect = [
            '{"name": "OtherMessage", "payload": {}}',
            '{"name": "TestRsp", "payload": {}}',
        ]
        client = AdaptioWebHmi(uri="ws://testserver")

        # Define the condition function
        def condition(response):
            data = json.loads(response)
            return data.get("name") == "TestRsp"

        # Execution
        result = client.send_and_receive_message(
            condition=condition,
            request_name="TestReq",
            response_name="TestRsp",
            payload={"key": "value"},
        )

        # Verification
        mock_websocket_client_sync.send_message.assert_called_once_with('{"name":"TestReq","payload":{"key":"value"},"result":null}')
        assert mock_websocket_client_sync.receive_message.call_count == 2
        assert result.name == "TestRsp"
        assert result.payload == {}

    def test_send_and_receive_with_custom_condition(self, mock_websocket_client_sync):
        """Test send_and_receive with custom condition function."""
        mock_websocket_client_sync.receive_message.return_value = (
            '{"name": "CustomRsp", "payload": {"result": "success"}}'
        )

        def custom_condition(message):
            data = json.loads(message)
            return data.get("payload", {}).get("result") == "success"

        client = AdaptioWebHmi(uri="ws://testserver")
        result = client.send_and_receive_message(
            condition=custom_condition, request_name="CustomReq", response_name="CustomRsp", payload={}
        )

        assert result.payload["result"] == "success"

    def test_receive_message_max_retries(self, mock_websocket_client_sync):
        """Test receive message with max retries."""
        # Preparation
        mock_websocket_client_sync.receive_message.side_effect = [
            '{"name": "OtherMessage", "payload": {}}'
        ] * 5  # Simulate 5 responses that do not meet the condition
        client = AdaptioWebHmi(uri="ws://testserver")

        # Define the condition function
        def condition(response):
            data = json.loads(response)
            return data.get("name") == "TestRsp"

        # Execution and Verification
        with pytest.raises(TimeoutError):
            client.receive_message(condition=condition, max_retries=5)

        assert mock_websocket_client_sync.receive_message.call_count == 5

    def test_receive_message_without_condition(self, mock_websocket_client_sync):
        """Test receiving message without condition."""
        mock_websocket_client_sync.receive_message.return_value = '{"name": "TestMessage", "payload": {}}'
        client = AdaptioWebHmi(uri="ws://testserver")

        result = client.receive_message(condition=None)
        assert result.name == "TestMessage"
        mock_websocket_client_sync.receive_message.assert_called_once()

    def test_receive_message_invalid_json_response(self, mock_websocket_client_sync):
        """Test receiving invalid JSON response."""
        mock_websocket_client_sync.receive_message.return_value = "invalid json"
        client = AdaptioWebHmi(uri="ws://testserver")

        with pytest.raises(ValidationError, match="Invalid JSON"):
            client.receive_message()


class TestEnumClasses:
    def test_message_name_enum_values(self):
        """Test MessageName enum has expected values."""
        assert MessageName.GET_ACTIVITY_STATUS.value == "GetActivityStatus"
        assert MessageName.ADD_WELD_PROCESS_PARAMETERS.value == "AddWeldProcessParameters"
        assert MessageName.SET_JOINT_GEOMETRY.value == "SetJointGeometry"
        assert MessageName.START_TRACKING.value == "StartTracking"

    def test_activity_status_enum_values(self):
        """Test ActivityStatus enum has expected values matching Gen2 ActivityStatusE."""
        assert ActivityStatus.IDLE.value == 0
        assert ActivityStatus.LASER_TORCH_CALIBRATION.value == 1
        assert ActivityStatus.WELD_OBJECT_CALIBRATION.value == 2
        assert ActivityStatus.CALIBRATION_AUTO_MOVE.value == 3
        assert ActivityStatus.TRACKING.value == 4
        assert ActivityStatus.LW_CALIBRATION.value == 5
        assert ActivityStatus.MANUAL_WELDING.value == 6

    def test_enum_uniqueness(self):
        """Test that enum values are unique."""
        message_values = [item.value for item in MessageName]
        assert len(message_values) == len(set(message_values))

        activity_values = [item.value for item in ActivityStatus]
        assert len(activity_values) == len(set(activity_values))


class TestErrorHandling:
    def test_validation_error_logging(self):
        """Test that validation errors are properly logged."""
        fields = {"required_field": (str, ...)}
        kwargs = {}  # Missing required field

        with patch("testzilla.adaptio_web_hmi.adaptio_web_hmi.logger") as mock_logger:
            with pytest.raises(ValidationError):
                validate_kwargs(fields, **kwargs)
            mock_logger.exception.assert_called_once_with("Kwargs validation error!")

    def test_destructor_with_missing_ws_client(self):
        """Test destructor when ws_client doesn't exist."""
        client = AdaptioWebHmi(uri="ws://testserver")
        # Simulate missing ws_client
        delattr(client, "ws_client")

        # Should not raise exception
        del client
        gc.collect()

    def test_connect_when_already_connected(self, mock_websocket_client_sync):
        """Test connect when already connected."""
        mock_websocket_client_sync.is_connected.return_value = True
        client = AdaptioWebHmi(uri="ws://testserver")

        client.connect()
        # Should not call connect on ws_client if already connected
        mock_websocket_client_sync.connect.assert_not_called()


# Performance and resource management tests
class TestResourceManagement:
    def test_multiple_clients_cleanup(self, mock_websocket_client_sync):
        """Test proper cleanup of multiple client instances."""
        clients = [AdaptioWebHmi(uri=f"ws://testserver{i}") for i in range(5)]

        for client in clients:
            client.close()

        # All should be properly closed
        assert all(client._closed for client in clients)

    def test_repeated_operations(self, mock_websocket_client_sync):
        """Test repeated operations don't cause issues."""
        mock_websocket_client_sync.receive_message.return_value = (
            '{"name": "GetActivityStatusRsp", "payload": {"value": 0}}'
        )
        client = AdaptioWebHmi(uri="ws://testserver")

        # Perform same operation multiple times
        for _ in range(10):
            result = client.get_activity_status()
            assert result.name == "GetActivityStatusRsp"


# Tests for specific API methods
class TestAdaptioWebHmiApiMethods:
    def test_get_adaptio_version(self, mock_websocket_client_sync):
        """Test getting Adaptio version."""
        # Preparation
        request = AdaptioWebHmiMessage(name="GetAdaptioVersion", payload={})
        response = AdaptioWebHmiMessage(name="GetAdaptioVersionRsp", payload={"version": "0.1.0"})
        mock_websocket_client_sync.receive_message.return_value = str(response)

        # Execution
        client = AdaptioWebHmi(uri="ws://testserver")
        result = client.get_adaptio_version()

        # Verification
        assert result.name == MessageName.GET_ADAPTIO_VERSION_RSP.value
        assert result.payload == response.payload

        mock_websocket_client_sync.send_message.assert_called_once_with(str(request))
        mock_websocket_client_sync.receive_message.assert_called_once()

    def test_get_activity_status(self, mock_websocket_client_sync):
        """Test getting activity status."""
        # Preparation
        request = AdaptioWebHmiMessage(name="GetActivityStatus", payload={})
        response = AdaptioWebHmiMessage(name="GetActivityStatusRsp", payload={"value": 0})
        mock_websocket_client_sync.receive_message.return_value = str(response)

        # Execution
        client = AdaptioWebHmi(uri="ws://testserver")
        result = client.get_activity_status()

        # Verification
        assert result.name == MessageName.GET_ACTIVITY_STATUS_RSP.value
        assert result.payload == response.payload

        mock_websocket_client_sync.send_message.assert_called_once_with(str(request))
        mock_websocket_client_sync.receive_message.assert_called_once()

    def test_add_weld_process_parameters(self, mock_websocket_client_sync):
        """Test adding weld process parameters."""
        # Preparation
        request = AdaptioWebHmiMessage(
            name="AddWeldProcessParameters",
            payload={
                "name": "FillType1",
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
            },
        )
        response = AdaptioWebHmiMessage(name="AddWeldProcessParametersRsp", payload={})
        mock_websocket_client_sync.receive_message.return_value = str(response)

        # Execution
        client = AdaptioWebHmi(uri="ws://testserver")
        result = client.add_weld_process_parameters(**request.payload)

        # Verification
        assert result.name == MessageName.ADD_WELD_PROCESS_PARAMETERS_RSP.value
        assert result.payload == response.payload
        mock_websocket_client_sync.send_message.assert_called_once_with(str(request))

    def test_add_weld_data_set(self, mock_websocket_client_sync):
        """Test adding weld data set."""
        # Preparation
        request = AdaptioWebHmiMessage(
            name="AddWeldDataSet",
            payload={"name": "root1", "ws1WppId": 1, "ws2WppId": 2},
        )
        response = AdaptioWebHmiMessage(name="AddWeldDataSetRsp", payload={})
        mock_websocket_client_sync.receive_message.return_value = str(response)

        # Execution
        client = AdaptioWebHmi(uri="ws://testserver")
        result = client.add_weld_data_set(**request.payload)

        # Verification
        assert result.name == MessageName.ADD_WELD_DATA_SET_RSP.value
        assert result.payload == response.payload
        mock_websocket_client_sync.send_message.assert_called_once_with(str(request))

    def test_select_weld_data_set(self, mock_websocket_client_sync):
        """Test selecting weld data set."""
        # Preparation
        request = AdaptioWebHmiMessage(name="SelectWeldDataSet", payload={"id": 1})
        response = AdaptioWebHmiMessage(name="SelectWeldDataSetRsp", payload={"result": "ok"})
        mock_websocket_client_sync.receive_message.return_value = str(response)

        # Execution
        client = AdaptioWebHmi(uri="ws://testserver")
        result = client.select_weld_data_set(**request.payload)

        # Verification
        assert result.name == MessageName.SELECT_WELD_DATA_SET_RSP.value
        assert result.payload == response.payload
        mock_websocket_client_sync.send_message.assert_called_once_with(str(request))

    def test_get_weld_process_parameters(self, mock_websocket_client_sync):
        """Test getting weld process parameters list.

        Gen2 sends the WPP list as the payload array directly, matching:
        {"name": "GetWeldProcessParametersRsp", "result": "ok", "payload": [...]}
        """
        # Preparation
        request = AdaptioWebHmiMessage(name="GetWeldProcessParameters", payload={})
        response = AdaptioWebHmiMessage(
            name="GetWeldProcessParametersRsp",
            payload=[{"id": 1, "name": "WPP1"}],
        )
        mock_websocket_client_sync.receive_message.return_value = str(response)

        # Execution
        client = AdaptioWebHmi(uri="ws://testserver")
        result = client.get_weld_process_parameters()

        # Verification
        assert result.name == MessageName.GET_WELD_PROCESS_PARAMETERS_RSP.value
        assert result.payload == response.payload
        mock_websocket_client_sync.send_message.assert_called_once_with(str(request))
        mock_websocket_client_sync.receive_message.assert_called_once()

    def test_update_weld_process_parameters(self, mock_websocket_client_sync):
        """Test updating weld process parameters."""
        # Preparation
        request = AdaptioWebHmiMessage(
            name="UpdateWeldProcessParameters",
            payload={
                "id": 1,
                "name": "UpdatedWPP",
                "method": "dc",
                "regulationType": "cc",
                "startAdjust": 10,
                "startType": "scratch",
                "voltage": 26.0,
                "current": 150.0,
                "wireSpeed": 12.5,
                "iceWireSpeed": 0.0,
                "acFrequency": 60.0,
                "acOffset": 1.2,
                "acPhaseShift": 0.5,
                "craterFillTime": 2.0,
                "burnBackTime": 1.0,
            },
        )
        response = AdaptioWebHmiMessage(name="UpdateWeldProcessParametersRsp", payload={"result": "ok"})
        mock_websocket_client_sync.receive_message.return_value = str(response)

        # Execution
        client = AdaptioWebHmi(uri="ws://testserver")
        result = client.update_weld_process_parameters(**request.payload)

        # Verification
        assert result.name == MessageName.UPDATE_WELD_PROCESS_PARAMETERS_RSP.value
        assert result.payload == response.payload
        mock_websocket_client_sync.send_message.assert_called_once_with(str(request))

    def test_remove_weld_process_parameters(self, mock_websocket_client_sync):
        """Test removing weld process parameters."""
        # Preparation
        request = AdaptioWebHmiMessage(name="RemoveWeldProcessParameters", payload={"id": 1})
        response = AdaptioWebHmiMessage(name="RemoveWeldProcessParametersRsp", payload={"result": "ok"})
        mock_websocket_client_sync.receive_message.return_value = str(response)

        # Execution
        client = AdaptioWebHmi(uri="ws://testserver")
        result = client.remove_weld_process_parameters(**request.payload)

        # Verification
        assert result.name == MessageName.REMOVE_WELD_PROCESS_PARAMETERS_RSP.value
        assert result.payload == response.payload
        mock_websocket_client_sync.send_message.assert_called_once_with(str(request))

    def test_get_weld_data_sets(self, mock_websocket_client_sync):
        """Test getting weld data sets list.

        Gen2 sends the WDS list as the payload array directly, matching:
        {"name": "GetWeldDataSetsRsp", "result": "ok", "payload": [...]}
        """
        # Preparation
        request = AdaptioWebHmiMessage(name="GetWeldDataSets", payload={})
        response = AdaptioWebHmiMessage(
            name="GetWeldDataSetsRsp",
            payload=[{"id": 1, "name": "WDS1", "ws1WppId": 1, "ws2WppId": 2}],
        )
        mock_websocket_client_sync.receive_message.return_value = str(response)

        # Execution
        client = AdaptioWebHmi(uri="ws://testserver")
        result = client.get_weld_data_sets()

        # Verification
        assert result.name == MessageName.GET_WELD_DATA_SETS_RSP.value
        assert result.payload == response.payload
        mock_websocket_client_sync.send_message.assert_called_once_with(str(request))
        mock_websocket_client_sync.receive_message.assert_called_once()

    def test_update_weld_data_set(self, mock_websocket_client_sync):
        """Test updating a weld data set."""
        # Preparation
        request = AdaptioWebHmiMessage(
            name="UpdateWeldDataSet",
            payload={"id": 1, "name": "UpdatedWDS", "ws1WppId": 2, "ws2WppId": 3},
        )
        response = AdaptioWebHmiMessage(name="UpdateWeldDataSetRsp", payload={"result": "ok"})
        mock_websocket_client_sync.receive_message.return_value = str(response)

        # Execution
        client = AdaptioWebHmi(uri="ws://testserver")
        result = client.update_weld_data_set(**request.payload)

        # Verification
        assert result.name == MessageName.UPDATE_WELD_DATA_SET_RSP.value
        assert result.payload == response.payload
        mock_websocket_client_sync.send_message.assert_called_once_with(str(request))

    def test_remove_weld_data_set(self, mock_websocket_client_sync):
        """Test removing a weld data set."""
        # Preparation
        request = AdaptioWebHmiMessage(name="RemoveWeldDataSet", payload={"id": 1})
        response = AdaptioWebHmiMessage(name="RemoveWeldDataSetRsp", payload={"result": "ok"})
        mock_websocket_client_sync.receive_message.return_value = str(response)

        # Execution
        client = AdaptioWebHmi(uri="ws://testserver")
        result = client.remove_weld_data_set(**request.payload)

        # Verification
        assert result.name == MessageName.REMOVE_WELD_DATA_SET_RSP.value
        assert result.payload == response.payload
        mock_websocket_client_sync.send_message.assert_called_once_with(str(request))

    def test_subscribe_arc_state(self, mock_websocket_client_sync):
        """Test subscribing to arc state notifications."""
        # Preparation
        request = AdaptioWebHmiMessage(name="SubscribeArcState", payload={})
        response = AdaptioWebHmiMessage(name="SubscribeArcStateRsp", payload={"result": "ok"})
        mock_websocket_client_sync.receive_message.return_value = str(response)

        # Execution
        client = AdaptioWebHmi(uri="ws://testserver")
        result = client.subscribe_arc_state()

        # Verification
        assert result.name == MessageName.SUBSCRIBE_ARC_STATE_RSP.value
        assert result.payload == response.payload
        mock_websocket_client_sync.send_message.assert_called_once_with(str(request))
        mock_websocket_client_sync.receive_message.assert_called_once()

    def test_get_arc_state(self, mock_websocket_client_sync):
        """Test getting current arc state."""
        # Preparation
        request = AdaptioWebHmiMessage(name="GetArcState", payload={})
        response = AdaptioWebHmiMessage(
            name="GetArcStateRsp",
            payload={"result": "ok", "state": "idle"},
        )
        mock_websocket_client_sync.receive_message.return_value = str(response)

        # Execution
        client = AdaptioWebHmi(uri="ws://testserver")
        result = client.get_arc_state()

        # Verification
        assert result.name == MessageName.GET_ARC_STATE_RSP.value
        assert result.payload == response.payload
        mock_websocket_client_sync.send_message.assert_called_once_with(str(request))
        mock_websocket_client_sync.receive_message.assert_called_once()

    def test_get_joint_geometry(self, mock_websocket_client_sync):
        """Test getting joint geometry."""
        # Preparation
        request = AdaptioWebHmiMessage(name="GetJointGeometry", payload={})
        response = AdaptioWebHmiMessage(
            name="GetJointGeometryRsp",
            payload={
                "grooveDepthMm": 120.0,
                "leftJointAngleRad": 0.139,
                "leftMaxSurfaceAngleRad": 0.35,
                "rightJointAngleRad": 0.139,
                "rightMaxSurfaceAngleRad": 0.35,
                "upperJointWidthMm": 42.0,
            },
        )
        mock_websocket_client_sync.receive_message.return_value = str(response)

        # Execution
        client = AdaptioWebHmi(uri="ws://testserver")
        result = client.get_joint_geometry()

        # Verification
        assert result.name == MessageName.GET_JOINT_GEOMETRY_RSP.value
        assert result.payload == response.payload
        mock_websocket_client_sync.send_message.assert_called_once_with(str(request))
        mock_websocket_client_sync.receive_message.assert_called_once()

    def test_set_joint_geometry(self, mock_websocket_client_sync):
        """Test setting joint geometry."""
        # Preparation
        request = AdaptioWebHmiMessage(
            name="SetJointGeometry",
            payload={
                "grooveDepthMm": 0.0,
                "leftJointAngleRad": 0.139,
                "leftMaxSurfaceAngleRad": 0.35,
                "rightJointAngleRad": 0.139,
                "rightMaxSurfaceAngleRad": 0.35,
                "upperJointWidthMm": 42.0,
            },
        )

        # Execution
        client = AdaptioWebHmi(uri="ws://testserver")
        client.set_joint_geometry(
            leftJointAngleRad=0.139,
            leftMaxSurfaceAngleRad=0.35,
            rightJointAngleRad=0.139,
            rightMaxSurfaceAngleRad=0.35,
            upperJointWidthMm=42.0,
        )

        # Verification
        mock_websocket_client_sync.send_message.assert_called_once_with(str(request))

    def test_set_joint_geometry_partial_params(self, mock_websocket_client_sync):
        """Test setting joint geometry with only some parameters."""
        client = AdaptioWebHmi(uri="ws://testserver")
        client.set_joint_geometry(grooveDepthMm=5.0, upperJointWidthMm=10.0)

        # Should use defaults for missing parameters
        expected_payload = {
            "grooveDepthMm": 5.0,
            "leftJointAngleRad": 0.0,
            "leftMaxSurfaceAngleRad": 0.0,
            "rightJointAngleRad": 0.0,
            "rightMaxSurfaceAngleRad": 0.0,
            "upperJointWidthMm": 10.0,
        }

        expected_message = (
            f'{{"name":"SetJointGeometry","payload":{json.dumps(expected_payload, separators=(",", ":"))},"result":null}}'
        )

        mock_websocket_client_sync.send_message.assert_called_once_with(expected_message)

    def test_laser_to_torch_calibration(self, mock_websocket_client_sync):
        """Test laser to torch calibration."""
        # Preparation
        request = AdaptioWebHmiMessage(
            name="LaserToTorchCalibration", payload={"angle": -45.0, "offset": 1.0, "stickout": 10}
        )
        response = AdaptioWebHmiMessage(
            name="LaserToTorchCalibrationRsp", payload={"angle": 12.0, "valid": True, "x": 6.9, "y": 0.0, "z": 0.5}
        )
        mock_websocket_client_sync.receive_message.return_value = str(response)

        # Execution
        client = AdaptioWebHmi(uri="ws://testserver")
        result = client.laser_to_torch_calibration(offset=1.0, angle=-45.0, stickout=10)

        # Verification
        assert result.name == MessageName.LASER_TO_TORCH_CALIBRATION_RSP.value
        assert result.payload == response.payload
        mock_websocket_client_sync.send_message.assert_called_once_with(str(request))

    def test_laser_calibration_with_zero_values(self, mock_websocket_client_sync):
        """Test laser calibration with zero values."""
        mock_websocket_client_sync.receive_message.return_value = (
            '{"name": "LaserToTorchCalibrationRsp", "payload": {"valid": false}}'
        )

        client = AdaptioWebHmi(uri="ws://testserver")
        result = client.laser_to_torch_calibration(angle=0.0, offset=0.0, stickout=0)

        assert result.payload["valid"] is False

    def test_get_laser_to_torch_calibration(self, mock_websocket_client_sync):
        """Test getting laser to torch calibration."""
        # Preparation
        request = AdaptioWebHmiMessage(name="GetLaserToTorchCalibration", payload={})
        response = AdaptioWebHmiMessage(
            name="GetLaserToTorchCalibrationRsp",
            payload={"angle": 0.26, "valid": True, "x": 6.9, "y": 200.1, "z": -29.5},
        )
        mock_websocket_client_sync.receive_message.return_value = str(response)

        # Execution
        client = AdaptioWebHmi(uri="ws://testserver")
        result = client.get_laser_to_torch_calibration()

        # Verification
        assert result.name == MessageName.GET_LASER_TO_TORCH_CALIBRATION_RSP.value
        assert result.payload == response.payload
        mock_websocket_client_sync.send_message.assert_called_once_with(str(request))

    def test_set_laser_to_torch_calibration(self, mock_websocket_client_sync):
        """Test setting laser to torch calibration."""
        # Preparation
        request = AdaptioWebHmiMessage(
            name="SetLaserToTorchCalibration", payload={"angle": 0.26, "x": 6.9, "y": 200.1, "z": -29.5}
        )
        response = AdaptioWebHmiMessage(name="SetLaserToTorchCalibrationRsp", payload={"result": True})
        mock_websocket_client_sync.receive_message.return_value = str(response)

        # Execution
        client = AdaptioWebHmi(uri="ws://testserver")
        result = client.set_laser_to_torch_calibration(**request.payload)

        # Verification
        assert result.name == MessageName.SET_LASER_TO_TORCH_CALIBRATION_RSP.value
        assert result.payload == response.payload
        mock_websocket_client_sync.send_message.assert_called_once_with(str(request))

    def test_weld_object_calibration(self, mock_websocket_client_sync):
        """Test weld object calibration."""
        # Preparation
        request = AdaptioWebHmiMessage(name="WeldObjectCalibration", payload={"radius": 8000.1, "stickout": 30})
        response = AdaptioWebHmiMessage(
            name="WeldObjectCalibrationRsp", payload={"valid": True, "y": -8000, "z": -14.7}
        )
        mock_websocket_client_sync.receive_message.return_value = str(response)

        # Execution
        client = AdaptioWebHmi(uri="ws://testserver")
        result = client.weld_object_calibration(**request.payload)

        # Verification
        assert result.name == MessageName.WELD_OBJECT_CALIBRATION_RSP.value
        assert result.payload == response.payload
        mock_websocket_client_sync.send_message.assert_called_once_with(str(request))

    def test_weld_object_calibration_large_radius(self, mock_websocket_client_sync):
        """Test weld object calibration with large radius value."""
        mock_websocket_client_sync.receive_message.return_value = (
            '{"name": "WeldObjectCalibrationRsp", "payload": {"valid": true, "y": -50000, "z": -100.5}}'
        )

        client = AdaptioWebHmi(uri="ws://testserver")
        result = client.weld_object_calibration(radius=50000.0, stickout=50)

        assert result.payload["valid"] is True
        assert result.payload["y"] == -50000

    def test_get_weld_object_calibration(self, mock_websocket_client_sync):
        """Test getting weld object calibration."""
        # Preparation
        request = AdaptioWebHmiMessage(name="GetWeldObjectCalibration", payload={})
        response = AdaptioWebHmiMessage(
            name="GetWeldObjectCalibrationRsp", payload={"valid": True, "y": -8000, "z": -14.7}
        )
        mock_websocket_client_sync.receive_message.return_value = str(response)

        # Execution
        client = AdaptioWebHmi(uri="ws://testserver")
        result = client.get_weld_object_calibration()

        # Verification
        assert result.name == MessageName.GET_WELD_OBJECT_CALIBRATION_RSP.value
        assert result.payload == response.payload
        mock_websocket_client_sync.send_message.assert_called_once_with(str(request))

    def test_set_weld_object_calibration(self, mock_websocket_client_sync):
        """Test setting weld object calibration."""
        # Preparation
        request = AdaptioWebHmiMessage(name="SetWeldObjectCalibration", payload={"y": -8000.0, "z": -14.7})
        response = AdaptioWebHmiMessage(name="SetWeldObjectCalibrationRsp", payload={"result": True})
        mock_websocket_client_sync.receive_message.return_value = str(response)

        # Execution
        client = AdaptioWebHmi(uri="ws://testserver")
        result = client.set_weld_object_calibration(**request.payload)

        # Verification
        assert result.name == MessageName.SET_WELD_OBJECT_CALIBRATION_RSP.value
        assert result.payload == response.payload
        mock_websocket_client_sync.send_message.assert_called_once_with(str(request))

    def test_get_slides_status(self, mock_websocket_client_sync):
        """Test getting slides status."""
        # Preparation
        request = AdaptioWebHmiMessage(name="GetSlidesStatus", payload={})
        response = AdaptioWebHmiMessage(
            name="GetSlidesStatusRsp", payload={"horizontal_in_position": True, "vertical_in_position": False}
        )
        mock_websocket_client_sync.receive_message.return_value = str(response)

        # Execution
        client = AdaptioWebHmi(uri="ws://testserver")
        result = client.get_slides_status()

        # Verification
        assert result.name == MessageName.GET_SLIDES_STATUS_RSP.value
        assert result.payload == response.payload
        mock_websocket_client_sync.send_message.assert_called_once_with(str(request))

    def test_get_slides_postion(self, mock_websocket_client_sync):
        # Preparation
        request = AdaptioWebHmiMessage(name="GetSlidesPosition", payload={})
        response = AdaptioWebHmiMessage(name="GetSlidesPositionRsp", payload={"horizontal": 5.0, "vertical": 10.0})
        mock_websocket_client_sync.receive_message.return_value = str(response)

        # Execution
        client = AdaptioWebHmi(uri="ws://testserver")
        result = client.get_slides_position()

        # Verification
        assert result.name == MessageName.GET_SLIDES_POSITION_RSP.value
        assert result.payload == response.payload
        mock_websocket_client_sync.send_message.assert_called_once_with(str(request))

    def test_set_slides_postion(self, mock_websocket_client_sync):
        # Preparation
        request = AdaptioWebHmiMessage(name="SetSlidesPosition", payload={"horizontal": 5.0, "vertical": 10.0})

        # Execution
        client = AdaptioWebHmi(uri="ws://testserver")
        client.set_slides_position(**request.payload)

        # Verification
        mock_websocket_client_sync.send_message.assert_called_once_with(str(request))

    def test_service_mode_tracking(self, mock_websocket_client_sync):
        # Preparation
        request = AdaptioWebHmiMessage(name="ServiceModeTracking", payload={})

        # Execution
        client = AdaptioWebHmi(uri="ws://testserver")
        client.service_mode_tracking()

        # Verification
        mock_websocket_client_sync.send_message.assert_called_once_with(str(request))

    def test_start_tracking(self, mock_websocket_client_sync):
        # Preparation
        request = AdaptioWebHmiMessage(name="StartTracking", payload={})

        # Execution
        client = AdaptioWebHmi(uri="ws://testserver")
        client.start_tracking()

        # Verification
        mock_websocket_client_sync.send_message.assert_called_once_with(str(request))

    def test_service_mode_kinetics_control(self, mock_websocket_client_sync):
        # Preparation
        request = AdaptioWebHmiMessage(name="ServiceModeKinematicsControl", payload={})

        # Execution
        client = AdaptioWebHmi(uri="ws://testserver")
        client.service_mode_kinematics_control()

        # Verification
        mock_websocket_client_sync.send_message.assert_called_once_with(str(request))
