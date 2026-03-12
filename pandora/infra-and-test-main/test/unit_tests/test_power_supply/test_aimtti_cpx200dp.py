"""Module for testing methods in power_supply.py"""

from unittest.mock import MagicMock, patch
import pytest
from testzilla.power_supply.aimtti_cpx200dp import AimTTiCPX200DPPowerSupply
from testzilla.power_supply.abstract_power_supply import (
    PowerSupplyParameterError,
    PowerSupplyConnectionError,
    PowerSupplyError
)


class TestCPX200DPBasicFunctionality:
    """Tests for basic CPX200DP functionality."""

    def test_invalid_output(self):
        """Test using an invalid output number."""
        # Create a mock device
        connection_params = {"ip_address": "192.168.0.1"}
        device = AimTTiCPX200DPPowerSupply(connection_params)

        # Test with invalid output
        with pytest.raises(PowerSupplyParameterError, match="Invalid output: 5"):
            device.validate_output(5)

    def test_read_identity(self, aimtti_cpx200dp_device):
        """Test read_identity method."""
        # Fix the device state to simulate proper connection
        aimtti_cpx200dp_device._device_validated = True
        aimtti_cpx200dp_device.socket_manager.is_connected = True
        aimtti_cpx200dp_device.socket_manager.recv.return_value = b"THURLBY THANDAR CPX200DP\n"

        # Execution
        identity = aimtti_cpx200dp_device.read_identity()

        # Verification
        aimtti_cpx200dp_device.socket_manager.send.assert_called_once_with(b"*IDN?\n")
        aimtti_cpx200dp_device.socket_manager.recv.assert_called_once_with(4096)
        assert identity == "THURLBY THANDAR CPX200DP"


