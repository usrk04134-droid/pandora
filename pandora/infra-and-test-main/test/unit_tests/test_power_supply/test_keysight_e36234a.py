"""Module for testing methods in keysight_e36234a.py"""

from unittest.mock import MagicMock, patch
import pytest
from testzilla.power_supply.keysight_e36234a import KeysightE36234APowerSupply
from testzilla.power_supply.abstract_power_supply import (
    PowerSupplyParameterError,
    PowerSupplyConnectionError,
    PowerSupplyError
)


class TestKeysightE36234ABasicFunctionality:
    """Tests for basic Keysight E36234A functionality."""

    def test_invalid_output(self):
        """Test using an invalid output number."""
        # Create a mock device
        connection_params = {"ip_address": "192.168.0.1"}
        device = KeysightE36234APowerSupply(connection_params)

        # Test with invalid output
        with pytest.raises(PowerSupplyParameterError, match="Invalid output: 5"):
            device.validate_output(5)

    def test_read_identity(self, keysight_e36234a_device):
        """Test read_identity method."""
        # Fix the device state to simulate proper connection
        keysight_e36234a_device._device_validated = True
        keysight_e36234a_device.socket_manager.is_connected = True
        keysight_e36234a_device.socket_manager.recv.return_value = b"KEYSIGHT TECHNOLOGIES,E36234A,MY12345678,1.0.0\n"

        # Execution
        identity = keysight_e36234a_device.read_identity()

        # Verification
        keysight_e36234a_device.socket_manager.send.assert_called_once_with(b"*IDN?\n")
        keysight_e36234a_device.socket_manager.recv.assert_called_once_with(4096)
        assert identity == "KEYSIGHT TECHNOLOGIES,E36234A,MY12345678,1.0.0"


class TestKeysightE36234AVoltageOperations:
    """Tests for voltage-related operations."""

    @pytest.mark.parametrize("output", [1, 2])
    def test_read_voltage(self, output, keysight_e36234a_device):
        """Test reading voltage."""
        # Fix the device state
        keysight_e36234a_device._device_validated = True
        keysight_e36234a_device.socket_manager.is_connected = True
        keysight_e36234a_device.socket_manager.recv.return_value = b"25.5\n"

        # Execution
        voltage = keysight_e36234a_device.read_voltage(output=output)

        # Verification
        expected_command = f"MEAS:VOLT? (@{output})\n".encode()
        keysight_e36234a_device.socket_manager.send.assert_called_once_with(expected_command)
        keysight_e36234a_device.socket_manager.recv.assert_called_once_with(4096)
        assert voltage == 25.5

    def test_read_voltage_on_unavailable_output(self, keysight_e36234a_device):
        """Test reading voltage on an unavailable output."""
        # Execution
        with pytest.raises(PowerSupplyParameterError, match="Invalid output: 3"):
            keysight_e36234a_device.read_voltage(output=3)  # Unavailable output 3

        # Verification - no socket operations should occur
        keysight_e36234a_device.socket_manager.send.assert_not_called()
        keysight_e36234a_device.socket_manager.recv.assert_not_called()

    @pytest.mark.parametrize("output", [1, 2])
    def test_set_voltage(self, output, keysight_e36234a_device):
        """Test setting voltage."""
        # Fix the device state
        keysight_e36234a_device._device_validated = True
        keysight_e36234a_device.socket_manager.is_connected = True

        # Mock the validate_last_command to avoid additional socket calls
        with patch.object(keysight_e36234a_device, 'validate_last_command'):
            # Execution
            keysight_e36234a_device.set_voltage(voltage=30.0, output=output)

            # Verification
            expected_command = f"SOUR:VOLT 30.0,(@{output})\n".encode()
            keysight_e36234a_device.socket_manager.send.assert_called_once_with(expected_command)

    @pytest.mark.parametrize("output", [1, 2])
    def test_set_voltage_with_more_than_upper_limit(self, keysight_e36234a_device, output):
        """Test setting voltage with input more than the upper limit."""
        # Execution
        with pytest.raises(PowerSupplyParameterError, match="Voltage 100.0 out of range"):
            keysight_e36234a_device.set_voltage(voltage=100.0, output=output)

        # Verification - no socket operations should occur
        keysight_e36234a_device.socket_manager.send.assert_not_called()
        keysight_e36234a_device.socket_manager.recv.assert_not_called()

    @pytest.mark.parametrize("output", [1, 2])
    def test_set_voltage_with_less_than_lower_limit(self, keysight_e36234a_device, output):
        """Test setting voltage with input less than the lower limit."""
        # Execution
        with pytest.raises(PowerSupplyParameterError, match="Voltage -100.0 out of range"):
            keysight_e36234a_device.set_voltage(voltage=-100.0, output=output)

        # Verification - no socket operations should occur
        keysight_e36234a_device.socket_manager.send.assert_not_called()
        keysight_e36234a_device.socket_manager.recv.assert_not_called()

    def test_set_voltage_on_unavailable_output(self, keysight_e36234a_device):
        """Test setting voltage on an unavailable output."""
        # Execution
        with pytest.raises(PowerSupplyParameterError, match="Invalid output: 3"):
            keysight_e36234a_device.set_voltage(output=3, voltage=40.0)  # Unavailable output 3

        # Verification - no socket operations should occur
        keysight_e36234a_device.socket_manager.send.assert_not_called()
        keysight_e36234a_device.socket_manager.recv.assert_not_called()

    @pytest.mark.parametrize("output", [1, 2])
    def test_read_voltage_protection(self, output, keysight_e36234a_device):
        """Test reading voltage protection level."""
        # Fix the device state
        keysight_e36234a_device._device_validated = True
        keysight_e36234a_device.socket_manager.is_connected = True
        keysight_e36234a_device.socket_manager.recv.return_value = b"35.0\n"

        # Execution
        level = keysight_e36234a_device.read_voltage_protection(output=output)

        # Verification
        expected_command = f"VOLT:PROT? (@{output})\n".encode()
        keysight_e36234a_device.socket_manager.send.assert_called_once_with(expected_command)
        keysight_e36234a_device.socket_manager.recv.assert_called_once_with(4096)
        assert level == 35.0

    @pytest.mark.parametrize("output", [1, 2])
    def test_set_voltage_protection(self, output, keysight_e36234a_device):
        """Test setting voltage protection level."""
        # Fix the device state
        keysight_e36234a_device._device_validated = True
        keysight_e36234a_device.socket_manager.is_connected = True

        # Mock the validate_last_command to avoid additional socket calls
        with patch.object(keysight_e36234a_device, 'validate_last_command'):
            # Execution
            keysight_e36234a_device.set_voltage_protection(level=45.0, output=output)

            # Verification - uses voltage protection command
            expected_command = f"VOLT:PROT 45.0,(@{output})\n".encode()
            keysight_e36234a_device.socket_manager.send.assert_called_once_with(expected_command)


