# Demand Flex Devkit

Beckn Protocol v2.0 devkit for **behavioral demand response**. A utility publishes flexibility needs (peak demand reduction), and aggregators discover, commit to, and deliver demand flexibility — with settlement based on measured grid-meter performance and optional per-DER (Distributed Energy Resource) reconciliation telemetry.

For the shared stack topology, prerequisites, Quick Start, transaction flow, hosting, ngrok notes, and cleanup, see [../README.md](../README.md).

## Scenario

**TPDDL** (Tata Power Delhi Distribution, the utility) publishes a 500 kW curtailment need during a peak event window. **GreenFlex Aggregator** discovers the opportunity, enrolls participating grid meters (each with one or more DERs sitting behind it — EV chargers in this example), and commits to providing 150 kW of demand reduction. After the event, TPDDL publishes per-meter baselines, measured actuals, and per-DER BecknTimeSeries (collected from GreenFlex out-of-band) before computing settlement (e.g., 150 kWh × 3.5 INR/kWh = 525 INR).

**Settlement is utility-only.** Revenue is computed against the DISCOM's own grid-meter measurements (`BASELINE` and `USAGE` per interval), authored by the utility (BPP) and pushed via `on_status`. The settlement rego ([`demand_flex_revenue.rego`](../../specification/policies/demand_flex_revenue.rego)) is hard-wired to ignore any performance record whose `methodology` is in the non-settlement allowlist (`DER_TELEMETRY`) — even if such a record is the first one in the payload, even if it is the only record on the wire (in which case the rego refuses to settle and surfaces an explicit violation). Baselines do not appear in DER telemetry at all.

**DER telemetry is reconciliation-only.** The seller (aggregator) MAY contribute per-DER proof-of-performance telemetry — `USAGE` / `POWER` / `SOC_END` per interval and `GPS_LAT` / `GPS_LON` once per event — which the DISCOM aggregates out-of-band from the aggregator's vendor-API integrations (e.g. Tata EVP Telematics, MG iMotion) and republishes on the same `on_status` channel as a separate performance record (`methodology: "DER_TELEMETRY"`, status `REPORT_DELIVERED`). It exists so anomalous meter readings can be cross-checked against DER truth after the fact; it never feeds the revenue flow.

## Use Cases

| Use Case | BPP (Provider) | BAP (Consumer) | Description |
|----------|---------------|----------------|-------------|
| [uc1-bdr-w-baselining](./uc1-bdr-w-baselining/) | TPDDL (utility) | GreenFlex (aggregator) | Publish flex need → discover → commit → baseline → actuals → DER telemetry → settle on meter actuals/baselines |

## Key Schemas

| Schema | Slot | Description |
|--------|------|-------------|
| [DemandFlexNeed](../../specification/schema/DemandFlexNeed/v2.0/) | `resourceAttributes` | Direction (REDUCE/INCREASE), event window, capacity type, location |
| [DemandFlexBuyOffer](../../specification/schema/DemandFlexBuyOffer/v2.0/) | `offerAttributes` | Incentive per kWh, baseline methodology, penalty rate, seller's `participatingMeters` / `ders` / `reportDescriptors` |
| [DER](../../specification/schema/DER/v1.0/) | `offerAttributes.inputs[seller].inputs.ders[*]` | Distributed Energy Resource — stable identity (derId, derType, behindMeter, make, model) + rated dimensioning (ratedPowerKw, energyCapacityKwh). EV chargers, batteries, solar PV, smart HVAC, … |
| [DEGContract](../../specification/schema/DEGContract/v2.0/) | `contractAttributes` | Roles (buyer/seller), policy reference, revenue flows |
| [DemandFlexPerformance](../../specification/schema/DemandFlexPerformance/v2.0/) | `performanceAttributes` | M&V baselines and actuals per meter; per-DER BecknTimeSeries for reconciliation |
| [BecknReportDescriptors](../../specification/schema/BecknReportDescriptors/v1.0/) | `offerAttributes.inputs[seller].inputs.reportDescriptors` | OpenADR3-aligned descriptors with `cardinality` (PER_INTERVAL / PER_EVENT) committing what DER telemetry types the seller will report |
| [BecknPageInfo](../../specification/schema/BecknPageInfo/v1.0/) | `performanceAttributes.pageInfo` | Optional — present only when `meters[]` is split across messages (push or pull). Absence of `pageInfo` is the signal that the message is self-contained. |
| [BecknResourceRef](../../specification/schema/BecknResourceRef/v1.0/) | `inputs[seller].inputs.participatingMetersRef` / `performanceAttributes.metersRef` | Optional — off-protocol delivery for bulk collections (content-addressed via `sha256`). |

## Bulk cohorts (paginating thousands of meters)

For demonstration purposes the example fixtures carry three meters. Real DR programs routinely span thousands. Pagination kicks in at two distinct points in the flow:

