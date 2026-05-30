#!/usr/bin/env bash
# Generate all Postman collections for demand-flex uc1-bdr-w-baselining.
# Run from any directory — paths are resolved relative to this script.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../" && pwd)"
GENERATOR="$REPO_ROOT/scripts/generate_postman_collection.py"
OUTPUT_DIR="devkits/demand-flex/uc1-bdr-w-baselining/postman"

for ROLE in BUYER SELLER; do
  echo "Generating $ROLE..."
  python3 "$GENERATOR" \
    --devkit demand-flex \
    --role "$ROLE" \
    --usecase uc1-bdr-w-baselining \
    --output-dir "$OUTPUT_DIR"
done

echo "Done. Collections written to $REPO_ROOT/$OUTPUT_DIR/"
