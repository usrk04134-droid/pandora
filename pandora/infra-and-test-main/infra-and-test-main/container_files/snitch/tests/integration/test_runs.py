"""Integration tests for TestRail Runs wrapper."""
import pytest

@pytest.fixture(scope="session")
def test_run_id(runs_client, sandbox_project_id, testzilla_suite_id):
    """Get an existing test run ID from the sandbox project."""
    runs_response = runs_client.get_runs(sandbox_project_id, limit=1)

    if runs_response.get('size', 0) == 0:
        pytest.skip("No test runs found in sandbox project")

    return runs_response['runs'][0]['id']


class TestRuns:
    """Test the Runs wrapper functionality."""

    def test_get_runs(self, runs_client, sandbox_project_id):
        """Test getting all runs for the sandbox project."""
        response = runs_client.get_runs(sandbox_project_id)

        assert isinstance(response, dict)
        assert 'runs' in response
        assert 'offset' in response
        assert 'limit' in response
        assert 'size' in response
        assert isinstance(response['runs'], list)

        # If runs exist, verify structure
        if response['size'] > 0:
            run = response['runs'][0]
            required_fields = ['id', 'name', 'project_id', 'suite_id']
            for field in required_fields:
                assert field in run

    def test_get_runs_with_filters(self, runs_client, sandbox_project_id):
        """Test getting runs with various filters."""
        # Test with is_completed filter
        active_runs = runs_client.get_runs(sandbox_project_id, is_completed=False, limit=5)
        assert active_runs['limit'] == 5

        # Test with limit and offset
        paginated_runs = runs_client.get_runs(sandbox_project_id, limit=2, offset=0)
        assert paginated_runs['limit'] == 2
        assert paginated_runs['offset'] == 0

    def test_get_specific_run(self, runs_client, test_run_id):
        """Test getting a specific run by ID."""
        run = runs_client.get_run(test_run_id)

        assert isinstance(run, dict)
        assert run['id'] == test_run_id
        assert 'name' in run
        assert 'project_id' in run
        assert 'suite_id' in run

    def test_get_active_runs_convenience_method(self, runs_client, sandbox_project_id):
        """Test the convenience method for getting active runs."""
        response = runs_client.get_active_runs(sandbox_project_id, limit=5)

        assert isinstance(response, dict)
        assert 'runs' in response
        assert response['limit'] == 5

    def test_get_completed_runs_convenience_method(self, runs_client, sandbox_project_id):
        """Test the convenience method for getting completed runs."""
        response = runs_client.get_completed_runs(sandbox_project_id, limit=5)

        assert isinstance(response, dict)
        assert 'runs' in response
        assert response['limit'] == 5

    def test_get_nonexistent_run_raises_error(self, runs_client):
        """Test that getting a non-existent run raises an error."""
        with pytest.raises(Exception):
            runs_client.get_run(99999)


