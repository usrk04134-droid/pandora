"""
Module for doing socket operations. This implementation is not
thread safe.
"""

import socket
import time
from ipaddress import IPv4Address

from loguru import logger


class SocketManager:
    """Class for doing socket operations. Not thread-safe."""

    TIMEOUT = 2
    RETRIES = 5
    DELAY = 1.0

    def __init__(self, ip_address: IPv4Address, port: int) -> None:
        """Initialize a new instance."""
        self.ip_address = str(ip_address)
        self.port = port
        self.sock = None

    @property
    def is_connected(self) -> bool:
        """Check if socket is connected and alive."""
        if self.sock is None:
            return False

        try:
            # Test connection with zero-byte send
            self.sock.send(b"", socket.MSG_DONTWAIT)
            return True
        except (OSError, socket.error):
            # Socket is dead, clean it up
            self._cleanup_socket()
            return False

    def _cleanup_socket(self) -> None:
        """Internal method to clean up dead socket."""
        if self.sock:
            try:
                self.sock.close()
            except OSError:
                pass  # Already closed
            self.sock = None

    def connect(self, timeout: int = TIMEOUT, retries: int = RETRIES, delay: float = DELAY) -> "SocketManager":
        """Connect to the socket, reusing if possible. Returns self for chaining."""
        # If already connected and alive, return immediately
        if self.is_connected:
            return self

        # Clean up any dead socket first
        self._cleanup_socket()

        attempt = 0
        last_error = None
        while attempt <= retries:
            try:
                self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                self.sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
                self.sock.settimeout(timeout)
                logger.info(f"Attempt {attempt}: Connecting to ({self.ip_address}, {self.port})")
                self.sock.connect((self.ip_address, self.port))
                logger.info("Socket connected")
                return self
            except OSError as e:
                last_error = e
                logger.exception(f"Failed to connect to TCP socket due to: {e}")
                self._cleanup_socket()
                attempt += 1
                if attempt <= retries:
                    time.sleep(delay)

        raise OSError(f"Failed to connect after {retries} retries: {last_error}") from last_error

    def send(self, data: bytes) -> None:
        """Send data, auto-connecting if necessary."""
        if not self.is_connected:
            self.connect()

        if self.sock is None:
            raise OSError("Socket is not connected.")

        try:
            self.sock.sendall(data)
        except OSError as e:
            # Connection might have died, clean up and re-raise
            self._cleanup_socket()
            raise OSError(f"Send failed: {e}") from e

    def recv(self, bufsize: int = 4096) -> bytes:
        """Receive data, auto-connecting if necessary."""
        if not self.is_connected:
            self.connect()

        if self.sock is None:
            raise OSError("Socket is not connected.")

        try:
            return self.sock.recv(bufsize)
        except OSError as e:
            # Connection might have died, clean up and re-raise
            self._cleanup_socket()
            raise OSError(f"Receive failed: {e}") from e

    def close(self) -> None:
        """Explicitly close the connection."""
        if self.sock:
            try:
                self.sock.close()
            except OSError as e:
                logger.warning(f"Exception on socket close: {e}")
            finally:
                self.sock = None
                logger.info("Socket closed")

    def __enter__(self) -> "SocketManager":
        self.connect()
        return self

    def __exit__(
        self, exc_type: type[BaseException] | None, exc_val: BaseException | None, exc_tb: object | None
    ) -> None:
        self.close()

    def __del__(self) -> None:
        self.close()
