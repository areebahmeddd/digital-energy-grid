#!/usr/bin/env python3
"""
Compact-yet-readable formatter for devkit example payloads.

Pretty-prints each example JSON with 2-space indentation, but collapses the
small, repetitive arrays to one line per element so payloads stay easy to scan:

  - Each element of an array under one of the "collapse" keys (intervals,
    payloadDescriptors, reportDescriptors, vendorDevices, roles, participants,
    revenueFlows) renders on a single line. So every `intervals[i]` (id +
    payloads) for a TimeSeries telemetry block is one row, every
    payloadDescriptor is one row, etc.
  - Short pure-scalar arrays (e.g. schemaContext-style id lists) render inline.
  - Larger nested structures (commitments, resources, inputs, meters,
    performance, offers, catalogs) stay expanded.

This reuses `_format_payload` from generate_postman_collection.py verbatim, so
the on-disk examples match the bodies emitted into the generated Postman
collections exactly — one convention, no drift.

USAGE
-----
  python3 scripts/compact_examples.py            # format all devkit examples
  python3 scripts/compact_examples.py --check     # report files that would change, exit 1 if any
  python3 scripts/compact_examples.py path1 ...    # format only the given files/dirs

After formatting, regenerate the Postman collections by running each
devkits/<devkit>/<usecase>/postman/generate.sh.
"""

import argparse
import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO_ROOT / "scripts"))

from generate_postman_collection import _format_payload  # noqa: E402


def find_example_files(targets):
    """Resolve the set of example JSON files to format.

    With no targets, walk every devkits/<devkit>/<usecase>/examples tree
    (recursively, to catch ev-charging's folder-based layout). With targets,
    accept files or directories and collect their *.json contents.
    """
    files = []
    if targets:
        for t in targets:
            p = Path(t)
            if not p.is_absolute():
                p = REPO_ROOT / p
            if p.is_dir():
                files.extend(sorted(p.rglob("*.json")))
            elif p.suffix == ".json" and p.exists():
                files.append(p)
            else:
                print(f"  skip (not a json file/dir): {t}")
    else:
        for examples_dir in sorted(REPO_ROOT.glob("devkits/*/*/examples")):
            files.extend(sorted(examples_dir.rglob("*.json")))
    # De-dup while preserving order
    seen = set()
    unique = []
    for f in files:
        rp = f.resolve()
        if rp not in seen:
            seen.add(rp)
            unique.append(f)
    return unique


def format_file(path: Path) -> bool:
    """Reformat one file in place. Returns True if its contents changed."""
    original = path.read_text(encoding="utf-8")
    try:
        doc = json.loads(original)
    except json.JSONDecodeError as exc:
        print(f"  SKIP (invalid JSON): {path} ({exc})")
        return False
    formatted = _format_payload(doc) + "\n"
    if formatted != original:
        path.write_text(formatted, encoding="utf-8")
        return True
    return False


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("targets", nargs="*",
                        help="Files or directories to format (default: all devkit examples)")
    parser.add_argument("--check", action="store_true",
                        help="Report files that would change without writing; exit 1 if any")
    args = parser.parse_args()

    files = find_example_files(args.targets)
    if not files:
        print("No example JSON files found.")
        return 0

    changed = []
    for fp in files:
        rel = fp.relative_to(REPO_ROOT) if REPO_ROOT in fp.resolve().parents else fp
        if args.check:
            original = fp.read_text(encoding="utf-8")
            try:
                doc = json.loads(original)
            except json.JSONDecodeError as exc:
                print(f"  SKIP (invalid JSON): {rel} ({exc})")
                continue
            if _format_payload(doc) + "\n" != original:
                changed.append(rel)
                print(f"would reformat: {rel}")
        else:
            if format_file(fp):
                changed.append(rel)
                print(f"reformatted: {rel}")

    verb = "would reformat" if args.check else "reformatted"
    print(f"\n{len(changed)}/{len(files)} files {verb}.")
    if args.check and changed:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
