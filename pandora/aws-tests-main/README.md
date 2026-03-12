# Adaptive Weld System Tests

## Git Commit Message Format

Refer [git-message-format]

## HIL testcase development

### The HIL testing stack

```plantuml
@startuml
!include https://raw.githubusercontent.com/plantuml-stdlib/C4-PlantUML/master/C4_Component.puml

    title HIL Tech Stack - Components (HIL PC)

    Person_Ext(operator, "Operator", "Person who manages the system")

    System_Ext(gitlab, "GitLab.com", "External CI/CD system")
    System_Ext(testrail, "TestRail", "External test management system")

    Container_Boundary(nixos, "NixOS Host") {
        Component(system, "Flake based NixOS", "Stored in Git", "System configurations, tests, and monitoring definitions")
        Component(gitlab_runner, "GitLab Runner", "Nix Service", "Runs CI/CD tasks and reports to GitLab")
        'Component(monitoring, "Monitoring Tools", "Nix Service", "TCPDump, Other Tools for packet inspection and system monitoring")
        Component(test_environment, "Test Environment", "Python, Testzilla", "Test cases and test execution environment")
    }

    Boundary(sut, "System Under Test") {
      Component(adaptio, "Adaptio PC")
      Component(plc, "PLC")
    }

    Rel(operator, system, "Manages and watches", "Local / SSH")

    Rel(gitlab_runner, testrail, "Reports test results", "HTTPS")
    Rel(gitlab, system, "Deploys new versions of NixOS", "HTTPS")
    Rel(gitlab, gitlab_runner, "Sends CI/CD jobs to", "HTTPS")

    Rel(gitlab_runner, gitlab, "Reports status of system and logs to", "HTTPS")

    Rel(system, gitlab_runner, "Starts", "Local")
    Rel(gitlab_runner, test_environment, "Starts", "Local")

    Rel(test_environment, sut, "Runs tests against", "HTTPS | SSH")
@enduml
```

### Current Test Execution Framework Setup

The Gitlab runner on the HIL PC receives CI/CD jobs from Gitlab when a pipeline
is created. It clones the [aws-tests] repository, runs the tests in
the [test environment][test-env] (containerized), and reports the results back
to Gitlab. The execution framework is [Pytest][pytest], configured in
the [conftest.py][conftest] file within the [aws-tests] repository.

If enabled, the framework automatically handles the following operations:

**Before each test case:**

* Stops Adaptio
* Clears Adaptio logs
* Starts Adaptio

> [!note]
Enable with `--clean-logs`

**After each test case:**

* Collects Adaptio logs

> [!note]
Enable with `--collect-logs`

**After the pytest session:**

* Archives collected logs.

For the following scenarios, testers must explicitly include fixtures in their
tests:

**Image Simulation Test Cases:**

* Use the `update_adaptio_config` fixture. Pass the path to the configuration
  files to copy the correct configurations to Adaptio. The framework
  automatically resets the configuration files to those in `/etc/adaptio` at
  the **end of each test case**.

> [!note]
> Can be disabled with `--disable-config-update`

**Tests Requiring PLC Interaction:**

* Use the `setup_plc` fixture to log in to the PLC and interact with it. The
  framework automatically logs out of the PLC at the **end of each test module
  **.

### Writing Test Cases with Testzilla

Follow these steps to write test cases using Testzilla:

1. **Create a Python Module:** Under the `hil-tests` directory, create a Python
   module to group related test cases. Name the file using the format:
   `test_<test module name>.py`.

1. **Define a Test Suite Class:** Inside the Python module, create a class that
   represents the test suite. Name the class using the format:
   `class TestModuleName`.

1. **Implement Test Case Functions:** For each individual test case within the
   suite, create a Python function. Name the function using the format:
   `test_<describing_name>`.
    * Utilize Required Fixtures: Within each test case function, use the
      necessary fixtures defined in the [conftest.py][conftest] file.
    * Create New Fixtures (If Needed): If new fixtures are required, create
      them in the appropriate locations.
    * Global settings: Global settings should be specified in the
      `pytest_configure` function in [conftest.py][conftest].
    * Logging in test cases: It is recommended to use `loguru` to log
      information in the test cases.

