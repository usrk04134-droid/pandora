"""Integration tests for TestRail Suites wrapper."""
import pytest
from snitch.suites import Suites


@pytest.fixture(scope="session")
def suites_client(api_client):
    """Create Suites wrapper for testing."""
    return Suites(api_client)


class TestSuites:
    """Test the Suites wrapper functionality."""

    def test_get_suites(self, suites_client, sandbox_project_id):
        """Test getting all suites for the sandbox project."""
        response = suites_client.get_suites(sandbox_project_id)

        assert isinstance(response, list)
        assert len(response) > 0

        # Verify suite structure
        suite = response[0]
        required_fields = ['id', 'name', 'project_id', 'description']
        for field in required_fields:
            assert field in suite

    def test_get_specific_suite(self, suites_client, testzilla_suite_id):
        """Test getting a specific suite by ID."""
        suite = suites_client.get_suite(testzilla_suite_id)

        assert isinstance(suite, dict)
        assert suite['id'] == testzilla_suite_id
        assert 'name' in suite
        assert 'description' in suite

    def test_get_nonexistent_suite_raises_error(self, suites_client):
        """Test that getting a non-existent suite raises an error."""
        with pytest.raises(Exception):
            suites_client.get_suite(99999)


class TestSuitesCRUD:
    """Test Create, Read, Update, Delete operations for suites."""

    @pytest.fixture
    def test_suite_data(self):
        """Test data for creating suites."""
        return {
            'name': 'Integration Test Suite - Auto Generated',
            'description': 'Test suite created by integration tests'
        }

    def test_create_update_and_delete_suite(self, suites_client, sandbox_project_id, test_suite_data):
        """Test creating, updating, and deleting a suite."""
        # Create suite
        created_suite = suites_client.add_suite(sandbox_project_id, **test_suite_data)

        assert created_suite['name'] == test_suite_data['name']
        assert created_suite['project_id'] == sandbox_project_id
        assert 'id' in created_suite

        suite_id = created_suite['id']

        try:
            # Verify suite exists
            retrieved_suite = suites_client.get_suite(suite_id)
            assert retrieved_suite['id'] == suite_id
            assert retrieved_suite['name'] == test_suite_data['name']

            # Update suite
            updated_data = {
                'name': 'Updated Integration Test Suite',
                'description': 'Updated description'
            }
            updated_suite = suites_client.update_suite(suite_id, **updated_data)
            assert updated_suite['name'] == updated_data['name']
            assert updated_suite['description'] == updated_data['description']

        finally:
            # Clean up - delete the test suite
            suites_client.delete_suite(suite_id)

            # Verify suite is deleted
            with pytest.raises(Exception):
                suites_client.get_suite(suite_id)

    def test_soft_delete_suite(self, suites_client, sandbox_project_id, test_suite_data):
        """Test soft delete to get deletion info without actually deleting."""
        # Create a test suite first
        created_suite = suites_client.add_suite(sandbox_project_id, **test_suite_data)
        suite_id = created_suite['id']

        try:
            # Test soft delete (get info without deleting)
            deletion_info = suites_client.delete_suite(suite_id, soft=1)

            # Should return deletion info
            assert deletion_info is not None
            assert isinstance(deletion_info, dict)

            # Verify suite still exists after soft delete
            suite = suites_client.get_suite(suite_id)
            assert suite['id'] == suite_id

        finally:
            # Clean up - actually delete the test suite
            suites_client.delete_suite(suite_id)


class TestSuitesErrorHandling:
    """Test error handling scenarios for Suites."""

    def test_invalid_suite_id_type(self, suites_client):
        """Test that invalid suite ID types are handled properly."""
        with pytest.raises((TypeError, ValueError, Exception)):
            suites_client.get_suite("invalid_id")

    def test_empty_suite_name_fails(self, suites_client, sandbox_project_id):
        """Test that creating suite with empty name fails."""
        with pytest.raises(Exception):
            suites_client.add_suite(sandbox_project_id, "")

    def test_invalid_project_id_fails(self, suites_client):
        """Test that using invalid project ID fails."""
        with pytest.raises(Exception):
            suites_client.get_suites(99999)

    def test_update_nonexistent_suite_fails(self, suites_client):
        """Test that updating non-existent suite fails."""
        with pytest.raises(Exception):
            suites_client.update_suite(99999, name="Updated Name")


class TestSuitesDataValidation:
    """Test data validation and response structure for Suites."""

    def test_suites_list_response_structure(self, suites_client, sandbox_project_id):
        """Test that suites list response has expected structure."""
        response = suites_client.get_suites(sandbox_project_id)

        assert isinstance(response, list)
        assert len(response) > 0

        suite = response[0]
        required_fields = ['id', 'name', 'project_id']
        for field in required_fields:
            assert field in suite, f"Missing required field: {field}"

        # Test data types
        assert isinstance(suite['id'], int)
        assert isinstance(suite['name'], str)
        assert isinstance(suite['project_id'], int)

    def test_suite_response_structure(self, suites_client, testzilla_suite_id):
        """Test that suite response has expected structure."""
        suite = suites_client.get_suite(testzilla_suite_id)

        required_fields = ['id', 'name', 'project_id']
        for field in required_fields:
            assert field in suite, f"Missing required field: {field}"

        # Test data types
        assert isinstance(suite['id'], int)
        assert isinstance(suite['name'], str)
        assert isinstance(suite['project_id'], int)
