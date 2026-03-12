from pathlib import Path
import pytest

from testzilla.utility.rsync import RemoteRsyncCmdBuilder, CopyDirection


@pytest.mark.parametrize(
    "copy_contents_only, copy_direction",
    [
        (True, CopyDirection.FROM_LOCAL),
        (False, CopyDirection.FROM_LOCAL),
        (True, CopyDirection.FROM_REMOTE),
        (False, CopyDirection.FROM_REMOTE),
    ],
)
def test_get_rsync_command(copy_contents_only, copy_direction):
    """Test get rsync command to copy from remote to local."""
    # Preparation
    local_paths = [Path("/local/path1")]
    remote_paths = [Path("/remote/path1"), Path("/remote/path2")]
    hostname = "hostname"
    username = "username"
    password = "password"

    builder = RemoteRsyncCmdBuilder(
        local_paths=local_paths,
        remote_paths=remote_paths,
        hostname=hostname,
        username=username,
        password=password,
    )

    # Execution
    actual = builder.get_command(copy_direction=copy_direction, copy_contents_only=copy_contents_only)

    # Verification
    assert f"sshpass -p {password}" in actual

    if copy_contents_only:
        if copy_direction == CopyDirection.FROM_LOCAL:
            source_and_destination = (
                f"{local_paths[0].as_posix()}/ "
                f"{username}@{hostname}:{remote_paths[0].as_posix()} "
                f":{remote_paths[1].as_posix()}"
            )
        else:
            source_and_destination = (
                f"{username}@{hostname}:{remote_paths[0].as_posix()}/ "
                f":{remote_paths[1].as_posix()}/ "
                f"{local_paths[0].as_posix()}"
            )
    else:
        if copy_direction == CopyDirection.FROM_LOCAL:
            source_and_destination = (
                f"{local_paths[0].as_posix()} "
                f"{username}@{hostname}:{remote_paths[0].as_posix()} "
                f":{remote_paths[1].as_posix()}"
            )
        else:
            source_and_destination = (
                f"{username}@{hostname}:{remote_paths[0].as_posix()} "
                f":{remote_paths[1].as_posix()} "
                f"{local_paths[0].as_posix()}"
            )

    assert source_and_destination in actual
