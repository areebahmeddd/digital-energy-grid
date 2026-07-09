# DISCOM Policy Guide

How a distribution company (discom) authors, tests, versions, and publishes
the policy that governs P2P energy trades involving its prosumers — and how
the network enforces it.

What's in this directory:

```
discom-policy-guide/
├── README.md                    ← you are here
├── example-discom-policy.rego   ← heavily commented template — copy this
├── validate-policy.sh           ← one-command validation of any policy
└── examples/                    ← minimal payloads, one per behavior
    ├── init-allowed.json                  → no violations, no injection
    ├── init-blocked-discom.json           → allowlist violation (NACK)
    ├── init-unknown-network.json          → network-membership violation (NACK)
    ├── init-prod-blocked-test-partner.json→ test-only partner on prod (NACK)
    └── on-status-settled.json             → 4 itemized net-zero revenue flows
```

## Contents

1. [What a discom policy is](#1-what-a-discom-policy-is)
2. [How the network enforces it](#2-how-the-network-enforces-it)
3. [The interface your policy must export](#3-the-interface-your-policy-must-export)
4. [Author your policy](#4-author-your-policy)
5. [Test and validate](#5-test-and-validate)
6. [Best practices: action gating and cheap evaluation](#6-best-practices-action-gating-and-cheap-evaluation)
7. [Publish: checksum → release tag → stable URL → DeDi record](#7-publish-checksum--release-tag--stable-url--dedi-record)
8. [Checklist](#8-checklist)

## 1. What a discom policy is

A discom policy is a single [OPA rego](https://www.openpolicyagent.org/docs/latest/policy-language/)
artifact that declares, in one place:

- **Network membership** — which IES P2P trading networks (test and
  production) the discom recognizes. A trade arriving on any other
  `context.networkId` is rejected outright.
- **Trading rules** — an allowlist of counterpart discoms whose customers may
  buy energy from this discom's prosumers, **per environment**: the test
  network's allowlist can include prospective partners the discom is not yet
  permitted to trade with under production regulations, so pilots can run
  before regulatory approval. The whole allowlist can be switched off with
  one boolean (`enforce_allowlist := false`) — in which case it is not merely
  unenforced but never even evaluated.
- **Charges** — the discom's wheeling charges, delivery-shortfall penalty
  rate, and the cap on what a trading platform may retain. These feed the
  settlement computation and appear itemized in every revenue flow.
- **Settlement computation** — how the trade value is split between the four
  roles (`buyerPlatform`, `sellerPlatform`, `buyerDiscom`, `sellerDiscom`) as
  a net-zero `revenue_flows` array.

Broken rules surface as `violations`, and violations get trades **NACKed**
before they form.

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

## 2. How the network enforces it

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

## 3. The interface your policy must export

The `settlementflows` step queries the package named by `policy.queryPath`
and reads two keys from the result:

| Rule | Type | Contract |
|---|---|---|
| `violations` | set of strings | Non-empty ⇒ the trade is blocked on enforced actions. Scope settlement-integrity checks to `input.context.action == "on_status"` so they can never block select/init/confirm. |
| `revenue_flows` | array of `{role, value, currency, description}` | Only export it once settled intervals exist (otherwise zero-value flows get injected into pre-settlement payloads). Values must sum to zero. |

Everything else (charge rates, helper rules) is internal to your policy —
but keeping the exported names from the [example policy](./example-discom-policy.rego)
makes your policy drop-in compatible with the wave2 tooling.

## 4. Author your policy

Copy [`example-discom-policy.rego`](./example-discom-policy.rego) — it is a
fully commented template. Everything a discom decides lives in the
**DISCOM PARAMETERS** block at the top; the rest is mechanics you should not
need to touch:

| Knob | Meaning |
|---|---|
| `enforce_allowlist` | Master switch. `false` disables the counterpart allowlist entirely — it is the first guard of every allowlist rule, so nothing allowlist-related is even evaluated. Network-membership and settlement checks stay active. |
| `network_ids_test` / `network_ids_prod` | The IES P2P trading networks you recognize (currently `nfh.global/testnet-deg` + `indiaenergystack.in/test-ies-p2p-trading-network` for test, `indiaenergystack.in/ies-p2p-trading-network` for production). A message on any other `context.networkId` is a violation → NACK. |
| `allowed_buyer_discoms_test` / `allowed_buyer_discoms_prod` | Counterpart allowlists per environment, selected by which network set the message's networkId falls in. Put a prospective partner in the **test** list to pilot trades before the regulator approves them for the **production** list. Include your own utilityId so intra-discom trades stay allowed. |
| `wheeling_charge_buyer_per_kwh` / `wheeling_charge_seller_per_kwh` | Wheeling charges, INR per settled kWh. |
| `penalty_rate_per_kwh` | Penalty on under-delivery (REQUESTED_QTY − FINAL_ALLOC, clamped ≥ 0), INR/kWh. |
| `platform_charge_cap_per_kwh` | Ceiling on what a trading platform may retain; disclosed in the settlement itemization. |

Keep the package as `deg.contracts.p2p_trading` (then `policy.queryPath`
stays `data.deg.contracts.p2p_trading`), or rename both consistently.

> Naming gotcha: don't start rule names with `test_` (e.g. `test_network_ids`)
> — `opa test` treats `test_`-prefixed rules as unit tests. That's why the
> template uses `network_ids_test`.

## 5. Test and validate

### One command

```bash
cd specification/policies/discom-policy-guide
./validate-policy.sh my-discom-policy.rego
```

The script runs three stages: `opa check` (compiles), `opa test` (your unit
tests, if a `<policy>_test.rego` sits next to the policy), and a behavioral
suite that evaluates the policy against every payload in
[`examples/`](./examples/) and asserts the expected outcome:

| Payload | Scenario | Expected |
|---|---|---|
| `init-allowed.json` | Allowed buyer (`TEST_DISCOM_BUYER`), test network | `violations == []`, no `revenue_flows` (nothing to inject pre-settlement) |
| `init-blocked-discom.json` | Buyer discom not in the active allowlist | violation `"... not allowed to trade ..."` → NACK |
| `init-unknown-network.json` | `networkId` not in `network_ids_test`/`prod` | violation `"... not a recognized IES P2P trading network ..."` → NACK |
| `init-prod-blocked-test-partner.json` | Partner in the test allowlist arriving on the **production** network | violation `"... on the production network ..."` → NACK |
| `on-status-settled.json` | Settled interval (20 of 20.5 kWh @ 12.5 INR) | `violations == []`, 4 itemized flows, values sum to 0 |

Expected output:

```
[1/3] opa check ...
      OK
[2/3] opa test my-discom-policy.rego my-discom-policy_test.rego ...
PASS: 21/21
[3/3] behavioral suite against examples/*.json ...
      PASS  allowed init: no violations, no flows  (init-allowed.json)
      PASS  blocked discom: allowlist violation    (init-blocked-discom.json)
      PASS  unknown network: membership violation  (init-unknown-network.json)
      PASS  test-only partner blocked on prod      (init-prod-blocked-test-partner.json)
      PASS  settled: 4 itemized flows, net-zero    (on-status-settled.json)

All checks passed.
```

The example payloads are deliberately minimal — they contain exactly the
fields the policy reads, so they double as documentation of the input
contract. After editing your allowlists, adjust the buyer `utilityId` values
in your own copies of the payloads (or add payloads for your real partner
discoms).

### Unit tests

Write `with input as` tests per action, including the "must NOT fire here"
cases. The wave2 policy's test file
([`p2p_trading_ies_wave2_revenue_test.rego`](../p2p_trading_ies_wave2_revenue_test.rego))
is the reference pattern — it covers allowlist pass/fail per environment,
the `enforce_allowlist` switch (`with enforce_allowlist as false`), network
membership, charge math, shortfall penalty, and action scoping.

### Ad-hoc evaluation

```bash
opa eval -d my-discom-policy.rego \
  --input examples/init-allowed.json \
  'data.deg.contracts.p2p_trading.violations'
```

## 6. Best practices: action gating and cheap evaluation

Your policy runs inline in the message pipeline on every configured action —
badly scoped rules NACK legitimate traffic, and badly ordered rules burn
evaluation time on messages they were never meant to judge.

### 6.1 Gate every rule class by action — and put the guard FIRST

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

The same principle powers feature switches: `enforce_allowlist` is the first
guard of every allowlist rule, so setting it to `false` doesn't just suppress
the violation — it prevents the buyer-discom extraction and environment
resolution from ever being demanded.

### 6.2 Scope by lifecycle stage, not only by action

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

### 6.3 Lean on OPA's laziness — rules are computed on demand and memoized

A complete rule (`trade_value := ...`) is **not** evaluated unless something
in the query actually needs it, and once evaluated its result is **cached for
the rest of that evaluation**. Two consequences:

- Expensive aggregates are free on actions whose rules never reference them —
  *provided* the referencing rules are action-gated (6.1). With the guard
  first, `trade_value` is simply never demanded at init.
- Factor repeated expressions into named rules, not repeated inline logic:
  `total_settled_kwh` referenced by four flow descriptions is computed once,
  not four times.

**Caveat:** user-defined *functions* (`f(x) := ...`) are re-evaluated on every
call — they are not memoized. Use functions for per-item logic inside
comprehensions; use complete rules for shared scalars/aggregates.

### 6.4 Make undefined a non-event, not an error

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
	enforce_allowlist
	_buyer_discom_id                          # defined → check the allowlist
	not _buyer_discom_id in _active_buyer_allowlist
	msg := sprintf("buyer discom %q is not allowed ...", [_buyer_discom_id])
}

violations contains msg if {
	enforce_allowlist
	not _buyer_discom_id                      # undefined → its own, explicit violation
	msg := "cannot determine buyer discom: ..."
}
```

Only do this for data the decision genuinely requires — don't fail-closed on
optional fields that legitimately appear later in the lifecycle.

The environment selection uses the same idea defensively: an unknown
networkId leaves `_active_buyer_allowlist` undefined, so the allowlist rule
cannot accidentally judge against the wrong environment — the (cheap,
unconditional) network-membership violation fires instead.

### 6.5 Keep the exported surface stable and the rest private

The network contract is `violations` + `revenue_flows` (+ the documented
knobs). Prefix everything else with `_` so consumers and tests never couple
to internals, and future refactors can't break payloads.

### 6.6 Test each action's cost and behavior separately

Write `with input as` tests per action — including the "rule must NOT fire
here" cases (e.g. no FINAL_ALLOC violation at init). To find rules that
evaluate where they shouldn't, profile a representative payload per action:

```bash
opa eval -d my-discom-policy.rego --input examples/init-allowed.json \
  --profile --format=pretty 'data.deg.contracts.p2p_trading'
```

If an interval-walking rule shows up in the init profile, its action guard is
missing or not first.

## 7. Publish: checksum → release tag → stable URL → DeDi record

### 7.1 Compute the checksum

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

### 7.2 Tag a release for a stable URL

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

### 7.3 Host it anywhere — reference it in DeDi

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
    "data_url_checksum": "<sha256 hex from step 7.1>",
    "data_url_checksum_type": "sha256"
  }
}
```

The record is then resolvable at
`https://api.dedi.global/dedi/lookup/<namespace>/<registry>/<record_name>` —
that lookup URL is what goes into the payload's `policy.url`.

### 7.4 Publish under the IES namespace (recommended)

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

## 8. Checklist

- [ ] Parameters edited: `enforce_allowlist`, network sets, per-environment allowlists, wheeling/penalty/platform-cap rates
- [ ] Own utilityId present in both allowlists (intra-discom trades allowed)
- [ ] Prospective (not-yet-regulated) partners only in `allowed_buyer_discoms_test`
- [ ] `./validate-policy.sh my-discom-policy.rego` — all checks pass
- [ ] Unit tests next to the policy (`<policy>_test.rego`), `opa test` green
- [ ] Every rule class action-gated, guard as the first body expression
- [ ] Settlement-integrity violations scoped to `on_status` + a stage gate
- [ ] `opa eval --profile` on an init payload shows no settlement rules evaluating
- [ ] sha256 computed from the exact hosted bytes
- [ ] Release tagged; `data_url` is tag-pinned (immutable), not a branch URL
- [ ] DeDi record created (IES namespace recommended), lookup URL resolves
- [ ] `policy.url` in the catalog/trade payloads points at the DeDi record
