"""Managers for conftest.py."""

import os
import shlex
import time
from datetime import datetime
from pathlib import Path
from typing import Any, Callable, Dict, List, Optional, Union

import pytest
import yaml
from base_test_case import TestCase
from conftest import logger
from testzilla.utility.cleanup_utils import cleanup_web_hmi_client
from invoke.exceptions import Failure
from snitch.api_client import TestRailAPIClient
from snitch.cases import Cases
from snitch.results import Results
from snitch.runs import Runs
from snitch.sections import Sections
from testzilla.adaptio_web_hmi.adaptio_web_hmi import AdaptioWebHmi
from testzilla.remote_comm.remote_host import RemoteHostManager


def parse_test_manifest(request: pytest.FixtureRequest,
                        manifest_path: Optional[Union[str, Path]] = None) -> Dict[str, Any]:
    """Parse test manifest YAML file and return the raw data."""
    if manifest_path is None:
        possible_paths = [
            Path.cwd().parent / request.config.TEST_MANIFEST_FILENAME,
            Path(os.getenv('CI_PROJECT_DIR', '.')) / request.config.TEST_MANIFEST_FILENAME,
        ]

        manifest_path = None
        for path in possible_paths:
            if path.exists():
                manifest_path = path
                break

        if manifest_path is None:
            logger.warning(f"Test manifest file not found in any of: {[str(p) for p in possible_paths]}")
            return {}
    else:
        manifest_path = Path(manifest_path)

    if not manifest_path.exists():
        logger.warning(f"Test manifest file not found at {manifest_path}")
        return {}

    try:
        with open(manifest_path, 'r', encoding='utf-8') as file:
            manifest_data = yaml.safe_load(file) or {}

        logger.debug(f"Successfully parsed test manifest from {manifest_path}")
        return manifest_data

    except yaml.YAMLError as e:
        logger.error(f"Failed to parse YAML file {manifest_path}: {e}")
        return {}


def requires_client(func: Callable) -> Callable:
    """Decorator to ensure the TestRail client is initialized."""
    def wrapper(self, *args, **kwargs) -> Any:
        if not self.client:
            logger.debug(f"TestRail client is not initialized. Skipping {func.__name__}.")
            return None
        return func(self, *args, **kwargs)
    return wrapper


