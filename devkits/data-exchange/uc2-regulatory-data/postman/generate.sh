#!/usr/bin/env bash
# Generate all Postman collections for data-exchange uc2-regulatory-data.
# Run from any directory — paths are resolved relative to this script.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../" && pwd)"
GENERATOR="$REPO_ROOT/scripts/generate_postman_collection.py"
OUTPUT_DIR="devkits/data-exchange/uc2-regulatory-data/postman"

for ROLE in BUYER SELLER; do
  echo "Generating $ROLE..."
  python3 "$GENERATOR" \
    --devkit data-exchange-uc2-regulatory-data \
    --role "$ROLE" \
    --output-dir "$OUTPUT_DIR"
done

echo "Done. Collections written to $REPO_ROOT/$OUTPUT_DIR/"
