"""Tests for the abstract power supply interface and default implementations."""

from unittest.mock import patch
import pytest
from testzilla.power_supply.abstract_power_supply import (
    AbstractPowerSupply,
    PowerSupplyError,
    PowerSupplyConnectionError,
    PowerSupplyParameterError,
)


class MockPowerSupplyImplementation(AbstractPowerSupply):
    """Mock implementation of AbstractPowerSupply for testing purposes."""

    def __init__(self, connection_params):
        super().__init__(connection_params)
        self._connected = False
        self._voltage = 0.0
        self._current = 0.0

    @property
    def is_ready(self) -> bool:
        return self._connected

    @property
    def available_outputs(self) -> list[int]:
        return [1, 2]

    @property
    def voltage_range(self) -> tuple[float, float]:
        return (0.0, 30.0)

    @property
    def current_range(self) -> tuple[float, float]:
        return (0.0, 5.0)

    def connect(self) -> None:
        self._connected = True

    def disconnect(self) -> None:
        self._connected = False

    def read_identity(self) -> str:
        return "Test Power Supply"

    def read_voltage(self, output: int = 1) -> float:
        self.validate_output(output)
        return self._voltage

    def set_voltage(self, voltage: float, output: int = 1) -> None:
        self.validate_output(output)
        self.validate_voltage(voltage)
        self._voltage = voltage

    def read_current(self, output: int = 1) -> float:
        self.validate_output(output)
        return self._current

    def set_current(self, current: float, output: int = 1) -> None:
        self.validate_output(output)
        self.validate_current(current)
        self._current = current

    def clear_errors(self) -> None:
        pass


class TestAbstractPowerSupplyInterface:
    """Tests for the abstract power supply interface."""

    def test_abstract_class_cannot_be_instantiated(self):
        """Test that AbstractPowerSupply cannot be instantiated directly."""
        with pytest.raises(TypeError):
            AbstractPowerSupply({})

    def test_connection_params_storage(self):
        """Test that connection parameters are stored correctly."""
        params = {"ip_address": "192.168.1.100", "port": 5025}
        device = MockPowerSupplyImplementation(params)
        assert device.connection_params == params

    def test_context_manager_connect_disconnect(self):
        """Test context manager calls connect and disconnect."""
        device = MockPowerSupplyImplementation({})

        assert not device.is_ready

        with device:
            assert device.is_ready

        assert not device.is_ready

    def test_context_manager_with_exception(self):
        """Test context manager disconnects even when exception occurs."""
        device = MockPowerSupplyImplementation({})

        try:
            with device:
                assert device.is_ready
                raise ValueError("Test exception")
        except ValueError:
            pass

        assert not device.is_ready


class TestAbstractPowerSupplyValidation:
    """Tests for validation methods in the abstract class."""

    def test_validate_output_valid(self):
        """Test output validation with valid outputs."""
        device = MockPowerSupplyImplementation({})

        # Valid outputs should not raise
        device.validate_output(1)
        device.validate_output(2)

    def test_validate_output_invalid(self):
        """Test output validation with invalid outputs."""
        device = MockPowerSupplyImplementation({})

        with pytest.raises(PowerSupplyParameterError, match="Invalid output: 0"):
            device.validate_output(0)

        with pytest.raises(PowerSupplyParameterError, match="Invalid output: 3"):
            device.validate_output(3)

    def test_validate_voltage_valid(self):
        """Test voltage validation with valid values."""
        device = MockPowerSupplyImplementation({})

        # Valid voltages should not raise
        device.validate_voltage(0.0)
        device.validate_voltage(15.0)
        device.validate_voltage(30.0)

    def test_validate_voltage_invalid(self):
        """Test voltage validation with invalid values."""
        device = MockPowerSupplyImplementation({})

        with pytest.raises(PowerSupplyParameterError, match="Voltage -5.0 out of range"):
            device.validate_voltage(-5.0)

        with pytest.raises(PowerSupplyParameterError, match="Voltage 35.0 out of range"):
            device.validate_voltage(35.0)

    def test_validate_current_valid(self):
        """Test current validation with valid values."""
        device = MockPowerSupplyImplementation({})

        # Valid currents should not raise
        device.validate_current(0.0)
        device.validate_current(2.5)
        device.validate_current(5.0)

    def test_validate_current_invalid(self):
        """Test current validation with invalid values."""
        device = MockPowerSupplyImplementation({})

        with pytest.raises(PowerSupplyParameterError, match="Current -1.0 out of range"):
            device.validate_current(-1.0)

        with pytest.raises(PowerSupplyParameterError, match="Current 6.0 out of range"):
            device.validate_current(6.0)