class TestRailManager:
    """Class that handles communication with TestRail"""

    def __init__(self, request: pytest.FixtureRequest) -> None:
        """Initialize the TestRailManager with the given request."""
        self.request = request
        self.client = None
        self.url = request.config.TESTRAIL_URL
        self.username = request.config.TESTRAIL_USERNAME
        self.api_key = request.config.TESTRAIL_API_KEY
        self.project_id = request.config.TESTRAIL_PROJECT_ID
        self.test_manifest_data = parse_test_manifest(request)
        self.test_cases = []
        self.test_run = None

    def initialize_client(self) -> None:
        """Initialize the client"""
        # Environment variables below are pre-defined in GitLab jobs!
        if os.getenv("CI") != "true":
            logger.warning("Tests are not being run in CI. Skipping Testrail client setup.")
            return
        if os.getenv("CI_COMMIT_REF_PROTECTED") != "true":
            logger.warning("Tests are not being run on a protected ref. Skipping Testrail client setup.")
            return
        self.client = TestRailAPIClient(
            base_url=self.url,
            username=self.username,
            api_key=self.api_key
        )

    @requires_client
    def create_test_run(self, name: Optional[str] = None, description: Optional[str] = None) \
            -> Optional[Dict[str, Any]]:
        """Create a new test run in TestRail."""
        runs_client = Runs(self.client)

        system_version = None
        if self.test_manifest_data:
            system_manifest = self.test_manifest_data.get('system_manifest', {})
            system_source = system_manifest.get('source', {})
            system_version = system_source.get('version')

        # Generate description with manifest info FOR THE RUN
        if not description:
            description = "Automated test execution"
            if system_version:
                description += f"\nSystem Version: {system_version}"
            
            # Add system manifest details to RUN description
            if self.test_manifest_data:
                system_manifest = self.test_manifest_data.get('system_manifest', {})
                system_source = system_manifest.get('source', {})
                if system_source:
                    description += f"\nSystem Repository: {system_source.get('repository', 'N/A')}"
                    description += f"\nSystem Branch: {system_source.get('branch', 'N/A')}"
                    description += f"\nSystem Manifest Path: {system_manifest.get('path', 'N/A')}"

            if os.getenv("CI"):
                description += "\n\nTest executed in GitLab environment"
                description += f"\nJob URL: {os.getenv('CI_JOB_URL')}"
                description += f"\nPipeline URL: {os.getenv('CI_PIPELINE_URL')}"
                description += f"\nPipeline ID: {os.getenv('CI_PIPELINE_ID')}"
                description += f"\nJob ID: {os.getenv('CI_JOB_ID')}"
                description += f"\nCommit SHA: {os.getenv('CI_COMMIT_SHA')}"
                description += f"\nCommit Reference: {os.getenv('CI_COMMIT_REF_NAME')}"
                description += f"\nCommit Message: {os.getenv('CI_COMMIT_MESSAGE')}"
                description += f"\nCommit Author: {os.getenv('CI_COMMIT_AUTHOR')}"


        if not name:
            timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            name = f"Automated HIL Test Run - {timestamp}"
            if system_version:
                name += f" - {system_version}"

        # Get case IDs for the run
        case_ids = []
        for test_case in self.test_cases:
            if test_case.exists_in_testrail:
                case_ids.append(test_case.testrail_case_id)

        if not case_ids:
            logger.warning("No test cases found with TestRail references. Cannot create test run.")
            return None

        try:
            run_data = {
                'suite_id': self.request.config.TESTRAIL_SUITE_ID,
                'name': name,
                'milestone_id': self.request.config.TESTRAIL_MILESTONE_ID,
                'description': description,
                'case_ids': case_ids,
                'refs': system_version,
                'include_all': False
            }

            logger.info(f"Creating test run: {name}")
            logger.debug(f"Test run data: {run_data}")

            self.test_run = runs_client.add_run(self.project_id, **run_data)
            logger.info(f"Created test run ID: {self.test_run['id']}")
            logger.warning(f"Test run {self.test_run['name']} created. URL: {self.test_run['url']}")
        
            # Populate test IDs in TestCase objects
            self._populate_test_case_run_ids()
        
            return self.test_run

        except Exception as e:
            logger.error(f"Failed to create test run: {e}")
            return None

    @requires_client
    def _populate_test_case_run_ids(self) -> None:
        """Populate test run IDs in TestCase objects."""
        if not self.test_run:
            return

        try:
            test_cases_to_run = self.client.send_get(f"get_tests/{self.test_run['id']}")

            for test in test_cases_to_run.get('tests', []):
                case_id = test['case_id']
                test_id = test['id']

                # Find the matching TestCase and set the run test ID
                for test_case in self.test_cases:
                    if test_case.testrail_case_id == case_id:
                        test_case.set_testrail_test_id(test_id)
                        logger.debug(f"Set run test ID {test_id} for case {test_case.name}")
                        break

        except Exception as e:
            logger.error(f"Failed to populate test case run IDs: {e}")

    @requires_client
    def update_test_result(self, test_case: TestCase, status_id: int,
                           comment: Optional[str] = None, elapsed: Optional[str] = None) -> None:
        """Update test result in the current test run."""
        if not self.test_run:
            logger.warning("No test run created. Cannot update test result.")
            return

        if not test_case.has_testrail_test_id():
            logger.warning(f"Test case {test_case.name} has no run test ID. Cannot update result.")
            return

        results_client = Results(self.client)
        test_id = test_case.testrail_test_id

        try:
            result_data = {
                'status_id': status_id,
                'comment': comment or f"Test executed: {test_case.name}",
            }

            if elapsed:
                result_data['elapsed'] = elapsed

            logger.info(f"Updating test result for {test_case.name} (Test ID: {test_id}) with status {status_id}")
            results_client.add_result(test_id, **result_data)
            logger.debug(f"Successfully updated test result for {test_case.name}")

        except Exception as e:
            logger.error(f"Failed to update test result for {test_case.name}: {e}")



    def _create_test_cases(self) -> None:
        """Create TestCase objects from pytest session items."""
        logger.debug("Creating TestCase objects from pytest session")

        for item in self.request.session.items:
            test_case = TestCase.from_pytest_item(item, self.test_manifest_data)
            self.test_cases.append(test_case)

            # Store reference on the pytest item for later access
            item.test_case = test_case


    def _populate_existing_testrail_data(self) -> None:
        """Map test cases between pytest session and testrail suite cases."""
        cases_client = Cases(self.client)

        # Hardcoded the test filter because we don't run tests that are not prefixed with 'test_'
        current_tcs = cases_client.get_cases(self.project_id,
                                             suite_id=self.request.config.TESTRAIL_SUITE_ID ,
                                             title_filter="test_")

        existing_cases_lookup = {}
        for case in current_tcs.get('cases', []):
            case_title = case.get('title', '').lower()
            existing_cases_lookup[case_title] = case
        logger.debug(f"Existing test cases: {existing_cases_lookup}")

        for test_case in self.test_cases:
            test_name_lower = test_case.name.lower()

            if test_name_lower in existing_cases_lookup:
                testrail_data = existing_cases_lookup[test_name_lower]
                test_case.set_testrail_data(testrail_data)
                logger.debug(f"Found exact match for {test_case.name}: case {testrail_data['id']}")

    def _create_missing_test_cases_in_testrail(self) -> None:
        """Create missing Test Cases in TestRail"""
        missing_tcs = [test_case for test_case in self.test_cases if test_case.needs_creation]

        if not missing_tcs:
            logger.debug("All test cases already exist in TestRail, no creation needed.")
            return

        cases_client = Cases(self.client)
        sections_client = Sections(self.client)

        response = sections_client.get_sections(self.project_id, suite_id=self.request.config.TESTRAIL_SUITE_ID)
        logger.debug(f"Creating {len(missing_tcs)} missing test cases in TestRail")

        section_id = None
        for test_case in missing_tcs:
            logger.debug(f"Creating test case {test_case.name} with fields: {test_case.testrail_fields}")
            for section in response['sections']:
                if section['name'].lower() == self.request.config.TESTRAIL_SECTION_NAME.lower():
                    section_id = section['id']
                    break
            logger.info(f"Creating test case {test_case.name} in TestRail in section {section_id}")
            add_response = cases_client.add_case(section_id=section_id, **test_case.testrail_fields)
            test_case.set_testrail_data(add_response)
            logger.info(f"Created Test Case {test_case.name} ID={add_response['id']} with "
                        f"revision={test_case.testrail_revision}")

    def _update_test_case_revisions(self) -> None:
        """Update test case revisions if they have changed."""
        cases_needing_revision_update = [
            test_case for test_case in self.test_cases 
            if test_case.exists_in_testrail and test_case.needs_revision_update()
        ]
    
        if not cases_needing_revision_update:
            logger.debug("No test cases need revision updates.")
            return
        
        cases_client = Cases(self.client)
        logger.info(f"Updating revisions for {len(cases_needing_revision_update)} test cases")
        
        for test_case in cases_needing_revision_update:
            try:
                update_data = {'custom_tcrevision': test_case.testrail_revision}
                logger.info(f"Updating revision for {test_case.name} to {test_case.testrail_revision}")
                cases_client.update_case(test_case.testrail_case_id, **update_data)
            
                # Update our local data
                test_case.testrail_case_data['custom_tcrevision'] = test_case.testrail_revision
                logger.debug(f"Successfully updated revision for {test_case.name}")
            
            except Exception as e:
                logger.error(f"Failed to update revision for {test_case.name}: {e}")

    def _update_test_cases_from_manifest_and_pytest(self) -> None:
        """Update test cases with manifest data ALWAYS and pytest changes when detected."""
        if not self.test_cases:
            logger.debug("No test cases to update.")
            return
        
        cases_needing_manifest_updates = []
        cases_needing_pytest_updates = []
        
        # Categorize what needs updating
        for test_case in self.test_cases:
            if not test_case.exists_in_testrail:
                continue
                
            # Always check for manifest updates
            if test_case.needs_update_from_manifest():
                cases_needing_manifest_updates.append(test_case)
                
            # Check for pytest info changes  
            if test_case.needs_update_from_pytest_changes():
                cases_needing_pytest_updates.append(test_case)
        
        # Update manifest data for all cases that need it
        if cases_needing_manifest_updates:
            logger.info(f"Updating manifest data for {len(cases_needing_manifest_updates)} test cases")
            self._batch_update_test_cases(cases_needing_manifest_updates, update_type="manifest")
        
        # Update pytest changes for cases that need it
        if cases_needing_pytest_updates:
            logger.info(f"Updating pytest changes for {len(cases_needing_pytest_updates)} test cases")
            self._batch_update_test_cases(cases_needing_pytest_updates, update_type="pytest")
        
        # Cases that need both (overlap)
        cases_needing_both = [tc for tc in cases_needing_manifest_updates if tc in cases_needing_pytest_updates]
        if cases_needing_both:
            logger.info(f"Updating comprehensive changes for {len(cases_needing_both)} test cases")
            self._batch_update_test_cases(cases_needing_both, update_type="comprehensive")

    def _batch_update_test_cases(self, test_cases: List[TestCase], update_type: str = "comprehensive") -> None:
        """Batch update test cases with specified update type."""
        cases_client = Cases(self.client)
        
        for test_case in test_cases:
            try:
                # Get the appropriate update fields based on type
                if update_type == "manifest":
                    update_fields = test_case.get_update_fields_manifest_only()
                elif update_type == "pytest":
                    update_fields = test_case.get_update_fields_pytest_changes()
                else:  # comprehensive
                    update_fields = test_case.get_update_fields_comprehensive()
                
                # Never update title to avoid losing manual TestRail edits
                update_fields.pop('title', None)
                
                logger.info(f"Updating test case {test_case.name} "
                            f"(ID: {test_case.testrail_case_id}) - {update_type} update")
                logger.debug(f"Update fields: {list(update_fields.keys())}")
                
                cases_client.update_case(test_case.testrail_case_id, **update_fields)
                
                # Update our local cache with the new data
                test_case.testrail_case_data.update(update_fields)
                
                logger.debug(f"Successfully updated test case {test_case.name}")
                
            except Exception as e:
                logger.error(f"Failed to update test case {test_case.name}: {e}")

    @requires_client
    def sync_test_cases(self) -> None:
        """Sync test cases between pytest session and TestRail"""
        if not self.client:
            logger.debug("TestRail client is not initialized. Skipping syncing Test cases.")
            return

        # Creating TestCase objects from a pytest session
        self._create_test_cases()

        # Populating existing data from testrail
        self._populate_existing_testrail_data()

        # Creating test cases in testrail
        self._create_missing_test_cases_in_testrail()
        
        # Update existing test cases with manifest data ALWAYS and pytest changes when detected
        self._update_test_cases_from_manifest_and_pytest()

    @requires_client
    def close_test_run(self) -> None:
        """Close the current test run in TestRail."""
        if not self.test_run:
            logger.warning("No test run to close.")
            return

        runs_client = Runs(self.client)
        
        try:
            logger.info(f"Closing test run ID: {self.test_run['id']}")
            runs_client.close_run(self.test_run['id'])
            logger.info(f"Successfully closed test run ID: {self.test_run['id']}")
            logger.warning(f"Test run URL: {self.test_run['url']}")
            
            # Clear the test run reference
            self.test_run = None
            
        except Exception as e:
            logger.error(f"Failed to close test run: {e}")


    def _debug_testrail_configuration(self) -> None:
        """Debug TestRail configuration to see available options."""
        if not self.client:
            return

        try:
            # Get available priorities
            priorities_response = self.client.send_get("get_priorities")
            logger.debug(f"Available priorities: {priorities_response}")

            # Get available case types
            types_response = self.client.send_get("get_case_types")
            logger.debug(f"Available case types: {types_response}")

        except Exception as e:
            logger.error(f"Failed to debug TestRail configuration: {e}")




