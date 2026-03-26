import asyncio
import gc
import json

import pytest
import websockets.exceptions as websocketsExc
from pydantic import ValidationError
from testzilla.adaptio_web_hmi.adaptio_web_hmi import (
    AdaptioWebHmi,
    AdaptioWebHmiMessage,
    create_name_condition,
)
from websockets.frames import Close


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

    def test_adaptio_web_hmi_init_with_env_var(self, mock_websocket_client_sync, monkeypatch):
        """Test AdaptioWebHmi initialization via ADAPTIO_WEB_HMI_URI env var."""
        monkeypatch.setenv("ADAPTIO_WEB_HMI_URI", "ws://env-server:9090")

        client = AdaptioWebHmi()

        assert client.uri == "ws://env-server:9090"

    def test_adaptio_web_hmi_init_explicit_uri_overrides_env_var(self, mock_websocket_client_sync, monkeypatch):
        """Test that an explicit uri argument takes precedence over the env var."""
        monkeypatch.setenv("ADAPTIO_WEB_HMI_URI", "ws://env-server:9090")

        client = AdaptioWebHmi(uri="ws://explicit-server:8080")

        assert client.uri == "ws://explicit-server:8080"

    def test_adaptio_web_hmi_init_missing_uri_raises(self, mock_websocket_client_sync, monkeypatch):
        """Test that ValueError is raised when neither uri nor env var is set."""
        monkeypatch.delenv("ADAPTIO_WEB_HMI_URI", raising=False)

        with pytest.raises(ValueError, match="ADAPTIO_WEB_HMI_URI"):
            AdaptioWebHmi()

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
            result = client.send_and_receive_message(None, "GetActivityStatus", "GetActivityStatusRsp", {})
            assert result.name == "GetActivityStatusRsp"

