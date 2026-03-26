import asyncio
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
import websockets
from testzilla.utility.websocket_client import WebSocketClient, WebSocketClientSync


@pytest.mark.asyncio
async def test_async_client_connect(mock_websockets_connect):
    # Preparation
    client = WebSocketClient("ws://mockserver")

    # Execution
    await client.connect()

    # Verification
    mock_websockets_connect.assert_called_once_with("ws://mockserver", open_timeout=5)
    assert client.is_connected()


@pytest.mark.asyncio
async def test_async_client_connect_already_connected(mock_websockets_connect):
    # Preparation
    client = WebSocketClient("ws://mockserver")
    await client.connect()

    # Execution
    await client.connect()

    # Verification
    mock_websockets_connect.assert_called_once_with("ws://mockserver", open_timeout=5)
    assert client.is_connected()


@pytest.mark.asyncio
async def test_connect_and_close_race_condition(mock_websockets_connect):
    # Preparation
    client = WebSocketClient("ws://mockserver")

    async def connect_client():
        await client.connect()

    async def close_client():
        await client.close()

    # Execution
    # Run connect and close concurrently
    await asyncio.gather(connect_client(), close_client())

    # Verification
    mock_websockets_connect.assert_called_once_with("ws://mockserver", open_timeout=5)
    mock_websockets_connect.return_value.close.assert_called_once()
    assert not client.is_connected()


@pytest.mark.asyncio
async def test_async_client_send_message(mock_websockets_connect):
    # Preparation
    mock_websockets_connect.return_value.send = AsyncMock()
    client = WebSocketClient("ws://mockserver")
    await client.connect()

    # Execution
    await client.send_message("Hello, WebSocket!")

    # Verification
    mock_websockets_connect.return_value.send.assert_called_once_with("Hello, WebSocket!")


@pytest.mark.asyncio
async def test_async_client_receive_message(mock_websockets_connect):
    # Preparation
    mock_websockets_connect.return_value.recv = AsyncMock(return_value="Hello from WebSocket!")
    client = WebSocketClient("ws://mockserver")
    await client.connect()

    # Execution
    response = await client.receive_message()

    # Verification
    assert response == "Hello from WebSocket!"
    mock_websockets_connect.return_value.recv.assert_called_once()


@pytest.mark.asyncio
async def test_async_client_receive_message_timeout(mock_websockets_connect):
    # Preparation
    mock_websockets_connect.return_value.recv = AsyncMock(side_effect=asyncio.TimeoutError)
    client = WebSocketClient("ws://mockserver")
    await client.connect()

    # Execution and Verification
    with pytest.raises(asyncio.TimeoutError):
        await client.receive_message(timeout=1)

    mock_websockets_connect.return_value.recv.assert_called_once()


@pytest.mark.asyncio
async def test_async_client_close(mock_websockets_connect):
    # Preparation
    mock_websockets_connect.return_value.close = AsyncMock()
    client = WebSocketClient("ws://mockserver")
    await client.connect()

    # Execution
    await client.close()

    # Verification
    mock_websockets_connect.return_value.close.assert_called_once()


@pytest.mark.asyncio
async def test_async_client_is_connected(mock_websockets_connect):
    # Preparation
    client = WebSocketClient("ws://mockserver")

    # Execution
    await client.connect()

    # Verification
    assert client.is_connected() is True

    # Simulate closed connection
    mock_websockets_connect.return_value.open = False
    assert client.is_connected() is False


@pytest.mark.asyncio
async def test_async_client_connect_with_custom_timeout(mock_websockets_connect):
    """Test connecting with custom timeout value."""
    client = WebSocketClient("ws://mockserver")

    await client.connect(timeout=10)

    mock_websockets_connect.assert_called_once_with("ws://mockserver", open_timeout=10)


@pytest.mark.asyncio
async def test_async_client_connect_connection_closed_error(mock_websockets_connect):
    """Test connection failure due to ConnectionClosedError."""
    mock_websockets_connect.side_effect = websockets.exceptions.ConnectionClosedError(rcvd=None, sent=None)
    client = WebSocketClient("ws://mockserver")

    with pytest.raises(websockets.exceptions.ConnectionClosedError):
        await client.connect()

    assert not client.is_connected()


@pytest.mark.asyncio
async def test_async_client_connect_invalid_uri_error(mock_websockets_connect):
    """Test connection failure due to InvalidURI."""
    mock_websockets_connect.side_effect = websockets.exceptions.InvalidURI("ws://invalid", "Invalid URI format")
    client = WebSocketClient("ws://mockserver")

    with pytest.raises(websockets.exceptions.InvalidURI):
        await client.connect()

    assert not client.is_connected()


