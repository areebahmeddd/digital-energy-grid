#!/usr/bin/env bash
# Run the uc1-p2p-trading-interdiscom Arazzo workflows via Redocly Respect.
#
# Default mode (no PUBLIC_URL): payload bapUri/bppUri are rewritten to
# http://beckn-router:9000 — Caddy bridges BAP↔BPP traffic locally inside
# docker, no ngrok needed.
#
# Over-internet mode (forces public-internet traversal): set PUBLIC_URL
# to the ngrok tunnel URL fronting beckn-router:9000.
#
# Usage (from uc1-p2p-trading-interdiscom/workflows/):
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

WORK="$(mktemp -d "${TMPDIR:-/tmp}/p2p-trading-interdiscom-arazzo-XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/workflows" "$WORK/examples"

cp "$USECASE_ROOT/workflows/p2p-trading-interdiscom.arazzo.yaml" "$WORK/workflows/"

PUBLIC_URL="$PUBLIC_URL" python3 - "$USECASE_ROOT/examples" "$WORK/examples" <<'PY'
import json, os, sys, pathlib
src, dst = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
pub = os.environ['PUBLIC_URL']
for f in sorted(src.glob('*.json')):
    d = json.load(open(f))
    ctx = d.get('context', {})
    if 'bap_uri' in ctx:
        ctx['bap_uri'] = pub + '/bap/receiver'
    if 'bpp_uri' in ctx:
        ctx['bpp_uri'] = pub + '/bpp/receiver'
    json.dump(d, open(dst / f.name, 'w'), indent=2)
PY

JSON_OUT="$WORK/respect-output.json"

set +e
if [ "$PUBLIC_URL" = "http://beckn-router:9000" ]; then
  npx --yes @redocly/cli respect \
    "$WORK/workflows/p2p-trading-interdiscom.arazzo.yaml" \
    -J "$JSON_OUT" \
    "${RESPECT_ARGS[@]}"
else
  npx --yes @redocly/cli respect \
    "$WORK/workflows/p2p-trading-interdiscom.arazzo.yaml" \
    -J "$JSON_OUT" \
    -S "beckn-bap-caller=$PUBLIC_URL/bap/caller" \
    -S "beckn-bpp-caller=$PUBLIC_URL/bpp/caller" \
    "${RESPECT_ARGS[@]}"
fi
RESPECT_EXIT=$?
set -e

# Fail the run if any step got a NACK response (statusCode != 200 or NACK in body).
# respect's native successCriteria don't work reliably against $statusCode in the
# installed version, so we post-process the JSON log instead.
python3 - "$JSON_OUT" "$RESPECT_EXIT" <<'PY'
import json, sys
log_path, respect_exit = sys.argv[1], int(sys.argv[2])
try:
    data = json.load(open(log_path))
except Exception as e:
    print(f"NACK check: unable to read respect JSON log ({e})")
    sys.exit(respect_exit)
nacks = []
for _, file_data in data.get('files', {}).items():
    for wf in file_data.get('executedWorkflows', []):
        for step in wf.get('executedSteps', []):
            resp = step.get('response') or {}
            body = resp.get('body')
            status = resp.get('statusCode')
            body_str = json.dumps(body) if not isinstance(body, str) else body
            is_nack = (
                isinstance(status, int) and status >= 400
            ) or (body_str and '"NACK"' in body_str)
            if is_nack:
                nacks.append((wf.get('workflowId'), step.get('stepId'), status))
if nacks:
    print("\nNACK check: FAILED — the following steps returned a NACK/error response:")
    for wf_id, step_id, status in nacks:
        print(f"  - {wf_id} / {step_id}  (HTTP {status})")
    sys.exit(1)
print("\nNACK check: PASSED — all steps returned ACK.")
sys.exit(respect_exit)
PY
