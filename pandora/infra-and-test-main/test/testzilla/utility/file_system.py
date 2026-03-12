import tarfile
from loguru import logger
from pathlib import Path


def create_archive(source_dir: Path, archive_path: Path) -> None:
    """Creates a tar.gz archive of the given directory."""
    logger.info(f"Creating archive of {source_dir} as {archive_path}")
    with tarfile.open(archive_path, "w:gz") as tar:
        tar.add(source_dir, arcname=source_dir.name)
