# Guide: Writing WebHMI UI Test Cases with pytest

## Table of Contents

1. [Introduction](#introduction)
2. [Prerequisites](#prerequisites)
3. [Understanding the Test Structure](#understanding-the-test-structure)
4. [Writing Your First Test](#writing-your-first-test)
5. [Essential Fixtures](#essential-fixtures)
6. [Test Patterns and Best Practices](#test-patterns-and-best-practices)
7. [Debugging and Troubleshooting](#debugging-and-troubleshooting)
8. [Advanced Features](#advanced-features)
9. [Common Pitfalls](#common-pitfalls)
10. [Example Test Cases](#example-test-cases)

## Introduction

Think of this guide as a teammate who sits beside you while you write WebHMI UI tests. We slow down the pace, explain the why behind the how, and keep the technical depth you rely on. By the end you should feel ready to build, extend, and troubleshoot WebHMI pytest suites without bouncing between tabs.

### What You'll Learn

- Structuring pytest UI tests so they stay readable and reliable
- Leaning on fixtures to keep setup predictable and fast
- Speaking Playwright’s “locator language” to interact with UI controls
- Waiting for the UI the way humans naturally do—only when it matters
- Capturing screenshots and logs that make failures easy to replay

If you are new to WebHMI, that is fine. As long as Python syntax and basic web concepts feel familiar, the rest will come together while you read and practice.

## Prerequisites

### Basic Knowledge Required

- Comfortable with Python functions, imports, and assertions
- Able to spot common HTML elements in a browser inspector
- Exposure to industrial automation vocabulary helps, but we explain terms as we use them

### Tools and Libraries Used

- **pytest** gives us clean test discovery and simple assertions
- **Playwright** drives real browsers the way a user would
- **loguru** keeps logging expressive and minimal
- **WebHMI Session** wraps Playwright with app-specific helpers

If any of these feel unfamiliar, skim their docs later—you can still follow along now.

## Understanding the Test Structure

Before writing code, it helps to know where things live. The WebHMI tests follow a predictable layout so adding a new scenario feels natural the second time you do it.

### Test File Organization

```text
hil-tests/
├── conftest.py              # Shared fixtures and configuration
├── managers.py              # Manager classes for different systems
├── test_webhmi.py           # WebHMI UI tests (our focus)
└── other test files...
```

You will spend most of your time in `test_webhmi.py`, borrowing fixtures and helpers from the neighboring files.

### Test Class Structure

```python
class TestAdaptioWebHMI:
    """Test suite for Adaptio WebHMI UI testing using Sync Playwright with fixtures"""

    @pytest.mark.webhmi_ui
    def test_example(self, webhmi_session, playwright_manager):
        """Your test description here"""
        # Test implementation
```

We group tests by intent (navigation, configuration, etc.) inside the class, and let pytest markers filter the runs in CI or locally.

## Writing Your First Test

Start with the mental model: every test opens a browser, points it at WebHMI, performs an action, and states what “success” looks like. The template below mirrors that rhythm.

### Basic Test Template

```python
@pytest.mark.webhmi_ui
def test_your_feature_name(self, webhmi_session, playwright_manager):
    """Explain what this test proves for future you"""
    session = webhmi_session

    try:
        logger.info("Starting test: your_feature_name")

        # 1. Navigate to the page you want to test
        session.navigate_to("/your-page", timeout=LOAD_TIMEOUT)
        session.wait_for_page_ready(timeout=LOAD_TIMEOUT)

        # 2. Perform your test actions
        # (find elements, click buttons, verify content, etc.)

        # 3. Add assertions to verify expected behavior
        assert "expected-text" in session.page.url

        # 4. Take screenshot for documentation
        playwright_manager.take_screenshot("your_feature_name_success")

        logger.info("Test completed successfully")

    except Exception as e:
        logger.error(f"Test failed: {e}")
        playwright_manager.take_screenshot("error_your_feature_name")
        raise
```

### Step-by-Step Breakdown

Each number in the template maps to a habit you will repeat across tests.

#### 1. Test Markers

Markers tell pytest (and teammates) what sort of test this is. Add more as needed when you need to slice runs.

```python
@pytest.mark.webhmi_ui          # Marks this as a WebHMI UI test
@pytest.mark.webhmi_settings    # Additional marker for settings-related tests
```

#### 2. Test Function Signature

Fixture names show up in the arguments. pytest handles the rest.

```python
def test_feature_name(self, webhmi_session, playwright_manager):
```

- `webhmi_session`: Spins up the browser and exposes WebHMI-aware helpers.
- `playwright_manager`: Grabs screenshots and manages Playwright’s lifecycle.

#### 3. Navigation

Use the helper that communicates the intent best. Direct paths are great when you know the URL; dedicated helpers read better when they exist.

```python
# Navigate to a specific page
session.navigate_to("/abp", timeout=LOAD_TIMEOUT)
session.wait_for_page_ready(timeout=LOAD_TIMEOUT)

# Or use convenience methods
session.goto_abp()  # Specialized method for ABP page
```

#### 4. Finding Elements

Locators are the heart of reliable UI tests. Favor selectors that change the least and express meaning.

```python
# Using CSS selectors
button = session.page.locator("button[name='Store Parameters']")

# Using data attributes (preferred for stable tests)
settings_panel = session.page.locator("[data-track-id='frame__116__Settings']")

# Using text content
submit_btn = session.page.get_by_role("button", name="Submit")

# Chaining selectors for specificity
dropdown = settings_panel.locator("div:has(label:has-text('Edge sensor')) select").first
```

#### 5. Common Interactions

Most Playwright calls read like short sentences. Combine them with waits when timing is tricky.

```python
# Click elements
button.click()

# Type in input fields
input_field.fill("test value")

# Select dropdown options
dropdown.select_option("left")

# Check/uncheck checkboxes
checkbox.check()
checkbox.uncheck()

# Wait for elements
element.wait_for(state="visible", timeout=5000)
```

#### 6. Assertions

Assertions document expectations. When a failure happens, they tell you exactly which assumption broke.

```python
# URL validation
assert "/abp" in session.page.url

# Element state validation
assert button.is_visible()
assert checkbox.is_checked()

# Content validation
assert "Success" in session.page.content()

# Element count validation
options = select.locator("option").count()
assert options == 2
```

## Essential Fixtures

Fixtures keep repetitive setup out of your tests. Treat them as the backstage crew that make each scene possible.

### webhmi_session

Gives you a WebHMI-aware Playwright session, already authenticated and tuned for our app.

```python
def test_example(self, webhmi_session):
    session = webhmi_session

    # Navigation methods
    session.navigate_to("/path")
    session.goto_abp()
    session.wait_for_page_ready()

    # Browser page access
    session.page.click("button")
    session.page.locator("input").fill("value")

    # Configuration
    session.set_default_timeout(30000)
    session.disable_animations()
```

### playwright_manager

Owns the Playwright lifecycle and provides helpers for screenshots and cleanup.

```python
def test_example(self, playwright_manager):
    # Take screenshots for documentation
    playwright_manager.take_screenshot("test_step_1")
    playwright_manager.take_screenshot("error_condition")

    # Screenshots are automatically saved with timestamps
    # and organized by test name
```

### webhmi_session_with_backend

Extends the standard session with WebSocket calls so you can talk to the backend when UI alone is not enough.

```python
def test_with_backend(self, webhmi_session_with_backend):
    session = webhmi_session_with_backend

    # Configure settings via WebSocket
    success = session.configure_settings({
        "useEdgeSensor": False,
        "edgeSensorPlacement": "left"
    })

    if success:
        logger.info("Settings configured successfully")
```

## Test Patterns and Best Practices

Great tests feel boring in the best way—they run the same every time. The patterns below help you get there faster.

### 1. Timeout Management

```python
# Define constants at the top of your test file
DEFAULT_TIMEOUT = 30000
LOAD_TIMEOUT = 15000

# Use appropriate timeouts for different operations
element.wait_for(state="visible", timeout=DEFAULT_TIMEOUT)
session.navigate_to("/page", timeout=LOAD_TIMEOUT)
```

Time spent choosing the right timeout beats time spent re-running flaky tests.

### 2. Element Location Strategies

```python
# ✅ GOOD: Use data attributes when available
panel = session.page.locator("[data-track-id='frame__116__Settings']")

# ✅ GOOD: Use semantic selectors
button = session.page.get_by_role("button", name="Store Parameters")

# ⚠️ ACCEPTABLE: Use CSS selectors as fallback
dropdown = panel.locator("select").first

# ❌ AVOID: Using XPath or brittle selectors
# element = session.page.locator("//div[3]/span[2]/input")
```

When in doubt, imagine the selector surviving a UI facelift. If it probably would, you are on the right track.

### 3. Robust Element Interactions

```python
# Wait for element to be ready before interacting
button = session.page.locator("button")
button.wait_for(state="visible", timeout=DEFAULT_TIMEOUT)
button.click()

# Chain operations for complex elements
dropdown = (settings_panel
           .locator("div:has(label:has-text('Edge sensor'))")
           .locator("select")
           .first)
```

Playwright is fast, but the UI still needs a moment to catch up. Waits keep you in sync.

### 4. Error Handling and Screenshots

```python
def test_feature(self, webhmi_session, playwright_manager):
    session = webhmi_session

    try:
        # Test implementation
        pass

    except Exception as e:
        logger.error(f"Test failed: {e}")
        playwright_manager.take_screenshot("error_feature_name")
        raise  # Re-raise to mark test as failed
```

Screenshots and logs turn “it failed” into “it failed here for this reason.” Future you will be thankful.

### 5. Parameterized Tests

```python
@pytest.mark.webhmi_ui
@pytest.mark.parametrize("target_path", [
    "/abp",
    "/events",
    "/calibration",
])
def test_page_navigation(self, webhmi_session, target_path):
    """Test navigation to different pages"""
    session = webhmi_session

    session.navigate_to(target_path, timeout=LOAD_TIMEOUT)
    assert target_path in session.page.url
```

Parametrization keeps similar tests together—less copy/paste, more signal.

### 6. Page State Management

```python
def test_toggle_feature(self, webhmi_session, playwright_manager):
    session = webhmi_session

    # Capture initial state
    initial_state = checkbox.is_checked()

    # Perform action
    checkbox.click()

    # Verify state change
    new_state = checkbox.is_checked()
    assert new_state != initial_state

    # Restore initial state for cleanup
    if new_state != initial_state:
        checkbox.click()
```

Always leave the page as you found it unless the test specifically checks state persistence.

## Debugging and Troubleshooting

Even the best tests misbehave sometimes. These tools help you understand what changed and why.

### 1. Enable Headed Mode

Run tests with a visible browser when you want to watch the UI flow.

```bash
pytest --headed test_webhmi.py::test_your_test
```

### 2. Capture Screenshots at Key Points

```python
def test_debug_example(self, webhmi_session, playwright_manager):
    session = webhmi_session

    # Take screenshot before action
    playwright_manager.take_screenshot("before_click")

    button.click()

    # Take screenshot after action
    playwright_manager.take_screenshot("after_click")
```

Pair screenshots with log statements to reconstruct the story later.

### 3. Add Debug Logging

```python
def test_with_logging(self, webhmi_session):
    session = webhmi_session

    logger.info("Starting navigation")
    session.navigate_to("/abp")
    logger.info(f"Current URL: {session.page.url}")

    element = session.page.locator("button")
    logger.info(f"Button visible: {element.is_visible()}")
    logger.info(f"Button count: {element.count()}")
```

Short, descriptive log messages beat stack traces when you are scanning through CI output.

### 4. Wait for Network Activity

```python
# Wait for page to settle after navigation
session.page.wait_for_load_state("networkidle", timeout=10000)

# Wait for specific network response
with session.page.expect_response("**/api/settings") as response_info:
    button.click()
response = response_info.value
```

Use network waits when the UI changes after an API call that takes a variable amount of time.

### 5. Console Message Monitoring

```python
def test_with_console_monitoring(self, webhmi_session):
    session = webhmi_session
    console_messages = []

    def handle_console(msg):
        console_messages.append(msg.text)
        logger.info(f"Console: {msg.text}")

    session.page.on("console", handle_console)

    # Perform test actions
    button.click()

    # Check for errors in console
    errors = [msg for msg in console_messages if "error" in msg.lower()]
    assert len(errors) == 0, f"Console errors detected: {errors}"
```

Console monitoring is invaluable when the UI fails silently but the browser logs the truth.

## Advanced Features

Once the basics feel automatic, these techniques help you cover trickier flows.

### 1. Custom Waiting Conditions

```python
def wait_for_ajax_complete(session):
    """Wait for AJAX requests to complete"""
    session.page.wait_for_function("() => window.jQuery && jQuery.active === 0")

def wait_for_element_text(element, expected_text, timeout=5000):
    """Wait for element to contain specific text"""
    element.wait_for(lambda: expected_text in element.text_content(), timeout=timeout)
```

Custom waits let you describe exactly what “ready” means for a given component.

### 2. Working with Frames/iframes

```python
def test_iframe_content(self, webhmi_session):
    session = webhmi_session

    # Access iframe content
    frame = session.page.frame_locator("iframe[name='content']")
    button_in_frame = frame.locator("button")
    button_in_frame.click()
```

Treat frames as mini pages—locate them first, then interact inside their scope.

### 3. File Upload Testing

```python
def test_file_upload(self, webhmi_session):
    session = webhmi_session

    # Upload file
    file_input = session.page.locator("input[type='file']")
    file_input.set_input_files("path/to/test/file.txt")
```

Keep test files small and predictable, and clean them up if you create them dynamically.

### 4. Keyboard and Mouse Interactions

```python
def test_keyboard_shortcuts(self, webhmi_session):
    session = webhmi_session

    # Keyboard shortcuts
    session.page.keyboard.press("Control+S")
    session.page.keyboard.type("test input")

    # Mouse actions
    element = session.page.locator("button")
    element.hover()
    element.click(button="right")  # Right click
```

These interactions help replicate power-user workflows and accessibility checks.

## Common Pitfalls

Every team hits the same bumps on the road. Knowing them upfront makes them easier to avoid.

### 1. Race Conditions

```python
# ❌ WRONG: Not waiting for element
button = session.page.locator("button")
button.click()  # May fail if button not ready

# ✅ CORRECT: Wait for element to be ready
button = session.page.locator("button")
button.wait_for(state="visible", timeout=5000)
button.click()
```

### 2. Stale Element References

```python
# ❌ WRONG: Reusing locators after page changes
dropdown = session.page.locator("select")
dropdown.select_option("option1")
session.page.reload()
dropdown.select_option("option2")  # May fail - stale reference

# ✅ CORRECT: Re-locate elements after page changes
dropdown = session.page.locator("select")
dropdown.select_option("option1")
session.page.reload()
dropdown = session.page.locator("select")  # Re-locate
dropdown.select_option("option2")
```

### 3. Insufficient Waiting

```python
# ❌ WRONG: Fixed sleeps
session.page.wait_for_timeout(5000)  # Arbitrary wait

# ✅ CORRECT: Wait for specific conditions
element.wait_for(state="visible")
session.page.wait_for_load_state("networkidle")
```

### 4. Overly Specific Selectors

```python
# ❌ WRONG: Brittle selector
button = session.page.locator("div.container > div:nth-child(3) > button.btn-primary")

# ✅ CORRECT: Semantic selector
button = session.page.get_by_role("button", name="Submit")
```

## Example Test Cases

Reading full tests is the fastest way to see how the pieces fit together. Use these as starting points and adapt them to match your feature under test.

### Example 1: Basic Page Load Test

```python
@pytest.mark.webhmi_ui
def test_abp_page_loads(self, webhmi_session, playwright_manager):
    """Test that the ABP page loads successfully and contains expected elements"""
    session = webhmi_session

    try:
        logger.info("Testing ABP page load")

        # Navigate to ABP page
        session.goto_abp()

        # Verify URL
        assert "/abp" in session.page.url

        # Verify essential elements are present
        settings_panel = session.page.locator("[data-track-id='frame__116__Settings']")
        settings_panel.wait_for(state="visible", timeout=10000)

        # Take success screenshot
        playwright_manager.take_screenshot("abp_page_loaded")

        logger.info("ABP page loaded successfully")

    except Exception as e:
        logger.error(f"ABP page load test failed: {e}")
        playwright_manager.take_screenshot("error_abp_page_load")
        raise
```

### Example 2: Form Interaction Test

```python
@pytest.mark.webhmi_ui
@pytest.mark.webhmi_settings
def test_edge_sensor_configuration(self, webhmi_session, playwright_manager):
    """Test edge sensor dropdown configuration"""
    session = webhmi_session

    try:
        logger.info("Testing edge sensor configuration")

        # Navigate to settings page
        session.goto_abp()

        # Locate the settings panel and dropdown
        settings = session.page.locator("[data-track-id='frame__116__Settings']")
        dropdown = settings.locator(
            "div:has(label:has-text('Edge sensor placement')) select"
        ).first

        # Wait for dropdown to be ready
        dropdown.wait_for(state="visible", timeout=DEFAULT_TIMEOUT)

        # Verify dropdown options
        options = dropdown.locator("option").all_text_contents()
        expected_options = ["left", "right"]
        assert options == expected_options, f"Expected {expected_options}, got {options}"

        # Test selecting each option
        for option in expected_options:
            dropdown.select_option(option)
            current_value = dropdown.evaluate("el => el.value")
            assert current_value == option, f"Expected '{option}', got '{current_value}'"

            # Screenshot for each selection
            playwright_manager.take_screenshot(f"edge_sensor_{option}")
            logger.info(f"Successfully selected '{option}' option")

        logger.info("Edge sensor configuration test completed")

    except Exception as e:
        logger.error(f"Edge sensor configuration test failed: {e}")
        playwright_manager.take_screenshot("error_edge_sensor_config")
        raise
```

### Example 3: Toggle Switch Test

```python
@pytest.mark.webhmi_ui
@pytest.mark.webhmi_settings
def test_feature_toggle_switch(self, webhmi_session, playwright_manager):
    """Test toggling a feature switch and verifying state changes"""
    session = webhmi_session

    try:
        logger.info("Testing feature toggle switch")

        session.goto_abp()

        # Locate the switch
        settings = session.page.locator("[data-track-id='frame__116__Settings']")
        switch_label = settings.locator("label.switch").first
        checkbox = settings.locator("label.switch input[type='checkbox']").first

        # Wait for elements to be ready
        checkbox.wait_for(state="attached", timeout=DEFAULT_TIMEOUT)

        # Get initial state
        initial_state = checkbox.is_checked()
        logger.info(f"Initial switch state: {initial_state}")

        # Toggle the switch
        switch_label.click()
        session.page.wait_for_timeout(500)  # Allow for animation

        # Verify state changed
        new_state = checkbox.is_checked()
        assert new_state != initial_state, "Switch state should have changed"

        playwright_manager.take_screenshot(f"switch_toggled_to_{new_state}")
        logger.info(f"Switch toggled from {initial_state} to {new_state}")

        # Toggle back to original state
        switch_label.click()
        session.page.wait_for_timeout(500)

        final_state = checkbox.is_checked()
        assert final_state == initial_state, "Switch should return to initial state"

        logger.info("Feature toggle test completed successfully")

    except Exception as e:
        logger.error(f"Feature toggle test failed: {e}")
        playwright_manager.take_screenshot("error_feature_toggle")
        raise
```

### Example 4: Parameterized Navigation Test

```python
@pytest.mark.webhmi_ui
@pytest.mark.parametrize("page_path,expected_content", [
    ("/abp", "Parameters"),
    ("/events", "Events"),
    ("/calibration", "Calibration"),
])
def test_page_navigation_content(self, webhmi_session, playwright_manager, page_path, expected_content):
    """Test navigation to different pages and verify content"""
    session = webhmi_session

    try:
        logger.info(f"Testing navigation to {page_path}")

        # Navigate to the page
        session.navigate_to(page_path, timeout=LOAD_TIMEOUT)
        session.wait_for_page_ready(timeout=LOAD_TIMEOUT)

        # Verify URL
        assert page_path in session.page.url

        # Verify page content
        page_content = session.page.content()
        assert expected_content.lower() in page_content.lower(), \
            f"Expected content '{expected_content}' not found in page"

        # Take screenshot
        safe_path = page_path.replace("/", "_")
        playwright_manager.take_screenshot(f"page{safe_path}_loaded")

        logger.info(f"Navigation to {page_path} successful")

    except Exception as e:
        logger.error(f"Navigation test for {page_path} failed: {e}")
        safe_path = page_path.replace("/", "_")
        playwright_manager.take_screenshot(f"error_page{safe_path}")
        raise
```

## Running Your Tests

When you are ready to run tests, pick the command that matches your goal—quick feedback locally or full suites in CI.

### Basic Test Execution

```bash
# Run all WebHMI UI tests
pytest -m webhmi_ui hil-tests/

# Run specific test file
pytest hil-tests/test_webhmi.py

# Run specific test
pytest hil-tests/test_webhmi.py::TestAdaptioWebHMI::test_your_test_name

# Run with visible browser (for debugging)
pytest --headed hil-tests/test_webhmi.py

# Run with video recording
pytest --record-video hil-tests/test_webhmi.py
```

### Test Configuration Options

```bash
# Use different browser
pytest --browser=firefox hil-tests/test_webhmi.py

# Clean logs before test execution
pytest --clean-logs hil-tests/test_webhmi.py

# Collect logs after test execution
pytest --collect-logs hil-tests/test_webhmi.py

# Update TestRail with results
pytest --testrail hil-tests/test_webhmi.py
```

### Useful pytest Options

```bash
# Stop on first failure
pytest -x hil-tests/test_webhmi.py

# Show local variables in tracebacks
pytest -l hil-tests/test_webhmi.py

# Verbose output
pytest -v hil-tests/test_webhmi.py

# Show print statements
pytest -s hil-tests/test_webhmi.py
```

## Conclusion

You now have a roadmap for building WebHMI UI tests that are readable, maintainable, and kind to teammates who inherit them. Keep these habits front of mind:

1. **Wait with intention** rather than relying on arbitrary sleeps.
2. **Capture context** through screenshots and logging.
3. **Name things clearly**—tests, fixtures, selectors, screenshots.
4. **Choose resilient selectors** that survive UI tweaks.
5. **Handle errors gracefully** so debugging stays focused.
6. **Log what matters** for future triage.
7. **Reset state when possible** so tests stay independent.

As you get comfortable, experiment with new fixtures, integrate with CI, or add reporting hooks. And when something fails, treat it as feedback from a future teammate—very likely yourself.

Happy testing! 🧪
