# UC2 — Behavioral Demand Response with Vendor Telemetry

Vendor-telemetry-settled curtailment: the **DISCOM (TPDDL)** asks the **Aggregator (GreenFlex)** for fulfillment status using a Beckn `status` call that carries an OpenADR3-style `reportSpecifier`. The Aggregator answers via `on_status` with per-EV `BecknTimeSeries` (USAGE, SOC, POWER, GPS). DISCOM settles against vendor-rated baselines and pays both an incentive and a carbon-credit value.

For the shared stack topology, prerequisites, and Quick Start, see [../../README.md](../../README.md). For UC1 (grid-meter baselining), see [../uc1-bdr-w-baselining/](../uc1-bdr-w-baselining/).

## Scenario

TPDDL needs **100 kW** of EV-charging curtailment during the 2026-04-01 08:30–10:30 UTC peak. GreenFlex commits **3 EVs × 7 kW rated chargers = 21 kW**:

| Device | Vehicle | Behavior during event | USAGE | Reduction |
|---|---|---|---|---|
| ev://vehicle/VIN001 | Tata Nexon EV | Trickle-charging at home (partial) | 1 kW | 12 kWh |
| ev://vehicle/VIN002 | MG ZS EV | Plugged in, charge paused (full) | 0 kW | 14 kWh |
| ev://vehicle/VIN003 | Tata Tigor EV | Disconnected, driving (full)       | 0 kW | 14 kWh |

**Settlement:** 40 kWh × 3.5 INR/kWh = **140 INR incentive**. CO2 avoided 32.8 kg × 1500 INR/tCO2e = **49.2 INR carbon credit**. Aggregator earns **189.2 INR**; DISCOM pays 140 INR; carbon registry pays 49.2 INR.

## Subscriber roles — both actors carry both BAP and BPP roles

Subscriber IDs are placeholders fixed to actors:

- `bap.example.com` → **Aggregator (GreenFlex)**
- `bpp.example.com` → **DISCOM (TPDDL)**

Each subscriber is registered with **both BAP and BPP roles** in the Beckn registry. The `bapId` / `bppId` slots in each message's `context` decide who's playing which role for that one call. Most calls follow the UC1 default (Aggregator=BAP, DISCOM=BPP). Two calls flip:

| Step | bapId | bppId | Why |
|---|---|---|---|
| catalog/publish, search, select, on_select, init, on_init, confirm, on_confirm | bap (Agg) | bpp (DISCOM) | Aggregator drives discovery and contracting. |
| on_status (baselines, with report-request tag) | bap (Agg) | bpp (DISCOM) | DISCOM unilateral push of baselines. |
| **status (DISCOM asks for vendor telemetry)** | **bpp (DISCOM)** | **bap (Agg)** | DISCOM uses BAP-caller; Aggregator is BPP-receiver. |
| **on_status (Aggregator returns vendor telemetry)** | **bpp (DISCOM)** | **bap (Agg)** | Aggregator uses BPP-caller; same swap. |
| on_status (settlement) | bap (Agg) | bpp (DISCOM) | DISCOM unilateral push of settlement. |

This dual-role-per-subscriber pattern is allowed by Beckn 2.0; for live testnet runs, both subscribers must have BAP **and** BPP roles registered with valid signing keys against `nfh.global/testnet-deg-vendor`.

## OpenADR3 alignment — `BecknReportRequest` / `BecknReportPayload`