@pytest.mark.asyncio
async def test_async_client_connect_timeout_error(mock_websockets_connect):
    """Test connection failure due to timeout."""
    mock_websockets_connect.side_effect = asyncio.TimeoutError()
    client = WebSocketClient("ws://mockserver")

    with pytest.raises(asyncio.TimeoutError):
        await client.connect()

    assert not client.is_connected()


@pytest.mark.asyncio
async def test_async_client_send_message_without_connection():
    """Test sending message when not connected."""
    client = WebSocketClient("ws://mockserver")

    with pytest.raises(ConnectionError, match="WebSocket is not connected"):
        await client.send_message("test message")


@pytest.mark.asyncio
async def test_async_client_receive_message_without_connection():
    """Test receiving message when not connected."""
    client = WebSocketClient("ws://mockserver")

    with pytest.raises(ConnectionError, match="WebSocket is not connected"):
        await client.receive_message()


@pytest.mark.asyncio
async def test_async_client_receive_message_with_custom_timeout(mock_websockets_connect):
    """Test receiving message with custom timeout."""
    mock_websockets_connect.return_value.recv = AsyncMock(return_value="response")
    client = WebSocketClient("ws://mockserver")
    await client.connect()

    response = await client.receive_message(timeout=10)

    assert response == "response"
    # Verify asyncio.wait_for was called with correct timeout
    # This would require more sophisticated mocking to verify the timeout parameter


@pytest.mark.asyncio
async def test_async_client_close_when_not_connected():
    """Test closing when not connected (should not raise error)."""
    client = WebSocketClient("ws://mockserver")

    # Should not raise any exception
    await client.close()
    assert not client.is_connected()


@pytest.mark.asyncio
async def test_async_client_close_multiple_times(mock_websockets_connect):
    """Test closing multiple times."""
    mock_websockets_connect.return_value.close = AsyncMock()
    client = WebSocketClient("ws://mockserver")
    await client.connect()

    await client.close()
    await client.close()  # Second close should not raise error

    # Close should only be called once on the websocket
    mock_websockets_connect.return_value.close.assert_called_once()


@pytest.mark.asyncio
async def test_async_client_is_connected_websocket_none():
    """Test is_connected when websocket is None."""
    client = WebSocketClient("ws://mockserver")
    assert not client.is_connected()


@pytest.mark.asyncio
async def test_async_client_multiple_concurrent_connects(mock_websockets_connect):
    """Test multiple concurrent connect attempts (lock protection)."""
    client = WebSocketClient("ws://mockserver")

    # Create multiple connect tasks
    tasks = [client.connect() for _ in range(5)]
    await asyncio.gather(*tasks)

    # Connect should only be called once due to lock protection
    mock_websockets_connect.assert_called_once()
    assert client.is_connected()


def test_sync_client_connect(mock_websockets_connect):
    # Preparation
    client = WebSocketClientSync("ws://mockserver")

    # Execution
    client.connect()

    # Verification
    mock_websockets_connect.assert_called_once_with("ws://mockserver", open_timeout=5)
    assert client.is_connected()


def test_sync_client_send_message(mock_websockets_connect):
    # Preparation
    mock_websockets_connect.return_value.send = AsyncMock()
    client = WebSocketClientSync("ws://mockserver")
    client.connect()

    # Execution
    client.send_message("Hello, WebSocket!")

    # Verification
    mock_websockets_connect.return_value.send.assert_called_once_with("Hello, WebSocket!")


def test_sync_client_receive_message(mock_websockets_connect):
    # Preparation
    mock_websockets_connect.return_value.recv = AsyncMock(return_value="Hello from WebSocket!")
    client = WebSocketClientSync("ws://mockserver")
    client.connect()

    # Execution
    response = client.receive_message()

    # Verification
    assert response == "Hello from WebSocket!"
    mock_websockets_connect.return_value.recv.assert_called_once()


def test_sync_client_close(mock_websockets_connect):
    # Preparation
    mock_websockets_connect.return_value.close = AsyncMock()
    client = WebSocketClientSync("ws://mockserver")
    client.connect()

    # Execution
    client.close()

    # Verification
    mock_websockets_connect.return_value.close.assert_called_once()


