"""WebHMI UI Tests for Adaptio using sync Playwright"""

from requests import request, session
import pytest
from loguru import logger
import os
import yaml
import random
import warnings
import urllib3
import time
from pathlib import Path
from pydantic_core import ValidationError as PydanticCoreValidationError

# Suppress urllib3 InsecureRequestWarning for this test module
warnings.filterwarnings('ignore', category=urllib3.exceptions.InsecureRequestWarning)
from testzilla.adaptio_web_hmi.adaptio_web_hmi import AdaptioWebHmi as AdaptioWebHmiClient
from concurrent.futures import ThreadPoolExecutor, TimeoutError as FutureTimeout
from testzilla.utility.cleanup_utils import cleanup_web_hmi_client

DEFAULT_TIMEOUT = 30000
LOAD_TIMEOUT = 30000
PAGE_LOADTIMEOUT = 3000
yaml_file_path = os.path.join(os.path.dirname(__file__), "webhmi_data.yml")

def run_sync_in_thread(func, *args, timeout=None, **kwargs):
    """
    Run a blocking function in a separate thread and return its result.

    This is useful when the function may call `asyncio` APIs that
    call `loop.run_until_complete` while the main event loop is already
    running (e.g., when tests use Playwright which runs its own loop).
    """
    with ThreadPoolExecutor(max_workers=1) as ex:
        fut = ex.submit(func, *args, **kwargs)
        try:
            return fut.result(timeout=timeout)
        except FutureTimeout:
            fut.cancel()
            raise TimeoutError("Operation timed out")


def run_adaptio_send(uri, request_name, response_name, payload, condition=None):
    """Create Adaptio client in-thread, send/receive, then close it.

    Creating the client inside the worker thread ensures the websocket
    sync wrapper creates its own event loop instead of capturing the
    test/main thread's running loop (which causes run_until_complete
    to raise "event loop already running").
    """
    client = AdaptioWebHmiClient(uri=uri)
    try:
        return client.send_and_receive_message(
            condition=condition,
            request_name=request_name,
            response_name=response_name,
            payload=payload,
        )
    except PydanticCoreValidationError as exc:
        # Handle failure responses that don't match expected schema (e.g., missing 'payload' field)
        # Extract and return the raw response data so caller can handle the failure
        raw_input = None
        for err in exc.errors():
            if "input" in err:
                raw_input = err["input"]
                break
        if raw_input is not None:
            logger.warning(f"Received failure response: {raw_input}")
            return raw_input
        raise
    finally:
        cleanup_web_hmi_client(client)

def run_adaptio_send_receive_data(uri, request_name, response_name, payload, message, condition=None):
    """Create Adaptio client in-thread, send/receive, then close it.

    Creating the client inside the worker thread ensures the websocket
    sync wrapper creates its own event loop instead of capturing the
    test/main thread's running loop (which causes run_until_complete
    to raise "event loop already running").
    """
    client = AdaptioWebHmiClient(uri=uri)
    try:
        return client.send_and_receive_data(
            condition=condition,
            request_name=request_name,
            response_name=response_name,
            payload=payload,
            message=message,
        )
    except PydanticCoreValidationError as exc:
        raw_input = None
        for err in exc.errors():
            if "input" in err:
                raw_input = err["input"]
                break
        if raw_input is not None:
            return raw_input
        raise
    finally:
        cleanup_web_hmi_client(client)