class TestCPX200DPVoltageOperations:
    """Tests for voltage-related operations."""

    @pytest.mark.parametrize("output", [1, 2])
    def test_read_voltage(self, output, aimtti_cpx200dp_device):
        """Test reading voltage."""
        # Fix the device state
        aimtti_cpx200dp_device._device_validated = True
        aimtti_cpx200dp_device.socket_manager.is_connected = True
        aimtti_cpx200dp_device.socket_manager.recv.return_value = b"45.0\n"

        # Execution
        voltage = aimtti_cpx200dp_device.read_voltage(output=output)

        # Verification
        expected_command = f"V{output}?\n".encode()
        aimtti_cpx200dp_device.socket_manager.send.assert_called_once_with(expected_command)
        aimtti_cpx200dp_device.socket_manager.recv.assert_called_once_with(4096)
        assert voltage == 45.0

    def test_read_voltage_on_unavailable_output(self, aimtti_cpx200dp_device):
        """Test reading voltage on an unavailable output."""
        # Execution
        with pytest.raises(PowerSupplyParameterError, match="Invalid output: 3"):
            aimtti_cpx200dp_device.read_voltage(output=3)  # Unavailable output 3

        # Verification - no socket operations should occur
        aimtti_cpx200dp_device.socket_manager.send.assert_not_called()
        aimtti_cpx200dp_device.socket_manager.recv.assert_not_called()

    @pytest.mark.parametrize("output", [1, 2])
    def test_set_voltage(self, output, aimtti_cpx200dp_device):
        """Test setting voltage."""
        # Fix the device state
        aimtti_cpx200dp_device._device_validated = True
        aimtti_cpx200dp_device.socket_manager.is_connected = True

        # Mock the validate_last_command to avoid additional socket calls
        with patch.object(aimtti_cpx200dp_device, 'validate_last_command'):
            # Execution
            aimtti_cpx200dp_device.set_voltage(voltage=50.0, output=output)

            # Verification
            expected_command = f"V{output} 50.0\n".encode()
            aimtti_cpx200dp_device.socket_manager.send.assert_called_once_with(expected_command)

    @pytest.mark.parametrize("output", [1, 2])
    def test_set_voltage_with_more_than_upper_limit(self, aimtti_cpx200dp_device, output):
        """Test setting voltage with input more than the upper limit."""
        # Execution
        with pytest.raises(PowerSupplyParameterError, match="Voltage 100.0 out of range"):
            aimtti_cpx200dp_device.set_voltage(voltage=100.0, output=output)

        # Verification - no socket operations should occur
        aimtti_cpx200dp_device.socket_manager.send.assert_not_called()
        aimtti_cpx200dp_device.socket_manager.recv.assert_not_called()

    @pytest.mark.parametrize("output", [1, 2])
    def test_set_voltage_with_less_than_lower_limit(self, aimtti_cpx200dp_device, output):
        """Test setting voltage with input less than the lower limit."""
        # Execution
        with pytest.raises(PowerSupplyParameterError, match="Voltage -100.0 out of range"):
            aimtti_cpx200dp_device.set_voltage(voltage=-100.0, output=output)

        # Verification - no socket operations should occur
        aimtti_cpx200dp_device.socket_manager.send.assert_not_called()
        aimtti_cpx200dp_device.socket_manager.recv.assert_not_called()

    def test_set_voltage_on_unavailable_output(self, aimtti_cpx200dp_device):
        """Test setting voltage on an unavailable output."""
        # Execution
        with pytest.raises(PowerSupplyParameterError, match="Invalid output: 3"):
            aimtti_cpx200dp_device.set_voltage(output=3, voltage=40.0)  # Unavailable output 3

        # Verification - no socket operations should occur
        aimtti_cpx200dp_device.socket_manager.send.assert_not_called()
        aimtti_cpx200dp_device.socket_manager.recv.assert_not_called()

    @pytest.mark.parametrize("output", [1, 2])
    def test_increment_voltage(self, output, aimtti_cpx200dp_device):
        """Test incrementing voltage."""
        # Fix the device state
        aimtti_cpx200dp_device._device_validated = True
        aimtti_cpx200dp_device.socket_manager.is_connected = True

        # Mock the methods called by increment_voltage
        with patch.object(aimtti_cpx200dp_device, 'read_voltage_step_size', return_value=1.0), \
             patch.object(aimtti_cpx200dp_device, 'set_voltage_step_size'), \
             patch.object(aimtti_cpx200dp_device, 'validate_last_command'):

            # Execution
            aimtti_cpx200dp_device.increment_voltage(step_size=2.0, output=output)

            # Verification
            aimtti_cpx200dp_device.read_voltage_step_size.assert_called_once_with(output)
            aimtti_cpx200dp_device.set_voltage_step_size.assert_called_once_with(2.0, output)
            expected_command = f"INCV{output}\n".encode()
            aimtti_cpx200dp_device.socket_manager.send.assert_called_with(expected_command)

    @pytest.mark.parametrize("output", [1, 2])
    def test_increment_voltage_same_step_size(self, output, aimtti_cpx200dp_device):
        """Test incrementing voltage when step size is already correct."""
        # Fix the device state
        aimtti_cpx200dp_device._device_validated = True
        aimtti_cpx200dp_device.socket_manager.is_connected = True

        # Mock the methods called by increment_voltage
        with patch.object(aimtti_cpx200dp_device, 'read_voltage_step_size', return_value=2.0), \
             patch.object(aimtti_cpx200dp_device, 'set_voltage_step_size'), \
             patch.object(aimtti_cpx200dp_device, 'validate_last_command'):

            # Execution
            aimtti_cpx200dp_device.increment_voltage(step_size=2.0, output=output)

            # Verification
            aimtti_cpx200dp_device.read_voltage_step_size.assert_called_once_with(output)
            aimtti_cpx200dp_device.set_voltage_step_size.assert_not_called()  # Should not be called
            expected_command = f"INCV{output}\n".encode()
            aimtti_cpx200dp_device.socket_manager.send.assert_called_with(expected_command)

    def test_increment_voltage_on_unavailable_output(self, aimtti_cpx200dp_device):
        """Test incrementing voltage on an unavailable output."""
        # Execution
        with pytest.raises(PowerSupplyParameterError, match="Invalid output: 3"):
            aimtti_cpx200dp_device.increment_voltage(step_size=2.0, output=3)

        # Verification - no socket operations should occur
        aimtti_cpx200dp_device.socket_manager.send.assert_not_called()
        aimtti_cpx200dp_device.socket_manager.recv.assert_not_called()

    @pytest.mark.parametrize("output", [1, 2])
    def test_decrement_voltage(self, output, aimtti_cpx200dp_device):
        """Test decrementing voltage."""
        # Fix the device state
        aimtti_cpx200dp_device._device_validated = True
        aimtti_cpx200dp_device.socket_manager.is_connected = True

        # Mock the methods called by decrement_voltage
        with patch.object(aimtti_cpx200dp_device, 'read_voltage_step_size', return_value=1.0), \
             patch.object(aimtti_cpx200dp_device, 'set_voltage_step_size'), \
             patch.object(aimtti_cpx200dp_device, 'validate_last_command'):

            # Execution
            aimtti_cpx200dp_device.decrement_voltage(step_size=2.0, output=output)

            # Verification
            aimtti_cpx200dp_device.read_voltage_step_size.assert_called_once_with(output)
            aimtti_cpx200dp_device.set_voltage_step_size.assert_called_once_with(2.0, output)
            expected_command = f"DECV{output}\n".encode()
            aimtti_cpx200dp_device.socket_manager.send.assert_called_with(expected_command)