class TestKeysightE36234ACurrentOperations:
    """Tests for current-related operations."""

    @pytest.mark.parametrize("output", [1, 2])
    def test_read_current(self, output, keysight_e36234a_device):
        """Test reading current."""
        # Fix the device state
        keysight_e36234a_device._device_validated = True
        keysight_e36234a_device.socket_manager.is_connected = True
        keysight_e36234a_device.socket_manager.recv.return_value = b"2.5\n"

        # Execution
        current = keysight_e36234a_device.read_current(output=output)

        # Verification
        expected_command = f"MEAS:CURR? (@{output})\n".encode()
        keysight_e36234a_device.socket_manager.send.assert_called_once_with(expected_command)
        keysight_e36234a_device.socket_manager.recv.assert_called_once_with(4096)
        assert current == 2.5

    @pytest.mark.parametrize("output", [1, 2])
    def test_set_current(self, output, keysight_e36234a_device):
        """Test setting current."""
        # Fix the device state
        keysight_e36234a_device._device_validated = True
        keysight_e36234a_device.socket_manager.is_connected = True

        # Mock the validate_last_command to avoid additional socket calls
        with patch.object(keysight_e36234a_device, 'validate_last_command'):
            # Execution
            keysight_e36234a_device.set_current(current=5.0, output=output)

            # Verification
            expected_command = f"SOUR:CURR 5.0,(@{output})\n".encode()
            keysight_e36234a_device.socket_manager.send.assert_called_once_with(expected_command)

    @pytest.mark.parametrize("output", [1, 2])
    def test_set_current_with_more_than_upper_limit(self, keysight_e36234a_device, output):
        """Test setting current with input more than upper limit."""
        # Execution
        with pytest.raises(PowerSupplyParameterError, match="Current 12.0 out of range"):
            keysight_e36234a_device.set_current(current=12.0, output=output)

        # Verification - no socket operations should occur
        keysight_e36234a_device.socket_manager.send.assert_not_called()
        keysight_e36234a_device.socket_manager.recv.assert_not_called()

    @pytest.mark.parametrize("output", [1, 2])
    def test_set_current_with_less_than_lower_limit(self, keysight_e36234a_device, output):
        """Test setting current with input less than the lower limit."""
        # Execution
        with pytest.raises(PowerSupplyParameterError, match="Current -12.0 out of range"):
            keysight_e36234a_device.set_current(current=-12.0, output=output)

        # Verification - no socket operations should occur
        keysight_e36234a_device.socket_manager.send.assert_not_called()
        keysight_e36234a_device.socket_manager.recv.assert_not_called()



