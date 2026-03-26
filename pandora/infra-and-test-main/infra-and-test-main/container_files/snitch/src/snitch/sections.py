"""Wraps TestRail Sections API in Python using a simple object-oriented interface."""
from typing import Dict, Optional
from snitch import logger
from snitch.api_client import TestRailAPIClient


class Sections:
    """Wrapper class for TestRail Sections API operations."""

    def __init__(self, api_client: TestRailAPIClient) -> None:
        """Initialize the TestRail Sections wrapper.

        Args:
            api_client: The TestRail API client instance
        """
        self.client = api_client
        logger.debug("Sections API wrapper initialized")

    def get_section(self, section_id: int) -> Dict:
        """Get details of a specific section.

        Args:
            section_id: The ID of the section

        Returns:
            Dict containing section details
        """
        logger.debug(f"Getting section with ID: {section_id}")
        endpoint = f"get_section/{section_id}"
        result = self.client.send_get(endpoint)
        logger.debug(f"Retrieved section: {result.get('name', 'Unknown')}")
        return result

    def get_sections(self, project_id: int,
                     suite_id: Optional[int] = None,
                     limit: Optional[int] = None,
                     offset: Optional[int] = None) -> Dict:
        """Get list of sections for a project and test suite."""
        params = {}

        if suite_id is not None:
            params['suite_id'] = suite_id
        if limit is not None:
            params['limit'] = limit
        if offset is not None:
            params['offset'] = offset

        logger.debug(f"Getting sections for project {project_id} with params: {params}")
        endpoint = f"get_sections/{project_id}"
        result = self.client.send_get(endpoint, params=params)

        # Extract sections from the response if it's wrapped
        if isinstance(result, dict) and 'sections' in result:
            sections_count = len(result['sections'])
        else:
            sections_count = len(result) if isinstance(result, list) else 0

        logger.debug(f"Retrieved {sections_count} sections")
        return result

    def add_section(self, project_id: int,
                    name: str,
                    suite_id: Optional[int] = None,
                    description: Optional[str] = None,
                    parent_id: Optional[int] = None) -> Dict:
        """Create a new section.

        Args:
            project_id: The ID of the project
            name: The name of the new section
            suite_id: Optional ID of the test suite
            description: Optional description for the section
            parent_id: Optional ID of the parent section

        Returns:
            Dict containing the created section data
        """
        data = {"name": name}

        if suite_id is not None:
            data['suite_id'] = suite_id
        if description is not None:
            data['description'] = description
        if parent_id is not None:
            data['parent_id'] = parent_id

        logger.debug(f"Creating new section '{name}' in project {project_id}")
        endpoint = f"add_section/{project_id}"
        result = self.client.send_post(endpoint, data=data)
        logger.debug(f"Section created successfully with ID: {result.get('id')}")
        return result

    def update_section(self, section_id: int, name: Optional[str] = None, description: Optional[str] = None) -> Dict:
        """Update an existing section.

        Args:
            section_id: The ID of the section to update
            name: Optional new name for the section
            description: Optional new description for the section

        Returns:
            Dict containing the updated section data
        """
        data = {}

        if name is not None:
            data['name'] = name
        if description is not None:
            data['description'] = description

        logger.debug(f"Updating section with ID: {section_id}")
        endpoint = f"update_section/{section_id}"
        result = self.client.send_post(endpoint, data=data)
        logger.debug(f"Section {section_id} updated successfully")
        return result

    def move_section(self, section_id: int, parent_id: Optional[int] = None, after_id: Optional[int] = None) -> Dict:
        """Move a section to another parent or reorder it.

        Args:
            section_id: The ID of the section to move
            parent_id: Optional ID of the new parent section
            after_id: Optional ID of the section after which to place this section

        Returns:
            Dict containing the moved section data
        """
        data = {}

        if parent_id is not None:
            data['parent_id'] = parent_id
        if after_id is not None:
            data['after_id'] = after_id

        logger.debug(f"Moving section {section_id} to parent {parent_id} after {after_id}")
        endpoint = f"move_section/{section_id}"
        result = self.client.send_post(endpoint, data=data)
        logger.debug(f"Section {section_id} moved successfully")
        return result

    def delete_section(self, section_id: int, soft: Optional[int] = None) -> Optional[Dict]:
        """Delete an existing section.

        Args:
            section_id: The ID of the section to delete
            soft: Optional flag (1) to get deletion info without deleting

        Returns:
            Dict containing deletion info if soft=1, None otherwise
        """
        data = {}
        if soft is not None:
            data['soft'] = soft

        if soft == 1:
            logger.debug(f"Getting deletion info for section {section_id}")
        else:
            logger.warning(f"Deleting section with ID: {section_id} - this will permanently delete all data")

        endpoint = f"delete_section/{section_id}"
        result = self.client.send_post(endpoint, data=data if data else None)

        if soft == 1:
            logger.debug(f"Retrieved deletion info for section {section_id}")
            return result
        else:
            logger.debug(f"Section {section_id} deleted successfully")
            return None