class TestAbstractPowerSupplyDefaultImplementations:
    """Tests for default implementations of optional methods."""

    def test_default_increment_voltage(self):
        """Test default increment voltage implementation."""
        device = MockPowerSupplyImplementation({})
        device.set_voltage(10.0, 1)

        # Test normal increment
        device.increment_voltage(2.0, 1)
        assert device.read_voltage(1) == 12.0

        # Test increment that would exceed maximum (should clamp)
        device.increment_voltage(25.0, 1)  # Would be 37.0, but max is 30.0
        assert device.read_voltage(1) == 30.0

    def test_default_decrement_voltage(self):
        """Test default decrement voltage implementation."""
        device = MockPowerSupplyImplementation({})
        device.set_voltage(10.0, 1)

        # Test normal decrement
        device.decrement_voltage(3.0, 1)
        assert device.read_voltage(1) == 7.0

        # Test decrement that would go below minimum (should clamp)
        device.decrement_voltage(15.0, 1)  # Would be -8.0, but min is 0.0
        assert device.read_voltage(1) == 0.0

    def test_default_increment_current(self):
        """Test default increment current implementation."""
        device = MockPowerSupplyImplementation({})
        device.set_current(2.0, 1)

        # Test normal increment
        device.increment_current(1.0, 1)
        assert device.read_current(1) == 3.0

        # Test increment that would exceed maximum (should clamp)
        device.increment_current(5.0, 1)  # Would be 8.0, but max is 5.0
        assert device.read_current(1) == 5.0

    def test_default_decrement_current(self):
        """Test default decrement current implementation."""
        device = MockPowerSupplyImplementation({})
        device.set_current(3.0, 1)

        # Test normal decrement
        device.decrement_current(1.0, 1)
        assert device.read_current(1) == 2.0

        # Test decrement that would go below minimum (should clamp)
        device.decrement_current(5.0, 1)  # Would be -2.0, but min is 0.0
        assert device.read_current(1) == 0.0

    def test_not_implemented_methods(self):
        """Test that optional methods raise NotImplementedError by default."""
        device = MockPowerSupplyImplementation({})

        # These methods should raise NotImplementedError in the base class
        with pytest.raises(NotImplementedError, match="Voltage protection reading not supported"):
            device.read_voltage_protection(1)

        with pytest.raises(NotImplementedError, match="Voltage protection setting not supported"):
            device.set_voltage_protection(30.0, 1)

        with pytest.raises(NotImplementedError, match="Current protection reading not supported"):
            device.read_current_protection(1)

        with pytest.raises(NotImplementedError, match="Current protection setting not supported"):
            device.set_current_protection(5.0, 1)

        with pytest.raises(NotImplementedError, match="Voltage step size not supported"):
            device.read_voltage_step_size(1)

        with pytest.raises(NotImplementedError, match="Voltage step size not supported"):
            device.set_voltage_step_size(1.0, 1)

        with pytest.raises(NotImplementedError, match="Current step size not supported"):
            device.read_current_step_size(1)

        with pytest.raises(NotImplementedError, match="Current step size not supported"):
            device.set_current_step_size(0.1, 1)

        with pytest.raises(NotImplementedError, match="Output control not supported"):
            device.enable_output(1)

        with pytest.raises(NotImplementedError, match="Output control not supported"):
            device.disable_output(1)

        with pytest.raises(NotImplementedError, match="Output status not supported"):
            device.is_output_enabled(1)


