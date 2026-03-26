import re
import socket
import time
from typing import Any, Callable, Dict, Type, Union

from loguru import logger

from .abstract_power_supply import AbstractPowerSupply, PowerSupplyConnectionError, PowerSupplyParameterError


# Factory pattern for creating power supply instances
class PowerSupplyFactory:
    """Factory for creating power supply instances."""

    _registry: Dict[str, type] = {}
    _identity_patterns: Dict[str, str] = {}

    @classmethod
    def register(cls, name: str, power_supply_class: type, identity_pattern: Union[str, None] = None) -> None:
        """
        Register a power supply implementation.

        Args:
            name: Model name identifier
            power_supply_class: Class implementing AbstractPowerSupply
            identity_pattern: Regex pattern or substring to match in *IDN? response
        """
        cls._registry[name.lower()] = power_supply_class
        if identity_pattern:
            cls._identity_patterns[name.lower()] = identity_pattern

    @classmethod
    def create(cls, model: str, connection_params: Dict[str, Any]) -> AbstractPowerSupply:
        """Create a power supply instance by model name."""
        model_lower = model.lower()
        if model_lower not in cls._registry:
            available_models = list(cls._registry.keys())
            raise ValueError(f"Unknown power supply model '{model}'. Available: {available_models}")

        power_supply_class = cls._registry[model_lower]
        return power_supply_class(connection_params)

    @classmethod
    def auto_detect(cls, connection_params: Dict[str, Any]) -> AbstractPowerSupply:
        """
        Automatically detect and create the appropriate power supply instance.

        This method connects to the device, reads its identity, and creates
        the appropriate power supply instance based on the *IDN? response.

        Args:
            connection_params: Connection parameters (must include 'ip_address')

        Returns:
            Appropriate power supply instance

        Raises:
            PowerSupplyConnectionError: If connection fails
            ValueError: If device cannot be identified
        """
        # Ensure we have an IP address for TCP connection
        if "ip_address" not in connection_params:
            raise PowerSupplyParameterError("Auto-detection requires 'ip_address' in connection_params")

        # Try to connect and get identity
        identity = cls._probe_device_identity(connection_params)

        # Try to match identity against known patterns
        for model_name, pattern in cls._identity_patterns.items():
            if re.search(pattern, identity, re.IGNORECASE):
                logger.info(f"Auto-detected device: {model_name} (matched pattern: {pattern}")
                return cls.create(model_name, connection_params)

        # If no pattern matches, try substring matching as fallback
        identity_upper = identity.upper()
        if "CPX200DP" in identity_upper:
            logger.info("Auto-detected device: aimtti_cpx200dp (substring match)")
            return cls.create("aimtti_cpx200dp", connection_params)
        elif "E36234A" in identity_upper:
            logger.info("Auto-detected device: keysight_e36234a (substring match)")
            return cls.create("keysight_e36234a", connection_params)

        # Could not identify device
        available_models = list(cls._registry.keys())
        raise ValueError(f"Could not identify device from identity: '{identity}'. Available models: {available_models}")

    @classmethod
    def _probe_device_identity(cls, connection_params: Dict[str, Any]) -> str:
        """
        Probe device identity using raw TCP/SCPI connection.

        This creates a temporary connection to read the device identity
        without committing to a specific power supply implementation.
        """

        ip_address = connection_params["ip_address"]
        port = connection_params.get("port", 9221)  # Default to CPX200DP port first

        # Try common ports for power supplies
        ports_to_try = [
            port,  # User specified or CPX200DP default (9221)
            5025,  # Standard SCPI over TCP port (Keysight default)
            9221,  # CPX200DP port
            5024,  # Alternative SCPI port
        ]

        last_error = None

        for try_port in ports_to_try:
            try:
                # Create socket connection
                sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                sock.settimeout(5.0)  # 5 second timeout
                sock.connect((ip_address, try_port))

                # Send *IDN? command
                sock.send(b"*IDN?\n")
                time.sleep(0.1)  # Brief pause for response

                # Read response
                response = sock.recv(1024).decode("utf-8").strip()
                sock.close()

                if response and not response.startswith("ERROR"):
                    logger.debug(f"Device identity from {ip_address}:{try_port}: {response}")
                    # Update connection params with the working port
                    connection_params["port"] = try_port
                    return response

            except Exception as e:
                last_error = e
                logger.debug(f"Failed to connect to {ip_address}:{try_port} - {e}")
                if "sock" in locals():
                    try:
                        sock.close()
                    except OSError:
                        pass

        raise PowerSupplyConnectionError(
            f"Could not connect to device at {ip_address} on any port {ports_to_try}. Last error: {last_error}"
        )

    @classmethod
    def list_available_models(cls) -> list[str]:
        """Get list of available power supply models."""
        return list(cls._registry.keys())


def register_power_supply(model_name: str, identity_pattern: Union[str, None] = None) -> Callable[[Type], Type]:
    """
    Decorator to register a power supply implementation.

    Args:
        model_name: Name to register the power supply under
        identity_pattern: Regex pattern to match in *IDN? response for auto-detection
    """

    def decorator(cls: Type) -> Type:
        PowerSupplyFactory.register(model_name, cls, identity_pattern)
        return cls

    return decorator
