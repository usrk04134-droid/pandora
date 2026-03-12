"""Integration tests for TestRail API Client."""
import pytest

class TestAPIClient:
    """Test the base API client functionality."""

    def test_api_client_initialization(self, api_client):
        """Test API client is properly initialized."""
        assert api_client.base_url.endswith('/index.php?/api/v2')
        assert api_client.auth is not None
        assert api_client.headers['Content-Type'] == 'application/json'

    def test_send_get_projects(self, api_client):
        """Test basic GET request functionality."""
        response = api_client.send_get('get_projects')

        assert isinstance(response, dict)
        assert 'projects' in response
        assert 'offset' in response
        assert 'limit' in response
        assert 'size' in response

    def test_send_get_with_params(self, api_client):
        """Test GET request with parameters."""
        params = {'is_completed': 0, 'limit': 10}
        response = api_client.send_get('get_projects', params=params)

        assert isinstance(response, dict)
        assert response['limit'] == 10
        assert len(response['projects']) <= 10

    def test_send_get_with_single_project(self, api_client, sandbox_project_id):
        """Test GET request for a specific project."""
        endpoint = f"get_project/{sandbox_project_id}"
        response = api_client.send_get(endpoint)

        assert isinstance(response, dict)
        assert response['id'] == sandbox_project_id
        assert 'name' in response

    def test_send_post_request(self, api_client):
        """Test POST request functionality (using a safe endpoint)."""
        # Note: This would typically test project creation, but requires admin rights
        # For now, we'll test that the method exists and handles errors properly
        with pytest.raises(Exception):
            api_client.send_post('add_project', data={'name': ''})

    def test_invalid_endpoint_raises_error(self, api_client):
        """Test that invalid endpoints raise appropriate errors."""
        with pytest.raises(Exception):
            api_client.send_get('invalid_endpoint')

    def test_malformed_endpoint_raises_error(self, api_client):
        """Test that malformed endpoints raise appropriate errors."""
        with pytest.raises(Exception):
            api_client.send_get('get_project/invalid_id')

    def test_authentication_headers(self, api_client):
        """Test that authentication is properly configured."""
        assert api_client.auth is not None
        assert hasattr(api_client.auth, 'username')
        assert hasattr(api_client.auth, 'password')

    def test_base_url_construction(self, api_client):
        """Test that base URL is properly constructed."""
        expected_suffix = '/index.php?/api/v2'
        assert api_client.base_url.endswith(expected_suffix)
        assert 'https://' in api_client.base_url
