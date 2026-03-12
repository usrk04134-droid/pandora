"""Conftest file for fixtures."""

import os
import sys
from ipaddress import IPv4Address
from unittest import mock
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from testzilla.power_supply.aimtti_cpx200dp import AimTTiCPX200DPPowerSupply
from testzilla.power_supply.keysight_e36234a import KeysightE36234APowerSupply
from testzilla.utility.socket_manager import SocketManager
from testzilla.remote_comm.remote_host import RemoteHostManager


@pytest.fixture
@patch("testzilla.remote_comm.remote_host.Connection")
def remote_host_manager(mock_connection):
    """Fixture for remote host manager."""
    mock_connection.return_value = MagicMock()
    manager = RemoteHostManager(hostname="192.168.100.200", username="user", password="pass")
    return manager


@pytest.fixture
def aimtti_cpx200dp_device():
    """Fixture for power supply instance with mocked socket parts."""
    connection_params = {"ip_address": IPv4Address("192.168.0.1")}
    power_supply = AimTTiCPX200DPPowerSupply(connection_params)

    # Mock the socket manager with all necessary methods and properties
    power_supply.socket_manager = mock.Mock()
    power_supply.socket_manager.is_connected = True
    power_supply.socket_manager.send = mock.Mock()
    power_supply.socket_manager.recv = mock.Mock()
    power_supply.socket_manager.connect = mock.Mock()
    power_supply.socket_manager.close = mock.Mock()

    # Set the correct connection state that the implementation expects
    power_supply._device_validated = True

    return power_supply


@pytest.fixture
def cpx200dp_device_disconnected():
    """Fixture for power supply instance in disconnected state."""
    connection_params = {"ip_address": IPv4Address("192.168.0.1")}
    power_supply = AimTTiCPX200DPPowerSupply(connection_params)

    # Mock the socket manager
    power_supply.socket_manager = mock.Mock()
    power_supply.socket_manager.is_connected = False
    power_supply.socket_manager.send = mock.Mock()
    power_supply.socket_manager.recv = mock.Mock()
    power_supply.socket_manager.connect = mock.Mock()
    power_supply.socket_manager.close = mock.Mock()

    # Set disconnected state
    power_supply._device_validated = False

    return power_supply


@pytest.fixture
def keysight_e36234a_device():
    """Fixture for Keysight E36234A power supply instance with mocked socket parts."""
    connection_params = {"ip_address": IPv4Address("192.168.0.1")}
    power_supply = KeysightE36234APowerSupply(connection_params)

    # Mock the socket manager with all necessary methods and properties
    power_supply.socket_manager = mock.Mock()
    power_supply.socket_manager.is_connected = True
    power_supply.socket_manager.send = mock.Mock()
    power_supply.socket_manager.recv = mock.Mock()
    power_supply.socket_manager.connect = mock.Mock()
    power_supply.socket_manager.close = mock.Mock()

    # Set the correct connection state that the implementation expects
    power_supply._device_validated = True

    return power_supply


@pytest.fixture
def keysight_e36234a_device_disconnected():
    """Fixture for Keysight E36234A power supply instance in disconnected state."""
    connection_params = {"ip_address": IPv4Address("192.168.0.1")}
    power_supply = KeysightE36234APowerSupply(connection_params)

    # Mock the socket manager
    power_supply.socket_manager = mock.Mock()
    power_supply.socket_manager.is_connected = False
    power_supply.socket_manager.send = mock.Mock()
    power_supply.socket_manager.recv = mock.Mock()
    power_supply.socket_manager.connect = mock.Mock()
    power_supply.socket_manager.close = mock.Mock()

    # Set disconnected state
    power_supply._device_validated = False

    return power_supply


@pytest.fixture
def mock_socket():
    """Fixture for mocking the socket object."""
    with patch("socket.socket") as mock_socket_class:
        mock_socket_instance = MagicMock()
        mock_socket_class.return_value = mock_socket_instance
        yield mock_socket_instance


@pytest.fixture
def socket_manager():
    """Fixture for creating a SocketManager instance."""
    ip_address = IPv4Address("192.168.1.100")
    port = 9221
    return SocketManager(ip_address, port)


@pytest.fixture
def mock_websocket_client_sync():
    with patch("testzilla.adaptio_web_hmi.adaptio_web_hmi.WebSocketClientSync") as MockWebSocket:
        instance = MockWebSocket.return_value
        instance.connect.return_value = None
        instance.is_connected.return_value = True
        instance.send_message.return_value = None
        instance.receive_message.return_value = '{"name": "", "payload": {}}'
        yield instance


@pytest.fixture
def mock_websockets_connect():
    """Mocks `websockets.connect` and returns a mock websocket object."""
    with patch("testzilla.utility.websocket_client.websockets.connect", new_callable=AsyncMock) as mock_ws_connect:
        mock_ws_connect.return_value.open = True  # Simulate an open WebSocket connection
        yield mock_ws_connect