class TestRunsCRUD:
    """Test Create, Read, Update, Delete operations for runs."""

    @pytest.fixture
    def test_run_data(self):
        """Test data for creating runs."""
        return {
            'name': 'Integration Test Run - Auto Generated',
            'description': 'Test run created by integration tests',
            'include_all': True
        }

    def test_create_update_and_delete_run(self, runs_client, sandbox_project_id, testzilla_suite_id, test_run_data):
        """Test creating, updating, and deleting a run."""
        # Add suite_id to test data
        run_data = test_run_data.copy()
        run_data['suite_id'] = testzilla_suite_id

        # Create run
        created_run = runs_client.add_run(sandbox_project_id, **run_data)

        assert created_run['name'] == test_run_data['name']
        assert created_run['project_id'] == sandbox_project_id
        assert created_run['suite_id'] == testzilla_suite_id
        assert 'id' in created_run

        run_id = created_run['id']

        try:
            # Verify run exists
            retrieved_run = runs_client.get_run(run_id)
            assert retrieved_run['id'] == run_id
            assert retrieved_run['name'] == test_run_data['name']

            # Update run
            updated_data = {
                'name': 'Updated Integration Test Run',
                'description': 'Updated description'
            }
            updated_run = runs_client.update_run(run_id, **updated_data)
            assert updated_run['name'] == updated_data['name']
            assert updated_run['description'] == updated_data['description']

        finally:
            # Clean up - delete the test run
            runs_client.delete_run(run_id)

            # Verify run is deleted
            with pytest.raises(Exception):
                runs_client.get_run(run_id)

    def test_create_run_with_custom_case_selection(self, runs_client, sandbox_project_id, testzilla_suite_id,
                                                   api_client):
        """Test creating a run with custom case selection."""
        # First get some case IDs from the suite
        cases_response = api_client.send_get(f"get_cases/{sandbox_project_id}&suite_id={testzilla_suite_id}&limit=2")

        if cases_response.get('size', 0) == 0:
            pytest.skip("No test cases found in testzilla suite")

        case_ids = [case['id'] for case in cases_response['cases']]

        run_data = {
            'name': 'Custom Case Selection Test Run',
            'suite_id': testzilla_suite_id,
            'include_all': False,
            'case_ids': case_ids
        }

        # Create run
        created_run = runs_client.add_run(sandbox_project_id, **run_data)

        assert created_run['name'] == run_data['name']
        assert not created_run['include_all']
        assert 'id' in created_run

        try:
            # Verify run was created correctly
            retrieved_run = runs_client.get_run(created_run['id'])
            assert not retrieved_run['include_all']

        finally:
            # Clean up
            runs_client.delete_run(created_run['id'])

    def test_close_run(self, runs_client, sandbox_project_id, testzilla_suite_id):
        """Test closing a run."""
        # Create a test run first
        run_data = {
            'name': 'Test Run to Close',
            'suite_id': testzilla_suite_id,
            'include_all': True
        }
        created_run = runs_client.add_run(sandbox_project_id, **run_data)
        run_id = created_run['id']

        try:
            # Close the run
            closed_run = runs_client.close_run(run_id)

            assert closed_run['id'] == run_id
            assert closed_run['is_completed']
            assert closed_run['completed_on'] is not None

        finally:
            # Note: Closed runs can still be deleted for cleanup
            runs_client.delete_run(run_id)

    def test_soft_delete_run(self, runs_client, sandbox_project_id, testzilla_suite_id):
        """Test soft delete to get deletion info without actually deleting."""
        # Create a test run first
        run_data = {
            'name': 'Test Run for Soft Delete',
            'suite_id': testzilla_suite_id,
            'include_all': True
        }
        created_run = runs_client.add_run(sandbox_project_id, **run_data)
        run_id = created_run['id']

        try:
            # Test soft delete (get info without deleting)
            deletion_info = runs_client.delete_run(run_id, soft=1)

            # Should return deletion info
            assert deletion_info is not None
            assert isinstance(deletion_info, dict)

            # Verify run still exists after soft delete
            run = runs_client.get_run(run_id)
            assert run['id'] == run_id

        finally:
            # Clean up - actually delete the test run
            runs_client.delete_run(run_id)


class TestRunsErrorHandling:
    """Test error handling scenarios for Runs."""

    def test_invalid_run_id_type(self, runs_client):
        """Test that invalid run ID types are handled properly."""
        with pytest.raises((TypeError, ValueError, Exception)):
            runs_client.get_run("invalid_id")

    def test_empty_run_name_gets_suite_name(self, runs_client,
                                            sandbox_project_id,
                                            testzilla_suite_id):
        """Test that creating run with empty name gets assigned the suite name."""
        # TestRail API automatically assigns suite name when run name is empty
        created_run = runs_client.add_run(sandbox_project_id, "",
                                          suite_id=testzilla_suite_id)

        # Should get the suite name "Testzilla" as the run name
        assert created_run['name'] == "Testzilla"
        assert 'id' in created_run

        # Clean up the created run
        runs_client.delete_run(created_run['id'])

    def test_invalid_project_id_fails(self, runs_client):
        """Test that using invalid project ID fails."""
        with pytest.raises(Exception):
            runs_client.get_runs(99999)

    def test_update_nonexistent_run_fails(self, runs_client):
        """Test that updating non-existent run fails."""
        with pytest.raises(Exception):
            runs_client.update_run(99999, name="Updated Name")

    def test_close_nonexistent_run_fails(self, runs_client):
        """Test that closing non-existent run fails."""
        with pytest.raises(Exception):
            runs_client.close_run(99999)

    def test_delete_nonexistent_run_fails(self, runs_client):
        """Test that deleting non-existent run fails."""
        with pytest.raises(Exception):
            runs_client.delete_run(99999)

    def test_invalid_suite_id_fails(self, runs_client, sandbox_project_id):
        """Test that using invalid suite ID fails."""
        with pytest.raises(Exception):
            runs_client.add_run(sandbox_project_id, "Test Run", suite_id=99999)