class TestAbstractPowerSupplyErrorHandling:
    """Tests for error handling in the abstract class."""

    def test_check_errors_default(self):
        """Test default check_errors implementation."""
        device = MockPowerSupplyImplementation({})
        errors = device.check_errors()
        assert errors == []

    def test_validate_last_command_no_errors(self):
        """Test validate_last_command when no errors are present."""
        device = MockPowerSupplyImplementation({})

        # Should not raise when no errors
        device.validate_last_command()

    def test_validate_last_command_with_errors(self):
        """Test validate_last_command when errors are present."""
        device = MockPowerSupplyImplementation({})

        with patch.object(device, 'check_errors', return_value=["Error 1", "Error 2"]):
            with pytest.raises(PowerSupplyError, match="Error 1; Error 2"):
                device.validate_last_command()

    def test_validate_last_command_single_error(self):
        """Test validate_last_command with a single error."""
        device = MockPowerSupplyImplementation({})

        with patch.object(device, 'check_errors', return_value=["Single error"]):
            with pytest.raises(PowerSupplyError, match="Single error"):
                device.validate_last_command()


class TestPowerSupplyExceptions:
    """Tests for power supply exception hierarchy."""

    def test_exception_hierarchy(self):
        """Test that power supply exceptions have correct inheritance."""
        # PowerSupplyError is the base
        assert issubclass(PowerSupplyConnectionError, PowerSupplyError)
        assert issubclass(PowerSupplyParameterError, PowerSupplyError)

        # All are exceptions
        assert issubclass(PowerSupplyError, Exception)
        assert issubclass(PowerSupplyConnectionError, Exception)
        assert issubclass(PowerSupplyParameterError, Exception)

    def test_exception_instantiation(self):
        """Test that exceptions can be instantiated and have messages."""
        base_error = PowerSupplyError("Base error message")
        assert str(base_error) == "Base error message"

        conn_error = PowerSupplyConnectionError("Connection failed")
        assert str(conn_error) == "Connection failed"

        param_error = PowerSupplyParameterError("Invalid parameter")
        assert str(param_error) == "Invalid parameter"


class TestAbstractPowerSupplyEdgeCases:
    """Tests for edge cases and boundary conditions."""

    def test_increment_voltage_at_maximum(self):
        """Test incrementing voltage when already at maximum."""
        device = MockPowerSupplyImplementation({})
        device.set_voltage(30.0, 1)  # At maximum

        device.increment_voltage(5.0, 1)
        assert device.read_voltage(1) == 30.0  # Should stay at maximum

    def test_decrement_voltage_at_minimum(self):
        """Test decrementing voltage when already at minimum."""
        device = MockPowerSupplyImplementation({})
        device.set_voltage(0.0, 1)  # At minimum

        device.decrement_voltage(5.0, 1)
        assert device.read_voltage(1) == 0.0  # Should stay at minimum

    def test_increment_current_at_maximum(self):
        """Test incrementing current when already at maximum."""
        device = MockPowerSupplyImplementation({})
        device.set_current(5.0, 1)  # At maximum

        device.increment_current(2.0, 1)
        assert device.read_current(1) == 5.0  # Should stay at maximum

    def test_decrement_current_at_minimum(self):
        """Test decrementing current when already at minimum."""
        device = MockPowerSupplyImplementation({})
        device.set_current(0.0, 1)  # At minimum

        device.decrement_current(2.0, 1)
        assert device.read_current(1) == 0.0  # Should stay at minimum

    def test_validation_with_floating_point_precision(self):
        """Test validation works correctly with floating point precision."""
        device = MockPowerSupplyImplementation({})

        # These should work (within range)
        device.validate_voltage(29.999999)
        device.validate_current(4.999999)

        # These should still fail (outside range)
        with pytest.raises(PowerSupplyParameterError):
            device.validate_voltage(30.000001)

        with pytest.raises(PowerSupplyParameterError):
            device.validate_current(5.000001)