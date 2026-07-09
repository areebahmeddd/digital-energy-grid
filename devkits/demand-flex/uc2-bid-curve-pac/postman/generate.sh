#!/usr/bin/env bash
# Generate all Postman collections for demand-flex uc2-bid-curve-pac.
# Run from any directory — paths are resolved relative to this script.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../" && pwd)"
GENERATOR="$REPO_ROOT/scripts/generate_postman_collection.py"
OUTPUT_DIR="devkits/demand-flex/uc2-bid-curve-pac/postman"

# NOTE: use the dedicated demand-flex-uc2-bid-curve-pac devkit config — it
# carries this use case's examples_path. `--devkit demand-flex --usecase
# uc2-bid-curve-pac` only renames the collection and silently generates from
# the uc1 examples.
for ROLE in BUYER SELLER; do
  echo "Generating $ROLE..."
  python3 "$GENERATOR" \
    --devkit demand-flex-uc2-bid-curve-pac \
    --role "$ROLE" \
    --output-dir "$OUTPUT_DIR"
done

echo "Done. Collections written to $REPO_ROOT/$OUTPUT_DIR/"
