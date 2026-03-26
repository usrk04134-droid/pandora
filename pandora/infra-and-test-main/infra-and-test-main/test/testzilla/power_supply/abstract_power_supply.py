from abc import ABC, abstractmethod
from typing import Any, Dict


class PowerSupplyError(Exception):
    pass


class PowerSupplyConnectionError(PowerSupplyError):
    pass


class PowerSupplyParameterError(PowerSupplyError):
    pass


class AbstractPowerSupply(ABC):
    def __init__(self, connection_params: Dict[str, Any]) -> None:
        self.connection_params = connection_params

    def __enter__(self) -> "AbstractPowerSupply":
        self.connect()
        return self

    def __exit__(
        self, exc_type: type[BaseException] | None, exc_val: BaseException | None, exc_tb: object | None
    ) -> None:
        self.disconnect()

    @property
    @abstractmethod
    def is_ready(self) -> bool:
        pass

    @property
    @abstractmethod
    def available_outputs(self) -> list[int]:
        pass

    @property
    @abstractmethod
    def voltage_range(self) -> tuple[float, float]:
        pass

    @property
    @abstractmethod
    def current_range(self) -> tuple[float, float]:
        pass

    @abstractmethod
    def connect(self) -> None:
        pass

    @abstractmethod
    def disconnect(self) -> None:
        pass

    @abstractmethod
    def read_identity(self) -> str:
        pass

    @abstractmethod
    def read_voltage(self, output: int = 1) -> float:
        pass

    @abstractmethod
    def set_voltage(self, voltage: float, output: int = 1) -> None:
        pass

    @abstractmethod
    def read_current(self, output: int = 1) -> float:
        pass

    @abstractmethod
    def set_current(self, current: float, output: int = 1) -> None:
        pass

    def read_voltage_protection(self, output: int = 1) -> float:
        raise NotImplementedError("Voltage protection reading not supported.")

    def set_voltage_protection(self, level: float, output: int = 1) -> None:
        raise NotImplementedError("Voltage protection setting not supported.")

    def read_current_protection(self, output: int = 1) -> float:
        raise NotImplementedError("Current protection reading not supported.")

    def set_current_protection(self, level: float, output: int = 1) -> None:
        raise NotImplementedError("Current protection setting not supported.")

    def read_voltage_step_size(self, output: int = 1) -> float:
        raise NotImplementedError("Voltage step size not supported.")

    def set_voltage_step_size(self, step_size: float, output: int = 1) -> None:
        raise NotImplementedError("Voltage step size not supported.")

    def read_current_step_size(self, output: int = 1) -> float:
        raise NotImplementedError("Current step size not supported.")

    def set_current_step_size(self, step_size: float, output: int = 1) -> None:
        raise NotImplementedError("Current step size not supported.")

    def increment_voltage(self, step_size: float = 1.0, output: int = 1) -> None:
        current_voltage = self.read_voltage(output)
        new_voltage = min(current_voltage + step_size, self.voltage_range[1])
        self.set_voltage(new_voltage, output)

    def decrement_voltage(self, step_size: float = 1.0, output: int = 1) -> None:
        current_voltage = self.read_voltage(output)
        new_voltage = max(current_voltage - step_size, self.voltage_range[0])
        self.set_voltage(new_voltage, output)

    def increment_current(self, step_size: float = 0.01, output: int = 1) -> None:
        current = self.read_current(output)
        new_current = min(current + step_size, self.current_range[1])
        self.set_current(new_current, output)

    def decrement_current(self, step_size: float = 0.01, output: int = 1) -> None:
        current = self.read_current(output)
        new_current = max(current - step_size, self.current_range[0])
        self.set_current(new_current, output)

    def enable_output(self, output: int = 1) -> None:
        raise NotImplementedError("Output control not supported.")

    def disable_output(self, output: int = 1) -> None:
        raise NotImplementedError("Output control not supported.")

    def is_output_enabled(self, output: int = 1) -> bool:
        raise NotImplementedError("Output status not supported.")

    def validate_output(self, output: int) -> None:
        if output not in self.available_outputs:
            raise PowerSupplyParameterError(f"Invalid output: {output}")

    def validate_voltage(self, voltage: float) -> None:
        vmin, vmax = self.voltage_range
        if not vmin <= voltage <= vmax:
            raise PowerSupplyParameterError(f"Voltage {voltage} out of range [{vmin}, {vmax}]")

    def validate_current(self, current: float) -> None:
        cmin, cmax = self.current_range
        if not cmin <= current <= cmax:
            raise PowerSupplyParameterError(f"Current {current} out of range [{cmin}, {cmax}]")

    def check_errors(self) -> list[str]:
        return []

    def validate_last_command(self) -> None:
        errors = self.check_errors()
        if errors:
            raise PowerSupplyError("; ".join(errors))

    @abstractmethod
    def clear_errors(self) -> None:
        pass
