# Demand Flex Devkit

Beckn Protocol v2.0 devkit for **behavioral demand response**. A utility publishes flexibility needs (peak demand reduction), and aggregators discover, commit to, and deliver demand flexibility — with settlement based on measured grid-meter performance and optional per-device vendor backstop telemetry.

For the shared stack topology, prerequisites, Quick Start, transaction flow, hosting, ngrok notes, and cleanup, see [../README.md](../README.md).

## Scenario

**TPDDL** (Tata Power Delhi Distribution, the utility) publishes a 500 kW curtailment need during a peak event window. **GreenFlex Aggregator** discovers the opportunity, enrolls participating grid meters (each backed by an EV charger as a vendor device), and commits to providing 150 kW of demand reduction. After the event, TPDDL publishes per-meter baselines, measured actuals, and per-EV vendor BecknTimeSeries (collected from GreenFlex out-of-band) before computing settlement (e.g., 150 kWh × 3.5 INR/kWh = 525 INR).

Settlement is computed against the DISCOM's own grid-meter measurements (`BASELINE` and `USAGE` per interval). The per-EV vendor telemetry — `BASELINE` / `USAGE` / `POWER` / `SOC_END` per interval and `GPS_LAT` / `GPS_LON` once per event — flows over the same `on_status` channel as a **backstop / reconciliation** payload only; the settlement rego never reads it. Anomalous meter readings can be cross-checked against vendor truth without changing how revenue is computed.

## Use Cases

| Use Case | BPP (Provider) | BAP (Consumer) | Description |
|----------|---------------|----------------|-------------|
| [uc1-bdr-w-baselining](./uc1-bdr-w-baselining/) | TPDDL (utility) | GreenFlex (aggregator) | Publish flex need → discover → commit → baseline → actuals → vendor backstop telemetry → settle on meter actuals/baselines |

## Key Schemas

| Schema | Slot | Description |
|--------|------|-------------|
| [DemandFlexNeed](../../specification/schema/DemandFlexNeed/v2.0/) | `resourceAttributes` | Direction (REDUCE/INCREASE), event window, capacity type, location |
| [DemandFlexBuyOffer](../../specification/schema/DemandFlexBuyOffer/v2.0/) | `offerAttributes` | Incentive per kWh, baseline methodology, penalty rate, seller's `participatingMeters` / `vendorDevices` / `reportDescriptors` |
| [DEGContract](../../specification/schema/DEGContract/v2.0/) | `contractAttributes` | Roles (buyer/seller), policy reference, revenue flows |
| [DemandFlexPerformance](../../specification/schema/DemandFlexPerformance/v2.0/) | `performanceAttributes` | M&V baselines and actuals per meter; per-EV vendor BecknTimeSeries for backstop |
| [BecknReportDescriptors](../../specification/schema/BecknReportDescriptors/v1.0/) | `offerAttributes.inputs[seller].inputs.reportDescriptors` | OpenADR3-aligned descriptors with `cardinality` (PER_INTERVAL / PER_EVENT) committing what vendor telemetry types the seller will report |

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

Cardinality self-skips when no `reportDescriptors` are on the wire (e.g. a status round-trip carrying only commitment ids) or when the meter's own `payloadDescriptors` don't declare the type (e.g. a grid-meter baselines push that only declares `BASELINE`). So traffic without vendor commitments passes transparently.

Settlement rego is referenced per-contract via `contractAttributes.policy.url` → [`specification/policies/demand_flex_revenue.rego`](../../specification/policies/demand_flex_revenue.rego), package `deg.contracts.demand_flex`. The settlement rego reads per-meter `BASELINE` / `USAGE` from the performance section and produces a net-zero `buyer pays / seller receives` revenue flow; per-EV vendor telemetry pushed as the prior `on_status` message is ignored by the rego (its perf record's status is `REPORT_DELIVERED`, not `SETTLED`).

Signature/registry lookups currently target `nfh.global/testnet-deg` via the `allowedNetworkIDs` key on the `dediregistry` plugin. Subscriber IDs are placeholders (`bap.example.com` / `bpp.example.com`) with signing keys borrowed from the p2p-trading devkit, so arazzo flows will NACK on lookup until real subscribers are registered on testnet-deg.

## Related

- [DemandFlexNeed Schema](../../specification/schema/DemandFlexNeed/v2.0/) — Flex resource attributes
- [DemandFlexBuyOffer Schema](../../specification/schema/DemandFlexBuyOffer/v2.0/) — Incentive and policy terms, including `vendorDevices` and `reportDescriptors`
- [BecknReportDescriptors Schema](../../specification/schema/BecknReportDescriptors/v1.0/) — OpenADR3-aligned vendor-telemetry commitments
- [Demand Flexibility Implementation Guide](../../docs/implementation-guides/v2/Demand_Flexibility/Demand_Flexibility.md) — Detailed protocol flows and schema mappings
- [Data Exchange Devkit](../data-exchange/) — Companion devkit for energy data delivery
