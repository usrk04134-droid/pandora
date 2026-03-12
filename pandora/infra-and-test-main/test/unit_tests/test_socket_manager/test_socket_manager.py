"""Module for testing methods in socket_manager.py"""

import socket
from ipaddress import IPv4Address
from unittest.mock import MagicMock, PropertyMock, patch

import pytest
from testzilla.utility.socket_manager import SocketManager


def test_socket_manager_connect(socket_manager, mock_socket):
    """Test the connect method."""
    # Execution
    socket_manager.connect(retries=0)

    # Verification
    mock_socket.setsockopt.assert_called_once_with(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
    mock_socket.settimeout.assert_called_once_with(SocketManager.TIMEOUT)
    mock_socket.connect.assert_called_once_with(("192.168.1.100", 9221))


def test_socket_manager_connect_with_custom_timeout(socket_manager, mock_socket):
    """Test the connect method with a custom timeout."""
    # Preparation
    custom_timeout = 20

    # Execution
    socket_manager.connect(timeout=custom_timeout, retries=0)

    # Verification
    mock_socket.settimeout.assert_called_once_with(custom_timeout)


@patch("testzilla.utility.socket_manager.time.sleep", return_value=None)
def test_socket_manager_connect_succeed_on_2nd_attempt(mock_sleep, socket_manager, mock_socket):
    """Test the connect method with retries."""
    # Preparation
    mock_socket.connect.side_effect = [OSError("Unknown host"), None]

    # Execution
    socket_manager.connect(retries=3)

    # Verification
    assert mock_sleep.call_count == 1
    assert mock_socket.settimeout.call_count == 2
    assert mock_socket.connect.call_count == 2
    assert mock_socket.setsockopt.call_count == 2


@patch("testzilla.utility.socket_manager.time.sleep", return_value=None)
def test_socket_manager_connect_fails_after_all_attempts(mock_sleep, socket_manager, mock_socket):
    """Test the connect method with retries."""
    # Preparation
    mock_socket.connect.side_effect = [
        OSError("Unknown host"),
        OSError("Unknown host"),
        OSError("Unknown host"),
        OSError("Unknown host"),
    ]

    # Execution
    with pytest.raises(OSError):
        socket_manager.connect(retries=3)

    # Verification
    assert mock_sleep.call_count == 3
    assert mock_socket.setsockopt.call_count == 4
    assert mock_socket.settimeout.call_count == 4
    assert mock_socket.connect.call_count == 4


def test_socket_manager_connect_with_socket(socket_manager, mock_socket):
    """Test the connect method."""
    # Preparation
    socket_manager.sock = MagicMock()

    # Execution
    socket_manager.connect()

    # Verification
    mock_socket.connect.assert_not_called()


def test_socket_manager_close(socket_manager, mock_socket):
    """Test the close method."""
    # Preparation
    socket_manager.connect()

    # Execution
    socket_manager.close()

    # Verification
    mock_socket.close.assert_called_once()


def test_socket_manager_close_without_socket(socket_manager, mock_socket):
    """Test the close method when socket was never opened."""
    # Execution
    socket_manager.close()

    # Verification
    mock_socket.close.assert_not_called()


def test_socket_manager_is_connected_socket_dead(socket_manager, mock_socket):
    """Test is_connected when socket.send() raises exception."""
    # Preparation
    socket_manager.connect()
    mock_socket.send.side_effect = OSError("Connection dead")

    # Execution
    result = socket_manager.is_connected

    # Verification
    assert result is False
    assert socket_manager.sock is None
    mock_socket.close.assert_called_once()


def test_socket_manager_cleanup_socket_close_raises(socket_manager, mock_socket):
    """Test _cleanup_socket when close() raises OSError."""
    # Preparation
    socket_manager.connect()
    mock_socket.close.side_effect = OSError("Close failed")

    # Execution: should not raise
    socket_manager._cleanup_socket()

    # Verification
    assert socket_manager.sock is None


def test_socket_manager_send_auto_connect(socket_manager, mock_socket):
    """Test send() auto-connects when not connected."""
    # Execution
    socket_manager.send(b"test data")

    # Verification
    mock_socket.connect.assert_called_once()
    mock_socket.sendall.assert_called_once_with(b"test data")


def test_socket_manager_send_raises_when_sendall_fails(socket_manager, mock_socket):
    """Test send() when sendall() raises OSError."""
    # Preparation
    socket_manager.connect()
    mock_socket.sendall.side_effect = OSError("Send failed")

    # Execution and Verification
    with pytest.raises(OSError, match="Send failed"):
        socket_manager.send(b"data")

    # Socket should be cleaned up
    assert socket_manager.sock is None


def test_socket_manager_recv_auto_connect(socket_manager, mock_socket):
    """Test recv() auto-connects when not connected."""
    # Preparation
    mock_socket.recv.return_value = b"response"

    # Execution
    result = socket_manager.recv()

    # Verification
    mock_socket.connect.assert_called_once()
    assert result == b"response"


def test_socket_manager_recv_raises_when_recv_fails(socket_manager, mock_socket):
    """Test recv() when socket.recv() raises OSError."""
    # Preparation
    socket_manager.connect()
    mock_socket.recv.side_effect = OSError("Receive failed")

    # Execution and Verification
    with pytest.raises(OSError, match="Receive failed"):
        socket_manager.recv()

    # Socket should be cleaned up
    assert socket_manager.sock is None


def test_socket_manager_close_with_exception(socket_manager, mock_socket):
    """Test close() when socket.close() raises OSError."""
    # Preparation
    socket_manager.connect()
    mock_socket.close.side_effect = OSError("Close error")

    # Execution: should not raise
    socket_manager.close()

    # Verification
    assert socket_manager.sock is None


def test_socket_manager_context_manager(socket_manager, mock_socket):
    """Test __enter__ and __exit__ context manager methods."""
    # Execution
    with socket_manager as sm:
        assert sm is socket_manager
        mock_socket.connect.assert_called_once()

    # Verification: __exit__ should have called close()
    mock_socket.close.assert_called_once()


def test_socket_manager_destructor(socket_manager, mock_socket):
    """Test __del__ calls close()."""
    # Preparation
    socket_manager.connect()

    # Execution
    socket_manager.__del__()

    # Verification
    mock_socket.close.assert_called_once()
    assert socket_manager.sock is None


def test_socket_manager_send_with_none_sock_after_is_connected():
    """Test send() when sock becomes None after is_connected check."""
    # Edge case: is_connected passes but sock is None
    sm = SocketManager(IPv4Address("1.2.3.4"), 9221)

    # Patch is_connected to return True
    with patch.object(type(sm), 'is_connected', new=PropertyMock(return_value=True)):
        sm.sock = None  # Now sock is None but is_connected returns True

        with pytest.raises(OSError, match="Socket is not connected"):
            sm.send(b"data")


def test_socket_manager_recv_with_none_sock_after_is_connected():
    """Test recv() when sock becomes None after is_connected check."""
    # Edge case: is_connected passes but sock is None
    sm = SocketManager(IPv4Address("1.2.3.4"), 9221)

    # Patch is_connected to return True
    with patch.object(type(sm), 'is_connected', new=PropertyMock(return_value=True)):
        sm.sock = None  # Now sock is None but is_connected returns True

        with pytest.raises(OSError, match="Socket is not connected"):
            sm.recv()
