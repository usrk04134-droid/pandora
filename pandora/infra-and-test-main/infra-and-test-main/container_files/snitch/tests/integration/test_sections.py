"""Integration tests for TestRail Sections wrapper."""
import pytest
from snitch.sections import Sections


@pytest.fixture(scope="session")
def sections_client(api_client):
    """Create Sections wrapper for testing."""
    return Sections(api_client)


class TestSections:
    """Test the Sections wrapper functionality."""

    def test_get_sections(self, sections_client, sandbox_project_id, testzilla_suite_id):
        """Test getting all sections for the sandbox project and suite."""
        response = sections_client.get_sections(sandbox_project_id, testzilla_suite_id)

        assert isinstance(response, dict)
        assert 'sections' in response

        if response['sections']:
            # Verify section structure
            section = response['sections'][0]
            required_fields = ['id', 'name', 'suite_id', 'depth']
            for field in required_fields:
                assert field in section

            # Verify all sections belong to the specified suite
            for section in response['sections']:
                assert section['suite_id'] == testzilla_suite_id

    def test_get_specific_section(self, sections_client, test_section_id):
        """Test getting a specific section by ID."""
        section = sections_client.get_section(test_section_id)

        assert isinstance(section, dict)
        assert section['id'] == test_section_id
        assert 'name' in section
        assert 'suite_id' in section

    def test_get_nonexistent_section_raises_error(self, sections_client):
        """Test that getting a non-existent section raises an error."""
        with pytest.raises(Exception):
            sections_client.get_section(99999)


class TestSectionsCRUD:
    """Test Create, Read, Update, Delete operations for sections."""

    @pytest.fixture
    def test_section_data(self):
        """Test data for creating sections."""
        return {
            'name': 'Integration Test Section - Auto Generated',
            'description': 'Test section created by integration tests'
        }

    def test_create_update_and_delete_section(self, sections_client, sandbox_project_id,
                                              testzilla_suite_id, test_section_data):
        """Test creating, updating, and deleting a section."""
        # Create section
        created_section = sections_client.add_section(
            sandbox_project_id,
            suite_id=testzilla_suite_id,
            **test_section_data
        )

        assert created_section['name'] == test_section_data['name']
        assert created_section['suite_id'] == testzilla_suite_id
        assert 'id' in created_section

        section_id = created_section['id']

        try:
            # Verify section exists
            retrieved_section = sections_client.get_section(section_id)
            assert retrieved_section['id'] == section_id
            assert retrieved_section['name'] == test_section_data['name']

            # Update section
            updated_data = {
                'name': 'Updated Integration Test Section',
                'description': 'Updated description'
            }
            updated_section = sections_client.update_section(section_id, **updated_data)
            assert updated_section['name'] == updated_data['name']
            assert updated_section['description'] == updated_data['description']

        finally:
            # Clean up - delete the test section
            sections_client.delete_section(section_id)

            # Verify section is deleted
            with pytest.raises(Exception):
                sections_client.get_section(section_id)

    def test_soft_delete_section(self, sections_client, sandbox_project_id,
                                 testzilla_suite_id, test_section_data):
        """Test soft delete to get deletion info without actually deleting."""
        # Create a test section first
        created_section = sections_client.add_section(
            sandbox_project_id,
            suite_id=testzilla_suite_id,
            **test_section_data
        )
        section_id = created_section['id']

        try:
            # Test soft delete (get info without deleting)
            deletion_info = sections_client.delete_section(section_id, soft=1)

            # Should return deletion info
            assert deletion_info is not None
            assert isinstance(deletion_info, dict)

            # Verify section still exists after soft delete
            section = sections_client.get_section(section_id)
            assert section['id'] == section_id

        finally:
            # Clean up - actually delete the test section
            sections_client.delete_section(section_id)


class TestSectionsErrorHandling:
    """Test error handling scenarios for Sections."""

    def test_invalid_section_id_type(self, sections_client):
        """Test that invalid section ID types are handled properly."""
        with pytest.raises((TypeError, ValueError, Exception)):
            sections_client.get_section("invalid_id")

    def test_empty_section_name_fails(self, sections_client, sandbox_project_id, testzilla_suite_id):
        """Test that creating section with empty name fails."""
        with pytest.raises(Exception):
            sections_client.add_section(sandbox_project_id, "", suite_id=testzilla_suite_id)

    def test_invalid_project_id_fails(self, sections_client):
        """Test that using invalid project ID fails."""
        with pytest.raises(Exception):
            sections_client.get_sections(99999)

    def test_update_nonexistent_section_fails(self, sections_client):
        """Test that updating non-existent section fails."""
        with pytest.raises(Exception):
            sections_client.update_section(99999, name="Updated Name")


class TestSectionsDataValidation:
    """Test data validation and response structure for Sections."""

    def test_sections_list_response_structure(self, sections_client, sandbox_project_id, testzilla_suite_id):
        """Test that sections list response has expected structure."""
        response = sections_client.get_sections(sandbox_project_id, testzilla_suite_id)

        assert isinstance(response, dict)
        assert 'sections' in response

        if response['sections']:
            section = response['sections'][0]
            required_fields = ['id', 'name', 'suite_id', 'depth']
            for field in required_fields:
                assert field in section, f"Missing required field: {field}"

            # Test data types
            assert isinstance(section['id'], int)
            assert isinstance(section['name'], str)
            assert isinstance(section['suite_id'], int)
            assert isinstance(section['depth'], int)

    def test_section_response_structure(self, sections_client, test_section_id):
        """Test that section response has expected structure."""
        section = sections_client.get_section(test_section_id)

        required_fields = ['id', 'name', 'suite_id', 'depth']
        for field in required_fields:
            assert field in section, f"Missing required field: {field}"

        # Test data types
        assert isinstance(section['id'], int)
        assert isinstance(section['name'], str)
        assert isinstance(section['suite_id'], int)
        assert isinstance(section['depth'], int)
