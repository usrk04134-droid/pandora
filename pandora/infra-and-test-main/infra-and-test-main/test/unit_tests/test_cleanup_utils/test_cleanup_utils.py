"""Unit tests for testzilla.utility.cleanup_utils."""

import asyncio
from unittest.mock import MagicMock, patch

import pytest

from testzilla.utility.cleanup_utils import cleanup_web_hmi_client


def test_cleanup_web_hmi_client_basic():
    """Test cleanup_web_hmi_client with basic happy path."""
    # Preparation
    mock_web_hmi = MagicMock()
    mock_web_hmi.close.return_value = None
    mock_web_hmi.ws_client = None

    # Execution: should not raise
    cleanup_web_hmi_client(mock_web_hmi)

    # Verification
    mock_web_hmi.close.assert_called_once()


def test_cleanup_web_hmi_client_close_raises():
    """Test cleanup_web_hmi_client when web_hmi.close() raises exception."""
    # Preparation
    mock_web_hmi = MagicMock()
    mock_web_hmi.close.side_effect = Exception("Close failed")
    mock_web_hmi.ws_client = None

    # Execution: should not raise
    cleanup_web_hmi_client(mock_web_hmi)

    # Verification
    mock_web_hmi.close.assert_called_once()


def test_cleanup_web_hmi_client_with_pending_tasks():
    """Test cleanup_web_hmi_client cancels pending tasks in event loop."""
    # Preparation
    mock_web_hmi = MagicMock()
    mock_web_hmi.close.return_value = None

    # Create a real event loop for testing
    loop = asyncio.new_event_loop()

    # Create a mock task
    async def _dummy():
        await asyncio.sleep(3600)

    task = loop.create_task(_dummy())

    # Mock ws_client with loop
    mock_ws_client = MagicMock()
    mock_ws_client.loop = loop
    mock_ws_client._loop_created = False
    mock_web_hmi.ws_client = mock_ws_client

    # Execution
    cleanup_web_hmi_client(mock_web_hmi)

    # Verification: task should be cancelled
    assert task.done()

    # Cleanup
    loop.close()


def test_cleanup_web_hmi_client_closes_owned_loop():
    """Test cleanup_web_hmi_client closes loop when _loop_created is True."""
    # Preparation
    mock_web_hmi = MagicMock()
    mock_web_hmi.close.return_value = None

    # Create a real event loop
    loop = asyncio.new_event_loop()

    # Mock ws_client with owned loop
    mock_ws_client = MagicMock()
    mock_ws_client.loop = loop
    mock_ws_client._loop_created = True
    mock_web_hmi.ws_client = mock_ws_client

    # Execution
    cleanup_web_hmi_client(mock_web_hmi)

    # Verification: loop should be closed
    assert loop.is_closed()


def test_cleanup_web_hmi_client_no_ws_client_uses_get_event_loop():
    """Test cleanup_web_hmi_client falls back to asyncio.get_event_loop()."""
    # Preparation
    mock_web_hmi = MagicMock()
    mock_web_hmi.close.return_value = None
    mock_web_hmi.ws_client = None

    # Create and set a test loop
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)

    # Create a pending task
    async def _dummy():
        await asyncio.sleep(3600)

    task = loop.create_task(_dummy())

    try:
        # Execution
        cleanup_web_hmi_client(mock_web_hmi)

        # Verification: task should be cancelled
        assert task.done()
    finally:
        # Cleanup
        if not loop.is_closed():
            loop.close()
        asyncio.set_event_loop(None)


def test_cleanup_web_hmi_client_loop_is_running():
    """Test cleanup_web_hmi_client when loop is running (should skip cleanup)."""
    # Preparation
    mock_web_hmi = MagicMock()
    mock_web_hmi.close.return_value = None

    # Mock a running loop
    mock_loop = MagicMock()
    mock_loop.is_closed.return_value = False
    mock_loop.is_running.return_value = True  # Loop is running

    mock_ws_client = MagicMock()
    mock_ws_client.loop = mock_loop
    mock_web_hmi.ws_client = mock_ws_client

    # Execution: should not raise
    cleanup_web_hmi_client(mock_web_hmi)

    # Verification: should not attempt to run_until_complete on running loop
    mock_loop.run_until_complete.assert_not_called()


