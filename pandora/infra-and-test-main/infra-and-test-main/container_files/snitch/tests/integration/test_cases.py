"""Integration tests for TestRail Cases wrapper."""
import pytest
from snitch.cases import Cases


@pytest.fixture(scope="session")
def cases_client(api_client):
    """Create Cases wrapper for testing."""
    return Cases(api_client)


class TestCases:
    """Test the Cases wrapper functionality."""

    def test_get_cases_with_suite_filter(self, cases_client, sandbox_project_id, testzilla_suite_id):
        """Test getting cases filtered by Testzilla suite."""
        response = cases_client.get_cases(sandbox_project_id, suite_id=testzilla_suite_id)

        assert isinstance(response, dict)
        assert 'cases' in response

        # Verify all returned cases belong to the Testzilla suite
        for case in response['cases']:
            assert case['suite_id'] == testzilla_suite_id

    def test_get_cases_with_limit(self, cases_client, sandbox_project_id, testzilla_suite_id):
        """Test getting cases with limit parameter."""
        limit = 5
        response = cases_client.get_cases(sandbox_project_id, suite_id=testzilla_suite_id, limit=limit)

        assert response['limit'] == limit
        assert len(response['cases']) <= limit

    def test_get_cases_with_offset(self, cases_client, sandbox_project_id, testzilla_suite_id):
        """Test getting cases with offset parameter."""
        offset = 1
        response = cases_client.get_cases(sandbox_project_id, suite_id=testzilla_suite_id, offset=offset)

        assert response['offset'] == offset

    def test_get_cases_with_filter(self, cases_client, sandbox_project_id, testzilla_suite_id):
        """Test getting cases with title filter."""
        response = cases_client.get_cases(sandbox_project_id, suite_id=testzilla_suite_id, title_filter="test")

        assert isinstance(response, dict)
        assert 'cases' in response

    def test_get_specific_case(self, cases_client, sandbox_project_id, testzilla_suite_id):
        """Test getting a specific case by ID."""
        # First get some cases to find a valid case ID
        cases_response = cases_client.get_cases(sandbox_project_id, suite_id=testzilla_suite_id, limit=1)

        if cases_response['size'] == 0:
            pytest.skip("No test cases found in sandbox project")

        case_id = cases_response['cases'][0]['id']
        case = cases_client.get_case(case_id)

        assert isinstance(case, dict)
        assert case['id'] == case_id
        assert 'title' in case
        assert 'section_id' in case
        assert 'suite_id' in case

    def test_get_case_history(self, cases_client, sandbox_project_id, testzilla_suite_id):
        """Test getting case history."""
        # First get a case to get history for
        cases_response = cases_client.get_cases(sandbox_project_id, suite_id=testzilla_suite_id, limit=1)

        if cases_response['size'] == 0:
            pytest.skip("No test cases found in sandbox project")

        case_id = cases_response['cases'][0]['id']
        history = cases_client.get_history_for_case(case_id)

        assert isinstance(history, dict)
        assert 'history' in history
        assert isinstance(history['history'], list)

    def test_get_case_history_with_pagination(self, cases_client, sandbox_project_id, testzilla_suite_id):
        """Test getting case history with pagination."""
        cases_response = cases_client.get_cases(sandbox_project_id, suite_id=testzilla_suite_id, limit=1)

        if cases_response['size'] == 0:
            pytest.skip("No test cases found in sandbox project")

        case_id = cases_response['cases'][0]['id']
        history = cases_client.get_history_for_case(case_id, limit=10, offset=0)

        assert isinstance(history, dict)
        assert 'history' in history
        assert 'limit' in history
        assert 'offset' in history

    def test_get_nonexistent_case_raises_error(self, cases_client):
        """Test that getting a non-existent case raises an error."""
        with pytest.raises(Exception):
            cases_client.get_case(99999)


