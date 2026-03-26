"""
https://gitlab.com/esab/abw/adaptio/-/blob/a3e97d79095207afdae559d742b36dbecdbadc00/docs/WebHMI_Interface_Description.md
"""

import asyncio
import json
import os
import time
from typing import Any, Callable, Dict, List, Union

import websockets.exceptions as websocketsExc
from loguru import logger
from pydantic import BaseModel
from testzilla.utility.websocket_client import WebSocketClientSync

class AdaptioWebHmiMessage(BaseModel):
    """Base class for the Adaptio WebHMI message format."""

    name: str
    payload: Union[Dict[str, Any], List[Any]]
    result: str | None = None

    def __str__(self):
        return self.model_dump_json()


def create_name_condition(name: str) -> Callable[[Any], bool]:
    """Create condition for matching name in the message data."""

    def condition(message: Any) -> bool:
        data = json.loads(message)
        return data.get("name") == name

    return condition


class AdaptioWebHmi:
    """Client for interacting with the Adaptio WebHMI server via WebSocket.
    
    This class provides methods to connect to, send messages to, and receive
    messages from the Adaptio WebHMI server using the WebSocket protocol.
    """
    def __init__(self, uri: str | None = None) -> None:
        """Initialize a new instance.

        Args:
            uri: WebSocket URI for the Adaptio WebHMI server. If not provided,
                 the value of the ``ADAPTIO_WEB_HMI_URI`` environment variable
                 is used. Raises ``ValueError`` when neither is supplied.
        """
        if uri is None:
            uri = os.getenv("ADAPTIO_WEB_HMI_URI")
            if uri is None:
                raise ValueError(
                    "WebHMI URI must be provided either as the 'uri' argument "
                    "or via the ADAPTIO_WEB_HMI_URI environment variable"
                )
        self.uri = uri
        self.ws_client = WebSocketClientSync(uri=self.uri)
        self._closed = False

    def __del__(self) -> None:
        """Destructor called when an instance is destroyed."""
        self.close()

    def close(self) -> None:
        """Explicitly close the WebSocket connection."""
        if not getattr(self, "_closed", False) and hasattr(self, "ws_client"):
            try:
                # WebSocketClientSync.close() is synchronous and handles cleanup properly
                if hasattr(self.ws_client, "close") and callable(self.ws_client.close):
                    self.ws_client.close()
            except RuntimeError:
                pass
            except Exception:
                pass
            finally:
                self._closed = True

    def connect(self, retries=3, retry_delay=1) -> None:
        """Connect to the websocket."""
        if self._closed:
            raise RuntimeError("AdaptioWebHmi instance has been closed")

        attempt = 1
        while not self.ws_client.is_connected():
            if attempt > retries:
                raise ConnectionError("Failed to connect to WebSocket after multiple attempts.")

            if attempt > 1:
                logger.warning(f"Client not connected. Attempting to reconnect (attempt {attempt}/{retries})...")

            try:
                self.ws_client.connect()
            except (
                websocketsExc.ConnectionClosedError,
                websocketsExc.InvalidURI,
                asyncio.TimeoutError,
            ):
                logger.exception(f"Connection error during attempt {attempt}/{retries}")
                attempt += 1
                time.sleep(retry_delay)
                continue

    def send_message(self, message: AdaptioWebHmiMessage) -> None:
        """Send message to the websocket client."""
        if self._closed:
            raise RuntimeError("AdaptioWebHmi instance has been closed")
        self.connect()
        self.ws_client.send_message(str(message))

    def receive_message(
        self, condition: Callable[[Any], bool] | None = None, max_retries: int = 5
    ) -> AdaptioWebHmiMessage:
        """Wait for a message that match the condition."""
        if self._closed:
            raise RuntimeError("AdaptioWebHmi instance has been closed")
        self.connect()

        retries = 0
        while retries < max_retries:
            response = self.ws_client.receive_message()
            if condition is None or condition(response):
                return AdaptioWebHmiMessage.model_validate_json(response)
            retries += 1

        raise TimeoutError("Max retries reached without receiving the expected message.")

    def send_and_receive_message(
        self, condition, request_name: str, response_name: str, payload: Dict[str, Any]
    ) -> AdaptioWebHmiMessage:
        """Create the message and send it."""
        if self._closed:
            raise RuntimeError("AdaptioWebHmi instance has been closed")

        message = AdaptioWebHmiMessage(name=request_name, payload=payload)

        if not condition:
            condition = create_name_condition(name=response_name)

        self.send_message(message)

        response = self.receive_message(condition)

        return response

    def send_and_receive_data(
        self,
        condition,
        request_name: str,
        response_name: str,
        payload: Dict[str, Any],
        message: Dict[str, Any] | str | None,
    ) -> AdaptioWebHmiMessage:
        """Create the message and send it."""
        if self._closed:
            raise RuntimeError("AdaptioWebHmi instance has been closed")

        data_payload = dict(payload)
        if message is not None:
            data_payload["message"] = message

        data = AdaptioWebHmiMessage(name=request_name, payload=data_payload)

        if not condition:
            condition = create_name_condition(name=response_name)

        self.send_message(data)

        response = self.receive_message(condition)

        return response