def test_sync_client_is_connected(mock_websockets_connect):
    # Preparation
    client = WebSocketClientSync("ws://mockserver")
    client.connect()

    # Execution
    assert client.is_connected() is True

    # Verification
    # Simulate closed connection
    mock_websockets_connect.return_value.open = False
    assert client.is_connected() is False


def test_sync_client_send_message_without_connection():
    """Test sync client sending message when not connected."""
    client = WebSocketClientSync("ws://mockserver")

    with pytest.raises(ConnectionError, match="WebSocket is not connected"):
        client.send_message("test message")


def test_sync_client_receive_message_without_connection():
    """Test sync client receiving message when not connected."""
    client = WebSocketClientSync("ws://mockserver")

    with pytest.raises(ConnectionError, match="WebSocket is not connected"):
        client.receive_message()


def test_sync_client_receive_message_with_custom_timeout(mock_websockets_connect):
    """Test sync client receiving message with custom timeout."""
    mock_websockets_connect.return_value.recv = AsyncMock(return_value="response")
    client = WebSocketClientSync("ws://mockserver")
    client.connect()

    response = client.receive_message(timeout=10)

    assert response == "response"


def test_sync_client_close_when_not_connected():
    """Test sync client closing when not connected."""
    client = WebSocketClientSync("ws://mockserver")

    # Should not raise any exception
    client.close()
    assert not client.is_connected()


def test_sync_client_connect_with_closed_loop():
    """Test sync client operations when event loop is closed."""
    client = WebSocketClientSync("ws://mockserver")
    client.loop.close()

    with pytest.raises(RuntimeError, match="Event loop is closed"):
        client.connect()


def test_sync_client_send_message_with_closed_loop(mock_websockets_connect):
    """Test sync client send message when event loop is closed."""
    client = WebSocketClientSync("ws://mockserver")
    client.connect()
    client.loop.close()

    with pytest.raises(RuntimeError, match="Event loop is closed"):
        client.send_message("test")


def test_sync_client_receive_message_with_closed_loop(mock_websockets_connect):
    """Test sync client receive message when event loop is closed."""
    client = WebSocketClientSync("ws://mockserver")
    client.connect()
    client.loop.close()

    with pytest.raises(RuntimeError, match="Event loop is closed"):
        client.receive_message()


def test_sync_client_destructor_with_running_loop(mock_websockets_connect):
    """Test sync client destructor when loop is running and connected."""
    mock_websockets_connect.return_value.close = AsyncMock()

    with patch("asyncio.get_running_loop") as mock_get_loop:
        mock_loop = MagicMock()
        mock_loop.is_closed.return_value = False
        mock_get_loop.return_value = mock_loop

        client = WebSocketClientSync("ws://mockserver")
        client.connect()

        # Manually call destructor
        client.__del__()

        # Verify close was attempted
        mock_loop.run_until_complete.assert_called()


def test_sync_client_destructor_with_closed_loop():
    """Test sync client destructor when loop is already closed."""
    with patch("asyncio.get_running_loop") as mock_get_loop:
        mock_loop = MagicMock()
        mock_loop.is_closed.return_value = True
        mock_get_loop.return_value = mock_loop

        client = WebSocketClientSync("ws://mockserver")

        # Should not raise exception even if loop is closed
        client.__del__()


def test_sync_client_destructor_runtime_error_handling():
    """Test sync client destructor handles RuntimeError gracefully."""
    with patch("asyncio.get_running_loop") as mock_get_loop:
        mock_loop = MagicMock()
        mock_loop.is_closed.return_value = False
        mock_loop.run_until_complete.side_effect = RuntimeError("Loop closed")
        mock_get_loop.return_value = mock_loop

        client = WebSocketClientSync("ws://mockserver")
        client._loop_created = True

        # Should not raise exception
        client.__del__()


def test_sync_client_with_existing_event_loop():
    """Test sync client initialization with existing event loop."""
    with patch("asyncio.get_running_loop") as mock_get_loop:
        mock_loop = MagicMock()
        mock_get_loop.return_value = mock_loop

        client = WebSocketClientSync("ws://mockserver")

        assert client.loop is mock_loop
        assert not client._loop_created


def test_sync_client_with_no_event_loop():
    """Test sync client initialization when no event loop exists."""
    with patch("asyncio.get_running_loop", side_effect=RuntimeError("No running loop")):
        with patch("asyncio.new_event_loop") as mock_new_loop:
            with patch("asyncio.set_event_loop") as mock_set_loop:
                mock_loop = MagicMock()
                mock_new_loop.return_value = mock_loop

                client = WebSocketClientSync("ws://mockserver")

                assert client.loop is mock_loop
                assert client._loop_created
                mock_new_loop.assert_called_once()
                mock_set_loop.assert_called_once_with(mock_loop)