class TestKeysightE36234AConnectionHandling:
    """Tests for connection management."""

    def test_auto_connect_on_read_voltage(self, keysight_e36234a_device_disconnected):
        """Test that read_voltage automatically connects if disconnected."""
        # Setup - device is disconnected
        assert not keysight_e36234a_device_disconnected.is_ready

        # Mock the connect method and subsequent recv
        keysight_e36234a_device_disconnected.socket_manager.recv.return_value = b"25.5\n"

        with patch.object(keysight_e36234a_device_disconnected, 'connect') as mock_connect:
            # The connect method should set these states
            def mock_connect_side_effect():
                keysight_e36234a_device_disconnected._device_validated = True
                keysight_e36234a_device_disconnected.socket_manager.is_connected = True

            mock_connect.side_effect = mock_connect_side_effect

            # Execute
            voltage = keysight_e36234a_device_disconnected.read_voltage(1)

            # Verify
            mock_connect.assert_called_once()
            assert voltage == 25.5

    def test_auto_connect_on_set_voltage(self, keysight_e36234a_device_disconnected):
        """Test that set_voltage automatically connects if disconnected."""
        # Setup - device is disconnected
        assert not keysight_e36234a_device_disconnected.is_ready

        with patch.object(keysight_e36234a_device_disconnected, 'connect') as mock_connect, \
             patch.object(keysight_e36234a_device_disconnected, 'validate_last_command'):

            # The connect method should set these states
            def mock_connect_side_effect():
                keysight_e36234a_device_disconnected._device_validated = True
                keysight_e36234a_device_disconnected.socket_manager.is_connected = True

            mock_connect.side_effect = mock_connect_side_effect

            # Execute
            keysight_e36234a_device_disconnected.set_voltage(12.0, 1)

            # Verify
            mock_connect.assert_called_once()
            keysight_e36234a_device_disconnected.socket_manager.send.assert_called_with(b"SOUR:VOLT 12.0,(@1)\n")

    def test_connection_validation(self):
        """Test device identity validation during connection."""
        connection_params = {"ip_address": "192.168.0.1"}
        device = KeysightE36234APowerSupply(connection_params)
        device.socket_manager = MagicMock()
        device.socket_manager.connect.return_value = None
        device.socket_manager.is_connected = True

        # Test successful validation
        with patch.object(device, 'read_identity', return_value="KEYSIGHT TECHNOLOGIES,E36234A,MY12345678,1.0.0"):
            device.connect()
            assert device._device_validated is True

        # Test validation with unexpected identity raises error
        device._device_validated = False
        with patch.object(device, 'read_identity', return_value="UNKNOWN DEVICE"):
            with pytest.raises(PowerSupplyConnectionError, match="Failed to connect to E36234A"):
                device.connect()
            assert device._device_validated is False


class TestKeysightE36234AErrorHandling:
    """Tests for error handling and validation."""

    def test_socket_error_handling(self, keysight_e36234a_device):
        """Test handling of socket errors."""
        # Simulate socket error during send
        keysight_e36234a_device.socket_manager.send.side_effect = OSError("Connection lost")

        with pytest.raises(PowerSupplyParameterError, match="Failed to send command"):
            keysight_e36234a_device.set_voltage(12.0, 1)

    def test_socket_error_invalidates_device(self, keysight_e36234a_device):
        """Test that socket errors invalidate device validation."""
        keysight_e36234a_device._device_validated = True
        keysight_e36234a_device.socket_manager.send.side_effect = OSError("Connection lost")

        with pytest.raises(PowerSupplyParameterError):
            keysight_e36234a_device.set_voltage(12.0, 1)

        # Device should be invalidated after error
        assert keysight_e36234a_device._device_validated is False

    def test_parse_numeric_response_error(self, keysight_e36234a_device):
        """Test error handling in numeric response parsing."""
        keysight_e36234a_device.socket_manager.recv.return_value = b"ERROR: Invalid command\n"

        with pytest.raises(ValueError):
            keysight_e36234a_device.read_voltage(1)

    def test_validate_last_command_with_errors(self, keysight_e36234a_device):
        """Test validate_last_command when errors are present."""
        with patch.object(keysight_e36234a_device, 'check_errors', return_value=["Error 1", "Error 2"]):
            # The base class raises PowerSupplyError, not PowerSupplyParameterError
            with pytest.raises(PowerSupplyError, match="Error 1; Error 2"):
                keysight_e36234a_device.validate_last_command()


class TestKeysightE36234AErrorFunctions:
    """Tests for error checking and clearing."""

    def test_check_errors_no_error(self, keysight_e36234a_device):
        """Test checking device errors when no errors are present."""
        # Fix the device state
        keysight_e36234a_device._device_validated = True
        keysight_e36234a_device.socket_manager.is_connected = True
        keysight_e36234a_device.socket_manager.recv.return_value = b"+0,\"No error\"\n"

        # Execution
        errors = keysight_e36234a_device.check_errors()

        # Verification
        keysight_e36234a_device.socket_manager.send.assert_called_once_with(b"SYST:ERR?\n")
        keysight_e36234a_device.socket_manager.recv.assert_called_once_with(4096)
        assert errors == []

    def test_check_errors_with_error(self, keysight_e36234a_device):
        """Test checking device errors when errors are present."""
        # Fix the device state
        keysight_e36234a_device._device_validated = True
        keysight_e36234a_device.socket_manager.is_connected = True
        keysight_e36234a_device.socket_manager.recv.return_value = b"-113,\"Undefined header\"\n"

        # Execution
        errors = keysight_e36234a_device.check_errors()

        # Verification
        keysight_e36234a_device.socket_manager.send.assert_called_once_with(b"SYST:ERR?\n")
        keysight_e36234a_device.socket_manager.recv.assert_called_once_with(4096)
        assert errors == ["-113,\"Undefined header\""]

    def test_check_errors_with_malformed_response(self, keysight_e36234a_device):
        """Test checking device errors with unexpected response format."""
        # Fix the device state
        keysight_e36234a_device._device_validated = True
        keysight_e36234a_device.socket_manager.is_connected = True
        keysight_e36234a_device.socket_manager.recv.return_value = b"UNEXPECTED FORMAT\n"

        # Execution
        errors = keysight_e36234a_device.check_errors()

        # Verification
        assert errors == ["UNEXPECTED FORMAT"]

    def test_check_errors_with_exception(self, keysight_e36234a_device):
        """Test check_errors when communication fails."""
        keysight_e36234a_device.socket_manager.send.side_effect = OSError("Connection failed")

        # Execution
        errors = keysight_e36234a_device.check_errors()

        # Verification
        assert len(errors) == 1
        assert "Failed to check errors" in errors[0]

    def test_clear_errors(self, keysight_e36234a_device):
        """Test clearing device errors using *CLS."""
        # Fix the device state
        keysight_e36234a_device._device_validated = True
        keysight_e36234a_device.socket_manager.is_connected = True

        # Execution
        keysight_e36234a_device.clear_errors()

        # Verification
        keysight_e36234a_device.socket_manager.send.assert_called_once_with(b"*CLS\n")

    def test_clear_errors_with_exception(self, keysight_e36234a_device):
        """Test clear_errors when communication fails."""
        keysight_e36234a_device.socket_manager.send.side_effect = OSError("Connection failed")

        # Should not raise exception, just log warning
        keysight_e36234a_device.clear_errors()