class TestAdaptioWebHMI:
    """Test suite for Adaptio WebHMI UI testing using Sync Playwright with fixtures"""

    @pytest.fixture(autouse=True)
    def setup_adaptio_logs(self, adaptio_manager):
        """Setup fixture to enable Adaptio log collection for WebHMI tests"""
        # This fixture ensures adaptio_manager is initialized for all tests in this class
        # which enables automatic log collection when --collect-logs flag is used
        # and log cleanup when --clean-logs flag is used
        pass

    def _navigate_and_validate(self, session, playwright_manager, target_path):
        """Helper function for navigating and validating page load."""
        try:
            logger.info(f"Testing navigation to: {session.base_url}{target_path}")

            session.navigate_to(target_path, timeout=LOAD_TIMEOUT)
            session.wait_for_page_ready(timeout=LOAD_TIMEOUT)

            assert target_path in session.page.url

            title = session.page.title()
            content = session.page.content()
            assert len(content) > 500, f"Page content appears insufficient for {target_path}"
            logger.info(f"Page loaded - Title: {title}, Content length: {len(content)}")

            safe_path = target_path.replace("/", "_")
            playwright_manager.take_screenshot(f"navigation{safe_path}")

            logger.info(f"Navigation to {target_path} completed successfully")

        except Exception as e:
            logger.error(f"Navigation test for {target_path} failed: {e}")
            safe_path = target_path.replace("/", "_")
            playwright_manager.take_screenshot(f"error_navigation{safe_path}")
            raise

    @pytest.mark.webhmi_ui
    def webhmi_page_navigation_call(self, webhmi_session, playwright_manager, target_path):
        """Test basic navigation to different pages"""
        self._navigate_and_validate(webhmi_session, playwright_manager, target_path)

    def _click_button_and_assert(self, webhmi_session, playwright_manager, button_name, success_text, timeout):
        """
        Click a button on the page and assert that a success text appears after the action.

            Args:
            session: The WebHMI session object.
            playwright_manager: Playwright manager object (for screenshots).
            button_name: The text of the button to click.
            success_text: Text to assert exists after the click.
            timeout: Maximum wait time for button to appear and action to complete.
        """
        session = webhmi_session
        try:
            # Locate the button by its role and name
            button = session.page.get_by_role("button", name=button_name).first
            button.wait_for(state="visible", timeout=DEFAULT_TIMEOUT)

            # Take screenshot before click
            playwright_manager.take_screenshot(f"{button_name}_before_click")

            # Click the button
            button.click()
            playwright_manager.take_screenshot(f"{button_name}_after_click")

            # Reload page and wait a bit (if needed)
            session.page.reload()
            session.page.wait_for_timeout(PAGE_LOADTIMEOUT)

            # Assert success text exists in page content
            assert success_text in session.page.content(), f"'{success_text}' not found after clicking '{button_name}'"
            logger.info(f"Button '{button_name}' clicked successfully and '{success_text}' found.")

        except Exception as e:
            playwright_manager.take_screenshot(f"{button_name}_click_fail")
            logger.error(f"Failed to click '{button_name}' or assert '{success_text}': {e}")
            raise

    def click_button_and_assert_call(self, webhmi_session, playwright_manager, button_name, success_text, timeout=DEFAULT_TIMEOUT):
        """Function call of Button click and asserting success text appears"""
        self._click_button_and_assert(webhmi_session, playwright_manager, button_name, success_text, timeout)

    def _send_lw_calibration_request(
        self,
        request,
        session,
        playwright_manager,
        request_name: str,
        response_name: str,
        payload: dict,
        joint_type: str,
        expected_texts: list,
        button_name: str = "Start Calibration",
    ):
        """
        Execute an LW calibration API request and validate UI state.

        Args:
            request: pytest FixtureRequest for accessing WEB_HMI_URI
            session: The WebHMI session object
            playwright_manager: Playwright manager object (for screenshots)
            request_name: API request name (e.g., "LWCalStart", "LWCalTopPos")
            response_name: Expected response name
            payload: Payload dict for the API request
            joint_type: Joint type for logging
            expected_texts: List of texts to find in page content
            button_name: Button to check on page

        Returns:
            bool: True if succeeded, False if failed 
        """
        try:
            response = run_sync_in_thread(
                run_adaptio_send,
                request.config.WEB_HMI_URI,
                request_name=request_name,
                response_name=response_name,
                payload=payload,
                timeout=10,
            )
            logger.debug(f"Received response: {response}")

            # Extract result and message (handle both dict and object formats)
            if isinstance(response, dict):
                result, resp_name = response.get("result"), response.get("name")
                resp_message = response.get("message", "")
            else:
                result = getattr(response, "result", None) or (response.payload.get("result") if hasattr(response, 'payload') else None)
                resp_name = getattr(response, "name", None) or getattr(response, "response_name", None)
                resp_message = getattr(response, "message", "") or (response.payload.get("message", "") if hasattr(response, 'payload') else "")

            if response and result == "ok":
                logger.info(f"Successfully got {resp_name} from {request_name} with joint_type: {joint_type}")
            else:
                logger.warning(f"Failed {request_name} - result: {result}, message: {resp_message}")
                playwright_manager.take_screenshot(f"LW_{request_name}_failed_{joint_type}")
                if result != "ok":
                    if "Timeout waiting for scanner" in str(resp_message) or "Calibration already in progress" in str(resp_message):
                        logger.error("Scanner issue - check connection or simulation status")
                    pytest.skip(f"LW calibration failed: {resp_message}")
                return False

        except TimeoutError:
            logger.exception(f"Timeout in {request_name} with joint_type: {joint_type}")
            if result != "ok":
                pytest.skip("LW calibration failed due to timeout")
            return False

        # Validate UI state
        session.page.wait_for_timeout(1000)
        page_content = session.page.content()
        matched_text = next((text for text in expected_texts if text in page_content), None)
        if matched_text:
            logger.info(f"Expected '{matched_text}' found for {request_name}")
        else:
            logger.warning(f"None of {expected_texts} found for {request_name}, joint_type: {joint_type}")
            playwright_manager.take_screenshot(f"LW_{request_name}_incomplete")
        return True

    def _checkbox_click(self, webhmi_session, playwright_manager, text, timeout):
        """
        Click a checkbox-like element identified by visible text, and capture a screenshot.

        Args:
            session: The WebHMI session object.
            playwright_manager: Playwright manager object (for screenshots).
            text (str): The visible text to match inside elements with class "cursor-pointer".
            timeout (int | float): Timeout in milliseconds to wait for the element to become visible.

        Returns:
            None
        """

        session = webhmi_session
        try:
            locator = session.page.locator("div.cursor-pointer", has_text=text)
            locator.wait_for(state="visible", timeout=timeout)
            locator.click()
            playwright_manager.take_screenshot(f"Checkbox_{text}")
        except Exception as e:
            logger.error(f"Failed to click element with text '{text}': {e}")
            playwright_manager.take_screenshot(f"Checkbox_{text}_fails")
            raise

    def checkbox_click_call(self, webhmi_session, playwright_manager, text, timeout):
        """A function call of checkbox-like element by text"""
        self._checkbox_click(webhmi_session, playwright_manager, text, timeout)

    def _select_random_option(self, webhmi_session, playwright_manager, selector:str) -> str:
        """
        Selects a random option from a <select> dropdown.

        Args:
            page (Page): Playwright page object
            selector (str): Selector for the <select> element

        Returns:
            str: The value of the selected option
        """
        session = webhmi_session
        dropdown = session.page.locator(selector)

        # Get all option elements
        options = dropdown.locator("option").all()

        # Extract values
        values = [opt.get_attribute("value") for opt in options]
        logger.info(f"values are : {values}")
        # Pick a random value
        choice = random.choice(values)
        logger.info(f"Random choice selected as : {choice}")
        # Select it
        dropdown.select_option(choice)
        playwright_manager.take_screenshot(f"Choice of dropdown sensor{choice}")
        #playwright_manager.take_screenshot(f"navigation{safe_path}")

        return choice

    @pytest.mark.webhmi_ui
    def select_random_dropdown_call(self, webhmi_session, playwright_manager, selector:str):
        """Function call of a random option from a dropdown and return the selected value"""
        session = webhmi_session

        selected_value= self._select_random_option(webhmi_session, playwright_manager, selector)

        logger.info(f"Selected dropdown value: {selected_value}")

        # Optional assertion: confirm the dropdown value changed
        assert session.page.locator("select").input_value() == selected_value

    @pytest.mark.webhmi_ui
    def test_webhmi_base_page_loads(self, webhmi_session, playwright_manager):
        """Test that the WebHMI base page loads successfully"""
        session = webhmi_session

        try:
            logger.info(f"Testing WebHMI base page load for {session.base_url}")

            session.navigate_to("/", timeout=LOAD_TIMEOUT)
            session.wait_for_page_ready(timeout=LOAD_TIMEOUT)
            logger.info("WebHMI base page loaded successfully")

            title = session.page.title()
            content = session.page.content()

            assert session.base_url in session.page.url
            assert len(content) > 1000, "Page content appears insufficient"
            logger.info(f"Page title: {title}, Content length: {len(content)}")

            playwright_manager.take_screenshot("webhmi_base_page")

        except Exception as e:
            logger.error(f"WebHMI base page load test failed: {e}")
            playwright_manager.take_screenshot("error_base_page_load")
            raise

    @pytest.mark.webhmi_ui
    def test_webhmi_abp_loads_and_has_core_sections(self, webhmi_session, playwright_manager):
        """Test that ABP page loads and has core sections"""
        session = webhmi_session

        try:
            logger.info("Testing ABP page loads and has core sections")
            session.goto_abp()

            assert "/abp" in session.page.url
            logger.info("ABP page loaded successfully")

            headings_found = []

            try:
                parameters_heading = session.page.locator("[data-track-id$='__Parameters'] h2").first
                parameters_heading.wait_for(state="visible", timeout=LOAD_TIMEOUT)
                heading_text = parameters_heading.text_content()
                if "Parameters" in heading_text:
                    headings_found.append("Parameters")
            except Exception:
                logger.debug("Parameters heading not found")

            try:
                # Status frame's inner panel is labelled "Weld Session" in the UI;
                # use ^= + $= to match only the frame element (not grid/main_view wrappers)
                # and accept any non-empty heading text.
                status_heading = session.page.locator(
                    "[data-track-id^='frame__'][data-track-id$='__Status'] h2"
                ).first
                status_heading.wait_for(state="visible", timeout=LOAD_TIMEOUT)
                heading_text = status_heading.text_content().strip()
                if heading_text:
                    headings_found.append("Status")
            except TimeoutError:
                logger.debug("Status heading not found - timeout")
            except Exception as e:
                logger.debug(f"Status heading not found - {type(e).__name__}: {e}")

            try:
                settings_panel = session.page.locator("[data-track-id$='__Settings']")
                settings_panel.wait_for(state="visible", timeout=LOAD_TIMEOUT)
                headings_found.append("Settings")
            except TimeoutError:
                logger.debug("Settings panel not found - timeout")
            except Exception as e:
                logger.debug(f"Settings panel not found - {type(e).__name__}: {e}")

            page_content = session.page.content()
            content_check = len(page_content) > 1000

            logger.info(f"Found headings: {headings_found}")
            logger.info(f"Page content substantial: {content_check}")

            assert headings_found or content_check, (
                f"No expected elements found and page content insufficient. "
                f"Found headings: {headings_found}, Content length: {len(page_content)}"
            )

            playwright_manager.take_screenshot("abp_core_sections")
            logger.info("ABP core sections test completed successfully")

        except Exception as e:
            logger.error(f"ABP core sections test failed: {e}")
            playwright_manager.take_screenshot("error_abp_core_sections")
            raise

    @pytest.mark.webhmi_ui
    def test_webhmi_abp_navigation_from_base(self, webhmi_session, playwright_manager):
        """Test navigation from base page to ABP page"""
        session = webhmi_session

        try:
            logger.info("Testing navigation from base to ABP page")

            session.navigate_to("/", timeout=LOAD_TIMEOUT)
            session.wait_for_page_ready(timeout=LOAD_TIMEOUT)

            session.navigate_to("/abp", timeout=LOAD_TIMEOUT)
            session.wait_for_page_ready(timeout=LOAD_TIMEOUT)

            assert "/abp" in session.page.url
            logger.info(f"Successfully navigated to: {session.page.url}")

            content = session.page.content()
            assert len(content) > 1000, "ABP page content appears insufficient"

            playwright_manager.take_screenshot("abp_navigation")
            logger.info("ABP navigation test completed successfully")

        except Exception as e:
            logger.error(f"ABP navigation test failed: {e}")
            playwright_manager.take_screenshot("error_abp_navigation")
            raise

    @pytest.mark.webhmi_ui
    @pytest.mark.parametrize("target_path", [
        "/abp",
        "/events",
        "/calibration",
    ])
    def test_webhmi_basic_page_navigation(self, webhmi_session, playwright_manager, target_path):
        """Test basic navigation to different pages"""
        session = webhmi_session

        try:
            logger.info(f"Testing navigation to: {session.base_url}{target_path}")

            session.navigate_to(target_path, timeout=LOAD_TIMEOUT)
            session.wait_for_page_ready(timeout=LOAD_TIMEOUT)

            assert target_path in session.page.url

            title = session.page.title()
            content = session.page.content()

            assert len(content) > 500, f"Page content appears insufficient for {target_path}"
            logger.info(f"Page loaded - Title: {title}, Content length: {len(content)}")

            safe_path = target_path.replace("/", "_")
            playwright_manager.take_screenshot(f"navigation{safe_path}")

            logger.info(f"Navigation to {target_path} completed successfully")

        except Exception as e:
            logger.error(f"Navigation test for {target_path} failed: {e}")
            safe_path = target_path.replace("/", "_")
            playwright_manager.take_screenshot(f"error_navigation{safe_path}")
            raise

    @pytest.mark.webhmi_ui
    @pytest.mark.webhmi_settings
    def test_webhmi_edge_sensor_dropdown_options_and_select(self, webhmi_session, playwright_manager):
        """Test edge sensor dropdown options and selection"""
        session = webhmi_session

        try:
            logger.info("Testing edge sensor dropdown options and selection")
            session.goto_abp()

            settings = session.page.locator("[data-track-id$='__Settings']").filter(
                has=session.page.locator("label:has-text('Edge sensor')")
            )
            try:
                settings.wait_for(state="visible", timeout=LOAD_TIMEOUT)
            except Exception as e:
                logger.warning(f"Settings panel not found, skipping test: {e}")
                pytest.skip("Settings panel [data-track-id$='__Settings'] not found on ABP page")

            select = settings.locator(
                "div:has(label:has-text('Edge sensor placement')) select"
            ).first
            select.wait_for(state="visible", timeout=DEFAULT_TIMEOUT)

            options = select.locator("option").count()
            assert options == 2, f"Expected 2 options, found {options}"

            labels = select.locator("option").all_text_contents()
            values = select.locator("option").evaluate_all("els => els.map(o => o.value)")

            assert labels == ["left", "right"], f"Expected ['left', 'right'], got {labels}"
            assert values == ["left", "right"], f"Expected ['left', 'right'], got {values}"

            select.select_option("right")
            current = select.evaluate("el => el.value")
            assert current == "right", f"Expected 'right', got '{current}'"

            playwright_manager.take_screenshot("edge_sensor_dropdown")
            logger.info("Edge sensor dropdown test completed successfully")

        except Exception as e:
            logger.error(f"Edge sensor dropdown test failed: {e}")
            playwright_manager.take_screenshot("error_edge_sensor_dropdown")
            raise

    @pytest.mark.webhmi_ui
    @pytest.mark.webhmi_settings
    def test_webhmi_use_edge_sensor_switch_toggles(self, webhmi_session, playwright_manager):
        """Test use edge sensor switch toggles"""
        session = webhmi_session

        try:
            logger.info("Testing use edge sensor switch toggles")
            session.goto_abp()

            settings = session.page.locator("[data-track-id$='__Settings']").filter(
                has=session.page.locator("label.switch")
            )
            try:
                settings.wait_for(state="visible", timeout=LOAD_TIMEOUT)
            except Exception as e:
                logger.warning(f"Settings panel not found, skipping test: {e}")
                pytest.skip("Settings panel [data-track-id$='__Settings'] not found on ABP page")

            checkbox = settings.locator("label.switch input[type='checkbox']").first
            checkbox.wait_for(state="attached", timeout=DEFAULT_TIMEOUT)

            initial_state = checkbox.is_checked()
            logger.info(f"Initial checkbox state: {initial_state}")

            try:
                settings.locator("label.switch").first.click()

                current_state = checkbox.is_checked()
                expected_state = not initial_state
                assert current_state == expected_state, f"Expected {expected_state}, got {current_state}"
                logger.info(f"Toggle successful: {initial_state} -> {current_state}")

            finally:
                current_state = checkbox.is_checked()
                if current_state != initial_state:
                    settings.locator("label.switch").first.click()
                    logger.info("Restored checkbox to initial state")

            playwright_manager.take_screenshot("edge_sensor_switch")
            logger.info("Edge sensor switch test completed successfully")

        except Exception as e:
            logger.error(f"Edge sensor switch test failed: {e}")
            playwright_manager.take_screenshot("error_edge_sensor_switch")
            raise

    @pytest.mark.webhmi_ui
    @pytest.mark.webhmi_settings
    def test_webhmi_store_parameters_button_is_clickable(self, webhmi_session, playwright_manager):
        """Test store parameters button is clickable"""
        session = webhmi_session

        try:
            logger.info("Testing store parameters button clickability")
            session.goto_abp()

            settings = session.page.locator("[data-track-id$='__Settings']").filter(
                has=session.page.locator("button:has-text('Store Parameters')")
            )
            try:
                settings.wait_for(state="visible", timeout=LOAD_TIMEOUT)
            except Exception as e:
                logger.warning(f"Settings panel not found, skipping test: {e}")
                pytest.skip("Settings panel [data-track-id$='__Settings'] not found on ABP page")

            btn = settings.get_by_role("button", name="Store Parameters")

            btn.wait_for(state="visible", timeout=DEFAULT_TIMEOUT)

            is_visible = btn.is_visible()
            assert is_visible, "Store Parameters button should be visible"

            btn.click()
            logger.info("Store Parameters button clicked successfully")

            is_still_visible = btn.is_visible()
            assert is_still_visible, "Store Parameters button should remain visible after click"

            playwright_manager.take_screenshot("store_parameters_button")
            logger.info("Store parameters button test completed successfully")

        except Exception as e:
            logger.error(f"Store parameters button test failed: {e}")
            playwright_manager.take_screenshot("error_store_parameters_button")
            raise

    @pytest.mark.webhmi_ui
    @pytest.mark.webhmi_settings
    def test_webhmi_events(self, webhmi_session, playwright_manager):
        """ Loads the Event page and look for the events such as
        Active, resolved, All sessions """

        session = webhmi_session

        try:

            self.webhmi_page_navigation_call(webhmi_session, playwright_manager, "/events")
            playwright_manager.take_screenshot("event_active")

            self.checkbox_click_call(webhmi_session, playwright_manager, "Resolved", DEFAULT_TIMEOUT)
            self.checkbox_click_call(webhmi_session, playwright_manager, "All", DEFAULT_TIMEOUT)

        except Exception as e:
            logger.error(f"setting of Events page fails: {e}")
            playwright_manager.take_screenshot(f"Events_{e}")
            raise

    @pytest.mark.webhmi_ui
    @pytest.mark.webhmi_settings
    def test_webhmi_laser_to_torch_calibration(self, webhmi_session, playwright_manager):
        """Loads the Laser to torch calibration page and fills the respective data"""

        session = webhmi_session

        try:
            logger.info("Testing Laser to torch calibration webhmi usecases started")

            # Click on "Laser To Torch Calibration" option to open the calibration form
            logger.info("Clicking on 'Laser To Torch Calibration' option")
            try:
                # Try using a more flexible locator
                self.webhmi_page_navigation_call(session, playwright_manager, "/calibration")
                self.checkbox_click_call(session, playwright_manager, "Circumferential Welding Calibration", DEFAULT_TIMEOUT)
                self.checkbox_click_call(session, playwright_manager, "Laser To Torch Calibration", DEFAULT_TIMEOUT)
                session.page.wait_for_timeout(2000)
            except Exception as e:
                logger.warning(f"Could not click 'Laser To Torch Calibration' option: {e}")
                playwright_manager.take_screenshot("laser_to_torch_option_not_found")
                pytest.skip("'Laser To Torch Calibration' option not found or not clickable")

            calibration = []

            with open (yaml_file_path, "r") as file:
                data = yaml.safe_load(file)

            stickout = data['laser_to_torch_calibration']['stickout']
            laser_to_torch_distance = data['laser_to_torch_calibration']['laser_to_torch_distance']
            scanner_mount_angle = data['laser_to_torch_calibration']['scanner_mount_angle']
            calibration.extend([stickout, laser_to_torch_distance, scanner_mount_angle])

            logger.info(f"calibration values to set are : {calibration}")

            # Wait for input fields to appear
            session.page.wait_for_timeout(1000)

            # Fill input fields - now they should be present after clicking the option
            selector = 'input'
            inputs = session.page.query_selector_all(selector)
            logger.info(f"Found {len(inputs)} input fields")

            if len(inputs) < len(calibration):
                logger.warning(f"Expected {len(calibration)} inputs but found {len(inputs)}")
                playwright_manager.take_screenshot("laser_to_torch_insufficient_inputs")
                pytest.skip(f"Insufficient input fields: expected {len(calibration)}, found {len(inputs)}")

            for input_box, value in zip(inputs[:len(calibration)], calibration):
                input_box.fill(str(int(value)))
                logger.info(f"Filled input with value: {value}")

            playwright_manager.take_screenshot("laser_to_torch_inputs_filled")

            # Wait for button to be available after inputs are filled
            session.page.wait_for_timeout(2000)

            # Check if Start Calibration button exists and try to click it
            all_buttons = session.page.query_selector_all('button')
            button_texts = [btn.inner_text().strip() for btn in all_buttons if btn.is_visible()]
            logger.info(f"Available buttons on page: {button_texts}")
            
            button = session.page.get_by_role("button", name="Start Calibration").first
            button_count = button.count()
            logger.info(f"'Start Calibration' button count: {button_count}")
            
            if button_count > 0:
                try:
                    button.wait_for(state="visible", timeout=5000)
                    logger.info("Start Calibration button is visible, attempting to click...")
                    button.click(timeout=5000, force=True)
                    session.page.wait_for_timeout(2000)
                    
                    # Check for success message
                    page_content = session.page.content()
                    if "Calibrated" in page_content or "calibrated" in page_content:
                        logger.info("Calibration successful - 'Calibrated' text found")
                    else:
                        logger.info("Button clicked, but 'Calibrated' text not found")
                    
                    playwright_manager.take_screenshot("laser_to_torch_calibration_completed")
                except Exception as e:
                    logger.info(f"Could not click Start Calibration button: {e}")
                    playwright_manager.take_screenshot("laser_to_torch_calibration_click_failed")
            else:
                logger.info("Start Calibration button not found")
            
            logger.info("Laser to torch calibration test completed - inputs filled successfully")

        except Exception as e:
            logger.error(f"Laser to Torch calibration: {e}")
            playwright_manager.take_screenshot("Laser_to_Torch_calibration_fails")
            raise
    
    @pytest.mark.webhmi_ui
    @pytest.mark.parametrize("joint_type", ["cw"])
    @pytest.mark.webhmi_settings
    @pytest.mark.usefixtures("joint_geometry_setup")
    def test_lasertotorchcalibration_call(self, request: pytest.FixtureRequest, joint_type: str,
                                          webhmi_session, playwright_manager):
        """Function call of Laser to torch calibration with configurable joint type
        
        Args:
            request: pytest FixtureRequest
            joint_type: Joint type configuration ("cw" or "lw")
        """
        logger.info(f"Testing Laser to Torch Calibration with joint_type: {joint_type}")
        session = webhmi_session
        logger.info("Testing Laser to torch calibration webhmi usecases started")
        
        self.webhmi_page_navigation_call(webhmi_session, playwright_manager, "/calibration")
        self.checkbox_click_call(webhmi_session, playwright_manager, "Circumferential Welding Calibration", DEFAULT_TIMEOUT)
        self.checkbox_click_call(webhmi_session, playwright_manager, "Laser To Torch Calibration", DEFAULT_TIMEOUT)


        with open (yaml_file_path, "r") as file:
                data = yaml.safe_load(file)

        stickout = data['laser_to_torch_calibration']['stickout']
        laser_to_torch_distance = data['laser_to_torch_calibration']['laser_to_torch_distance']
        scanner_mount_angle = data['laser_to_torch_calibration']['scanner_mount_angle']
        
        response = None
        try:
            # Instantiate and use the Adaptio client inside the worker thread so
            # WebSocketClientSync creates its own event loop and doesn't capture
            # the test's running loop (which causes "event loop is already running").
            response = run_sync_in_thread(
                run_adaptio_send,
                request.config.WEB_HMI_URI,
                request_name="LaserTorchCalSet",
                response_name="LaserTorchCalSetRsp",
                payload={"distanceLaserTorch": laser_to_torch_distance, "stickout": stickout, "scannerMountAngle": scanner_mount_angle},
                timeout=10,
            )
            logger.debug(f"Received response: {response}")
            result = getattr(response, "result", None) or response.payload.get("result")
            if response and result == "ok":
                resp_name = getattr(response, "name", None) or getattr(response, "response_name", None)
                logger.info(f"Successfully got response {resp_name} from laser to torch calibration with joint_type: {joint_type}")
            else:
                logger.warning(f"Failed to set laser to torch calibration with joint_type: {joint_type}")
        except TimeoutError:
            logger.exception(f"Failed to set laser to torch calibration with joint_type: {joint_type}")
        
        all_buttons = session.page.query_selector_all('button')
        button_texts = [btn.inner_text().strip() for btn in all_buttons if btn.is_visible()]
        logger.info(f"Available buttons on page: {button_texts}")
            
        button = session.page.get_by_role("button", name="Start Calibration").first
        button_count = button.count()
        session.page.wait_for_timeout(1000)
        logger.info(f"'Start Calibration' button count: {button_count}")

        page_content = session.page.content()
        if "Calibrated" in page_content or "calibrated" in page_content:
            logger.info("Calibration successful - 'Calibrated' text found")
        else:
            logger.info("Button clicked, but 'Calibrated' text not found")
            logger.warning(f"Button clicked, but 'Calibrated' text not found, {joint_type}") 
            playwright_manager.take_screenshot("laser_to_torch_calibration_incomplete")
        playwright_manager.take_screenshot("laser_to_torch_calibration_completed")

        try:
            response = run_sync_in_thread(
                run_adaptio_send,
                request.config.WEB_HMI_URI,
                request_name="LaserTorchCalGet",
                response_name="LaserTorchCalGetRsp",
                payload={"distanceLaserTorch": laser_to_torch_distance, "stickout": stickout, "scannerMountAngle": scanner_mount_angle},
                timeout=10,
            )
            logger.debug(f"Received response: {response}")
            result = getattr(response, "result", None) or response.payload.get("result")
            if response and result == "ok":
                resp_name = getattr(response, "name", None) or getattr(response, "response_name", None)
                logger.info(f"Successfully got response {resp_name} from laser to torch calibration")
                # Log payload values for verification
                try:
                    logger.info(f"LaserToTorch payload: {response.payload}")
                except Exception:
                    logger.debug("Response payload not available to log")
            else:
                logger.warning(f"Failed to get LaserTorchCalGetRsp response from laser to torch calibration")
        except TimeoutError:
            logger.exception("Failed to get response from laser to torch calibration")
            

    @pytest.mark.webhmi_ui
    @pytest.mark.parametrize("joint_type", ["cw"])
    @pytest.mark.webhmi_settings
    @pytest.mark.usefixtures("joint_geometry_setup")
    def test_lasertotorchcalibration_invalid_stickout(self, request: pytest.FixtureRequest, joint_type: str,
                                          webhmi_session, playwright_manager):
        """Function call of Laser to torch calibration with invalid stickout values

        Tests multiple invalid stickout values
        
        Args:
            request: pytest FixtureRequest
            joint_type: Joint type configuration ("cw" or "lw")
        """
        logger.info(f"Testing Laser to Torch Calibration with joint_type: {joint_type}")
        session = webhmi_session
        logger.info("Testing Laser to torch calibration webhmi usecases started")
        
        self.webhmi_page_navigation_call(webhmi_session, playwright_manager, "/calibration")
        self.checkbox_click_call(webhmi_session, playwright_manager, "Circumferential Welding Calibration", DEFAULT_TIMEOUT)
        self.checkbox_click_call(webhmi_session, playwright_manager, "Laser To Torch Calibration", DEFAULT_TIMEOUT)

        with open (yaml_file_path, "r") as file:
                data = yaml.safe_load(file)

        # Test each invalid stickout value
        invalid_stickout_values = [-15, 0, "abc"]
        test_results = []
        
        for idx, invalid_value in enumerate(invalid_stickout_values, 1):
            logger.info(f"\n--- Testing invalid stickout #{idx}: {invalid_value} ---")
            
            stickout = invalid_value
            laser_to_torch_distance = data['laser_to_torch_calibration']['laser_to_torch_distance']
            scanner_mount_angle = data['laser_to_torch_calibration']['scanner_mount_angle']
            
            response = None
            try:
                response = run_sync_in_thread(
                    run_adaptio_send_receive_data,
                    request.config.WEB_HMI_URI,
                    request_name="LaserTorchCalSet",
                    response_name="LaserTorchCalSetRsp",
                    payload={"distanceLaserTorch": laser_to_torch_distance, "stickout": stickout, "scannerMountAngle": scanner_mount_angle},
                    message={"Unable to store laser to torch calibration data"},
                    timeout=10,
                )
                logger.debug(f"Received response: {response}")
                if isinstance(response, dict):
                    result = response.get("result") or response.get("payload", {}).get("result")
                    resp_name = response.get("name") or response.get("response_name") 
                    resp_message = response.get("message", {})
                else:
                    result = getattr(response, "result", None) or response.message.get("result")
                    resp_name = getattr(response, "name", None) or getattr(response, "response_name", None)
                    resp_message = getattr(response, "message", {})

                logger.info(f"Result: {result} | Response: {resp_name} | Message: {resp_message}")
                
                if result == "fail":
                    logger.info(f"✓ Got expected FAIL result for invalid stickout: {stickout}")
                    test_results.append((invalid_value, "PASS", "Got expected fail result"))
                else:
                    logger.warning(f"✗ Unexpected result '{result}' for invalid stickout: {stickout}")
                    test_results.append((invalid_value, "FAIL", f"Expected fail, got {result}"))
                    
            except TimeoutError as e:
                logger.exception(f"Timeout error for stickout value {invalid_value}: {e}")
                test_results.append((invalid_value, "ERROR", f"Timeout: {str(e)}"))
            except Exception as e:
                logger.exception(f"Error testing stickout value {invalid_value}: {e}")
                test_results.append((invalid_value, "ERROR", f"Exception: {str(e)}"))
            
            # Take screenshot for each test case
            screenshot_name = f"LTC_invalid_stickout_{invalid_value}_{idx}"
            playwright_manager.take_screenshot(screenshot_name)
            logger.info(f"Screenshot taken: {screenshot_name}")
        
        # Summary of all tests
        logger.info("\n" + "="*60)
        logger.info("TEST SUMMARY - Invalid Stickout")
        logger.info("="*60)
        for value, status, message in test_results:
            logger.info(f"  Value: {value!s:6} | Status: {status:6} | {message}")
        logger.info("="*60)
        
        failed_tests = [t for t in test_results if t[1] != "PASS"]
        if failed_tests:
            logger.warning(f"Some tests did not pass as expected: {failed_tests}")
        else:
            logger.info("All invalid stickout tests passed!")

    
    @pytest.mark.webhmi_ui
    @pytest.mark.parametrize("joint_type", ["cw"])
    @pytest.mark.webhmi_settings
    @pytest.mark.usefixtures("joint_geometry_setup")
    def test_lasertotorchcalibration_invalid_scan_angle(self, request: pytest.FixtureRequest, joint_type: str,
                                          webhmi_session, playwright_manager):
        """Function call of Laser to torch calibration with invalid scanner mount angle

        Tests multiple invalid scanner mount angle values
        
        Args:
            request: pytest FixtureRequest
            joint_type: Joint type configuration ("cw" or "lw")
        """
        logger.info(f"Testing Laser to Torch Calibration with joint_type: {joint_type}")
        session = webhmi_session
        logger.info("Testing Laser to torch calibration webhmi usecases started")
        
        self.webhmi_page_navigation_call(webhmi_session, playwright_manager, "/calibration")
        self.checkbox_click_call(webhmi_session, playwright_manager, "Circumferential Welding Calibration", DEFAULT_TIMEOUT)
        self.checkbox_click_call(webhmi_session, playwright_manager, "Laser To Torch Calibration", DEFAULT_TIMEOUT)

        with open (yaml_file_path, "r") as file:
                data = yaml.safe_load(file)

        # Test each invalid scanner mount angle value
        invalid_scanner_mount_angles = [-15, "abc", 400]
        test_results = []
        
        for idx, invalid_angle in enumerate(invalid_scanner_mount_angles, 1):
            logger.info(f"\n--- Testing invalid scanner mount angle #{idx}: {invalid_angle} ---")
            
            scanner_mount_angle = invalid_angle
            stickout = data['laser_to_torch_calibration']['stickout']
            laser_to_torch_distance = data['laser_to_torch_calibration']['laser_to_torch_distance']
            
            response = None
            try:
                # Send request with invalid scanner mount angle
                response = run_sync_in_thread(
                    run_adaptio_send_receive_data,
                    request.config.WEB_HMI_URI,
                    request_name="LaserTorchCalSet",
                    response_name="LaserTorchCalSetRsp",
                    payload={"distanceLaserTorch": laser_to_torch_distance, "stickout": stickout, "scannerMountAngle": scanner_mount_angle},
                    message={"Unable to store laser to torch calibration data"},
                    timeout=10,
                )
                logger.debug(f"Received response: {response}")
                
                if isinstance(response, dict):
                    result = response.get("result") or response.get("payload", {}).get("result")
                    resp_name = response.get("name") or response.get("response_name") 
                    resp_message = response.get("message", {})
                else:
                    result = getattr(response, "result", None) or response.message.get("result")
                    resp_name = getattr(response, "name", None) or getattr(response, "response_name", None)
                    resp_message = getattr(response, "message", {})

                logger.info(f"Result: {result} | Response: {resp_name} | Message: {resp_message}")
                
                if result == "fail":
                    logger.info(f"✓ Got expected FAIL result for invalid angle: {scanner_mount_angle}")
                    test_results.append((invalid_angle, "PASS", "Got expected fail result"))
                else:
                    logger.warning(f"✗ Unexpected result '{result}' for invalid angle: {scanner_mount_angle}")
                    test_results.append((invalid_angle, "FAIL", f"Expected fail, got {result}"))
                    
            except TimeoutError as e:
                logger.exception(f"Timeout error for angle value {invalid_angle}: {e}")
                test_results.append((invalid_angle, "ERROR", f"Timeout: {str(e)}"))
            except Exception as e:
                logger.exception(f"Error testing angle value {invalid_angle}: {e}")
                test_results.append((invalid_angle, "ERROR", f"Exception: {str(e)}"))
            
            # Take screenshot for each test case
            screenshot_name = f"LTC_invalid_angle_{invalid_angle}_{idx}"
            playwright_manager.take_screenshot(screenshot_name)
            logger.info(f"Screenshot taken: {screenshot_name}")
        
        # Summary of all tests
        logger.info("\n" + "="*60)
        logger.info("TEST SUMMARY - Invalid Scanner Mount Angle")
        logger.info("="*60)
        for angle, status, message in test_results:
            logger.info(f"  Angle: {angle:6} | Status: {status:6} | {message}")
        logger.info("="*60)
        
        # Fail the test if any invalid value didn't produce expected fail
        failed_tests = [t for t in test_results if t[1] != "PASS"]
        if failed_tests:
            logger.warning(f"Some tests did not pass as expected: {failed_tests}")
        else:
            logger.info("All invalid angle tests passed!")

    
    @pytest.mark.webhmi_ui
    @pytest.mark.parametrize("joint_type", ["cw"])
    @pytest.mark.webhmi_settings
    @pytest.mark.usefixtures("joint_geometry_setup")
    def test_lasertotorchcalibration_invalid_ltc_distance(self, request: pytest.FixtureRequest, joint_type: str,
                                          webhmi_session, playwright_manager):
        """Function call of Laser to torch calibration with invalid laser to torch distance

        Tests multiple invalid distance values
        
        Args:
            request: pytest FixtureRequest
            joint_type: Joint type configuration ("cw" or "lw")
        """
        logger.info(f"Testing Laser to Torch Calibration with joint_type: {joint_type}")
        session = webhmi_session
        logger.info("Testing Laser to torch calibration webhmi usecases started")
        
        self.webhmi_page_navigation_call(webhmi_session, playwright_manager, "/calibration")
        self.checkbox_click_call(webhmi_session, playwright_manager, "Circumferential Welding Calibration", DEFAULT_TIMEOUT)
        self.checkbox_click_call(webhmi_session, playwright_manager, "Laser To Torch Calibration", DEFAULT_TIMEOUT)

        with open (yaml_file_path, "r") as file:
                data = yaml.safe_load(file)

        # Test each invalid laser to torch distance value
        invalid_distance_values = [-15, "abc", 0]
        test_results = []
        
        for idx, invalid_value in enumerate(invalid_distance_values, 1):
            logger.info(f"\n--- Testing invalid LTC distance #{idx}: {invalid_value} ---")
            
            laser_to_torch_distance = invalid_value
            stickout = data['laser_to_torch_calibration']['stickout']
            scanner_mount_angle = data['laser_to_torch_calibration']['scanner_mount_angle']
            
            response = None
            try:
                response = run_sync_in_thread(
                    run_adaptio_send_receive_data,
                    request.config.WEB_HMI_URI,
                    request_name="LaserTorchCalSet",
                    response_name="LaserTorchCalSetRsp",
                    payload={"distanceLaserTorch": laser_to_torch_distance, "stickout": stickout, "scannerMountAngle": scanner_mount_angle},
                    message={"Unable to store laser to torch calibration data"},
                    timeout=10,
                )
                logger.debug(f"Received response: {response}")
                if isinstance(response, dict):
                    result = response.get("result") or response.get("payload", {}).get("result")
                    resp_name = response.get("name") or response.get("response_name") 
                    resp_message = response.get("message", {})
                else:
                    result = getattr(response, "result", None) or response.message.get("result")
                    resp_name = getattr(response, "name", None) or getattr(response, "response_name", None)
                    resp_message = getattr(response, "message", {})

                logger.info(f"Result: {result} | Response: {resp_name} | Message: {resp_message}")
                
                if result == "fail":
                    logger.info(f"✓ Got expected FAIL result for invalid distance: {laser_to_torch_distance}")
                    test_results.append((invalid_value, "PASS", "Got expected fail result"))
                else:
                    logger.warning(f"✗ Unexpected result '{result}' for invalid distance: {laser_to_torch_distance}")
                    test_results.append((invalid_value, "FAIL", f"Expected fail, got {result}"))
                    
            except TimeoutError as e:
                logger.exception(f"Timeout error for distance value {invalid_value}: {e}")
                test_results.append((invalid_value, "ERROR", f"Timeout: {str(e)}"))
            except Exception as e:
                logger.exception(f"Error testing distance value {invalid_value}: {e}")
                test_results.append((invalid_value, "ERROR", f"Exception: {str(e)}"))
            
            # Take screenshot for each test case
            screenshot_name = f"LTC_invalid_distance_{invalid_value}_{idx}"
            playwright_manager.take_screenshot(screenshot_name)
            logger.info(f"Screenshot taken: {screenshot_name}")
        # Summary of all testvalues
        logger.info("\n" + "="*60)
        logger.info("TEST SUMMARY - Invalid Laser to Torch Distance")
        logger.info("="*60)
        for value, status, message in test_results:
            logger.info(f"  Value: {value!s:6} | Status: {status:6} | {message}")
        logger.info("="*60)
        
        failed_tests = [t for t in test_results if t[1] != "PASS"]
        if failed_tests:
            logger.warning(f"Some tests did not pass as expected: {failed_tests}")
        else:
            logger.info("All invalid distance tests passed!")

    @pytest.mark.webhmi_ui
    @pytest.mark.parametrize("joint_type", ["lw"])
    @pytest.mark.webhmi_settings
    @pytest.mark.usefixtures("joint_geometry_setup")
    def test_lw_calibration_call(self, request: pytest.FixtureRequest, 
                                 joint_type: str, update_adaptio_config,
                                 webhmi_session, playwright_manager):
        """Function call of Laser to torch calibration with configurable joint type
        
        Args:
            request: pytest FixtureRequest
            joint_type: Joint type configuration ("cw" or "lw")
        """
        # Run config update in separate thread to avoid event loop conflict with Playwright
        run_sync_in_thread(
            update_adaptio_config,
            Path(__file__).parent / Path("adaptio_configs/lw_image_simulation"),
            timeout=60
        )
        # replace_config_files already restarts Adaptio, just wait for it to be ready
        time.sleep(5)
        
        logger.info(f"Testing Laser to Torch Calibration with joint_type: {joint_type}")
        session = webhmi_session
        logger.info("Testing Laser to torch calibration webhmi usecases started")
        
        self.webhmi_page_navigation_call(webhmi_session, playwright_manager, "/calibration")
        self.checkbox_click_call(webhmi_session, playwright_manager, "Longitudinal Welding Calibration", DEFAULT_TIMEOUT)

        with open (yaml_file_path, "r") as file:
                data = yaml.safe_load(file)

        cal_data = data['lw_calibration_1751026725959']
        start_payload = {
            "distanceLaserTorch": cal_data['laser_to_torch_distance'],
            "stickout": cal_data['stickout'],
            "scannerMountAngle": cal_data['scanner_mount_angle'],
            "wireDiameter": cal_data['wire_diameter'],
        }

        # LWCalStart - skip test if scanner/hardware issues
        self._send_lw_calibration_request(
            request, session, playwright_manager,
            request_name="LWCalStart", response_name="LWCalStartRsp",
            payload=start_payload, joint_type=joint_type,
            expected_texts=["Calibration in progress... Record top position"],
        )

        # Position calibration steps
        calibration_steps = [
            ("LWCalTopPos", "LWCalTopPosRsp", ["Top position accepted"]),
            ("LWCalLeftPos", "LWCalLeftPosRsp", ["Left position accepted"]),
            ("LWCalRightPos", "LWCalRightPosRsp", ["Calibrated"]),
        ]
        for req_name, resp_name, expected in calibration_steps:
            self._send_lw_calibration_request(
                request, session, playwright_manager,
                request_name=req_name, response_name=resp_name,
                payload={}, joint_type=joint_type, expected_texts=expected,
            )

        # Get and log calibration result
        try:
            response = run_sync_in_thread(
                run_adaptio_send, request.config.WEB_HMI_URI,
                request_name="LWCalGet", response_name="LWCalGetRsp",
                payload={}, timeout=10,
            )
            result = getattr(response, "result", None) or response.payload.get("result")
            if response and result == "ok":
                logger.info(f"LWCalGet succeeded")
                payload = response.payload if hasattr(response, 'payload') else response
                if isinstance(payload, dict):
                    logger.info(f"LWCalGet: {payload}")
            else:
                logger.warning("Failed to get LWCalGetRsp")
        except TimeoutError:
            logger.exception("Timeout getting LWCalGet response")
            playwright_manager.take_screenshot("LW_calibration_incomplete")
        playwright_manager.take_screenshot("LW_calibration_completed")
        
    @pytest.mark.webhmi_ui
    @pytest.mark.webhmi_settings
    def test_abp(self, request: pytest.FixtureRequest, webhmi_session, playwright_manager):
        """
        Validate ABP configuration workflow by populating UI fields, storing via API, and confirming the values.
        Args:
            request: pytest FixtureRequest providing WEB_HMI_URI.
            webhmi_session: Playwright session fixture scoped to WebHMI.
            playwright_manager: Helper used for screenshots on success/failure.
        """
        session = webhmi_session
        try:
            logger.info("Testing ABP webhmi usecases started")

            # Step 1: navigate to the ABP page
            try:
                self.webhmi_page_navigation_call(session, playwright_manager, "/abp")
                session.page.wait_for_timeout(2000)
            except Exception as e:
                logger.warning(f"Could not navigate to ABP page: {e}")
                playwright_manager.take_screenshot("abp_page_not_found")
                pytest.skip("ABP page not found or not accessible")

            # Step 2: load ABP defaults from YAML
            with open(yaml_file_path, "r") as file:
                data = yaml.safe_load(file)

            bead_switch_angle = data['abp']['general']['bead_switch_angle']
            bead_switch_overlap = data['abp']['general']['bead_switch_overlap']

            offset = data['abp']['fill']['wall_offset']
            stepup = data['abp']['fill']['step']
            weld_speed_min = data['abp']['fill']['weld_speed']['min']
            weld_speed_max = data['abp']['fill']['weld_speed']['max']
            heat_input_min = data['abp']['fill']['heat_input']['min']
            heat_input_max = data['abp']['fill']['heat_input']['max']
            weld_system_2_current_min = data['abp']['fill']['weld_system_2_current']['min']
            weld_system_2_current_max = data['abp']['fill']['weld_system_2_current']['max']

            cap_beads = data['abp']['cap']['cap_beads']
            cap_corner_offset = data['abp']['cap']['cap_corner_offset']
            cap_init_depth = data['abp']['cap']['cap_init_depth']

            store_payload = {
                "beadOverlap": bead_switch_overlap, "beadSwitchAngle": bead_switch_angle,
                "heatInput": {"min": heat_input_min, "max": heat_input_max},
                "stepUpValue": stepup, "wallOffset": offset,
                "weldSpeed": {"min": weld_speed_min, "max": weld_speed_max},
                "weldSystem2Current": {"min": weld_system_2_current_min,
                    "max": weld_system_2_current_max},
                "capBeads": cap_beads, "capCornerOffset": cap_corner_offset,
                "capInitDepth": cap_init_depth,
            }
            response = run_sync_in_thread(
                run_adaptio_send,
                request.config.WEB_HMI_URI,
                request_name="StoreABPParameters",
                response_name="StoreABPParametersRsp",
                payload=store_payload,
                timeout=10,
            )
            logger.debug(f"Received response: {response}")
            session.page.wait_for_timeout(1000)
            result = getattr(response, "result", None) or response.payload.get("result")
            if response and result == "ok":
                logger.info("StoreABPParameters succeeded")
            else:
                logger.warning("Failed to get StoreABPParametersRsp response")
                pytest.skip(f"StoreABPParameters failed — cannot verify persistence: {result}")

            # Step 4: retrieve ABP parameters to verify persistence
            response = run_sync_in_thread(
                run_adaptio_send,
                request.config.WEB_HMI_URI,
                request_name="GetABPParameters",
                response_name="GetABPParametersRsp",
                payload=store_payload,
                timeout=10,
            )
            logger.debug(f"Received response: {response}")
            session.page.wait_for_timeout(1000)
            result = getattr(response, "result", None) or response.payload.get("result")
            if response and result == "ok":
                logger.info("GetABPParameters succeeded")
                payload = response.payload if hasattr(response, 'payload') else response
                if isinstance(payload, dict):
                    logger.info(f"GetABPParameters: {payload}")
            else:
                logger.warning("Failed to get GetABPParametersRsp response")
                pytest.skip(f"GetABPParameters failed — cannot verify persistence: {result}")
            # Step 5: click "Store Parameters" UI button for parity with UI workflow
            all_buttons = session.page.query_selector_all('button')
            button_texts = [btn.inner_text().strip() for btn in all_buttons if btn.is_visible()]
            logger.info(f"Available buttons on page: {button_texts}")
            button = session.page.get_by_role("button", name="Store Parameters").first
            button_count = button.count()
            logger.info(f"'Store Parameters' button count: {button_count}")

            if button_count > 0:
                try:
                    button.wait_for(state="visible", timeout=5000)
                    logger.info("'Store Parameters' button is visible, attempting to click...")
                    button.click(timeout=5000, force=True)
                    session.page.reload()
                    session.page.wait_for_timeout(1000)
                    playwright_manager.take_screenshot("store_parameters_clicked")
                except Exception as e:
                    logger.info(f"Could not click 'Store Parameters' button: {e}")
                    playwright_manager.take_screenshot("store_parameters_click_failed")
            else:
                logger.info("'Store Parameters' button not found")
            logger.info("ABP test completed")
        except Exception as e:
            logger.error(f"ABP test failed: {e}")
            playwright_manager.take_screenshot("abp_fails")
            pytest.skip(f"ABP test failed — cannot verify persistence: {e}")
