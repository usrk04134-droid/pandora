#!/usr/bin/env python3

import argparse
import sys
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import Union

from junit_xml import TestCase, TestSuite, to_xml_report_file
from loguru import logger


def xml_to_dict(xml_file: Path) -> Union[dict, None]:
    """Parse an XML file and convert it into a dictionary."""
    try:
        tree = ET.parse(xml_file)
        root = tree.getroot()
        return _element_to_dict(root)
    except FileNotFoundError:
        logger.exception(f"File not found at {xml_file}")
        return None
    except ET.ParseError:
        logger.exception("Error parsing XML file")
        return None


def _element_to_dict(element: ET.Element) -> dict:
    """Convert an XML element and its children to a dictionary."""
    data = {}
    for child in element:
        child_data = _element_to_dict(child)
        if child.tag in data:
            if isinstance(data[child.tag], list):
                data[child.tag].append(child_data)
            else:
                data[child.tag] = [data[child.tag], child_data]
        else:
            data[child.tag] = child_data

    # Add attributes of the current element
    data.update(element.attrib)
    return data


def create_junit_from_axunit(axunit_report_path: Path, junit_report_name: str) -> Path | None:
    """Create Junit test report from AxUnit test report."""
    axunit_dict = xml_to_dict(axunit_report_path)

    if not axunit_dict:
        logger.warning(f"Valid data could not be parsed from the AxUnit report file: {axunit_report_path}")
        return

    if not isinstance(axunit_dict["TestResults"]["TestFixtures"]["TestFixture"], list):
        axunit_dict["TestResults"]["TestFixtures"]["TestFixture"] = [
            axunit_dict["TestResults"]["TestFixtures"]["TestFixture"]
        ]

    junit_testcases = []

    for axunit_class in axunit_dict["TestResults"]["TestFixtures"]["TestFixture"]:
        if not isinstance(axunit_class["TestCase"], list):
            axunit_class["TestCase"] = [axunit_class["TestCase"]]

        for axunit_testcase in axunit_class["TestCase"]:
            parameters = axunit_testcase["Parameters"]
            testcase_name = axunit_testcase["TestName"].split(".")[-1]
            testcase_name = f"{testcase_name}-[{parameters}]" if parameters else testcase_name

            junit_testcase = TestCase(classname=axunit_class["Name"], name=testcase_name)

            if axunit_testcase["Result"] != "Sucess":
                junit_testcase.add_failure_info(message=axunit_testcase["Message"])

            junit_testcases.append(junit_testcase)

    junit_testsuites = [TestSuite(name="apax test", test_cases=junit_testcases)]

    junit_report_path = axunit_report_path.parent / Path(junit_report_name)
    with open(junit_report_path, "w", encoding="utf-8") as file:
        to_xml_report_file(file_descriptor=file, test_suites=junit_testsuites)

    return junit_report_path


def setup_parser():
    parser = argparse.ArgumentParser(description="Convert the provided ax unit test report to junit")
    parser.add_argument("--axunit-report-path", required=True, help="Path to the ax unit test report")
    parser.add_argument(
        "--junit-report-name",
        default="junit_report.xml",
        help="Name of the junit test report file",
    )

    return parser


def main():
    parser = setup_parser()
    args = parser.parse_args()

    axunit_report_path = Path(args.axunit_report_path)
    junit_report_name = args.junit_report_name

    if not axunit_report_path.exists():
        logger.error(f"AxUnit report not found at {axunit_report_path}. Won't create Junit report.")
        return 1

    junit_report_path = None
    try:
        junit_report_path = create_junit_from_axunit(
            axunit_report_path=axunit_report_path, junit_report_name=junit_report_name
        )
    except (OSError, ValueError, KeyError) as e:
        logger.exception(f"An error occurred during the creation of Junit report: {e}")

    if junit_report_path and junit_report_path.exists():
        logger.info(f"Successfully created JUnit report: {junit_report_path}")
        return 0

    logger.error("Failed to create the JUnit report.")
    return 1


if __name__ == "__main__":
    sys.exit(main())
