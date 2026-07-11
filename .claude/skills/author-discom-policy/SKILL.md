---
name: author-discom-policy
description: >
  Turn plain-English rules + example payloads into a production-grade OPA rego
  policy for the IES network: one policy per use case, gated (nested) rules,
  environment map, comprehensive commented test suite with pass/fail payloads,
  a README, sha256 checksum, and a DeDi public-dataset record. Use when a
  discom (or IES) needs a new policy authored, or an existing one extended,
  validated, or published.
---

# Author a discom rego policy — from English rules to a published DeDi record

## How to use this skill

- **With Claude Code** (in this repo): type `/author-discom-policy`, then
  provide the inputs listed below — your rules in English and example
  payloads. Claude follows the steps, asks for anything missing, and
  produces the policy, tests, examples, README, checksum, and DeDi record
  fields for your review. It picks the skill up automatically on prompts
  like "create a rego policy for <use case>".
- **By hand**: work through Steps 1–7 in order; the final checklist is the
  definition of done. Everything here also applies outside this repo — a
  discom authoring in its own repository only adjusts the file paths.

This skill is the end-to-end process. The deep reference material lives in
[`specification/policies/discom-policy-guide/README.md`](../../../specification/policies/discom-policy-guide/README.md)
(the **Guide**) and the commented template
[`example-discom-policy.rego`](../../../specification/policies/discom-policy-guide/example-discom-policy.rego).
Read the Guide's §6 (gating & cheap evaluation) before writing any rule.

**Inputs you must have (ask for whatever is missing before writing code):**

1. The rules in English — each rule stated as "on <action(s)>, <condition> is
   a violation" or "on <action(s)>, compute/inject <output>".
2. At least one example payload per message shape the policy will judge
   (trade contract, catalog publish, settled on_status, credential…).
3. The discom parameters: which discoms the policy applies to, test + prod
   network IDs, allowlists, ledger URLs, currencies, charge rates.
4. The use case name (p2p-trading, demand-flex, electricity-credential-eligibility, …).
5. Where the file will be hosted and who publishes the DeDi record.

---

## Step 1 — Scope: one policy file per logical use case

Never mix use cases in one file. One rego file each for e.g. P2P trading,
demand response, eligibility against `ElectricityCredential` — even if the
same discom owns them all. Each gets its own package, test file, examples,
and DeDi record, so one use case can be revised and re-published without
re-verifying the others.

Naming:

| Artifact | Convention | Example |
|---|---|---|
| Policy file | `<discom-or-network>_<use_case>[_<kind>].rego` | `acme_p2p_trading_revenue.rego` |
| Package | `deg.contracts.<use_case>` (injects outputs) or `deg.policy.<use_case>` (violations only) | `deg.contracts.p2p_trading` |
| Test file | `test/<policy>_test.rego` (tests live in `specification/policies/test/`) | `test/acme_p2p_trading_revenue_test.rego` |
| Examples | `examples/<action>-<expected-outcome>.json` | `examples/init-blocked-discom.json` |

Don't name policy rules `test_*` — `opa test` treats those as unit tests
(Guide §4, "naming gotcha").

## Step 2 — Collect every discom decision in ONE place

All knobs go in a single **DISCOM PARAMETERS** block at the top of the file;
everything below it is mechanics. Environment-specific data lives in one
`environments` map with (at minimum) `test` and `production` entries — the
rules themselves never mention an environment (Guide §6.3):

```rego
environments := {
	"test": {
		"network_ids": {"indiaenergystack.in/test-ies-p2p-trading-network"},
		"applicable_seller_discoms": {"TEST_DISCOM_SELLER"},
		"enforce_allowlist": true,
		"allowed_buyer_discoms": {"TEST_DISCOM_BUYER", "TEST_DISCOM_SELLER"},
		"allowed_ledger_urls": {"https://sandbox-ledger.example.com"},
	},
	"production": {
		"network_ids": {"indiaenergystack.in/ies-p2p-trading-network"},
		"applicable_seller_discoms": {"TPDDL", "BRPL", "PVVNL"},
		"enforce_allowlist": true,
		"allowed_buyer_discoms": {"TPDDL", "BRPL"},
		"allowed_ledger_urls": {"https://ies-p2p-energy-ledger.beckn.io"},
	},
}
```

Rules for the map: `network_ids` disjoint across entries; an unknown
networkId leaves `_env` undefined so no `_env`-reading rule can fire (the
unconditional membership violation reports it); prospective partners go in
the **test** allowlist only; the discom's own ID stays in every allowlist so
intra-discom trades pass. Shared scalars (charge rates, currency) sit beside
the map — move one *into* the map the day it must differ per environment;
never fork a rule.

