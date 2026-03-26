"""Tests for the power supply factory module."""

from unittest.mock import MagicMock, patch
import pytest

from testzilla.power_supply.power_supply_factory import (
    PowerSupplyFactory,
    register_power_supply,
)
from testzilla.power_supply.abstract_power_supply import (
    AbstractPowerSupply,
    PowerSupplyConnectionError,
    PowerSupplyParameterError,
)


class DummyPowerSupply(AbstractPowerSupply):
    """Dummy implementation for factory tests."""
    def connect(self): pass
    def disconnect(self): pass
    def read_identity(self): return "Dummy Identity"
    @property
    def is_ready(self): return True
    @property
    def available_outputs(self): return [1]
    @property
    def voltage_range(self): return (0, 10)
    @property
    def current_range(self): return (0, 1)
    def read_voltage(self, output=1): return 0
    def set_voltage(self, voltage, output=1): pass
    def read_current(self, output=1): return 0
    def set_current(self, current, output=1): pass
    def clear_errors(self): pass


class TestPowerSupplyFactoryRegistration:
    """Tests for model registration."""

    def test_register_and_create(self):
        PowerSupplyFactory.register("dummy", DummyPowerSupply)
        device = PowerSupplyFactory.create("dummy", {"ip_address": "1.2.3.4"})
        assert isinstance(device, DummyPowerSupply)

    def test_register_with_pattern(self):
        PowerSupplyFactory.register("pattern_model", DummyPowerSupply, r"PATTERN")
        assert "pattern_model" in PowerSupplyFactory._identity_patterns

    def test_register_power_supply_decorator(self):
        @register_power_supply("decorator_model", r"DECO")
        class DecoratedPS(DummyPowerSupply):
            pass

        assert "decorator_model" in PowerSupplyFactory._registry
        assert PowerSupplyFactory._registry["decorator_model"] is DecoratedPS


class TestPowerSupplyFactoryCreate:
    """Tests for creating devices by model name."""

    def test_create_unknown_model(self):
        with pytest.raises(ValueError, match="Unknown power supply model"):
            PowerSupplyFactory.create("nonexistent", {})


class TestPowerSupplyFactoryAutoDetect:
    """Tests for auto-detection of devices."""

    def setup_method(self):
        PowerSupplyFactory._registry.clear()
        PowerSupplyFactory._identity_patterns.clear()

    @patch.object(PowerSupplyFactory, "_probe_device_identity", return_value="DUMMY MODEL")
    def test_auto_detect_pattern_match(self, mock_probe):
        PowerSupplyFactory.register("dummy", DummyPowerSupply, r"DUMMY")
        device = PowerSupplyFactory.auto_detect({"ip_address": "1.2.3.4"})
        assert isinstance(device, DummyPowerSupply)
        mock_probe.assert_called_once_with({"ip_address": "1.2.3.4"})

    @patch.object(PowerSupplyFactory, "_probe_device_identity", return_value="AimTTi CPX200DP")
    def test_auto_detect_substring_match_cpx200dp(self, mock_probe):
        PowerSupplyFactory.register("aimtti_cpx200dp", DummyPowerSupply)
        device = PowerSupplyFactory.auto_detect({"ip_address": "1.2.3.4"})
        assert isinstance(device, DummyPowerSupply)
        mock_probe.assert_called_once_with({"ip_address": "1.2.3.4"})

    @patch.object(PowerSupplyFactory, "_probe_device_identity", return_value="Keysight E36234A")
    def test_auto_detect_substring_match_keysight(self, mock_probe):
        PowerSupplyFactory.register("keysight_e36234a", DummyPowerSupply)
        device = PowerSupplyFactory.auto_detect({"ip_address": "1.2.3.4"})
        assert isinstance(device, DummyPowerSupply)
        mock_probe.assert_called_once_with({"ip_address": "1.2.3.4"})

    @patch.object(PowerSupplyFactory, "_probe_device_identity", return_value="Unknown Device")
    def test_auto_detect_no_match(self, mock_probe):
        PowerSupplyFactory.register("dummy", DummyPowerSupply, r"DUMMY")
        with pytest.raises(ValueError, match="Could not identify device"):
            PowerSupplyFactory.auto_detect({"ip_address": "1.2.3.4"})
        mock_probe.assert_called_once_with({"ip_address": "1.2.3.4"})

    def test_auto_detect_missing_ip(self):
        with pytest.raises(PowerSupplyParameterError):
            PowerSupplyFactory.auto_detect({})


class TestProbeDeviceIdentity:
    """Tests for probing device identity via TCP."""

    @patch("socket.socket")
    def test_probe_device_identity_success(self, mock_socket_cls):
        params = {"ip_address": "1.2.3.4"}
        mock_sock = MagicMock()
        mock_sock.recv.return_value = b"TEST IDENTITY"
        mock_socket_cls.return_value = mock_sock

        identity = PowerSupplyFactory._probe_device_identity(params)
        assert identity == "TEST IDENTITY"
        mock_socket_cls.assert_called()  # socket was created

    @patch("socket.socket", side_effect=OSError("No connection"))
    def test_probe_device_identity_failure(self, mock_socket_cls):
        params = {"ip_address": "1.2.3.4"}
        with pytest.raises(PowerSupplyConnectionError):
            PowerSupplyFactory._probe_device_identity(params)
        mock_socket_cls.assert_called()  # socket creation attempted

    @patch("socket.socket")
    def test_probe_device_identity_skips_error_responses(self, mock_socket_cls):
        params = {"ip_address": "1.2.3.4"}
        mock_sock = MagicMock()
        mock_sock.recv.return_value = b"ERROR Something"
        mock_socket_cls.return_value = mock_sock
        with pytest.raises(PowerSupplyConnectionError):
            PowerSupplyFactory._probe_device_identity(params)
        mock_socket_cls.assert_called()  # socket was created


class TestListAvailableModels:
    """Tests for listing available models."""

    def test_list_available_models(self):
        PowerSupplyFactory._registry.clear()
        PowerSupplyFactory.register("dummy", DummyPowerSupply)
        models = PowerSupplyFactory.list_available_models()
        assert models == ["dummy"]


    @patch("testzilla.power_supply.power_supply_factory.socket.socket")
    def test_probe_device_identity_socket_close_raises(self, mock_socket_cls):
        """Test _probe_device_identity when socket.close() raises OSError."""
        params = {"ip_address": "1.2.3.4"}
        mock_sock = MagicMock()
        mock_sock.recv.side_effect = Exception("Connection error")
        mock_sock.close.side_effect = OSError("Already closed")
        mock_socket_cls.return_value = mock_sock

        # Execution: should not raise from socket.close()
        with pytest.raises(PowerSupplyConnectionError):
            PowerSupplyFactory._probe_device_identity(params)

        # Verification
        mock_sock.close.assert_called()