class TestKeysightE36234ARangeValidation:
    """Tests for parameter range validation."""

    def test_voltage_range_validation(self):
        """Test voltage range validation."""
        connection_params = {"ip_address": "192.168.0.1"}
        device = KeysightE36234APowerSupply(connection_params)

        # Valid voltage
        device.validate_voltage(30.0)  # Should not raise

        # Invalid voltages
        with pytest.raises(PowerSupplyParameterError, match="Voltage.*out of range"):
            device.validate_voltage(-5.0)

        with pytest.raises(PowerSupplyParameterError, match="Voltage.*out of range"):
            device.validate_voltage(100.0)

    def test_current_range_validation(self):
        """Test current range validation."""
        connection_params = {"ip_address": "192.168.0.1"}
        device = KeysightE36234APowerSupply(connection_params)

        # Valid current
        device.validate_current(5.0)  # Should not raise

        # Invalid currents
        with pytest.raises(PowerSupplyParameterError, match="Current.*out of range"):
            device.validate_current(-1.0)

        with pytest.raises(PowerSupplyParameterError, match="Current.*out of range"):
            device.validate_current(15.0)

    def test_output_validation(self):
        """Test output number validation."""
        connection_params = {"ip_address": "192.168.0.1"}
        device = KeysightE36234APowerSupply(connection_params)

        # Valid outputs
        device.validate_output(1)  # Should not raise
        device.validate_output(2)  # Should not raise

        # Invalid outputs
        with pytest.raises(PowerSupplyParameterError, match="Invalid output"):
            device.validate_output(0)

        with pytest.raises(PowerSupplyParameterError, match="Invalid output"):
            device.validate_output(3)


class TestKeysightE36234AContextManager:
    """Tests for context manager functionality."""

    def test_context_manager_success(self):
        """Test successful use of context manager."""
        connection_params = {"ip_address": "192.168.0.1"}
        device = KeysightE36234APowerSupply(connection_params)
        device.socket_manager = MagicMock()

        with patch.object(device, 'connect') as mock_connect, \
             patch.object(device, 'disconnect') as mock_disconnect:

            with device:
                # Device should be connected
                mock_connect.assert_called_once()
                mock_disconnect.assert_not_called()

            # Device should be disconnected after exiting context
            mock_disconnect.assert_called_once()

    def test_context_manager_with_exception(self):
        """Test context manager when exception occurs."""
        connection_params = {"ip_address": "192.168.0.1"}
        device = KeysightE36234APowerSupply(connection_params)
        device.socket_manager = MagicMock()

        with patch.object(device, 'connect') as mock_connect, \
             patch.object(device, 'disconnect') as mock_disconnect:

            try:
                with device:
                    mock_connect.assert_called_once()
                    raise ValueError("Test exception")
            except ValueError:
                pass  # Expected

            # Device should still be disconnected
            mock_disconnect.assert_called_once()


class TestKeysightE36234AProperties:
    """Tests for property methods."""

    def test_available_outputs(self):
        """Test available_outputs property."""
        connection_params = {"ip_address": "192.168.0.1"}
        device = KeysightE36234APowerSupply(connection_params)
        assert device.available_outputs == [1, 2]

    def test_voltage_range(self):
        """Test voltage_range property."""
        connection_params = {"ip_address": "192.168.0.1"}
        device = KeysightE36234APowerSupply(connection_params)
        assert device.voltage_range == (0.0, 61.8)

    def test_current_range(self):
        """Test current_range property."""
        connection_params = {"ip_address": "192.168.0.1"}
        device = KeysightE36234APowerSupply(connection_params)
        assert device.current_range == (0.0, 10.3)

    def test_is_ready_property(self):
        """Test is_ready property logic."""
        connection_params = {"ip_address": "192.168.0.1"}
        device = KeysightE36234APowerSupply(connection_params)
        device.socket_manager = MagicMock()

        # Both conditions must be true
        device.socket_manager.is_connected = True
        device._device_validated = True
        assert device.is_ready is True

        # If socket not connected
        device.socket_manager.is_connected = False
        device._device_validated = True
        assert device.is_ready is False

        # If device not validated
        device.socket_manager.is_connected = True
        device._device_validated = False
        assert device.is_ready is False

    def test_socket_connected_property(self):
        """Test socket_connected property."""
        connection_params = {"ip_address": "192.168.0.1"}
        device = KeysightE36234APowerSupply(connection_params)
        device.socket_manager = MagicMock()

        # Test when is_connected exists
        device.socket_manager.is_connected = True
        assert device.socket_connected is True

        device.socket_manager.is_connected = False
        assert device.socket_connected is False

        # Test when is_connected attribute doesn't exist
        delattr(device.socket_manager, 'is_connected')
        assert device.socket_connected is False


