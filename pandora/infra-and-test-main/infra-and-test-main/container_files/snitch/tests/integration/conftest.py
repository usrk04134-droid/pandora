"""Shared fixtures for integration tests."""
import os
import pytest
from snitch.api_client import TestRailAPIClient
from snitch.projects import Projects
from snitch.runs import Runs


@pytest.fixture(scope="session")
def api_client():
    """Create TestRail API client for testing."""
    base_url = os.getenv('TESTRAIL_URL', 'https://esabgrnd.testrail.com')
    username = os.getenv('TESTRAIL_USERNAME', 'team-godzilla@esab.onmicrosoft.com')
    api_key = os.getenv('TESTRAIL_API_KEY')

    if not api_key:
        pytest.skip("TESTRAIL_API_KEY environment variable not set")

    return TestRailAPIClient(base_url, username, api_key)


@pytest.fixture(scope="session")
def projects_client(api_client):
    """Create Projects wrapper for testing."""
    return Projects(api_client)


@pytest.fixture(scope="session")
def sandbox_project_id(projects_client):
    """Get Sandbox project ID for testing."""
    projects_response = projects_client.get_projects()

    for project in projects_response.get('projects', []):
        if project['name'].lower() == 'sandbox':
            return project['id']

    pytest.skip("Sandbox project not found in TestRail instance")


@pytest.fixture(scope="session")
def testzilla_suite_id(api_client, sandbox_project_id):
    """Get Testzilla suite ID from the sandbox project."""
    suites_response = api_client.send_get(f"get_suites/{sandbox_project_id}")

    for suite in suites_response:
        if suite['name'].lower() == 'testzilla':
            return suite['id']

    pytest.skip("Testzilla suite not found in Sandbox project")


@pytest.fixture(scope="session")
def test_section_id(api_client, sandbox_project_id, testzilla_suite_id):
    """Get a test section ID from the Testzilla suite."""
    sections_response = api_client.send_get(f"get_sections/{sandbox_project_id}&suite_id={testzilla_suite_id}")

    # Handle the response structure - sections API returns a dict with 'sections' key
    if isinstance(sections_response, dict) and 'sections' in sections_response:
        sections = sections_response['sections']
    else:
        sections = sections_response

    if not sections:
        pytest.skip("No sections found in Testzilla suite")

    return sections[0]['id']


@pytest.fixture(scope="session")
def test_case_data():
    """Test data for creating cases."""
    return {
        'title': 'Integration Test Case - Auto Generated',
        'estimate': '5m',
        'refs': 'INT-TEST-001',
        'custom_preconds': 'Test preconditions for integration test',
        'custom_steps': 'Step 1: Execute test\nStep 2: Verify results',
        'custom_step_results': 'Test passed successfully'
    }

@pytest.fixture(scope="session")
def runs_client(api_client):
    """Create Runs wrapper for testing."""
    return Runs(api_client)


def test_connection():
    """Quick test to verify TestRail connection works."""
    try:
        client = TestRailAPIClient(
            base_url=os.getenv('TESTRAIL_URL', 'https://esabgrnd.testrail.com'),
            username=os.getenv('TESTRAIL_USERNAME', 'team-godzilla@esab.onmicrosoft.com'),
            api_key=os.getenv('TESTRAIL_API_KEY')
        )
        projects = Projects(client)
        response = projects.get_projects()
        return len(response.get('projects', [])) > 0
    except Exception as e:
        print(f"Connection test failed: {e}")
        return False