1. **Categorize Test Case Functions:** When applicable, add pytest markers
   to categorize the test function.
   * Add marker: For each test function, add the appropriate marker using
     `@pytest.mark.<name>`. Custom markers are defined in the [conftest.py][conftest] file.
   * Create marker (if needed): If a new marker is needed, create it in the
     [conftest.py][conftest] file.

#### Key Testzilla Features

[Testzilla][testzilla] offers features for interacting with:

* [Adaptio PC][adaptio-pc]
* [Programmable logic controller (PLC)][plc]
* [Power source units (PSUs)][psu]
* [WebHMI][webhmi]

### Executing test cases

We use [Pytest][use-pytest] to execute the test cases. To run tests manually:

* **Enter the Test Environment:** Navigate to the infra-and-test repository and
  and use `nix develop` to create the necessary test environment with Pytest.

```bash
cd abw/infra-and-test/flakes/test-env
nix develop
```

You'll see a shell prompt like: [test-environment-2]

* **Run the tests:** In the same shell, go to the [aws-tests] repo and execute
  the test cases using Pytest.

```bash
cd abw/aws-tests
pytest ./hil-tests
```

* **Select tests:** Markers can be used to select which test cases to run.
  Custom markers are defined in [conftest.py][conftest].

```bash
pytest ./hil-tests -m "plc_only"
```

* **Logs:** Pytest logs will be saved to `./logs`. To have test case logs printed to the
  console during execution:

```bash
export TESTZILLA_LOG_LEVEL=INFO
pytest ./hil-tests -vv --capture=tee-sys
```

  Coredumps and Adaptio logs are automatically fetched from Adaptio PC and
  saved as `sut_logs.tar.gz` in the [aws-tests] working directory.

### Debugging test cases

To debug failing test cases, utilize the pytest logs generated during
execution. These logs contain all information logged by the test case.

**Analyzing Pytest Logs:**

Near the end of the test log, pytest provides a summary of failed tests,
including the verdict and the reason for each failure.

**Example Log Analysis:**

```python
__________
TestJointTracking.test_joint_tracking_run_for_5_seconds
____________
self = < test_joint_tracking.TestJointTracking
object
at
0x7f9d63e714c0 >
setup_plc = < testzilla.plc.plc_json_rpc.PlcJsonRpc
object
at
0x7f9d63d98590 >
update_adaptio_config = < function
update_adaptio_config_fixture. < locals >._update_adaptio_config
at
0x7f9d63ce98a0 >
addresses = {
    'heartbeat_from_adaptio': '"Adaptio.DB_AdaptioCommunication".DataFromAdaptio.Adaptio.Heartbeat',
    ...}
reset_slide_cross_positions = None


def test_joint_tracking_run_for_5_seconds(self, setup_plc,
                                          addresses, reset_slide_cross_positions):
    plc = setup_plc
    started, _ = plc.write(var=addresses["joint_tracking_button"], value=3)
    logger.info("Starting joint tracking")
    time.sleep(
        5)  # TODO: Get info from developers on how to time/loop this best
    status, _ = plc.read(var=addresses["joint_tracking_button"])
    logger.info(f"Joint tracking status: {status}")

> assert status == 3
E
assert 1 == 3
test_joint_tracking.py: 27: AssertionError
```

In this example, the `AssertionError` clearly indicates that the expected
status (`3`) did not match the actual status (`1`). To investigate further,
examine the code leading up to the assertion, specifically the line where the
`status` variable was assigned.

**Reporting Testzilla Issues:**

If you suspect the test case failure is due to a problem within the Testzilla
framework itself, contact Team Godzilla
at [team-godzilla@esab.onmicrosoft.com](team-godzilla@esab.onmicrosoft.com)