class TestKeysightE36234AOutputControl:
    """Tests for output enable/disable and status."""

    def test_enable_output(self, keysight_e36234a_device):
        """Enable output should send the correct command and validate last command."""
        # Ensure connected state
        keysight_e36234a_device._device_validated = True
        keysight_e36234a_device.socket_manager.is_connected = True

        # Avoid extra traffic from validate_last_command
        with patch.object(keysight_e36234a_device, 'validate_last_command') as mock_validate:
            keysight_e36234a_device.enable_output(1)
            keysight_e36234a_device.socket_manager.send.assert_called_once_with(b"OUTP ON,(@1)\n")
            mock_validate.assert_called_once()

    def test_disable_output(self, keysight_e36234a_device):
        """Disable output should send the correct command and validate last command."""
        keysight_e36234a_device._device_validated = True
        keysight_e36234a_device.socket_manager.is_connected = True

        with patch.object(keysight_e36234a_device, 'validate_last_command') as mock_validate:
            keysight_e36234a_device.disable_output(1)
            keysight_e36234a_device.socket_manager.send.assert_called_once_with(b"OUTP OFF,(@1)\n")
            mock_validate.assert_called_once()

    @pytest.mark.parametrize(
        "resp,expected",
        [
            (b"1\n", True),
            (b"0\n", False),
        ],
    )
    def test_is_output_enabled_parsing(self, resp, expected, keysight_e36234a_device):
        """is_output_enabled should correctly parse device responses."""
        keysight_e36234a_device._device_validated = True
        keysight_e36234a_device.socket_manager.is_connected = True
        keysight_e36234a_device.socket_manager.recv.return_value = resp

        state = keysight_e36234a_device.is_output_enabled(1)
        keysight_e36234a_device.socket_manager.send.assert_called_once_with(b"OUTP? (@1)\n")
        keysight_e36234a_device.socket_manager.recv.assert_called_once_with(4096)
        assert state is expected


class TestKeysightE36234AInitialization:
    """Tests for device initialization and parameter validation."""

    def test_initialization_with_valid_ip(self):
        """Test successful initialization with valid IP address."""
        connection_params = {"ip_address": "192.168.0.1"}
        device = KeysightE36234APowerSupply(connection_params)
        assert str(device.ip_address) == "192.168.0.1"
        assert device.port == 5025  # Default port

    def test_initialization_with_custom_port(self):
        """Test initialization with custom port."""
        connection_params = {"ip_address": "192.168.0.1", "port": 9999}
        device = KeysightE36234APowerSupply(connection_params)
        assert device.port == 9999

    def test_initialization_with_ipv4_address_object(self):
        """Test initialization with IPv4Address object."""
        from ipaddress import IPv4Address
        ip_obj = IPv4Address("10.0.0.1")
        connection_params = {"ip_address": ip_obj}
        device = KeysightE36234APowerSupply(connection_params)
        assert device.ip_address == ip_obj

    def test_initialization_missing_ip_address(self):
        """Test initialization fails without IP address."""
        connection_params = {}
        with pytest.raises(PowerSupplyParameterError, match="IP address required"):
            KeysightE36234APowerSupply(connection_params)

    def test_initialization_invalid_ip_address(self):
        """Test initialization with invalid IP address format."""
        connection_params = {"ip_address": "invalid.ip.address"}
        with pytest.raises(ValueError):
            KeysightE36234APowerSupply(connection_params)


class TestKeysightE36234AConnectionErrors:
    """Tests for various connection error scenarios."""

    def test_connection_failure_during_connect(self):
        """Test handling of connection failures."""
        connection_params = {"ip_address": "192.168.0.1"}
        device = KeysightE36234APowerSupply(connection_params)
        device.socket_manager = MagicMock()

        # Simulate connection failure
        device.socket_manager.connect.side_effect = OSError("Connection refused")

        with pytest.raises(PowerSupplyConnectionError, match="Failed to connect to E36234A"):
            device.connect()

        # Device should not be validated after failed connection
        assert device._device_validated is False

    def test_recv_failure_invalidates_device(self):
        """Test that recv failures invalidate the device."""
        connection_params = {"ip_address": "192.168.0.1"}
        device = KeysightE36234APowerSupply(connection_params)
        device.socket_manager = MagicMock()
        device._device_validated = True
        device.socket_manager.is_connected = True

        # Simulate recv failure
        device.socket_manager.recv.side_effect = OSError("Connection lost")

        with pytest.raises(PowerSupplyParameterError, match="Failed to receive response"):
            device.read_voltage(1)

        # Device should be invalidated
        assert device._device_validated is False

    def test_auto_reconnection_after_invalidation(self):
        """Test that device auto-reconnects after being invalidated."""
        connection_params = {"ip_address": "192.168.0.1"}
        device = KeysightE36234APowerSupply(connection_params)
        device.socket_manager = MagicMock()
        device._device_validated = False
        device.socket_manager.is_connected = False

        with patch.object(device, 'connect') as mock_connect:
            def mock_connect_side_effect():
                device._device_validated = True
                device.socket_manager.is_connected = True

            mock_connect.side_effect = mock_connect_side_effect
            device.socket_manager.recv.return_value = b"25.5\n"

            # This should trigger auto-reconnection
            voltage = device.read_voltage(1)

            mock_connect.assert_called_once()
            assert voltage == 25.5


