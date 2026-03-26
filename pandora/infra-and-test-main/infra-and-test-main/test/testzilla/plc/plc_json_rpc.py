import atexit
import json
import threading
from pprint import pformat
from typing import Any

import requests
import urllib3
from loguru import logger

from .models import (
    ApiLogin,
    JsonRpcError,
    JsonRpcRequest,
    JsonRpcResponse,
    PlcProgramBrowse,
    PlcProgramRead,
    PlcProgramWrite,
)


class AuthenticationError(Exception):
    def __init__(self, message: str):
        super().__init__(message)


class PlcReadError(Exception):
    def __init__(self, message: str):
        super().__init__(message)


class PlcJsonRpc:
    def __init__(self, url: str, token_keep_alive_interval: int = 60) -> None:
        """Initialize a new instance."""
        self.cpu_id = None
        self.url = url
        self._user = None
        self._password = None
        self._token = None

        # Disble this warning to avoid log spam due to PLC self-signed certificate.
        urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

        # Create a separate thread to make sure the token validity time does not expire.
        self._stop_event = threading.Event()
        self._daemon = threading.Thread(
            target=self._token_keep_alive,
            args=(token_keep_alive_interval,),
            daemon=True,
            name="plc_token_keep_alive",
        )

        # Register a cleanup function to be run at normal interpreter termination.
        atexit.register(self._cleanup)

    def _cleanup(self) -> None:
        """Cleanup function."""
        if self._daemon.is_alive():
            self._stop_event.set()
            self._daemon.join(timeout=5)

        if self._token is not None:
            try:
                self.logout()
            except (requests.RequestException, ValueError):
                logger.exception("Failed to logout!")

    def _token_keep_alive(self, interval: int) -> None:
        """Periodically ping the PLC with the token to extend its validity."""
        while not self._stop_event.wait(interval):
            result, error = self.ping(authenticate=True)

            if error:
                logger.warning(f"Failed to extend token validity: {error}")

            if not result:
                logger.warning("Failed to extend token validity!")

    def send_request(
        self,
        data: JsonRpcRequest | list[JsonRpcRequest],
        authenticate: bool = True,
        verify_ssl: bool = False,
        timeout: int = 5,
    ) -> JsonRpcResponse | list[JsonRpcResponse]:
        """Send HTTP POST request with the given payload and options."""

        headers = {"Content-Type": "application/json"}

        if authenticate:
            if not self._token:
                raise AuthenticationError("Authentication required but token is missing.")
            headers["X-Auth-Token"] = self._token

        # Convert data to JSON
        if isinstance(data, list):
            json_data = json.dumps([req.model_dump() for req in data])
        else:
            json_data = data.model_dump_json()

        try:
            response = requests.post(
                self.url,
                headers=headers,
                data=json_data,
                verify=verify_ssl,
                timeout=timeout,
            )
            response.raise_for_status()
        except requests.RequestException:
            logger.exception(f"Request to {self.url} with payload {data} failed!")
            raise

        try:
            response_data = response.json()
        except ValueError:
            logger.exception(f"Failed to parse JSON response from {self.url}: {response.text}")
            raise

        if isinstance(response_data, list):
            return [JsonRpcResponse(**resp) for resp in response_data]

        return JsonRpcResponse(**response_data)

    def login(self, user: str = "Anonymous", password: str = "") -> None:
        """Authenticate the user and open a Web API session."""

        self._user = user
        self._password = password

        payload = ApiLogin(
            id="test",
            params={
                "user": self._user,
                "password": self._password,
            },
        )

        response = self.send_request(data=payload, authenticate=False)

        if response.error:
            if response.error.code == 101:
                logger.debug("User is already authenticated and token is valid!")
                return

            raise AuthenticationError(f"Authentication failed: {response.error.code} {response.error.message}")

        if not response.result or "token" not in response.result:
            logger.debug(f"Response result: {response.result}")
            raise AuthenticationError("Failed to acquire a valid token from the server.")

        logger.debug("Successfully acquired authentication token.")
        self._token = response.result["token"]

        if not self._daemon.is_alive():
            self._daemon.start()

    def logout(self) -> tuple[bool | None, JsonRpcError | None]:
        """Remove the token from the list of active Web API sessions and end the session."""

        payload = JsonRpcRequest(method="Api.Logout")

        response = self.send_request(data=payload, authenticate=False)

        if response.error:
            logger.warning(f"Failed to logout session: {response.error.code} {response.error.message}")
        elif not response.result:
            logger.warning("Failed to logout session!")

        return response.result, response.error

    def browse(
        self, var: str = None, mode: str = "children", browse_type: list[str] = None
    ) -> tuple[list[dict[str, Any]], JsonRpcError | None]:
        """Search for tags and the corresponding metadata.

        Requires "read_value" authorization.
        """

        payload = PlcProgramBrowse(
            params={
                "mode": mode,
                "var": var,
                "type": browse_type,
            },
        )

        response = self.send_request(data=payload)

        return response.result, response.error

    def ping(self, authenticate: bool = False) -> tuple[str | None, JsonRpcError | None]:
        """Ping the PLC.

        Returns a unique ID for the CPU used. The system assigns
        a new, unique CPU ID after each restart or warm start of the CPU.
        """
        payload = JsonRpcRequest(method="Api.Ping")

        response = self.send_request(
            data=payload,
            authenticate=authenticate,
        )

        if response.result != self.cpu_id:
            logger.debug(f"Store new CPU ID: {response.result}")
            self.cpu_id = response.result

        return response.result, response.error

    def read(self, var: str, mode: str = "simple") -> tuple[Any, JsonRpcError | None]:
        """Get tag value.

        Requires "read_value" authorization.
        """
        payload = PlcProgramRead(
            params={
                "var": var,
                "mode": mode,
            },
        )

        response = self.send_request(data=payload)

        return response.result, response.error

    def write(self, var: str, value: Any, mode: str = "simple") -> tuple[bool, JsonRpcError | None]:
        """Write tag value.

        Requires "write_value" authorization.
        """
        payload = PlcProgramWrite(
            params={
                "var": var,
                "value": value,
                "mode": mode,
            },
        )

        logger.debug(f"Writing value '{value}' to variable '{var}'")
        response = self.send_request(data=payload)

        return response.result, response.error

    def bulk_request(self, methods: list[JsonRpcRequest]) -> list[tuple[Any, JsonRpcError | None]]:
        """Send multiple method calls in a single request.

        While bulk operations are not explicitly limited by a fixed number of method calls,
        there is a limit for the HTTP request body.
        The limit differs depending on the firmware version of the CPU:
        • Limit of 64 KB for CPUs with firmware version ≤ V3.0
        • Limit of 128 KB for CPUs as of firmware version ≥ V3.1

        """

        # Ensure each request has a unique ID
        for i, method in enumerate(methods, start=1):
            method.id = i

        logger.debug(f"Sending the following commands in bulk:\n{pformat(methods)}")

        responses = self.send_request(data=methods)

        return [(response.result, response.error) for response in responses]
