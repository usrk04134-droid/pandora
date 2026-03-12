"""Integration tests for TestRail Results wrapper."""
import pytest
from snitch.results import Results


@pytest.fixture(scope="session")
def results_client(api_client):
    """Create Results wrapper for testing."""
    return Results(api_client)


@pytest.fixture(scope="session")
def test_run_with_results(runs_client, sandbox_project_id, testzilla_suite_id):
    """Create a test run with some test cases for results testing."""
    run_data = {
        'name': 'Results Integration Test Run',
        'suite_id': testzilla_suite_id,
        'include_all': True
    }
    created_run = runs_client.add_run(sandbox_project_id, **run_data)
    yield created_run['id']
    runs_client.delete_run(created_run['id'])


@pytest.fixture(scope="session")
def test_case_id(api_client, sandbox_project_id, testzilla_suite_id):
    """Get a test case ID from the testzilla suite."""
    cases_response = api_client.send_get(f"get_cases/{sandbox_project_id}&suite_id={testzilla_suite_id}&limit=1")

    if cases_response.get('size', 0) == 0:
        pytest.skip("No test cases found in testzilla suite")

    return cases_response['cases'][0]['id']

@pytest.fixture(scope="session")
def test_result_data():
    """Test data for creating results."""
    return {
        'status_id': 1,  # Passed
        'comment': 'Integration test result - Auto Generated',
        'elapsed': '30s',
        'version': '1.0.0-test'
    }


@pytest.fixture(scope="session")
def test_id(api_client, test_run_with_results):
    """Get a test ID from the created test run."""
    tests_response = api_client.send_get(f"get_tests/{test_run_with_results}")

    # Handle different possible response formats
    if isinstance(tests_response, dict) and 'tests' in tests_response:
        tests = tests_response['tests']
    elif isinstance(tests_response, list):
        tests = tests_response
    else:
        pytest.skip("Unexpected tests response format")

    if not tests or len(tests) == 0:
        pytest.skip("No tests found in test run")

    return tests[0]['id']


class TestResults:
    """Test the Results wrapper functionality."""

    def test_get_results_for_run(self, results_client, test_run_with_results):
        """Test getting all results for a test run."""
        response = results_client.get_results_for_run(test_run_with_results)

        assert isinstance(response, dict)
        assert 'results' in response
        assert 'offset' in response
        assert 'limit' in response
        assert 'size' in response
        assert isinstance(response['results'], list)

    def test_get_results_for_run_with_filters(self, results_client, test_run_with_results):
        """Test getting results with various filters."""
        # Test with limit
        response = results_client.get_results_for_run(test_run_with_results, limit=5)
        assert response['limit'] == 5

        # Test with offset
        response = results_client.get_results_for_run(test_run_with_results, limit=2, offset=0)
        assert response['limit'] == 2
        assert response['offset'] == 0

        # Test with status filter
        response = results_client.get_results_for_run(test_run_with_results, status_id=[1, 5], limit=10)
        assert response['limit'] == 10

    def test_get_results_for_case(self, results_client, test_run_with_results, test_case_id):
        """Test getting results for a specific run and case combination."""
        response = results_client.get_results_for_case(test_run_with_results, test_case_id)

        assert isinstance(response, dict)
        assert 'results' in response
        assert 'offset' in response
        assert 'limit' in response
        assert 'size' in response

    def test_get_results_for_case_with_filters(self, results_client, test_run_with_results, test_case_id):
        """Test getting results for case with filters."""
        response = results_client.get_results_for_case(
            test_run_with_results,
            test_case_id,
            limit=5,
            status_id=[1, 5]
        )
        assert response['limit'] == 5

    def test_get_results_for_test(self, results_client, test_id):
        """Test getting results for a specific test."""
        response = results_client.get_results(test_id)

        assert isinstance(response, dict)
        assert 'results' in response
        assert 'offset' in response
        assert 'limit' in response
        assert 'size' in response

    def test_get_results_with_filters(self, results_client, test_id):
        """Test getting results with various filters."""
        response = results_client.get_results(test_id, limit=5, status_id=[1, 5])
        assert response['limit'] == 5

    def test_convenience_methods(self, results_client, test_id):
        """Test convenience methods for getting results by status."""
        # Test get_passed_results
        passed_response = results_client.get_passed_results(test_id, limit=5)
        assert isinstance(passed_response, dict)
        assert passed_response['limit'] == 5

        # Test get_failed_results
        failed_response = results_client.get_failed_results(test_id, limit=5)
        assert isinstance(failed_response, dict)
        assert failed_response['limit'] == 5

        # Test get_results_by_status
        status_response = results_client.get_results_by_status(test_id, [1, 2], limit=5)
        assert isinstance(status_response, dict)
        assert status_response['limit'] == 5

    def test_get_nonexistent_test_results_raises_error(self, results_client):
        """Test that getting results for non-existent test raises an error."""
        with pytest.raises(Exception):
            results_client.get_results(99999)