class TestCPX200DPVoltageStepSizeAndProtection:
    """Tests for voltage step size and protection operations."""

    @pytest.mark.parametrize("output", [1, 2])
    def test_read_voltage_step_size(self, output, aimtti_cpx200dp_device):
        """Test reading voltage step size."""
        # Fix the device state
        aimtti_cpx200dp_device._device_validated = True
        aimtti_cpx200dp_device.socket_manager.is_connected = True
        aimtti_cpx200dp_device.socket_manager.recv.return_value = b"5.0\n"

        # Execution
        step_size = aimtti_cpx200dp_device.read_voltage_step_size(output=output)

        # Verification
        expected_command = f"DELTAV{output}?\n".encode()
        aimtti_cpx200dp_device.socket_manager.send.assert_called_once_with(expected_command)
        aimtti_cpx200dp_device.socket_manager.recv.assert_called_once_with(4096)
        assert step_size == 5.0

    @pytest.mark.parametrize("output", [1, 2])
    def test_set_voltage_step_size(self, output, aimtti_cpx200dp_device):
        """Test setting voltage step size."""
        # Fix the device state
        aimtti_cpx200dp_device._device_validated = True
        aimtti_cpx200dp_device.socket_manager.is_connected = True

        # Mock the validate_last_command to avoid additional socket calls
        with patch.object(aimtti_cpx200dp_device, 'validate_last_command'):
            # Execution
            aimtti_cpx200dp_device.set_voltage_step_size(step_size=5.0, output=output)

            # Verification
            expected_command = f"DELTAV{output} 5.0\n".encode()
            aimtti_cpx200dp_device.socket_manager.send.assert_called_once_with(expected_command)

    @pytest.mark.parametrize("output", [1, 2])
    def test_set_voltage_step_size_with_less_than_lower_limit(self, aimtti_cpx200dp_device, output):
        """Test setting voltage step size with input less than the lower limit."""
        # Execution
        with pytest.raises(PowerSupplyParameterError, match="Voltage step size 0.01V out of range"):
            aimtti_cpx200dp_device.set_voltage_step_size(step_size=0.01, output=output)

        # Verification - no socket operations should occur
        aimtti_cpx200dp_device.socket_manager.send.assert_not_called()
        aimtti_cpx200dp_device.socket_manager.recv.assert_not_called()

    @pytest.mark.parametrize("output", [1, 2])
    def test_set_voltage_step_size_with_more_than_upper_limit(self, aimtti_cpx200dp_device, output):
        """Test setting voltage step size with input more than the upper limit."""
        # Execution
        with pytest.raises(PowerSupplyParameterError, match="Voltage step size 65.0V out of range"):
            aimtti_cpx200dp_device.set_voltage_step_size(step_size=65.0, output=output)

        # Verification - no socket operations should occur
        aimtti_cpx200dp_device.socket_manager.send.assert_not_called()
        aimtti_cpx200dp_device.socket_manager.recv.assert_not_called()

    @pytest.mark.parametrize("output", [1, 2])
    def test_read_voltage_protection(self, output, aimtti_cpx200dp_device):
        """Test reading voltage protection level."""
        # Fix the device state
        aimtti_cpx200dp_device._device_validated = True
        aimtti_cpx200dp_device.socket_manager.is_connected = True
        aimtti_cpx200dp_device.socket_manager.recv.return_value = b"35.0\n"

        # Execution
        level = aimtti_cpx200dp_device.read_voltage_protection(output=output)

        # Verification
        expected_command = f"OVP{output}?\n".encode()
        aimtti_cpx200dp_device.socket_manager.send.assert_called_once_with(expected_command)
        aimtti_cpx200dp_device.socket_manager.recv.assert_called_once_with(4096)
        assert level == 35.0

    @pytest.mark.parametrize("output", [1, 2])
    def test_set_voltage_protection(self, output, aimtti_cpx200dp_device):
        """Test setting voltage protection level."""
        # Fix the device state
        aimtti_cpx200dp_device._device_validated = True
        aimtti_cpx200dp_device.socket_manager.is_connected = True

        # Mock the validate_last_command to avoid additional socket calls
        with patch.object(aimtti_cpx200dp_device, 'validate_last_command'):
            # Execution
            aimtti_cpx200dp_device.set_voltage_protection(level=45.0, output=output)

            # Verification
            expected_command = f"OVP{output} 45.0\n".encode()
            aimtti_cpx200dp_device.socket_manager.send.assert_called_once_with(expected_command)

    @pytest.mark.parametrize("output", [1, 2])
    def test_set_voltage_protection_with_more_than_upper_limit(self, aimtti_cpx200dp_device, output):
        """Test setting voltage protection with input more than the upper limit."""
        # Execution
        with pytest.raises(PowerSupplyParameterError, match="Voltage protection 70.0V out of range"):
            aimtti_cpx200dp_device.set_voltage_protection(level=70.0, output=output)

        # Verification - no socket operations should occur
        aimtti_cpx200dp_device.socket_manager.send.assert_not_called()
        aimtti_cpx200dp_device.socket_manager.recv.assert_not_called()

    @pytest.mark.parametrize("output", [1, 2])
    def test_set_voltage_protection_with_less_than_lower_limit(self, aimtti_cpx200dp_device, output):
        """Test setting voltage protection with input less than the lower limit."""
        # Execution
        with pytest.raises(PowerSupplyParameterError, match="Voltage protection 0.5V out of range"):
            aimtti_cpx200dp_device.set_voltage_protection(level=0.5, output=output)

        # Verification - no socket operations should occur
        aimtti_cpx200dp_device.socket_manager.send.assert_not_called()
        aimtti_cpx200dp_device.socket_manager.recv.assert_not_called()

    def test_voltage_step_size_boundaries(self, aimtti_cpx200dp_device):
        """Test voltage step size boundary conditions."""
        with patch.object(aimtti_cpx200dp_device, 'validate_last_command'):
            # Test minimum valid step size
            aimtti_cpx200dp_device.set_voltage_step_size(0.1, 1)
            aimtti_cpx200dp_device.socket_manager.send.assert_called_with(b"DELTAV1 0.1\n")

            # Test maximum valid step size
            aimtti_cpx200dp_device.socket_manager.reset_mock()
            aimtti_cpx200dp_device.set_voltage_step_size(60.0, 1)
            aimtti_cpx200dp_device.socket_manager.send.assert_called_with(b"DELTAV1 60.0\n")

        # Test invalid step sizes
        with pytest.raises(PowerSupplyParameterError, match="Voltage step size.*out of range"):
            aimtti_cpx200dp_device.set_voltage_step_size(0.05, 1)

        with pytest.raises(PowerSupplyParameterError, match="Voltage step size.*out of range"):
            aimtti_cpx200dp_device.set_voltage_step_size(65.0, 1)

    def test_voltage_protection_boundaries(self, aimtti_cpx200dp_device):
        """Test voltage protection boundary conditions."""
        with patch.object(aimtti_cpx200dp_device, 'validate_last_command'):
            # Test minimum valid level
            aimtti_cpx200dp_device.set_voltage_protection(1.0, 1)
            aimtti_cpx200dp_device.socket_manager.send.assert_called_with(b"OVP1 1.0\n")

            # Test maximum valid level
            aimtti_cpx200dp_device.socket_manager.reset_mock()
            aimtti_cpx200dp_device.set_voltage_protection(66.0, 1)
            aimtti_cpx200dp_device.socket_manager.send.assert_called_with(b"OVP1 66.0\n")

        # Test invalid levels
        with pytest.raises(PowerSupplyParameterError, match="Voltage protection.*out of range"):
            aimtti_cpx200dp_device.set_voltage_protection(0.5, 1)

        with pytest.raises(PowerSupplyParameterError, match="Voltage protection.*out of range"):
            aimtti_cpx200dp_device.set_voltage_protection(70.0, 1)