class TestKeysightE36234AEdgeCases:
    """Tests for edge cases and boundary conditions."""

    def test_voltage_boundary_values(self):
        """Test voltage validation at boundary values."""
        connection_params = {"ip_address": "192.168.0.1"}
        device = KeysightE36234APowerSupply(connection_params)

        # Test minimum valid voltage
        device.validate_voltage(0.0)  # Should not raise

        # Test maximum valid voltage
        device.validate_voltage(61.8)  # Should not raise

        # Test just below minimum
        with pytest.raises(PowerSupplyParameterError):
            device.validate_voltage(-0.1)

        # Test just above maximum
        with pytest.raises(PowerSupplyParameterError):
            device.validate_voltage(61.9)

    def test_current_boundary_values(self):
        """Test current validation at boundary values."""
        connection_params = {"ip_address": "192.168.0.1"}
        device = KeysightE36234APowerSupply(connection_params)

        # Test minimum valid current
        device.validate_current(0.0)  # Should not raise

        # Test maximum valid current
        device.validate_current(10.3)  # Should not raise

        # Test just below minimum
        with pytest.raises(PowerSupplyParameterError):
            device.validate_current(-0.1)

        # Test just above maximum
        with pytest.raises(PowerSupplyParameterError):
            device.validate_current(10.4)

    def test_output_boundary_values(self):
        """Test output validation at boundary values."""
        connection_params = {"ip_address": "192.168.0.1"}
        device = KeysightE36234APowerSupply(connection_params)

        # Test valid outputs
        device.validate_output(1)  # Should not raise
        device.validate_output(2)  # Should not raise

        # Test invalid outputs
        with pytest.raises(PowerSupplyParameterError):
            device.validate_output(0)

        with pytest.raises(PowerSupplyParameterError):
            device.validate_output(3)


class TestKeysightE36234AVoltageProtectionControls:
    """Tests for voltage protection (OVP) controls."""

    def test_enable_voltage_protection(self, keysight_e36234a_device):
        keysight_e36234a_device._device_validated = True
        keysight_e36234a_device.socket_manager.is_connected = True
        with patch.object(keysight_e36234a_device, 'validate_last_command') as mock_validate:
            keysight_e36234a_device.enable_voltage_protection(1)
            keysight_e36234a_device.socket_manager.send.assert_called_once_with(b"VOLT:PROT:STAT ON,(@1)\n")
            mock_validate.assert_called_once()

    def test_disable_voltage_protection(self, keysight_e36234a_device):
        keysight_e36234a_device._device_validated = True
        keysight_e36234a_device.socket_manager.is_connected = True
        with patch.object(keysight_e36234a_device, 'validate_last_command') as mock_validate:
            keysight_e36234a_device.disable_voltage_protection(1)
            keysight_e36234a_device.socket_manager.send.assert_called_once_with(b"VOLT:PROT:STAT OFF,(@1)\n")
            mock_validate.assert_called_once()

    @pytest.mark.parametrize("resp,expected", [(b"1\n", True), (b"0\n", False)])
    def test_is_voltage_protection_enabled(self, resp, expected, keysight_e36234a_device):
        keysight_e36234a_device._device_validated = True
        keysight_e36234a_device.socket_manager.is_connected = True
        keysight_e36234a_device.socket_manager.recv.return_value = resp
        state = keysight_e36234a_device.is_voltage_protection_enabled(1)
        keysight_e36234a_device.socket_manager.send.assert_called_once_with(b"VOLT:PROT:STAT? (@1)\n")
        keysight_e36234a_device.socket_manager.recv.assert_called_once_with(4096)
        assert state is expected

    def test_clear_voltage_protection(self, keysight_e36234a_device):
        keysight_e36234a_device._device_validated = True
        keysight_e36234a_device.socket_manager.is_connected = True
        with patch.object(keysight_e36234a_device, 'validate_last_command') as mock_validate:
            keysight_e36234a_device.clear_voltage_protection(2)
            keysight_e36234a_device.socket_manager.send.assert_called_once_with(b"VOLT:PROT:CLE (@2)\n")
            mock_validate.assert_called_once()


