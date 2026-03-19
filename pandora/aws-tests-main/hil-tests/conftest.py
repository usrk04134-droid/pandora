"""Configuration file for all hil/demorig tests."""

import os
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
from testzilla.adaptio_web_hmi.adaptio_web_hmi import AdaptioWebHmi, create_name_condition
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
        "markers", "weld: mark test as weld operation test (WPP, WDS, arc state)"
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
        #"vertical_position":'"DB_UserInteraction.HMI".MotionControl.Axis.VerticalSlide.Status.Position'
 
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
    except Exception:
        logger.exception("Failed to set Adaptio joint geometry")
        return False


def get_weld_process_parameters_config(weld_system: str = "ws1") -> dict:
    """
    Parse weld process parameters configuration from YAML file.

    Args:
        weld_system: Weld system identifier ("ws1" or "ws2")

    Returns:
        dict: Weld process parameters with keys expected by add_weld_process_parameters()

    Raises:
        ValueError: If weld process parameters configuration not found in YAML file
    """
    with open(yaml_file_path, "r") as file:
        data = yaml.safe_load(file)

    yaml_key = f"weld_process_parameters_{weld_system}"

    if yaml_key not in data:
        raise ValueError(f"Weld process parameters for '{weld_system}' not found in {yaml_file_path}")

    config = data[yaml_key]
    return {
        "name": config["name"],
        "method": config["method"],
        "regulationType": config["regulationType"],
        "startAdjust": config["startAdjust"],
        "startType": config["startType"],
        "voltage": float(config["voltage"]),
        "current": float(config["current"]),
        "wireSpeed": float(config["wireSpeed"]),
        "iceWireSpeed": float(config["iceWireSpeed"]),
        "acFrequency": float(config["acFrequency"]),
        "acOffset": float(config["acOffset"]),
        "acPhaseShift": float(config["acPhaseShift"]),
        "craterFillTime": float(config["craterFillTime"]),
        "burnBackTime": float(config["burnBackTime"]),
    }


def add_weld_process_parameters(web_hmi: AdaptioWebHmi, **kwargs) -> bool:
    """Add weld process parameters via WebHMI.

    Args:
        web_hmi: AdaptioWebHmi instance for communication
        **kwargs: Weld process parameter fields (name, method, regulationType, etc.)

    Returns:
        True if successful, False otherwise
    """
    try:
        response = web_hmi.add_weld_process_parameters(**kwargs)
        logger.debug(f"Received response: {response}")
        result = getattr(response, "result", None) or response.payload.get("result")
        if response and result == "ok":
            logger.info(f"Successfully added weld process parameters: {kwargs.get('name', '')}")
            return True
        else:
            logger.warning(f"Failed to add weld process parameters: {kwargs.get('name', '')}")
            return False
    except Exception:
        logger.exception("Failed to add weld process parameters")
        return False


def add_weld_data_set(web_hmi: AdaptioWebHmi, name: str, ws1_wpp_id: int, ws2_wpp_id: int) -> bool:
    """Add a weld data set via WebHMI.

    Args:
        web_hmi: AdaptioWebHmi instance for communication
        name: Name of the weld data set
        ws1_wpp_id: Weld system 1 weld process parameter ID
        ws2_wpp_id: Weld system 2 weld process parameter ID

    Returns:
        True if successful, False otherwise
    """
    try:
        response = web_hmi.add_weld_data_set(name=name, ws1WppId=ws1_wpp_id, ws2WppId=ws2_wpp_id)
        logger.debug(f"Received response: {response}")
        result = getattr(response, "result", None) or response.payload.get("result")
        if response and result == "ok":
            logger.info(f"Successfully added weld data set: {name}")
            return True
        else:
            logger.warning(f"Failed to add weld data set: {name}")
            return False
    except Exception:
        logger.exception("Failed to add weld data set")
        return False


def update_weld_process_parameters(web_hmi: AdaptioWebHmi, wpp_id: int, **kwargs) -> bool:
    """Update existing weld process parameters via WebHMI.

    Args:
        web_hmi: AdaptioWebHmi instance for communication
        wpp_id: ID of the weld process parameters to update
        **kwargs: Weld process parameter fields (name, method, regulationType, etc.)

    Returns:
        True if successful, False otherwise
    """
    try:
        payload = {"id": wpp_id, **kwargs}
        response = web_hmi.send_and_receive_message(
            condition=None,
            request_name="UpdateWeldProcessParameters",
            response_name="UpdateWeldProcessParametersRsp",
            payload=payload,
        )
        logger.debug(f"Received UpdateWeldProcessParameters response: {response}")
        result = getattr(response, "result", None) or response.payload.get("result")
        if response and result == "ok":
            logger.info(f"Successfully updated weld process parameters: {kwargs.get('name', '')} (id={wpp_id})")
            return True
        else:
            logger.warning(f"Failed to update weld process parameters: {kwargs.get('name', '')} (id={wpp_id})")
            return False
    except Exception:
        logger.exception("Failed to update weld process parameters")
        return False


