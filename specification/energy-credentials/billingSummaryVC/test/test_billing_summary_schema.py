"""Validate billingSummaryVC examples against schema.json using pytest."""

import json
from pathlib import Path

import pytest
from jsonschema import Draft202012Validator

BASE = Path(__file__).resolve().parent.parent
SCHEMA_PATH = BASE / "schema.json"
EXAMPLES_DIR = BASE / "examples"


@pytest.fixture(scope="session")
def schema():
    with open(SCHEMA_PATH) as f:
        return json.load(f)


@pytest.fixture(scope="session")
def validator(schema):
    return Draft202012Validator(schema)


# ── Collect .json example files ──────────────────────────────────────

json_files = sorted(EXAMPLES_DIR.glob("*.json"))


@pytest.mark.parametrize("path", json_files, ids=[f.name for f in json_files])
def test_json_example(validator, path):
    with open(path) as f:
        instance = json.load(f)
    errors = list(validator.iter_errors(instance))
    assert not errors, "\n".join(f"{e.json_path}: {e.message}" for e in errors)
