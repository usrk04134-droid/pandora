"""Configuration file for all hil/demorig tests."""

import json
import os
import shlex
import shutil
import tarfile
import time
from enum import IntEnum
from pathlib import Path
from typing import Any, Iterator
from dataclasses import dataclass

import warnings
import pytest
import urllib3
import asyncio
import yaml
from laserbeak import logger, setup_logging

from managers import AdaptioManager, TestRailManager
from testzilla.utility.playwright import PlaywrightManager
from testzilla.adaptio_web_hmi.adaptio_web_hmi import (
    AdaptioWebHmi,
    AdaptioWebHmiMessage,
)
from testzilla.plc.models import PlcProgramWrite
from testzilla.plc.plc_json_rpc import PlcJsonRpc
from testzilla.utility.cleanup_utils import cleanup_web_hmi_client
from testzilla.utility.file_system import create_archive
from plc_address_space import Addresses

# Suppress urllib3 InsecureRequestWarning as early as possible (before any HTTPS requests)
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
warnings.filterwarnings("ignore", category=urllib3.exceptions.InsecureRequestWarning)

logger.remove()
setup_logging("TESTZILLA", pytest_mode=True)

# YAML configuration file path
yaml_file_path = os.path.join(os.path.dirname(__file__), "webhmi_data.yml")


def get_joint_geometry_config(joint_type: str = "cw") -> dict:
    """
    Parse joint geometry configuration from YAML file for the specified joint type.

    Args:
        joint_type: Joint type ("cw" or "lw")

    Returns:
        dict: Geometry config with keys expected by set_joint_geometry():
            - groove_depth_mm
            - left_joint_angle_rad
            - left_max_surface_angle_rad
            - right_joint_angle_rad
            - right_max_surface_angle_rad
            - upper_joint_width_mm

    Raises:
        ValueError: If joint geometry configuration not found in YAML file
    """
    with open(yaml_file_path, "r") as file:
        data = yaml.safe_load(file)

    # Find matching joint geometry key (handles suffixes like timestamps)
    yaml_key = None
    for key in data.keys():
        # Match keys like "cw_joint_geometry", "cw_joint_geometry::", "lw_joint_geometry_123"
        if key.startswith(f"{joint_type}_joint_geometry"):
            yaml_key = key
            break

    if not yaml_key or yaml_key not in data:
        raise ValueError(f"No {joint_type}_joint_geometry found in YAML file: {yaml_file_path}")

    cal_data = data[yaml_key]

    # Required fields mapping: YAML field name -> API field name
    field_mapping = {
        "groove_depth": "groove_depth_mm",
        "left_wall_angle": "left_joint_angle_rad",
        "left_max_surface_angle": "left_max_surface_angle_rad",
        "right_wall_angle": "right_joint_angle_rad",
        "right_max_surface_angle": "right_max_surface_angle_rad",
        "upper_joint_width": "upper_joint_width_mm",
    }

    # Validate all required fields have values
    missing_fields = [f for f in field_mapping if cal_data.get(f) is None]
    if missing_fields:
        raise ValueError(f"Missing or empty fields in {yaml_key}: {missing_fields}")

    # Map YAML field names to API field names
    return {api_name: float(cal_data[yaml_name]) for yaml_name, api_name in field_mapping.items()}


# dataclasses for cleaner ABW simulation configuration
@dataclass
class AbwSimConfig:
    weld_movement_type: str
    target_stickout: float
    nbr_abw_points: int
    travel_speed: float
    root_gap: float
    total_width: float
    joint_bottom_curv_radius: float
    joint_depth_percentage: float
    nbr_joint_bottom_points: int
    nbr_slices_per_rev: int
    drift_speed: float
    ignore_collisions: bool

    @dataclass
    class JointDef:
        basemetal_thickness: float
        groove_ang: float
        chamfer_ang: float
        chamfer_len: float
        root_face: float
        outer_diameter: float
        radial_offset: float

    joint_def_left: JointDef
    joint_def_right: JointDef

    @dataclass
    class LpcsConfig:
        alpha: float
        x: float
        y: float
        z: float

    lpcs_config: LpcsConfig

    @dataclass
    class OpcConfig:
        x: float
        y: float
        z: float

    opcs_config: OpcConfig


def get_abw_simulation_params(config_path: Path | None = None) -> AbwSimConfig:
    """
    Load ABW simulation parameters from YAML configuration file.

    Args:
        config_path: Path to the configuration.yaml file. If None, uses the ABW simulation config directory.

    Returns:
        AbwSimConfig: typed configuration object

    Raises:
        ValueError: If ABW simulation configuration not found or required fields are missing
    """
    if config_path is None:
        config_path = Path(__file__).parent / "adaptio_configs" / "abw_simulation_params.yaml"
    
    if not config_path.exists():
        raise ValueError(f"Configuration file not found: {config_path}")
    
    with open(config_path, "r") as file:
        data = yaml.safe_load(file)
    
    if not data or "abw_simulation" not in data:
        raise ValueError(f"No 'abw_simulation' section found in configuration file: {config_path}")
    
    abw_config = data["abw_simulation"]

    try:
        left = AbwSimConfig.JointDef(
            basemetal_thickness=float(abw_config["left_basemetal_thickness"]),
            groove_ang=float(abw_config["left_groove_ang"]),
            chamfer_ang=float(abw_config["left_chamfer_ang"]),
            chamfer_len=float(abw_config["left_chamfer_len"]),
            root_face=float(abw_config["left_root_face"]),
            outer_diameter=float(abw_config["left_outer_diameter"]),
            radial_offset=float(abw_config["left_radial_offset"]),
        )
        right = AbwSimConfig.JointDef(
            basemetal_thickness=float(abw_config["right_basemetal_thickness"]),
            groove_ang=float(abw_config["right_groove_ang"]),
            chamfer_ang=float(abw_config["right_chamfer_ang"]),
            chamfer_len=float(abw_config["right_chamfer_len"]),
            root_face=float(abw_config["right_root_face"]),
            outer_diameter=float(abw_config["right_outer_diameter"]),
            radial_offset=float(abw_config["right_radial_offset"]),
        )
        lpcs = AbwSimConfig.LpcsConfig(
            alpha=float(abw_config["lpcs_alpha"]),
            x=float(abw_config["lpcs_x"]),
            y=float(abw_config["lpcs_y"]),
            z=float(abw_config["lpcs_z"]),
        )
        opcs = AbwSimConfig.OpcConfig(
            x=float(abw_config["opcs_x"]),
            y=float(abw_config["opcs_y"]),
            z=float(abw_config["opcs_z"]),
        )
        return AbwSimConfig(
            weld_movement_type=str(abw_config["weld_movement_type"]),
            target_stickout=float(abw_config["target_stickout"]),
            nbr_abw_points=int(abw_config["nbr_abw_points"]),
            travel_speed=float(abw_config["travel_speed"]),
            root_gap=float(abw_config["root_gap"]),
            total_width=float(abw_config["total_width"]),
            joint_bottom_curv_radius=float(abw_config["joint_bottom_curv_radius"]),
            joint_depth_percentage=float(abw_config["joint_depth_percentage"]),
            nbr_joint_bottom_points=int(abw_config["nbr_joint_bottom_points"]),
            nbr_slices_per_rev=int(abw_config["nbr_slices_per_rev"]),
            drift_speed=float(abw_config["drift_speed"]),
            ignore_collisions=bool(abw_config["ignore_collisions"]),
            joint_def_left=left,
            joint_def_right=right,
            lpcs_config=lpcs,
            opcs_config=opcs,
        )
    except KeyError as e:
        raise ValueError(f"Missing required field in ABW simulation config: {e}") from e

def pytest_addoption(parser):
    parser.addoption(
        "--clean-logs", action="store_true", default=False,
        help="Remove Adaptio logs before every test case execution"
    )
    parser.addoption(
        "--collect-logs", action="store_true", default=False,
        help="Collect Adaptio logs after every test case execution"
    )
    # Playwright browser options
    parser.addoption(
        "--browser",
        action="store",
        default="chromium",
        help="Browser to use for tests: chromium or firefox",
    )
    parser.addoption(
        "--headed",
        action="store_true",
        default=False,
        help="Run tests in headed mode (show browser window)",
    )
    parser.addoption(
        "--record-video",
        action="store_true",
        default=False,
        help="Record videos of test execution",
    )
    parser.addoption(
        "--testrail", action="store_true", default=False,
        help="Update test cases and report test results to TestRail"

    )
    parser.addoption(
        "--disable-config-update", action="store_true", default=False,
        help="Disable Adaptio configuration update for applicable tests"

    )

def pytest_configure(config: pytest.Config) -> None:
    """Set global configuration options for all test runs (immutable)"""
    # Suppress InsecureRequestWarning more aggressively via pytest config
    import sys
    if not any('-W' in arg for arg in sys.argv):
        # Only apply if not already overridden via command line
        warnings.simplefilter("ignore", urllib3.exceptions.InsecureRequestWarning)
        warnings.filterwarnings("ignore", message=".*Unverified HTTPS request.*")
    
    # Disable pytest's log capture to prevent interference with our loguru setup
    config.option.log_cli = False
    config.option.log_capture = False

    config.PLC_IP = "192.168.100.10"
    config.PLC_JSON_RPC_URL = f"https://{config.PLC_IP}/api/jsonrpc"
    config.ADAPTIO_EXTERNAL_IP = "192.168.101.151"
    config.ADAPTIO_RESTART_WAIT_TIME = 5  # seconds
    config.ADAPTIO_USERNAME = "esab"
    config.ADAPTIO_PASSWORD = "esab"
    config.ADAPTIO_USER_CONFIG_PATH = Path("/var/lib/adaptio")
    config.ADAPTIO_SYSTEM_CONFIG_PATH = Path("/etc/adaptio")
    config.ADAPTIO_DB = "data.db3"

    config.ADAPTIO_SUT_LOG_PATHS = [
        Path("/var/log/adaptio"),
        #Path("/var/lib/systemd/coredump"), # Disabled due to permission issues
    ]
    config.SUT_LOGS_ROOT_LOCAL_PATH = Path.cwd() / Path("sut_logs")
    config.COLLECT_SUT_LOGS_TIMEOUT = 300  # In seconds

    config.WEB_HMI_URI = f"ws://{config.ADAPTIO_EXTERNAL_IP}:8080"

    # Bench power supply (AimTTi CPX200DP)
    config.BENCH_PSU_IP = "192.168.100.231"
    config.BENCH_PSU_PORT = 9221

    # Testrail

    config.TESTRAIL_URL = "https://esabgrnd.testrail.com"
    config.TESTRAIL_USERNAME = "team-godzilla@esab.onmicrosoft.com"
    config.TESTRAIL_API_KEY = os.getenv("TESTZILLA_TESTRAIL_API_KEY")
    config.TESTRAIL_PROJECT_ID = 34
    config.TESTRAIL_SUITE_ID = 3767
    config.TESTRAIL_SECTION_NAME = "HIL Tests"
    config.TESTRAIL_MILESTONE_ID = 265

    config.TEST_MANIFEST_FILENAME = "test-manifest.yaml"

    # Test case markers

    config.addinivalue_line(
        "markers", "plc_only: mark test as only for PLC (no Adaptio connection needed)"
    )
    config.addinivalue_line(
        "markers", "webhmi_ui: mark test as WebHMI UI test requiring browser automation"
    )
    config.addinivalue_line(
        "markers", "webhmi_settings: mark test as WebHMI settings/configuration test"
    )
    config.addinivalue_line(
        "markers", "weld: mark test as weld-related test"
    )
    config.addinivalue_line(
        "markers", "weld_process_parameters: mark test as weld process parameters test"
    )
    config.addinivalue_line(
        "markers", "weld_data_set: mark test as weld data set test"
    )
    config.addinivalue_line(
        "markers", "gen2: mark test as gen2-specific test"
    )