class TestCPX200DPCurrentOperations:
    """Tests for current-related operations."""

    @pytest.mark.parametrize("output", [1, 2])
    def test_read_current(self, output, aimtti_cpx200dp_device):
        """Test reading current."""
        # Fix the device state
        aimtti_cpx200dp_device._device_validated = True
        aimtti_cpx200dp_device.socket_manager.is_connected = True
        aimtti_cpx200dp_device.socket_manager.recv.return_value = b"10.0\n"

        # Execution
        current = aimtti_cpx200dp_device.read_current(output=output)

        # Verification
        expected_command = f"I{output}?\n".encode()
        aimtti_cpx200dp_device.socket_manager.send.assert_called_once_with(expected_command)
        aimtti_cpx200dp_device.socket_manager.recv.assert_called_once_with(4096)
        assert current == 10.0

    @pytest.mark.parametrize("output", [1, 2])
    def test_set_current(self, output, aimtti_cpx200dp_device):
        """Test setting current."""
        # Fix the device state
        aimtti_cpx200dp_device._device_validated = True
        aimtti_cpx200dp_device.socket_manager.is_connected = True

        # Mock the validate_last_command to avoid additional socket calls
        with patch.object(aimtti_cpx200dp_device, 'validate_last_command'):
            # Execution
            aimtti_cpx200dp_device.set_current(current=10.0, output=output)

            # Verification
            expected_command = f"I{output} 10.0\n".encode()
            aimtti_cpx200dp_device.socket_manager.send.assert_called_once_with(expected_command)

    @pytest.mark.parametrize("output", [1, 2])
    def test_set_current_with_more_than_upper_limit(self, aimtti_cpx200dp_device, output):
        """Test setting current with input more than upper limit."""
        # Execution
        with pytest.raises(PowerSupplyParameterError, match="Current 12.0 out of range"):
            aimtti_cpx200dp_device.set_current(current=12.0, output=output)

        # Verification - no socket operations should occur
        aimtti_cpx200dp_device.socket_manager.send.assert_not_called()
        aimtti_cpx200dp_device.socket_manager.recv.assert_not_called()

    @pytest.mark.parametrize("output", [1, 2])
    def test_set_current_with_less_than_lower_limit(self, aimtti_cpx200dp_device, output):
        """Test setting current with input less than the lower limit."""
        # Execution
        with pytest.raises(PowerSupplyParameterError, match="Current -12.0 out of range"):
            aimtti_cpx200dp_device.set_current(current=-12.0, output=output)

        # Verification - no socket operations should occur
        aimtti_cpx200dp_device.socket_manager.send.assert_not_called()
        aimtti_cpx200dp_device.socket_manager.recv.assert_not_called()

    @pytest.mark.parametrize("output", [1, 2])
    def test_increment_current(self, output, aimtti_cpx200dp_device):
        """Test incrementing current."""
        # Fix the device state
        aimtti_cpx200dp_device._device_validated = True
        aimtti_cpx200dp_device.socket_manager.is_connected = True

        # Mock the methods called by increment_current
        with patch.object(aimtti_cpx200dp_device, 'read_current_step_size', return_value=0.01), \
             patch.object(aimtti_cpx200dp_device, 'set_current_step_size'), \
             patch.object(aimtti_cpx200dp_device, 'validate_last_command'):

            # Execution
            aimtti_cpx200dp_device.increment_current(step_size=0.1, output=output)

            # Verification
            aimtti_cpx200dp_device.read_current_step_size.assert_called_once_with(output)
            aimtti_cpx200dp_device.set_current_step_size.assert_called_once_with(0.1, output)
            expected_command = f"INCI{output}\n".encode()
            aimtti_cpx200dp_device.socket_manager.send.assert_called_with(expected_command)

    @pytest.mark.parametrize("output", [1, 2])
    def test_decrement_current(self, output, aimtti_cpx200dp_device):
        """Test decrementing current."""
        # Fix the device state
        aimtti_cpx200dp_device._device_validated = True
        aimtti_cpx200dp_device.socket_manager.is_connected = True

        # Mock the methods called by decrement_current
        with patch.object(aimtti_cpx200dp_device, 'read_current_step_size', return_value=0.01), \
             patch.object(aimtti_cpx200dp_device, 'set_current_step_size'), \
             patch.object(aimtti_cpx200dp_device, 'validate_last_command'):

            # Execution
            aimtti_cpx200dp_device.decrement_current(step_size=0.1, output=output)

            # Verification
            aimtti_cpx200dp_device.read_current_step_size.assert_called_once_with(output)
            aimtti_cpx200dp_device.set_current_step_size.assert_called_once_with(0.1, output)
            expected_command = f"DECI{output}\n".encode()
            aimtti_cpx200dp_device.socket_manager.send.assert_called_with(expected_command)