def update_weld_data_set(
    web_hmi: AdaptioWebHmi, wds_id: int, name: str, ws1_wpp_id: int, ws2_wpp_id: int
) -> bool:
    """Update an existing weld data set via WebHMI.

    Args:
        web_hmi: AdaptioWebHmi instance for communication
        wds_id: ID of the weld data set to update
        name: Name of the weld data set
        ws1_wpp_id: Weld system 1 weld process parameter ID
        ws2_wpp_id: Weld system 2 weld process parameter ID

    Returns:
        True if successful, False otherwise
    """
    try:
        payload = {"id": wds_id, "name": name, "ws1WppId": ws1_wpp_id, "ws2WppId": ws2_wpp_id}
        response = web_hmi.send_and_receive_message(
            condition=None,
            request_name="UpdateWeldDataSet",
            response_name="UpdateWeldDataSetRsp",
            payload=payload,
        )
        logger.debug(f"Received UpdateWeldDataSet response: {response}")
        result = getattr(response, "result", None) or response.payload.get("result")
        if response and result == "ok":
            logger.info(f"Successfully updated weld data set: {name} (id={wds_id})")
            return True
        else:
            logger.warning(f"Failed to update weld data set: {name} (id={wds_id})")
            return False
    except Exception:
        logger.exception("Failed to update weld data set")
        return False


_FLOAT_COMPARISON_TOLERANCE = 1e-6


def _wpp_config_matches(existing_wpp: dict, desired_config: dict) -> bool:
    """Check if existing WPP matches the desired configuration (ignoring ID).

    Compares all fields in desired_config against the existing WPP dict.
    Float values are compared with tolerance to handle floating point differences.

    Args:
        existing_wpp: Existing WPP dict from GetWeldProcessParameters
        desired_config: Desired WPP configuration dict

    Returns:
        True if all fields match, False otherwise
    """
    for key, value in desired_config.items():
        existing_value = existing_wpp.get(key)
        if isinstance(value, float) and isinstance(existing_value, (int, float)):
            if abs(float(existing_value) - value) > _FLOAT_COMPARISON_TOLERANCE:
                return False
        elif existing_value != value:
            return False
    return True


def ensure_weld_process_parameters(web_hmi: AdaptioWebHmi, **config) -> int | None:
    """Ensure weld process parameters exist with the given configuration.

    Uses an upsert pattern to avoid unnecessary deletion and re-creation:
      - If WPP with the given name already exists and config matches, reuse it
      - If WPP exists but config differs, update it
      - If WPP doesn't exist, add it

    This prevents SQLite auto-increment IDs from growing across test runs.

    Args:
        web_hmi: AdaptioWebHmi instance for communication
        **config: Weld process parameter fields (name, method, regulationType, etc.)

    Returns:
        WPP database ID if successful, None otherwise
    """
    name = config.get("name", "")
    wpp_list = get_weld_process_parameters(web_hmi)

    if wpp_list:
        for wpp in wpp_list:
            if isinstance(wpp, dict) and wpp.get("name") == name:
                wpp_id = wpp.get("id")
                if _wpp_config_matches(wpp, config):
                    logger.info(f"WPP '{name}' already exists with matching config (id={wpp_id})")
                    return wpp_id
                if update_weld_process_parameters(web_hmi, wpp_id, **config):
                    logger.info(f"Updated WPP '{name}' (id={wpp_id})")
                    return wpp_id
                logger.warning(f"Failed to update WPP '{name}' (id={wpp_id})")
                return None

    # Not found, add new
    if add_weld_process_parameters(web_hmi, **config):
        updated_list = get_weld_process_parameters(web_hmi)
        if updated_list:
            for wpp in updated_list:
                if isinstance(wpp, dict) and wpp.get("name") == name:
                    return wpp.get("id")
    return None


