"""
Power Supply Control Module

This module provides a unified interface for controlling different power supplies
using an abstract base class and factory pattern.
"""

# Import implementations to trigger registration
from . import aimtti_cpx200dp, keysight_e36234a
from .abstract_power_supply import (
    AbstractPowerSupply,
    PowerSupplyConnectionError,
    PowerSupplyError,
    PowerSupplyParameterError,
)
from .power_supply_factory import PowerSupplyFactory, register_power_supply

__all__ = [
    "AbstractPowerSupply",
    "PowerSupplyError",
    "PowerSupplyConnectionError",
    "PowerSupplyParameterError",
    "PowerSupplyFactory",
    "register_power_supply",
]
