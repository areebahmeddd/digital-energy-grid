#!/usr/bin/env bash
# Run the uc2-regulatory-data Arazzo workflows via Redocly Respect.
#
# Default mode (no PUBLIC_URL): payload bapUri/bppUri are rewritten to
# http://beckn-router:9000 — Caddy bridges BAP↔BPP traffic locally inside
# docker, no ngrok needed.
#
# Over-internet mode (forces public-internet traversal): set PUBLIC_URL
# to the ngrok tunnel URL fronting beckn-router:9000.
#
# Usage (from uc2-regulatory-data/workflows/):
#   ./run-arazzo.sh                                                    # local-bridge mode
#   ./run-arazzo.sh -w select-through-status -v
#   PUBLIC_URL=https://your-domain.ngrok-free.dev ./run-arazzo.sh      # over-internet mode

set -euo pipefail

USECASE_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RESPECT_ARGS=(--severity 'SCHEMA_CHECK=off' "$@")

PUBLIC_URL="${PUBLIC_URL:-http://beckn-router:9000}"
PUBLIC_URL="${PUBLIC_URL%/}"

if [ "$PUBLIC_URL" = "http://beckn-router:9000" ]; then
  echo "Mode: local-bridge via beckn-router (payloads patched in tmpdir)"
else
  echo "Mode: over-internet via $PUBLIC_URL (payloads patched in tmpdir)"
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/data-exchange-arazzo-XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/workflows" "$WORK/examples"

cp "$USECASE_ROOT/workflows/data-exchange.arazzo.yaml" "$WORK/workflows/"

PUBLIC_URL="$PUBLIC_URL" python3 - "$USECASE_ROOT/examples" "$WORK/examples" <<'PY'
import json, os, sys, pathlib
src, dst = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
pub = os.environ['PUBLIC_URL']
for f in sorted(src.glob('*.json')):
    d = json.load(open(f))
    ctx = d.get('context', {})
    if 'bapUri' in ctx:
        ctx['bapUri'] = pub + '/bap/receiver'
    if 'bppUri' in ctx:
        ctx['bppUri'] = pub + '/bpp/receiver'
    json.dump(d, open(dst / f.name, 'w'), indent=2)
PY

# Server URLs (host-side caller endpoints) always go via the published host
# ports — direct in local-bridge mode, via the tunnel only when PUBLIC_URL
# is a remote URL.
if [ "$PUBLIC_URL" = "http://beckn-router:9000" ]; then
  exec npx --yes @redocly/cli respect \
    "$WORK/workflows/data-exchange.arazzo.yaml" \
    "${RESPECT_ARGS[@]}"
else
  exec npx --yes @redocly/cli respect \
    "$WORK/workflows/data-exchange.arazzo.yaml" \
    -S "beckn-bap-caller=$PUBLIC_URL/bap/caller" \
    -S "beckn-bpp-caller=$PUBLIC_URL/bpp/caller" \
    "${RESPECT_ARGS[@]}"
fi
