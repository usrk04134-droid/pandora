"""Test cases for verifying heartbeat values from PLC and Adaptio"""


class TestHeartbeats:
    """Test suite for all heartbeats of the system"""

    def test_heartbeat_plc_to_adaptio(self, setup_plc, addresses):
        plc = setup_plc
        value, _ = plc.read(var=addresses["heartbeat_from_plc"])
        assert isinstance(value, int)
        assert value > 0

    def test_heartbeat_adaptio_to_plc_relay(self, setup_plc, addresses):
        plc = setup_plc
        value, _ = plc.read(var=addresses["heartbeat_from_adaptio"])
        assert isinstance(value, int)
        assert value > 0