class TestRunsDataValidation:
    """Test data validation and response structure for Runs."""

    def test_runs_list_response_structure(self, runs_client, sandbox_project_id):
        """Test that runs list response has expected structure."""
        response = runs_client.get_runs(sandbox_project_id)

        required_fields = ['runs', 'offset', 'limit', 'size']
        for field in required_fields:
            assert field in response, f"Missing required field: {field}"

        assert isinstance(response['runs'], list)
        assert isinstance(response['offset'], int)
        assert isinstance(response['limit'], int)
        assert isinstance(response['size'], int)

        # If runs exist, test their structure
        if response['size'] > 0:
            run = response['runs'][0]
            required_run_fields = ['id', 'name', 'project_id', 'suite_id', 'created_by', 'created_on']
            for field in required_run_fields:
                assert field in run, f"Missing required field in run: {field}"

            # Test data types
            assert isinstance(run['id'], int)
            assert isinstance(run['name'], str)
            assert isinstance(run['project_id'], int)
            assert isinstance(run['suite_id'], int)

    def test_run_response_structure(self, runs_client, test_run_id):
        """Test that run response has expected structure."""
        run = runs_client.get_run(test_run_id)

        required_fields = [
            'id', 'name', 'project_id', 'suite_id', 'created_by', 'created_on',
            'is_completed', 'passed_count', 'failed_count', 'blocked_count',
            'untested_count', 'retest_count'
        ]
        for field in required_fields:
            assert field in run, f"Missing required field: {field}"

        # Test data types
        assert isinstance(run['id'], int)
        assert isinstance(run['name'], str)
        assert isinstance(run['project_id'], int)
        assert isinstance(run['suite_id'], int)
        assert isinstance(run['is_completed'], bool)
        assert isinstance(run['passed_count'], int)
        assert isinstance(run['failed_count'], int)
        assert isinstance(run['blocked_count'], int)
        assert isinstance(run['untested_count'], int)
        assert isinstance(run['retest_count'], int)

    def test_runs_filtering_validation(self, runs_client, sandbox_project_id):
        """Test that filtering parameters work correctly."""
        # Test created_by filter with list
        response = runs_client.get_runs(sandbox_project_id, created_by=[1, 2],
                                        limit=5)
        assert response['limit'] == 5

        # Test milestone_id filter with single value
        response = runs_client.get_runs(sandbox_project_id, milestone_id=1,
                                        limit=5)
        assert response['limit'] == 5

        # Test suite_id filter with list
        response = runs_client.get_runs(sandbox_project_id, suite_id=[1, 2],
                                        limit=5)
        assert response['limit'] == 5

    def test_run_creation_validation(self, runs_client, sandbox_project_id,
                                     testzilla_suite_id):
        """Test that run creation handles various parameter combinations."""
        # Test minimal run creation
        minimal_run = runs_client.add_run(
            sandbox_project_id,
            name="Minimal Test Run",
            suite_id=testzilla_suite_id
        )

        assert minimal_run['name'] == "Minimal Test Run"
        assert 'id' in minimal_run

        try:
            # Test run creation with all optional parameters
            full_run_data = {
                'name': 'Full Parameter Test Run',
                'suite_id': testzilla_suite_id,
                'description': 'Test description',
                'include_all': True,
                'refs': 'TEST-001,TEST-002'
            }
            full_run = runs_client.add_run(sandbox_project_id, **full_run_data)

            assert full_run['name'] == full_run_data['name']
            assert full_run['description'] == full_run_data['description']
            assert full_run['refs'] == full_run_data['refs']
            assert 'id' in full_run

            # Clean up the full parameter run
            runs_client.delete_run(full_run['id'])

        finally:
            # Clean up the minimal run
            runs_client.delete_run(minimal_run['id'])

    def test_run_update_validation(self, runs_client, sandbox_project_id,
                                   testzilla_suite_id):
        """Test that run updates handle various parameter combinations."""
        # Create a test run first
        run_data = {
            'name': 'Test Run for Update Validation',
            'suite_id': testzilla_suite_id,
            'include_all': True
        }
        created_run = runs_client.add_run(sandbox_project_id, **run_data)
        run_id = created_run['id']

        try:
            # Test partial update
            partial_update = {'name': 'Partially Updated Run'}
            updated_run = runs_client.update_run(run_id, **partial_update)
            assert updated_run['name'] == partial_update['name']

            # Test multiple field update
            multi_update = {
                'name': 'Multi-field Updated Run',
                'description': 'Updated description',
                'refs': 'UPD-001'
            }
            updated_run = runs_client.update_run(run_id, **multi_update)
            assert updated_run['name'] == multi_update['name']
            assert updated_run['description'] == multi_update['description']
            assert updated_run['refs'] == multi_update['refs']

        finally:
            # Clean up
            runs_client.delete_run(run_id)