class TestCasesCRUD:
    """Test Create, Read, Update, Delete operations for cases."""

    def test_create_update_and_delete_case(self, cases_client, test_section_id, test_case_data):
        """Test creating, updating, and deleting a case."""
        # Create case
        created_case = cases_client.add_case(test_section_id, **test_case_data)

        assert created_case['title'] == test_case_data['title']
        assert created_case['section_id'] == test_section_id
        assert 'id' in created_case

        case_id = created_case['id']

        try:
            # Verify case exists
            retrieved_case = cases_client.get_case(case_id)
            assert retrieved_case['id'] == case_id
            assert retrieved_case['title'] == test_case_data['title']

            # Update case - remove priority_id and custom_expected
            updated_data = {
                'title': 'Updated Integration Test Case',
                'estimate': '10min'
            }
            updated_case = cases_client.update_case(case_id, **updated_data)
            assert updated_case['title'] == updated_data['title']
            assert updated_case['estimate'] == updated_data['estimate']

        finally:
            # Clean up - delete the test case
            cases_client.delete_case(case_id)

            # Verify case is deleted
            with pytest.raises(Exception):
                cases_client.get_case(case_id)

    def test_copy_cases_to_section(self, cases_client, test_section_id, test_case_data, sandbox_project_id,
                                   testzilla_suite_id):
        """Test copying cases to another section."""
        # Create a test case first
        created_case = cases_client.add_case(test_section_id, **test_case_data)
        case_id = created_case['id']

        # Get initial count of cases in the section
        initial_cases = cases_client.get_cases(
            sandbox_project_id,
            suite_id=testzilla_suite_id,
            section_id=test_section_id
        )
        initial_count = len(initial_cases['cases'])

        try:
            # Copy case to the same section (for testing purposes)
            cases_client.copy_cases_to_section(test_section_id, [case_id])

            # Verify the copy operation worked by checking case count increased
            updated_cases = cases_client.get_cases(
                sandbox_project_id,
                suite_id=testzilla_suite_id,
                section_id=test_section_id
            )
            assert len(updated_cases['cases']) == initial_count + 1

            # Find the copied case (it will have a different ID)
            copied_case_ids = [case['id'] for case in updated_cases['cases'] if case['id'] != case_id]
            # The below assertion is based on the assumption that there are only two manually created test cases
            # in the suite. No other tests should exist
            assert len(copied_case_ids) == 3
            copied_case_id = copied_case_ids[0]

        finally:
            # Clean up - delete both the original and copied cases
            cases_client.delete_case(case_id)
            if 'copied_case_id' in locals():
                cases_client.delete_case(copied_case_id)

    def test_move_cases_to_section(self, cases_client, test_section_id, testzilla_suite_id, test_case_data):
        """Test moving cases to another section."""
        # Create a test case first
        created_case = cases_client.add_case(test_section_id, **test_case_data)
        case_id = created_case['id']

        try:
            # Move case to the same section (for testing purposes)
            cases_client.move_cases_to_section(test_section_id, testzilla_suite_id, [case_id])

            # Verify the case still exists and is in the correct section
            moved_case = cases_client.get_case(case_id)
            assert moved_case['id'] == case_id
            assert moved_case['section_id'] == test_section_id

        finally:
            # Clean up - delete the test case
            cases_client.delete_case(case_id)

    def test_update_multiple_cases(self, cases_client, test_section_id, testzilla_suite_id, test_case_data):
        """Test updating multiple cases at once."""
        # Create two test cases using minimal data
        case1 = cases_client.add_case(test_section_id, title="Integration Test Case 1")
        case2 = cases_client.add_case(test_section_id, title="Integration Test Case 2")

        case_ids = [case1['id'], case2['id']]

        try:
            # Update both cases - only use basic fields
            update_data = {
                'estimate': '15min'
            }
            cases_client.update_cases(testzilla_suite_id, case_ids, **update_data)

            # Verify updates
            updated_case1 = cases_client.get_case(case1['id'])
            updated_case2 = cases_client.get_case(case2['id'])

            assert updated_case1['estimate'] == '15min'
            assert updated_case2['estimate'] == '15min'

        finally:
            # Clean up - delete the test cases
            for case_id in case_ids:
                cases_client.delete_case(case_id)

    def test_soft_delete_case(self, cases_client, test_section_id, test_case_data):
        """Test soft delete to get deletion info without actually deleting."""
        # Create a test case first
        created_case = cases_client.add_case(test_section_id, **test_case_data)
        case_id = created_case['id']

        try:
            # Test soft delete (get info without deleting)
            deletion_info = cases_client.delete_case(case_id, soft=1)

            # Should return deletion info
            assert deletion_info is not None
            assert isinstance(deletion_info, dict)

            # Verify case still exists after soft delete
            case = cases_client.get_case(case_id)
            assert case['id'] == case_id

        finally:
            # Clean up - actually delete the test case
            cases_client.delete_case(case_id)


