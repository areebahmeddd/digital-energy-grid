# UC2 — Behavioral Demand Response with Vendor Telemetry

Vendor-telemetry-settled curtailment: the **DISCOM (TPDDL)** publishes per-EV vendor `BecknTimeSeries` (BASELINE/USAGE/POWER/SOC_END per interval; GPS_LAT/GPS_LON once per event) — collected from the **Aggregator (GreenFlex)** out-of-band — alongside the per-EV baselines, and settles against vendor-rated baselines. The buyer (DISCOM) pays the aggregator a bundle of incentive plus carbon-credit value; the seller (aggregator) keeps both.

For the shared stack topology, prerequisites, and Quick Start, see [../../README.md](../../README.md). For UC1 (grid-meter baselining), see [../uc1-bdr-w-baselining/](../uc1-bdr-w-baselining/).

## Scenario

TPDDL needs **100 kW** of EV-charging curtailment during the 2026-04-01 08:30–10:30 UTC peak. GreenFlex commits **3 EVs × 7 kW rated chargers = 21 kW**:

| Device | Vehicle | Behavior during event | USAGE | Reduction |
|---|---|---|---|---|
| ev://vehicle/VIN001 | Tata Nexon EV | Trickle-charging at home (partial) | 1 kW | 12 kWh |
| ev://vehicle/VIN002 | MG ZS EV | Plugged in, charge paused (full) | 0 kW | 14 kWh |
| ev://vehicle/VIN003 | Tata Tigor EV | Disconnected, driving (full)       | 0 kW | 14 kWh |

**Settlement:** 40 kWh × 3.5 INR/kWh = **140 INR incentive**. CO2 avoided 32.8 kg × 1500 INR/tCO2e = **49.2 INR carbon credit**. DISCOM pays the bundled **189.2 INR** to the aggregator; the carbon credit accrues to the seller (no separate registry counterparty). Net-zero across the two roles.

## Subscriber roles

Subscriber IDs are placeholders fixed to actors:

- `bap.example.com` → **Aggregator (GreenFlex)**
- `bpp.example.com` → **DISCOM (TPDDL)**