class TestResultsCRUD:
    """Test Create operations for results."""

    def test_add_result_for_case(self, results_client, test_run_with_results, test_case_id, test_result_data):
        """Test adding a result for a case."""
        result = results_client.add_result_for_case(
            test_run_with_results,
            test_case_id,
            **test_result_data
        )

        assert isinstance(result, dict)
        assert result['status_id'] == test_result_data['status_id']
        assert result['comment'] == test_result_data['comment']
        # TestRail normalizes elapsed time format
        assert result['elapsed'] in ['30s', '30sec']  # Accept both formats
        assert result['version'] == test_result_data['version']
        assert 'id' in result
        assert 'test_id' in result

    def test_add_result_for_test(self, results_client, test_id, test_result_data):
        """Test adding a result for a test."""
        result = results_client.add_result(test_id, **test_result_data)

        assert isinstance(result, dict)
        assert result['status_id'] == test_result_data['status_id']
        assert result['comment'] == test_result_data['comment']
        assert result['elapsed'] in ['30s', '30sec']
        assert result['version'] == test_result_data['version']
        assert 'id' in result
        assert result['test_id'] == test_id

    def test_add_result_with_custom_fields(self, results_client, test_id):
        """Test adding a result with custom fields."""
        result_data = {
            'status_id': 5,  # Failed
            'comment': 'Test with custom fields',
            'custom_step_results': [
                {
                    'content': 'Step 1',
                    'expected': 'Expected Result 1',
                    'actual': 'Actual Result 1',
                    'status_id': 1
                }
            ]
        }

        result = results_client.add_result(test_id, **result_data)

        assert isinstance(result, dict)
        assert result['status_id'] == 5
        assert result['comment'] == result_data['comment']
        assert 'id' in result

    def test_add_multiple_results(self, results_client, test_run_with_results, api_client, sandbox_project_id,
                                  testzilla_suite_id):
        """Test adding multiple results at once."""
        # Get some test IDs from the run
        tests_response = api_client.send_get(f"get_tests/{test_run_with_results}")

        # Handle different possible response formats
        if isinstance(tests_response, dict) and 'tests' in tests_response:
            tests = tests_response['tests']
        elif isinstance(tests_response, list):
            tests = tests_response
        else:
            pytest.skip("Unexpected tests response format")

        if not tests or len(tests) < 2:
            pytest.skip("Not enough tests found in test run")

        test_ids = [test['id'] for test in tests[:2]]

        results_data = [
            {
                'test_id': test_ids[0],
                'status_id': 1,
                'comment': 'Bulk test result 1',
                'elapsed': '15s'
            },
            {
                'test_id': test_ids[1],
                'status_id': 5,
                'comment': 'Bulk test result 2',
                'elapsed': '25s'
            }
        ]

        results = results_client.add_results(test_run_with_results, results_data)

        assert isinstance(results, list)
        assert len(results) == 2
        assert results[0]['status_id'] == 1
        assert results[1]['status_id'] == 5

    def test_add_multiple_results_for_cases(self, results_client, test_run_with_results, api_client, sandbox_project_id,
                                            testzilla_suite_id):
        """Test adding multiple results for cases at once."""
        # Get some case IDs from the suite
        cases_response = api_client.send_get(f"get_cases/{sandbox_project_id}&suite_id={testzilla_suite_id}&limit=2")

        if cases_response.get('size', 0) < 2:
            pytest.skip("Not enough test cases found in testzilla suite")

        case_ids = [case['id'] for case in cases_response['cases'][:2]]

        results_data = [
            {
                'case_id': case_ids[0],
                'status_id': 1,
                'comment': 'Bulk case result 1',
                'elapsed': '20s'
            },
            {
                'case_id': case_ids[1],
                'status_id': 4,
                'comment': 'Bulk case result 2',
                'elapsed': '35s'
            }
        ]

        results = results_client.add_results_for_cases(test_run_with_results, results_data)

        assert isinstance(results, list)
        assert len(results) == 2
        assert results[0]['status_id'] == 1
        assert results[1]['status_id'] == 4