| Where | When inline is fine | When to switch | Mechanism |
|---|---|---|---|
| Confirm-time cohort enrollment (`participatingMeters[]` on the seller's offer block) | Up to ~10k meters fits in a single confirm message | Above that threshold the confirm payload becomes unwieldy and the offer can't span messages (offers are bound at confirm) | Replace inline `participatingMeters` with `participatingMetersRef` ([BecknResourceRef](../../specification/schema/BecknResourceRef/v1.0/)) and pin the cohort with `participatingMetersDigest` (on-protocol `sha256` of the sorted meter IDs) so the contract stays auditable even after the off-protocol URL expires. |
| Performance-time telemetry (`performanceAttributes.meters[]` on `on_status`) | Up to ~10k meters fits in a single on_status | Above that threshold the BPP either splits the delivery across multiple on_status messages (paged inline) or substitutes `metersRef` (off-protocol) | Paged inline: BPP fills `pageInfo` ([BecknPageInfo](../../specification/schema/BecknPageInfo/v1.0/)) on each message; receivers assemble by `sequence` and only settle when `isLast: true`. Off-protocol: BPP omits `meters[]` and ships `metersRef` instead. |

The 10k threshold is a working guideline, not a hard cap — implementations tune to their wire budget.

### Push vs pull pagination

Both delivery patterns share the same `BecknPageInfo` shape; they differ only in who drives the cadence:

- **BPP push** — BPP fires `N` back-to-back `on_status` messages, each with monotonically-increasing `pageInfo.sequence`, ending with `isLast: true`. The BAP does nothing special — it accumulates and fires settlement on the last page. Example: [`on-status-response-actuals-paged-push.json`](./uc1-bdr-w-baselining/examples/on-status-response-actuals-paged-push.json).
- **BAP pull** — BAP issues `status` calls carrying a `pageCursor` tag, and the BPP returns one page per call. The response echoes `pageInfo.cursor` and advertises `pageInfo.nextCursor` for the next request. Use when the BAP needs flow control or wants to interleave page fetches with other work. Example: [`on-status-response-actuals-paged-pull.json`](./uc1-bdr-w-baselining/examples/on-status-response-actuals-paged-pull.json) (the inbound `status` request that triggered this response is recorded in the `_comment_inbound_request` block of the same file).

Both examples reuse the same 12,000-meter `participatingMetersRef` cohort to show how a bulk-enrolled contract performs at scale.

### Network rego under pagination

The cross-field type-coverage and cardinality checks in [`demand_flex_network.rego`](./policies/demand_flex_network.rego) operate per-meter — they fire on each page in isolation, with no awareness of the wider delivery. That's fine: any malformed meter telemetry NACKs immediately on the page that carries it, regardless of the page's position. Settlement runs against the assembled view only (see [`demand_flex_revenue.rego`](../../specification/policies/demand_flex_revenue.rego)).

## Postman

`uc1-bdr-w-baselining/postman/demand-flex-uc1-bdr-w-baselining.{BAP,BPP}-DEG.postman_collection.json`. Collections are regenerated with `python3 scripts/generate_postman_collection.py --role BAP|BPP`.

## Policy Enforcement

Uses OPA (Open Policy Agent) via the `opapolicychecker` plugin. Policies are declared in [`config/opa-network-policies.yaml`](./config/opa-network-policies.yaml).

A single rego file ([`policies/demand_flex_network.rego`](./policies/demand_flex_network.rego), mirrors [`specification/policies/demand_flex_network.rego`](../../specification/policies/demand_flex_network.rego)) backs every networkId with one `violations` rule that enforces:

| Check | Behavior |
|---|---|
| BecknTimeSeries type-coverage | Every `payloadType` used in `intervals[*].payloads[*].type` must be declared in the meter's `payloadDescriptors`. |
| PER_EVENT cardinality | Each `PER_EVENT` type declared by the seller (e.g. `GPS_LAT`, `GPS_LON`) must appear in exactly one interval of any meter that declares it. |
| PER_INTERVAL cardinality | Each `PER_INTERVAL` type declared by the seller (e.g. `BASELINE`, `USAGE`, `POWER`, `SOC_END`) must appear in every interval of any meter that declares it. |

Cardinality self-skips when no `reportDescriptors` are on the wire (e.g. a status round-trip carrying only commitment ids) or when the meter's own `payloadDescriptors` don't declare the type (e.g. a grid-meter baselines push that only declares `BASELINE`). So traffic without DER commitments passes transparently.

Settlement rego is referenced per-contract via `contractAttributes.policy.url` → [`specification/policies/demand_flex_revenue.rego`](../../specification/policies/demand_flex_revenue.rego), package `deg.contracts.demand_flex`. It picks the first `performance[*]` record whose `performanceAttributes.methodology` is NOT in the non-settlement allowlist (`{"DER_TELEMETRY"}`) and computes a net-zero `buyer pays / seller receives` revenue flow from its per-meter `BASELINE` / `USAGE`. If a payload carries only DER-telemetry perf records, the rego emits an explicit `"no settlement-eligible performance record found"` violation rather than coercing DER numbers into the settlement — see [`demand_flex_revenue_test.rego`](../../specification/policies/demand_flex_revenue_test.rego) `test_der_perf_record_excluded_from_settlement` and `test_der_only_payload_violation`.

Signature/registry lookups currently target `nfh.global/testnet-deg` via the `allowedNetworkIDs` key on the `dediregistry` plugin. Subscriber IDs are placeholders (`bap.example.com` / `bpp.example.com`) with signing keys borrowed from the p2p-trading devkit, so arazzo flows will NACK on lookup until real subscribers are registered on testnet-deg.

## Related

- [DemandFlexNeed Schema](../../specification/schema/DemandFlexNeed/v2.0/) — Flex resource attributes
- [DemandFlexBuyOffer Schema](../../specification/schema/DemandFlexBuyOffer/v2.0/) — Incentive and policy terms, including `ders` and `reportDescriptors`
- [DER Schema](../../specification/schema/DER/v1.0/) — Distributed Energy Resource class — EV chargers, batteries, solar PV, smart HVAC; reusable across DEG
- [BecknReportDescriptors Schema](../../specification/schema/BecknReportDescriptors/v1.0/) — OpenADR3-aligned DER-telemetry commitments
- [Demand Flexibility Implementation Guide](../../docs/implementation-guides/v2/Demand_Flexibility/Demand_Flexibility.md) — Detailed protocol flows and schema mappings
- [Data Exchange Devkit](../data-exchange/) — Companion devkit for energy data delivery