class TestCPX200DPCurrentStepSizeAndProtection:
    """Tests for current step size and protection operations."""

    @pytest.mark.parametrize("output", [1, 2])
    def test_read_current_step_size(self, output, aimtti_cpx200dp_device):
        """Test reading current step size."""
        # Fix the device state
        aimtti_cpx200dp_device._device_validated = True
        aimtti_cpx200dp_device.socket_manager.is_connected = True
        aimtti_cpx200dp_device.socket_manager.recv.return_value = b"0.1\n"

        # Execution
        step_size = aimtti_cpx200dp_device.read_current_step_size(output=output)

        # Verification
        expected_command = f"DELTAI{output}?\n".encode()
        aimtti_cpx200dp_device.socket_manager.send.assert_called_once_with(expected_command)
        aimtti_cpx200dp_device.socket_manager.recv.assert_called_once_with(4096)
        assert step_size == 0.1

    @pytest.mark.parametrize("output", [1, 2])
    def test_set_current_step_size(self, output, aimtti_cpx200dp_device):
        """Test setting current step size."""
        # Fix the device state
        aimtti_cpx200dp_device._device_validated = True
        aimtti_cpx200dp_device.socket_manager.is_connected = True

        # Mock the validate_last_command to avoid additional socket calls
        with patch.object(aimtti_cpx200dp_device, 'validate_last_command'):
            # Execution
            aimtti_cpx200dp_device.set_current_step_size(step_size=0.1, output=output)

            # Verification
            expected_command = f"DELTAI{output} 0.1\n".encode()
            aimtti_cpx200dp_device.socket_manager.send.assert_called_once_with(expected_command)

    @pytest.mark.parametrize("output", [1, 2])
    def test_set_current_step_size_with_more_than_upper_limit(self, aimtti_cpx200dp_device, output):
        """Test setting current step size with input more than upper limit."""
        # Execution
        with pytest.raises(PowerSupplyParameterError, match="Current step size 12.0A out of range"):
            aimtti_cpx200dp_device.set_current_step_size(step_size=12.0, output=output)

        # Verification - no socket operations should occur
        aimtti_cpx200dp_device.socket_manager.send.assert_not_called()
        aimtti_cpx200dp_device.socket_manager.recv.assert_not_called()

    @pytest.mark.parametrize("output", [1, 2])
    def test_set_current_step_size_with_less_than_lower_limit(self, aimtti_cpx200dp_device, output):
        """Test setting current step size with input less than the lower limit."""
        # Execution
        with pytest.raises(PowerSupplyParameterError, match="Current step size -12.0A out of range"):
            aimtti_cpx200dp_device.set_current_step_size(step_size=-12.0, output=output)

        # Verification - no socket operations should occur
        aimtti_cpx200dp_device.socket_manager.send.assert_not_called()
        aimtti_cpx200dp_device.socket_manager.recv.assert_not_called()

    @pytest.mark.parametrize("output", [1, 2])
    def test_read_current_protection(self, output, aimtti_cpx200dp_device):
        """Test reading current protection level."""
        # Fix the device state
        aimtti_cpx200dp_device._device_validated = True
        aimtti_cpx200dp_device.socket_manager.is_connected = True
        aimtti_cpx200dp_device.socket_manager.recv.return_value = b"8.0\n"

        # Execution
        level = aimtti_cpx200dp_device.read_current_protection(output=output)

        # Verification
        expected_command = f"OCP{output}?\n".encode()
        aimtti_cpx200dp_device.socket_manager.send.assert_called_once_with(expected_command)
        aimtti_cpx200dp_device.socket_manager.recv.assert_called_once_with(4096)
        assert level == 8.0

    @pytest.mark.parametrize("output", [1, 2])
    def test_set_current_protection(self, output, aimtti_cpx200dp_device):
        """Test setting current protection level."""
        # Fix the device state
        aimtti_cpx200dp_device._device_validated = True
        aimtti_cpx200dp_device.socket_manager.is_connected = True

        # Mock the validate_last_command to avoid additional socket calls
        with patch.object(aimtti_cpx200dp_device, 'validate_last_command'):
            # Execution
            aimtti_cpx200dp_device.set_current_protection(level=9.0, output=output)

            # Verification
            expected_command = f"OCP{output} 9.0\n".encode()
            aimtti_cpx200dp_device.socket_manager.send.assert_called_once_with(expected_command)

    @pytest.mark.parametrize("output", [1, 2])
    def test_set_current_protection_with_more_than_upper_limit(self, aimtti_cpx200dp_device, output):
        """Test setting current protection with input more than the upper limit."""
        # Execution
        with pytest.raises(PowerSupplyParameterError, match="Current protection 12.0A out of range"):
            aimtti_cpx200dp_device.set_current_protection(level=12.0, output=output)

        # Verification - no socket operations should occur
        aimtti_cpx200dp_device.socket_manager.send.assert_not_called()
        aimtti_cpx200dp_device.socket_manager.recv.assert_not_called()

    @pytest.mark.parametrize("output", [1, 2])
    def test_set_current_protection_with_less_than_lower_limit(self, aimtti_cpx200dp_device, output):
        """Test setting current protection with input less than the lower limit."""
        # Execution
        with pytest.raises(PowerSupplyParameterError, match="Current protection -12.0A out of range"):
            aimtti_cpx200dp_device.set_current_protection(level=-12.0, output=output)

        # Verification - no socket operations should occur
        aimtti_cpx200dp_device.socket_manager.send.assert_not_called()
        aimtti_cpx200dp_device.socket_manager.recv.assert_not_called()

    def test_current_step_size_boundaries(self, aimtti_cpx200dp_device):
        """Test current step size boundary conditions."""
        with patch.object(aimtti_cpx200dp_device, 'validate_last_command'):
            # Test minimum valid step size
            aimtti_cpx200dp_device.set_current_step_size(0.01, 1)
            aimtti_cpx200dp_device.socket_manager.send.assert_called_with(b"DELTAI1 0.01\n")

            # Test maximum valid step size
            aimtti_cpx200dp_device.socket_manager.reset_mock()
            aimtti_cpx200dp_device.set_current_step_size(10.0, 1)
            aimtti_cpx200dp_device.socket_manager.send.assert_called_with(b"DELTAI1 10.0\n")

        # Test invalid step sizes
        with pytest.raises(PowerSupplyParameterError, match="Current step size.*out of range"):
            aimtti_cpx200dp_device.set_current_step_size(0.005, 1)

        with pytest.raises(PowerSupplyParameterError, match="Current step size.*out of range"):
            aimtti_cpx200dp_device.set_current_step_size(15.0, 1)

    def test_current_protection_boundaries(self, aimtti_cpx200dp_device):
        """Test current protection boundary conditions."""
        with patch.object(aimtti_cpx200dp_device, 'validate_last_command'):
            # Test minimum valid level
            aimtti_cpx200dp_device.set_current_protection(1.0, 1)
            aimtti_cpx200dp_device.socket_manager.send.assert_called_with(b"OCP1 1.0\n")

            # Test maximum valid level
            aimtti_cpx200dp_device.socket_manager.reset_mock()
            aimtti_cpx200dp_device.set_current_protection(11.0, 1)
            aimtti_cpx200dp_device.socket_manager.send.assert_called_with(b"OCP1 11.0\n")

        # Test invalid levels
        with pytest.raises(PowerSupplyParameterError, match="Current protection.*out of range"):
            aimtti_cpx200dp_device.set_current_protection(0.5, 1)

        with pytest.raises(PowerSupplyParameterError, match="Current protection.*out of range"):
            aimtti_cpx200dp_device.set_current_protection(15.0, 1)


