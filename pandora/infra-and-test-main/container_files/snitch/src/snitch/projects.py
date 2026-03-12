"""Wraps TestRail Projects API in Python using a simple object-oriented interface."""
from typing import Dict, Optional
from snitch import logger
from snitch.api_client import TestRailAPIClient


class Projects:
    """Wrapper class for TestRail Projects API operations."""

    def __init__(self, api_client: TestRailAPIClient) -> None:
        """
        Initialize the TestRail Projects wrapper.

        Args:
            api_client (TestRailAPIClient): The API client instance
        """
        self.client = api_client
        logger.debug("Projects API wrapper initialized")

    def get_project(self, project_id: int) -> Dict:
        """
        Get details of a specific project.

        Args:
            project_id (int): The ID of the project

        Returns:
            dict: Project details including id, name, announcement, etc.

        Raises:
            requests.exceptions.HTTPError: If project not found or no access
        """
        logger.debug(f"Getting project with ID: {project_id}")
        endpoint = f"get_project/{project_id}"
        result = self.client.send_get(endpoint)
        logger.debug(f"Retrieved project: {result.get('name', 'Unknown')}")
        return result

    def get_projects(self, is_completed: Optional[bool] = None,
                     limit: Optional[int] = None,
                     offset: Optional[int] = None) -> Dict:
        """
        Get list of available projects.

        Args:
            is_completed (bool, optional): True for completed projects only,
                                         False for active projects only
            limit (int, optional): Number of projects to return (default 250)
            offset (int, optional): Where to start counting projects from

        Returns:
            dict: Response containing projects list, offset, limit, and size
        """
        params = {}

        if is_completed is not None:
            params['is_completed'] = 1 if is_completed else 0
        if limit is not None:
            params['limit'] = limit
        if offset is not None:
            params['offset'] = offset

        logger.debug(f"Getting projects with params: {params}")
        result = self.client.send_get("get_projects", params=params)
        logger.debug(f"Retrieved {len(result.get('projects', []))} projects")
        return result

    def add_project(self, name: str,
                    announcement: Optional[str] = None,
                    show_announcement: Optional[bool] = None,
                    suite_mode: Optional[int] = None) -> Dict:
        """
        Create a new project (requires admin status).

        Args:
            name (str): The name of the project
            announcement (str, optional): The description/announcement of the project
            show_announcement (bool, optional): Whether to display announcement on overview page
            suite_mode (int, optional): Suite mode (1=single suite, 2=single suite + baselines,
                                       3=multiple suites)

        Returns:
            dict: The created project details

        Raises:
            requests.exceptions.HTTPError: If no admin permissions
        """
        data = {"name": name}

        if announcement is not None:
            data["announcement"] = announcement
        if show_announcement is not None:
            data["show_announcement"] = show_announcement
        if suite_mode is not None:
            data["suite_mode"] = suite_mode

        logger.debug(f"Creating new project: {name}")
        result = self.client.send_post("add_project", data=data)
        logger.debug(f"Project created successfully with ID: {result.get('id')}")
        return result

    def update_project(self, project_id: int,
                       name: Optional[str] = None,
                       announcement: Optional[str] = None,
                       show_announcement: Optional[bool] = None,
                       suite_mode: Optional[int] = None) -> Dict:
        """
        Update an existing project (requires admin status).

        Args:
            project_id (int): The ID of the project to update
            name (str, optional): The name of the project
            announcement (str, optional): The description/announcement of the project
            show_announcement (bool, optional): Whether to display announcement on overview page
            suite_mode (int, optional): Suite mode (1=single suite, 2=single suite + baselines,
                                       3=multiple suites)

        Returns:
            dict: The updated project details

        Raises:
            requests.exceptions.HTTPError: If project not found or no admin permissions
        """
        data = {}

        if name is not None:
            data["name"] = name
        if announcement is not None:
            data["announcement"] = announcement
        if show_announcement is not None:
            data["show_announcement"] = show_announcement
        if suite_mode is not None:
            data["suite_mode"] = suite_mode

        logger.debug(f"Updating project with ID: {project_id}")
        endpoint = f"update_project/{project_id}"
        result = self.client.send_post(endpoint, data=data)
        logger.debug(f"Project {project_id} updated successfully")
        return result

    def delete_project(self, project_id: int) -> None:
        """
        Delete an existing project (requires admin status).

        WARNING: This permanently deletes all test suites, cases, runs,
                results, and everything else in the project.

        Args:
            project_id (int): The ID of the project to delete

        Raises:
            requests.exceptions.HTTPError: If project not found or no admin permissions
        """
        logger.warning(f"Deleting project with ID: {project_id} - this will permanently delete all data")
        endpoint = f"delete_project/{project_id}"
        self.client.send_post(endpoint)
        logger.debug(f"Project {project_id} deleted successfully")

    def get_active_projects(self, limit: Optional[int] = None,
                            offset: Optional[int] = None) -> Dict:
        """
        Convenience method to get only active projects.

        Args:
            limit (int, optional): Number of projects to return
            offset (int, optional): Where to start counting projects from

        Returns:
            dict: Response containing active projects list
        """
        logger.debug("Getting active projects")
        result = self.get_projects(is_completed=False, limit=limit, offset=offset)
        logger.debug(f"Retrieved {len(result.get('projects', []))} active projects")
        return result

    def get_completed_projects(self, limit: Optional[int] = None,
                               offset: Optional[int] = None) -> Dict:
        """
        Convenience method to get only completed projects.

        Args:
            limit (int, optional): Number of projects to return
            offset (int, optional): Where to start counting projects from

        Returns:
            dict: Response containing completed projects list
        """
        logger.debug("Getting completed projects")
        result = self.get_projects(is_completed=True, limit=limit, offset=offset)
        logger.debug(f"Retrieved {len(result.get('projects', []))} completed projects")
        return result
