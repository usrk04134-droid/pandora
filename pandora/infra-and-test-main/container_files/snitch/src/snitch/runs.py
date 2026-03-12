"""Wraps TestRail Runs API in Python using a simple object-oriented interface."""
from typing import Dict, List, Optional, Union
from snitch import logger
from snitch.api_client import TestRailAPIClient


class Runs:
    """Wrapper class for TestRail Runs API operations."""

    def __init__(self, api_client: TestRailAPIClient) -> None:
        """
        Initialize the TestRail Runs wrapper.

        Args:
            api_client (TestRailAPIClient): The API client instance
        """
        self.client = api_client
        logger.debug("Runs API wrapper initialized")

    def get_run(self, run_id: int) -> Dict:
        """
        Get details of a specific test run.

        Args:
            run_id (int): The ID of the test run

        Returns:
            dict: Test run details including id, name, status counts, etc.

        Raises:
            requests.exceptions.HTTPError: If run not found or no access
        """
        logger.debug(f"Getting run with ID: {run_id}")
        endpoint = f"get_run/{run_id}"
        result = self.client.send_get(endpoint)
        logger.debug(f"Retrieved run: {result.get('name', 'Unknown')}")
        return result

    def get_runs(self, project_id: int,
                 created_after: Optional[int] = None,
                 created_before: Optional[int] = None,
                 created_by: Optional[Union[int, List[int]]] = None,
                 is_completed: Optional[bool] = None,
                 limit: Optional[int] = None,
                 offset: Optional[int] = None,
                 milestone_id: Optional[Union[int, List[int]]] = None,
                 refs_filter: Optional[str] = None,
                 suite_id: Optional[Union[int, List[int]]] = None) -> Dict:
        """
        Get list of test runs for a project.

        Args:
            project_id (int): The ID of the project
            created_after (int, optional): Only return runs created after this date (UNIX timestamp)
            created_before (int, optional): Only return runs created before this date (UNIX timestamp)
            created_by (int or list, optional): Creator user ID(s) to filter by
            is_completed (bool, optional): True for completed runs only, False for active runs only
            limit (int, optional): Number of runs to return (default 250)
            offset (int, optional): Where to start counting runs from
            milestone_id (int or list, optional): Milestone ID(s) to filter by
            refs_filter (str, optional): Single Reference ID to filter by
            suite_id (int or list, optional): Test suite ID(s) to filter by

        Returns:
            dict: Response containing runs list, offset, limit, and size
        """
        params = {}

        if created_after is not None:
            params['created_after'] = created_after
        if created_before is not None:
            params['created_before'] = created_before
        if created_by is not None:
            if isinstance(created_by, list):
                params['created_by'] = ','.join(map(str, created_by))
            else:
                params['created_by'] = created_by
        if is_completed is not None:
            params['is_completed'] = 1 if is_completed else 0
        if limit is not None:
            params['limit'] = limit
        if offset is not None:
            params['offset'] = offset
        if milestone_id is not None:
            if isinstance(milestone_id, list):
                params['milestone_id'] = ','.join(map(str, milestone_id))
            else:
                params['milestone_id'] = milestone_id
        if refs_filter is not None:
            params['refs_filter'] = refs_filter
        if suite_id is not None:
            if isinstance(suite_id, list):
                params['suite_id'] = ','.join(map(str, suite_id))
            else:
                params['suite_id'] = suite_id

        logger.debug(f"Getting runs for project {project_id} with params: {params}")
        endpoint = f"get_runs/{project_id}"
        result = self.client.send_get(endpoint, params=params)
        logger.debug(f"Retrieved {len(result.get('runs', []))} runs")
        return result

    def add_run(self, project_id: int,
                name: str,
                suite_id: Optional[int] = None,
                description: Optional[str] = None,
                milestone_id: Optional[int] = None,
                assignedto_id: Optional[int] = None,
                include_all: Optional[bool] = None,
                case_ids: Optional[List[int]] = None,
                refs: Optional[str] = None) -> Dict:
        """
        Create a new test run.

        Args:
            project_id (int): The ID of the project
            name (str): The name of the test run
            suite_id (int, optional): The ID of the test suite (required for multi-suite projects)
            description (str, optional): The description of the test run
            milestone_id (int, optional): The ID of the milestone to link to
            assignedto_id (int, optional): The ID of the user to assign the run to
            include_all (bool, optional): True to include all test cases, False for custom selection
            case_ids (list, optional): Array of case IDs for custom case selection
            refs (str, optional): Comma-separated list of references/requirements

        Returns:
            dict: The created test run details

        Raises:
            requests.exceptions.HTTPError: If no permissions or invalid project
        """
        data = {"name": name}

        if suite_id is not None:
            data["suite_id"] = suite_id
        if description is not None:
            data["description"] = description
        if milestone_id is not None:
            data["milestone_id"] = milestone_id
        if assignedto_id is not None:
            data["assignedto_id"] = assignedto_id
        if include_all is not None:
            data["include_all"] = include_all
        if case_ids is not None:
            data["case_ids"] = case_ids
        if refs is not None:
            data["refs"] = refs

        logger.debug(f"Creating new run: {name} for project {project_id}")
        endpoint = f"add_run/{project_id}"
        result = self.client.send_post(endpoint, data=data)
        logger.debug(f"Run created successfully with ID: {result.get('id')}")
        return result

    def update_run(self, run_id: int,
                   name: Optional[str] = None,
                   description: Optional[str] = None,
                   milestone_id: Optional[int] = None,
                   include_all: Optional[bool] = None,
                   case_ids: Optional[List[int]] = None,
                   refs: Optional[str] = None) -> Dict:
        """
        Update an existing test run.

        Args:
            run_id (int): The ID of the test run to update
            name (str, optional): The name of the test run
            description (str, optional): The description of the test run
            milestone_id (int, optional): The ID of the milestone to link to
            include_all (bool, optional): True to include all test cases, False for custom selection
            case_ids (list, optional): Array of case IDs for custom case selection
            refs (str, optional): Comma-separated list of references/requirements

        Returns:
            dict: The updated test run details

        Raises:
            requests.exceptions.HTTPError: If run not found or no permissions
        """
        data = {}

        if name is not None:
            data["name"] = name
        if description is not None:
            data["description"] = description
        if milestone_id is not None:
            data["milestone_id"] = milestone_id
        if include_all is not None:
            data["include_all"] = include_all
        if case_ids is not None:
            data["case_ids"] = case_ids
        if refs is not None:
            data["refs"] = refs

        logger.debug(f"Updating run with ID: {run_id}")
        endpoint = f"update_run/{run_id}"
        result = self.client.send_post(endpoint, data=data)
        logger.debug(f"Run {run_id} updated successfully")
        return result

    def close_run(self, run_id: int) -> Dict:
        """
        Close an existing test run and archive its tests & results.

        WARNING: Closing a test run cannot be undone.

        Args:
            run_id (int): The ID of the test run to close

        Returns:
            dict: The closed test run details

        Raises:
            requests.exceptions.HTTPError: If run not found or no permissions
        """
        logger.warning(f"Closing run with ID: {run_id} - this cannot be undone")
        endpoint = f"close_run/{run_id}"
        result = self.client.send_post(endpoint)
        logger.debug(f"Run {run_id} closed successfully")
        return result

    def delete_run(self, run_id: int, soft: Optional[int] = None) -> Optional[Dict]:
        """
        Delete an existing test run.

        WARNING: Deleting a test run cannot be undone and permanently deletes
                all tests & results of the test run.

        Args:
            run_id (int): The ID of the test run to delete
            soft (int, optional): If 1, returns data on affected tests without deleting.
                                 If 0 or omitted, actually deletes the run.

        Returns:
            dict or None: If soft=1, returns data on affected tests. Otherwise None.

        Raises:
            requests.exceptions.HTTPError: If run not found or no permissions
        """
        params = {}
        if soft is not None:
            params['soft'] = soft

        if soft == 1:
            logger.debug(f"Getting deletion preview for run with ID: {run_id}")
        else:
            logger.warning(f"Deleting run with ID: {run_id} - this will permanently delete all data")

        endpoint = f"delete_run/{run_id}"
        result = self.client.send_post(endpoint, data=params if params else None)

        if soft == 1:
            logger.debug(f"Retrieved deletion preview for run {run_id}")
            return result
        else:
            logger.debug(f"Run {run_id} deleted successfully")
            return None

    def get_active_runs(self, project_id: int,
                        limit: Optional[int] = None,
                        offset: Optional[int] = None) -> Dict:
        """
        Convenience method to get only active test runs.

        Args:
            project_id (int): The ID of the project
            limit (int, optional): Number of runs to return
            offset (int, optional): Where to start counting runs from

        Returns:
            dict: Response containing active runs list
        """
        logger.debug(f"Getting active runs for project {project_id}")
        result = self.get_runs(project_id, is_completed=False, limit=limit, offset=offset)
        logger.debug(f"Retrieved {len(result.get('runs', []))} active runs")
        return result

    def get_completed_runs(self, project_id: int,
                           limit: Optional[int] = None,
                           offset: Optional[int] = None) -> Dict:
        """
        Convenience method to get only completed test runs.

        Args:
            project_id (int): The ID of the project
            limit (int, optional): Number of runs to return
            offset (int, optional): Where to start counting runs from

        Returns:
            dict: Response containing completed runs list
        """
        logger.debug(f"Getting completed runs for project {project_id}")
        result = self.get_runs(project_id, is_completed=True, limit=limit, offset=offset)
        logger.debug(f"Retrieved {len(result.get('runs', []))} completed runs")
        return result
