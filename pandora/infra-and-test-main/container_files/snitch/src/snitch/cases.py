"""Wraps TestRail Cases API in Python using a simple object-oriented interface."""
from typing import Dict, List, Optional, Union, Any
from snitch import logger
from snitch.api_client import TestRailAPIClient


class Cases:
    """Wrapper class for TestRail Cases API operations."""

    def __init__(self, api_client: TestRailAPIClient) -> None:
        """
        Initialize the TestRail Cases wrapper.

        Args:
            api_client (TestRailAPIClient): The API client instance
        """
        self.client = api_client
        logger.debug("Cases API wrapper initialized")

    def get_case(self, case_id: int) -> Dict:
        """
        Get details of a specific test case.

        Args:
            case_id (int): The ID of the test case

        Returns:
            dict: Test case details including id, title, section_id, etc.

        Raises:
            requests.exceptions.HTTPError: If case not found or no access
        """
        logger.debug(f"Getting test case with ID: {case_id}")
        endpoint = f"get_case/{case_id}"
        result = self.client.send_get(endpoint)
        logger.debug(f"Retrieved test case: {result.get('title', 'Unknown')}")
        return result

    def get_cases(self, project_id: int,
                  suite_id: Optional[int] = None,
                  created_after: Optional[int] = None,
                  created_before: Optional[int] = None,
                  created_by: Optional[Union[int, List[int]]] = None,
                  title_filter: Optional[str] = None,
                  limit: Optional[int] = None,
                  milestone_id: Optional[Union[int, List[int]]] = None,
                  offset: Optional[int] = None,
                  priority_id: Optional[Union[int, List[int]]] = None,
                  refs: Optional[str] = None,
                  section_id: Optional[int] = None,
                  template_id: Optional[Union[int, List[int]]] = None,
                  type_id: Optional[Union[int, List[int]]] = None,
                  updated_after: Optional[int] = None,
                  updated_before: Optional[int] = None,
                  updated_by: Optional[Union[int, List[int]]] = None) -> Dict:
        """
        Get list of test cases for a project or specific test suite.

        Args:
            project_id (int): The ID of the project
            suite_id (int, optional): The ID of the test suite
            created_after (int, optional): Only return cases created after this date (UNIX timestamp)
            created_before (int, optional): Only return cases created before this date (UNIX timestamp)
            created_by (int|list, optional): Creator user ID(s) to filter by
            title_filter (str, optional): Filter string to match in case title
            limit (int, optional): Number of test cases to return (default 250)
            milestone_id (int|list, optional): Milestone ID(s) to filter by
            offset (int, optional): Where to start counting from
            priority_id (int|list, optional): Priority ID(s) to filter by
            refs (str, optional): Single Reference ID to filter by
            section_id (int, optional): The ID of a test case section
            template_id (int|list, optional): Template ID(s) to filter by
            type_id (int|list, optional): Case type ID(s) to filter by
            updated_after (int, optional): Only return cases updated after this date (UNIX timestamp)
            updated_before (int, optional): Only return cases updated before this date (UNIX timestamp)
            updated_by (int|list, optional): User ID(s) who updated cases to filter by

        Returns:
            dict: Response containing cases list, offset, limit, and size
        """
        params = {}

        if suite_id is not None:
            params['suite_id'] = suite_id
        if created_after is not None:
            params['created_after'] = created_after
        if created_before is not None:
            params['created_before'] = created_before
        if created_by is not None:
            params['created_by'] = ','.join(map(str, created_by)) if isinstance(created_by, list) else created_by
        if title_filter is not None:
            params['filter'] = title_filter
        if limit is not None:
            params['limit'] = limit
        if milestone_id is not None:
            params['milestone_id'] = ','.join(map(str, milestone_id)) if isinstance(milestone_id, list) \
                else milestone_id
        if offset is not None:
            params['offset'] = offset
        if priority_id is not None:
            params['priority_id'] = ','.join(map(str, priority_id)) if isinstance(priority_id, list) \
                else priority_id
        if refs is not None:
            params['refs'] = refs
        if section_id is not None:
            params['section_id'] = section_id
        if template_id is not None:
            params['template_id'] = ','.join(map(str, template_id)) if isinstance(template_id, list) else template_id
        if type_id is not None:
            params['type_id'] = ','.join(map(str, type_id)) if isinstance(type_id, list) else type_id
        if updated_after is not None:
            params['updated_after'] = updated_after
        if updated_before is not None:
            params['updated_before'] = updated_before
        if updated_by is not None:
            params['updated_by'] = ','.join(map(str, updated_by)) if isinstance(updated_by, list) else updated_by

        logger.debug(f"Getting test cases for project {project_id} with params: {params}")
        endpoint = f"get_cases/{project_id}"
        result = self.client.send_get(endpoint, params=params)
        logger.debug(f"Retrieved {len(result.get('cases', []))} test cases")
        return result

    def get_history_for_case(self, case_id: int,
                             limit: Optional[int] = None,
                             offset: Optional[int] = None) -> Dict:
        """
        Get edit history for a test case.

        Args:
            case_id (int): The ID of the test case
            limit (int, optional): Number of changes to return (default 250)
            offset (int, optional): Where to start counting changes from

        Returns:
            dict: Response containing history array with change records
        """
        params = {}

        if limit is not None:
            params['limit'] = limit
        if offset is not None:
            params['offset'] = offset

        logger.debug(f"Getting history for test case {case_id}")
        endpoint = f"get_history_for_case/{case_id}"
        result = self.client.send_get(endpoint, params=params)
        logger.debug(f"Retrieved {len(result.get('history', []))} history records")
        return result

    def add_case(self, section_id: int,
                 title: str,
                 template_id: Optional[int] = None,
                 type_id: Optional[int] = None,
                 priority_id: Optional[int] = None,
                 estimate: Optional[str] = None,
                 milestone_id: Optional[int] = None,
                 refs: Optional[str] = None,
                 **custom_fields: Any) -> Dict:
        """
        Create a new test case.

        Args:
            section_id (int): The ID of the section to add the case to
            title (str): The title of the test case
            template_id (int, optional): The ID of the template (field layout)
            type_id (int, optional): The ID of the case type
            priority_id (int, optional): The ID of the case priority
            estimate (str, optional): The estimate, e.g. "30s" or "1m 45s"
            milestone_id (int, optional): The ID of the milestone to link
            refs (str, optional): Comma-separated list of references/requirements
            **custom_fields (Any): Custom field values (prefixed with 'custom_')

        Returns:
            dict: The created test case details

        Raises:
            requests.exceptions.HTTPError: If section not found or no access
        """
        data = {"title": title}

        if template_id is not None:
            data["template_id"] = template_id
        if type_id is not None:
            data["type_id"] = type_id
        if priority_id is not None:
            data["priority_id"] = priority_id
        if estimate is not None:
            data["estimate"] = estimate
        if milestone_id is not None:
            data["milestone_id"] = milestone_id
        if refs is not None:
            data["refs"] = refs

        # Add custom fields
        data.update(custom_fields)

        logger.debug(f"Creating new test case: {title} in section {section_id}")
        endpoint = f"add_case/{section_id}"
        result = self.client.send_post(endpoint, data=data)
        logger.debug(f"Test case created successfully with ID: {result.get('id')}")
        return result

    def copy_cases_to_section(self, section_id: int,
                              case_ids: List[int]) -> None:
        """
        Copy test cases to another section.

        Args:
            section_id (int): The ID of the section to copy cases to
            case_ids (list): List of case IDs to copy

        Raises:
            requests.exceptions.HTTPError: If section not found or no access
        """
        data = {"case_ids": case_ids}

        logger.debug(f"Copying {len(case_ids)} test cases to section {section_id}")
        endpoint = f"copy_cases_to_section/{section_id}"
        self.client.send_post(endpoint, data=data)
        logger.debug(f"Successfully copied {len(case_ids)} test cases to section {section_id}")

    def update_case(self, case_id: int,
                    section_id: Optional[int] = None,
                    title: Optional[str] = None,
                    template_id: Optional[int] = None,
                    type_id: Optional[int] = None,
                    priority_id: Optional[int] = None,
                    estimate: Optional[str] = None,
                    milestone_id: Optional[int] = None,
                    refs: Optional[str] = None,
                    **custom_fields: Any) -> Dict:
        """
        Update an existing test case.

        Args:
            case_id (int): The ID of the test case to update
            section_id (int, optional): The ID of the section to move case to
            title (str, optional): The title of the test case
            template_id (int, optional): The ID of the template (field layout)
            type_id (int, optional): The ID of the case type
            priority_id (int, optional): The ID of the case priority
            estimate (str, optional): The estimate, e.g. "30s" or "1m 45s"
            milestone_id (int, optional): The ID of the milestone to link
            refs (str, optional): Comma-separated list of references/requirements
            **custom_fields (Any): Custom field values (prefixed with 'custom_')

        Returns:
            dict: The updated test case details

        Raises:
            requests.exceptions.HTTPError: If case not found or no access
        """
        data = {}

        if section_id is not None:
            data["section_id"] = section_id
        if title is not None:
            data["title"] = title
        if template_id is not None:
            data["template_id"] = template_id
        if type_id is not None:
            data["type_id"] = type_id
        if priority_id is not None:
            data["priority_id"] = priority_id
        if estimate is not None:
            data["estimate"] = estimate
        if milestone_id is not None:
            data["milestone_id"] = milestone_id
        if refs is not None:
            data["refs"] = refs

        # Add custom fields
        data.update(custom_fields)

        logger.debug(f"Updating test case with ID: {case_id}")
        endpoint = f"update_case/{case_id}"
        result = self.client.send_post(endpoint, data=data)
        logger.debug(f"Test case {case_id} updated successfully")
        return result

    def update_cases(self, suite_id: int,
                     case_ids: List[int],
                     section_id: Optional[int] = None,
                     title: Optional[str] = None,
                     template_id: Optional[int] = None,
                     type_id: Optional[int] = None,
                     priority_id: Optional[int] = None,
                     estimate: Optional[str] = None,
                     milestone_id: Optional[int] = None,
                     refs: Optional[str] = None,
                     **custom_fields: Any) -> Dict:
        """
        Update multiple test cases with the same values.

        Args:
            suite_id (int): The ID of the test suite
            case_ids (list): List of case IDs to update
            section_id (int, optional): The ID of the section to move cases to
            title (str, optional): The title of the test cases
            template_id (int, optional): The ID of the template (field layout)
            type_id (int, optional): The ID of the case type
            priority_id (int, optional): The ID of the case priority
            estimate (str, optional): The estimate, e.g. "30s" or "1m 45s"
            milestone_id (int, optional): The ID of the milestone to link
            refs (str, optional): Comma-separated list of references/requirements
            **custom_fields (Any): Custom field values (prefixed with 'custom_')

        Returns:
            dict: The updated test cases details

        Raises:
            requests.exceptions.HTTPError: If suite not found or no access
        """
        data = {"case_ids": case_ids}

        if section_id is not None:
            data["section_id"] = section_id
        if title is not None:
            data["title"] = title
        if template_id is not None:
            data["template_id"] = template_id
        if type_id is not None:
            data["type_id"] = type_id
        if priority_id is not None:
            data["priority_id"] = priority_id
        if estimate is not None:
            data["estimate"] = estimate
        if milestone_id is not None:
            data["milestone_id"] = milestone_id
        if refs is not None:
            data["refs"] = refs

        # Add custom fields
        data.update(custom_fields)

        logger.debug(f"Updating {len(case_ids)} test cases in suite {suite_id}")
        endpoint = f"update_cases/{suite_id}"
        result = self.client.send_post(endpoint, data=data)
        logger.debug(f"Successfully updated {len(case_ids)} test cases")
        return result

    def move_cases_to_section(self, section_id: int,
                              suite_id: int,
                              case_ids: List[int]) -> None:
        """
        Move test cases to another suite or section.

        Args:
            section_id (int): The ID of the section to move cases to
            suite_id (int): The ID of the suite to move cases to
            case_ids (list): List of case IDs to move

        Raises:
            requests.exceptions.HTTPError: If section/suite not found or no access
        """
        data = {
            "suite_id": suite_id,
            "case_ids": case_ids
        }

        logger.debug(f"Moving {len(case_ids)} test cases to section {section_id}, suite {suite_id}")
        endpoint = f"move_cases_to_section/{section_id}"
        self.client.send_post(endpoint, data=data)
        logger.debug(f"Successfully moved {len(case_ids)} test cases to section {section_id}")

    def delete_case(self, case_id: int, soft: Optional[int] = None) -> Optional[Dict]:
        """
        Delete an existing test case.

        WARNING: This permanently deletes the test case and all test results
                in active test runs.

        Args:
            case_id (int): The ID of the test case to delete
            soft (int, optional): If 1, returns deletion info without deleting

        Returns:
            dict: Deletion info if soft=1, None otherwise

        Raises:
            requests.exceptions.HTTPError: If case not found or no access
        """
        data = {}
        if soft is not None:
            data["soft"] = soft

        if soft == 1:
            logger.debug(f"Getting deletion info for test case {case_id}")
        else:
            logger.warning(f"Deleting test case with ID: {case_id} - this will permanently delete all data")

        endpoint = f"delete_case/{case_id}"
        result = self.client.send_post(endpoint, data=data if data else None)

        if soft == 1:
            logger.debug(f"Retrieved deletion info for test case {case_id}")
            return result
        else:
            logger.debug(f"Test case {case_id} deleted successfully")
            return None

    def delete_cases(self, project_id: int,
                     case_ids: List[int],
                     suite_id: Optional[int] = None,
                     soft: Optional[int] = None) -> Optional[Dict]:
        """
        Delete multiple test cases from a project or test suite.

        WARNING: This permanently deletes test cases and all test results
                in active test runs.

        Args:
            project_id (int): The ID of the project
            case_ids (list): List of case IDs to delete
            suite_id (int, optional): The ID of the suite (required for multi-suite projects)
            soft (int, optional): If 1, returns deletion info without deleting

        Returns:
            dict: Deletion info if soft=1, None otherwise

        Raises:
            requests.exceptions.HTTPError: If project/suite not found or no access
        """
        data = {"case_ids": case_ids}
        params = {}

        if soft is not None:
            params["soft"] = soft

        if soft == 1:
            logger.debug(f"Getting deletion info for {len(case_ids)} test cases in project {project_id}")
        else:
            logger.warning(f"Deleting {len(case_ids)} test cases from project {project_id} - "
                           f"this will permanently delete all data")

        if suite_id is not None:
            endpoint = f"delete_cases/{suite_id}"
        else:
            endpoint = "delete_cases"
            params["project_id"] = project_id

        result = self.client.send_post(endpoint, data=data)

        if soft == 1:
            logger.debug(f"Retrieved deletion info for {len(case_ids)} test cases")
            return result
        else:
            logger.debug(f"Successfully deleted {len(case_ids)} test cases")
            return None
