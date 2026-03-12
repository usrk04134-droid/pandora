"""This script validates a given YAML manifest file against a given JSON schema"""

import json
import yaml
import argparse
from loguru import logger
from jsonschema import Draft202012Validator, ValidationError


def validate_manifest(schema_path, manifest_path):
    """Validate a YAML manifest against a JSON schema."""
    try:
        with open(schema_path, "r") as schema_file:
            schema = json.load(schema_file)

        with open(manifest_path, "r") as manifest_file:
            manifest = yaml.safe_load(manifest_file)

        validator = Draft202012Validator(schema)
        validator.validate(manifest)
        logger.success("Manifest is valid!")
        return True
    except FileNotFoundError as f_error:
        logger.error(f"File not found: {f_error.filename}")
        return False
    except ValidationError as v_error:
        logger.error("Manifest validation failed!")
        logger.error(f"Error: {v_error.message}")
        return False


def main():
    parser = argparse.ArgumentParser(
        description="Validate a YAML manifest against a JSON schema."
    )
    parser.add_argument(
        "-s", "--schema",
        required=True,
        help="Path to the JSON schema file."
    )
    parser.add_argument(
        "-m", "--manifest",
        required=True,
        help="Path to the YAML manifest file."
    )
    args = parser.parse_args()
    return 0 if validate_manifest(args.schema, args.manifest) else 1


if __name__ == "__main__":
    exit(main())