class TestResultsErrorHandling:
    """Test error handling scenarios for Results."""

    def test_invalid_test_id_type(self, results_client):
        """Test that invalid test ID types are handled properly."""
        with pytest.raises((TypeError, ValueError, Exception)):
            results_client.get_results("invalid_id")

    def test_invalid_test_id_fails(self, results_client):
        """Test that using invalid test ID fails."""
        with pytest.raises(Exception):
            results_client.get_results(99999)

    def test_invalid_run_id_fails(self, results_client):
        """Test that using invalid run ID fails."""
        with pytest.raises(Exception):
            results_client.get_results_for_run(99999)

    def test_invalid_case_id_fails(self, results_client, test_run_with_results):
        """Test that using invalid case ID fails."""
        with pytest.raises(Exception):
            results_client.get_results_for_case(test_run_with_results, 99999)

    def test_add_result_invalid_test_fails(self, results_client):
        """Test that adding result to invalid test fails."""
        with pytest.raises(Exception):
            results_client.add_result(99999, status_id=1, comment="Test")

    def test_add_result_invalid_status_fails(self, results_client, test_id):
        """Test that adding result with invalid status fails."""
        with pytest.raises(Exception):
            results_client.add_result(test_id, status_id=99, comment="Test")

    def test_add_result_for_case_invalid_run_fails(self, results_client, test_case_id):
        """Test that adding result for invalid run fails."""
        with pytest.raises(Exception):
            results_client.add_result_for_case(99999, test_case_id, status_id=1)

    def test_add_results_invalid_run_fails(self, results_client):
        """Test that adding bulk results to invalid run fails."""
        results_data = [{'test_id': 1, 'status_id': 1, 'comment': 'Test'}]
        with pytest.raises(Exception):
            results_client.add_results(99999, results_data)

    def test_add_results_empty_list_fails(self, results_client, test_run_with_results):
        """Test that adding empty results list fails."""
        with pytest.raises(Exception):
            results_client.add_results(test_run_with_results, [])


