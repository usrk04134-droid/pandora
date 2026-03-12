# Power Supply Module

This module provides a unified Python interface for controlling bench power supplies. It defines a common abstract interface and concrete drivers for specific models, with a factory to construct the appropriate driver explicitly or via auto‑detection.

Supported models in this package:

- AimTTi CPX200DP (TCP socket, default port 9221)
- Keysight E36234A (SCPI over TCP, default port 5025)

Paths in this repository: `test/testzilla/power_supply/`

## Architecture

- abstract_power_supply.py
   - Defines `AbstractPowerSupply` and exception types:
      - `PowerSupplyError`, `PowerSupplyConnectionError`, `PowerSupplyParameterError`
   - Defines the standard API that the concrete drivers must implement
   - Provides common helpers like validation, increment/decrement, context manager support
- aimtti_cpx200dp.py
   - Driver for AimTTi CPX200DP
- keysight_e36234a.py
   - Driver for Keysight E36234A
- power_supply_factory.py
   - `PowerSupplyFactory` for creating drivers by model or via `auto_detect`
   - `register_power_supply` decorator used by drivers for self‑registration
- __init__.py
   - Exposes the public symbols and ensures drivers are imported (registered)

Both drivers use `testzilla.utility.socket_manager.SocketManager` for TCP communication.

## Core concepts and API

Every power supply driver implements the same interface:

- Connection and state
   - `connect()`, `disconnect()`
   - Context manager: `with driver: ...` auto connects/disconnects
   - `is_ready` indicates the driver is connected and validated
   - `read_identity()` returns the device identity string (`*IDN?`)
- Capabilities
   - `available_outputs -> list[int]` (e.g., `[1, 2]`)
   - `voltage_range -> tuple[float, float]`
   - `current_range -> tuple[float, float]`
- Voltage/current
   - `read_voltage(output=1) -> float`
   - `set_voltage(voltage: float, output=1)`
   - `read_current(output=1) -> float`
   - `set_current(current: float, output=1)`
   - `increment_voltage(step_size=1.0, output=1)`
   - `decrement_voltage(step_size=1.0, output=1)`
   - `increment_current(step_size=0.01, output=1)`
   - `decrement_current(step_size=0.01, output=1)`
   - Step sizes can also be queried/set where supported:
      - `read_voltage_step_size`, `set_voltage_step_size`
      - `read_current_step_size`, `set_current_step_size`
- Output control
   - `enable_output(output=1)` / `disable_output(output=1)`
   - `is_output_enabled(output=1) -> bool`
- Protection (support varies by model)
   - Over‑voltage protection (OVP): `read_voltage_protection`, `set_voltage_protection`
   - Over‑current protection (OCP): `read_current_protection`, `set_current_protection`
   - Keysight driver also supports enable/disable/clear for protections
- Errors
   - `check_errors() -> list[str]` queries device error queue/register
   - `clear_errors()` clears device errors
   - `validate_last_command()` raises if the device reported an error after the last command

Exceptions you may encounter:

- `PowerSupplyConnectionError`: failures to connect/validate
- `PowerSupplyParameterError`: invalid parameters (e.g. out‑of‑range voltage/current) or command issues
- `PowerSupplyError`: generic errors

## Installation/Import

If your Python path resolves the `testzilla` package, you can import like this:

```python
from testzilla.power_supply import (
    PowerSupplyFactory,
    AbstractPowerSupply,
    PowerSupplyError,
    PowerSupplyConnectionError,
    PowerSupplyParameterError,
)
```

If running examples from within this repository without installing a package, ensure the project root (that contains `test/`) is on `PYTHONPATH`.

## Usage examples

Below examples assume TCP access to the instrument. Replace the IP address with your device’s address. Output channels are 1 or 2 for both supported models.

### 1. Create a driver explicitly by model name

```python
from testzilla.power_supply import PowerSupplyFactory, PowerSupplyParameterError

# AimTTi CPX200DP
psu = PowerSupplyFactory.create(
    model="aimtti_cpx200dp",
    connection_params={"ip_address": "192.168.0.50"},  # optional: "port": 9221
)

# Keysight E36234A
# psu = PowerSupplyFactory.create(
#     model="keysight_e36234a",
#     connection_params={"ip_address": "192.168.0.60"},  # optional: "port": 5025
# )

with psu:  # auto connect/disconnect
    psu.clear_errors()

    # Set limits
    psu.set_voltage(5.0, output=1)
    psu.set_current(2.0, output=1)

    # Enable output and verify
    psu.enable_output(output=1)
    assert psu.is_output_enabled(1)

    # Measure back
    v = psu.read_voltage(1)
    i = psu.read_current(1)
    print(f"Measured: {v:.3f} V, {i:.3f} A")

    # Step adjustments (driver will set step size if needed)
    psu.increment_voltage(step_size=0.5, output=1)
    psu.decrement_current(step_size=0.1, output=1)

    # Protections
    try:
        psu.set_voltage_protection(12.0, output=1)
    except PowerSupplyParameterError:
        # Some models require enabling or have different ranges
        pass

    # Turn off output when done
    psu.disable_output(1)
```

