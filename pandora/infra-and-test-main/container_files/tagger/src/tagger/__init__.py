"""Tagger package for analyzing git repositories and managing version tags."""

from laserbeak import logger as _logger
from laserbeak import setup_logging

# Remove any default handlers
_logger.remove()

setup_logging("TAGGER")
logger = _logger
