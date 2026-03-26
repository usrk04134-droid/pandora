# ADR 020: Playwright for UI testing framework

## Status

Accepted

## Context

We need a reliable way to automate testing of WebHMI interfaces.

Current challenges with UI testing include:

- Need for robust handling of dynamic content and asynchronous operations in modern web applications
- Requirement for cross-browser compatibility testing across different environments
- Integration with our existing Python/Pytest testing infrastructure
- Minimizing test maintenance overhead while maximizing reliability
- Comprehensive debugging and reporting capabilities for failed tests

For our WebHMI testing needs, we need to select a browser automation framework. Selenium is the most established option in this space, while Playwright is a newer alternative that promises modern APIs and built-in features for handling dynamic web content.

## Decision

We shall use Playwright in our UI testing framework for WebHMI testing. Playwright will be the browser automation engine, working alongside our Pytest toolchain.

The UI testing framework should:

- Use Playwright as the browser automation technology
- Handle testing of WebHMI interfaces across multiple browsers (Chromium, Firefox, WebKit)
- Provide reliable element detection and interaction without manual wait statements
- Support both headless execution for CI pipelines and headed mode for local debugging
- Generate comprehensive test reports with screenshots and traces that integrate with our testing infrastructure

## Consequences

### Positive

- Built-in auto-wait functionality should reduce the need for explicit wait management in tests
- Clean integration opportunity with our Python/Pytest infrastructure from the ground up
- Cross-browser support for testing WebHMI across different environments (Chromium, Firefox)
- Built-in screenshot, video recording, and trace capabilities for enhanced test reporting
- Modern API designed for current web application patterns and JavaScript frameworks
- Can design our test patterns to take full advantage of Playwright's features from day one
- Active development and strong community support from Microsoft
- Supports both headless (for CI) and headed (for development) modes

### Negative

- Smaller community and fewer online resources compared to Selenium's extensive ecosystem.
- Less mature tooling and third-party integrations than Selenium's established ecosystem.
- Newer technology with potentially undiscovered edge cases compared to Selenium's battle-tested stability.
- Requires downloading and managing browser binaries compared to Selenium's system browser usage.

## References

- [Playwright for Python](https://playwright.dev/python/)
- [Playwright Documentation](https://playwright.dev/)
- [Playwright with Pytest](https://playwright.dev/python/docs/test-runners)
- [Microsoft Playwright GitHub](https://github.com/microsoft/playwright)