## Step 3 — Translate each English rule into a gated (nested) rule

Every rule body is a guard cascade, cheapest and most selective first. OPA
abandons a body at the first failing expression, so a violated parent gate
means the child logic is **never evaluated** — this is the nesting that keeps
per-message cost flat:

```rego
violations contains msg if {
	input.context.action == "on_status"   # 1. action gate — one comparison for other actions
	_env.enforce_allowlist                 # 2. environment/feature gate
	_settled                               # 3. lifecycle-stage gate (data shape exists)
	some i in _commit_ts.intervals         # 4. only now walk the payload
	not _price_by_id[i.id]
	msg := sprintf("settled interval %v has no PRICE_PER_KWH interval", [i.id])
}
```

Guard order: **action → environment/feature switch → stage/shape → checks**.
Name shared gates (`_is_trade_formation`, `_settled`) once and reuse them.
Scalars others read get a `default` so arithmetic never hits undefined; and
where the decision is fail-closed (allowlists), write the explicit paired
"cannot determine X" violation instead of relying on undefinedness
(Guide §6.1–§6.5).

For every rule, record in a comment which English rule it implements:

```rego
# Rule 3 (discom spec): buyer's discom must hold a valid trading licence
# in the resolved environment's allowlist. Fail-closed if undeterminable.
```

## Step 4 — Declare the exported interface up front

The policy's consumers query one package (`policy.queryPath`) and read a
fixed surface. State it in the file header comment AND the README — which
query paths exist, and whether each **blocks** (violations) or **produces**
(injected payload):

```rego
# Exported interface (queryPath: data.deg.contracts.p2p_trading)
#   violations    — set of strings; non-empty ⇒ NACK on enforced actions
#                   (select/init/confirm). Query: data.deg.contracts.p2p_trading.violations
#   revenue_flows — [{role, value, currency, description}], net-zero;
#                   only defined once settled intervals exist (on_status).
#                   Injected into the payload by the contractpolicyenforcer step.
# Everything prefixed `_` is private — do not query it.
```

Violations-only policies (eligibility checks, network policies) export just
`violations`. Settlement/derivation policies also export the injected
artifact, gated so it is undefined until there is something to inject
(`revenue_flows := [...] if _settled`) — otherwise pre-settlement payloads
get zero-value flows injected. Prefix all internals with `_`.

## Step 5 — Build the test suite (comprehensive, commented, payload-backed)

Tests are the policy's specification. The suite is complete when it covers
the **matrix**: every English rule × pass and fail × each environment it
varies in × every action where it must **not** fire.

Structure — three tiers:

1. **Unit tests** (`test/<policy>_test.rego`, same package as the policy).
   Every test carries a human-readable comment saying what it enforces, and
   asserts on the specific violation text (`contains(msg, ...)`), not just
   counts:

   ```rego
   # Rule 3: a buyer discom absent from the production allowlist is NACKed —
   # but the SAME discom trades fine on the test network (pilot before approval).
   test_prod_blocks_unapproved_partner if {
   	some msg in violations with input as _prod_input_with_buyer("NEWDISCOM")
   	contains(msg, "not allowed")
   }

   test_testnet_allows_pilot_partner if {
   	count(violations) == 0 with input as _test_input_with_buyer("NEWDISCOM")
   }
   ```

   Exercise environments and switches by patching data, not by forking rules:
   `with environments as json.patch(environments, [...])`,
   `with enforce_allowlist as false`.

   Mirror the gate cascade in the tests: for each child rule, include a case
   proving it does NOT fire when a parent gate fails (wrong action, unknown
   network, pre-settlement) — this pins the nesting so a refactor can't
   silently un-gate an expensive rule. Verify cost with
   `opa eval --profile` on a formation-action payload: no settlement rule
   may appear (Guide §6.7).

2. **Example payloads** (`examples/*.json`) — one minimal payload per
   behavior, passing AND failing, named for the expected outcome
   (`init-allowed.json`, `init-blocked-discom.json`,
   `on-status-settled.json`). Minimal = exactly the fields the policy reads,
   so the payloads double as the input-contract documentation. These come
   from the user's real example payloads, stripped down.

3. **Behavioral suite** — every example evaluated end-to-end with the
   expected outcome asserted (violations empty / specific message / N flows
   summing to zero). Extend
   [`validate-policy.sh`](../../../specification/policies/discom-policy-guide/validate-policy.sh)
   or copy its pattern next to your policy.

Run everything per policy/test pair (whole-directory `opa test .` clashes
across packages):

