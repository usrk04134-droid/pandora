import socket
from pathlib import Path
from typing import List, Union

from fabric import Config, Connection
from invoke.exceptions import Failure
from invoke.runners import Result
from loguru import logger
from paramiko.ssh_exception import SSHException

from testzilla.utility.rsync import CopyDirection, RemoteRsyncCmdBuilder


class RemoteHostManager:
    """A class to communicate with a remote host."""

    # Timeout in seconds for executing commands on the local/remote host.
    # Prevents the script from hanging indefinitely if a command
    # takes too long or the connection is lost.
    EXECUTION_TIMEOUT = 60

    # Timeout in seconds for establishing the initial SSH connection
    # # to the remote host.  This prevents the script from getting stuck
    # if the remote host is unreachable or the network is down.
    CONNECTION_TIMEOUT = 30

    def __init__(
        self,
        hostname: str,
        username: str,
        password: str,
        connect_timeout: int = CONNECTION_TIMEOUT,
    ) -> None:
        """Initialize the RemoteHostManager instance."""
        self._hostname = hostname
        self._username = username
        self._password = password

        self._config = Config(
            overrides={
                "sudo": {
                    "password": self._password,
                },
                "run": {
                    "in_stream": False,  # Disable stdin reading to fix pytest conflicts
                },
                "timeouts": {
                    "connect": connect_timeout,
                },
                "connect_kwargs": {
                    "password": password,
                },
            }
        )

        self._connection = Connection(
            host=hostname,
            user=username,
            config=self._config,
        )

    def _execute_local_command(self, command: str, timeout: int) -> Result | None:
        """Execute a command on the local host."""
        logger.debug(f"Executing command '{command}'")
        result = self._connection.local(
            command=command,
            hide=True,
            timeout=timeout,
        )

        return result

    def _execute_remote_command(self, command: str, sudo: bool, timeout: int) -> Result:
        """Execute a command on the remote host."""
        if sudo:
            logger.debug(f"Executing command '{command}' with sudo")
            # Use pty=True only for sudo (required for password prompts)
            result = self._connection.sudo(
                command=command,
                hide=True,
                pty=True,
                timeout=timeout,
            )
        else:
            logger.debug(f"Executing command '{command}' with no sudo")
            result = self._connection.run(
                command=command,
                hide=True,
                timeout=timeout,
            )

        return result

    def execute_command(
        self,
        command: str,
        local: bool = False,
        sudo: bool = False,
        timeout: int = EXECUTION_TIMEOUT,
    ) -> tuple[str, str, int]:
        """Execute a command on the local or remote host.

        Returns:
            tuple[str, str, int]: (stdout, stderr, exit_code)
        """
        if local:
            result = self._execute_local_command(command=command, timeout=timeout)
        else:
            result = self._execute_remote_command(command=command, sudo=sudo, timeout=timeout)

        if result is not None:
            logger.debug(f"Command output: {result.stdout.strip()}")
            logger.debug(f"Command error: {result.stderr.strip()}")
            logger.debug(f"Command exit code: {result.exited}")
            return result.stdout.strip(), result.stderr.strip(), result.exited

        logger.debug("Command result is None")
        return "", "", 1

    def _copy_dir_content_to_remote_with_no_sudo(self, local_path: Path, remote_path: Path) -> None:
        """Copy content of the local path to a remote path that does not require superuser privilege."""
        logger.info(f"Copy content of {local_path} to {remote_path} with no sudo")
        self.execute_command(command=f"mkdir -p {remote_path}")

        rsync_cmd_builder = RemoteRsyncCmdBuilder(
            local_paths=[local_path],
            remote_paths=[remote_path],
            hostname=self._hostname,
            username=self._username,
            password=self._password,
        )
        self.execute_command(
            command=rsync_cmd_builder.get_command(copy_direction=CopyDirection.FROM_LOCAL, copy_contents_only=True),
            local=True,
        )

    def _copy_dir_content_to_remote_with_sudo(self, local_path: Path, remote_path: Path) -> None:
        """Copy content of the local path to a remote path that requires superuser privilege."""
        logger.info(f"Copy content of {local_path} to {remote_path} with sudo")

        temp_remote_path = None
        try:
            logger.info(f"Copy {local_path} to a temporary remote path")
            temp_remote_path = Path(self.execute_command(command="mktemp -d")[0])
            logger.debug(f"Temporary remote path: {temp_remote_path}")

            self._copy_dir_content_to_remote_with_no_sudo(local_path=local_path, remote_path=temp_remote_path)

            logger.info(f"Copy from {temp_remote_path} to {remote_path}")
            self.execute_command(command=f"mkdir -p {remote_path}", sudo=True)
            self.execute_command(command=f"chmod 755 {remote_path}", sudo=True)
            self.execute_command(command=f"cp -r {temp_remote_path}/. {remote_path}", sudo=True)
        except (SSHException, socket.error, Failure, OSError):
            msg = f"Problem copying content of {local_path} to {remote_path}"
            logger.exception(msg)
            raise
        finally:
            if temp_remote_path:
                logger.info(f"Removing temp dir: {temp_remote_path}")
                self.execute_command(command=f"rm -rf {temp_remote_path}")

    def copy_dir_content_to_remote(self, local_path: Path, remote_path: Path, sudo: bool = False) -> None:
        """Copy content of the local path to a remote path."""

        logger.info(f"Copy contents of {local_path} to {remote_path}")

        if not local_path.is_dir():
            raise ValueError(f"Local path {local_path} needs to be a directory")

        backup_path = None
        try:
            logger.info(f"Backup remote path {remote_path}")
            backup_path = Path(self.execute_command(command="mktemp -d")[0])
            logger.debug(f"Backup path: {backup_path}")

            self.execute_command(command=f"cp -r {remote_path}/. {backup_path}", sudo=sudo)

            if sudo:
                self._copy_dir_content_to_remote_with_sudo(local_path=local_path, remote_path=remote_path)
            else:
                self._copy_dir_content_to_remote_with_no_sudo(local_path=local_path, remote_path=remote_path)
        except (SSHException, socket.error, Failure, OSError, TypeError):
            logger.exception(f"Problem copying content of {local_path} to {remote_path}")

            self.execute_command(command=f"find {remote_path} -mindepth 1 -delete", sudo=sudo)
            logger.info(f"Restore remote path {remote_path} from backup {backup_path}")
            self.execute_command(command=f"cp -r {backup_path}/. {remote_path}", sudo=sudo)
            raise
        finally:
            if backup_path:
                logger.info(f"Remove the backup path {backup_path}")
                self.execute_command(command=f"rm -rf {backup_path}", sudo=sudo)

    def fetch_directory_from_remote(
        self,
        local_path: Path,
        remote_paths: Union[Path, List[Path]],
        timeout: int = EXECUTION_TIMEOUT,
    ) -> None:
        """Fetch directories from the remote host."""

        def _check_path_type_validity(paths: List[Path]):
            """Check that the provided paths are valid."""
            logger.debug(f"Checking type validity of {paths}")

            for path in paths:
                if not isinstance(path, Path):
                    raise TypeError(f"Provided path '{path}' should be of type {Path} and not {type(path)}")

        logger.info(f"Fetch contents of remote path {remote_paths} to {local_path}")
        remote_paths = [remote_paths] if not isinstance(remote_paths, list) else remote_paths

        try:
            _check_path_type_validity(remote_paths + [local_path])
            local_path.mkdir(parents=True, exist_ok=True)

            rsync_cmd_builder = RemoteRsyncCmdBuilder(
                local_paths=[local_path],
                remote_paths=remote_paths,
                hostname=self._hostname,
                username=self._username,
                password=self._password,
            )
            self.execute_command(
                command=rsync_cmd_builder.get_command(
                    copy_direction=CopyDirection.FROM_REMOTE, copy_contents_only=False
                ),
                local=True,
                timeout=timeout,
            )
        except (Failure, OSError, TypeError):
            logger.exception(f"Problem fetching from {remote_paths} to {local_path}")
            raise

    def close_connection(self) -> None:
        """Close the connection. Users should call this explicitly when they are done with the connection."""
        if self._connection:
            self._connection.close()

    def __del__(self) -> None:
        """Destructor called when an instance is destroyed. This is a last resort mechanism to close the
        connection if it is not. Users should call `close_connection` when they are done.
        """
        if hasattr(self, "_connection") and self._connection:
            self.close_connection()