# Edge case and error handling tests


@pytest.mark.asyncio
async def test_async_client_websocket_send_exception(mock_websockets_connect):
    """Test handling of exceptions during send operation."""
    mock_websockets_connect.return_value.send = AsyncMock(
        side_effect=websockets.exceptions.ConnectionClosedError(rcvd=None, sent=None)
    )
    client = WebSocketClient("ws://mockserver")
    await client.connect()

    with pytest.raises(websockets.exceptions.ConnectionClosedError):
        await client.send_message("test")


@pytest.mark.asyncio
async def test_async_client_websocket_recv_exception(mock_websockets_connect):
    """Test handling of exceptions during receive operation."""
    mock_websockets_connect.return_value.recv = AsyncMock(
        side_effect=websockets.exceptions.ConnectionClosedError(rcvd=None, sent=None)
    )
    client = WebSocketClient("ws://mockserver")
    await client.connect()

    with pytest.raises(websockets.exceptions.ConnectionClosedError):
        await client.receive_message()


def test_sync_client_websocket_send_exception(mock_websockets_connect):
    """Test sync client handling of exceptions during send operation."""
    mock_websockets_connect.return_value.send = AsyncMock(
        side_effect=websockets.exceptions.ConnectionClosedError(rcvd=None, sent=None)
    )
    client = WebSocketClientSync("ws://mockserver")
    client.connect()

    with pytest.raises(websockets.exceptions.ConnectionClosedError):
        client.send_message("test")


def test_sync_client_websocket_recv_exception(mock_websockets_connect):
    """Test sync client handling of exceptions during receive operation."""
    mock_websockets_connect.return_value.recv = AsyncMock(
        side_effect=websockets.exceptions.ConnectionClosedError(rcvd=None, sent=None)
    )
    client = WebSocketClientSync("ws://mockserver")
    client.connect()

    with pytest.raises(websockets.exceptions.ConnectionClosedError):
        client.receive_message()


@pytest.mark.asyncio
async def test_async_client_connect_reconnect_after_failure(mock_websockets_connect):
    """Test reconnecting after a failed connection attempt."""
    # First attempt fails
    mock_websockets_connect.side_effect = [
        websockets.exceptions.ConnectionClosedError(rcvd=None, sent=None),
        mock_websockets_connect.return_value,  # Second attempt succeeds
    ]
    client = WebSocketClient("ws://mockserver")

    # First connection should fail
    with pytest.raises(websockets.exceptions.ConnectionClosedError):
        await client.connect()

    assert not client.is_connected()

    # Second connection should succeed
    await client.connect()
    assert client.is_connected()

    # Should have been called twice
    assert mock_websockets_connect.call_count == 2


@pytest.mark.asyncio
async def test_async_client_close_cancels_internal_websocket_tasks(mock_websockets_connect):
    """Test that close() cancels and awaits websockets legacy background tasks."""
    # Preparation
    async def _forever():
        await asyncio.sleep(3600)

    loop = asyncio.get_running_loop()
    transfer_task = loop.create_task(_forever(), name="transfer_data_task")
    keepalive_task = loop.create_task(_forever(), name="keepalive_ping_task")
    close_conn_task = loop.create_task(_forever(), name="close_connection_task")

    mock_ws = mock_websockets_connect.return_value
    mock_ws.transfer_data_task = transfer_task
    mock_ws.keepalive_ping_task = keepalive_task
    mock_ws.close_connection_task = close_conn_task

    client = WebSocketClient("ws://mockserver")
    await client.connect()

    # Execution
    await client.close()

    # Verification
    assert transfer_task.done()
    assert keepalive_task.done()
    assert close_conn_task.done()


@pytest.mark.asyncio
async def test_async_client_close_tolerates_missing_internal_tasks(mock_websockets_connect):
    """Test that close() does not raise when internal task attributes are absent."""
    # Preparation
    client = WebSocketClient("ws://mockserver")
    await client.connect()

    # Execution and Verification
    await client.close()
    assert not client.is_connected()


