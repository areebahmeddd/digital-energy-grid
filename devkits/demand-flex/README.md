# Demand Flex Devkit

Beckn Protocol v2.0 devkit for **behavioral demand response**. A utility publishes flexibility needs (peak demand reduction), and aggregators discover, commit to, and deliver demand flexibility — with settlement based on measured performance.

For the shared stack topology, prerequisites, Quick Start, transaction flow, hosting, ngrok notes, and cleanup, see [../README.md](../README.md).

## Scenario

**TPDDL** (Tata Power Delhi Distribution, the utility) publishes a 500 kW curtailment need during a peak event window. **GreenFlex Aggregator** discovers the opportunity, enrolls participating meters, and commits to providing 150 kW of demand reduction. After the event, TPDDL publishes baselines, measured actuals, and computes settlement (e.g., 150 kWh x 3.5 INR/kWh = 525 INR).

## Use Cases

| Use Case | BPP (Provider) | BAP (Consumer) | Description |
|----------|---------------|----------------|-------------|
| [uc1-bdr-w-baselining](./uc1-bdr-w-baselining/) | TPDDL (utility) | GreenFlex (aggregator) | Publish flex need → discover → commit → deliver → settle |
| [uc2-bdr-w-vendor-telemetry](./uc2-bdr-w-vendor-telemetry/) | TPDDL (utility) / GreenFlex (aggregator) — **dual role** | GreenFlex (aggregator) / TPDDL (utility) — **dual role** | Vendor-telemetry settlement: DISCOM asks via Beckn `status` (BAP-caller, OpenADR3 reportSpecifier in tags); aggregator answers via `on_status` (BPP-caller) with per-EV BecknTimeSeries (USAGE/SOC/POWER/GPS); settlement includes carbon-credit revenue flow. |

## Key Schemas

| Schema | Slot | Description |
|--------|------|-------------|
| [DemandFlexNeed](../../specification/schema/DemandFlexNeed/v2.0/) | `resourceAttributes` | Direction (REDUCE/INCREASE), event window, capacity type, location |
| [DemandFlexBuyOffer](../../specification/schema/DemandFlexBuyOffer/v2.0/) | `offerAttributes` | Incentive per kWh, baseline methodology, penalty rate |
| [DEGContract](../../specification/schema/DEGContract/v2.0/) | `contractAttributes` | Roles (buyer/seller), policy reference, revenue flows |
| [DemandFlexPerformance](../../specification/schema/DemandFlexPerformance/v2.0/) | `performanceAttributes` | M&V baselines and actuals per meter |

## Postman

`uc1-bdr-w-baselining/postman/demand-flex-uc1-bdr-w-baselining.{BAP,BPP}-DEG.postman_collection.json`. Collections are regenerated with `python3 scripts/generate_postman_collection.py --role BAP|BPP`.

## Policy Enforcement

Uses OPA (Open Policy Agent) via the `opapolicychecker` plugin. Policies are declared in [`config/opa-network-policies.yaml`](./config/opa-network-policies.yaml):

| networkId | Network rego | Used by |
|---|---|---|
| `default:` (fallback) | [`policies/demand_flex_network.rego`](./policies/demand_flex_network.rego) — type-coverage check, mirrors [`specification/policies/demand_flex_network.rego`](../../specification/policies/demand_flex_network.rego) | UC1 |
| `nfh.global/testnet-deg-vendor` | [`policies/demand_flex_uc2_network.rego`](./policies/demand_flex_uc2_network.rego) — type-coverage + GPS-coherence + SOC-monotonicity | UC2 |

Settlement rego is referenced per-contract via `contractAttributes.policy.url`:

- UC1 → [`specification/policies/demand_flex_revenue.rego`](../../specification/policies/demand_flex_revenue.rego), package `deg.contracts.demand_flex`
- UC2 → [`specification/policies/demand_flex_uc2_revenue.rego`](../../specification/policies/demand_flex_uc2_revenue.rego), package `deg.contracts.demand_flex_uc2` (incentive + carbon-credit revenue flow)

Signature/registry lookups currently target `nfh.global/testnet-deg` via the `allowedNetworkIDs` key on the `dediregistry` plugin. Subscriber IDs are placeholders (`bap.example.com` / `bpp.example.com`) with signing keys borrowed from the p2p-trading devkit, so arazzo flows will NACK on lookup until real subscribers are registered on testnet-deg.

## Related

- [DemandFlexNeed Schema](../../specification/schema/DemandFlexNeed/v2.0/) — Flex resource attributes
- [DemandFlexBuyOffer Schema](../../specification/schema/DemandFlexBuyOffer/v2.0/) — Incentive and policy terms
- [Demand Flexibility Implementation Guide](../../docs/implementation-guides/v2/Demand_Flexibility/Demand_Flexibility.md) — Detailed protocol flows and schema mappings
- [Data Exchange Devkit](../data-exchange/) — Companion devkit for energy data delivery
