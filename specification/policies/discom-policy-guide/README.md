# DISCOM Policy Guide

How a distribution company (discom) authors, versions, and publishes the policy
that governs P2P energy trades involving its prosumers — and how the network
enforces it.

## What a discom policy is

A discom policy is a single [OPA rego](https://www.openpolicyagent.org/docs/latest/policy-language/)
artifact that declares, in one place:

- **Trading rules** — e.g. an allowlist of counterpart discoms whose customers
  may buy energy from this discom's prosumers. Broken rules surface as
  `violations`, and violations get trades **NACKed** before they form.
- **Charges** — the discom's wheeling charges, delivery-shortfall penalty
  rate, and the cap on what a trading platform may retain. These feed the
  settlement computation and appear itemized in every revenue flow.
- **Settlement computation** — how the trade value is split between the four
  roles (`buyerPlatform`, `sellerPlatform`, `buyerDiscom`, `sellerDiscom`) as
  a net-zero `revenue_flows` array.

The catalog publisher links the **prosumer's discom's** policy into every
trade via `message.contract.contractAttributes.policy`:

```json
"policy": {
  "url": "https://api.dedi.global/dedi/lookup/indiaenergystack.in/ies-policies/<record-name>",
  "queryPath": "data.deg.contracts.p2p_trading"
}
```

So one policy — authored by the discom whose prosumer is selling — governs
each trade end to end.

## How the network enforces it

The ONIX adapter's `settlementflows` pipeline step resolves `policy.url`,
compiles the rego, and evaluates it against the full message. Two modes,
controlled per pipeline in the adapter YAML:

| Mode | Config | Behavior |
|---|---|---|
| Enforcement | `violationActions: "select,init,confirm"` | Non-empty `violations` → synchronous **400 NACK**; fail-closed (missing/unfetchable policy also NACKs) |
| Injection | `violationActions: ""` | On `on_status`, once settled intervals exist, `revenue_flows` is written into the payload; violations are only logged |

See the wave2 sellerapp config
([`devkits/p2p-trading-ies-wave2/config/local-p2p-trading-sellerapp.yaml`](../../../devkits/p2p-trading-ies-wave2/config/local-p2p-trading-sellerapp.yaml))
for a working example of both.

## The interface your policy must export

The `settlementflows` step queries the package named by `policy.queryPath`
and reads two keys from the result:

| Rule | Type | Contract |
|---|---|---|
| `violations` | set of strings | Non-empty ⇒ the trade is blocked on enforced actions. Scope settlement-integrity checks to `input.context.action == "on_status"` so they can never block select/init/confirm. |
| `revenue_flows` | array of `{role, value, currency, description}` | Only export it once settled intervals exist (otherwise zero-value flows get injected into pre-settlement payloads). Values must sum to zero. |

Everything else (charge rates, helper rules) is internal to your policy —
but keeping the exported names from the [example policy](./example-discom-policy.rego)
makes your policy drop-in compatible with the wave2 tooling.

## Authoring walkthrough

1. Copy [`example-discom-policy.rego`](./example-discom-policy.rego) — it is a
   fully commented template. Edit the parameter block at the top: your
   allowlist, wheeling rates, penalty rate, platform-charge cap.
2. Keep the package as `deg.contracts.p2p_trading` (then `policy.queryPath`
   stays `data.deg.contracts.p2p_trading`), or rename both consistently.
3. Test locally:

   ```bash
   opa test my-discom-policy.rego my-discom-policy_test.rego -v
   # and against a real payload:
   opa eval -d my-discom-policy.rego \
     --input init-request.json \
     'data.deg.contracts.p2p_trading.violations'
   ```

   The wave2 policy's test file
   ([`p2p_trading_ies_wave2_revenue_test.rego`](../p2p_trading_ies_wave2_revenue_test.rego))
   shows how to cover the allowlist, charge math, and action scoping.

## Best practices: action gating and cheap evaluation

Your policy runs inline in the message pipeline on every configured action —
badly scoped rules NACK legitimate traffic, and badly ordered rules burn
evaluation time on messages they were never meant to judge.

### 1. Gate every rule class by action — and put the guard FIRST

OPA evaluates a rule body top to bottom and abandons it at the first failing
expression. A guard on `input.context.action` as the **first** line means the
rest of the body — interval walks, aggregations, sprintf — is never evaluated
for other actions:

```rego
# GOOD — action guard first: for init/confirm this rule costs one comparison.
violations contains msg if {
	input.context.action == "on_status"      # cheapest, most selective first
	some i in _commit_ts.intervals            # only runs on on_status
	i.id in _settled_interval_ids
	not _price_by_id[i.id]
	msg := sprintf("settled interval %v has no matching PRICE_PER_KWH interval", [i.id])
}

# BAD — walks every interval on every action, then throws the work away.
violations contains msg if {
	some i in _commit_ts.intervals
	i.id in _settled_interval_ids
	not _price_by_id[i.id]
	input.context.action == "on_status"       # guard last = wasted evaluation
	msg := sprintf(...)
}
```

For rule classes that apply to several actions, name the gate once and reuse
it — this also documents intent:

```rego
_trade_formation_actions := {"select", "init", "confirm"}

_is_trade_formation if input.context.action in _trade_formation_actions
```

### 2. Scope by lifecycle stage, not only by action

`on_status` arrives many times before settlement. Gating on the action alone
still fires settlement checks against half-built contracts. Add a data-shape
gate (here: "settled intervals exist") so the rule only judges messages that
carry the data it validates:

```rego
_settled := count(_settled_interval_ids) > 0

violations contains msg if {
	input.context.action == "on_status"
	_settled                                  # stage gate: skip pre-settlement on_status
	not net_zero_ok
	msg := sprintf("net-zero failed: revenue sum = %g (expected 0)", [_revenue_sum])
}
```

The same idea protects injection: export `revenue_flows` only when there is
something to inject, so trade-formation payloads stay untouched:

```rego
revenue_flows := [...] if _settled
```

### 3. Lean on OPA's laziness — rules are computed on demand and memoized

A complete rule (`trade_value := ...`) is **not** evaluated unless something
in the query actually needs it, and once evaluated its result is **cached for
the rest of that evaluation**. Two consequences:

- Expensive aggregates are free on actions whose rules never reference them —
  *provided* the referencing rules are action-gated (point 1). With the guard
  first, `trade_value` is simply never demanded at init.
- Factor repeated expressions into named rules, not repeated inline logic:
  `total_settled_kwh` referenced by four flow descriptions is computed once,
  not four times.

**Caveat:** user-defined *functions* (`f(x) := ...`) are re-evaluated on every
call — they are not memoized. Use functions for per-item logic inside
comprehensions; use complete rules for shared scalars/aggregates.

### 4. Make undefined a non-event, not an error

Partial-set rules (`violations contains msg if {...}`) are undefined-safe: a
body that fails just contributes nothing. For scalars that other rules read,
declare a `default` so downstream arithmetic never hits undefined:

```rego
default penalty_charge := 0
penalty_charge := _round2(penalty_rate_per_kwh * total_shortfall_kwh) if _settled
```

And when a violation *should* fire on missing data (fail-closed decisions
like the allowlist), make that an explicit paired rule rather than an
accident of undefinedness:

```rego
violations contains msg if {
	_buyer_discom_id                          # defined → check the allowlist
	not _buyer_discom_id in allowed_buyer_discoms
	msg := sprintf("buyer discom %q is not allowed ...", [_buyer_discom_id])
}

violations contains msg if {
	not _buyer_discom_id                      # undefined → its own, explicit violation
	msg := "cannot determine buyer discom: ..."
}
```

Only do this for data the decision genuinely requires — don't fail-closed on
optional fields that legitimately appear later in the lifecycle.

### 5. Keep the exported surface stable and the rest private

The network contract is `violations` + `revenue_flows` (+ the documented
charge parameters). Prefix everything else with `_` so consumers and tests
never couple to internals, and future refactors can't break payloads.

### 6. Test each action's cost and behavior separately

Write `with input as` tests per action — including the "rule must NOT fire
here" cases (e.g. no FINAL_ALLOC violation at init). To find rules that
evaluate where they shouldn't, profile a representative payload per action:

```bash
opa eval -d my-discom-policy.rego --input init-request.json \
  --profile --format=pretty 'data.deg.contracts.p2p_trading'
```

If an interval-walking rule shows up in the init profile, its action guard is
missing or not first.

## Publishing: checksum → release tag → stable URL → DeDi record

### 1. Compute the checksum

The DeDi record carries an integrity checksum of the exact bytes served at
your hosting URL:

```bash
shasum -a 256 my-discom-policy.rego
# → 3f6c1a…9be2  my-discom-policy.rego
```

That hex digest goes into the record's `data_url_checksum`, with
`data_url_checksum_type: sha256`. The `settlementflows` step recomputes the
hash on every fetch and rejects the policy on mismatch — so the checksum, not
the hosting location, is what consumers trust.

### 2. Tag a release for a stable URL

The URL in the DeDi record must serve **immutable** content — if the file
changes under the same URL, every adapter's checksum verification breaks.
Never point a record at a branch URL for production use. Tag a release and
use the tag-pinned raw URL:

```bash
git add my-discom-policy.rego
git commit -m "policy: my-discom trading policy v1.0.0"
git tag policy-v1.0.0
git push origin main --tags
```

Stable URL form (GitHub):

```
https://raw.githubusercontent.com/<org>/<repo>/refs/tags/policy-v1.0.0/path/to/my-discom-policy.rego
```

To change the policy, publish a **new** tag and a **new** DeDi record version
(or a new record) — never rewrite a tag.

### 3. Host it anywhere — reference it in DeDi

The policy file itself can be hosted **anywhere**: the discom's own website,
the discom's git repo, an object store. Hosting is not what makes it
authoritative — the **DeDi record referencing it** is. A DeDi public-dataset
record binds a versioned, checksummed pointer to your artifact, and that
record URL is what payloads carry in `contractAttributes.policy.url`.

Create the record (via the [DeDi dashboard](https://dedi.global)) with these
fields (this is the live wave2 record as a template):

```jsonc
{
  "record_name": "acme-discom-trading-policy-v1",   // versioned name
  "description": "ACME Discom P2P trading policy (allowlist + charges + settlement)",
  "details": {
    "name": "acme-discom-trading-policy",
    "tags": ["p2p-trading", "policy", "settlement", "discom"],
    "type": "other",
    "publisher_id": "acme-discom.example.com",
    "data_url": "https://raw.githubusercontent.com/acme-discom/policies/refs/tags/policy-v1.0.0/my-discom-policy.rego",
    "data_url_checksum": "<sha256 hex from step 1>",
    "data_url_checksum_type": "sha256"
  }
}
```

The record is then resolvable at
`https://api.dedi.global/dedi/lookup/<namespace>/<registry>/<record_name>` —
that lookup URL is what goes into the payload's `policy.url`.

### 4. Publish under the IES namespace (recommended)

Publish your record in the **India Energy Stack** namespace/registry —
`indiaenergystack.in` / `ies-policies` — rather than a private namespace:

- **Uniform quality control**: IES reviews records entering `ies-policies`,
  so consumers get a consistent bar for policy quality and metadata.
- **A single root of trust**: adapters pin the namespace once via the
  `settlementflows` step's `allowedPolicyUrlPrefixes` config and thereby
  accept any discom's policy published under it — no per-discom
  configuration:

  ```yaml
  - id: settlementflows
    config:
      # Only India Energy Stack policy records on DeDi are accepted.
      allowedPolicyUrlPrefixes: "https://api.dedi.global/dedi/lookup/indiaenergystack.in"
  ```

A policy referenced from outside the allowlisted prefixes is rejected — on
enforced actions (select/init/confirm) that rejection is itself a NACK.

## Checklist

- [ ] Parameters edited (allowlist, wheeling, penalty, platform cap)
- [ ] `opa test` green; `violations` empty on a known-good init payload
- [ ] Every rule class action-gated, guard as the first body expression
- [ ] Settlement-integrity violations scoped to `on_status` + a stage gate
- [ ] `opa eval --profile` on an init payload shows no settlement rules evaluating
- [ ] `revenue_flows` only exported when settled intervals exist, sums to zero
- [ ] sha256 computed from the exact hosted bytes
- [ ] Release tagged; `data_url` is tag-pinned (immutable), not a branch URL
- [ ] DeDi record created (IES namespace recommended), lookup URL resolves
- [ ] `policy.url` in the catalog/trade payloads points at the DeDi record