### Debugging SUTs

Debugging SUTs primarily involves analyzing logs collected during test
execution. The following logs are automatically gathered from Adaptio for each
test case.

* **Adaptio Logs:** These logs provide detailed information about Adaptio's
  behavior.
* **Coredumps:** These files capture the memory state of Adaptio in case of
  crashes or unexpected termination.

These logs are collected for each test and then archived into
`artifacts -> hil-tests -> sut_logs.tar.gz` in Gitlab.

**Log File Organization:**
The archived logs are structured hierarchically, making it easy to locate logs
for specific tests:

```bash
├── test_heartbeats
│   ├── test_heartbeat_adaptio_to_plc_relay
│   │   ├── adaptio
│   │   │   ├── ADAPTIO.log
│   │   │   └── weldcontrol
│   │   │       └── 20250327_153011.log
│   │   └── coredump
│   └── test_heartbeat_plc_to_adaptio
│       ├── adaptio
│       │   ├── ADAPTIO.log
│   │   └── weldcontrol
│   │       └── 20250327_153001.log
│       └── coredump
└── test_joint_tracking
       ├── test_joint_tracking_initial_state
       │   ├── adaptio
       │   │   ├── ADAPTIO.log
       │   │   └── weldcontrol
       │   │       └── 20250327_153018.log
       │   └── coredump
       └── test_joint_tracking_run_for_5_seconds
           ├── adaptio
           │   ├── ADAPTIO_20250327_153030.log
           │   ├── ADAPTIO_20250327_153045.log
           │   ├── ADAPTIO.log
           │   └── weldcontrol
           │       ├── 20250327_153026.log
           │       ├── 20250327_153035.log
           │       └── 20250327_153047.log
           └── coredump
```

To debug Adaptio related issues, analyze the collected Adaptio logs and any
generated coredump files.

## Setup and Teardown Procedures

### Setup procedure

1. PLC Connection Setup:

    * Establishes connection to PLC via JSON-RPC interface at `192.168.100.10`
    * Performs login authentication

1. Adaptio Service Management:

    * Function to Start, Stop, and Restart the Adaptio service
    * Includes wait time after restart to ensure PLC connection is established

1. Configuration Management:

    * Function to replace and restore configuration files
    * Copy from local to remote destinations with proper permissions

1. Slide Cross Position Reset:

    * Resets slide cross positions to a defined baseline (0.0)
    * Executes a sequence of PLC commands to perform homing

### Teardown Procedure

1. Log Collection:

    * Collects logs from specified directories in Adaptio OS
    * Stores logs in test-specific directories for debugging
    * Archives logs at the end of test sessions

1. Log Cleanup

    * Deletes existing logs before test execution
    * Ensures clean environment for accurate logging

1. Configuration Restoration

    * Restores original Adaptio configuration files from system defaults
    * Ensures test environment is returned to initial state

1. Connection Cleanup

    * Properly closes remote connections
    * Logs out from PLC interface

## TestRail Integration

### Overview

The TestRail ([testrail]) integration in this testing framework provides
automated test case
management, synchronization, and result reporting between the local test
environment and the TestRail cloud platform. This integration is designed to
maintain consistency between test implementations and TestRail test cases while
providing _decent_ test execution tracking.

To activate this feature for a test execution, `--testrail` must be used in the pytest command.

### Core Components

#### TestRailManager Class

The `TestRailManager` class serves as the primary interface for all TestRail
operations:

* **Client Management**: Handles authentication and API client initialization
* **Test Case Synchronization**: Manages bidirectional sync between local test
  definitions and TestRail
* **Test Run Management**: Creates and manages test runs automatically
* **Result Reporting**: Updates test execution results with detailed
  information

#### TestCase Class

The `TestCase` class provides comprehensive test case representation with
built-in TestRail functionality:

* **Metadata Extraction**: Automatically extracts test information from pytest
  items
* **TestRail Data Management**: Stores and manages TestRail-specific
  identifiers and metadata
