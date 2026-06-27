#!/usr/bin/env bash
# Runner for vc-validation.arazzo.yaml.
#
# Exercises the DEG `vcvalidator` middleware end-to-end against the running
# data-exchange devkit (docker compose up -d in install/). The shared
# run-arazzo.sh treats every NACK as a failure — the opposite of what the
# negative cases assert here — so this dedicated runner drives the cases with
# curl + jq and asserts the expected ACK / NACK responses directly.
#
#   Positive case  → BAP caller (signs) → BPP receiver → ACK (HTTP 200)
#   Negative cases → BPP receiver directly. The middleware runs outermost and
#                    NACKs before signature/schema validation, so rejection is
#                    deterministic and offline.
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

check() {
  local name="$1" want_status="$2" want_code="$3"
  local got_code
  got_code="$(field '.message.error.code')"
  if [ "$HTTP" = "$want_status" ] && [ "$got_code" = "$want_code" ]; then
    echo "  ✓ $name — HTTP $HTTP, error.code=$got_code"
    pass=$((pass + 1))
  else
    echo "  ✗ $name — want [HTTP $want_status, code $want_code], got [HTTP $HTTP, code '${got_code:-<none>}']"
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
errcode="$(field '.message.error.code')"
if [ "$HTTP" = "200" ] && [ "$status" = "ACK" ]; then
  echo "  ✓ valid VC accepted — HTTP $HTTP, status=$status"
  pass=$((pass + 1))
elif [ -n "$errcode" ] && [[ "$errcode" == INVALID_PROOF || "$errcode" == ISSUER_MISMATCH \
  || "$errcode" == CREDENTIAL_EXPIRED || "$errcode" == CREDENTIAL_REVOKED \
  || "$errcode" == DID_RESOLUTION_FAILED || "$errcode" == INVALID_CREDENTIAL ]]; then
  echo "  ✗ valid VC was rejected by vcvalidator — HTTP $HTTP, code=$errcode"
  echo "      body: $(echo "$BODY" | jq -c . 2>/dev/null || echo "$BODY")"
  fail=$((fail + 1))
else
  echo "  ✗ valid VC: unexpected response — HTTP $HTTP, status='${status:-<none>}', code='${errcode:-<none>}'"
  echo "      body: $(echo "$BODY" | jq -c . 2>/dev/null || echo "$BODY")"
  fail=$((fail + 1))
fi

echo "[2/4] tampered-vc-rejected (direct to BPP receiver)"
post "$BPP_RECEIVER/confirm" "$EX/confirm-tampered-vc.json"
check "tampered VC → INVALID_PROOF" 401 INVALID_PROOF

echo "[3/4] expired-vc-rejected (direct to BPP receiver)"
post "$BPP_RECEIVER/confirm" "$EX/confirm-expired-vc.json"
check "expired VC → CREDENTIAL_EXPIRED" 401 CREDENTIAL_EXPIRED

echo "[4/4] wrong-issuer-vc-rejected (direct to BPP receiver)"
post "$BPP_RECEIVER/confirm" "$EX/confirm-wrong-issuer-vc.json"
check "wrong issuer VC → ISSUER_MISMATCH" 401 ISSUER_MISMATCH

echo
echo "Summary: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