def test_cleanup_web_hmi_client_loop_closed():
    """Test cleanup_web_hmi_client when loop is already closed."""
    # Preparation
    mock_web_hmi = MagicMock()
    mock_web_hmi.close.return_value = None

    # Mock a closed loop
    mock_loop = MagicMock()
    mock_loop.is_closed.return_value = True

    mock_ws_client = MagicMock()
    mock_ws_client.loop = mock_loop
    mock_web_hmi.ws_client = mock_ws_client

    # Execution: should not raise
    cleanup_web_hmi_client(mock_web_hmi)

    # Verification: should not try to use closed loop
    mock_loop.run_until_complete.assert_not_called()


def test_cleanup_web_hmi_client_gather_exception():
    """Test cleanup_web_hmi_client when gathering tasks encounters errors."""
    # Preparation
    mock_web_hmi = MagicMock()
    mock_web_hmi.close.return_value = None

    # Create a real event loop for testing
    loop = asyncio.new_event_loop()

    # Create a mock task that will be cancelled
    async def _dummy():
        try:
            await asyncio.sleep(3600)
        except asyncio.CancelledError:
            raise  # Re-raise to simulate cancellation

    task = loop.create_task(_dummy())

    # Mock ws_client with loop
    mock_ws_client = MagicMock()
    mock_ws_client.loop = loop
    mock_ws_client._loop_created = False
    mock_web_hmi.ws_client = mock_ws_client

    # Execution: should handle cancellation gracefully
    cleanup_web_hmi_client(mock_web_hmi)

    # Verification: task should be cancelled
    assert task.done()

    # Cleanup
    loop.close()


def test_cleanup_web_hmi_client_gather_runtime_error():
    """Test cleanup_web_hmi_client when run_until_complete raises RuntimeError."""
    # Preparation
    mock_web_hmi = MagicMock()
    mock_web_hmi.close.return_value = None

    # Create a real loop
    loop = asyncio.new_event_loop()

    # Create a task
    async def _dummy():
        await asyncio.sleep(3600)

    task = loop.create_task(_dummy())

    # Mock ws_client
    mock_ws_client = MagicMock()
    mock_ws_client.loop = loop
    mock_ws_client._loop_created = False
    mock_web_hmi.ws_client = mock_ws_client

    # Patch run_until_complete to raise RuntimeError on gather
    original_run = loop.run_until_complete
    call_count = [0]

    def mock_run(coro):
        call_count[0] += 1
        if call_count[0] == 1:  # First call (gather)
            raise RuntimeError("Loop error during gather")
        return original_run(coro)

    loop.run_until_complete = mock_run

    # Execution: should not raise
    cleanup_web_hmi_client(mock_web_hmi)

    # Cleanup
    if not loop.is_closed():
        for t in asyncio.all_tasks(loop):
            t.cancel()
        loop.close()



def test_cleanup_web_hmi_client_sleep_raises_runtime_error():
    """Test cleanup_web_hmi_client when sleep() raises RuntimeError (breaks loop)."""
    # Preparation
    mock_web_hmi = MagicMock()
    mock_web_hmi.close.return_value = None

    # Mock loop
    mock_loop = MagicMock()
    mock_loop.is_closed.return_value = False
    mock_loop.is_running.return_value = False

    with patch("asyncio.all_tasks", return_value=[]):
        # First sleep raises, should break the loop
        mock_loop.run_until_complete.side_effect = [
            RuntimeError("Loop closed during sleep")
        ]

        mock_ws_client = MagicMock()
        mock_ws_client.loop = mock_loop
        mock_ws_client._loop_created = False
        mock_web_hmi.ws_client = mock_ws_client

        # Execution: should not raise
        cleanup_web_hmi_client(mock_web_hmi)


def test_cleanup_web_hmi_client_outer_runtime_error():
    """Test cleanup_web_hmi_client outer exception handler for RuntimeError."""
    # Preparation
    mock_web_hmi = MagicMock()
    mock_web_hmi.close.return_value = None
    mock_web_hmi.ws_client = MagicMock()

    with patch("asyncio.get_event_loop", side_effect=RuntimeError("No event loop")):
        # Execution: should not raise
        cleanup_web_hmi_client(mock_web_hmi)

        # Verification
        mock_web_hmi.close.assert_called_once()


def test_cleanup_web_hmi_client_outer_value_error():
    """Test cleanup_web_hmi_client outer exception handler for ValueError."""
    # Preparation
    mock_web_hmi = MagicMock()
    mock_web_hmi.close.return_value = None
    mock_web_hmi.ws_client = MagicMock()

    with patch("asyncio.get_event_loop", side_effect=ValueError("Invalid loop")):
        # Execution: should not raise
        cleanup_web_hmi_client(mock_web_hmi)

        # Verification
        mock_web_hmi.close.assert_called_once()