* **Update Detection**: Intelligently detects when test cases need updates in
  TestRail
* **Field Mapping**: Maps pytest test attributes to TestRail custom fields

### Configuration

#### Environment Variables

The following environment variables must be configured to configure the
TestRail client:

* `TESTZILLA_TESTRAIL_API_KEY`: TestRail API key for authentication

At present the conditions to run TestRail integration require the following
environment variables:

* `CI`: Must be `true`
* `CI_COMMIT_REF_PROTECTED`: Must be `true`. Could be `main` or `release/*`
  branch that publishes HIL test results

#### Configuration Parameters

TestRail integration uses the following configuration parameters set in
`conftest.py`:

```python
config.TESTRAIL_URL = "https://esabgrnd.testrail.com"
config.TESTRAIL_USERNAME = "team-godzilla@esab.onmicrosoft.com"
config.TESTRAIL_PROJECT_ID = 34
config.TESTRAIL_SUITE_ID = 3767
config.TESTRAIL_SECTION_NAME = "HIL Tests"
config.TESTRAIL_MILESTONE_ID =  # Changes Frequently - Can be fetched
config.TEST_MANIFEST_FILENAME = "test-manifest.yaml"
```

### Test Manifest Integration

The system uses a `test-manifest.yaml` file to define test metadata that gets
synchronized with TestRail:

```yaml
kind: TestManifest
test_environment:
  type: 'container_registry'
  registry_path: 'esab/abw/infra-and-test/test-env'
  version: '1.0.2'
tests:
  source:
    type: 'git'
    repository: 'esab/abw/aws-tests'
    branch: 'main'
    commit: '4fc2d0ab4cc01eee02d25a02f3cf12364a936647'
  paths:
    - 'hil-tests'
```

### Automatic Test Case Synchronization

#### Sync Process

1. **Test Discovery**: The system automatically discovers all pytest test
   functions **for a given pytest session**
2. **TestRail Comparison**: Compares local test definitions with existing
   TestRail test cases
3. **Creation**: Creates new test cases in TestRail for tests that don't exist
4. **Update Detection**: Identifies test cases that need updates based on:
    * Test function docstrings
    * Test source code changes
    * Manifest data changes
    * Pytest markers and metadata
5. **Batch Updates**: Performs efficient batch updates to minimize API calls

#### TestRail Field Mapping

The integration maps pytest test attributes to TestRail fields:

* **Title**: Derived from test function name and docstring
* **Description**: Generated from test docstring and source code
* **Steps**: Extracted from test implementation
* **Priority**: Determined from pytest markers
* **Type**: Mapped from test categorization
* **Revision**: Tracks test case version for update detection

### Test Run Management

#### Automatic Test Run Creation

The system automatically creates TestRail test runs for each test session:

1. **Run Initialization**: Creates a new test run with timestamp-based and
   system manifest version naming
2. **Test Case Population**: Populates the run with all synchronized test cases
3. **Run ID Mapping**: Maps TestRail test IDs to local test cases for result
   reporting

#### Test Run Lifecycle

* **Session Start**: Creates test run and populates with test cases
* **Test Execution**: Updates individual test results in real-time
* **Session End**: Closes the test run and archives results

### Result Reporting

#### Automatic Result Updates

The `update_testrail_test_result` fixture automatically reports test results:

```python
@pytest.fixture(name="update_testrail_test_result", scope="function",
                autouse=True)
def update_testrail_test_result(request: pytest.FixtureRequest,
                                testrail: TestRailManager) -> Iterator[None]:
    # Test execution timing
    start_time = time.time()
    yield  # Test runs here
    elapsed_time = time.time() - start_time

    # Result mapping and reporting
    status_mapping = {
        'passed': 1,  # Passed
        'failed': 5,  # Failed
        'skipped': 2,  # Blocked
        'error': 5,  # Failed
        'xfail': 1,  # Passed (expected failure)
        'xpass': 5,  # Failed (unexpected pass)
    }
```

