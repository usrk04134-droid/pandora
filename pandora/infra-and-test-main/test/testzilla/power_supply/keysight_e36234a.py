from ipaddress import IPv4Address
from typing import Any, Dict

from loguru import logger

from testzilla.utility.socket_manager import SocketManager

from .abstract_power_supply import (
    AbstractPowerSupply,
    PowerSupplyConnectionError,
    PowerSupplyParameterError,
)
from .power_supply_factory import register_power_supply


@register_power_supply("keysight_e36234a", identity_pattern=r"KEYSIGHT.*E36234A")
class KeysightE36234APowerSupply(AbstractPowerSupply):
    """Keysight E36234A power supply implementation using the abstract interface."""

    TCP_SOCKET_PORT = 5025  # Default TCP socket port for Keysight E36234A

    AVAILABLE_OUTPUTS = [1, 2]

    MIN_VOLTAGE = 0.0
    MIN_CURRENT = 0.0
    MAX_VOLTAGE = 61.8
    MAX_CURRENT = 10.3

    MIN_VOLTAGE_STEP_SIZE = 0.0
    MAX_VOLTAGE_STEP_SIZE = 61.8
    MIN_CURRENT_STEP_SIZE = 0.0
    MAX_CURRENT_STEP_SIZE = 10.3

    MIN_VOLTAGE_PROTECTION = 1.0
    MAX_VOLTAGE_PROTECTION = 67.98
    MIN_CURRENT_PROTECTION = 0.0
    MAX_CURRENT_PROTECTION = 11.3

    def __init__(self, connection_params: Dict[str, Any]) -> None:
        """Initialize the Keysight E36234A power supply."""
        super().__init__(connection_params)

        if "ip_address" not in connection_params:
            raise PowerSupplyParameterError("IP address required for TCP connection.")

        ip_address = connection_params["ip_address"]
        port = connection_params.get("port", self.TCP_SOCKET_PORT)

        if isinstance(ip_address, str):
            ip_address = IPv4Address(ip_address)

        self.ip_address = ip_address
        self.port = port
        self.socket_manager = SocketManager(self.ip_address, self.port)
        self._device_validated = False

    @property
    def available_outputs(self) -> list[int]:
        """Return a copy of the list of available outputs."""
        return self.AVAILABLE_OUTPUTS.copy()

    @property
    def voltage_range(self) -> tuple[float, float]:
        """Return the voltage range supported by the power supply."""
        return (self.MIN_VOLTAGE, self.MAX_VOLTAGE)

    @property
    def current_range(self) -> tuple[float, float]:
        """Return the current range supported by the power supply."""
        return (self.MIN_CURRENT, self.MAX_CURRENT)

    @property
    def socket_connected(self) -> bool:
        """Low-level socket connection status."""
        return getattr(self.socket_manager, "is_connected", False)

    @property
    def is_ready(self) -> bool:
        """True if socket is connected and device identity has been validated."""
        return self.socket_connected and self._device_validated

    def connect(self) -> None:
        """Connect and validate device identity."""
        try:
            self.socket_manager.connect()
            if not self._device_validated:
                identity = self.read_identity()
                if "E36234A" not in identity.upper():
                    raise PowerSupplyConnectionError(f"Unexpected device identity: {identity}")
                self._device_validated = True
                logger.info(f"Connected to Keysight E36234A at {self.ip_address}:{self.port} - {identity}")
        except Exception as e:
            self._device_validated = False
            raise PowerSupplyConnectionError(f"Failed to connect to E36234A: {e}") from e

    def disconnect(self) -> None:
        """Disconnect from device."""
        if self.socket_manager:
            self.socket_manager.close()
        self._device_validated = False
        logger.info("Disconnected from Keysight E36234A")

    def _write_command(self, command: str) -> None:
        """Send command with automatic connection management."""
        if not getattr(self.socket_manager, "is_connected", False):
            self.connect()

        try:
            self.socket_manager.send((command + "\n").encode())
            logger.debug(f"Sent command: {command}")
        except Exception as e:
            self._device_validated = False
            raise PowerSupplyParameterError(f"Failed to send command '{command}': {e}") from e

    def _query_command(self, command: str) -> str:
        """Send command and return response."""
        self._write_command(command)
        try:
            response = self.socket_manager.recv(4096).decode().strip()
            logger.debug(f"Response: {response}")
            return response
        except Exception as e:
            self._device_validated = False
            raise PowerSupplyParameterError(f"Failed to receive response: {e}") from e

    def read_identity(self) -> str:
        """Read the device identity string."""
        return self._query_command("*IDN?")

    # ========================================================================
    # BASIC VOLTAGE & CURRENT METHODS
    # ========================================================================

    def read_voltage(self, output: int = 1) -> float:
        """Read the voltage of the specified output channel."""
        self.validate_output(output)
        return float(self._query_command(f"MEAS:VOLT? (@{output})"))

    def set_voltage(self, voltage: float, output: int = 1) -> None:
        """Set voltage for the specified output channel."""
        self.validate_output(output)
        self.validate_voltage(voltage)
        self._write_command(f"SOUR:VOLT {voltage},(@{output})")
        self.validate_last_command()

    def read_current(self, output: int = 1) -> float:
        """Read the current of the specified output channel."""
        self.validate_output(output)
        return float(self._query_command(f"MEAS:CURR? (@{output})"))

    def set_current(self, current: float, output: int = 1) -> None:
        """Set current for the specified output channel."""
        self.validate_output(output)
        self.validate_current(current)
        self._write_command(f"SOUR:CURR {current},(@{output})")
        self.validate_last_command()

    # ========================================================================
    # VOLTAGE PROTECTION (OVP) METHODS
    # ========================================================================

    def read_voltage_protection(self, output: int = 1) -> float:
        """Read the over-voltage protection level for the specified output channel."""
        self.validate_output(output)
        return float(self._query_command(f"VOLT:PROT? (@{output})"))

    def set_voltage_protection(self, level: float, output: int = 1) -> None:
        """Set the over-voltage protection level for the specified output channel."""
        self.validate_output(output)
        if not self.MIN_VOLTAGE_PROTECTION <= level <= self.MAX_VOLTAGE_PROTECTION:
            msg = (
                f"Voltage protection {level}V out of range "
                f"[{self.MIN_VOLTAGE_PROTECTION}V, {self.MAX_VOLTAGE_PROTECTION}V]"
            )
            raise PowerSupplyParameterError(msg)
        self._write_command(f"VOLT:PROT {level},(@{output})")
        self.validate_last_command()

    def enable_voltage_protection(self, output: int = 1) -> None:
        """Enable over-voltage protection for the specified output."""
        self.validate_output(output)
        self._write_command(f"VOLT:PROT:STAT ON,(@{output})")
        self.validate_last_command()

    def disable_voltage_protection(self, output: int = 1) -> None:
        """Disable over-voltage protection for the specified output."""
        self.validate_output(output)
        self._write_command(f"VOLT:PROT:STAT OFF,(@{output})")
        self.validate_last_command()

    def is_voltage_protection_enabled(self, output: int = 1) -> bool:
        """Return True if over-voltage protection is enabled for the specified output."""
        self.validate_output(output)
        val = self._query_command(f"VOLT:PROT:STAT? (@{output})").strip().upper()
        return val in ("1", "ON", "TRUE")

    def clear_voltage_protection(self, output: int = 1) -> None:
        """Clear an OVP trip for the specified output."""
        self.validate_output(output)
        self._write_command(f"VOLT:PROT:CLE (@{output})")
        self.validate_last_command()

    # ========================================================================
    # CURRENT PROTECTION (OCP) METHODS
    # ========================================================================

    def read_current_protection(self, output: int = 1) -> float:
        """Read OCP trip level for the specified output in amps."""
        self.validate_output(output)
        return float(self._query_command(f"CURR:PROT? (@{output})"))

    def set_current_protection(self, level: float, output: int = 1) -> None:
        """Set OCP trip level for the specified output in amps."""
        self.validate_output(output)
        if not self.MIN_CURRENT_PROTECTION <= level <= self.MAX_CURRENT_PROTECTION:
            msg = (
                f"Current protection {level}A out of range "
                f"[{self.MIN_CURRENT_PROTECTION}A, {self.MAX_CURRENT_PROTECTION}A]"
            )
            raise PowerSupplyParameterError(msg)
        self._write_command(f"CURR:PROT {level},(@{output})")
        self.validate_last_command()

    def enable_current_protection(self, output: int = 1) -> None:
        """Enable OCP for the specified output."""
        self.validate_output(output)
        self._write_command(f"CURR:PROT:STAT ON,(@{output})")
        self.validate_last_command()

    def disable_current_protection(self, output: int = 1) -> None:
        """Disable OCP for the specified output."""
        self.validate_output(output)
        self._write_command(f"CURR:PROT:STAT OFF,(@{output})")
        self.validate_last_command()

    def is_current_protection_enabled(self, output: int = 1) -> bool:
        """Return True if OCP is enabled for the specified output."""
        self.validate_output(output)
        val = self._query_command(f"CURR:PROT:STAT? (@{output})").strip().upper()
        return val in ("1", "ON", "TRUE")

    def clear_current_protection(self, output: int = 1) -> None:
        """Clear an OCP trip for the specified output."""
        self.validate_output(output)
        self._write_command(f"CURR:PROT:CLE (@{output})")
        self.validate_last_command()

    # ========================================================================
    # STEP SIZE METHODS
    # ========================================================================

    def read_voltage_step_size(self, output: int = 1) -> float:
        """Read voltage step size."""
        self.validate_output(output)
        return float(self._query_command(f"VOLT:STEP? (@{output})"))

    def set_voltage_step_size(self, step_size: float, output: int = 1) -> None:
        """Set voltage step size.

        Args:
            step_size: Step size in volts (0.0 to 61.8V for E36234A)
            output: Output channel (1 or 2)
        """
        self.validate_output(output)

        if not self.MIN_VOLTAGE_STEP_SIZE <= step_size <= self.MAX_VOLTAGE_STEP_SIZE:
            msg = (
                f"Voltage step size {step_size}V out of range "
                f"[{self.MIN_VOLTAGE_STEP_SIZE}V, {self.MAX_VOLTAGE_STEP_SIZE}V]"
            )
            raise PowerSupplyParameterError(msg)

        self._write_command(f"VOLT:STEP {step_size},(@{output})")
        self.validate_last_command()

    def read_current_step_size(self, output: int = 1) -> float:
        """Read current step size."""
        self.validate_output(output)
        return float(self._query_command(f"CURR:STEP? (@{output})"))

    def set_current_step_size(self, step_size: float, output: int = 1) -> None:
        """Set current step size.

        Args:
            step_size: Step size in amps (0.0 to 10.3A for E36234A)
            output: Output channel (1 or 2)
        """
        self.validate_output(output)

        if not self.MIN_CURRENT_STEP_SIZE <= step_size <= self.MAX_CURRENT_STEP_SIZE:
            msg = (
                f"Current step size {step_size}A out of range "
                f"[{self.MIN_CURRENT_STEP_SIZE}A, {self.MAX_CURRENT_STEP_SIZE}A]"
            )
            raise PowerSupplyParameterError(msg)

        self._write_command(f"CURR:STEP {step_size},(@{output})")
        self.validate_last_command()

    def increment_voltage(self, step_size: float = 1.0, output: int = 1) -> None:
        """Increment voltage by step size."""
        self.validate_output(output)
        if self.read_voltage_step_size(output) != step_size:
            self.set_voltage_step_size(step_size, output)

        try:
            self._write_command(f"VOLT UP,(@{output})")
            self.validate_last_command()
        except Exception as e:
            raise PowerSupplyParameterError(f"Failed to increment voltage: {e}") from e

    def decrement_voltage(self, step_size: float = 1.0, output: int = 1) -> None:
        """Decrement voltage by step size."""
        self.validate_output(output)
        if self.read_voltage_step_size(output) != step_size:
            self.set_voltage_step_size(step_size, output)

        try:
            self._write_command(f"VOLT DOWN,(@{output})")
            self.validate_last_command()
        except Exception as e:
            raise PowerSupplyParameterError(f"Failed to decrement voltage: {e}") from e

    def increment_current(self, step_size: float = 0.01, output: int = 1) -> None:
        """Increment current by step size."""
        self.validate_output(output)
        if self.read_current_step_size(output) != step_size:
            self.set_current_step_size(step_size, output)

        try:
            self._write_command(f"CURR UP,(@{output})")
            self.validate_last_command()
        except Exception as e:
            raise PowerSupplyParameterError(f"Failed to increment current: {e}") from e

    def decrement_current(self, step_size: float = 0.01, output: int = 1) -> None:
        """Decrement current by step size."""
        self.validate_output(output)
        if self.read_current_step_size(output) != step_size:
            self.set_current_step_size(step_size, output)

        try:
            self._write_command(f"CURR DOWN,(@{output})")
            self.validate_last_command()
        except Exception as e:
            raise PowerSupplyParameterError(f"Failed to decrement current: {e}") from e

    # ========================================================================
    # OUTPUT CONTROL METHODS
    # ========================================================================

    def enable_output(self, output: int = 1) -> None:
        """Enable the specified output channel."""
        self.validate_output(output)
        self._write_command(f"OUTP ON,(@{output})")
        self.validate_last_command()

    def disable_output(self, output: int = 1) -> None:
        """Disable the specified output channel."""
        self.validate_output(output)
        self._write_command(f"OUTP OFF,(@{output})")
        self.validate_last_command()

    def is_output_enabled(self, output: int = 1) -> bool:
        """Return True if the specified output channel is enabled."""
        self.validate_output(output)
        val = self._query_command(f"OUTP? (@{output})").strip().upper()
        return val in ("1", "ON", "TRUE")

    # ========================================================================
    # ERROR HANDLING METHODS
    # ========================================================================

    def clear_errors(self) -> None:
        """Clear any errors on the device."""
        try:
            self._write_command("*CLS")
        except Exception as e:
            logger.warning("Failed to clear errors: %s", e)

    def check_errors(self) -> list[str]:
        """Check for any errors on the device and return a list of error messages."""
        try:
            resp = self._query_command("SYST:ERR?")
            code_str = resp.split(",", 1)[0].strip().lstrip("+")
            try:
                code = int(code_str)
            except ValueError:
                return [resp]
            return [] if code == 0 else [resp]
        except Exception as e:
            return [f"Failed to check errors: {e}"]