class TestKeysightE36234ACurrentProtectionControls:
    """Tests for overcurrent protection (OCP) controls."""

    def test_read_current_protection(self, keysight_e36234a_device):
        keysight_e36234a_device._device_validated = True
        keysight_e36234a_device.socket_manager.is_connected = True
        keysight_e36234a_device.socket_manager.recv.return_value = b"8.0\n"
        level = keysight_e36234a_device.read_current_protection(1)
        keysight_e36234a_device.socket_manager.send.assert_called_once_with(b"CURR:PROT? (@1)\n")
        keysight_e36234a_device.socket_manager.recv.assert_called_once_with(4096)
        assert level == 8.0

    def test_set_current_protection_valid(self, keysight_e36234a_device):
        keysight_e36234a_device._device_validated = True
        keysight_e36234a_device.socket_manager.is_connected = True
        with patch.object(keysight_e36234a_device, 'validate_last_command'):
            keysight_e36234a_device.set_current_protection(5.0, 1)
            keysight_e36234a_device.socket_manager.send.assert_called_once_with(b"CURR:PROT 5.0,(@1)\n")

    def test_set_current_protection_above_limit_raises(self, keysight_e36234a_device):
        with pytest.raises(PowerSupplyParameterError, match="Current protection.*out of range"):
            keysight_e36234a_device.set_current_protection(12.0, 1)

    def test_set_current_protection_below_min_raises(self, keysight_e36234a_device):
        with pytest.raises(PowerSupplyParameterError, match="Current protection.*out of range"):
            keysight_e36234a_device.set_current_protection(-0.1, 1)

    def test_enable_disable_current_protection(self, keysight_e36234a_device):
        keysight_e36234a_device._device_validated = True
        keysight_e36234a_device.socket_manager.is_connected = True
        with patch.object(keysight_e36234a_device, 'validate_last_command') as mock_validate:
            keysight_e36234a_device.enable_current_protection(1)
            keysight_e36234a_device.disable_current_protection(2)
            keysight_e36234a_device.socket_manager.send.assert_any_call(b"CURR:PROT:STAT ON,(@1)\n")
            keysight_e36234a_device.socket_manager.send.assert_any_call(b"CURR:PROT:STAT OFF,(@2)\n")
            assert mock_validate.call_count == 2

    @pytest.mark.parametrize("resp,expected", [(b"1\n", True), (b"0\n", False)])
    def test_is_current_protection_enabled(self, resp, expected, keysight_e36234a_device):
        keysight_e36234a_device._device_validated = True
        keysight_e36234a_device.socket_manager.is_connected = True
        keysight_e36234a_device.socket_manager.recv.return_value = resp
        state = keysight_e36234a_device.is_current_protection_enabled(1)
        keysight_e36234a_device.socket_manager.send.assert_called_once_with(b"CURR:PROT:STAT? (@1)\n")
        keysight_e36234a_device.socket_manager.recv.assert_called_once_with(4096)
        assert state is expected

    def test_clear_current_protection(self, keysight_e36234a_device):
        keysight_e36234a_device._device_validated = True
        keysight_e36234a_device.socket_manager.is_connected = True
        with patch.object(keysight_e36234a_device, 'validate_last_command') as mock_validate:
            keysight_e36234a_device.clear_current_protection(1)
            keysight_e36234a_device.socket_manager.send.assert_called_once_with(b"CURR:PROT:CLE (@1)\n")
            mock_validate.assert_called_once()


class TestKeysightE36234AStepSize:
    """Tests for step size and increment/decrement operations."""

    def test_read_set_voltage_step_size(self, keysight_e36234a_device):
        keysight_e36234a_device._device_validated = True
        keysight_e36234a_device.socket_manager.is_connected = True
        keysight_e36234a_device.socket_manager.recv.return_value = b"0.5\n"
        sz = keysight_e36234a_device.read_voltage_step_size(1)
        keysight_e36234a_device.socket_manager.send.assert_called_with(b"VOLT:STEP? (@1)\n")
        assert sz == 0.5
        with patch.object(keysight_e36234a_device, 'validate_last_command'):
            keysight_e36234a_device.set_voltage_step_size(1.0, 1)
            keysight_e36234a_device.socket_manager.send.assert_called_with(b"VOLT:STEP 1.0,(@1)\n")

    def test_set_voltage_step_size_out_of_range(self, keysight_e36234a_device):
        with pytest.raises(PowerSupplyParameterError):
            keysight_e36234a_device.set_voltage_step_size(100.0, 1)

    def test_read_set_current_step_size(self, keysight_e36234a_device):
        keysight_e36234a_device._device_validated = True
        keysight_e36234a_device.socket_manager.is_connected = True
        keysight_e36234a_device.socket_manager.recv.return_value = b"0.1\n"
        sz = keysight_e36234a_device.read_current_step_size(1)
        keysight_e36234a_device.socket_manager.send.assert_called_with(b"CURR:STEP? (@1)\n")
        assert sz == 0.1
        with patch.object(keysight_e36234a_device, 'validate_last_command'):
            keysight_e36234a_device.set_current_step_size(0.5, 1)
            keysight_e36234a_device.socket_manager.send.assert_called_with(b"CURR:STEP 0.5,(@1)\n")

    def test_set_current_step_size_out_of_range(self, keysight_e36234a_device):
        with pytest.raises(PowerSupplyParameterError):
            keysight_e36234a_device.set_current_step_size(100.0, 1)

    def test_increment_decrement_voltage(self, keysight_e36234a_device):
        with patch.object(keysight_e36234a_device, 'read_voltage_step_size', return_value=0.5), \
             patch.object(keysight_e36234a_device, 'set_voltage_step_size') as mock_set, \
             patch.object(keysight_e36234a_device, 'validate_last_command'):
            keysight_e36234a_device.increment_voltage(step_size=1.0, output=1)
            mock_set.assert_called_once_with(1.0, 1)
            keysight_e36234a_device.socket_manager.send.assert_called_with(b"VOLT UP,(@1)\n")

        with patch.object(keysight_e36234a_device, 'read_voltage_step_size', return_value=1.0), \
             patch.object(keysight_e36234a_device, 'set_voltage_step_size') as mock_set2, \
             patch.object(keysight_e36234a_device, 'validate_last_command'):
            keysight_e36234a_device.decrement_voltage(step_size=1.0, output=2)
            mock_set2.assert_not_called()
            keysight_e36234a_device.socket_manager.send.assert_called_with(b"VOLT DOWN,(@2)\n")

    def test_increment_decrement_current(self, keysight_e36234a_device):
        with patch.object(keysight_e36234a_device, 'read_current_step_size', return_value=0.01), \
             patch.object(keysight_e36234a_device, 'set_current_step_size') as mock_set, \
             patch.object(keysight_e36234a_device, 'validate_last_command'):
            keysight_e36234a_device.increment_current(step_size=0.02, output=1)
            mock_set.assert_called_once_with(0.02, 1)
            keysight_e36234a_device.socket_manager.send.assert_called_with(b"CURR UP,(@1)\n")

        with patch.object(keysight_e36234a_device, 'read_current_step_size', return_value=0.02), \
             patch.object(keysight_e36234a_device, 'set_current_step_size') as mock_set2, \
             patch.object(keysight_e36234a_device, 'validate_last_command'):
            keysight_e36234a_device.decrement_current(step_size=0.02, output=2)
            mock_set2.assert_not_called()
            keysight_e36234a_device.socket_manager.send.assert_called_with(b"CURR DOWN,(@2)\n")