class TestCasesErrorHandling:
    """Test error handling scenarios for Cases."""

    def test_invalid_case_id_type(self, cases_client):
        """Test that invalid case ID types are handled properly."""
        with pytest.raises((TypeError, ValueError, Exception)):
            cases_client.get_case("invalid_id")

    def test_empty_case_title_fails(self, cases_client, test_section_id):
        """Test that creating case with empty title fails."""
        with pytest.raises(Exception):
            cases_client.add_case(test_section_id, "")

    def test_invalid_section_id_fails(self, cases_client):
        """Test that using invalid section ID fails."""
        with pytest.raises(Exception):
            cases_client.add_case(99999, "Test Case")

    def test_update_nonexistent_case_fails(self, cases_client):
        """Test that updating non-existent case fails."""
        with pytest.raises(Exception):
            cases_client.update_case(99999, title="Updated Title")

    def test_invalid_project_id_fails(self, cases_client, testzilla_suite_id):
        """Test that using invalid project ID fails."""
        with pytest.raises(Exception):
            cases_client.get_cases(99999, suite_id=testzilla_suite_id)


class TestCasesDataValidation:
    """Test data validation and response structure for Cases."""

    def test_case_response_structure(self, cases_client, sandbox_project_id, testzilla_suite_id):
        """Test that case response has expected structure."""
        cases_response = cases_client.get_cases(sandbox_project_id, suite_id=testzilla_suite_id, limit=1)

        if cases_response['size'] == 0:
            pytest.skip("No test cases found in sandbox project")

        case = cases_response['cases'][0]

        required_fields = ['id', 'title', 'section_id', 'suite_id', 'created_by', 'created_on']
        for field in required_fields:
            assert field in case, f"Missing required field: {field}"

        # Test data types
        assert isinstance(case['id'], int)
        assert isinstance(case['title'], str)
        assert isinstance(case['section_id'], int)
        assert isinstance(case['suite_id'], int)

    def test_cases_list_response_structure(self, cases_client, sandbox_project_id, testzilla_suite_id):
        """Test that cases list response has expected structure."""
        response = cases_client.get_cases(sandbox_project_id, suite_id=testzilla_suite_id)

        required_fields = ['cases', 'offset', 'limit', 'size']
        for field in required_fields:
            assert field in response, f"Missing required field: {field}"

        assert isinstance(response['cases'], list)
        assert isinstance(response['offset'], int)
        assert isinstance(response['limit'], int)
        assert isinstance(response['size'], int)

    def test_case_history_response_structure(self, cases_client, sandbox_project_id, testzilla_suite_id):
        """Test that case history response has expected structure."""
        cases_response = cases_client.get_cases(sandbox_project_id, suite_id=testzilla_suite_id, limit=1)

        if cases_response['size'] == 0:
            pytest.skip("No test cases found in sandbox project")

        case_id = cases_response['cases'][0]['id']
        history_response = cases_client.get_history_for_case(case_id)

        required_fields = ['history', 'offset', 'limit', 'size']
        for field in required_fields:
            assert field in history_response, f"Missing required field: {field}"

        assert isinstance(history_response['history'], list)
