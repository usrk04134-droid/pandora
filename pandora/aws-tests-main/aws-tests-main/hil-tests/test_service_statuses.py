"""This test script contains all tests for selected services on Adaptio PC."""
from managers import AdaptioManager

class TestServiceStatuses:
    """Test suite for checking status of all important services on Adaptio OS"""

    def _get_service_active_state(self, adaptio_manager: AdaptioManager, service: str) -> str:
        """Return the ActiveState property of a systemd service (e.g. 'active', 'inactive', 'failed')."""
        stdout, _, _ = adaptio_manager.manager.execute_command(
            command=f"systemctl show -p ActiveState --value {service}",
            sudo=False,
        )
        return stdout.strip()

    def test_adaptio_service_active(self, adaptio_manager: AdaptioManager):
        """Test that adaptio.service is active."""
        state = self._get_service_active_state(adaptio_manager, "adaptio.service")
        assert state == "active", f"adaptio.service: expected 'active', got '{state}'"

    def test_adaptio_intermediary_service_active(self, adaptio_manager: AdaptioManager):
        """Test that adaptio-intermediary.service is active."""
        state = self._get_service_active_state(adaptio_manager, "adaptio-intermediary.service")
        assert state == "active", f"adaptio-intermediary.service: expected 'active', got '{state}'"