class TestKeysightE36234ALogging:
    """Tests for logging behavior."""

    def test_successful_connection_logs_info(self):
        """Test that successful connection logs appropriate info."""
        connection_params = {"ip_address": "192.168.0.1"}
        device = KeysightE36234APowerSupply(connection_params)
        device.socket_manager = MagicMock()
        device.socket_manager.is_connected = True

        with patch.object(device, 'read_identity', return_value="KEYSIGHT TECHNOLOGIES,E36234A,MY12345678,1.0.0"), \
             patch('testzilla.power_supply.keysight_e36234a.logger') as mock_logger:

            device.connect()

            # Should log successful connection
            mock_logger.info.assert_called_with(
                "Connected to Keysight E36234A at 192.168.0.1:5025 - KEYSIGHT TECHNOLOGIES,E36234A,MY12345678,1.0.0"
            )

    def test_disconnect_logs_info(self):
        """Test that disconnect logs appropriate info."""
        connection_params = {"ip_address": "192.168.0.1"}
        device = KeysightE36234APowerSupply(connection_params)
        device.socket_manager = MagicMock()

        with patch('testzilla.power_supply.keysight_e36234a.logger') as mock_logger:
            device.disconnect()
            mock_logger.info.assert_called_with("Disconnected from Keysight E36234A")

    def test_command_logging(self):
        """Test that commands and responses are logged at debug level."""
        connection_params = {"ip_address": "192.168.0.1"}
        device = KeysightE36234APowerSupply(connection_params)
        device.socket_manager = MagicMock()
        device._device_validated = True
        device.socket_manager.is_connected = True
        device.socket_manager.recv.return_value = b"25.5\n"

        with patch('testzilla.power_supply.keysight_e36234a.logger') as mock_logger:
            device.read_voltage(1)

            # Should log command and response
            mock_logger.debug.assert_any_call("Sent command: MEAS:VOLT? (@1)")
            mock_logger.debug.assert_any_call("Response: 25.5")

    def test_non_e36234a_device_raises(self):
        """Test that connecting to non-E36234A device raises PowerSupplyConnectionError."""
        connection_params = {"ip_address": "192.168.0.1"}
        device = KeysightE36234APowerSupply(connection_params)
        device.socket_manager = MagicMock()
        device.socket_manager.is_connected = True

        with patch.object(device, 'read_identity', return_value="SOME OTHER DEVICE"):
            with pytest.raises(PowerSupplyConnectionError, match="Failed to connect to E36234A"):
                device.connect()


# Fixture definitions should be in conftest.py, but included here for completeness
@pytest.fixture
def keysight_e36234a_device():
    """Create a mock Keysight E36234A device for testing."""
    connection_params = {"ip_address": "192.168.0.1"}
    device = KeysightE36234APowerSupply(connection_params)
    device.socket_manager = MagicMock()
    device.socket_manager.is_connected = True
    device._device_validated = True
    return device


@pytest.fixture
def keysight_e36234a_device_disconnected():
    """Create a disconnected mock Keysight E36234A device for testing."""
    connection_params = {"ip_address": "192.168.0.1"}
    device = KeysightE36234APowerSupply(connection_params)
    device.socket_manager = MagicMock()
    device.socket_manager.is_connected = False
    device._device_validated = False
    return device