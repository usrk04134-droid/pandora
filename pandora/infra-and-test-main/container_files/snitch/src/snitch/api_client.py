"""API Client for TestRail Projects"""
from typing import Dict, Optional, Union, Any
import requests
from requests.auth import HTTPBasicAuth
from snitch import logger


class TestRailAPIClient:
    """Client for interacting with the TestRail API.

    This class provides methods to authenticate and make requests to the TestRail API.
    """

    def __init__(self, base_url: str, username: str, api_key: str) -> None:
        """Initialize the TestRail API client.

        Args:
            base_url (str): The base URL of the TestRail instance.
            username (str): The username or email for authentication.
            api_key (str): The API key for authentication.
        """
        self.base_url = base_url.rstrip('/') + '/index.php?/api/v2'
        self.auth = HTTPBasicAuth(username, api_key)
        self.headers = {'Content-Type': 'application/json'}

        logger.debug(f"Initialized TestRail API client for {self.base_url}")
        logger.debug(f"Using username: {username}")

    def send_get(self, endpoint: str, params: Optional[Dict[str, Any]] = None) -> Union[Dict[str, Any], Any]:
        """Send a GET request to the TestRail API.

        Args:
            endpoint (str): The API endpoint to call.
            params (dict, optional): Query parameters to include in the request.

        Returns:
            dict: The JSON response from the API.

        Raises:
            requests.exceptions.HTTPError: If the request fails.
            requests.exceptions.RequestException: If there's a network or request error.
        """
        url = f"{self.base_url}/{endpoint}"
        logger.debug(f"Sending GET request to: {url}")
        if params:
            logger.debug(f"Request parameters: {params}")

        try:
            response = requests.get(url, auth=self.auth, headers=self.headers, params=params, timeout=30)
            logger.debug(f"Response status code: {response.status_code}")

            response.raise_for_status()
            result = response.json()
            logger.debug(f"Successfully retrieved data from {endpoint}")

            return result

        except requests.exceptions.HTTPError as e:
            logger.error(f"HTTP error for GET {endpoint}: {e}")
            logger.error(f"Response content: {response.text}")
            raise
        except requests.exceptions.RequestException as e:
            logger.error(f"Request error for GET {endpoint}: {e}")
            raise

    def send_post(self, endpoint: str, data: Optional[Dict[str, Any]] = None) -> Optional[Union[Dict[str, Any], Any]]:
        """Send a POST request to the TestRail API.

        Args:
            endpoint (str): The API endpoint to call.
            data (dict, optional): JSON data to include in the request body.

        Returns:
            dict or None: The JSON response from the API, or None for empty responses.

        Raises:
            requests.exceptions.HTTPError: If the request fails.
            requests.exceptions.RequestException: If there's a network or request error.
        """
        url = f"{self.base_url}/{endpoint}"
        logger.debug(f"Sending POST request to: {url}")
        if data:
            logger.debug(f"Request data keys: {list(data.keys()) if isinstance(data, dict) else 'non-dict data'}")

        try:
            response = requests.post(url, auth=self.auth, headers=self.headers, json=data, timeout=60)
            logger.debug(f"Response status code: {response.status_code}")

            response.raise_for_status()

            # Handle empty responses (like delete operations)
            if response.text.strip() == '':
                logger.debug(f"Successfully posted data to {endpoint} (empty response)")
                return None

            result = response.json()
            logger.debug(f"Successfully posted data to {endpoint}")
            return result

        except requests.exceptions.HTTPError as e:
            logger.error(f"HTTP error for POST {endpoint}: {e}")
            logger.error(f"Response content: {response.text}")
            raise
        except requests.exceptions.RequestException as e:
            logger.error(f"Request error for POST {endpoint}: {e}")
            raise
