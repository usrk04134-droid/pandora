from enum import Enum, auto
from loguru import logger
from pathlib import Path


class CopyDirection(Enum):
    """Copy direction for rsync"""

    FROM_REMOTE = auto()
    FROM_LOCAL = auto()


class RemoteRsyncCmdBuilder:
    """A class for building rsync command for copying to/from remote host"""

    def __init__(
        self,
        local_paths: list[Path],
        remote_paths: list[Path],
        hostname: str,
        username: str,
        password: str,
    ):
        self._local_paths = local_paths
        self._remote_paths = remote_paths
        self._hostname = hostname
        self._username = username
        self._password = password

    @staticmethod
    def _get_posix_paths(paths: list[Path], is_source: bool, copy_contents_only: bool) -> list[str]:
        return [(f"{path.as_posix()}/" if is_source and copy_contents_only else path.as_posix()) for path in paths]

    def _construct_remote_path(self, is_source: bool = False, copy_contents_only: bool = False) -> str:
        """Construct remote path for rsync."""
        logger.debug("Constructing remote path")
        remote_paths_posix = RemoteRsyncCmdBuilder._get_posix_paths(
            paths=self._remote_paths,
            is_source=is_source,
            copy_contents_only=copy_contents_only,
        )
        remote_path = f"{self._username}@{self._hostname}:{' :'.join(remote_paths_posix)}"
        logger.debug(f"Constructed remote path: {remote_path}")

        return remote_path

    def _construct_local_path(self, is_source: bool = False, copy_contents_only: bool = False) -> str:
        """Construct local path for rsync."""
        logger.debug("Constructing local path")
        local_paths_posix = RemoteRsyncCmdBuilder._get_posix_paths(
            paths=self._local_paths,
            is_source=is_source,
            copy_contents_only=copy_contents_only,
        )
        local_path = " ".join(local_paths_posix)
        logger.debug(f"Constructed local path: {local_path}")

        return local_path

    def _get_source_path(self, copy_direction: CopyDirection, copy_contents_only: bool) -> str:
        """Get source path."""
        return (
            self._construct_local_path(is_source=True, copy_contents_only=copy_contents_only)
            if copy_direction == CopyDirection.FROM_LOCAL
            else self._construct_remote_path(is_source=True, copy_contents_only=copy_contents_only)
        )

    def _get_destination_path(self, copy_direction: CopyDirection) -> str:
        """Get destination path."""
        return (
            self._construct_remote_path()
            if copy_direction == CopyDirection.FROM_LOCAL
            else self._construct_local_path()
        )

    def get_command(self, copy_direction: CopyDirection, copy_contents_only: bool) -> str:
        """Get the rsync command."""
        logger.debug("Constructing command")

        command_list = [
            "sshpass",
            f"-p {self._password}",  # Provide password as argument (security unwise)
            "rsync",
            "--compress",
            "--recursive",
            "--times",
            "--verbose",
            "--rsh='ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no'",
            self._get_source_path(copy_direction=copy_direction, copy_contents_only=copy_contents_only),
            self._get_destination_path(copy_direction=copy_direction),
        ]

        command = " ".join(command_list)
        logger.debug(f"Constructed command: {command}")
        return command
