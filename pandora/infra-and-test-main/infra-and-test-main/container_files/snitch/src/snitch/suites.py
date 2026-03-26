"""Wraps TestRail Suites API in Python using a simple object-oriented interface."""
from typing import Dict, List, Optional
from snitch import logger
from snitch.api_client import TestRailAPIClient


class Suites:
    """Wrapper class for TestRail Suites API operations."""

    def __init__(self, api_client: TestRailAPIClient) -> None:
        """
        Initialize the TestRail Suites wrapper.

        Args:
            api_client (TestRailAPIClient): The API client instance
        """
        self.client = api_client
        logger.debug("Suites API wrapper initialized")

    def get_suite(self, suite_id: int) -> Dict:
        """
        Get details of a specific test suite.

        Args:
            suite_id (int): The ID of the test suite

        Returns:
            dict: Test suite details including id, name, description, etc.

        Raises:
            requests.exceptions.HTTPError: If suite not found or no access
        """
        logger.debug(f"Getting test suite with ID: {suite_id}")
        endpoint = f"get_suite/{suite_id}"
        result = self.client.send_get(endpoint)
        logger.debug(f"Retrieved test suite: {result.get('name', 'Unknown')}")
        return result

    def get_suites(self, project_id: int) -> List[Dict]:
        """
        Get list of test suites for a project.

        Args:
            project_id (int): The ID of the project

        Returns:
            list: List of test suites for the project

        Raises:
            requests.exceptions.HTTPError: If project not found or no access
        """
        logger.debug(f"Getting test suites for project {project_id}")
        endpoint = f"get_suites/{project_id}"
        result = self.client.send_get(endpoint)
        logger.debug(f"Retrieved {len(result)} test suites")
        return result

    def add_suite(self, project_id: int,
                  name: str,
                  description: Optional[str] = None) -> Dict:
        """
        Create a new test suite.

        Args:
            project_id (int): The ID of the project to add the suite to
            name (str): The name of the test suite
            description (str, optional): The description of the test suite

        Returns:
            dict: The created test suite details

        Raises:
            requests.exceptions.HTTPError: If project not found or no permissions
        """
        data = {"name": name}

        if description is not None:
            data["description"] = description

        logger.debug(f"Creating new test suite: {name} in project {project_id}")
        endpoint = f"add_suite/{project_id}"
        result = self.client.send_post(endpoint, data=data)
        logger.debug(f"Test suite created successfully with ID: {result.get('id')}")
        return result

    def update_suite(self, suite_id: int,
                     name: Optional[str] = None,
                     description: Optional[str] = None) -> Dict:
        """
        Update an existing test suite.

        Args:
            suite_id (int): The ID of the test suite to update
            name (str, optional): The name of the test suite
            description (str, optional): The description of the test suite

        Returns:
            dict: The updated test suite details

        Raises:
            requests.exceptions.HTTPError: If suite not found or no permissions
        """
        data = {}

        if name is not None:
            data["name"] = name
        if description is not None:
            data["description"] = description

        logger.debug(f"Updating test suite with ID: {suite_id}")
        endpoint = f"update_suite/{suite_id}"
        result = self.client.send_post(endpoint, data=data)
        logger.debug(f"Test suite {suite_id} updated successfully")
        return result

    def delete_suite(self, suite_id: int, soft: Optional[int] = None) -> Optional[Dict]:
        """
        Delete an existing test suite.

        WARNING: This permanently deletes the test suite and all active test runs
                and results that weren't closed (archived) yet.

        Args:
            suite_id (int): The ID of the test suite to delete
            soft (int, optional): If 1, returns deletion info without deleting

        Returns:
            dict: Deletion info if soft=1, None otherwise

        Raises:
            requests.exceptions.HTTPError: If suite not found or no permissions
        """
        data = {}
        if soft is not None:
            data["soft"] = soft

        if soft == 1:
            logger.debug(f"Getting deletion info for test suite {suite_id}")
        else:
            logger.warning(f"Deleting test suite with ID: {suite_id} - this will permanently delete all data")

        endpoint = f"delete_suite/{suite_id}"
        result = self.client.send_post(endpoint, data=data if data else None)

        if soft == 1:
            logger.debug(f"Retrieved deletion info for test suite {suite_id}")
            return result
        else:
            logger.debug(f"Test suite {suite_id} deleted successfully")
            return None
