import pytest
from pathlib import Path
from unittest.mock import patch, call, MagicMock
from testzilla.remote_comm.remote_host import RemoteHostManager
from testzilla.utility.rsync import RemoteRsyncCmdBuilder


@pytest.mark.parametrize("local, sudo", [(True, False), (False, True), (False, False)])
def test_execute_command(sudo, local, remote_host_manager):
    """Test executing command on a remote host."""
    # Preparation
    command = "ls -l"
    expected_output = "output"
    expected_error = ""
    expected_exit_code = 0

    mock_connection = remote_host_manager._connection
    mock_connection.run.return_value.stdout = expected_output
    mock_connection.sudo.return_value.stdout = expected_output
    mock_connection.local.return_value.stdout = expected_output

    mock_connection.run.return_value.stderr = expected_error
    mock_connection.sudo.return_value.stderr = expected_error
    mock_connection.local.return_value.stderr = expected_error

    mock_connection.run.return_value.exited = expected_exit_code
    mock_connection.sudo.return_value.exited = expected_exit_code
    mock_connection.local.return_value.exited = expected_exit_code

    # Execution
    output, error, exit_code = remote_host_manager.execute_command(command=command, sudo=sudo, local=local)

    # Verification
    if local:
        mock_connection.local.assert_called_with(
            command=command,
            hide=True,
            timeout=RemoteHostManager.EXECUTION_TIMEOUT,
        )
    else:
        if sudo:
            mock_connection.sudo.assert_called_with(
                command=command,
                hide=True,
                timeout=RemoteHostManager.EXECUTION_TIMEOUT,
                pty=True,
            )
        else:
            mock_connection.run.assert_called_with(
                command=command, hide=True, timeout=RemoteHostManager.EXECUTION_TIMEOUT
            )

    assert output == expected_output
    assert error == expected_error
    assert exit_code == expected_exit_code


@pytest.mark.parametrize("sudo", [False, True])
def test_copy_dir_content_to_remote(sudo, remote_host_manager):
    """Test executing command on a remote host."""
    # Preparation
    local_path = Path("/local/path")
    remote_path = Path("/remote/path")
    backup_path = Path("/backup/path")

    with (
        patch.object(remote_host_manager, "execute_command") as mock_execute_command,
        patch.object(remote_host_manager, "_copy_dir_content_to_remote_with_no_sudo") as mock_copy_no_sudo,
        patch.object(remote_host_manager, "_copy_dir_content_to_remote_with_sudo") as mock_copy_sudo,
        patch.object(Path, "is_dir", return_value=True),
    ):
        mock_execute_command.return_value = backup_path.as_posix(), "", 0

        # Execution
        remote_host_manager.copy_dir_content_to_remote(local_path=local_path, remote_path=remote_path, sudo=sudo)

        # Verification
        mock_execute_command.assert_has_calls(
            [
                call(command="mktemp -d"),
                call(command=f"cp -r {remote_path}/. {backup_path}", sudo=sudo),
                call(command=f"rm -rf {backup_path}", sudo=sudo),
            ]
        )
        if sudo:
            mock_copy_sudo.assert_has_calls([call(local_path=local_path, remote_path=remote_path)])
            mock_copy_no_sudo.assert_not_called()
        else:
            mock_copy_no_sudo.assert_has_calls([call(local_path=local_path, remote_path=remote_path)])
            mock_copy_sudo.assert_not_called()


def test_copy_dir_content_to_remote__local_not_dir(remote_host_manager):
    """Test copying to remote host when local path is not dir."""
    # Preparation
    local_path = Path("/local/path")
    remote_path = Path("/remote/path")

    # Execution and Verification
    with patch.object(Path, "is_dir", return_value=False):
        with pytest.raises(ValueError, match=".*Local path.*needs to be a directory.*"):
            remote_host_manager.copy_dir_content_to_remote(local_path=local_path, remote_path=remote_path)


def test_copy_dir_content_to_remote__problem_in_exec(remote_host_manager):
    """Test copying to remote host that causes a problem in executing a command."""
    # Preparation
    local_path = Path("/local/path")
    remote_path = Path("/remote/path")
    backup_path = Path("/backup/path")

    remote_host_manager.execute_command = MagicMock()
    mock_execute_command = remote_host_manager.execute_command
    mock_execute_command.side_effect = [
        (backup_path.as_posix(), "", 0),
        OSError("File error!"),
        None,
        None,
        None,
    ]

    # Execution
    with patch.object(Path, "is_dir", return_value=True):
        with pytest.raises(OSError, match=".*File error!.*"):
            remote_host_manager.copy_dir_content_to_remote(local_path=local_path, remote_path=remote_path)

    # Verification
    mock_execute_command.assert_has_calls(
        [
            call(command="mktemp -d"),
            call(command=f"cp -r {remote_path}/. {backup_path}", sudo=False),
            call(command=f"find {remote_path} -mindepth 1 -delete", sudo=False),
            call(command=f"cp -r {backup_path}/. {remote_path}", sudo=False),
            call(command=f"rm -rf {backup_path}", sudo=False),
        ]
    )