DISCOM declares its telemetry needs using the OpenADR3 [`reportDescriptor`](https://raw.githubusercontent.com/beckn/DEG/refs/heads/main/specification/external/openadr/3.1.0/openadr3.yaml) shape verbatim — one entry per `payloadType`, with `readingType`, `units`, `aggregate`, `historical`, `numIntervals`, `frequency`, `reportIntervals`, and (in the actual status request) `targets`. The descriptors travel inside two new DEG schemas at [`specification/schema/BecknReportRequest/v1.0/`](../../../specification/schema/BecknReportRequest/v1.0/) — `BecknReportRequest` (request side) and `BecknReportPayload` (reply correlation block) — both of which $ref the OpenADR3 reportDescriptor type.

The Beckn 2.1 `Contract` schema has `additionalProperties: false`, so the descriptors can't sit at `message.contract.*` directly. They ride inside `contractAttributes`, which is a polymorphic slot typed by `@context` / `@type` (the same `@type`-driven dispatch BecknTimeSeries documents). Two messages use a non-DEGContract type for `contractAttributes`:

| Message | `contractAttributes.@type` | Carries |
|---|---|---|
| `publish-catalog` … `on-confirm` | `DEGContract` | roles, policy. Telemetry needs are pre-declared at `offerAttributes.inputs[buyer].inputs.reportDescriptors[]` (no `targets` yet). |
| `on-status-baselines` (BPP push) | `DEGContract` | per-EV BASELINE telemetry; the report-request lives on the contract terms already. |
| **`status` (DISCOM asks)** | **`BecknReportRequest`** | `reportName`, `eventId`, `reportDescriptors[]` with `targets: [VINs]` populated. |
| **`on_status` (vendor telemetry reply)** | **`BecknReportPayload`** | `respondsTo` (status `messageId`), `reportName`, `eventId`, `intervalDuration`. The actual report body is the `BecknTimeSeries` under `performance[].performanceAttributes.meters[].telemetry`. |
| `on-status-settled` | `DEGContract` | full settlement contract; OPA evaluates against this. |

This is exactly the OpenADR3 reportSpecifier / reportPayload split — VTN→VEN report request and VEN→VTN report response — mapped onto Beckn's `status` / `on_status` actions and the polymorphic `contractAttributes` extension slot.

## Vendor telemetry payload types

Per-device `payloadDescriptors` use these `payloadType` values (any subset; coverage enforced by the network rego):

| payloadType | units | Notes |
|---|---|---|
| `BASELINE` | KW | DISCOM-supplied vendor-device-rated charging power |
| `USAGE` | KW | Vendor-reported actual draw during the event |
| `POWER` | KW | Signed instantaneous power at the charger (charge=+, discharge=−) |
| `SOC` | PERCENT | State of charge |
| `GPS_LAT` / `GPS_LON` | DEGREES | Vehicle location, **only while POWER ≠ 0** (network-rego rule) |

This list is open-ended; future `CO2_AVOIDED` (`KG_CO2E`) or temperature/SoH payloads can be added by extending `payloadDescriptors` without a schema bump.

## Carbon credits in the contract

`offerAttributes.inputs[buyer].inputs.carbonCredit`:

```jsonc
{
  "enabled": true,
  "gridEmissionFactorKgPerKwh": 0.82,        // CEA Indian grid avg
  "creditPricePerTonneCO2e": 1500.0,         // ₹/tCO2e
  "registry": "delhi-carbon-registry",
  "methodology": "CDM_AMS-II.G_v1"
}
```

The contract roles are extended with `carbonBuyer` (the registry). The settlement rego ([`demand_flex_uc2_revenue.rego`](../../../specification/policies/demand_flex_uc2_revenue.rego)) emits a 3-flow net-zero settlement when `enabled: true`, or a 2-flow + zero-stub flow when disabled — so consumers can count on a stable shape either way.

## Postman

Pre-built collections live at:
- `postman/demand-flex-uc2-bdr-w-vendor-telemetry.BAP-DEG.postman_collection.json`
- `postman/demand-flex-uc2-bdr-w-vendor-telemetry.BPP-DEG.postman_collection.json`

Regenerate with:
```bash
python3 scripts/generate_postman_collection.py --role BAP --usecase uc2-bdr-w-vendor-telemetry
python3 scripts/generate_postman_collection.py --role BPP --usecase uc2-bdr-w-vendor-telemetry
```

**Caveat on the role-swap requests.** The generator replaces every literal `bapId`/`bppId` with `{{bap_id}}`/`{{bpp_id}}`, so the source-level swap in `status-request-vendor-telemetry.json` and `on-status-response-vendor-telemetry.json` resolves to the default subscriber-role mapping at runtime. To exercise the swap in Postman, override `bap_id`/`bpp_id` in a Postman environment specifically for those two requests (or duplicate the collection variable as `bap_id_swapped` and edit the body accordingly).

## Files

| File | What it carries |
|---|---|
| [`examples/publish-catalog.json`](./examples/publish-catalog.json) | DISCOM publishes vendor-telemetry offer with reportRequirements + carbon terms |
| [`examples/discover-request.json`](./examples/discover-request.json) | Aggregator searches for CURTAILMENT/REDUCE |
| [`examples/select-request.json`](./examples/select-request.json) | Aggregator selects 21 kW |
| [`examples/on-select-response.json`](./examples/on-select-response.json) | DRAFT contract with carbonBuyer role placeholder |
| [`examples/init-request.json`](./examples/init-request.json) | Aggregator declares 3 EVs (vendorDevices[]) |
| [`examples/on-init-response.json`](./examples/on-init-response.json) | DISCOM acknowledges |
| [`examples/confirm-request.json`](./examples/confirm-request.json) | ACTIVE |
| [`examples/on-confirm-response.json`](./examples/on-confirm-response.json) | ACTIVE confirmed |
| [`examples/on-status-response-baselines.json`](./examples/on-status-response-baselines.json) | DISCOM publishes per-EV BASELINE + report-request tag |
| [`examples/status-request-vendor-telemetry.json`](./examples/status-request-vendor-telemetry.json) | **DISCOM asks** (BAP-caller; bapId/bppId swapped) |
| [`examples/on-status-response-vendor-telemetry.json`](./examples/on-status-response-vendor-telemetry.json) | **Aggregator answers** with full vendor BecknTimeSeries |
| [`examples/on-status-response-settled.json`](./examples/on-status-response-settled.json) | DISCOM publishes settlement + computed revenue flows in tags |
| [`workflows/demand-flex-vendor.arazzo.yaml`](./workflows/demand-flex-vendor.arazzo.yaml) | Arazzo workflow runner |

## Policy files

| File | Purpose |
|---|---|
| [`../policies/demand_flex_uc2_network.rego`](../policies/demand_flex_uc2_network.rego) | Network-level checks (type-coverage + GPS-coherence + SOC-monotonicity) |
| [`../../../specification/policies/demand_flex_uc2_revenue.rego`](../../../specification/policies/demand_flex_uc2_revenue.rego) | Settlement rego — package `deg.contracts.demand_flex_uc2`, computes incentive + carbon-credit revenue flows, net-zero |

UC2 runs on networkId `nfh.global/testnet-deg-vendor`; UC1 continues to run on `nfh.global/testnet-deg`. Routing is configured in [`../config/opa-network-policies.yaml`](../config/opa-network-policies.yaml).
