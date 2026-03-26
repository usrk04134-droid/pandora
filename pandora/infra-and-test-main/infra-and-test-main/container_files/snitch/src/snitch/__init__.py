"""Snitch package manages and interacts with TestRail via Python API."""

from laserbeak import logger as _logger, setup_logging

# Remove any default handlers
_logger.remove()

setup_logging("SNITCH")
logger = _logger
