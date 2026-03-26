"""Unit tests for testzilla.utility.file_system."""

import tarfile
from pathlib import Path

import pytest

from testzilla.utility.file_system import create_archive


def test_create_archive_produces_valid_tar_gz(tmp_path: Path) -> None:
    """Test that create_archive creates a readable tar.gz containing the source tree."""
    # Preparation
    source_dir = tmp_path / "source"
    source_dir.mkdir()
    (source_dir / "data.txt").write_text("hello world")

    archive_path = tmp_path / "output.tar.gz"

    # Execution
    create_archive(source_dir, archive_path)

    # Verification
    assert archive_path.exists()
    with tarfile.open(archive_path, "r:gz") as tar:
        names = tar.getnames()
    assert any("data.txt" in name for name in names)


def test_create_archive_handles_nested_files(tmp_path: Path) -> None:
    """Test that create_archive recursively includes nested files."""
    # Preparation
    source_dir = tmp_path / "root"
    source_dir.mkdir()
    sub = source_dir / "sub"
    sub.mkdir()
    (sub / "nested.txt").write_text("nested content")

    archive_path = tmp_path / "nested.tar.gz"

    # Execution
    create_archive(source_dir, archive_path)

    # Verification
    assert archive_path.exists()
    with tarfile.open(archive_path, "r:gz") as tar:
        names = tar.getnames()
    assert any("nested.txt" in n for n in names)