class TestCPX200DPConnectionHandling:
    """Tests for connection management."""

    def test_auto_connect_on_read_voltage(self, cpx200dp_device_disconnected):
        """Test that read_voltage automatically connects if disconnected."""
        # Setup - device is disconnected
        assert not cpx200dp_device_disconnected.is_ready

        # Mock the connect method and subsequent recv
        cpx200dp_device_disconnected.socket_manager.recv.return_value = b"25.5\n"

        with patch.object(cpx200dp_device_disconnected, 'connect') as mock_connect:
            # The connect method should set these states
            def mock_connect_side_effect():
                cpx200dp_device_disconnected._device_validated = True
                cpx200dp_device_disconnected.socket_manager.is_connected = True

            mock_connect.side_effect = mock_connect_side_effect

            # Execute
            voltage = cpx200dp_device_disconnected.read_voltage(1)

            # Verify
            mock_connect.assert_called_once()
            assert voltage == 25.5

    def test_auto_connect_on_set_voltage(self, cpx200dp_device_disconnected):
        """Test that set_voltage automatically connects if disconnected."""
        # Setup - device is disconnected
        assert not cpx200dp_device_disconnected.is_ready

        with patch.object(cpx200dp_device_disconnected, 'connect') as mock_connect, \
             patch.object(cpx200dp_device_disconnected, 'validate_last_command'):

            # The connect method should set these states
            def mock_connect_side_effect():
                cpx200dp_device_disconnected._device_validated = True
                cpx200dp_device_disconnected.socket_manager.is_connected = True

            mock_connect.side_effect = mock_connect_side_effect

            # Execute
            cpx200dp_device_disconnected.set_voltage(12.0, 1)

            # Verify
            mock_connect.assert_called_once()
            cpx200dp_device_disconnected.socket_manager.send.assert_called_with(b"V1 12.0\n")

    def test_connection_validation(self):
        """Test device identity validation during connection."""
        connection_params = {"ip_address": "192.168.0.1"}
        device = AimTTiCPX200DPPowerSupply(connection_params)
        device.socket_manager = MagicMock()
        device.socket_manager.connect.return_value = None
        device.socket_manager.is_connected = True

        # Test successful validation
        with patch.object(device, 'read_identity', return_value="THURLBY THANDAR CPX200DP"):
            device.connect()
            assert device._device_validated is True

        # Test failed validation
        device._device_validated = False
        with patch.object(device, 'read_identity', return_value="UNKNOWN DEVICE"):
            with pytest.raises(PowerSupplyConnectionError, match="Unexpected device identity"):
                device.connect()
            assert device._device_validated is False