@pytest.mark.asyncio
async def test_async_client_close_tolerates_already_done_internal_tasks(mock_websockets_connect):
    """Test that close() does not raise when internal tasks have already finished."""
    # Preparation
    async def _noop():
        pass

    loop = asyncio.get_running_loop()
    done_task = loop.create_task(_noop())
    await asyncio.sleep(0)

    mock_ws = mock_websockets_connect.return_value
    mock_ws.transfer_data_task = done_task
    mock_ws.keepalive_ping_task = None
    mock_ws.close_connection_task = done_task

    client = WebSocketClient("ws://mockserver")
    await client.connect()

    # Execution
    await client.close()

    # Verification
    assert not client.is_connected()


@pytest.mark.asyncio
async def test_async_client_close_ws_close_exception(mock_websockets_connect):
    """Test that close() silently absorbs exceptions raised by ws.close()."""
    # Preparation
    mock_websockets_connect.return_value.close = AsyncMock(side_effect=Exception("ws close error"))
    client = WebSocketClient("ws://mockserver")
    await client.connect()

    # Execution: should not raise even though ws.close() raises
    await client.close()

    # Verification
    assert not client.is_connected()


def test_sync_client_destructor_connected_and_loop_teardown():
    """Test __del__ when connected and the loop was created by WebSocketClientSync.

    In a sync (non-async) test there is no running event loop, so
    WebSocketClientSync creates its own (_loop_created = True).  __del__ should
    close the open websocket connection and then shut down the owned loop.
    """
    # Directly wire up a mock websocket; no need for the websockets.connect patch
    # so we avoid introducing an unawaited-coroutine interaction with AsyncMock.
    client = WebSocketClientSync("ws://mockserver")
    assert client._loop_created is True

    mock_ws = MagicMock()
    mock_ws.open = True
    mock_ws.close = AsyncMock()
    client.client.websocket = mock_ws  # simulate connected state

    assert client.is_connected()

    # Execution
    client.__del__()

    # Verification: the owned loop must be closed after __del__
    assert client.loop.is_closed()


def test_sync_client_destructor_close_raises_in_del():
    """Cover lines 123-125: except branch when run_until_complete raises during close in __del__."""
    with patch("asyncio.get_running_loop") as mock_get_loop:
        mock_loop = MagicMock()
        mock_loop.is_closed.return_value = False
        mock_loop.is_running.return_value = False
        mock_get_loop.return_value = mock_loop

        client = WebSocketClientSync("ws://mockserver")

    # Simulate a connected websocket
    mock_ws = MagicMock()
    mock_ws.open = True
    client.client.websocket = mock_ws

    # Patch client.close so we don't get an unawaited-coroutine warning, and
    # make run_until_complete raise to exercise the except branch.
    with patch.object(client.client, "close", return_value=MagicMock()):
        mock_loop.run_until_complete.side_effect = Exception("close failed in __del__")
        # Should not raise – the except branch must swallow the error
        client.__del__()


def test_sync_client_destructor_outer_runtime_error():
    """Cover lines 153-155: outer except RuntimeError branch when loop.is_running() raises."""
    with patch("asyncio.get_running_loop") as mock_get_loop:
        mock_loop = MagicMock()
        mock_loop.is_closed.return_value = False
        mock_loop.is_running.side_effect = RuntimeError("loop in bad state")
        mock_get_loop.return_value = mock_loop

        client = WebSocketClientSync("ws://mockserver")
        # Should not raise – the outer except RuntimeError must swallow the error
        client.__del__()


def test_sync_client_destructor_outer_generic_exception():
    """Cover lines 156-158: outer except Exception branch when loop.is_running() raises non-Runtime."""
    with patch("asyncio.get_running_loop") as mock_get_loop:
        mock_loop = MagicMock()
        mock_loop.is_closed.return_value = False
        mock_loop.is_running.side_effect = ValueError("unexpected loop error")
        mock_get_loop.return_value = mock_loop

        client = WebSocketClientSync("ws://mockserver")
        # Should not raise – the outer except Exception must swallow the error
        client.__del__()


def test_sync_client_destructor_with_pending_tasks_and_loop_created():
    """Test __del__ cancels pending event-loop tasks when _loop_created is True.

    Covers the pending-tasks cancellation branch inside __del__.
    """
    # Preparation: create a client with its own event loop (not connected)
    # No asyncio.get_running_loop patch: sync test has no running loop.
    client = WebSocketClientSync("ws://mockserver")
    assert client._loop_created is True

    # Plant a long-running task on the loop so __del__ has something to cancel
    async def _forever() -> None:
        await asyncio.sleep(3600)

    task = client.loop.create_task(_forever())

    # Execution
    client.__del__()

    # Verification: task must be cancelled and loop closed
    assert task.done()
    assert client.loop.is_closed()