#### Result Information

Each test result includes:

* **Status**: Pass/Fail/Skip/Error status
* **Execution Time**: Precise timing in TestRail format
* **Comments**: Test execution details and failure information
* **Failure Details**: Complete error traces for failed tests

### Integration Workflow

#### Session-Level Operations

1. **Client Initialization**: Establishes TestRail API connection
2. **Test Case Sync**: Synchronizes all test cases before execution
3. **Test Run Creation**: Creates new test run for the session
4. **Result Collection**: Aggregates all test results
5. **Run Closure**: Closes test run and finalizes results

#### Test-Level Operations

1. **Test Case Mapping**: Maps pytest test to TestRail test case
2. **Execution Tracking**: Monitors test execution time
3. **Result Capture**: Captures test outcome and details
4. **Result Reporting**: Updates TestRail with execution results

### Best Practices for Test Framework Developers and Testers

#### Test Case Documentation

* **Clear Docstrings**: Use comprehensive docstrings for TestRail descriptions
* **Descriptive Names**: Use meaningful test function names
* **Proper Markers**: Use pytest markers for TestRail field mapping

#### Manifest Management

* **Version Control**: Keep test manifest under version control
* **Metadata Maintenance**: Maintain accurate test metadata
* **Regular Updates**: Update manifest when test requirements change

#### Error Handling

* **Graceful Degradation**: Ensure tests can run even if TestRail is
  unavailable
* **Clear Error Messages**: Provide helpful error messages for debugging
* **Logging**: Use appropriate logging levels for TestRail operations

#### Debug Information

The system provides debug information through `laserbeak` a loguru based logger

Logs can be found in `logs` directory created at in the working directory where
pytest is executed from.

### API Integration Details

#### Snitch API Client

The integration uses the `snitch.api_client.TestRailAPIClient` for TestRail
communication:

[Snitch library can be found by clicking on this very long blue sentence here!!](https://gitlab.com/esab/abw/infra-and-test/-/tree/main/container_files/snitch?ref_type=heads)

## Lint Python

Refer [Ruff: Python Linter and Formatter][lint-python]

## Lint Nix

Use `nixfmt` from this repository flake.

* **Check formatting (no changes):**

```bash
nix run .#nixfmt -- --check flake.nix
```

* **Check all `.nix` files in the repository (no changes):**

```bash
find . -type f -name '*.nix' -print0 | xargs -0 -r nix run .#nixfmt -- --check
```

* **Format files in place:**

```bash
find . -type f -name '*.nix' -print0 | xargs -0 -r nix run .#nixfmt --
```

[conftest]: hil-tests/conftest.py

[plc]: https://esabgrnd.jira.com/wiki/spaces/ADTI/pages/353665033/Using+JSON-RPC+for+communication+with+PLC

[psu]: https://esabgrnd.jira.com/wiki/spaces/ADTI/pages/320798722/Power+Supply+Unit+PSU

[adaptio-pc]: https://esabgrnd.jira.com/wiki/spaces/ADTI/pages/344457217/Adaptio-PC

[testrail]: https://esabgrnd.testrail.com/index.php?/suites/overview/34

[webhmi]: https://gitlab.com/esab/abw/adaptio/-/blob/a3e97d79095207afdae559d742b36dbecdbadc00/docs/WebHMI_Interface_Description.md

[testzilla]: https://gitlab.com/esab/abw/infra-and-test/-/tree/main/test/testzilla?ref_type=heads

[test-env]: https://gitlab.com/esab/abw/infra-and-test/container_registry/8036134

[aws-tests]: https://gitlab.com/esab/abw/aws-tests

[pytest]: https://docs.pytest.org/en/stable/contents.html

[use-pytest]: https://docs.pytest.org/en/stable/how-to/usage.html

[lint-python]: https://gitlab.com/esab/abw/infra-and-test#ruff-introduction

[git-message-format]: https://gitlab.com/esab/abw/infra-and-test#git-commit-message-format