### 2. Auto‑detect the device model

`auto_detect` connects, issues `*IDN?`, matches known models by regex/substring, and returns the correct driver. It may probe common SCPI ports if none is specified.

```python
from testzilla.power_supply import PowerSupplyFactory

psu = PowerSupplyFactory.auto_detect({"ip_address": "192.168.0.50"})
print("Detected:", type(psu).__name__)

with psu:
    print("IDN:", psu.read_identity())
    psu.set_voltage(3.3, output=1)
    psu.set_current(1.0, output=1)
    psu.enable_output(1)
    print("V=", psu.read_voltage(1), "I=", psu.read_current(1))
    psu.disable_output(1)
```

### 3. Handling errors

```python
from testzilla.power_supply import PowerSupplyFactory, PowerSupplyConnectionError, PowerSupplyParameterError

try:
    psu = PowerSupplyFactory.auto_detect({"ip_address": "192.168.0.50"})
    with psu:
        # Intentionally set an out‑of‑range voltage to demonstrate validation
        psu.set_voltage(1000.0, output=1)
except PowerSupplyParameterError as e:
    print("Parameter error:", e)
except PowerSupplyConnectionError as e:
    print("Connection error:", e)
```

### 4. Keysight‑specific protection helpers

```python
from testzilla.power_supply import PowerSupplyFactory

psu = PowerSupplyFactory.create("keysight_e36234a", {"ip_address": "192.168.0.60"})
with psu:
    psu.clear_errors()
    psu.set_voltage_protection(12.0, output=1)
    psu.enable_voltage_protection(output=1)
    print("OVP enabled:", psu.is_voltage_protection_enabled(1))
    psu.clear_voltage_protection(output=1)

    psu.set_current_protection(2.5, output=1)
    psu.enable_current_protection(output=1)
    print("OCP enabled:", psu.is_current_protection_enabled(1))
    psu.clear_current_protection(output=1)
```

## Ranges and limits

Drivers enforce model‑specific ranges via `validate_voltage` and `validate_current`, and for step sizes and protection thresholds where applicable. Quick reference:

- AimTTi CPX200DP
   - Voltage: 0.0 – 60.0 V
   - Current: 0.0 – 10.0 A
   - Voltage step size: 0.1 – 60.0 V
   - Current step size: 0.01 – 10.0 A
   - OVP: 1.0 – 66.0 V
   - OCP: 1.0 – 11.0 A
- Keysight E36234A
   - Voltage: 0.0 – 61.8 V
   - Current: 0.0 – 10.3 A
   - Voltage step size: 0.0 – 61.8 V
   - Current step size: 0.0 – 10.3 A
   - OVP: 1.0 – 67.98 V
   - OCP: 0.0 – 11.3 A

Consult the instrument manuals for model nuances: \
[AimTTi CPX200DP Instruction Manual] \
[Keysight E36234A Instruction Manual]

## Tips

- Use the context manager to guarantee `disconnect()` on exit.
- Always check `available_outputs` before using a channel.
- After write operations, drivers call `validate_last_command()` which checks the instrument error queue/register and raises on error.
- If a method is not supported on a model, it will raise `NotImplementedError` (e.g., some protection helpers on the AimTTi).
- `PowerSupplyFactory.auto_detect` can update the chosen TCP port in your `connection_params` based on a successful probe.

## Extending: adding a new model

1. Create a new driver class that subclasses `AbstractPowerSupply`.
2. Decorate it with `@register_power_supply("your_model_name", identity_pattern=r"YOURVENDOR.*MODEL")`.
3. Implement all abstract methods and any optional protection/step‑size/output helpers your model supports.
4. Ensure your module is imported by `testzilla.power_supply.__init__` (so registration occurs).

Example skeleton:

```python
from testzilla.power_supply import AbstractPowerSupply, register_power_supply, PowerSupplyParameterError

@register_power_supply("acme_psu1000", identity_pattern=r"ACME.*PSU1000")
class AcmePSU1000(AbstractPowerSupply):
    AVAILABLE_OUTPUTS = [1]
    MIN_VOLTAGE, MAX_VOLTAGE = 0.0, 30.0
    MIN_CURRENT, MAX_CURRENT = 0.0, 5.0

    def __init__(self, connection_params):
        super().__init__(connection_params)
        # setup connection

    # implement required properties/methods...
```

[AimTTi CPX200DP Instruction Manual]: https://resources.aimtti.com/manuals/CPX200D+DP_Instruction_Manual-Iss8.pdf
[Keysight E36234A Instruction Manual]: https://www.keysight.com/us/en/assets/9018-04838/user-manuals/9018-04838.pdf