class TestResultsDataValidation:
    """Test data validation and response structure for Results."""

    def test_results_list_response_structure(self, results_client, test_run_with_results):
        """Test that results list response has expected structure."""
        response = results_client.get_results_for_run(test_run_with_results)

        required_fields = ['results', 'offset', 'limit', 'size']
        for field in required_fields:
            assert field in response, f"Missing required field: {field}"

        assert isinstance(response['results'], list)
        assert isinstance(response['offset'], int)
        assert isinstance(response['limit'], int)
        assert isinstance(response['size'], int)

        # If results exist, test their structure
        if response['size'] > 0:
            result = response['results'][0]
            required_result_fields = ['id', 'status_id', 'test_id', 'created_by', 'created_on']
            for field in required_result_fields:
                assert field in result, f"Missing required field in result: {field}"

            # Test data types
            assert isinstance(result['id'], int)
            assert isinstance(result['status_id'], int)
            assert isinstance(result['test_id'], int)
            assert isinstance(result['created_by'], int)
            assert isinstance(result['created_on'], int)

    def test_result_response_structure(self, results_client, test_run_with_results, test_case_id, test_result_data):
        """Test that individual result response has expected structure."""
        # Create a result first
        result = results_client.add_result_for_case(
            test_run_with_results,
            test_case_id,
            **test_result_data
        )

        required_fields = [
            'id', 'status_id', 'test_id', 'created_by', 'created_on',
            'comment', 'elapsed', 'version'
        ]
        for field in required_fields:
            assert field in result, f"Missing required field: {field}"

        # Test data types
        assert isinstance(result['id'], int)
        assert isinstance(result['status_id'], int)
        assert isinstance(result['test_id'], int)
        assert isinstance(result['created_by'], int)
        assert isinstance(result['created_on'], int)
        if result['comment'] is not None:
            assert isinstance(result['comment'], str)
        if result['elapsed'] is not None:
            assert isinstance(result['elapsed'], str)
        if result['version'] is not None:
            assert isinstance(result['version'], str)

    def test_results_filtering_validation(self, results_client, test_run_with_results):
        """Test that filtering parameters work correctly."""
        # Test created_by filter with list
        response = results_client.get_results_for_run(test_run_with_results, created_by=[1, 2], limit=5)
        assert response['limit'] == 5

        # Test status_id filter with single value
        response = results_client.get_results_for_run(test_run_with_results, status_id=1, limit=5)
        assert response['limit'] == 5

        # Test status_id filter with list
        response = results_client.get_results_for_run(test_run_with_results, status_id=[1, 5], limit=5)
        assert response['limit'] == 5

    def test_bulk_results_validation(self, results_client, test_run_with_results, api_client):
        """Test that bulk result operations handle various parameter combinations."""
        # Get a test ID from the run
        tests_response = api_client.send_get(
            f"get_tests/{test_run_with_results}")

        # Handle different possible response formats
        if isinstance(tests_response, dict) and 'tests' in tests_response:
            tests = tests_response['tests']
        elif isinstance(tests_response, list):
            tests = tests_response
        else:
            pytest.skip("Unexpected tests response format")

        if not tests or len(tests) == 0:
            pytest.skip("No tests found in test run")

        test_id = tests[0]['id']

        # Test minimal bulk result
        minimal_results = [
            {
                'test_id': test_id,
                'status_id': 1,
                'comment': 'Minimal bulk result'
            }
        ]
        results = results_client.add_results(test_run_with_results, minimal_results)
        assert len(results) == 1
        assert results[0]['status_id'] == 1

        # Test bulk result with all fields
        full_results = [
            {
                'test_id': test_id,
                'status_id': 5,
                'comment': 'Full bulk result',
                'elapsed': '45s',
                'version': '2.0.0-test',
                'defects': 'BUG-123'
            }
        ]
        results = results_client.add_results(test_run_with_results, full_results)
        assert len(results) == 1
        assert results[0]['status_id'] == 5
        assert results[0]['comment'] == 'Full bulk result'
        assert results[0]['elapsed'] in ['45s', '45sec']
        assert results[0]['version'] == '2.0.0-test'
        assert results[0]['defects'] == 'BUG-123'

    def test_custom_fields_validation(self, results_client, test_id):
        """Test that custom fields are properly handled."""
        custom_result_data = {
            'status_id': 1,
            'comment': 'Test with custom fields',
            'custom_step_results': [
                {
                    'content': 'Validation Step',
                    'expected': 'Should pass validation',
                    'actual': 'Validation passed',
                    'status_id': 1
                }
            ]
        }

        result = results_client.add_result(test_id, **custom_result_data)

        assert result['status_id'] == 1
        assert result['comment'] == 'Test with custom fields'
        assert 'custom_step_results' in result
        assert isinstance(result['custom_step_results'], list)
