#!/usr/bin/env bash
# Runner for vc-validation.arazzo.yaml.
#
# Exercises the beckn-onix `validateVC` step plugin end-to-end against the
# running data-exchange devkit (docker compose up -d in install/). The shared
# run-arazzo.sh treats every NACK as a failure — the opposite of what the
# negative cases assert here — so this dedicated runner drives the cases with
# curl + jq and asserts the expected ACK / NACK responses directly.
#
# A rejection NACK carries the standard pipeline error.code (Unauthorized /
# Bad Request); the machine-readable failure class (INVALID_PROOF,
# CREDENTIAL_EXPIRED, …) appears inside error.message.
#
#   Positive case  → BAP caller (signs) → BPP receiver → ACK (HTTP 200)
#   Negative cases → BPP receiver directly. validateVC is the first pipeline
#                    step, so it NACKs before signature/schema validation and
#                    rejection is deterministic and offline.
#
# Usage (from uc1-meter-data/workflows/):
#   ./run-vc-validation.sh
#
# Override endpoints:
#   BAP_CALLER=http://localhost:8081/bap/caller \
#   BPP_RECEIVER=http://localhost:8082/bpp/receiver ./run-vc-validation.sh

set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
EX="$(cd "$HERE/../examples" && pwd)"

BAP_CALLER="${BAP_CALLER:-http://localhost:8081/bap/caller}"
BPP_RECEIVER="${BPP_RECEIVER:-http://localhost:8082/bpp/receiver}"

pass=0
fail=0

# post URL PAYLOAD -> sets $HTTP (status) and $BODY (response body)
post() {
  local url="$1" payload="$2" tmp
  tmp="$(mktemp)"
  HTTP="$(curl -s -o "$tmp" -w '%{http_code}' \
    -H 'Content-Type: application/json' \
    --data @"$payload" "$url")"
  BODY="$(cat "$tmp")"
  rm -f "$tmp"
}

# field JSONPATH -> echoes the value (empty on miss)
field() { echo "$BODY" | jq -r "$1 // empty" 2>/dev/null; }

# check NAME WANT_STATUS WANT_CLASS — the failure class is asserted inside
# error.message (error.code carries the standard pipeline code).
check() {
  local name="$1" want_status="$2" want_class="$3"
  local got_msg
  got_msg="$(field '.message.error.message')"
  if [ "$HTTP" = "$want_status" ] && [[ "$got_msg" == *"$want_class"* ]]; then
    echo "  ✓ $name — HTTP $HTTP, class $want_class in error.message"
    pass=$((pass + 1))
  else
    echo "  ✗ $name — want [HTTP $want_status, class $want_class], got [HTTP $HTTP, message '${got_msg:-<none>}']"
    echo "      body: $(echo "$BODY" | jq -c . 2>/dev/null || echo "$BODY")"
    fail=$((fail + 1))
  fi
}

echo "VC validation suite against:"
echo "  BAP caller   : $BAP_CALLER"
echo "  BPP receiver : $BPP_RECEIVER"
echo

echo "[1/4] valid-vc-accepted (via BAP caller → signed → ACK)"
post "$BAP_CALLER/confirm" "$EX/confirm-request.json"
status="$(field '.message.status')"
errmsg="$(field '.message.error.message')"
if [ "$HTTP" = "200" ] && [ "$status" = "ACK" ]; then
  echo "  ✓ valid VC accepted — HTTP $HTTP, status=$status"
  pass=$((pass + 1))
elif [[ "$errmsg" == *INVALID_PROOF* || "$errmsg" == *ISSUER_MISMATCH* \
  || "$errmsg" == *CREDENTIAL_EXPIRED* || "$errmsg" == *CREDENTIAL_REVOKED* \
  || "$errmsg" == *DID_RESOLUTION_FAILED* || "$errmsg" == *INVALID_CREDENTIAL* ]]; then
  echo "  ✗ valid VC was rejected by validateVC — HTTP $HTTP, message=$errmsg"
  echo "      body: $(echo "$BODY" | jq -c . 2>/dev/null || echo "$BODY")"
  fail=$((fail + 1))
else
  echo "  ✗ valid VC: unexpected response — HTTP $HTTP, status='${status:-<none>}', message='${errmsg:-<none>}'"
  echo "      body: $(echo "$BODY" | jq -c . 2>/dev/null || echo "$BODY")"
  fail=$((fail + 1))
fi

echo "[2/4] tampered-vc-rejected (direct to BPP receiver)"
post "$BPP_RECEIVER/confirm" "$EX/confirm-request-tampered.json"
check "tampered VC → INVALID_PROOF" 401 INVALID_PROOF

echo "[3/4] expired-vc-rejected (direct to BPP receiver)"
post "$BPP_RECEIVER/confirm" "$EX/confirm-request-expired.json"
check "expired VC → CREDENTIAL_EXPIRED" 401 CREDENTIAL_EXPIRED

echo "[4/4] wrong-issuer-vc-rejected (direct to BPP receiver)"
post "$BPP_RECEIVER/confirm" "$EX/confirm-request-wrong-issuer.json"
check "wrong issuer VC → ISSUER_MISMATCH" 401 ISSUER_MISMATCH

echo
echo "Summary: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