@pytest.fixture(name="testrail", scope="session", autouse=True)
def testrail_fixture(request: pytest.FixtureRequest) -> TestRailManager | None:
    """Initialize TestRail API"""
    if not request.config.getoption("--testrail"):
        return

    testrail = TestRailManager(request)
    testrail.initialize_client()
    return testrail


@pytest.fixture(name="testrail_management", scope="session", autouse=True)
def testrail_management_fixture(testrail: TestRailManager | None, request: pytest.FixtureRequest) -> Iterator[None]:
    """Get test case information from the test manifest data."""
    if not request.config.getoption("--testrail"):
        logger.debug("TestRail client not initialized - skipping test case management")
        yield
        return

    testrail.sync_test_cases()
    testrail.create_test_run()
    yield
    testrail.close_test_run()


@pytest.fixture(name="update_testrail_test_result", scope="function", autouse=True,)
def update_testrail_test_result_fixture(request: pytest.FixtureRequest, testrail: TestRailManager | None)\
        -> Iterator[None]:
    """Update TestRail test result after test execution."""
    if not request.config.getoption("--testrail"):
        logger.debug("TestRail client not initialized - skipping test result update")
        yield
        return

    # Store start time for elapsed calculation
    start_time = time.time()

    yield  # Test runs here

    # Calculate elapsed time in TestRail format
    elapsed_time = time.time() - start_time

    # Convert to TestRail format (whole seconds only)
    if elapsed_time < 1:
        elapsed_str = "1s"  # Minimum 1 second
    elif elapsed_time < 60:
        elapsed_str = f"{int(elapsed_time)}s"
    else:
        minutes = int(elapsed_time // 60)
        seconds = int(elapsed_time % 60)
        elapsed_str = f"{minutes}m {seconds}s" if seconds > 0 else f"{minutes}m"

    # Get the test case from the request node
    test_case = getattr(request.node, 'test_case', None)
    if not test_case:
        logger.debug(f"No test case found for {request.node.name}")
        return

    # Map pytest outcomes to TestRail status IDs
    class TestCaseStatus(IntEnum):
        PASSED = 1
        FAILED = 5
        SKIPPED = 2
        ERROR = FAILED
        XFAIL = FAILED
        XPASS = FAILED

    # Get a test outcome
    outcome = TestCaseStatus.SKIPPED  # default
    if hasattr(request.node, 'rep_call'):
        if request.node.rep_call.failed:
            outcome = TestCaseStatus.FAILED
        elif request.node.rep_call.passed:
            outcome = TestCaseStatus.PASSED
        elif request.node.rep_call.skipped:
            outcome = TestCaseStatus.SKIPPED
    elif hasattr(request.node, 'rep_setup') and request.node.rep_setup.failed:
        outcome = TestCaseStatus.ERROR

    # Handle xfail/xpass
    if hasattr(request.node, 'rep_call') and hasattr(request.node.rep_call, 'wasxfail'):
        if request.node.rep_call.passed:
            outcome = TestCaseStatus.XPASS
        elif request.node.rep_call.failed:
            outcome = TestCaseStatus.XFAIL

    status_id = outcome.value

    # Create a comment based on an outcome
    comment = f"Test executed: {test_case.name}\nOutcome: {outcome.name.upper()}"

    # Add failure details if the test failed
    if outcome in [TestCaseStatus.FAILED, TestCaseStatus.ERROR] and hasattr(request.node, 'rep_call'):
        if hasattr(request.node.rep_call, 'longrepr'):
            comment += f"\n\nFailure Details:\n{request.node.rep_call.longrepr}"

    # Update the test result in TestRail
    testrail.update_test_result(
        test_case=test_case,
        status_id=status_id,
        comment=comment,
        elapsed=elapsed_str
    )


# Hook to capture test outcomes
@pytest.hookimpl(tryfirst=True, hookwrapper=True)
def pytest_runtest_makereport(item: pytest.Item) -> Iterator[None]:
    """Hook to capture test outcomes for TestRail reporting."""
    outcome = yield
    rep = outcome.get_result()

    # Store the report on the test item for later use
    setattr(item, f"rep_{rep.when}", rep)


@pytest.fixture(name="adaptio_manager")
def adaptio_manager_fixture(request: pytest.FixtureRequest) -> Iterator[AdaptioManager]:
    """Create a manager instance for Remote Adaptio PC connection."""
    manager_wrapper = AdaptioManager(request)
    yield manager_wrapper
    manager_wrapper.close()


@pytest.fixture(name="playwright_manager")
def playwright_manager_fixture(request: pytest.FixtureRequest) -> Iterator[PlaywrightManager]:
    """Create a manager instance for Playwright browser automation."""
    manager_wrapper = PlaywrightManager(request)
    yield manager_wrapper
    manager_wrapper.close()


class WebHMISession:
    """Manages a WebHMI UI session with configuration and state tracking."""

    def __init__(
        self,
        page: Any,
        context: Any,
        base_url: str,
        config: dict[str, Any],
        web_hmi: AdaptioWebHmi | None = None
    ):
        self.page = page
        self.context = context
        self.base_url = base_url
        self.config = config
        self.web_hmi = web_hmi
        self.authenticated = False
        self._initial_state: dict[str, Any] = {}

    def navigate_to(self, path: str, wait_until: str = "domcontentloaded", timeout: int = 30000) -> None:
        """Navigate to a specific path within the WebHMI application."""
        url = f"{self.base_url}{path}"
        logger.debug(f"Navigating to: {url}")

        self.page.goto(url, wait_until=wait_until, timeout=timeout)
        self.page.wait_for_timeout(1000)

        logger.info(f"Successfully navigated to: {url}")

    def goto_abp(self) -> None:
        """Navigate to ABP page with proper setup."""
        GOTO_TIMEOUT = 60000

        self.page.set_default_timeout(GOTO_TIMEOUT)
        self.page.add_style_tag(
            content="*,*::before,*::after{transition:none!important;animation:none!important}"
        )

        self.page.goto(f"{self.base_url}/abp", wait_until="domcontentloaded", timeout=GOTO_TIMEOUT)
        self.page.wait_for_timeout(2000)

        assert "/abp" in self.page.url

        # Use ends-with ($=) selectors so numeric IDs in data-track-id don't matter
        core_panels = [
            "[data-track-id$='__Settings']",
            "[data-track-id$='__Parameters']",
            "[data-track-id^='frame__'][data-track-id$='__Status']",
        ]

        panel_found = False
        for panel_selector in core_panels:
            try:
                self.page.wait_for_selector(panel_selector, timeout=GOTO_TIMEOUT)
                panel_found = True
                logger.debug(f"Found panel: {panel_selector}")
                break
            except Exception:
                continue

        if not panel_found:
            logger.warning("No core panels found, but page loaded successfully")

        try:
            nav = self.page.locator("nav").first
            nav_visible = nav.is_visible()
            if not nav_visible:
                menu_button = self.page.locator("button svg.lucide-file-icon").locator("..")
                button_count = menu_button.count()
                if button_count > 0:
                    menu_button.first.click()
                    nav.wait_for(state="visible", timeout=5000)
        except Exception:
            logger.debug("Navigation toggle failed or not needed")

    def wait_for_page_ready(self, timeout: int = 10000) -> None:
        """Wait for page to be fully ready and interactive."""
        try:
            self.page.wait_for_load_state("networkidle", timeout=timeout)
            logger.debug("Page reached networkidle state")
        except Exception as e:
            logger.warning(f"Page did not reach networkidle state: {e}")

    def disable_animations(self) -> None:
        """Disable CSS animations and transitions for stable testing."""
        self.page.add_style_tag(
            content="*,*::before,*::after{transition:none!important;animation:none!important}"
        )
        logger.debug("Disabled page animations")

    def set_default_timeout(self, timeout: int) -> None:
        """Set default timeout for all page operations."""
        self.page.set_default_timeout(timeout)
        logger.debug(f"Set default timeout to {timeout}ms")

    def capture_state(self) -> dict[str, Any]:
        """Capture current page state including cookies, local storage, and session storage."""
        state = {
            'cookies': self.context.cookies(),
            'url': self.page.url,
            'localStorage': self.page.evaluate("() => Object.assign({}, window.localStorage)"),
            'sessionStorage': self.page.evaluate("() => Object.assign({}, window.sessionStorage)"),
        }
        logger.debug(f"Captured page state from: {state['url']}")
        return state

    def restore_state(self, state: dict[str, Any]) -> None:
        """Restore page state from a previously captured snapshot."""
        try:
            if state.get('cookies'):
                self.context.add_cookies(state['cookies'])

            if state.get('localStorage'):
                self.page.evaluate(f"(storage) => {{ Object.assign(window.localStorage, storage) }}", 
                                 state['localStorage'])

            if state.get('sessionStorage'):
                self.page.evaluate(f"(storage) => {{ Object.assign(window.sessionStorage, storage) }}", 
                                 state['sessionStorage'])

            logger.debug("Restored page state")
        except Exception as e:
            logger.warning(f"Failed to restore some state: {e}")

    def clear_state(self) -> None:
        """Clear all session state including cookies and storage."""
        try:
            self.page.evaluate("() => { localStorage.clear(); sessionStorage.clear(); }")
            self.context.clear_cookies()
            logger.debug("Cleared all session state")
        except Exception as e:
            logger.warning(f"Failed to clear some state: {e}")

    def reset_to_initial_state(self) -> None:
        """Reset session to initial captured state."""
        if self._initial_state:
            self.clear_state()
            self.restore_state(self._initial_state)
            logger.info("Reset session to initial state")
        else:
            logger.warning("No initial state captured to restore")

    def configure_settings(self, settings: dict[str, Any]) -> bool:
        """Configure WebHMI settings via WebSocket if web_hmi client is available."""
        if not self.web_hmi:
            logger.debug("No web_hmi client available for configuration")
            return False

        try:
            response = self.web_hmi.send_and_receive_message(
                condition=None,
                request_name="SetSettings",
                response_name="SetSettingsRsp",
                payload=settings,
            )

            result = getattr(response, "result", None) or response.payload.get("result")
            if response and result == "ok":
                logger.info(f"Successfully configured settings: {list(settings.keys())}")
                return True
            else:
                logger.warning(f"Failed to configure settings: {settings}")
                return False

        except TimeoutError:
            logger.error(f"Timeout configuring settings: {settings}")
            return False

    def cleanup(self) -> None:
        """Perform cleanup operations for this session."""
        logger.debug("Cleaning up WebHMI session")
        self.clear_state()


@pytest.fixture(name="webhmi_base_url")
def webhmi_base_url_fixture(request: pytest.FixtureRequest) -> str:
    """Provide base URL for WebHMI application."""
    base_url = f"http://{request.config.ADAPTIO_EXTERNAL_IP}"
    logger.debug(f"WebHMI base URL: {base_url}")
    return base_url


@pytest.fixture(name="webhmi_config")
def webhmi_config_fixture(request: pytest.FixtureRequest) -> dict[str, Any]:
    """Provide WebHMI configuration dictionary."""
    DEFAULT_TIMEOUT = 30000
    LOAD_TIMEOUT = 15000

    config = {
        'username': request.config.ADAPTIO_USERNAME,
        'password': request.config.ADAPTIO_PASSWORD,
        'default_timeout': DEFAULT_TIMEOUT,
        'load_timeout': LOAD_TIMEOUT,
        'screenshot_on_failure': True,
    }
    return config


@pytest.fixture(name="webhmi_session")
def webhmi_session_fixture(
    playwright_manager: PlaywrightManager,
    request: pytest.FixtureRequest,
    webhmi_base_url: str,
    webhmi_config: dict[str, Any],
) -> Iterator[WebHMISession]:
    """Provide isolated WebHMI session for a single test."""
    logger.info(f"Setting up WebHMI session for test: {request.node.name}")

    page = playwright_manager.new_page()
    context = page.context

    session = WebHMISession(
        page=page,
        context=context,
        base_url=webhmi_base_url,
        config=webhmi_config,
        web_hmi=None
    )

    session.set_default_timeout(webhmi_config['default_timeout'])
    session.disable_animations()

    logger.info("WebHMI session setup complete")

    yield session

    logger.info(f"Tearing down WebHMI session for test: {request.node.name}")

    if hasattr(request.node, 'rep_call') and request.node.rep_call.failed:
        if webhmi_config.get('screenshot_on_failure', True):
            try:
                screenshot_name = f"failure_{request.node.name}"
                playwright_manager.take_screenshot(screenshot_name)
                logger.info(f"Captured failure screenshot: {screenshot_name}")
            except Exception as e:
                logger.warning(f"Failed to capture failure screenshot: {e}")

    try:
        session.cleanup()
        logger.info("WebHMI session cleanup complete")
    except Exception as e:
        logger.error(f"Error during session cleanup: {e}")


@pytest.fixture(name="webhmi_session_with_backend")
def webhmi_session_with_backend_fixture(
    playwright_manager: PlaywrightManager,
    request: pytest.FixtureRequest,
    webhmi_base_url: str,
    webhmi_config: dict[str, Any],
) -> Iterator[WebHMISession]:
    """Provide WebHMI session with backend WebSocket communication."""
    logger.info(f"Setting up WebHMI session with backend for test: {request.node.name}")

    uri = request.config.WEB_HMI_URI
    logger.info(f"Connecting to WebHMI WebSocket: {uri}")
    web_hmi = AdaptioWebHmi(uri=uri)

    page = playwright_manager.new_page()
    context = page.context

    session = WebHMISession(
        page=page,
        context=context,
        base_url=webhmi_base_url,
        config=webhmi_config,
        web_hmi=web_hmi
    )

    session.set_default_timeout(webhmi_config['default_timeout'])
    session.disable_animations()

    logger.info("WebHMI session with backend setup complete")

    yield session

    logger.info(f"Tearing down WebHMI session with backend for test: {request.node.name}")

    if hasattr(request.node, 'rep_call') and request.node.rep_call.failed:
        if webhmi_config.get('screenshot_on_failure', True):
            try:
                screenshot_name = f"failure_{request.node.name}"
                playwright_manager.take_screenshot(screenshot_name)
                logger.info(f"Captured failure screenshot: {screenshot_name}")
            except Exception as e:
                logger.warning(f"Failed to capture failure screenshot: {e}")


    cleanup_web_hmi_client(web_hmi)

    try:
        session.cleanup()
        logger.info("WebHMI session cleanup complete")
    except Exception as e:
        logger.error(f"Error during session cleanup: {e}")


@pytest.fixture(name="webhmi_configured_session")
def webhmi_configured_session_fixture(
    webhmi_session_with_backend: WebHMISession,
    request: pytest.FixtureRequest,
) -> Iterator[WebHMISession]:
    """Provide WebHMI session with custom backend configuration via marker."""
    session = webhmi_session_with_backend
    logger.info(f"Setting up configured session for test: {request.node.name}")

    marker = request.node.get_closest_marker("webhmi_config")
    if marker and marker.args:
        config_settings = marker.args[0]
        logger.info(f"Applying configuration from marker: {config_settings}")

        success = session.configure_settings(config_settings)
        if not success:
            logger.warning("Failed to apply configuration, continuing anyway")
        else:
            logger.info("Configuration applied successfully")
    else:
        logger.debug("No webhmi_config marker found, skipping configuration")

    yield session

    logger.debug("Configured session teardown (handled by parent fixture)")


@pytest.fixture(name="delete_adaptio_logs", scope="function", autouse=True)
def delete_adaptio_logs_fixture(request: pytest.FixtureRequest) -> None:
    """Delete logs from Adaptio PC before test execution starts."""

    if not request.config.getoption("--clean-logs"):
        logger.debug("Not deleting logs, as --clean-logs option is not enabled")
        return

    # Lazily request the manager only when the flag is enabled
    adaptio_manager: AdaptioManager = request.getfixturevalue("adaptio_manager")

    adaptio_manager.stop_adaptio()
    adaptio_manager.delete_logs()
    adaptio_manager.start_adaptio()


@pytest.fixture(name="collect_adaptio_logs", scope="function", autouse=True)
def collect_adaptio_logs_fixture(request: pytest.FixtureRequest) -> Iterator[None]:
    """Collect logs from Adaptio PC after test execution completes."""
    if not request.config.getoption("--collect-logs"):
        logger.debug("Not collecting logs, as --collect-logs option is not enabled")
        yield
        return

    # Lazily request the manager only when the flag is enabled
    adaptio_manager: AdaptioManager = request.getfixturevalue("adaptio_manager")
    
    # Capture test start time for selective log collection
    adaptio_manager.capture_test_start_time()

    yield
    adaptio_manager.collect_logs()


@pytest.fixture(name="update_adaptio_config")
def update_adaptio_config_fixture(request: pytest.FixtureRequest, adaptio_manager: AdaptioManager) -> Iterator[Any]:
    """Manage adaptio config files."""
    if request.config.getoption("--disable-config-update"):
        logger.debug("Not updating config files, as --disable-config-update option is enabled")
        yield
        return

    def _update_adaptio_config(local_path: Path) -> None:
        adaptio_manager.replace_config_files(local_path)

    yield _update_adaptio_config
    adaptio_manager.restore_config_files(
        local_default_path=Path(__file__).parent / "adaptio_configs" / "default_config"
    )


@pytest.fixture(name="setup_plc", scope="module")
def setup_plc_fixture(request: pytest.FixtureRequest) -> Iterator[PlcJsonRpc]:
    """Setup function for PLC"""
    logger.info(f"Logging in to PLC with address: {request.config.PLC_JSON_RPC_URL}")
    plc = PlcJsonRpc(url=request.config.PLC_JSON_RPC_URL)
    plc.login()
    logger.info("Logged in to PLC")

    yield plc

    plc.logout()


@pytest.fixture(name="bench_psu", scope="module")
def bench_psu_fixture(request: pytest.FixtureRequest):
    """Connect to the bench power supply (AimTTi CPX200DP) on the HIL.

    Yields an ``AbstractPowerSupply`` instance.  Disables all outputs and
    disconnects during teardown.
    """
    from testzilla.power_supply import PowerSupplyFactory

    ip = request.config.BENCH_PSU_IP
    port = request.config.BENCH_PSU_PORT
    psu = PowerSupplyFactory.create(
        "aimtti_cpx200dp", {"ip_address": ip, "port": port}
    )
    psu.connect()
    identity = psu.read_identity()
    logger.info(f"Bench PSU connected: {identity}")

    yield psu

    # Teardown: disable outputs and disconnect
    for out in psu.available_outputs:
        try:
            psu.disable_output(out)
        except Exception as exc:
            logger.debug(f"bench_psu teardown: failed to disable output {out}: {exc}")
    psu.disconnect()



@pytest.fixture(name="reset_slide_cross_positions")
def reset_slide_cross_positions_fixture(setup_plc: PlcJsonRpc, addresses: dict) -> Iterator[None]:
    """Reset slide cross positions in PLC by homing them to a set position"""
    plc = setup_plc
    reset_position = 0.0

    def __reset_slide_crosses(position: float) -> None:
        logger.info(f"Starting sequence to reset slide cross positions to: {position}")
        plc.bulk_request(
            [
                PlcProgramWrite(params={"var": addresses["slide_cross_horizontal_positioning_start"], "value": False}),
                PlcProgramWrite(params={"var": addresses["slide_cross_vertical_positioning_start"], "value": False}),
                PlcProgramWrite(
                    params={"var": addresses["slide_cross_vertical_homing_set_position"], "value": position}
                ),
                PlcProgramWrite(
                    params={"var": addresses["slide_cross_horizontal_homing_set_position"], "value": position}
                ),
                PlcProgramWrite(params={"var": addresses["slide_cross_horizontal_command_home"], "value": True}),
                PlcProgramWrite(params={"var": addresses["slide_cross_vertical_command_home"], "value": True}),
                PlcProgramWrite(params={"var": addresses["slide_cross_horizontal_command_home"], "value": False}),
                PlcProgramWrite(params={"var": addresses["slide_cross_vertical_command_home"], "value": False}),
            ]
        )
        logger.info("Finished resetting slide cross positions")

    __reset_slide_crosses(reset_position)

    yield

    __reset_slide_crosses(reset_position)


@pytest.fixture(name="enable_horizontal_slide_axis")
#def enable_horizontal_slide_axis_fixture(setup_plc: PlcJsonRpc, addresses_lp3: Addresses) -> Iterator[None]:
def enable_horizontal_slide_axis_fixture(setup_plc: PlcJsonRpc,addresses: dict)-> Iterator[None]:
    plc = setup_plc
    
    enable, _ = plc.read(
    var=addresses["slide_cross_horizontal_command_home_status"])

    logger.info(f"Home command status before enabling: {enable}")

    if not enable:
        plc.write(var=addresses["slide_cross_horizontal_command_home_enable"], value=True)
        time.sleep(2)
        enable, _ = plc.read(var=addresses["slide_cross_horizontal_command_home_status"])
        assert enable        

    yield

    time.sleep(1)
    plc.write(var=addresses["slide_cross_horizontal_command_home_enable"], value=False)
    

@pytest.fixture(name="enable_vertical_slide_axis")
def enable_vertical_slide_axis_fixture(setup_plc: PlcJsonRpc, addresses: dict) -> Iterator[None]:
    plc = setup_plc

    enable, _ = plc.read(
    var=addresses["slide_cross_vertical_command_home_status"])

    logger.info(f"Home command status before enabling: {enable}")

    if not enable:
        plc.write(var=addresses["slide_cross_vertical_command_home_enable"], value=True)
        time.sleep(2)
        enable, _ = plc.read(var=addresses["slide_cross_vertical_command_home_status"])
        assert enable

    yield

    time.sleep(0.5)
    plc.write(var=addresses["slide_cross_vertical_command_home_enable"], value=False)


@pytest.fixture(name="enable_high_speed")
def enable_high_speed_fixture(setup_plc: PlcJsonRpc, addresses_lp3: Addresses) -> Iterator[None]:
    plc = setup_plc

    enabled, _ = plc.read(addresses_lp3.Io.Outputs.DQ_PushButton_HighSpeed)

    if not enabled:
        plc.write(addresses_lp3.Io.Inputs.DI_PushButton_HighSpeed, True)
        time.sleep(0.2)
        plc.write(addresses_lp3.Io.Inputs.DI_PushButton_HighSpeed, False)
        enabled, _ = plc.read(addresses_lp3.Io.Outputs.DQ_PushButton_HighSpeed)
        assert enabled


@pytest.fixture(name="disable_high_speed")
def disable_high_speed_fixture(setup_plc: PlcJsonRpc, addresses_lp3: Addresses) -> Iterator[None]:
    plc = setup_plc

    enabled, _ = plc.read(addresses_lp3.Io.Outputs.DQ_PushButton_HighSpeed)

    if enabled:
        plc.write(addresses_lp3.Io.Inputs.DI_PushButton_HighSpeed, True)
        time.sleep(0.2)
        plc.write(addresses_lp3.Io.Inputs.DI_PushButton_HighSpeed, False)
        enabled, _ = plc.read(addresses_lp3.Io.Outputs.DQ_PushButton_HighSpeed)
        assert not enabled


@pytest.fixture(name="reset_horizontal_slide_axis")
def reset_horizontal_slide_axis_fixture(setup_plc: PlcJsonRpc, addresses_lp3: Addresses) -> Iterator[None]:
    plc = setup_plc
    position = 0.0

    def __reset_horizontal_slide_axis(position: float) -> None:
        logger.info("Homing horizontal slide axis to {position} mm.")
        plc.bulk_request([
            PlcProgramWrite(params={"var": addresses_lp3.Hmi.Inputs.HorizontalSlide.Commands.HomingCommand.HomingType, "value": 0}),
            PlcProgramWrite(params={"var": addresses_lp3.Hmi.Inputs.HorizontalSlide.Commands.HomingCommand.Position, "value": position}),
            PlcProgramWrite(params={"var": addresses_lp3.Hmi.Inputs.HorizontalSlide.Commands.HomingCommand.Execute, "value": True}),
        ])
        time.sleep(0.1)

    __reset_horizontal_slide_axis(position)

    yield

    __reset_horizontal_slide_axis(position)


@pytest.fixture(name="reset_vertical_slide_axis")
def reset_vertical_slide_axis_fixture(setup_plc: PlcJsonRpc, addresses_lp3: Addresses) -> Iterator[None]:
    plc = setup_plc
    position = 0.0

    def __reset_vertical_slide_axis(position: float) -> None:
        logger.info("Homing vertical slide axis to {position} mm.")
        plc.bulk_request([
            PlcProgramWrite(params={"var": addresses_lp3.Hmi.Inputs.VerticalSlide.Commands.HomingCommand.HomingType, "value": 0}),
            PlcProgramWrite(params={"var": addresses_lp3.Hmi.Inputs.VerticalSlide.Commands.HomingCommand.Position, "value": position}),
            PlcProgramWrite(params={"var": addresses_lp3.Hmi.Inputs.VerticalSlide.Commands.HomingCommand.Execute, "value": True}),
        ])
        time.sleep(0.1)

    __reset_vertical_slide_axis(position)

    yield

    __reset_vertical_slide_axis(position)


@pytest.fixture(name="addresses")
def addresses_fixture() -> dict:
    """Fixture for defining the commonly used PLC JSON RPC addresses"""
    return {
        "heartbeat_from_adaptio": '"Adaptio.DB_AdaptioCommunication".DataFromAdaptio.Adaptio.Heartbeat',
        "heartbeat_from_plc": '"Adaptio.DB_AdaptioCommunication".DataToAdaptio.Adaptio.Heartbeat',
        "joint_tracking_button": '"UnifiedCommonData.DB_HMI".SoftButton[0].Function',
        "joint_tracking_button_flag": '"UnifiedCommonData.DB_HMI".SoftButton[0].ShowList',
        "slide_cross_x_position_from_adaptio": (
            '"Adaptio.DB_AdaptioCommunication".DataFromAdaptio.SlideCrossX.Position'
        ),
        "slide_cross_y_position_from_adaptio": (
            '"Adaptio.DB_AdaptioCommunication".DataFromAdaptio.SlideCrossY.Position'
        ),
        "slide_cross_x_position_to_adaptio": '"Adaptio.DB_AdaptioCommunication".DataToAdaptio.SlideCrossX.Position',
        "slide_cross_y_position_to_adaptio": '"Adaptio.DB_AdaptioCommunication".DataToAdaptio.SlideCrossY.Position',
        "slide_cross_horizontal_homing_set_position": (
            '"UnifiedCommonData.DB_HMI".Values.Slides.Horizontal.RuntimeParameter.Homing.SetPosition'
        ),
        "slide_cross_horizontal_command_home": '"UnifiedCommonData.DB_HMI".Values.Slides.Horizontal.Command.Home',
        "slide_cross_horizontal_command_home_enable": '"UnifiedCommonData.DB_HMI".Values.Slides.Horizontal.Command.Enable',
        "slide_cross_horizontal_command_home_status": '"UnifiedCommonData.DB_HMI".Values.Slides.Horizontal.Status.AxisStatus.Enable',
        "slide_cross_vertical_command_home_enable": '"UnifiedCommonData.DB_HMI".Values.Slides.Vertical.Command.Enable',
        "slide_cross_vertical_command_home_status": '"UnifiedCommonData.DB_HMI".Values.Slides.Vertical.Status.AxisStatus.Enable',
        "slide_cross_horizontal_position": '"UnifiedCommonData.DB_HMI".Values.Slides.Horizontal.Status.Position',
        "slide_cross_horizontal_positioning_start": (
            '"UnifiedCommonData.DB_HMI".Values.Slides.Horizontal.Command.Positioning.Start'
        ),
        "slide_cross_horizontal_velocity": '"UnifiedCommonData.DB_HMI".Values.Slides.Horizontal.Status.Velocity',
        "slide_cross_horizontal_motion_set_type": (
            '"UnifiedCommonData.DB_HMI".Values.Slides.Horizontal.RuntimeParameter.Motion.SetType'
        ),
        "slide_cross_horizontal_motion_set_target_position": (
            '"UnifiedCommonData.DB_HMI".Values.Slides.Horizontal.RuntimeParameter.Motion.SetTargetPosition'
        ),
        "slide_cross_horizontal_motion_set_speed": (
            '"UnifiedCommonData.DB_HMI".Values.Slides.Horizontal.RuntimeParameter.Motion.SetSpeed'
        ),
        "slide_cross_vertical_homing_set_position": (
            '"UnifiedCommonData.DB_HMI".Values.Slides.Vertical.RuntimeParameter.Homing.SetPosition'
        ),
        "slide_cross_vertical_command_home": '"UnifiedCommonData.DB_HMI".Values.Slides.Vertical.Command.Home',
        "slide_cross_vertical_command_halt": '"UnifiedCommonData.DB_HMI".Values.Slides.Vertical.Command.Halt',
        "slide_cross_vertical_position": '"UnifiedCommonData.DB_HMI".Values.Slides.Vertical.Status.Position',
        "slide_cross_vertical_busy_status": '"UnifiedCommonData.DB_HMI".Values.Slides.Vertical.Status.Busy',
        "slide_cross_vertical_velocity": '"UnifiedCommonData.DB_HMI".Values.Slides.Vertical.Status.Velocity',
        "slide_cross_vertical_positioning_start": (
            '"UnifiedCommonData.DB_HMI".Values.Slides.Vertical.Command.Positioning.Start'
        ),
        "slide_cross_vertical_motion_set_type": (
            '"UnifiedCommonData.DB_HMI".Values.Slides.Vertical.RuntimeParameter.Motion.SetType'
        ),
        "slide_cross_vertical_motion_set_target_position": (
            '"UnifiedCommonData.DB_HMI".Values.Slides.Vertical.RuntimeParameter.Motion.SetTargetPosition'
        ),
        "slide_cross_vertical_motion_set_speed": (
            '"UnifiedCommonData.DB_HMI".Values.Slides.Vertical.RuntimeParameter.Motion.SetSpeed'
        ),
        "rollerbed_command_home": (
            '"UnifiedCommonData.DB_HMI".Values.Rollerbed.Command.Home'
        ),
        "rollerbed_homing_done": (
            '"UnifiedCommonData.DB_HMI".Values.Rollerbed.Status.AxisStatus.HomingDone'
        ),
        # Weld PLC addresses (DataToAdaptio)
        "weld_start": '"Adaptio.DB_AdaptioCommunication".DataToAdaptio.Adaptio.Start',
        "weld_stop": '"Adaptio.DB_AdaptioCommunication".DataToAdaptio.Adaptio.Stop',
        "ps1_ready_to_start": '"Adaptio.DB_AdaptioCommunication".DataToAdaptio.PowerSource1.ReadyToWeld',
        "ps2_ready_to_start": '"Adaptio.DB_AdaptioCommunication".DataToAdaptio.PowerSource2.ReadyToWeld',
        "ps1_arcing": '"Adaptio.DB_AdaptioCommunication".DataToAdaptio.PowerSource1.Arcing',
        "ps2_arcing": '"Adaptio.DB_AdaptioCommunication".DataToAdaptio.PowerSource2.Arcing',
        # Power-source voltage / current setpoints (DataFromAdaptio)
        "ps1_voltage_setpoint": '"Adaptio.DB_AdaptioCommunication".DataFromAdaptio.PowerSource1.Voltage',
        "ps1_current_setpoint": '"Adaptio.DB_AdaptioCommunication".DataFromAdaptio.PowerSource1.Current',
        "ps2_voltage_setpoint": '"Adaptio.DB_AdaptioCommunication".DataFromAdaptio.PowerSource2.Voltage',
        "ps2_current_setpoint": '"Adaptio.DB_AdaptioCommunication".DataFromAdaptio.PowerSource2.Current',
        # Power-source actual voltage / current (DataToAdaptio)
        "ps1_voltage_actual": '"Adaptio.DB_AdaptioCommunication".DataToAdaptio.PowerSource1.Voltage',
        "ps1_current_actual": '"Adaptio.DB_AdaptioCommunication".DataToAdaptio.PowerSource1.Current',
        "ps2_voltage_actual": '"Adaptio.DB_AdaptioCommunication".DataToAdaptio.PowerSource2.Voltage',
        "ps2_current_actual": '"Adaptio.DB_AdaptioCommunication".DataToAdaptio.PowerSource2.Current',
        # Power-source status flags (DataToAdaptio)
        "ps1_in_welding_sequence": '"Adaptio.DB_AdaptioCommunication".DataToAdaptio.PowerSource1.InWeldingSequence',
        "ps1_error": '"Adaptio.DB_AdaptioCommunication".DataToAdaptio.PowerSource1.Error',
        "ps1_start_failure": '"Adaptio.DB_AdaptioCommunication".DataToAdaptio.PowerSource1.StartFailure',
        "ps2_in_welding_sequence": '"Adaptio.DB_AdaptioCommunication".DataToAdaptio.PowerSource2.InWeldingSequence',
        "ps2_error": '"Adaptio.DB_AdaptioCommunication".DataToAdaptio.PowerSource2.Error',
        "ps2_start_failure": '"Adaptio.DB_AdaptioCommunication".DataToAdaptio.PowerSource2.StartFailure',
    }


@pytest.fixture(name="addresses_lp3")
def addresses_lp3_fixture() -> Addresses:
    return Addresses()


@pytest.fixture(name="archive_collected_sut_logs", scope="session", autouse=True)
def archive_collected_sut_logs_fixture(request: pytest.FixtureRequest) -> Iterator[None]:
    """Fixture to archive collected SUT logs."""
    if not request.config.getoption("--collect-logs"):
        logger.debug("Not archiving logs, as --collect-logs option is not enabled")
        yield
        return

    yield

    local_path = request.config.SUT_LOGS_ROOT_LOCAL_PATH

    if not any(local_path.iterdir()):
        logger.warning(f"There are no collected SUT logs to archive in {local_path.as_posix()}")
        return

    logger.info("Archiving collected SUT logs")
    try:
        create_archive(
            source_dir=local_path,
            archive_path=local_path.parent / Path(f"{local_path.name}.tar.gz"),
        )
        logger.info("Done archiving collected SUT logs")
    except (tarfile.TarError, PermissionError, FileNotFoundError, NotADirectoryError):
        logger.exception("Problem archiving collected SUT logs")
    else:
        logger.debug("Remove collected SUT logs after archiving is done")
        try:
            shutil.rmtree(local_path)
        except FileNotFoundError:
            logger.debug("Problem removing SUT logs after archiving is done")

def set_joint_geometry(
    web_hmi: AdaptioWebHmi,
    groove_depth_mm: float = 40.0,
    left_joint_angle_rad: float = 0.52,
    left_max_surface_angle_rad: float = 0.34906585,
    right_joint_angle_rad: float = 0.52,
    right_max_surface_angle_rad: float = 0.34906585,
    upper_joint_width_mm: float = 58.0,
    joint_type: str = "cw"
) -> bool:
    """Set joint geometry configuration via WebHMI.
    
    Args:
        web_hmi: AdaptioWebHmi instance for communication
        groove_depth_mm: Groove depth in millimeters
        left_joint_angle_rad: Left joint angle in radians
        left_max_surface_angle_rad: Left max surface angle in radians
        right_joint_angle_rad: Right joint angle in radians
        right_max_surface_angle_rad: Right max surface angle in radians
        upper_joint_width_mm: Upper joint width in millimeters
        joint_type: Joint type (default: "cw")
        
    Returns:
        True if successful, False otherwise
    """
    try:
        response = web_hmi.send_and_receive_message(
            condition=None,
            request_name="SetJointGeometry",
            response_name="SetJointGeometryRsp",
            payload={
                "grooveDepthMm": groove_depth_mm,
                "leftJointAngleRad": left_joint_angle_rad,
                "leftMaxSurfaceAngleRad": left_max_surface_angle_rad,
                "rightJointAngleRad": right_joint_angle_rad,
                "rightMaxSurfaceAngleRad": right_max_surface_angle_rad,
                "upperJointWidthMm": upper_joint_width_mm,
                "type": joint_type,
            }
        )
        logger.debug(f"Received response: {response}")
        result = getattr(response, "result", None) or response.payload.get("result")
        if response and result == "ok":
            logger.info("Successfully set joint geometry")
            return True
        else:
            logger.warning("Failed to set joint geometry")
            return False
    except TimeoutError:
        logger.exception("Failed to set Adaptio joint geometry")
        return False


@pytest.fixture(name="joint_type")
def joint_type_fixture(request: pytest.FixtureRequest) -> str:
    """Fixture to provide joint type configuration.
    
    Can be overridden by test using @pytest.mark.parametrize or by requesting with custom value.
    Default: "lw"
    """
    marker = request.node.get_closest_marker("joint_type")
    if marker:
        return marker.args[0]
    return "lw"


@pytest.fixture(name="joint_geometry_setup")
def joint_geometry_setup_fixture(request: pytest.FixtureRequest, joint_type: str) -> None:
    """Fixture to set joint geometry configuration with type-specific values.
    
    Reads geometry parameters from webhmi_data.yml based on joint_type.
    Falls back to defaults if YAML parsing fails.
    
    Usage:
        @pytest.mark.parametrize("joint_type", ["cw", "lw"])
        def test_something(joint_geometry_setup, joint_type):
            ...
    """
    web_hmi = AdaptioWebHmi(uri=request.config.WEB_HMI_URI)
    
    try:
        # Get type-specific geometry config from YAML
        geometry_config = get_joint_geometry_config(joint_type)
        
        success = set_joint_geometry(
            web_hmi,
            joint_type=joint_type,
            **geometry_config
        )
        logger.info(f"Successfully set joint geometry for joint_type: {joint_type}")
        if not success:
            pytest.skip("Skipping tests due to failure in setting joint geometry")
    finally:
        cleanup_web_hmi_client(web_hmi)


def set_abw_simulation(
        web_hmi: AdaptioWebHmi,
        config: AbwSimConfig
        ) -> bool:
    """Set ABW simulation mode via WebHMI."""
    try:
        response = web_hmi.send_and_receive_message(
            condition=None,
            request_name="AbwSimConfigSet",
            response_name="AbwSimConfigSetRsp",
            payload={
                "weldMovementType": config.weld_movement_type,
                "targetStickout": config.target_stickout,
                "nbrAbwPoints": config.nbr_abw_points,
                "travelSpeed": config.travel_speed,
                "rootGap": config.root_gap,
                "totalWidth": config.total_width,
                "jointBottomCurvRadius": config.joint_bottom_curv_radius,
                "jointDepthPercentage": config.joint_depth_percentage,
                "nbrJointBottomPoints": config.nbr_joint_bottom_points,
                "nbrSlicesPerRev": config.nbr_slices_per_rev,
                "driftSpeed": config.drift_speed,
                "ignoreCollisions": config.ignore_collisions,
                "jointDefLeft": {
                    "basemetalThickness": config.joint_def_left.basemetal_thickness,
                    "grooveAng": config.joint_def_left.groove_ang,
                    "chamferAng": config.joint_def_left.chamfer_ang,
                    "chamferLen": config.joint_def_left.chamfer_len,
                    "rootFace": config.joint_def_left.root_face,
                    "outerDiameter": config.joint_def_left.outer_diameter,
                    "radialOffset": config.joint_def_left.radial_offset
                },
                "jointDefRight": {
                    "basemetalThickness": config.joint_def_right.basemetal_thickness,
                    "grooveAng": config.joint_def_right.groove_ang,
                    "chamferAng": config.joint_def_right.chamfer_ang,
                    "chamferLen": config.joint_def_right.chamfer_len,
                    "rootFace": config.joint_def_right.root_face,
                    "outerDiameter": config.joint_def_right.outer_diameter,
                    "radialOffset": config.joint_def_right.radial_offset
                },
                "lpcsConfig": {
                    "alpha": config.lpcs_config.alpha,
                    "x": config.lpcs_config.x,
                    "y": config.lpcs_config.y,
                    "z": config.lpcs_config.z
                },
                "opcsConfig": {
                    "x": config.opcs_config.x,
                    "y": config.opcs_config.y,
                    "z": config.opcs_config.z
                }
            }
        )
        logger.debug(f"Received response: {response}")
        result = getattr(response, "result", None) or response.payload.get("result")
        if response and result == "ok":
            logger.info("ABW simulation config set")
            return True
        else:
            logger.warning("Failed to set ABW simulation Configuration")
            return False
    except Exception as e:
        logger.exception(f"Failed to set ABW simulation Configuration: {e}")
        return False
    

def start_abw_simulation(
        web_hmi: AdaptioWebHmi,
        timeout_ms: int = 500
        ) -> bool:
    """Start ABW simulation via WebHMI."""
    try:
        response = web_hmi.send_and_receive_message(
            condition=None,
            request_name="AbwSimStart",
            response_name="AbwSimStartRsp",
            payload={"timeoutMs": timeout_ms}
        )
        logger.debug(f"Received response: {response}")
        result = getattr(response, "result", None) or response.payload.get("result")
        if response and result == "ok":
            logger.info("ABW simulation started")
            return True
        else:
            logger.warning("Failed to start ABW simulation")
            return False
    except Exception as e:
        logger.exception(f"Failed to start ABW simulation: {e}")
        return False
    

def stop_abw_simulation(web_hmi: AdaptioWebHmi) -> bool:
    """Stop ABW simulation via WebHMI."""
    try:
        response = web_hmi.send_and_receive_message(
            condition=None,
            request_name="AbwSimStop",
            response_name="AbwSimStopRsp",
            payload={}
        )
        logger.debug(f"Received response: {response}")
        result = getattr(response, "result", None) or response.payload.get("result")
        if response and result == "ok":
            logger.info("ABW simulation stopped")
            return True
        else:
            logger.warning("Failed to stop ABW simulation")
            return False
    except Exception as e:
        logger.exception(f"Failed to stop ABW simulation: {e}")
        return False


@pytest.fixture(name="joint_tracking_sim_setup")
def joint_tracking_sim_setup_fixture(request: pytest.FixtureRequest, addresses, setup_plc) -> None:
    """Fixture to prepare for joint tracking tests."""

    web_hmi = AdaptioWebHmi(uri=request.config.WEB_HMI_URI)

    try:
        plc = setup_plc

        def wait_for_value(address, expected_value, iterations):
            current_value = None
            for _ in range(iterations):
                current_value, _ = plc.read(var=address)
                if expected_value == current_value:
                    return True
                time.sleep(1)

            return False

        logger.info("Set homing for rollerbed")
        plc.write(var=addresses["rollerbed_command_home"], value=True)

        assert wait_for_value(addresses["rollerbed_homing_done"], True, 30), "Homing not done"
        plc.write(var=addresses["rollerbed_command_home"], value=False)

        response = None
        try:
            response = web_hmi.send_and_receive_message(
                condition=None,
                request_name="SetSettings",
                response_name="SetSettingsRsp",
                payload={"useEdgeSensor": False},
            )
            logger.debug(f"Received response: {response}")
            result = getattr(response, "result", None) or response.payload.get("result")
            if response and result == "ok":
                logger.info("Successfully disabled edge sensor")
            else:
                logger.warning("Failed to disable edge sensor")
                pytest.skip("Skipping joint tracking tests due to failure in disabling edge sensor")
        except TimeoutError:
            logger.exception("Failed to disable edge sensor")
            pytest.skip("Skipping joint tracking tests due to failure in disabling edge sensor")

        # Set joint geometry using the helper function
        if not set_joint_geometry(web_hmi):
            pytest.skip("Skipping joint tracking tests due to failure in setting joint geometry")

        try:
            response = web_hmi.send_and_receive_message(
                condition=None,
                request_name="LaserTorchCalSet",
                response_name="LaserTorchCalSetRsp",
                payload=    {"distanceLaserTorch": 350.0 , "stickout": 25.0, "scannerMountAngle": 0.10 }
            )
            logger.debug(f"Received response: {response}")
            result = getattr(response, "result", None) or response.payload.get("result")
            if response and result == "ok":
                logger.info("Successfully set laser to torch calibration")
            else:
                logger.warning("Failed to set laser to torch calibration")
                pytest.skip("Skipping joint tracking tests due to failure in setting laser to torch calibration")
        except TimeoutError:
            logger.exception("Failed to set laser to torch calibration")
            pytest.skip("Skipping joint tracking tests due to set laser to torch calibration")

        try:
            response = web_hmi.send_and_receive_message(
                condition=None,
                request_name="WeldObjectCalSet",
                response_name="WeldObjectCalSetRsp",
                payload=    {"residualStandardError" :  0.00,
                             "rotationCenter" : {"c1": -28.79, "c2": -115.95, "c3": -1028.50} ,
                             "torchToLpcsTranslation" : {"c1": 0.0, "c2": 349.29, "c3": -31.79},
                             "weldObjectRadius" :       1000.0,
                            "weldObjectRotationAxis" : {"c1": 1.0, "c2": 0.0, "c3": 0.0}}
            )
            logger.debug(f"Received response: {response}")
            result = getattr(response, "result", None) or response.payload.get("result")
            if response and result == "ok":
                logger.info("Successfully set weld object calibration")
            else:
                logger.warning("Failed to set weld object calibration")
                pytest.skip("Skipping joint tracking tests due to failure in set weld object calibration")
        except TimeoutError:
            logger.exception("Failed to set weld object calibration")
            pytest.skip("Skipping joint tracking tests due to set weld object calibration")
    finally:
        cleanup_web_hmi_client(web_hmi)


@pytest.fixture(name="joint_tracking_abw_sim_setup")
def joint_tracking_abw_sim_setup_fixture(request: pytest.FixtureRequest, addresses, setup_plc, update_adaptio_config) -> None:
    """Fixture to prepare for joint tracking tests."""
    update = update_adaptio_config
    update(Path(__file__).parent / Path("adaptio_configs/abw_simulation_config"))

    web_hmi = AdaptioWebHmi(uri=request.config.WEB_HMI_URI)

    try:
        plc = setup_plc

        def wait_for_value(address, expected_value, iterations):
            current_value = None
            for _ in range(iterations):
                current_value, _ = plc.read(var=address)
                if expected_value == current_value:
                    return True
                time.sleep(1)

            return False

        logger.info("Set homing for rollerbed")
        plc.write(var=addresses["rollerbed_command_home"], value=True)

        assert wait_for_value(addresses["rollerbed_homing_done"], True, 30), "Homing not done"
        plc.write(var=addresses["rollerbed_command_home"], value=False)

        response = None
        try:
            response = web_hmi.send_and_receive_message(
                condition=None,
                request_name="SetSettings",
                response_name="SetSettingsRsp",
                payload={"useEdgeSensor": False},
            )
            logger.debug(f"Received response: {response}")
            result = getattr(response, "result", None) or response.payload.get("result")
            if response and result == "ok":
                logger.info("Successfully disabled edge sensor")
            else:
                logger.warning("Failed to disable edge sensor")
                pytest.skip("Skipping joint tracking tests due to failure in disabling edge sensor")
        except TimeoutError:
            logger.exception("Failed to disable edge sensor")
            pytest.skip("Skipping joint tracking tests due to failure in disabling edge sensor")
    
        logger.info("Setting up ABW simulation")
        if not stop_abw_simulation(web_hmi):
            pytest.skip("Failed to stop ABW simulation, cannot proceed with joint tracking tests")

        try:
            abw_config = get_abw_simulation_params()
            if not set_abw_simulation(web_hmi, abw_config):
                pytest.skip("Skipping abw simulation tests due to failure in setting ABW simulation")
        except ValueError as e:
            logger.exception(f"Failed to load ABW simulation config: {e}")
            pytest.skip(f"Skipping abw simulation tests due to config loading failure: {e}")

        if not start_abw_simulation(web_hmi):
            pytest.skip("Skipping abw simulation tests due to failure in starting ABW simulation")

        # Set joint geometry using the helper function
        if not set_joint_geometry(web_hmi):
            pytest.skip("Skipping joint tracking tests due to failure in setting joint geometry")

        try:
            response = web_hmi.send_and_receive_message(
                condition=None,
                request_name="LaserTorchCalSet",
                response_name="LaserTorchCalSetRsp",
                payload=    {"distanceLaserTorch": 350.0 , "stickout": 25.0, "scannerMountAngle": 0.10 }
            )
            logger.debug(f"Received response: {response}")
            result = getattr(response, "result", None) or response.payload.get("result")
            if response and result == "ok":
                logger.info("Successfully set laser to torch calibration")
            else:
                logger.warning("Failed to set laser to torch calibration")
                pytest.skip("Skipping joint tracking tests due to failure in setting laser to torch calibration")
        except TimeoutError:
            logger.exception("Failed to set laser to torch calibration")
            pytest.skip("Skipping joint tracking tests due to set laser to torch calibration")

        try:
            response = web_hmi.send_and_receive_message(
                condition=None,
                request_name="WeldObjectCalSet",
                response_name="WeldObjectCalSetRsp",
                payload=    {"residualStandardError" :  0.00,
                             "rotationCenter" : {"c1": -28.79, "c2": -115.95, "c3": -1028.50} ,
                             "torchToLpcsTranslation" : {"c1": 0.0, "c2": 349.29, "c3": -31.79},
                             "weldObjectRadius" :       1000.0,
                            "weldObjectRotationAxis" : {"c1": 1.0, "c2": 0.0, "c3": 0.0}}
            )
            logger.debug(f"Received response: {response}")
            result = getattr(response, "result", None) or response.payload.get("result")
            if response and result == "ok":
                logger.info("Successfully set weld object calibration")
            else:
                logger.warning("Failed to set weld object calibration")
                pytest.skip("Skipping joint tracking tests due to failure in set weld object calibration")
        except TimeoutError:
            logger.exception("Failed to set weld object calibration")
            pytest.skip("Skipping joint tracking tests due to set weld object calibration")
    finally:
        cleanup_web_hmi_client(web_hmi) 


@pytest.fixture(scope="session")
def browser_type(request):
    """
    Pytest fixture to provide browser type from command line.
    
    Usage:
        pytest --browser=firefox
        pytest --browser=chromium
    """
    return request.config.getoption("--browser")


@pytest.fixture(scope="session")
def headless_mode(request):
    """
    Pytest fixture to provide headless mode setting from command line.
    
    Usage:
        pytest --headed  # Run with visible browser
    """
    return not request.config.getoption("--headed")


@pytest.fixture(scope="session")
def record_video(request):
    """
    Pytest fixture to provide video recording setting from command line.
    
    Usage:
        pytest --record-video
    """
    return request.config.getoption("--record-video")


@pytest.hookimpl(hookwrapper=True)
def pytest_sessionfinish(session: pytest.Session, exitstatus: int):
    """Clean up event loops and pending tasks after test session."""
    yield
    
    # Clean up any remaining asyncio event loops and tasks
    try:
        # Give websockets time to fully close and tasks to settle
        time.sleep(0.3)
        try:
            loop = asyncio.get_running_loop()
        except RuntimeError:
            try:
                loop = asyncio.get_event_loop()
            except RuntimeError:
                logger.debug("No event loop to clean up")
                return

        if loop and not loop.is_closed():
            if loop.is_running():
                logger.debug("Event loop still running at session finish; skipping cleanup")
                return

            try:
                pending = [task for task in asyncio.all_tasks(loop) if not task.done()]
                if not pending:
                    return

                for task in pending:
                    task.cancel()
                    logger.debug(f"Cancelled pending task: {task.get_name()}")

                try:
                    loop.run_until_complete(asyncio.gather(*pending, return_exceptions=True))
                except (asyncio.CancelledError, RuntimeError):
                    pass

                # Allow callbacks to settle
                for _ in range(5):
                    try:
                        loop.run_until_complete(asyncio.sleep(0))
                    except (asyncio.CancelledError, RuntimeError):
                        break
            except Exception as e:
                logger.debug(f"Error managing tasks: {e}")
    except Exception as e:
        logger.debug(f"Error during event loop cleanup at session end: {e}")


# ===========================================================================
# Weld data handling – helpers, constants, and fixtures
# ===========================================================================

# ---------------------------------------------------------------------------
# Raw websocket message helpers
# ---------------------------------------------------------------------------

def send_message(web_hmi: AdaptioWebHmi, name: str, payload: dict | None = None) -> None:
    """Send a JSON message over the websocket."""
    msg = AdaptioWebHmiMessage(name=name, payload=payload or {})
    web_hmi.send_message(msg)


def receive_by_name(web_hmi: AdaptioWebHmi, name: str, max_retries: int = 10) -> dict:
    """Receive the next message matching *name* and return it as a plain dict.

    Using raw ``json.loads`` instead of ``AdaptioWebHmiMessage`` avoids
    Pydantic validation failures when the server response contains a list
    payload or omits the ``payload`` key on failure.

    Transient errors (timeouts, closed connections) are caught inside the
    retry loop so that a single hiccup does not abort the entire receive
    sequence.  Uses broad ``except Exception`` because
    ``websockets.exceptions.ConnectionClosedError`` inherits from
    ``Exception``, not from ``ConnectionError``.
    """
    web_hmi.connect()
    for _ in range(max_retries):
        try:
            raw = web_hmi.ws_client.receive_message()
            data = json.loads(raw)
        except Exception as exc:
            logger.debug(f"Transient error while waiting for '{name}': {exc}, retrying")
            try:
                web_hmi.connect()
            except Exception as conn_exc:
                logger.debug(f"Reconnection attempt failed: {conn_exc}")
            continue
        if data.get("name") == name:
            return data
    raise TimeoutError(f"Did not receive '{name}' within {max_retries} attempts")


def send_and_receive(
    web_hmi: AdaptioWebHmi,
    request_name: str,
    response_name: str,
    payload: dict | None = None,
    max_retries: int = 10,
) -> dict:
    """Send a request and wait for the matching response (as a raw dict)."""
    send_message(web_hmi, request_name, payload)
    return receive_by_name(web_hmi, response_name, max_retries=max_retries)


# ---------------------------------------------------------------------------
# Default weld process parameter payloads (mirror C++ block-test data)
# ---------------------------------------------------------------------------

WPP_DEFAULT_WS1: dict[str, Any] = {
    "name": "ManualWS1",
    "method": "dc",
    "regulationType": "cc",
    "startAdjust": 10,
    "startType": "scratch",
    "voltage": 25.0,
    "current": 200.0,
    "wireSpeed": 15.0,
    "iceWireSpeed": 0.0,
    "acFrequency": 60.0,
    "acOffset": 1.2,
    "acPhaseShift": 0.5,
    "craterFillTime": 2.0,
    "burnBackTime": 1.0,
}

WPP_DEFAULT_WS2: dict[str, Any] = {
    "name": "ManualWS2",
    "method": "dc",
    "regulationType": "cc",
    "startAdjust": 10,
    "startType": "direct",
    "voltage": 28.0,
    "current": 180.0,
    "wireSpeed": 14.0,
    "iceWireSpeed": 0.0,
    "acFrequency": 60.0,
    "acOffset": 1.2,
    "acPhaseShift": 0.5,
    "craterFillTime": 2.0,
    "burnBackTime": 1.0,
}

# ---------------------------------------------------------------------------
# CRUD helper functions
# ---------------------------------------------------------------------------


def get_weld_process_parameters(web_hmi: AdaptioWebHmi) -> list[dict]:
    """Return the list of stored weld process parameters."""
    rsp = send_and_receive(web_hmi, "GetWeldProcessParameters", "GetWeldProcessParametersRsp")
    return rsp.get("payload", [])


def add_weld_process_parameters(web_hmi: AdaptioWebHmi, params: dict | None = None, **kwargs) -> dict | bool:
    """Add a weld process parameter set.

    Accepts either a single *params* dict or keyword arguments.  Returns the
    full response dict when called with *params*, or ``True``/``False`` when
    called with keyword arguments (for compatibility with the new test style).
    """
    if params is not None:
        return send_and_receive(web_hmi, "AddWeldProcessParameters", "AddWeldProcessParametersRsp", params)
    # keyword-argument style
    payload = dict(kwargs)
    try:
        rsp = send_and_receive(web_hmi, "AddWeldProcessParameters", "AddWeldProcessParametersRsp", payload)
        return rsp.get("result") == "ok"
    except Exception:
        return False


def update_weld_process_parameters(web_hmi: AdaptioWebHmi, wpp_id: int, params: dict) -> dict:
    """Update a weld process parameter set.  Returns the full response dict."""
    payload = {**params, "id": wpp_id}
    return send_and_receive(web_hmi, "UpdateWeldProcessParameters", "UpdateWeldProcessParametersRsp", payload)


def remove_weld_process_parameters(web_hmi: AdaptioWebHmi, wpp_id: int) -> dict:
    """Remove a weld process parameter set.  Returns the full response dict."""
    return send_and_receive(
        web_hmi, "RemoveWeldProcessParameters", "RemoveWeldProcessParametersRsp", {"id": wpp_id}
    )


def get_weld_data_sets(web_hmi: AdaptioWebHmi) -> list[dict]:
    """Return the list of stored weld data sets."""
    rsp = send_and_receive(web_hmi, "GetWeldDataSets", "GetWeldDataSetsRsp")
    return rsp.get("payload", [])


def add_weld_data_set(web_hmi: AdaptioWebHmi, name: str, ws1_wpp_id: int, ws2_wpp_id: int) -> dict:
    """Add a weld data set.  Returns the full response dict.

    On communication failure returns ``{"result": "fail"}``.
    """
    payload = {"name": name, "ws1WppId": ws1_wpp_id, "ws2WppId": ws2_wpp_id}
    try:
        return send_and_receive(web_hmi, "AddWeldDataSet", "AddWeldDataSetRsp", payload)
    except Exception:
        return {"result": "fail"}


def update_weld_data_set(
    web_hmi: AdaptioWebHmi, wds_id: int, name: str, ws1_wpp_id: int, ws2_wpp_id: int
) -> dict:
    """Update a weld data set.  Returns the full response dict."""
    payload = {"id": wds_id, "name": name, "ws1WppId": ws1_wpp_id, "ws2WppId": ws2_wpp_id}
    return send_and_receive(web_hmi, "UpdateWeldDataSet", "UpdateWeldDataSetRsp", payload)


def remove_weld_data_set(web_hmi: AdaptioWebHmi, wds_id: int) -> dict:
    """Remove a weld data set.  Returns the full response dict."""
    return send_and_receive(web_hmi, "RemoveWeldDataSet", "RemoveWeldDataSetRsp", {"id": wds_id})


def select_weld_data_set(web_hmi: AdaptioWebHmi, wds_id: int | None = None, weld_data_set_id: int | None = None) -> dict:
    """Select a weld data set.  Returns the full response dict.

    Accepts either ``wds_id`` (legacy) or ``weld_data_set_id`` (new style).
    At least one must be provided.
    """
    effective_id = weld_data_set_id if weld_data_set_id is not None else wds_id
    if effective_id is None:
        raise ValueError("Either wds_id or weld_data_set_id must be provided")
    return send_and_receive(web_hmi, "SelectWeldDataSet", "SelectWeldDataSetRsp", {"id": effective_id})


def get_weld_programs(web_hmi: AdaptioWebHmi) -> list[dict]:
    """Return the list of stored weld programs."""
    rsp = send_and_receive(web_hmi, "GetWeldPrograms", "GetWeldProgramsRsp")
    return rsp.get("payload", [])


def remove_weld_program(web_hmi: AdaptioWebHmi, prog_id: int) -> dict:
    """Remove a weld program.  Returns the full response dict."""
    return send_and_receive(web_hmi, "RemoveWeldProgram", "RemoveWeldProgramRsp", {"id": prog_id})


# ---------------------------------------------------------------------------
# Arc state helpers
# ---------------------------------------------------------------------------

def subscribe_arc_state(web_hmi: AdaptioWebHmi) -> str | None:
    """Subscribe to arc-state push notifications and return the initial state.

    ``SubscribeArcState`` causes the device to push the current state
    immediately (as an ``ArcState`` message) followed by subsequent
    unsolicited pushes on every transition.

    Returns the state string (e.g. ``"idle"``) or ``None`` if the
    device does not respond.
    """
    try:
        send_message(web_hmi, "SubscribeArcState")
        msg = receive_by_name(web_hmi, "ArcState")
        return msg.get("payload", {}).get("state")
    except Exception:
        logger.debug("subscribe_arc_state: failed to receive initial ArcState")
        return None


def receive_arc_state(web_hmi: AdaptioWebHmi, max_retries: int = 10) -> str | None:
    """Wait for the next ``ArcState`` push message and return the state string.

    Returns ``None`` if no message is received within *max_retries* attempts.
    """
    try:
        msg = receive_by_name(web_hmi, "ArcState", max_retries=max_retries)
        return msg.get("payload", {}).get("state")
    except Exception:
        logger.debug("receive_arc_state: failed to receive ArcState push")
        return None


# ---------------------------------------------------------------------------
# PLC weld address constants
# ---------------------------------------------------------------------------

PLC_ADDR_START = '"Adaptio.DB_AdaptioCommunication".DataToAdaptio.Adaptio.Start'
PLC_ADDR_STOP = '"Adaptio.DB_AdaptioCommunication".DataToAdaptio.Adaptio.Stop'
PLC_ADDR_PS1_READY_TO_START = '"Adaptio.DB_AdaptioCommunication".DataToAdaptio.PowerSource1.ReadyToWeld'
PLC_ADDR_PS2_READY_TO_START = '"Adaptio.DB_AdaptioCommunication".DataToAdaptio.PowerSource2.ReadyToWeld'
PLC_ADDR_PS1_ARCING = '"Adaptio.DB_AdaptioCommunication".DataToAdaptio.PowerSource1.Arcing'
PLC_ADDR_PS2_ARCING = '"Adaptio.DB_AdaptioCommunication".DataToAdaptio.PowerSource2.Arcing'

# DataFromAdaptio – setpoint values (Adaptio → PLC → power source)
PLC_ADDR_PS1_VOLTAGE_SETPOINT = (
    '"Adaptio.DB_AdaptioCommunication".DataFromAdaptio.PowerSource1.Voltage'
)
PLC_ADDR_PS1_CURRENT_SETPOINT = (
    '"Adaptio.DB_AdaptioCommunication".DataFromAdaptio.PowerSource1.Current'
)
PLC_ADDR_PS2_VOLTAGE_SETPOINT = (
    '"Adaptio.DB_AdaptioCommunication".DataFromAdaptio.PowerSource2.Voltage'
)
PLC_ADDR_PS2_CURRENT_SETPOINT = (
    '"Adaptio.DB_AdaptioCommunication".DataFromAdaptio.PowerSource2.Current'
)

# DataToAdaptio – actual (feedback) values reported by the power source
PLC_ADDR_PS1_VOLTAGE_ACTUAL = (
    '"Adaptio.DB_AdaptioCommunication".DataToAdaptio.PowerSource1.Voltage'
)
PLC_ADDR_PS1_CURRENT_ACTUAL = (
    '"Adaptio.DB_AdaptioCommunication".DataToAdaptio.PowerSource1.Current'
)
PLC_ADDR_PS2_VOLTAGE_ACTUAL = (
    '"Adaptio.DB_AdaptioCommunication".DataToAdaptio.PowerSource2.Voltage'
)
PLC_ADDR_PS2_CURRENT_ACTUAL = (
    '"Adaptio.DB_AdaptioCommunication".DataToAdaptio.PowerSource2.Current'
)

# DataToAdaptio – additional status flags
PLC_ADDR_PS1_IN_WELDING_SEQ = (
    '"Adaptio.DB_AdaptioCommunication".DataToAdaptio.PowerSource1.InWeldingSequence'
)
PLC_ADDR_PS1_ERROR = (
    '"Adaptio.DB_AdaptioCommunication".DataToAdaptio.PowerSource1.Error'
)
PLC_ADDR_PS1_START_FAILURE = (
    '"Adaptio.DB_AdaptioCommunication".DataToAdaptio.PowerSource1.StartFailure'
)
PLC_ADDR_PS2_IN_WELDING_SEQ = (
    '"Adaptio.DB_AdaptioCommunication".DataToAdaptio.PowerSource2.InWeldingSequence'
)
PLC_ADDR_PS2_ERROR = (
    '"Adaptio.DB_AdaptioCommunication".DataToAdaptio.PowerSource2.Error'
)
PLC_ADDR_PS2_START_FAILURE = (
    '"Adaptio.DB_AdaptioCommunication".DataToAdaptio.PowerSource2.StartFailure'
)


def simulate_power_sources_ready(plc: "PlcJsonRpc") -> bool:
    """Set both power source ReadyToWeld flags to True via PLC.

    This simulates the power sources reporting ready, which triggers the
    arc state machine transition CONFIGURED → READY.
    Returns ``True`` if both writes succeed, ``False`` on failure.
    """
    try:
        _, err1 = plc.write(PLC_ADDR_PS1_READY_TO_START, True)
        _, err2 = plc.write(PLC_ADDR_PS2_READY_TO_START, True)
        if err1 or err2:
            logger.warning(f"simulate_power_sources_ready failed: err1={err1}, err2={err2}")
            return False
        return True
    except Exception as exc:
        logger.warning(f"simulate_power_sources_ready failed: {exc}")
        return False


def simulate_weld_start(plc: "PlcJsonRpc") -> bool:
    """Press the start button via PLC.

    This triggers READY → STARTING in the arc state machine.
    Returns ``True`` on success, ``False`` on failure.
    """
    try:
        _, err = plc.write(PLC_ADDR_START, True)
        if err:
            logger.warning(f"simulate_weld_start failed: {err}")
            return False
        return True
    except Exception as exc:
        logger.warning(f"simulate_weld_start failed: {exc}")
        return False


def simulate_arcing(plc: "PlcJsonRpc") -> bool:
    """Set power source 1 to ARCING via PLC.

    This triggers STARTING → ACTIVE in the arc state machine.
    Returns ``True`` on success, ``False`` on failure.
    """
    try:
        _, err = plc.write(PLC_ADDR_PS1_ARCING, True)
        if err:
            logger.warning(f"simulate_arcing failed: {err}")
            return False
        return True
    except Exception as exc:
        logger.warning(f"simulate_arcing failed: {exc}")
        return False


def simulate_weld_stop(plc: "PlcJsonRpc") -> bool:
    """Press the stop button via PLC.

    This sends the stop command to the weld system (from STARTING or ACTIVE).
    Returns ``True`` on success, ``False`` on failure.
    """
    try:
        _, err = plc.write(PLC_ADDR_STOP, True)
        if err:
            logger.warning(f"simulate_weld_stop failed: {err}")
            return False
        return True
    except Exception as exc:
        logger.warning(f"simulate_weld_stop failed: {exc}")
        return False


def simulate_arcing_stopped(plc: "PlcJsonRpc") -> bool:
    """Clear the ARCING flag on power source 1 via PLC.

    When no power source is ARCING the arc state machine transitions
    ACTIVE → READY.
    Returns ``True`` on success, ``False`` on failure.
    """
    try:
        _, err = plc.write(PLC_ADDR_PS1_ARCING, False)
        if err:
            logger.warning(f"simulate_arcing_stopped failed: {err}")
            return False
        return True
    except Exception as exc:
        logger.warning(f"simulate_arcing_stopped failed: {exc}")
        return False


def reset_plc_weld_signals(plc: "PlcJsonRpc") -> None:
    """Reset all PLC weld signals to their default (off) state.

    Called during teardown to leave the PLC in a clean state.
    """
    for addr in (
        PLC_ADDR_START,
        PLC_ADDR_STOP,
        PLC_ADDR_PS1_READY_TO_START,
        PLC_ADDR_PS2_READY_TO_START,
        PLC_ADDR_PS1_ARCING,
        PLC_ADDR_PS2_ARCING,
    ):
        try:
            plc.write(addr, False)
        except Exception as exc:
            logger.debug(f"reset_plc_weld_signals: failed to reset {addr}: {exc}")


# ---------------------------------------------------------------------------
# PLC power-source voltage / current / status helpers
# ---------------------------------------------------------------------------


def set_power_source_voltage(
    plc: "PlcJsonRpc", voltage: float, ps: int = 1
) -> bool:
    """Write a voltage setpoint to a power source via PLC (DataFromAdaptio).

    *ps* selects the power source (1 or 2).
    Returns ``True`` on success, ``False`` on failure.
    """
    addr = PLC_ADDR_PS1_VOLTAGE_SETPOINT if ps == 1 else PLC_ADDR_PS2_VOLTAGE_SETPOINT
    try:
        _, err = plc.write(addr, voltage)
        if err:
            logger.warning(f"set_power_source_voltage(ps={ps}) failed: {err}")
            return False
        return True
    except Exception as exc:
        logger.warning(f"set_power_source_voltage(ps={ps}) failed: {exc}")
        return False


def set_power_source_current(
    plc: "PlcJsonRpc", current: float, ps: int = 1
) -> bool:
    """Write a current setpoint to a power source via PLC (DataFromAdaptio).

    *ps* selects the power source (1 or 2).
    Returns ``True`` on success, ``False`` on failure.
    """
    addr = PLC_ADDR_PS1_CURRENT_SETPOINT if ps == 1 else PLC_ADDR_PS2_CURRENT_SETPOINT
    try:
        _, err = plc.write(addr, current)
        if err:
            logger.warning(f"set_power_source_current(ps={ps}) failed: {err}")
            return False
        return True
    except Exception as exc:
        logger.warning(f"set_power_source_current(ps={ps}) failed: {exc}")
        return False


def read_power_source_status(
    plc: "PlcJsonRpc", ps: int = 1
) -> dict | None:
    """Read the current status of a power source via PLC (DataToAdaptio).

    Returns a dict with keys:
        ready_to_weld, in_welding_sequence, arcing, start_failure, error,
        voltage, current
    or ``None`` if any read fails.
    """
    if ps == 1:
        addrs = {
            "ready_to_weld": PLC_ADDR_PS1_READY_TO_START,
            "in_welding_sequence": PLC_ADDR_PS1_IN_WELDING_SEQ,
            "arcing": PLC_ADDR_PS1_ARCING,
            "start_failure": PLC_ADDR_PS1_START_FAILURE,
            "error": PLC_ADDR_PS1_ERROR,
            "voltage": PLC_ADDR_PS1_VOLTAGE_ACTUAL,
            "current": PLC_ADDR_PS1_CURRENT_ACTUAL,
        }
    else:
        addrs = {
            "ready_to_weld": PLC_ADDR_PS2_READY_TO_START,
            "in_welding_sequence": PLC_ADDR_PS2_IN_WELDING_SEQ,
            "arcing": PLC_ADDR_PS2_ARCING,
            "start_failure": PLC_ADDR_PS2_START_FAILURE,
            "error": PLC_ADDR_PS2_ERROR,
            "voltage": PLC_ADDR_PS2_VOLTAGE_ACTUAL,
            "current": PLC_ADDR_PS2_CURRENT_ACTUAL,
        }

    result: dict = {}
    try:
        for key, addr in addrs.items():
            val, err = plc.read(addr)
            if err:
                logger.warning(
                    f"read_power_source_status(ps={ps}): "
                    f"failed to read {key} ({addr}): {err}"
                )
                return None
            result[key] = val
    except Exception as exc:
        logger.warning(f"read_power_source_status(ps={ps}) failed: {exc}")
        return None

    return result


def enable_bench_psu_output(
    psu,
    voltage: float,
    current: float,
    output: int = 1,
) -> bool:
    """Configure and enable a bench power-supply output.

    Sets *voltage* and *current* on the given *output*, then enables it.
    Returns ``True`` on success, ``False`` on failure.
    """
    try:
        psu.set_voltage(voltage, output)
        psu.set_current(current, output)
        psu.enable_output(output)
        logger.info(
            f"Bench PSU output {output}: {voltage} V / {current} A enabled"
        )
        return True
    except Exception as exc:
        logger.warning(f"enable_bench_psu_output(output={output}) failed: {exc}")
        return False


# ---------------------------------------------------------------------------
# Database deletion helper
# ---------------------------------------------------------------------------

def delete_adaptio_database(
    adaptio_manager: AdaptioManager,
    db_path,
) -> bool:
    """Stop Adaptio, delete the database file, and restart.

    Returns ``True`` on success, ``False`` on failure.  The restart causes
    Adaptio to re-create the database via ``SQLite::OPEN_CREATE`` (see
    ``main.cc``).
    """
    try:
        adaptio_manager.stop_adaptio()
        cmd = f"rm -f {shlex.quote(str(db_path))}"
        _, stderr, exit_code = adaptio_manager.manager.execute_command(
            command=cmd, sudo=True
        )
        if exit_code != 0:
            logger.warning(f"Failed to delete database file {db_path}: {stderr}")
            return False
        logger.info(f"Deleted database file {db_path}")
        adaptio_manager.start_adaptio()
        return True
    except Exception as exc:
        logger.warning(f"delete_adaptio_database failed: {exc}")
        return False


# ---------------------------------------------------------------------------
# WPP configuration presets
# ---------------------------------------------------------------------------

def get_weld_process_parameters_config(weld_system: str) -> dict:
    """Return default weld process parameters for the given weld system.

    Args:
        weld_system: ``"ws1"`` or ``"ws2"``.

    Returns:
        A dict suitable for passing as ``**kwargs`` to
        ``add_weld_process_parameters`` or directly as a payload.
    """
    if weld_system == "ws1":
        return dict(WPP_DEFAULT_WS1)
    elif weld_system == "ws2":
        return dict(WPP_DEFAULT_WS2)
    else:
        raise ValueError(f"Unknown weld system: {weld_system!r}  (expected 'ws1' or 'ws2')")


# ---------------------------------------------------------------------------
# Clean-up helpers
# ---------------------------------------------------------------------------

def clean_weld_data(web_hmi: AdaptioWebHmi) -> None:
    """Remove **all** weld programs, weld data sets, and weld process parameters.

    Removal order matters:
      WeldPrograms → WeldDataSets → WeldProcessParameters
    The adaptio module prevents removal of a WDS used by a program and of a
    WPP used by a WDS.
    """
    # 1. Remove weld programs
    for prog in get_weld_programs(web_hmi):
        prog_id = prog.get("id")
        if prog_id is not None:
            rsp = remove_weld_program(web_hmi, prog_id)
            logger.debug(f"Removed WeldProgram id={prog_id}: {rsp.get('result')}")

    # 2. Remove weld data sets
    for wds in get_weld_data_sets(web_hmi):
        wds_id = wds.get("id")
        if wds_id is not None:
            rsp = remove_weld_data_set(web_hmi, wds_id)
            logger.debug(f"Removed WDS id={wds_id}: {rsp.get('result')}")

    # 3. Remove weld process parameters
    for wpp in get_weld_process_parameters(web_hmi):
        wpp_id = wpp.get("id")
        if wpp_id is not None:
            rsp = remove_weld_process_parameters(web_hmi, wpp_id)
            logger.debug(f"Removed WPP id={wpp_id}: {rsp.get('result')}")


def ensure_weld_process_parameters(web_hmi: AdaptioWebHmi, params: dict) -> int:
    """Ensure a WPP with the given *name* exists.  Returns its id.

    If a WPP with the same name already exists it is updated; otherwise a
    new one is added.  Using upsert avoids SQLite auto-increment ID growth
    across repeated test runs on a persistent device database.
    """
    existing = get_weld_process_parameters(web_hmi)
    for wpp in existing:
        if wpp.get("name") == params.get("name"):
            wpp_id = wpp["id"]
            update_weld_process_parameters(web_hmi, wpp_id, params)
            return wpp_id

    add_weld_process_parameters(web_hmi, params)
    updated = get_weld_process_parameters(web_hmi)
    for wpp in updated:
        if wpp.get("name") == params.get("name"):
            return wpp["id"]
    raise RuntimeError(f"Failed to ensure WPP with name={params.get('name')}")


def ensure_weld_data_set(
    web_hmi: AdaptioWebHmi, name: str, ws1_wpp_id: int, ws2_wpp_id: int
) -> int:
    """Ensure a WDS with the given *name* exists.  Returns its id."""
    existing = get_weld_data_sets(web_hmi)
    for wds in existing:
        if wds.get("name") == name:
            wds_id = wds["id"]
            update_weld_data_set(web_hmi, wds_id, name, ws1_wpp_id, ws2_wpp_id)
            return wds_id

    add_weld_data_set(web_hmi, name, ws1_wpp_id, ws2_wpp_id)
    updated = get_weld_data_sets(web_hmi)
    for wds in updated:
        if wds.get("name") == name:
            return wds["id"]
    raise RuntimeError(f"Failed to ensure WDS with name={name}")


# ---------------------------------------------------------------------------
# Weld fixtures
# ---------------------------------------------------------------------------

@pytest.fixture(name="web_hmi")
def web_hmi_fixture(request: pytest.FixtureRequest):
    """Provide an AdaptioWebHmi client connected to the device."""
    uri = request.config.WEB_HMI_URI
    client = AdaptioWebHmi(uri=uri)
    try:
        client.connect()
    except Exception:
        pytest.skip("Could not connect to Adaptio WebHMI")

    yield client

    cleanup_web_hmi_client(client)


@pytest.fixture(name="clean_weld_state")
def clean_weld_state_fixture(request: pytest.FixtureRequest, web_hmi: AdaptioWebHmi):
    """Remove all weld data before and after the test.

    If the initial cleanup fails (e.g. the database file does not exist),
    the fixture checks database availability via ``ensure_db_available``
    and restarts Adaptio to create the database if necessary – following
    the same pattern as ``update_adaptio_config`` in
    ``test_joint_tracking.py``.
    """
    try:
        clean_weld_data(web_hmi)
    except Exception:
        logger.info("clean_weld_data failed, checking database availability")
        try:
            adaptio_manager: AdaptioManager = request.getfixturevalue("adaptio_manager")
            if ensure_db_available(request, adaptio_manager):
                # Adaptio was restarted – reconnect and retry
                web_hmi.connect()
            clean_weld_data(web_hmi)
        except Exception:
            pytest.skip("Could not clean weld data or ensure database")

    yield

    try:
        clean_weld_data(web_hmi)
    except Exception:
        logger.warning("Post-test weld data cleanup failed")


@pytest.fixture(name="seeded_weld_data")
def seeded_weld_data_fixture(web_hmi: AdaptioWebHmi, clean_weld_state):
    """Ensure two WPPs and one WDS exist.

    Returns:
        tuple[int, int, int]: (ws1_id, ws2_id, wds_id)
    """
    try:
        ws1_id = ensure_weld_process_parameters(web_hmi, WPP_DEFAULT_WS1)
        ws2_id = ensure_weld_process_parameters(web_hmi, WPP_DEFAULT_WS2)
        wds_id = ensure_weld_data_set(web_hmi, "TestWeld", ws1_id, ws2_id)
    except Exception:
        pytest.skip("Could not seed weld data")

    return ws1_id, ws2_id, wds_id


# ---------------------------------------------------------------------------
# Database availability helpers
# ---------------------------------------------------------------------------

def ensure_db_available(
    request: pytest.FixtureRequest,
    adaptio_manager: AdaptioManager,
) -> bool:
    """Check if the Adaptio database file exists and create it if not.

    If the database file is not available, restarts Adaptio so it re-creates
    the database via ``SQLite::OPEN_CREATE`` (see ``main.cc``).

    Returns ``True`` if a restart was performed, ``False`` if the database
    already existed.

    Reference: ``test_joint_tracking.py`` → ``update_adaptio_config`` fixture.
    """
    db_path = request.config.ADAPTIO_USER_CONFIG_PATH / request.config.ADAPTIO_DB
    cmd = f"test -f {shlex.quote(str(db_path))}"
    _, _, exit_code = adaptio_manager.manager.execute_command(
        command=cmd, sudo=True
    )
    if exit_code != 0:
        logger.info(f"Database file {db_path} not found, restarting Adaptio to create it")
        adaptio_manager.restart_adaptio()
        return True
    return False


# ---------------------------------------------------------------------------
# Database recreation helpers and fixtures
# ---------------------------------------------------------------------------

def delete_adaptio_db(adaptio_manager: AdaptioManager) -> None:
    """Delete the Adaptio database file on the remote device.

    Uses the same approach as ``AdaptioManager._cleanup_user_config`` but
    targets only the database file.  Adaptio must be stopped before calling
    this function; after a restart it will re-create the database via
    ``SQLite::OPEN_CREATE`` (see ``main.cc``).
    """
    db_file = (
        adaptio_manager.request.config.ADAPTIO_USER_CONFIG_PATH
        / adaptio_manager.request.config.ADAPTIO_DB
    )
    cmd = f"rm -f {shlex.quote(str(db_file))}"
    _, stderr, exit_code = adaptio_manager.manager.execute_command(
        command=cmd, sudo=True
    )
    if exit_code != 0:
        logger.warning(f"Failed to delete database file {db_file}: {stderr}")
    else:
        logger.info(f"Deleted database file {db_file}")


@pytest.fixture(name="ensure_fresh_db")
def ensure_fresh_db_fixture(
    request: pytest.FixtureRequest,
    adaptio_manager: AdaptioManager,
) -> Iterator[AdaptioWebHmi]:
    """Delete the Adaptio database and restart the service so it is recreated.

    Yields a freshly-connected ``AdaptioWebHmi`` client.  On teardown the
    database is deleted once more and Adaptio is restarted to leave the
    device in a clean state (same pattern as ``update_adaptio_config``).

    Reference: ``test_joint_tracking.py`` → ``update_adaptio_config`` fixture.
    """
    try:
        adaptio_manager.stop_adaptio()
        delete_adaptio_db(adaptio_manager)
        adaptio_manager.start_adaptio()
    except Exception:
        pytest.skip("Could not recreate Adaptio database")

    uri = request.config.WEB_HMI_URI
    client = AdaptioWebHmi(uri=uri)
    try:
        client.connect()
    except Exception:
        pytest.skip("Could not connect to Adaptio WebHMI after DB recreation")

    yield client

    cleanup_web_hmi_client(client)

    # Restore: delete DB and restart so the device is clean for the next test
    try:
        adaptio_manager.stop_adaptio()
        delete_adaptio_db(adaptio_manager)
        adaptio_manager.start_adaptio()
    except Exception:
        logger.warning("Post-test database cleanup failed")


