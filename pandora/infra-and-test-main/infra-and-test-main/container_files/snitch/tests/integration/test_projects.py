"""Integration tests for TestRail Projects wrapper."""
import pytest


class TestProjects:
    """Test the Projects wrapper functionality."""

    def test_get_projects_all(self, projects_client):
        """Test getting all projects."""
        response = projects_client.get_projects()

        assert isinstance(response, dict)
        assert 'projects' in response
        assert isinstance(response['projects'], list)
        assert response['size'] >= 0

    def test_get_active_projects(self, projects_client):
        """Test getting only active projects."""
        response = projects_client.get_active_projects()

        assert isinstance(response, dict)
        assert 'projects' in response

        # Verify all returned projects are active
        for project in response['projects']:
            assert project['is_completed'] is False

    def test_get_completed_projects(self, projects_client):
        """Test getting only completed projects."""
        response = projects_client.get_completed_projects()

        assert isinstance(response, dict)
        assert 'projects' in response

        # Verify all returned projects are completed
        for project in response['projects']:
            assert project['is_completed'] is True

    def test_get_projects_with_limit(self, projects_client):
        """Test getting projects with limit parameter."""
        limit = 5
        response = projects_client.get_projects(limit=limit)

        assert response['limit'] == limit
        assert len(response['projects']) <= limit

    def test_get_projects_with_offset(self, projects_client):
        """Test getting projects with offset parameter."""
        offset = 1
        response = projects_client.get_projects(offset=offset)

        assert response['offset'] == offset

    def test_get_specific_project(self, projects_client, sandbox_project_id):
        """Test getting a specific project by ID."""
        project = projects_client.get_project(sandbox_project_id)

        assert isinstance(project, dict)
        assert project['id'] == sandbox_project_id
        assert 'name' in project
        assert 'is_completed' in project
        assert 'suite_mode' in project
        assert 'url' in project

    def test_get_sandbox_project_details(self, projects_client, sandbox_project_id):
        """Test getting Sandbox project specific details."""
        project = projects_client.get_project(sandbox_project_id)

        assert project['name'].lower() == 'sandbox'
        assert isinstance(project['is_completed'], bool)
        assert project['suite_mode'] in [1, 2, 3]
        assert 'users' in project
        assert 'groups' in project

    def test_get_nonexistent_project_raises_error(self, projects_client):
        """Test that getting a non-existent project raises an error."""
        with pytest.raises(Exception):
            projects_client.get_project(99999)


class TestProjectsCRUD:
    """Test Create, Read, Update, Delete operations for projects."""

    @pytest.fixture
    def test_project_data(self):
        """Test data for creating projects."""
        return {
            'name': 'Test Project - Integration Test',
            'announcement': 'This is a test project created by integration tests',
            'show_announcement': True,
            'suite_mode': 1
        }

    @pytest.mark.skip(reason="Requires admin permissions - enable if you have admin access")
    def test_create_and_delete_project(self, projects_client, test_project_data):
        """Test creating and deleting a project (requires admin permissions)."""
        # Create project
        created_project = projects_client.add_project(**test_project_data)

        assert created_project['name'] == test_project_data['name']
        assert created_project['announcement'] == test_project_data['announcement']
        assert created_project['show_announcement'] == test_project_data['show_announcement']

        project_id = created_project['id']

        try:
            # Verify project exists
            retrieved_project = projects_client.get_project(project_id)
            assert retrieved_project['id'] == project_id

            # Update project
            updated_data = {'announcement': 'Updated announcement'}
            updated_project = projects_client.update_project(project_id, **updated_data)
            assert updated_project['announcement'] == updated_data['announcement']

        finally:
            # Clean up - delete the test project
            projects_client.delete_project(project_id)

            # Verify project is deleted
            with pytest.raises(Exception):
                projects_client.get_project(project_id)


class TestProjectsErrorHandling:
    """Test error handling scenarios for Projects."""

    def test_invalid_project_id_type(self, projects_client):
        """Test that invalid project ID types are handled properly."""
        with pytest.raises((TypeError, ValueError, Exception)):
            projects_client.get_project("invalid_id")

    def test_empty_project_name_fails(self, projects_client):
        """Test that creating project with empty name fails."""
        with pytest.raises(Exception):
            projects_client.add_project("")

    @pytest.mark.skip(reason="Requires admin permissions to test")
    def test_update_nonexistent_project_fails(self, projects_client):
        """Test that updating non-existent project fails."""
        with pytest.raises(Exception):
            projects_client.update_project(99999, name="Updated Name")


class TestProjectsDataValidation:
    """Test data validation and response structure for Projects."""

    def test_project_response_structure(self, projects_client, sandbox_project_id):
        """Test that project response has expected structure."""
        project = projects_client.get_project(sandbox_project_id)

        required_fields = ['id', 'name', 'is_completed', 'suite_mode', 'url']
        for field in required_fields:
            assert field in project, f"Missing required field: {field}"

        # Test data types
        assert isinstance(project['id'], int)
        assert isinstance(project['name'], str)
        assert isinstance(project['is_completed'], bool)
        assert isinstance(project['suite_mode'], int)
        assert isinstance(project['url'], str)

    def test_projects_list_response_structure(self, projects_client):
        """Test that projects list response has expected structure."""
        response = projects_client.get_projects()

        required_fields = ['projects', 'offset', 'limit', 'size']
        for field in required_fields:
            assert field in response, f"Missing required field: {field}"

        assert isinstance(response['projects'], list)
        assert isinstance(response['offset'], int)
        assert isinstance(response['limit'], int)
        assert isinstance(response['size'], int)

    def test_convenience_methods_return_correct_data(self, projects_client):
        """Test that convenience methods filter data correctly."""
        all_projects = projects_client.get_projects()
        active_projects = projects_client.get_active_projects()
        completed_projects = projects_client.get_completed_projects()

        # Verify structure is consistent
        for response in [all_projects, active_projects, completed_projects]:
            assert 'projects' in response
            assert 'size' in response

        # Verify filtering works (if there are projects of each type)
        if active_projects['size'] > 0:
            for project in active_projects['projects']:
                assert project['is_completed'] is False

        if completed_projects['size'] > 0:
            for project in completed_projects['projects']:
                assert project['is_completed'] is True
