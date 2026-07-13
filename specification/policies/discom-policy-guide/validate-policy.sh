#!/usr/bin/env bash
# Validate a discom policy against the guide's example payloads.
#
# Usage (from specification/policies/discom-policy-guide/):
#   ./validate-policy.sh                          # validates example-discom-policy.rego
#   ./validate-policy.sh my-discom-policy.rego    # validates your policy
#   ./validate-policy.sh my-policy.rego data.deg.contracts.p2p_trading
#
# What it checks (in order):
#   1. opa check          — the policy compiles
#   2. opa test           — unit tests, if a <policy>_test.rego exists
#   3. behavioral suite   — evaluates the policy against examples/*.json and
#                           asserts the expected violations / revenue flows
#
# Prerequisites: opa (https://www.openpolicyagent.org), python3.
#
# Exit code 0 = everything passed; non-zero otherwise.

set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"

POLICY="${1:-$HERE/example-discom-policy.rego}"
QUERY="${2:-data.deg.contracts.p2p_trading}"
EXAMPLES="$HERE/examples"

if [ ! -f "$POLICY" ]; then
  echo "ERROR: policy file not found: $POLICY" >&2
  exit 1
fi

echo "Policy : $POLICY"
echo "Query  : $QUERY"
echo ""

# ── 1. Compile ──────────────────────────────────────────────────────────────
echo "[1/3] opa check ..."
opa check "$POLICY"
echo "      OK"

# ── 2. Unit tests (optional) ────────────────────────────────────────────────
TEST_FILE="${POLICY%.rego}_test.rego"
if [ -f "$TEST_FILE" ]; then
  echo "[2/3] opa test $(basename "$POLICY") $(basename "$TEST_FILE") ..."
  opa test "$POLICY" "$TEST_FILE"
else
  echo "[2/3] no unit-test file next to the policy ($(basename "$TEST_FILE")) — skipped."
  echo "      (Recommended: copy the pattern from specification/policies/p2p-trading-ies-wave2-contractpolicy_test.rego)"
fi

# ── 3. Behavioral suite against example payloads ────────────────────────────
echo "[3/3] behavioral suite against $EXAMPLES/*.json ..."

evaluate() { # $1 = input file → full package document on stdout
  opa eval -d "$POLICY" --input "$1" "$QUERY" --format=json
}

fail=0
assert() { # $1 = name, $2 = input file, $3 = python assertion body (gets `doc`)
  local name="$1" input="$2" py="$3"
  local out
  out="$(evaluate "$EXAMPLES/$input")"
  if echo "$out" | python3 -c "
import json, sys
r = json.load(sys.stdin)['result'][0]['expressions'][0]['value']
violations = r.get('violations', [])
flows = r.get('revenue_flows')
assert_ok = True
$py
sys.exit(0 if assert_ok else 1)
"; then
    printf '      PASS  %-38s (%s)\n' "$name" "$input"
  else
    printf '      FAIL  %-38s (%s)\n' "$name" "$input"
    echo "$out" | python3 -c "import json,sys; r=json.load(sys.stdin)['result'][0]['expressions'][0]['value']; print('            violations:', r.get('violations', [])); print('            revenue_flows:', 'present' if 'revenue_flows' in r else 'absent')"
    fail=1
  fi
}

# Allowed buyer on the test network: clean, and nothing to inject yet.
assert "allowed init: no violations, no flows" "init-allowed.json" '
assert_ok = (violations == [] and flows is None)'

# Buyer discom outside the active (test) allowlist: exactly the allowlist violation.
assert "blocked discom: allowlist violation" "init-blocked-discom.json" '
assert_ok = any("not allowed to trade" in v for v in violations)'

# networkId not in network_ids_test/prod: membership violation.
assert "unknown network: membership violation" "init-unknown-network.json" '
assert_ok = any("not a recognized" in v for v in violations)'

# Partner allowed on the TEST network only, arriving on PROD: blocked.
assert "test-only partner blocked on prod" "init-prod-blocked-test-partner.json" '
assert_ok = any("on the production network" in v for v in violations)'

# Discoms recording against an unrecognized ledger endpoint: blocked.
assert "rogue ledger endpoint: violation" "init-bad-ledger-url.json" '
assert_ok = any("not a permitted ledger endpoint" in v for v in violations)'

# Seller discom this policy does not apply to: applicability violation.
assert "inapplicable seller: policy violation" "init-policy-not-applicable.json" '
assert_ok = any("does not apply to seller discom" in v for v in violations)'

# PRICE_PER_KWH priced in EUR: currency violation.
assert "non-INR currency: violation" "init-wrong-currency.json" '
assert_ok = any("currency \"EUR\" is not permitted" in v for v in violations)'

# Clean catalog publish: applicable provider, INR pricing → no violations.
assert "allowed publish: no violations" "publish-allowed.json" '
assert_ok = (violations == [] and flows is None)'

# Catalog offer from a discom this policy does not apply to: blocked at source.
assert "publish by inapplicable provider" "publish-blocked-provider.json" '
assert_ok = any("does not apply to seller discom" in v for v in violations)'

# Settled on_status: clean, four flows, net-zero.
assert "settled: 4 itemized flows, net-zero" "on-status-settled.json" '
assert_ok = (violations == [] and flows is not None and len(flows) == 4
             and abs(sum(f["value"] for f in flows)) < 0.005)'

echo ""
if [ "$fail" -eq 0 ]; then
  echo "All checks passed."
else
  echo "Some checks FAILED." >&2
  exit 1
fi
