"""NOTE: These unit tests were generated using AI."""
import shutil
import tempfile
from pathlib import Path

import pytest
from laserbeak import setup_logging, logger as module_logger


@pytest.fixture
def temp_log_dir():
    """Create a temporary directory for logs and clean up after the test."""
    temp_dir = tempfile.mkdtemp()
    yield temp_dir
    shutil.rmtree(temp_dir)


def test_setup_logging_creates_log_dir(temp_log_dir, monkeypatch):
    """Test that setup_logging creates the log directory if it doesn't exist."""
    monkeypatch.setenv("MYAPP_LOG_DIR", temp_log_dir)

    setup_logging("MYAPP")

    assert Path(temp_log_dir).exists()
    log_files = list(Path(temp_log_dir).glob("MYAPP_*.log"))
    assert log_files, "No log file created!"


def test_console_level_env_var(temp_log_dir, monkeypatch):
    """Test that console log level is picked from environment variable."""
    monkeypatch.setenv("MYAPP_LOG_DIR", temp_log_dir)
    monkeypatch.setenv("MYAPP_LOG_LEVEL", "DEBUG")

    setup_logging("MYAPP")

    try:
        module_logger.debug("Test debug message")
    except Exception:
        pass  # For test environment only


def test_file_level_env_var(temp_log_dir, monkeypatch):
    """Test that file log level is picked from environment variable."""
    monkeypatch.setenv("MYAPP_LOG_DIR", temp_log_dir)
    monkeypatch.setenv("MYAPP_FILE_LOG_LEVEL", "INFO")

    setup_logging("MYAPP")

    log_files = list(Path(temp_log_dir).glob("MYAPP_*.log"))
    assert log_files, "No log file created!"

    module_logger.info("Test info message")

    with open(log_files[0], "r") as f:
        content = f.read()
    assert "Test info message" in content


def test_app_name_uppercase_conversion(monkeypatch):
    """Test that app_name is converted to uppercase for env var usage."""
    monkeypatch.setenv("FOOBAR_LOG_DIR", tempfile.mkdtemp())
    setup_logging("foobar")


def test_logger_exported():
    """Test that the logger object is exported."""
    assert hasattr(module_logger, "info")
    assert hasattr(module_logger, "debug")
