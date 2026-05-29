#!/usr/bin/env bash
# Generate all Postman collections for p2p-trading-ies-wave1 uc1.
# Run from any directory — paths are resolved relative to this script.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../" && pwd)"
GENERATOR="$REPO_ROOT/scripts/generate_postman_collection.py"
OUTPUT_DIR="devkits/p2p-trading-ies-wave1/uc1/postman"

for ROLE in BAP BPP UtilityBPP; do
  echo "Generating $ROLE..."
  python3 "$GENERATOR" \
    --devkit p2p-trading-ies-wave1 \
    --role "$ROLE" \
    --usecase uc1 \
    --output-dir "$OUTPUT_DIR"
done

echo "Done. Collections written to $REPO_ROOT/$OUTPUT_DIR/"