def ensure_weld_data_set(
    web_hmi: AdaptioWebHmi, name: str, ws1_wpp_id: int, ws2_wpp_id: int
) -> int | None:
    """Ensure a weld data set exists with the given configuration.

    Uses an upsert pattern to avoid unnecessary deletion and re-creation:
      - If WDS with the given name already exists and WPP IDs match, reuse it
      - If WDS exists but WPP IDs differ, update it
      - If WDS doesn't exist, add it

    This prevents SQLite auto-increment IDs from growing across test runs.

    Args:
        web_hmi: AdaptioWebHmi instance for communication
        name: Name of the weld data set
        ws1_wpp_id: Weld system 1 weld process parameter ID
        ws2_wpp_id: Weld system 2 weld process parameter ID

    Returns:
        WDS database ID if successful, None otherwise
    """
    wds_list = get_weld_data_sets(web_hmi)

    if wds_list:
        for wds in wds_list:
            if isinstance(wds, dict) and wds.get("name") == name:
                wds_id = wds.get("id")
                if wds.get("ws1WppId") == ws1_wpp_id and wds.get("ws2WppId") == ws2_wpp_id:
                    logger.info(f"WDS '{name}' already exists with matching config (id={wds_id})")
                    return wds_id
                if update_weld_data_set(web_hmi, wds_id, name, ws1_wpp_id, ws2_wpp_id):
                    logger.info(f"Updated WDS '{name}' (id={wds_id})")
                    return wds_id
                logger.warning(f"Failed to update WDS '{name}' (id={wds_id})")
                return None

    # Not found, add new
    if add_weld_data_set(web_hmi, name=name, ws1_wpp_id=ws1_wpp_id, ws2_wpp_id=ws2_wpp_id):
        updated_list = get_weld_data_sets(web_hmi)
        if updated_list:
            for wds in updated_list:
                if isinstance(wds, dict) and wds.get("name") == name:
                    return wds.get("id")
    return None


def select_weld_data_set(web_hmi: AdaptioWebHmi, weld_data_set_id: int) -> bool:
    """Select a weld data set via WebHMI.

    Args:
        web_hmi: AdaptioWebHmi instance for communication
        weld_data_set_id: ID of the weld data set to select

    Returns:
        True if successful, False otherwise
    """
    try:
        response = web_hmi.select_weld_data_set(id=weld_data_set_id)
        logger.debug(f"Received response: {response}")
        result = getattr(response, "result", None) or response.payload.get("result")
        if response and result == "ok":
            logger.info(f"Successfully selected weld data set: {weld_data_set_id}")
            return True
        else:
            logger.warning(f"Failed to select weld data set: {weld_data_set_id}")
            return False
    except Exception:
        logger.exception("Failed to select weld data set")
        return False


def get_weld_data_sets(web_hmi: AdaptioWebHmi) -> list | None:
    """Get all weld data sets via WebHMI.

    Args:
        web_hmi: AdaptioWebHmi instance for communication

    Returns:
        List of weld data sets if successful, None otherwise
    """
    try:
        response = web_hmi.send_and_receive_message(
            condition=None,
            request_name="GetWeldDataSets",
            response_name="GetWeldDataSetsRsp",
            payload={},
        )
        logger.debug(f"Received response: {response}")
        if response and isinstance(response.payload, list):
            return response.payload
        return None
    except Exception:
        logger.exception("Failed to get weld data sets")
        return None


def get_weld_process_parameters(web_hmi: AdaptioWebHmi) -> list | None:
    """Get all weld process parameters via WebHMI.

    Args:
        web_hmi: AdaptioWebHmi instance for communication

    Returns:
        List of weld process parameter dicts if successful, None otherwise
    """
    try:
        response = web_hmi.send_and_receive_message(
            condition=None,
            request_name="GetWeldProcessParameters",
            response_name="GetWeldProcessParametersRsp",
            payload={},
        )
        logger.debug(f"Received GetWeldProcessParameters response: {response}")
        if response and isinstance(response.payload, list):
            return response.payload
        return None
    except Exception:
        logger.exception("Failed to get weld process parameters")
        return None


def remove_weld_data_set(web_hmi: AdaptioWebHmi, wds_id: int) -> bool:
    """Remove a weld data set via WebHMI.

    Args:
        web_hmi: AdaptioWebHmi instance for communication
        wds_id: ID of the weld data set to remove

    Returns:
        True if successful, False otherwise
    """
    try:
        response = web_hmi.send_and_receive_message(
            condition=None,
            request_name="RemoveWeldDataSet",
            response_name="RemoveWeldDataSetRsp",
            payload={"id": wds_id},
        )
        logger.debug(f"Received RemoveWeldDataSet response: {response}")
        result = getattr(response, "result", None) or response.payload.get("result")
        if response and result == "ok":
            logger.info(f"Successfully removed weld data set: {wds_id}")
            return True
        else:
            logger.warning(f"Failed to remove weld data set: {wds_id}")
            return False
    except Exception:
        logger.exception(f"Failed to remove weld data set: {wds_id}")
        return False


def remove_weld_process_parameters(web_hmi: AdaptioWebHmi, wpp_id: int) -> bool:
    """Remove weld process parameters via WebHMI.

    Args:
        web_hmi: AdaptioWebHmi instance for communication
        wpp_id: ID of the weld process parameters to remove

    Returns:
        True if successful, False otherwise
    """
    try:
        response = web_hmi.send_and_receive_message(
            condition=None,
            request_name="RemoveWeldProcessParameters",
            response_name="RemoveWeldProcessParametersRsp",
            payload={"id": wpp_id},
        )
        logger.debug(f"Received RemoveWeldProcessParameters response: {response}")
        result = getattr(response, "result", None) or response.payload.get("result")
        if response and result == "ok":
            logger.info(f"Successfully removed weld process parameters: {wpp_id}")
            return True
        else:
            logger.warning(f"Failed to remove weld process parameters: {wpp_id}")
            return False
    except Exception:
        logger.exception(f"Failed to remove weld process parameters: {wpp_id}")
        return False


