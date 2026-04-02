#!/usr/bin/env python3
"""Validate meter-data-vc example files against schema.json."""

import json
import sys
from pathlib import Path

from jsonschema import Draft202012Validator

BASE = Path(__file__).resolve().parent.parent
SCHEMA_PATH = BASE / "schema.json"
EXAMPLES_DIR = BASE / "examples"


def load_schema():
    with open(SCHEMA_PATH) as f:
        return json.load(f)


def validate_json_files(schema):
    validator = Draft202012Validator(schema)
    files = sorted(EXAMPLES_DIR.glob("*.json"))
    if not files:
        print("No .json example files found.")
        return False

    all_passed = True
    for path in files:
        with open(path) as f:
            instance = json.load(f)
        errors = list(validator.iter_errors(instance))
        if errors:
            print(f"FAIL  {path.name}")
            for e in errors:
                print(f"      → {e.json_path}: {e.message}")
            all_passed = False
        else:
            print(f"PASS  {path.name}")
    return all_passed


def validate_ndjson_files(schema):
    validator = Draft202012Validator(schema)
    files = sorted(EXAMPLES_DIR.glob("*.ndjson"))
    if not files:
        return True

    all_passed = True
    for path in files:
        with open(path) as f:
            lines = [line.strip() for line in f if line.strip()]
        line_errors = 0
        for i, line in enumerate(lines, 1):
            instance = json.loads(line)
            errors = list(validator.iter_errors(instance))
            if errors:
                line_errors += 1
                for e in errors:
                    print(f"FAIL  {path.name} line {i} → {e.json_path}: {e.message}")
        if line_errors:
            all_passed = False
        else:
            print(f"PASS  {path.name} ({len(lines)} lines)")
    return all_passed


def main():
    schema = load_schema()
    ok_json = validate_json_files(schema)
    ok_ndjson = validate_ndjson_files(schema)
    if ok_json and ok_ndjson:
        print("\nAll examples valid.")
        sys.exit(0)
    else:
        print("\nSome examples failed validation.")
        sys.exit(1)


if __name__ == "__main__":
    main()
