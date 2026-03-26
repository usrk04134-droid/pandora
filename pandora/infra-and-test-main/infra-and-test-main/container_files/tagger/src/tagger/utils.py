import os

from tagger import logger


def write_file(name: str, data: str, path: str = os.getcwd()) -> str:
    """Write to file.

    Args:
        name (str): Name of the file to write to
        data (dict): The data to write
        path (str, optional): Path to where to place the file. Defaults to current directory.

    Returns:
        str: File path.
    """

    file_path = _get_file_path(path, name)

    try:
        logger.debug(f"Writing to '{file_path}'")
        with open(file_path, "w", encoding="UTF-8") as file_handle:
            file_handle.write(data)
    except OSError as e:
        logger.exception(f"Error writing '{file_path}': {e.strerror}")

    return file_path


def _get_file_path(path: str, name: str) -> str:
    """Returns absolute path to file, creating missing parts if needed.

    Args:
        path (str): File location
        name (str): File name

    Returns:
        str: File path.
    """

    os.makedirs(path, exist_ok=True)

    return os.path.join(path, name)
