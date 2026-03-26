#!/usr/bin/env python3

"""
This script is used to generate a file from a jinja-template
"""

import os
import os.path
import string
import sys
from re import sub

import yaml
from jinja2 import Environment, FileSystemLoader, StrictUndefined

output_file = sys.argv[1]
template_path = os.path.abspath(sys.argv[2])
template_base_path = os.path.dirname(template_path)
template_file_name = os.path.basename(template_path)
data_file = sys.argv[3]

extra_yaml_data = ""
if len(sys.argv) == 5:
    extra_yaml_data = sys.argv[4]


def abp_type(typename: str) -> str:
    """
    Converts the given type to its ABP_ equivalent
    :param typename:
    :return:
    """
    match typename:
        case "uint32_t":
            return "ABP_UINT32"
        case "float":
            return "ABP_FLOAT"
        case _:
            return "TYPE_ERROR"


def gsd_type(typename: str) -> str:
    """
    Converts the given type to its GSDML equivalent
    :param typename:
    :return:
    """
    match typename:
        case "uint32_t":
            return "Unsigned32"
        case "float":
            return "Float32"
        case _:
            return "TYPE_ERROR"


def gsd_type_length(typename: str) -> int:
    """
    Returns the number of bytes occupied by a GSDML data type.
    If the type is not found, returns -1.

    :param typename: The name of the GSDML data type.
    :return: The number of bytes occupied by the type, or -1 if the type is not found.
    """
    type_lengths = {
        "Unsigned8": 1,
        "Unsigned16": 2,
        "Unsigned32": 4,
        "Unsigned64": 8,
        "Integer8": 1,
        "Integer16": 2,
        "Integer32": 4,
        "Integer64": 8,
        "Float32": 4,
    }
    return type_lengths.get(typename, -1)


def udt_type(typename: str) -> str:
    """
    Converts the given type to its UDT equivalent
    :param typename:
    :return:
    """
    match typename:
        case "uint32_t":
            return "DINT"
        case "float":
            return "REAL"
        case _:
            return "TYPE_ERROR"


def udt_type_size(typename: str) -> int:
    """Returns the number of bytes occupied by a Siemens data type.

    Args:
        typename: The Siemens data type name (e.g. 'BOOL', 'INT', etc.)

    Returns:
        int: Number of bytes for the type, 0 for BOOL, or -1 if unknown type
    """
    type_sizes = {
        "BOOL": 0,  # Special case - bit addressed
        "BYTE": 1,
        "INT": 2,
        "WORD": 2,
        "DINT": 4,
        "REAL": 4,
        "DWORD": 4,
    }
    return type_sizes.get(typename, -1)


def udt_type_suffix(size: int) -> str | int:
    """
    Returns the suffix used in I/O assignment
    :param size:
    :return:
    """
    suffix_map = {
        0: "X",
        1: "B",
        2: "W",
        3: "D",
        4: "D",
        5: "L",
        6: "L",
        7: "L",
        8: "L",
    }
    return suffix_map.get(size, -1)


def filter_name(name: str) -> str:
    """
    Returns a sanitized name
    :param name:
    :return:
    """

    if name.casefold() == "method" or name.casefold() == "type":
        return name + "_"
    else:
        return name


def filter_real(typename: str) -> str:
    """
    Replaces REAL with DWORD (for I/O)
    :param typename:
    :return:
    """

    if typename == "REAL":
        return "DWORD"
    else:
        return typename


def snake_to_pascal(text: str) -> str:
    """
    Converts from snake_case to PascalCase
    :param text:
    :return:
    """
    return string.capwords(text, "_").replace("_", "")


def to_hex(number: str) -> str:
    """
    Returns the last two digits of the number string converted to hex
    :param number:
    :return:
    """
    value = int(number)
    return f"{value:#0{4}x}"[-2:]


def py_type(typename: str) -> str:
    """
    Converts the given type to its Python equivalent
    :param typename:
    :return:
    """
    match typename:
        case "uint32_t":
            return "int"
        case "float":
            return "float"
        case _:
            return "TYPE_ERROR"


def io_get_addr(iodef: str) -> str:
    """
    Gets the address part from a io def string: "<TYPE> [AT <ADDR>]"
    Only the type part is mandatory
    :param iodef:
    :return:
    """

    str_split = iodef.split()

    if len(str_split) == 3:
        return str_split[2]

    return ""


def io_get_type(iodef: str) -> str:
    """
    Gets the type part from a io def string: "<TYPE> [AT <ADDR>]"
    The type part is mandatory
    :param iodef:
    :return:
    """

    str_split = iodef.split()

    return str_split[0]


def io_is_output(iodef: str) -> str:
    """
    Gets the type part from a io def string: "<TYPE> [AT <ADDR>]"
    The type part is mandatory
    :param iodef:
    :return:
    """

    str_split = iodef.split()

    return str_split[0]


def regex_replace(string: str, regex: str, replacement: str) -> str:
    """
    Replaces in the filtered string according to the regex and returns the result
    """

    return sub(regex, replacement, string)


environment = Environment(loader=FileSystemLoader(template_base_path), undefined=StrictUndefined)
environment.filters["snake_to_pascal"] = snake_to_pascal
environment.filters["to_hex"] = to_hex
environment.filters["abp_type"] = abp_type
environment.filters["gsd_type"] = gsd_type
environment.filters["gsd_type_length"] = gsd_type_length
environment.filters["udt_type"] = udt_type
environment.filters["udt_type_size"] = udt_type_size
environment.filters["udt_type_suffix"] = udt_type_suffix
environment.filters["filter_name"] = filter_name
environment.filters["filter_real"] = filter_real
environment.filters["py_type"] = py_type
environment.filters["io_get_addr"] = io_get_addr
environment.filters["io_get_type"] = io_get_type
environment.filters["regex_replace"] = regex_replace

template = environment.get_template(template_file_name)

data = yaml.safe_load(open(data_file, "r"))

extra_data = yaml.safe_load(extra_yaml_data)

if extra_data:
    data.update(extra_data)

open(output_file, "w").write(template.render(data=data))
