import asyncio
from typing import Any

import websockets
from loguru import logger


class WebSocketClient:
    """Class for doing websocket operations."""

    def __init__(self, uri: str) -> None:
        """Initialize a new instance."""
        self.uri = uri
        self.websocket = None
        self.lock = asyncio.Lock()

    async def connect(self, timeout: int = 5) -> None:
        """Connect to the websocket."""
        async with self.lock:
            if self.is_connected():
                logger.debug("Already connected to the websocket.")
                return

            try:
                self.websocket = await websockets.connect(self.uri, open_timeout=timeout)
            except (
                websockets.exceptions.ConnectionClosedError,
                websockets.exceptions.InvalidURI,
                asyncio.TimeoutError,
            ):
                logger.exception("Connection error")
                raise

    async def send_message(self, message: str) -> None:
        """Send message to the websocket."""
        if self.websocket is None:
            raise ConnectionError("WebSocket is not connected.")
        await self.websocket.send(message)

    async def receive_message(self, timeout: int = 5) -> Any:
        """Receive message from the websocket, optionally waiting for a specific condition."""
        if self.websocket is None:
            raise ConnectionError("WebSocket is not connected.")

        try:
            response = await asyncio.wait_for(self.websocket.recv(), timeout)
            return response
        except asyncio.TimeoutError:
            logger.exception("Timeout: No response received within the specified time.")
            raise

    async def close(self) -> None:
        """Close the connection to the websocket."""
        async with self.lock:
            if self.websocket is not None:
                ws = self.websocket
                self.websocket = None
                try:
                    await ws.close()
                except Exception:
                    pass

                # Cancel any still-running websockets legacy background tasks
                # (transfer_data_task, keepalive_ping_task, close_connection_task)
                # so they exit cleanly before the loop is torn down.
                internal_tasks: list[asyncio.Task] = [
                    t
                    for attr in (
                        "transfer_data_task",
                        "keepalive_ping_task",
                        "close_connection_task",
                    )
                    if isinstance(t := getattr(ws, attr, None), asyncio.Task)
                    and not t.done()
                ]
                if internal_tasks:
                    for task in internal_tasks:
                        task.cancel()
                    await asyncio.gather(*internal_tasks, return_exceptions=True)
                # One extra tick so any transport.call_connection_lost callbacks
                # scheduled via loop.call_soon() are executed before we return.
                await asyncio.sleep(0)

    def is_connected(self) -> bool:
        """Check if the websocket is connected."""
        return self.websocket is not None and self.websocket.open


class WebSocketClientSync:
    """Class for using the WebSocketClient in a synchronous way."""

    def __init__(self, uri: str) -> None:
        """Initialize a new instance."""
        self.client = WebSocketClient(uri)
        self._loop_created = False

        try:
            self.loop = asyncio.get_running_loop()
        except RuntimeError:
            # No running loop, create a new one
            self.loop = asyncio.new_event_loop()
            asyncio.set_event_loop(self.loop)
            self._loop_created = True

    def __del__(self) -> None:
        """Destructor called when an instance is destroyed.

        Properly close WebSocket connection and clean up event loop.
        """
        try:
            # Step 1: Close the WebSocket connection first (if we have a loop)
            if (
                hasattr(self, "loop")
                and self.loop is not None
                and not self.loop.is_closed()
                and not self.loop.is_running()
            ):
                # Close the websocket if connected
                if self.client.is_connected():
                    try:
                        coro = self.client.close()
                        self.loop.run_until_complete(coro)
                    except Exception:
                        # Websocket might already be closing
                        pass

                # Step 2: Cancel and wait for all pending tasks to complete
                if getattr(self, "_loop_created", False):
                    try:
                        # Get all pending tasks
                        pending = asyncio.all_tasks(self.loop)
                        if pending:
                            # Cancel all tasks
                            for task in pending:
                                task.cancel()

                            # Wait for all tasks to handle cancellation
                            # This ensures tasks like close_connection, keepalive_ping, etc. complete
                            self.loop.run_until_complete(
                                asyncio.gather(*pending, return_exceptions=True)
                            )

                        # Drain any remaining transport/connection-lost callbacks
                        # that were scheduled via loop.call_soon() during task
                        # cancellation so they run while the loop is still open.
                        self.loop.run_until_complete(asyncio.sleep(0))

                        # Step 3: Now it's safe to close the event loop
                        self.loop.close()
                    except Exception:
                        # Don't raise from __del__, but loop cleanup failed
                        pass
        except RuntimeError:
            # Event loop might be in an unexpected state
            pass
        except Exception:
            # Never raise from __del__
            pass

    def connect(self) -> None:
        """Connect to the websocket."""
        if self.loop.is_closed():
            raise RuntimeError("Event loop is closed")
        self.loop.run_until_complete(self.client.connect())

    def send_message(self, message: str) -> None:
        """Send message to the websocket."""
        if self.loop.is_closed():
            raise RuntimeError("Event loop is closed")
        self.loop.run_until_complete(self.client.send_message(message))

    def receive_message(self, timeout: int = 5) -> Any:
        """Receive message from the websocket."""
        if self.loop.is_closed():
            raise RuntimeError("Event loop is closed")
        return self.loop.run_until_complete(self.client.receive_message(timeout))

    def close(self) -> None:
        """Close the connection to the websocket."""
        if not self.loop.is_closed():
            self.loop.run_until_complete(self.client.close())

    def is_connected(self) -> bool:
        """Check if the websocket client is connected."""
        return self.client.is_connected()