class TestCPX200DPErrorHandling:
    """Tests for error handling and validation."""

    def test_socket_error_handling(self, aimtti_cpx200dp_device):
        """Test handling of socket errors."""
        # Simulate socket error during send
        aimtti_cpx200dp_device.socket_manager.send.side_effect = OSError("Connection lost")

        with pytest.raises(PowerSupplyParameterError, match="Failed to send command"):
            aimtti_cpx200dp_device.set_voltage(12.0, 1)

    def test_parse_numeric_response_error(self, aimtti_cpx200dp_device):
        """Test error handling in numeric response parsing."""
        aimtti_cpx200dp_device.socket_manager.recv.return_value = b"ERROR: Invalid command\n"

        with pytest.raises(ValueError):
            aimtti_cpx200dp_device.read_voltage(1)

    def test_parse_numeric_response_with_units(self, aimtti_cpx200dp_device):
        """Test parsing numeric response with units and extra text."""
        aimtti_cpx200dp_device.socket_manager.recv.return_value = b"Voltage: 42.5 V\n"

        # This should work with the improved parsing logic
        with patch.object(aimtti_cpx200dp_device, '_parse_numeric_response', return_value=42.5):
            voltage = aimtti_cpx200dp_device.read_voltage(1)
            assert voltage == 42.5

    def test_validate_last_command_with_errors(self, aimtti_cpx200dp_device):
        """Test validate_last_command when errors are present."""
        with patch.object(aimtti_cpx200dp_device, 'check_errors', return_value=["Error 1", "Error 2"]):
            # The base class raises PowerSupplyError, not PowerSupplyParameterError
            with pytest.raises(PowerSupplyError, match="Error 1; Error 2"):
                aimtti_cpx200dp_device.validate_last_command()


class TestCPX200DPErrorFunctions:
    """Tests for error checking and clearing."""

    def test_check_errors(self, aimtti_cpx200dp_device):
        """Test checking device errors via EER?."""
        # Fix the device state
        aimtti_cpx200dp_device._device_validated = True
        aimtti_cpx200dp_device.socket_manager.is_connected = True
        aimtti_cpx200dp_device.socket_manager.recv.return_value = b"0\n"  # No error status

        # Execution
        errors = aimtti_cpx200dp_device.check_errors()

        # Verification
        aimtti_cpx200dp_device.socket_manager.send.assert_called_once_with(b"EER?\n")
        aimtti_cpx200dp_device.socket_manager.recv.assert_called_once_with(4096)
        assert errors == []

    def test_check_errors_with_error_flag(self, aimtti_cpx200dp_device):
        """Test checking device errors when EER indicates an error."""
        # Fix the device state
        aimtti_cpx200dp_device._device_validated = True
        aimtti_cpx200dp_device.socket_manager.is_connected = True
        aimtti_cpx200dp_device.socket_manager.recv.return_value = b"1\n"  # Non-zero indicates error present

        # Execution
        errors = aimtti_cpx200dp_device.check_errors()

        # Verification
        aimtti_cpx200dp_device.socket_manager.send.assert_called_once_with(b"EER?\n")
        aimtti_cpx200dp_device.socket_manager.recv.assert_called_once_with(4096)
        assert "1" in errors

    def test_clear_errors(self, aimtti_cpx200dp_device):
        """Test clearing device errors using EER?."""
        # Fix the device state
        aimtti_cpx200dp_device._device_validated = True
        aimtti_cpx200dp_device.socket_manager.is_connected = True
        aimtti_cpx200dp_device.socket_manager.recv.return_value = b"0\n"

        # Execution
        aimtti_cpx200dp_device.clear_errors()

        # Verification
        aimtti_cpx200dp_device.socket_manager.send.assert_called_once_with(b"EER?\n")


