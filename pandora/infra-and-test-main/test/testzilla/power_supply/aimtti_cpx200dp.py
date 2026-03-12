import re
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


@register_power_supply("aimtti_cpx200dp", r"THURLBY THANDAR.*CPX200DP")
class AimTTiCPX200DPPowerSupply(AbstractPowerSupply):
    """AimTTi CPX200DP power supply implementation using the abstract interface."""

    TCP_SOCKET_PORT = 9221  # Default TCP socket port for AimTTi CPX200DP

    AVAILABLE_OUTPUTS = [1, 2]

    MIN_VOLTAGE = 0.0
    MIN_CURRENT = 0.0
    MAX_VOLTAGE = 60.0
    MAX_CURRENT = 10.0

    MIN_VOLTAGE_STEP_SIZE = 0.1
    MAX_VOLTAGE_STEP_SIZE = 60.0
    MIN_CURRENT_STEP_SIZE = 0.01
    MAX_CURRENT_STEP_SIZE = 10.0

    MIN_VOLTAGE_PROTECTION = 1.0
    MAX_VOLTAGE_PROTECTION = 66.0
    MIN_CURRENT_PROTECTION = 1.0
    MAX_CURRENT_PROTECTION = 11.0

    def __init__(self, connection_params: Dict[str, Any]) -> None:
        """Initialize the AimTTi CPX200DP power supply."""
        super().__init__(connection_params)

        if "ip_address" not in connection_params:
            raise PowerSupplyParameterError("IP address required for CPX200DP")

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
        """List of available output channels for this power supply."""
        return self.AVAILABLE_OUTPUTS.copy()

    @property
    def voltage_range(self) -> tuple[float, float]:
        """Return the voltage range supported by this power supply."""
        return (self.MIN_VOLTAGE, self.MAX_VOLTAGE)

    @property
    def current_range(self) -> tuple[float, float]:
        """Return the current range supported by this power supply."""
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
                if "CPX200DP" not in identity.upper():
                    raise PowerSupplyConnectionError(f"Unexpected device identity: {identity}")
                self._device_validated = True
                logger.info(f"Connected to AimTTI CPX200DP at {self.ip_address}:{self.port} - {identity}")
        except Exception as e:
            self._device_validated = False
            raise PowerSupplyConnectionError(f"Failed to connect to CPX200DP: {e}") from e

    def disconnect(self) -> None:
        """Disconnect from device."""
        if self.socket_manager:
            self.socket_manager.close()
        self._device_validated = False
        logger.info("Disconnected from AimTTi CPX200DP")

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

    def _parse_numeric_response(self, response: str) -> float:
        """Parse numeric response, handling various formats."""
        try:
            # Try direct conversion first
            return float(response)
        except ValueError:
            # Try to extract a numeric value using regex
            # Look for a number (possibly with decimal point and sign)
            match = re.search(r"[-+]?\d*\.?\d+", response)
            if match:
                return float(match.group())

            # Fall back to extracting tokens and finding a numeric one
            tokens = response.split()
            for token in tokens:
                try:
                    return float(token)
                except ValueError:
                    continue

            # If no numeric value found, raise an error
            raise ValueError(f"Could not parse numeric response: {response}") from None

    def read_identity(self) -> str:
        """Query the device identity string."""
        return self._query_command("*IDN?")

    # ========================================================================
    # BASIC VOLTAGE & CURRENT METHODS
    # ========================================================================

    def read_voltage(self, output: int = 1) -> float:
        """Read the voltage of the specified output channel."""
        self.validate_output(output)
        response = self._query_command(f"V{output}?")
        return self._parse_numeric_response(response)

    def set_voltage(self, voltage: float, output: int = 1) -> None:
        """Set the voltage of the specified output channel."""
        self.validate_output(output)
        self.validate_voltage(voltage)
        self._write_command(f"V{output} {voltage}")
        self.validate_last_command()

    def read_current(self, output: int = 1) -> float:
        """Read the current of the specified output channel."""
        self.validate_output(output)
        response = self._query_command(f"I{output}?")
        return self._parse_numeric_response(response)

    def set_current(self, current: float, output: int = 1) -> None:
        """Set the current of the specified output channel."""
        self.validate_output(output)
        self.validate_current(current)
        self._write_command(f"I{output} {current}")
        self.validate_last_command()

    # ========================================================================
    # VOLTAGE (OVP) & CURRENT (OCP) PROTECTION METHODS
    # ========================================================================

    def set_voltage_protection(self, level: float, output: int = 1) -> None:
        """Set the over-voltage protection level for the specified output channel."""
        self.validate_output(output)
        if not self.MIN_VOLTAGE_PROTECTION <= level <= self.MAX_VOLTAGE_PROTECTION:
            msg = (
                f"Voltage protection {level}V out of range "
                f"[{self.MIN_VOLTAGE_PROTECTION}V, {self.MAX_VOLTAGE_PROTECTION}V]"
            )
            raise PowerSupplyParameterError(msg)
        self._write_command(f"OVP{output} {level}")
        self.validate_last_command()

    def read_voltage_protection(self, output: int = 1) -> float:
        """Read the over-voltage protection level for the specified output channel."""
        self.validate_output(output)
        response = self._query_command(f"OVP{output}?")
        return self._parse_numeric_response(response)

    def read_current_protection(self, output: int = 1) -> float:
        """Read the current protection level for the specified output channel."""
        self.validate_output(output)
        response = self._query_command(f"OCP{output}?")
        return self._parse_numeric_response(response)

    def set_current_protection(self, level: float, output: int = 1) -> None:
        """Set the over-current protection level for the specified output channel."""
        self.validate_output(output)
        if not self.MIN_CURRENT_PROTECTION <= level <= self.MAX_CURRENT_PROTECTION:
            msg = (
                f"Current protection {level}A out of range "
                f"[{self.MIN_CURRENT_PROTECTION}A, {self.MAX_CURRENT_PROTECTION}A]"
            )
            raise PowerSupplyParameterError(msg)
        self._write_command(f"OCP{output} {level}")
        self.validate_last_command()

    # ========================================================================
    # STEP SIZE METHODS
    # ========================================================================

    def read_voltage_step_size(self, output: int = 1) -> float:
        """Read the voltage step size for the specified output channel."""
        self.validate_output(output)
        response = self._query_command(f"DELTAV{output}?")
        return self._parse_numeric_response(response)

    def read_current_step_size(self, output: int = 1) -> float:
        """Read the current step size for the specified output channel."""
        self.validate_output(output)
        response = self._query_command(f"DELTAI{output}?")
        return self._parse_numeric_response(response)

    def set_voltage_step_size(self, step_size: float, output: int = 1) -> None:
        """Set the voltage step size for the specified output channel."""
        self.validate_output(output)
        if not self.MIN_VOLTAGE_STEP_SIZE <= step_size <= self.MAX_VOLTAGE_STEP_SIZE:
            msg = (
                f"Voltage step size {step_size}V out of range "
                f"[{self.MIN_VOLTAGE_STEP_SIZE}V, {self.MAX_VOLTAGE_STEP_SIZE}V]"
            )
            raise PowerSupplyParameterError(msg)
        self._write_command(f"DELTAV{output} {step_size}")
        self.validate_last_command()

    def set_current_step_size(self, step_size: float, output: int = 1) -> None:
        """Set the current step size for the specified output channel."""
        self.validate_output(output)
        if not self.MIN_CURRENT_STEP_SIZE <= step_size <= self.MAX_CURRENT_STEP_SIZE:
            msg = (
                f"Current step size {step_size}A out of range "
                f"[{self.MIN_CURRENT_STEP_SIZE}A, {self.MAX_CURRENT_STEP_SIZE}A]"
            )
            raise PowerSupplyParameterError(msg)
        self._write_command(f"DELTAI{output} {step_size}")
        self.validate_last_command()

    def increment_voltage(self, step_size: float = 1.0, output: int = 1) -> None:
        """Increment the voltage of the specified output channel by the step size."""
        self.validate_output(output)
        if self.read_voltage_step_size(output) != step_size:
            self.set_voltage_step_size(step_size, output)

        try:
            self._write_command(f"INCV{output}")
            self.validate_last_command()
        except Exception as e:
            raise PowerSupplyParameterError(f"Failed to increment voltage: {e}") from e

    def decrement_voltage(self, step_size: float = 1.0, output: int = 1) -> None:
        """Decrement the voltage of the specified output channel by the step size."""
        self.validate_output(output)
        if self.read_voltage_step_size(output) != step_size:
            self.set_voltage_step_size(step_size, output)

        try:
            self._write_command(f"DECV{output}")
            self.validate_last_command()
        except Exception as e:
            raise PowerSupplyParameterError(f"Failed to decrement voltage: {e}") from e

    def increment_current(self, step_size: float = 0.01, output: int = 1) -> None:
        """Increment the current of the specified output channel by the step size."""
        self.validate_output(output)
        if self.read_current_step_size(output) != step_size:
            self.set_current_step_size(step_size, output)
        try:
            self._write_command(f"INCI{output}")
            self.validate_last_command()
        except Exception as e:
            raise PowerSupplyParameterError(f"Failed to increment current: {e}") from e

    def decrement_current(self, step_size: float = 0.01, output: int = 1) -> None:
        """Decrement the current of the specified output channel by the step size."""
        self.validate_output(output)
        if self.read_current_step_size(output) != step_size:
            self.set_current_step_size(step_size, output)

        try:
            self._write_command(f"DECI{output}")
            self.validate_last_command()
        except Exception as e:
            raise PowerSupplyParameterError(f"Failed to decrement current: {e}") from e

    # ========================================================================
    # OUTPUT CONTROL METHODS
    # ========================================================================

    def enable_output(self, output: int = 1) -> None:
        """Enable the specified output channel."""
        self.validate_output(output)
        self._write_command(f"OP{output} 1")
        self.validate_last_command()

    def disable_output(self, output: int = 1) -> None:
        """Disable the specified output channel."""
        self.validate_output(output)
        self._write_command(f"OP{output} 0")
        self.validate_last_command()

    def is_output_enabled(self, output: int = 1) -> bool:
        """Query whether the specified output channel is enabled."""
        self.validate_output(output)
        resp = self._query_command(f"OP{output}?")
        try:
            return int(self._parse_numeric_response(resp)) == 1
        except Exception:
            # Fall back to string matching if numeric parse fails
            return resp.strip().upper() in {"1", "ON", "ENABLE", "ENABLED"}

    # ========================================================================
    # ERROR HANDLING METHODS
    # ========================================================================

    def check_errors(self) -> list[str]:
        """Query and clear the Execution Error Register (EER).

        EER? returns "0" when no execution errors are pending; otherwise it
        returns a code or message and clears the register.
        """
        try:
            resp = self._query_command("EER?")
            txt = resp.strip()
            if txt == "0":
                return []
            return [txt]
        except Exception as e:
            return [f"Failed to check status: {e}"]

    def clear_errors(self) -> None:
        """Clear the execution error register by querying it once."""
        try:
            # EER? both queries and clears
            _ = self._query_command("EER?")
        except Exception as e:
            logger.warning("Failed to clear errors: %s", e)