```bash
cd specification/policies
opa check <policy>.rego
opa test <policy>.rego test/<policy>_test.rego -v
discom-policy-guide/validate-policy.sh <policy>.rego
```

All three must be green before publishing.

## Step 6 — Write the policy README

Every policy ships a README section (in
[`specification/policies/README.md`](../../../specification/policies/README.md)
or its own file for external discoms) stating: purpose (the English rules,
numbered — the same numbers the rule comments cite), the exported query
paths and whether each blocks or produces, the discom parameters and their
meaning, how to run the tests, and an `opa eval` one-liner against a sample
payload.

## Step 7 — Checksum, immutable URL, DeDi record

1. **Freeze the bytes, then hash them.** The checksum must cover the exact
   bytes served at the hosting URL (CRLF/trailing-newline changes break it):

   ```bash
   shasum -a 256 <policy>.rego | awk '{print $1}'          # before hosting
   curl -fsSL "$POLICY_URL" | shasum -a 256 | awk '{print $1}'   # verify after
   ```

2. **Tag a release; use the tag-pinned raw URL.** Never a branch URL — the
   `contractpolicyenforcer` step recomputes the hash on every fetch and rejects on
   mismatch. Changing the policy means a new tag + a new record (version).

   ```bash
   git tag policy-<use-case>-v1.0.0 && git push origin --tags
   # https://raw.githubusercontent.com/<org>/<repo>/refs/tags/policy-<use-case>-v1.0.0/path/<policy>.rego
   ```

3. **Create the DeDi public-dataset record** (via the
   [DeDi dashboard](https://dedi.global), IES namespace
   `indiaenergystack.in` / registry `ies-policies` recommended — Guide §7.4).
   The record `details` must satisfy DeDi's Public Data Set Schema
   (required: `publisher_id`, `name`, `description`;
   `data_url_checksum_type` enum: `sha256|sha384|sha512|md5|sha1` — use
   **sha256**):

   ```jsonc
   {
     "record_name": "<discom>-<use-case>-rego-policy-v1",   // versioned
     "description": "version 1 of <use case> rego policy for <discom/network>",
     "details": {
       "name": "<discom>-<use-case>-rego-policy",
       "tags": ["policy", "<use-case>", "discom"],
       "type": "other",
       "publisher_id": "<discom-domain>",
       "data_url": "<tag-pinned raw URL>",
       "data_url_checksum": "<sha256 hex>",
       "data_url_checksum_type": "sha256"
     }
   }
   ```

4. **Verify the lookup URL resolves** and the checksum matches the hosted
   bytes:

   ```bash
   URL="https://api.dedi.global/dedi/lookup/<namespace>/<registry>/<record_name>"
   curl -fsSL "$URL" | jq -r '.data.details.data_url_checksum'
   curl -fsSL "$(curl -fsSL "$URL" | jq -r '.data.details.data_url')" | shasum -a 256
   ```

   Live reference record:
   `https://api.dedi.global/dedi/lookup/indiaenergystack.in/ies-policies/ies-p2p-network-settlement-rego-policy-v1`

5. **Wire it into payloads.** The DeDi **lookup URL** (not the raw file URL)
   goes into `message.contract.contractAttributes.policy`:

   ```json
   "policy": {
     "url": "https://api.dedi.global/dedi/lookup/indiaenergystack.in/ies-policies/<record_name>",
     "queryPath": "data.deg.contracts.<use_case>"
   }
   ```

## Final checklist

- [ ] One policy file = one logical use case; package + queryPath consistent
- [ ] All discom decisions in the DISCOM PARAMETERS block; environment data in ONE `environments` map (test + production), `network_ids` disjoint
- [ ] Every rule: guards first (action → env/switch → stage → checks); comment citing the English rule it implements
- [ ] Exported interface documented in file header + README: query paths, violations vs injected outputs; internals `_`-prefixed
- [ ] Injected outputs (e.g. `revenue_flows`) gated on the stage that makes them meaningful; net-zero where applicable
- [ ] Test matrix complete: per rule × pass/fail × per environment × "must NOT fire" per gate; every test commented; assertions on violation text
- [ ] Example payloads for every pass AND fail behavior, minimal, outcome-named
- [ ] `opa check` + per-pair `opa test` + behavioral suite green; `opa eval --profile` on a formation payload shows no settlement rules
- [ ] README written (rules, query paths, parameters, how to test)
- [ ] sha256 of the exact hosted bytes; tag-pinned immutable `data_url`
- [ ] DeDi record created under `indiaenergystack.in`/`ies-policies`, lookup URL resolves, checksum verified
- [ ] Payloads carry the DeDi lookup URL + queryPath