class TestCPX200DPRangeValidation:
    """Tests for parameter range validation."""

    def test_voltage_range_validation(self):
        """Test voltage range validation."""
        connection_params = {"ip_address": "192.168.0.1"}
        device = AimTTiCPX200DPPowerSupply(connection_params)

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
        device = AimTTiCPX200DPPowerSupply(connection_params)

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
        device = AimTTiCPX200DPPowerSupply(connection_params)

        # Valid outputs
        device.validate_output(1)  # Should not raise
        device.validate_output(2)  # Should not raise

        # Invalid outputs
        with pytest.raises(PowerSupplyParameterError, match="Invalid output"):
            device.validate_output(0)

        with pytest.raises(PowerSupplyParameterError, match="Invalid output"):
            device.validate_output(3)


class TestCPX200DPContextManager:
    """Tests for context manager functionality."""

    def test_context_manager_success(self):
        """Test successful use of context manager."""
        connection_params = {"ip_address": "192.168.0.1"}
        device = AimTTiCPX200DPPowerSupply(connection_params)
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
        device = AimTTiCPX200DPPowerSupply(connection_params)
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


class TestCPX200DPProperties:
    """Tests for property methods."""

    def test_available_outputs(self):
        """Test available_outputs property."""
        connection_params = {"ip_address": "192.168.0.1"}
        device = AimTTiCPX200DPPowerSupply(connection_params)
        assert device.available_outputs == [1, 2]

    def test_voltage_range(self):
        """Test voltage_range property."""
        connection_params = {"ip_address": "192.168.0.1"}
        device = AimTTiCPX200DPPowerSupply(connection_params)
        assert device.voltage_range == (0.0, 60.0)

    def test_current_range(self):
        """Test current_range property."""
        connection_params = {"ip_address": "192.168.0.1"}
        device = AimTTiCPX200DPPowerSupply(connection_params)
        assert device.current_range == (0.0, 10.0)

    def test_is_ready_property(self):
        """Test is_ready property logic."""
        connection_params = {"ip_address": "192.168.0.1"}
        device = AimTTiCPX200DPPowerSupply(connection_params)
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


class TestCPX200DPOutputControl:
    """Tests for output enable/disable and status."""

    def test_enable_output(self, aimtti_cpx200dp_device):
        """Enable output should send the correct command and validate last command."""
        # Ensure connected state
        aimtti_cpx200dp_device._device_validated = True
        aimtti_cpx200dp_device.socket_manager.is_connected = True

        # Avoid extra traffic from validate_last_command
        from unittest.mock import patch
        with patch.object(aimtti_cpx200dp_device, 'validate_last_command') as mock_validate:
            aimtti_cpx200dp_device.enable_output(1)
            aimtti_cpx200dp_device.socket_manager.send.assert_called_once_with(b"OP1 1\n")
            mock_validate.assert_called_once()

    def test_disable_output(self, aimtti_cpx200dp_device):
        """Disable output should send the correct command and validate last command."""
        aimtti_cpx200dp_device._device_validated = True
        aimtti_cpx200dp_device.socket_manager.is_connected = True

        from unittest.mock import patch
        with patch.object(aimtti_cpx200dp_device, 'validate_last_command') as mock_validate:
            aimtti_cpx200dp_device.disable_output(1)
            aimtti_cpx200dp_device.socket_manager.send.assert_called_once_with(b"OP1 0\n")
            mock_validate.assert_called_once()

    @pytest.mark.parametrize(
        "resp,expected",
        [
            (b"1\n", True),
            (b"0\n", False),
            (b"ON\n", True),
            (b"OFF\n", False),
            (b"ENABLED\n", True),
            (b"DISABLED\n", False),
        ],
    )
    def test_is_output_enabled_parsing(self, resp, expected, aimtti_cpx200dp_device):
        """is_output_enabled should correctly parse various device responses."""
        aimtti_cpx200dp_device._device_validated = True
        aimtti_cpx200dp_device.socket_manager.is_connected = True
        aimtti_cpx200dp_device.socket_manager.recv.return_value = resp

        state = aimtti_cpx200dp_device.is_output_enabled(1)
        aimtti_cpx200dp_device.socket_manager.send.assert_called_once_with(b"OP1?\n")
        aimtti_cpx200dp_device.socket_manager.recv.assert_called_once_with(4096)
        assert state is expected
