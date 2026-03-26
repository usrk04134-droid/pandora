"""Playwright Manager Module for UI Testing"""

from datetime import datetime
from enum import Enum
from pathlib import Path
from typing import Optional

import pytest
from loguru import logger
from playwright.sync_api import (
    Browser,
    BrowserContext,
    Page,
    Playwright,
    sync_playwright,
)


class BrowserType(Enum):
    """Supported browser types for testing."""
    CHROMIUM = "chromium"
    FIREFOX = "firefox"


class PlaywrightManager:
    """Playwright Manager for UI Testing with pytest integration - Sync Version."""

    def __init__(self, request: pytest.FixtureRequest) -> None:
        """Initialize the PlaywrightManager from pytest config options."""
        self.request = request

        # Get browser options from pytest config
        getoption = getattr(request.config, "getoption", lambda x, default=None: default)
        browser_name = getoption("--browser", default="chromium")
        if browser_name is None:
            browser_name = "chromium"
        headless = not getoption("--headed", default=False)
        record_video = getoption("--record-video", default=False)

        # Map browser name to enum
        browser_map = {
            "chromium": BrowserType.CHROMIUM,
            "firefox": BrowserType.FIREFOX,
        }
        browser_type = browser_map.get(browser_name.lower(), BrowserType.CHROMIUM)

        # Configure playwright options
        self.browser_type = browser_type
        self.headless = headless if headless is not None else True
        self.slow_mo = 0
        self.viewport_size = {"width": 1920, "height": 1080}
        self.record_video = record_video if record_video is not None else False
        self.video_dir = Path("test_videos") if self.record_video else None
        self.tracing = False

        self._playwright: Optional[Playwright] = None
        self._browser: Optional[Browser] = None
        self._context: Optional[BrowserContext] = None
        self._page: Optional[Page] = None

        logger.info(f"Playwright configured: {browser_name} (headless={self.headless},"
                    f" record_video={self.record_video})")

    @property
    def browser(self) -> Optional[Browser]:
        """Get the browser instance."""
        return self._browser

    @property
    def context(self) -> Optional[BrowserContext]:
        """Get the browser context."""
        return self._context

    @property
    def page(self) -> Optional[Page]:
        """Get the current page."""
        return self._page

    def start(self) -> None:
        """Start the Playwright browser instance - Sync Version."""
        try:
            logger.info(f"Starting Playwright with {self.browser_type.value} browser")
            self._playwright = sync_playwright().start()

            # Launch browser based on type
            launch_options = {
                "headless": self.headless,
                "slow_mo": self.slow_mo,
            }

            if self.browser_type == BrowserType.CHROMIUM:
                # Add Chrome-specific args for better compatibility
                launch_options["args"] = [
                    "--no-sandbox",
                    "--disable-dev-shm-usage",
                    "--disable-extensions",
                    "--disable-gpu",
                ]
                self._browser = self._playwright.chromium.launch(**launch_options)
            elif self.browser_type == BrowserType.FIREFOX:
                self._browser = self._playwright.firefox.launch(**launch_options)
            else:
                raise ValueError(f"Unsupported browser type: {self.browser_type}")

            # Create context with video recording if enabled
            context_options = {
                "viewport": self.viewport_size,
                "ignore_https_errors": True,
            }

            if self.record_video and self.video_dir:
                self.video_dir.mkdir(exist_ok=True)
                context_options["record_video_dir"] = str(self.video_dir)
                context_options["record_video_size"] = self.viewport_size

            self._context = self._browser.new_context(**context_options)

            if self.tracing:
                self._context.tracing.start(screenshots=True, snapshots=True)

            # Create initial page
            self._page = self._context.new_page()

            logger.info("Playwright browser started successfully")

        except Exception as e:
            logger.error(f"Failed to start Playwright: {e}")
            self.stop()
            raise

    def stop(self) -> None:
        """Stop the Playwright browser instance - Sync Version."""
        try:
            logger.debug("Starting sync Playwright cleanup")

            # Stop tracing first (if enabled)
            if self.tracing and self._context:
                try:
                    self._context.tracing.stop(path="trace.zip")
                except Exception as e:
                    logger.debug(f"Tracing stop failed: {e}")

            # Close page first
            if self._page:
                try:
                    self._page.close()
                except Exception as e:
                    logger.debug(f"Page close failed: {e}")
                finally:
                    self._page = None

            # Close context
            if self._context:
                try:
                    self._context.close()
                except Exception as e:
                    logger.debug(f"Context close failed: {e}")
                finally:
                    self._context = None

            # Close browser
            if self._browser:
                try:
                    self._browser.close()
                except Exception as e:
                    logger.debug(f"Browser close failed: {e}")
                finally:
                    self._browser = None

            # Stop playwright
            if self._playwright:
                try:
                    self._playwright.stop()
                except Exception as e:
                    logger.debug(f"Playwright stop failed: {e}")
                finally:
                    self._playwright = None

            logger.debug("Sync Playwright cleanup completed")

        except Exception as e:
            logger.debug(f"Error during sync Playwright cleanup: {e}")
            # Force cleanup of references
            self._page = None
            self._context = None
            self._browser = None
            self._playwright = None

    def close(self) -> None:
        """Synchronous close method for fixture cleanup - Sync Version."""
        try:
            logger.debug("Sync close method - delegating to stop()")
            self.stop()
            logger.debug("Synchronous cleanup completed")

        except Exception as e:
            logger.debug(f"Error during sync Playwright cleanup: {e}")
            # Force cleanup of references
            self._page = None
            self._context = None
            self._browser = None
            self._playwright = None

    def new_page(self) -> Page:
        """Create a new page in the current context - Sync Version."""
        if not self._context:
            self.start()

        if self._context:
            page = self._context.new_page()
            self._page = page  # Update current page reference
            return page
        else:
            raise RuntimeError("Failed to create browser context")

    def ensure_started(self) -> None:
        """Ensure the Playwright instance is started - Sync Version."""
        if not self._playwright:
            self.start()

    def navigate_to(self, url: str, wait_until: str = "networkidle") -> None:
        """Navigate to a URL - Sync Version."""
        self.ensure_started()
        if not self._page:
            self.new_page()

        logger.info(f"Navigating to: {url}")
        self._page.goto(url, wait_until=wait_until)

    def click(self, selector: str, timeout: int = 30000) -> None:
        """Click an element - Sync Version."""
        self.ensure_started()
        if not self._page:
            self.new_page()

        logger.debug(f"Clicking element: {selector}")
        self._page.click(selector, timeout=timeout)

    def fill(self, selector: str, value: str, timeout: int = 30000) -> None:
        """Fill an input field - Sync Version."""
        self.ensure_started()
        if not self._page:
            self.new_page()

        logger.debug(f"Filling element {selector} with: {value}")
        self._page.fill(selector, value, timeout=timeout)

    def get_text(self, selector: str, timeout: int = 30000) -> str:
        """Get text content of an element - Sync Version."""
        self.ensure_started()
        if not self._page:
            self.new_page()

        element = self._page.wait_for_selector(selector, timeout=timeout)
        if element:
            return element.text_content() or ""
        return ""

    def wait_for_selector(
        self, selector: str, timeout: int = 30000, state: str = "visible"
    ) -> None:
        """Wait for a selector to be in a specific state - Sync Version."""
        self.ensure_started()
        if not self._page:
            self.new_page()

        logger.debug(f"Waiting for selector: {selector} (state: {state})")
        self._page.wait_for_selector(selector, timeout=timeout, state=state)

    def take_screenshot(self, name: str, full_page: bool = False) -> bytes:
        """Take a screenshot of the current page - Sync Version."""
        self.ensure_started()
        if not self._page:
            self.new_page()

        # Create screenshots directory if it doesn't exist
        screenshots_dir = Path("logs/screenshots")
        screenshots_dir.mkdir(parents=True, exist_ok=True)

        # Generate filename with timestamp
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        filename = f"{name}_{timestamp}.png"
        screenshot_path = screenshots_dir / filename

        logger.info(f"Taking screenshot: {screenshot_path}")
        screenshot_bytes = self._page.screenshot(
            path=str(screenshot_path),
            full_page=full_page
        )

        return screenshot_bytes

    def evaluate(self, expression: str):
        """Evaluate JavaScript expression in the page context - Sync Version."""
        self.ensure_started()
        if not self._page:
            self.new_page()

        return self._page.evaluate(expression)