All calls follow the standard direction (Aggregator=BAP, DISCOM=BPP). Vendor telemetry is delivered to DISCOM out-of-band (via the aggregator's vendor-API integrations) and DISCOM publishes it as `on_status` ahead of settlement, alongside the per-EV baselines.

## OpenADR3 alignment — `BecknReportDescriptors` sidecar

The seller declares what telemetry it commits to provide as a flat array attached to the offer at confirm time:

```
offerAttributes.inputs[seller].inputs.reportDescriptors[]
```

Each entry is an OpenADR3 [`reportPayloadDescriptor`](https://raw.githubusercontent.com/beckn/DEG/refs/heads/main/specification/external/openadr/3.1.0/openadr3.yaml) — same descriptor type used inside `BecknTimeSeries.payloadDescriptors` — augmented with one DEG extension, `cardinality` (`PER_INTERVAL` or `PER_EVENT`). Schema lives at [`specification/schema/BecknReportDescriptors/v1.0/`](../../../specification/schema/BecknReportDescriptors/v1.0/).

The descriptors are committed inside the contract at confirm and stay bound to it for the rest of the flow:

| Message | Carries |
|---|---|
| `publish-catalog` … `on-confirm` | Roles, policy. The seller's `reportDescriptors[]` are bound to the offer at confirm. |
| `on-status-baselines` (BPP push) | Per-EV BASELINE timeseries. |
| `on-status-vendor-telemetry` (BPP push) | Per-EV vendor BecknTimeSeries (`payloadDescriptors` + per-interval `payloads[]`) collected by DISCOM out-of-band ahead of settlement. |
| `on-status-settled` (BPP push) | Full settlement contract (offer block included so the network rego can verify telemetry against the seller's commitments). |

## Vendor telemetry payload types

Per-device `payloadDescriptors` and seller-side `reportDescriptors` use these `payloadType` values (any subset; coverage and cardinality enforced by the network rego):

| payloadType | units | cardinality | Notes |
|---|---|---|---|
| `BASELINE` | KW | `PER_INTERVAL` | Vendor-rated charging power, repeated each interval |
| `USAGE` | KW | `PER_INTERVAL` | Vendor-reported actual draw during the event |
| `POWER` | KW | `PER_INTERVAL` | Signed instantaneous power at the charger (charge=+, discharge=−) |
| `SOC_END` | PERCENT | `PER_INTERVAL` | State of charge at end of each interval |
| `GPS_LAT` / `GPS_LON` | DEGREES | `PER_EVENT` | Vehicle position at start of event (one shot, on interval 0) |

`PER_INTERVAL` payloads MUST appear in every `intervals[*].payloads[*]` row; `PER_EVENT` payloads MUST appear in exactly one interval (interval 0 by convention). The [network rego](../policies/demand_flex_uc2_network.rego) enforces both, plus type-coverage against `payloadDescriptors`. The list is open-ended; future `CO2_AVOIDED` (`KG_CO2E`) or temperature/SoH payloads can be added by extending the seller's `reportDescriptors` and the meter's `payloadDescriptors`.

## Carbon credits in the contract

`offerAttributes.inputs[buyer].inputs.carbonCredit`:

```jsonc
{
  "enabled": true,
  "gridEmissionFactorKgPerKwh": 0.82,        // CEA Indian grid avg
  "creditPricePerTonneCO2e": 1500.0,         // ₹/tCO2e
  "methodology": "CDM_AMS-II.G_v1"
}
```

The carbon credit value (verified kWh × `gridEmissionFactorKgPerKwh` × `creditPricePerTonneCO2e`) accrues to the **seller** on top of the demand-response incentive. The buyer (DISCOM) pays the bundle in a single flow. The settlement rego ([`demand_flex_uc2_revenue.rego`](../../../specification/policies/demand_flex_uc2_revenue.rego)) emits a 2-flow net-zero settlement either way — incentive only when `enabled: false`, incentive + carbon when `enabled: true`.

## Postman

Pre-built collections live at:
- `postman/demand-flex-uc2-bdr-w-vendor-telemetry.BAP-DEG.postman_collection.json`
- `postman/demand-flex-uc2-bdr-w-vendor-telemetry.BPP-DEG.postman_collection.json`

Regenerate with:
```bash
python3 scripts/generate_postman_collection.py --role BAP --usecase uc2-bdr-w-vendor-telemetry
python3 scripts/generate_postman_collection.py --role BPP --usecase uc2-bdr-w-vendor-telemetry
```

## Files

| File | What it carries |
|---|---|
| [`examples/publish-catalog.json`](./examples/publish-catalog.json) | DISCOM publishes vendor-telemetry offer with carbonCredit terms (seller block unbound until confirm) |
| [`examples/discover-request.json`](./examples/discover-request.json) | Aggregator searches for CURTAILMENT/REDUCE |
| [`examples/confirm-request.json`](./examples/confirm-request.json) | Aggregator confirms; seller's `reportDescriptors[]` (with `cardinality`) bound here |
| [`examples/on-confirm-response.json`](./examples/on-confirm-response.json) | DISCOM confirms ACTIVE — descriptors now frozen on the contract |
| [`examples/on-status-response-baselines.json`](./examples/on-status-response-baselines.json) | DISCOM publishes per-EV BASELINE timeseries |
| [`examples/on-status-response-vendor-telemetry.json`](./examples/on-status-response-vendor-telemetry.json) | DISCOM publishes per-EV vendor BecknTimeSeries (BASELINE/USAGE/POWER/SOC_END per interval; GPS only on interval 0) gathered out-of-band |
| [`examples/on-status-response-settled.json`](./examples/on-status-response-settled.json) | DISCOM publishes settlement; offer block included so rego can verify telemetry against committed descriptors |
| [`workflows/demand-flex-vendor.arazzo.yaml`](./workflows/demand-flex-vendor.arazzo.yaml) | Arazzo workflow runner |

## Policy files

| File | Purpose |
|---|---|
| [`../policies/demand_flex_network.rego`](../policies/demand_flex_network.rego) (rule `uc2_violations`) | Network-level checks: type-coverage + PER_EVENT/PER_INTERVAL cardinality enforcement against the seller's committed `reportDescriptors`. Same file backs UC1 (rule `violations`); UC2 simply queries the superset rule. |
| [`../../../specification/policies/demand_flex_uc2_revenue.rego`](../../../specification/policies/demand_flex_uc2_revenue.rego) | Settlement rego — package `deg.contracts.demand_flex_uc2`, computes incentive + carbon-credit revenue flows, net-zero |

UC1 and UC2 both run on networkId `nfh.global/testnet-deg`. A single rego file backs both via two named rules: `violations` (UC1 type-coverage) and `uc2_violations` (the strict superset adding cardinality). UC1 traffic transparently passes the UC2 rule because cardinality self-skips when no offer-side `reportDescriptors` are on the wire. Routing is configured in [`../config/opa-network-policies.yaml`](../config/opa-network-policies.yaml).