class AdaptioManager:
    """Wrapper class for RemoteHostManager with additional methods."""

    def __init__(self, request: pytest.FixtureRequest) -> None:
        self.request = request
        self.manager = RemoteHostManager(
            hostname=request.config.ADAPTIO_EXTERNAL_IP,
            username=request.config.ADAPTIO_USERNAME,
            password=request.config.ADAPTIO_PASSWORD,
        )
        self.web_hmi = AdaptioWebHmi(uri=request.config.WEB_HMI_URI)
        self._local_config_files = []

    def set_adaptio_log_level(self, level: str) -> None:
        """Set Adaptio log level"""
        response = None
        try:
            # Ensure fresh connection before sending
            try:
                cleanup_web_hmi_client(self.web_hmi)
            except Exception:
                pass
            self.web_hmi = AdaptioWebHmi(uri=self.request.config.WEB_HMI_URI)
            
            response = self.web_hmi.send_and_receive_message(
                condition=None, request_name="SetLogLevel", response_name="SetLogLevelRsp", payload={"logLevel": level}
            )
            logger.debug(f"Received response: {response}")
            result = getattr(response, "result", None) or response.payload.get("result")
            if response and result == "ok":
                logger.info(f"Successfully set Adaptio log level to {level}")
            else:
                logger.info(f"Failed to set Adaptio log level to {level}")
        except Exception as e:
            logger.warning(f"Failed to set Adaptio log level to {level}: {e}")

    def start_adaptio(self, set_trace_log_level: bool = True) -> None:
        """Start Adaptio service."""
        logger.info("Starting Adaptio service")
        self.manager.execute_command(command="systemctl start adaptio.service", sudo=True)
        logger.info("Adaptio service started")

        # Wait for PLC <-> Adaptio connection to be established
        time.sleep(self.request.config.ADAPTIO_RESTART_WAIT_TIME)
        if set_trace_log_level:
            self.set_adaptio_log_level(level="trace")
            logger.info("Log Level is set to trace for Adaptio service")

    def stop_adaptio(self) -> None:
        """Stop Adaptio service"""
        logger.info("Stopping Adaptio service")
        self.manager.execute_command(command="systemctl stop adaptio.service", sudo=True)
        logger.info("Adaptio service stopped")

    def restart_adaptio(self) -> None:
        """Restart Adaptio service."""
        logger.info("Restarting Adaptio service")
        self.manager.execute_command(command="systemctl restart adaptio.service", sudo=True)
        logger.info("Adaptio service restarted")

        # Wait for PLC <-> Adaptio connection to be established
        time.sleep(self.request.config.ADAPTIO_RESTART_WAIT_TIME)
        try:
            self.set_adaptio_log_level(level="trace")
        except Exception as e:
            logger.warning(f"Could not set Adaptio log level after restart: {e}")

    def replace_config_files(self, local_path: Path) -> None:
        """Copy config files directly to ADAPTIO_USER_CONFIG_PATH on the Adaptio PC."""
        self.stop_adaptio()

        usr_cfg_path = self.request.config.ADAPTIO_USER_CONFIG_PATH

        # remember filenames so restore_config_files can clean them up
        self._local_config_files = [p.name for p in local_path.iterdir() if p.is_file()]

        logger.info(f"Copying configuration files to {usr_cfg_path}")
        self.manager.copy_dir_content_to_remote(
            local_path=local_path,
            remote_path=usr_cfg_path,
            sudo=True,
        )
        logger.info(f"Configuration files copied to {usr_cfg_path}")

        self.start_adaptio()

    def restore_config_files(self, local_default_path: Optional[Path] = None) -> None:
        """Restore config files for Adaptio.

        Dispatches to helper methods based on presence of a local default path.
        """
        self.stop_adaptio()

        # ensure user config cleanup always happens
        self._cleanup_user_config()

        if local_default_path:
            self._copy_default_config(local_default_path)
        else:
            self._restore_system_config()

        logger.info("Configuration files restored")
        self.start_adaptio(set_trace_log_level=False)

    def _cleanup_user_config(self) -> None:
        """Delete config files, images and databases from user config path."""
        usr_cfg_path = self.request.config.ADAPTIO_USER_CONFIG_PATH
        config_files = self._local_config_files + [self.request.config.ADAPTIO_DB]

        logger.info(f"Cleaning up user config directory {usr_cfg_path}")
        for filename in config_files:
            usr_file = usr_cfg_path / filename
            logger.info(f"Deleting {usr_file}")
            self._run_sudo_command(f"rm -f {shlex.quote(str(usr_file))}", f"delete {filename}")

    def _restore_system_config(self) -> None:
        """Copy YAML files from system config to user config path."""
        sys_cfg_path = self.request.config.ADAPTIO_SYSTEM_CONFIG_PATH
        usr_cfg_path = self.request.config.ADAPTIO_USER_CONFIG_PATH

        logger.info(f"Restoring system configuration from {sys_cfg_path} to {usr_cfg_path}")
        # copy each yaml file that was previously present
        for filename in self._local_config_files:
            if filename.endswith(".yaml"):
                src_file = sys_cfg_path / filename
                logger.info(f"Copying {src_file} to {usr_cfg_path}")
                self._run_sudo_command(
                    f"cp {shlex.quote(str(src_file))} {shlex.quote(str(usr_cfg_path))}", f"copy {filename}"
                )

    def _copy_default_config(self, local_default_path: Path) -> None:
        """Copy default config from a local path to user config."""
        usr_cfg_path = self.request.config.ADAPTIO_USER_CONFIG_PATH
        logger.info(f"Copying default config from {local_default_path} to {usr_cfg_path}")
        self.manager.copy_dir_content_to_remote(
            local_path=local_default_path,
            remote_path=usr_cfg_path,
            sudo=True,
        )

    def _run_sudo_command(self, command: str, action: str) -> None:
        _, stderr, exit_code = self.manager.execute_command(command=command, sudo=True)
        if exit_code != 0:
            logger.warning(f"Failed to {action}: {stderr}")

    def get_adaptio_system_time(self) -> Optional[datetime]:
        """Retrieve the current system time from Adaptio OS."""
        try:
            # Execute 'date +%s' on Adaptio to get Unix timestamp
            stdout, stderr, exit_code = self.manager.execute_command(command="date +%s", sudo=False)
            
            if exit_code != 0:
                logger.warning(f"Failed to retrieve Adaptio system time: {stderr}")
                return None
            
            timestamp = int(stdout.strip())
            adaptio_time = datetime.fromtimestamp(timestamp)
            logger.debug(f"Retrieved Adaptio system time: {adaptio_time.isoformat()}")
            return adaptio_time
            
        except (ValueError, Failure) as e:
            logger.warning(f"Problem retrieving Adaptio system time: {e}")
            return None

    def capture_test_start_time(self) -> None:
        """Capture the test start time from Adaptio OS for selective log collection."""
        # Get Adaptio system time directly (no fallback to SSH/local time)
        adaptio_time = self.get_adaptio_system_time()
        
        if adaptio_time is not None:
            self._test_start_time = adaptio_time
            logger.info(f"Captured Adaptio system time as test start time: {self._test_start_time.isoformat()}")
        else:
            logger.error("Failed to retrieve Adaptio system time. Test start time cannot be determined.")

    def delete_logs(self) -> None:
        """Clean logs from Adaptio os."""
        logger.info("Remove SUT logs from adaptio os")
        try:
            for sut_log in self.request.config.ADAPTIO_SUT_LOG_PATHS:
                self.manager.execute_command(command=f"find {sut_log.as_posix()} -mindepth 1 -delete", sudo=True)
            logger.info("Done removing logs from Adaptio OS")
            # Capture the time right after log deletion
            self.capture_test_start_time()
        except Failure:
            logger.exception("Problem executing command to remove logs from Adaptio OS")

    def collect_logs(self) -> None:
        """Collect all logs from adaptio os, then delete old ones locally.
        
        Fetches entire log directory, then removes files older than test start time.
        Always keeps ADAPTIO.log.
        """
        logger.info("Start log collection from Adaptio OS")
        
        # If test start time was not captured, use fallback
        if self._test_start_time is None:
            logger.warning("Test start time not captured. Collecting all logs (fallback mode)")
            self._collect_all_logs()
            return
        
        try:
            local_path = (
                self.request.config.SUT_LOGS_ROOT_LOCAL_PATH
                / Path(self.request.module.__name__)
                / Path(self.request.node.name)
            )
            
            start_timestamp = int(self._test_start_time.timestamp())
            logger.info(f"Test start time: {self._test_start_time.isoformat()} (timestamp: {start_timestamp})")
            
            self.manager.fetch_directory_from_remote(
                local_path=local_path,
                remote_paths=self.request.config.ADAPTIO_SUT_LOG_PATHS,
                timeout=self.request.config.COLLECT_SUT_LOGS_TIMEOUT,
            )
                       
            # Step 2: Delete old log files locally
            self._cleanup_old_logs_locally(local_path, start_timestamp)
           
        except Failure:
            logger.exception("Problem collecting logs from Adaptio OS")
    
    def _cleanup_old_logs_locally(self, local_path: Path, start_timestamp: int) -> None:
        """Delete log files older than start_timestamp, but keep ADAPTIO.log.
        
        Args:
            local_path: Local path where logs were fetched
            start_timestamp: Unix timestamp of test start time
        """
        if not local_path.exists():
            logger.warning(f"Local log path does not exist: {local_path}")
            return
                
        deleted_count = 0
        kept_count = 0
        
        # Walk through all files in the fetched logs
        for root, dirs, files in os.walk(local_path):
            for filename in files:
                file_path = Path(root) / filename
                
                # Always keep ADAPTIO.log
                if filename == "ADAPTIO.log":
                    kept_count += 1
                    continue
                
                # Check file modification time
                try:
                    file_mtime = int(file_path.stat().st_mtime)
                    
                    # Keep files modified at or after test start time
                    if file_mtime >= start_timestamp:
                        kept_count += 1
                    else:
                        # Delete old files
                        file_path.unlink()
                        deleted_count += 1
                                              
                except (OSError, ValueError) as e:
                    logger.warning(f"Could not process file {file_path}: {e}")
                    
    def _collect_all_logs(self) -> None:
        """Fallback: Collect entire log directory (used when start time not captured)."""
        try:
            local_path = (
                self.request.config.SUT_LOGS_ROOT_LOCAL_PATH
                / Path(self.request.module.__name__)
                / Path(self.request.node.name)
            )
            
            self.manager.fetch_directory_from_remote(
                local_path=local_path,
                remote_paths=self.request.config.ADAPTIO_SUT_LOG_PATHS,
                timeout=self.request.config.COLLECT_SUT_LOGS_TIMEOUT,
            )
        except Failure:
            logger.exception("Problem collecting logs from Adaptio OS")

    def close(self) -> None:
        """Ensure the connection is closed properly."""
        if hasattr(self, "web_hmi") and self.web_hmi is not None:
            cleanup_web_hmi_client(self.web_hmi)
        logger.info("Closing remote connection to Adaptio OS")
        self.manager.close_connection()
