# DemandFlexNeed — v2.0

Buyer-authored demand-flex **procurement schedule** — an **OpenADR 3.1.0-aligned
time series** (one interval per tranche/timeslot). This is the single, unified
Need shape for **every** demand-flex market: uc1 behavioural DR (monopsony — the
DISCOM fixes one clearing price) and uc2 pay-as-clear auction (price discovered by
the market) both use it. Columns are open in the schema; each contract policy
rego imposes its own hard-`const` column set.

Part of the [DEG Schema](../../) · [DemandFlexNeed](../README.md)

## Files

| File | Description |
|------|-------------|
| [attributes.yaml](./attributes.yaml) | OpenAPI 3.1.1 `components.schemas.DemandFlexNeed` |
| [context.jsonld](./context.jsonld) | JSON-LD context (`https://schema.nfh.global/deg/DemandFlexNeed/v2.0/`) |
| [vocab.jsonld](./vocab.jsonld) | RDF vocabulary for `DemandFlexNeed` terms |

## Shape

DemandFlexNeed is structurally a `BecknTimeSeries` (it reuses OpenADR's
`intervalPeriod` and `interval`) with a **`const` payloadDescriptors** lock and a
`location`. There is no nested `resourceAttributes.resourceAttributes` — the Need
*is* the series.

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `location` | Beckn Location | | GeoJSON geometry (`geo`) + optional `address` |
| `intervalPeriod` | OpenADR intervalPeriod | ✅ | `start` + `duration` (e.g. `PT30M`) — the tranche grid |
| `payloadDescriptors` | const | ✅ | Locked to the three buyer columns (below) |
| `intervals` | OpenADR interval[] | ✅ | One row per tranche; `id` + typed `payloads` |

### Locked columns (buyer)

| payloadType | units | meaning |
|---|---|---|
| `CAPACITY_REQUESTED` | KW | flex the utility wants that slot — discovery signal only, drifts as aggregators confirm, **not** used in settlement |
| `PRICE` | INR_PER_KWH | per-slot incentive; a **negative** price pays for increased consumption (the sign carries reduce-vs-increase, so there is no `direction` field) |
| `SHORTFALL_PENALTY` | INR_PER_KWH | per-kWh charge on under-delivery vs the aggregator's `CAPACITY_OFFERED` |

The seller adds a `CAPACITY_OFFERED` column on `Commitment.commitmentAttributes`
at confirm; per-meter `BASELINE`/`USAGE` telemetry (DemandFlexPerformance) uses
the **same `intervalPeriod` grid** so settlement joins all three on interval `id`
(enforced by [`demand-flex-contractpolicy.rego`](../../../policies/demand-flex-contractpolicy.rego)).
