"""Wraps TestRail Results API in Python using a simple object-oriented interface."""
from typing import Dict, List, Optional, Union, Any
from snitch import logger
from snitch.api_client import TestRailAPIClient


class Results:
    """Wrapper class for TestRail Results API operations."""

    def __init__(self, api_client: TestRailAPIClient) -> None:
        """
        Initialize the TestRail Results wrapper.

        Args:
            api_client (TestRailAPIClient): The API client instance
        """
        self.client = api_client
        logger.debug("Results API wrapper initialized")

    def get_results(self, test_id: int,
                    limit: Optional[int] = None,
                    offset: Optional[int] = None,
                    defects_filter: Optional[str] = None,
                    status_id: Optional[Union[int, List[int]]] = None) -> Dict:
        """
        Get list of test results for a test.

        Args:
            test_id (int): The ID of the test
            limit (int, optional): Number of results to return (default 250)
            offset (int, optional): Where to start counting results from
            defects_filter (str, optional): Single Defect ID to filter by
            status_id (int or list, optional): Status ID(s) to filter by

        Returns:
            dict: Response containing results list, offset, limit, and size
        """
        params = {}

        if limit is not None:
            params['limit'] = limit
        if offset is not None:
            params['offset'] = offset
        if defects_filter is not None:
            params['defects_filter'] = defects_filter
        if status_id is not None:
            if isinstance(status_id, list):
                params['status_id'] = ','.join(map(str, status_id))
            else:
                params['status_id'] = status_id

        logger.debug(f"Getting results for test {test_id} with params: {params}")
        endpoint = f"get_results/{test_id}"
        result = self.client.send_get(endpoint, params=params)
        logger.debug(f"Retrieved {len(result.get('results', []))} results")
        return result

    def get_results_for_case(self, run_id: int, case_id: int,
                             limit: Optional[int] = None,
                             offset: Optional[int] = None,
                             defects_filter: Optional[str] = None,
                             status_id: Optional[Union[int, List[int]]] = None) -> Dict:
        """
        Get list of test results for a test run and case combination.

        Args:
            run_id (int): The ID of the test run
            case_id (int): The ID of the test case
            limit (int, optional): Number of results to return (default 250)
            offset (int, optional): Where to start counting results from
            defects_filter (str, optional): Single Defect ID to filter by
            status_id (int or list, optional): Status ID(s) to filter by

        Returns:
            dict: Response containing results list, offset, limit, and size
        """
        params = {}

        if limit is not None:
            params['limit'] = limit
        if offset is not None:
            params['offset'] = offset
        if defects_filter is not None:
            params['defects_filter'] = defects_filter
        if status_id is not None:
            if isinstance(status_id, list):
                params['status_id'] = ','.join(map(str, status_id))
            else:
                params['status_id'] = status_id

        logger.debug(f"Getting results for run {run_id} and case {case_id} with params: {params}")
        endpoint = f"get_results_for_case/{run_id}/{case_id}"
        result = self.client.send_get(endpoint, params=params)
        logger.debug(f"Retrieved {len(result.get('results', []))} results")
        return result

    def get_results_for_run(self, run_id: int,
                            created_after: Optional[int] = None,
                            created_before: Optional[int] = None,
                            created_by: Optional[Union[int, List[int]]] = None,
                            defects_filter: Optional[str] = None,
                            limit: Optional[int] = None,
                            offset: Optional[int] = None,
                            status_id: Optional[Union[int, List[int]]] = None) -> Dict:
        """
        Get list of test results for a test run.

        Args:
            run_id (int): The ID of the test run
            created_after (int, optional): Only return results created after this date (UNIX timestamp)
            created_before (int, optional): Only return results created before this date (UNIX timestamp)
            created_by (int or list, optional): Creator user ID(s) to filter by
            defects_filter (str, optional): Single Defect ID to filter by
            limit (int, optional): Number of results to return (default 250)
            offset (int, optional): Where to start counting results from
            status_id (int or list, optional): Status ID(s) to filter by

        Returns:
            dict: Response containing results list, offset, limit, and size
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
        if defects_filter is not None:
            params['defects_filter'] = defects_filter
        if limit is not None:
            params['limit'] = limit
        if offset is not None:
            params['offset'] = offset
        if status_id is not None:
            if isinstance(status_id, list):
                params['status_id'] = ','.join(map(str, status_id))
            else:
                params['status_id'] = status_id

        logger.debug(f"Getting results for run {run_id} with params: {params}")
        endpoint = f"get_results_for_run/{run_id}"
        result = self.client.send_get(endpoint, params=params)
        logger.debug(f"Retrieved {len(result.get('results', []))} results")
        return result

    def add_result(self, test_id: int,
                   status_id: Optional[int] = None,
                   comment: Optional[str] = None,
                   version: Optional[str] = None,
                   elapsed: Optional[str] = None,
                   defects: Optional[str] = None,
                   assignedto_id: Optional[int] = None,
                   **custom_fields: Any) -> Dict:
        """
        Add a new test result, comment or assign a test.

        Args:
            test_id (int): The ID of the test the result should be added to
            status_id (int, optional): The ID of the test status (1=Passed, 2=Blocked, 4=Retest, 5=Failed)
            comment (str, optional): The comment/description for the test result
            version (str, optional): The version or build you tested against
            elapsed (str, optional): The time it took to execute the test (e.g. "30s" or "1m 45s")
            defects (str, optional): Comma-separated list of defects to link to the test result
            assignedto_id (int, optional): The ID of a user the test should be assigned to
            **custom_fields (Any): Custom fields prefixed with custom_ (e.g. custom_comment="value")

        Returns:
            dict: The created test result details

        Raises:
            requests.exceptions.HTTPError: If no permissions or invalid test
        """
        data = {}

        if status_id is not None:
            data["status_id"] = status_id
        if comment is not None:
            data["comment"] = comment
        if version is not None:
            data["version"] = version
        if elapsed is not None:
            data["elapsed"] = elapsed
        if defects is not None:
            data["defects"] = defects
        if assignedto_id is not None:
            data["assignedto_id"] = assignedto_id

        # Add custom fields
        data.update(custom_fields)

        logger.debug(f"Adding result for test {test_id}")
        endpoint = f"add_result/{test_id}"
        result = self.client.send_post(endpoint, data=data)
        logger.debug(f"Result added successfully with ID: {result.get('id')}")
        return result

    def add_result_for_case(self, run_id: int, case_id: int,
                            status_id: Optional[int] = None,
                            comment: Optional[str] = None,
                            version: Optional[str] = None,
                            elapsed: Optional[str] = None,
                            defects: Optional[str] = None,
                            assignedto_id: Optional[int] = None,
                            **custom_fields: Any) -> Dict:
        """
        Add a new test result for a test run and case combination.

        Args:
            run_id (int): The ID of the test run
            case_id (int): The ID of the test case
            status_id (int, optional): The ID of the test status (1=Passed, 2=Blocked, 4=Retest, 5=Failed)
            comment (str, optional): The comment/description for the test result
            version (str, optional): The version or build you tested against
            elapsed (str, optional): The time it took to execute the test (e.g. "30s" or "1m 45s")
            defects (str, optional): Comma-separated list of defects to link to the test result
            assignedto_id (int, optional): The ID of a user the test should be assigned to
            **custom_fields (Any): Custom fields prefixed with custom_ (e.g. custom_comment="value")

        Returns:
            dict: The created test result details

        Raises:
            requests.exceptions.HTTPError: If no permissions or invalid run/case
        """
        data = {}

        if status_id is not None:
            data["status_id"] = status_id
        if comment is not None:
            data["comment"] = comment
        if version is not None:
            data["version"] = version
        if elapsed is not None:
            data["elapsed"] = elapsed
        if defects is not None:
            data["defects"] = defects
        if assignedto_id is not None:
            data["assignedto_id"] = assignedto_id

        # Add custom fields
        data.update(custom_fields)

        logger.debug(f"Adding result for run {run_id} and case {case_id}")
        endpoint = f"add_result_for_case/{run_id}/{case_id}"
        result = self.client.send_post(endpoint, data=data)
        logger.debug(f"Result added successfully with ID: {result.get('id')}")
        return result

    def add_results(self, run_id: int, results: List[Dict]) -> List[Dict]:
        """
        Add one or more new test results, comments, or assign one or more tests.

        Args:
            run_id (int): The ID of the test run the results should be added to
            results (list): List of result dictionaries, each containing test_id and result fields

        Returns:
            list: List of created test result details

        Raises:
            requests.exceptions.HTTPError: If no permissions or invalid run/tests
        """
        data = {"results": results}

        logger.debug(f"Adding {len(results)} results for run {run_id}")
        endpoint = f"add_results/{run_id}"
        result = self.client.send_post(endpoint, data=data)
        logger.debug(f"Added {len(results)} results successfully")
        return result

    def add_results_for_cases(self, run_id: int, results: List[Dict]) -> List[Dict]:
        """
        Add one or more new test results using case IDs.

        Args:
            run_id (int): The ID of the test run the results should be added to
            results (list): List of result dictionaries, each containing case_id and result fields

        Returns:
            list: List of created test result details

        Raises:
            requests.exceptions.HTTPError: If no permissions or invalid run/cases
        """
        data = {"results": results}

        logger.debug(f"Adding {len(results)} results for cases in run {run_id}")
        endpoint = f"add_results_for_cases/{run_id}"
        result = self.client.send_post(endpoint, data=data)
        logger.debug(f"Added {len(results)} results for cases successfully")
        return result

    def get_results_by_status(self, test_id: int, status_ids: List[int],
                              limit: Optional[int] = None) -> Dict:
        """
        Convenience method to get results filtered by specific status IDs.

        Args:
            test_id (int): The ID of the test
            status_ids (list): List of status IDs to filter by
            limit (int, optional): Number of results to return

        Returns:
            dict: Response containing filtered results
        """
        logger.debug(f"Getting results for test {test_id} with status IDs: {status_ids}")
        result = self.get_results(test_id, status_id=status_ids, limit=limit)
        logger.debug(f"Retrieved {len(result.get('results', []))} results with specified statuses")
        return result

    def get_failed_results(self, test_id: int, limit: Optional[int] = None) -> Dict:
        """
        Convenience method to get only failed test results.

        Args:
            test_id (int): The ID of the test
            limit (int, optional): Number of results to return

        Returns:
            dict: Response containing failed results
        """
        logger.debug(f"Getting failed results for test {test_id}")
        return self.get_results_by_status(test_id, [5], limit=limit)  # 5 = Failed

    def get_passed_results(self, test_id: int, limit: Optional[int] = None) -> Dict:
        """
        Convenience method to get only passed test results.

        Args:
            test_id (int): The ID of the test
            limit (int, optional): Number of results to return

        Returns:
            dict: Response containing passed results
        """
        logger.debug(f"Getting passed results for test {test_id}")
        return self.get_results_by_status(test_id, [1], limit=limit)  # 1 = Passed