def get_weld_programs(web_hmi: AdaptioWebHmi) -> list | None:
    """Get all weld programs via WebHMI.

    Args:
        web_hmi: AdaptioWebHmi instance for communication

    Returns:
        List of weld program dicts if successful, None otherwise
    """
    try:
        response = web_hmi.send_and_receive_message(
            condition=None,
            request_name="GetWeldPrograms",
            response_name="GetWeldProgramsRsp",
            payload={},
        )
        logger.debug(f"Received GetWeldPrograms response: {response}")
        if response and isinstance(response.payload, list):
            return response.payload
        return None
    except Exception:
        logger.exception("Failed to get weld programs")
        return None


def remove_weld_program(web_hmi: AdaptioWebHmi, program_id: int) -> bool:
    """Remove a weld program via WebHMI.

    Args:
        web_hmi: AdaptioWebHmi instance for communication
        program_id: ID of the weld program to remove

    Returns:
        True if successful, False otherwise
    """
    try:
        response = web_hmi.send_and_receive_message(
            condition=None,
            request_name="RemoveWeldProgram",
            response_name="RemoveWeldProgramRsp",
            payload={"id": program_id},
        )
        logger.debug(f"Received RemoveWeldProgram response: {response}")
        result = getattr(response, "result", None) or response.payload.get("result")
        if response and result == "ok":
            logger.info(f"Successfully removed weld program: {program_id}")
            return True
        else:
            logger.warning(f"Failed to remove weld program: {program_id}")
            return False
    except Exception:
        logger.exception(f"Failed to remove weld program: {program_id}")
        return False


def clean_weld_data(web_hmi: AdaptioWebHmi) -> None:
    """Remove all existing weld programs, weld data sets, and weld process parameters.

    Removal order matters due to referential constraints in the adaptio module:
      1. Weld programs (reference WDS)
      2. Weld data sets (reference WPP)
      3. Weld process parameters

    Args:
        web_hmi: AdaptioWebHmi instance for communication
    """
    # Remove all weld programs first (they reference WDS)
    weld_programs = get_weld_programs(web_hmi)
    if weld_programs:
        for prog in weld_programs:
            prog_id = prog.get("id") if isinstance(prog, dict) else None
            if prog_id is not None:
                remove_weld_program(web_hmi, prog_id)

    # Then remove all weld data sets (they reference WPP)
    weld_data_sets = get_weld_data_sets(web_hmi)
    if weld_data_sets:
        for wds in weld_data_sets:
            wds_id = wds.get("id") if isinstance(wds, dict) else None
            if wds_id is not None:
                remove_weld_data_set(web_hmi, wds_id)

    # Finally remove all weld process parameters
    weld_process_params = get_weld_process_parameters(web_hmi)
    if weld_process_params:
        for wpp in weld_process_params:
            wpp_id = wpp.get("id") if isinstance(wpp, dict) else None
            if wpp_id is not None:
                remove_weld_process_parameters(web_hmi, wpp_id)


def subscribe_arc_state(web_hmi: AdaptioWebHmi) -> str | None:
    """Subscribe to arc state updates and receive the initial state.

    Args:
        web_hmi: AdaptioWebHmi instance for communication

    Returns:
        Initial arc state string if successful, None otherwise
    """
    try:
        response = web_hmi.send_and_receive_message(
            condition=None,
            request_name="SubscribeArcState",
            response_name="ArcState",
            payload={},
        )
        logger.debug(f"Received ArcState response: {response}")
        if response:
            return response.payload.get("state")
        return None
    except Exception:
        logger.exception("Failed to subscribe to arc state")
        return None


def receive_arc_state(web_hmi: AdaptioWebHmi) -> str | None:
    """Receive the next arc state update.

    Args:
        web_hmi: AdaptioWebHmi instance for communication

    Returns:
        Arc state string if received, None otherwise
    """
    try:
        condition = create_name_condition(name="ArcState")
        # Use higher max_retries than default (5) to allow for other WebSocket
        # messages (e.g. status pushes) that may arrive before the expected ArcState.
        response = web_hmi.receive_message(condition=condition, max_retries=10)
        logger.debug(f"Received ArcState: {response}")
        if response:
            return response.payload.get("state")
        return None
    except Exception:
        logger.exception("Timed out waiting for arc state update")
        return None


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
    

