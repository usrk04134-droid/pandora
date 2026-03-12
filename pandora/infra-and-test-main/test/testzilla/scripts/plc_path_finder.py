#!/usr/bin/env python3

import json
import os
import re
import sys
from time import time
from typing import Any, Callable, Dict, List, Tuple

import click
from loguru import logger

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "../..")))
from testzilla.plc.plc_json_rpc import PlcJsonRpc


def set_logging_level(level: str) -> None:
    """Set the logging level for the logger."""
    logger.remove()
    logger.add(sink=sys.stderr, level=level.upper())


def _extract_quoted_substring(s: str) -> str | None:
    """Extract the first quoted substring from a string."""
    match = re.match(r'"(.*?)"\.?', s)
    return match.group(1) if match else None


def _function_timer(func: Callable) -> Callable:
    """Show the execution time of the function object passed"""

    def wrap_func(*args, **kwargs):
        start_time = time()
        result = func(*args, **kwargs)
        end_time = time()
        logger.debug(f"Function {func.__name__!r} executed in {(end_time - start_time):.4f}s")
        return result

    return wrap_func


@_function_timer
def _recursive_plc_browse(plc: PlcJsonRpc, var: str) -> Dict:
    """Recursively browse the PLC data structure.

    See "PlcProgram.Browse" in the Siemens S7-1500 Web Server Function Manual for more information
    about the data structure that is returned by the browse function.
    https://support.industry.siemens.com/cs/attachments/59193560/s71500_webserver_function_manual_en-US_en-US.pdf

    """

    def build_structure(path: str) -> dict:
        logger.debug(f"Browse: {path}")
        result, error = plc.browse(var=path, browse_type=["data_blocks"])

        if error:
            logger.error(f"Error: {error}, when browsing: {path}")
            sys.exit(1)

        structure = {}

        for item in result:
            if "array_dimensions" in item:
                array_dim = item["array_dimensions"][0]
                start_index = array_dim["start_index"]
                count = array_dim["count"]

                if item.get("has_children", False):
                    structure[item["name"]] = [
                        build_structure(f"{path}.{item['name']}[{index}]")
                        for index in range(start_index, start_index + count)
                    ]
                else:
                    # Handle primitive variables
                    datatype = item.get("datatype", None)
                    if not datatype:
                        logger.error(f"Missing data type for: {item['name']}")
                        sys.exit(1)

                    default_value = _get_default_value(datatype)
                    structure[item["name"]] = [default_value] * count

            elif item.get("has_children", False):
                # Recursive call for nested items, with updated path
                item_path = f"{path}.{item['name']}" if path else f'"{item["name"]}"'
                structure[item["name"]] = build_structure(item_path)

            else:
                # Handle primitive variables
                datatype = item.get("datatype", None)
                if not datatype:
                    logger.error(f"Missing data type for: {item['name']}")
                    sys.exit(1)

                default_value = _get_default_value(datatype)
                structure[item["name"]] = default_value

        return structure

    root_structure = {var.strip('"'): build_structure(var)}
    return root_structure


def _get_default_value(data_type: str) -> Any:
    """Get the default value for a given data type."""
    type_mapping = {
        "byte": 0,
        "bool": False,
        "dint": 0,
        "dword": 0,
        "hw_io": 0,
        "int": 0,
        "lreal": 0.0,
        "ltime": 0,
        "real": 0.0,
        "string": "",
        "time": 0,
        "udint": 0,
        "uint": 0,
        "usint": 0,
        "word": 0,
    }

    result = type_mapping.get(data_type, None)
    if result is None:
        logger.error(f"Missing mapping for data type: {data_type}")
        sys.exit(1)

    return result


