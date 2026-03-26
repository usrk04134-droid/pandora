"""Common loguru settings for infra and test python tools."""

import os
import sys
from datetime import datetime
from pathlib import Path
from typing import Dict, Any

from loguru import logger

# Remove any default handlers
logger.remove()

# Store handler IDs for potential removal
_handler_ids: Dict[str, int] = {}

def setup_logging(app_name: str, pytest_mode: bool = False) -> Dict[str, Any]:
    """Configure logging for a given Python application.

    This function sets up loguru with both console and file outputs:
    - Console: Shows INFO level messages with clean formatting
    - File: Records TRACE level messages with detailed information

    Args:
        app_name: Used to get environment variables and generate log file name
        pytest_mode: If True, configures logging to work with pytest

    Returns:
        Dict containing logger configuration details

    Configuration can be controlled via environment variables:
    - <APP_NAME>_LOG_LEVEL: Console output log level (default: INFO)
    - <APP_NAME>_FILE_LOG_LEVEL: File output log level (default: TRACE)
    - <APP_NAME>_LOG_DIR: Directory for log files (default: ./logs)
    """
    app_name = app_name.upper()
    # Get configuration from environment variables with defaults
    console_level = os.getenv(f"{app_name}_LOG_LEVEL", "INFO")
    file_level = os.getenv(f"{app_name}_FILE_LOG_LEVEL", "TRACE")
    log_dir = os.getenv(f"{app_name}_LOG_DIR", "./logs")

    # Ensure log directory exists
    log_dir = Path(log_dir)
    log_dir.mkdir(parents=True, exist_ok=True)

    # Generate log file name with timestamp
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    log_file = log_dir / f"{app_name}_{timestamp}.log"

    # Safely clear any existing handlers
    cleanup_logging()

    if pytest_mode:
        # Pytest-friendly logging - single unified console handler
        console_format = (
            "\n<green>{time:YYYY-MM-DD HH:mm:ss}</green> | "
            "<level>{level: <8}</level> | "
            "<level>{message}</level>"
        )
        
        _handler_ids["console"] = logger.add(
            sys.stderr,  # Use stderr to avoid pytest stdout capture
            format=console_format,
            level=console_level,
            colorize=True,
        )
    else:
        # Production logging - multiple handlers for different levels
        # INFO level - Clean format
        _handler_ids["info"] = logger.add(
            sys.stdout,
            format="{message}",
            filter=lambda record: record["level"].name == "INFO",
            level=console_level,
            colorize=True,
        )

        # DEBUG level - Detailed format
        if console_level == "DEBUG":
            _handler_ids["debug"] = logger.add(
                sys.stdout,
                format=(
                    "<green>{time:YYYY-MM-DD HH:mm:ss}</green> | <level>{level: <8}</level> | "
                    "<cyan>{name}</cyan>:<cyan>{function}</cyan>:<cyan>{line}</cyan> - <level>{message}</level>"
                ),
                filter=lambda record: record["level"].name == "DEBUG",
                level="DEBUG",
                colorize=True,
            )

        # TRACE level - Most detailed format
        if console_level == "TRACE":
            _handler_ids["trace"] = logger.add(
                sys.stdout,
                format=(
                    "<blue>{time:YYYY-MM-DD HH:mm:ss.SSS}</blue> | <level>{level: <8}</level> | "
                    "<cyan>{name}</cyan>:<cyan>{function}</cyan>:<cyan>{line}</cyan> - <level>{message}</level>"
                ),
                filter=lambda record: record["level"].name == "TRACE",
                level="TRACE",
                colorize=True,
            )

        # WARNING, ERROR, CRITICAL - Highlighted format to stderr
        _handler_ids["warnings"] = logger.add(
            sys.stderr,
            format="<yellow>{time:YYYY-MM-DD HH:mm:ss}</yellow> | <level>{level: <8}</level> | <red>{message}</red>",
            filter=lambda record: record["level"].name in ("WARNING", "ERROR", "CRITICAL"),
            level="WARNING",
            colorize=True,
        )

    # File handler with detailed logging (always enabled)
    _handler_ids["file"] = logger.add(
        str(log_file),
        format="{time:YYYY-MM-DD HH:mm:ss.SSS} | {level: <8} | {name}:{function}:{line} | {message}",
        level=file_level,
    )

    config = {
        "app_name": app_name,
        "console_level": console_level,
        "file_level": file_level,
        "log_file": str(log_file),
        "pytest_mode": pytest_mode,
        "handler_ids": _handler_ids.copy()
    }

    # Log configuration details at debug level
    logger.debug("Logging configured:")
    logger.debug(f"Console level: {console_level}")
    logger.debug(f"File level: {file_level}")
    logger.debug(f"Log file: {log_file}")
    logger.debug(f"Pytest mode: {pytest_mode}")

    return config

def get_configured_logger():
    """Get the configured logger instance."""
    return logger

def cleanup_logging():
    """Remove all configured handlers safely."""
    for handler_name, handler_id in _handler_ids.items():
        try:
            logger.remove(handler_id)
        except ValueError:
            # Handler was already removed or doesn't exist - ignore
            pass
    _handler_ids.clear()

# Export logger and functions for use by other modules
__all__ = ["logger", "setup_logging", "get_configured_logger", "cleanup_logging"]
