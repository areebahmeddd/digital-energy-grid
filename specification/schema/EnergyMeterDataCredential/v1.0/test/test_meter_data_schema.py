"""Validate meterDataVC examples against schema.json using pytest."""

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


# ── Collect .ndjson example files ────────────────────────────────────

ndjson_files = sorted(EXAMPLES_DIR.glob("*.ndjson"))


def _ndjson_lines(path):
    """Yield (line_number, parsed_json) for each non-empty line."""
    with open(path) as f:
        for i, line in enumerate(f, 1):
            if line.strip():
                yield i, json.loads(line)


def _ndjson_cases():
    """Produce (path, line_number, instance) tuples for parametrize."""
    cases = []
    for path in ndjson_files:
        for lineno, instance in _ndjson_lines(path):
            cases.append(pytest.param(instance, id=f"{path.name}:line{lineno}"))
    return cases


@pytest.mark.parametrize("instance", _ndjson_cases())
def test_ndjson_line(validator, instance):
    errors = list(validator.iter_errors(instance))
    assert not errors, "\n".join(f"{e.json_path}: {e.message}" for e in errors)