def _get_paths_with_types(db_structure: Dict | List, parent_key: str = "") -> List[Tuple[str, str]]:
    """Iterate a dictionary recursively and create a list of (paths,type) for all leafs."""
    paths = []
    if isinstance(db_structure, dict):
        for k, v in db_structure.items():
            if isinstance(v, (dict, list)):
                paths.extend(_get_paths_with_types(v, f"{parent_key}.{k}" if parent_key else f'"{k}"'))
            else:
                leaf_type = type(v).__name__
                paths.append((f"{parent_key}.{k}" if parent_key else f'"{k}"', leaf_type))
    elif isinstance(db_structure, list):
        for i, v in enumerate(db_structure):
            paths.extend(_get_paths_with_types(v, f"{parent_key}[{i}]"))
    return paths


def _generate_markdown(paths_with_types: List[Tuple[str, str]], header: str) -> str:
    """Generate markdown from the paths."""
    markdown = f"# {header}\n\n```text\n"

    if not paths_with_types:
        return ""

    for path, leaf_type in paths_with_types:
        markdown += f"{path} ({leaf_type})\n"

    markdown += "```\n"

    return markdown


def _write_file(filename: str, data: Dict | List | str, filepath: str, filetype: str = "text") -> None:
    """Write data to file, either by serializing it to a JSON formatted string or
    writing as plain text.
    """
    if filetype.lower() not in {"json", "text"}:
        logger.error(f"Unsupported file type: {filetype}")
        sys.exit(1)

    target = os.path.join(filepath, filename)
    logger.info(f"Writing to: {target}")

    with open(file=target, mode="w+", encoding="utf-8") as outfile:
        if "json" in filetype.lower():
            if not isinstance(data, (dict, list)):
                logger.error("Data must be a dictionary or list for JSON serialization")
                sys.exit(1)
            json.dump(data, outfile, indent=2, ensure_ascii=False)
        elif "text" in filetype.lower():
            if not isinstance(data, str):
                logger.error("Data must be a string for text writing")
                sys.exit(1)
            outfile.write(data)
        else:
            logger.error(f"Unsupported file type: {filetype}")
            sys.exit(1)


@click.group()
def cli() -> None:
    pass


@cli.command(
    help="Generate documentation from PLC Data Block paths",
    epilog="Example: plc_path_finder.py generate -s '\"AdaptioCommunication.DB_AdaptioCommunication\"' -f MD -f JSON",
)
@click.option("--url", "-u", default="https://192.168.100.10/api/jsonrpc")
@click.option(
    "--start-address",
    "-s",
    multiple=True,
    required=True,
    help='Address must start with a "SoftwareUnit.DataBlock" in quotes.',
)
@click.option(
    "--format",
    "-f",
    "format_",
    type=click.Choice(["MD", "JSON"], case_sensitive=False),
    multiple=True,
    required=True,
)
@click.option(
    "--out",
    "-o",
    default=os.getcwd(),
    help="Output directory for the generated files.",
)
@click.option(
    "--log-level",
    "-l",
    type=click.Choice(["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"], case_sensitive=False),
    default="INFO",
    show_default=True,
    help="Set the logging verbosity level.",
)
def generate(url, start_address, format_, out, log_level) -> None:
    set_logging_level(log_level)

    plc = PlcJsonRpc(url=url)
    plc.login()

    for address in start_address:
        logger.info(f"Generating documentation for: {address}")

        header = _extract_quoted_substring(address)
        if not header:
            logger.error(
                f'Invalid address format: {address}. Address must start with a "SoftwareUnit.DataBlock" in quotes'
            )
            sys.exit(1)

        db_structure = _recursive_plc_browse(plc, address)

        if "JSON" in format_:
            _write_file(
                filename=f"{header}.json",
                data=db_structure,
                filepath=out,
                filetype="json",
            )

        if "MD" in format_:
            paths_with_types = _get_paths_with_types(db_structure)
            markdown = _generate_markdown(paths_with_types, header)
            _write_file(
                filename=f"{header}.md",
                data=markdown,
                filepath=out,
            )


if __name__ == "__main__":
    cli(
        max_content_width=120,
        show_default=True,
        help_option_names=["-h", "--help"],
    )