def test__copy_dir_content_to_remote_with_sudo__success(remote_host_manager):
    """Test copying to remote host with sudo."""
    # Preparation
    local_path = Path("/local/path")
    remote_path = Path("/remote/path")
    temp_remote_path = Path("/temp/remote/path")

    with (
        patch.object(remote_host_manager, "execute_command") as mock_execute_command,
        patch.object(remote_host_manager, "_copy_dir_content_to_remote_with_no_sudo") as mock_copy_no_sudo,
    ):
        mock_execute_command.return_value = temp_remote_path.as_posix(), "", 0

        # Execution
        remote_host_manager._copy_dir_content_to_remote_with_sudo(local_path=local_path, remote_path=remote_path)

        # Verification
        mock_execute_command.assert_has_calls(
            [
                call(command="mktemp -d"),
                call(command=f"mkdir -p {remote_path}", sudo=True),
                call(command="chmod 755 /remote/path", sudo=True),
                call(command=f"cp -r {temp_remote_path}/. {remote_path}", sudo=True),
                call(command=f"rm -rf {temp_remote_path}"),
            ]
        )

        mock_copy_no_sudo.assert_has_calls([call(local_path=local_path, remote_path=temp_remote_path)])


def test__copy_dir_content_to_remote_with_sudo__exception(remote_host_manager):
    """Test copying to remote host with sudo causes exception."""
    # Preparation
    local_path = Path("/local/path")
    remote_path = Path("/remote/path")
    temp_remote_path = Path("/temp/remote/path")

    remote_host_manager.execute_command = MagicMock()
    mock_execute_command = remote_host_manager.execute_command
    mock_execute_command.return_value = temp_remote_path.as_posix(), "", 0

    remote_host_manager._copy_dir_content_to_remote_with_no_sudo = MagicMock()
    mock_copy_no_sudo = remote_host_manager._copy_dir_content_to_remote_with_no_sudo
    mock_copy_no_sudo.side_effect = OSError("File error!")

    # Execution
    with pytest.raises(OSError, match=".*File error!.*"):
        remote_host_manager._copy_dir_content_to_remote_with_sudo(local_path=local_path, remote_path=remote_path)

    # Verification
    mock_execute_command.assert_has_calls([call(command="mktemp -d"), call(command=f"rm -rf {temp_remote_path}")])

    mock_copy_no_sudo.assert_has_calls([call(local_path=local_path, remote_path=temp_remote_path)])


def test__copy_dir_content_to_remote_with_no_sudo(remote_host_manager):
    """Test copying local path to remote host with no sudo."""
    # Preparation
    local_path = Path("/local/path")
    remote_path = Path("/remote/path")

    with (
        patch.object(remote_host_manager, "execute_command") as mock_execute_command,
        patch.object(RemoteRsyncCmdBuilder, "get_command", return_value="rsync"),
    ):
        # Execution
        remote_host_manager._copy_dir_content_to_remote_with_no_sudo(local_path=local_path, remote_path=remote_path)

        assert "mkdir" in mock_execute_command.mock_calls[0].kwargs["command"]
        assert "rsync" in mock_execute_command.mock_calls[1].kwargs["command"]


def test_fetch_dir_content_from_remote__success(remote_host_manager):
    """Test fetching ddirectory from remote host."""
    # Preparation
    local_path = Path("/local/path")
    remote_path = Path("/remote/path")

    # Execution
    with (
        patch.object(remote_host_manager, "execute_command") as mock_execute_command,
        patch.object(Path, "mkdir") as mock_path_mkdir,
        patch.object(RemoteRsyncCmdBuilder, "get_command", return_value="rsync"),
    ):
        remote_host_manager.fetch_directory_from_remote(local_path=local_path, remote_paths=remote_path)

    # Verification
    mock_path_mkdir.assert_has_calls([call(parents=True, exist_ok=True)])
    assert "rsync" in mock_execute_command.mock_calls[0].kwargs["command"]


def test_fetch_directory_from_remote__invalid_path(remote_host_manager):
    """Test fetching directory from remote host with invalid path."""
    # Preparation
    local_path = "/local/path"
    remote_path = Path("/remote/path")

    # Execution
    with (
        patch.object(remote_host_manager, "execute_command") as mock_execute_command,
        patch.object(Path, "mkdir") as mock_path_mkdir,
    ):
        with pytest.raises(TypeError):
            remote_host_manager.fetch_directory_from_remote(local_path=local_path, remote_paths=remote_path)

    # Verification
    mock_execute_command.assert_not_called()
    mock_path_mkdir.assert_not_called()


def test_execute_command_result_is_none(remote_host_manager):
    """Test execute_command when result is None."""
    # Preparation
    command = "test command"
    mock_connection = remote_host_manager._connection
    mock_connection.run.return_value = None

    # Execution
    stdout, stderr, exit_code = remote_host_manager.execute_command(command=command, local=False, sudo=False)

    # Verification
    assert stdout == ""
    assert stderr == ""
    assert exit_code == 1
