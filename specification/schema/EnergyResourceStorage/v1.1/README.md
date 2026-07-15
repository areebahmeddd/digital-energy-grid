# EnergyResourceStorage v1.1

**Schema ID:** `https://schema.nfh.global/EnergyResourceStorage/v1.1`
**CIM:** `cim:BatteryUnit` (IEC 61970-302)
**Status:** Current

---

## v1.1 changes

Inherits `EnergyResourceCommon/v1.1`. Common power fields renamed to `QuantitativeValue`:
`ratedPowerKw → ratedPower`, `maxExportKw → maxExport`, `maxImportKw → maxImport`.
Storage-specific: `storageCapacityKwh → storageCapacity` (unit: `kWh|MWh`).

Optional admin attribute added (non-breaking; optional):

| Field | Standard | Notes |
|---|---|---|
| `roundTripEfficiencyPct` | IEC 62933-2-1 | AC-to-AC round-trip efficiency (0–100) over a full charge/discharge cycle. Distinct from `stateOfHealthPct` (cumulative life) and from inverter conversion efficiency. |

Common-attribute additions inherited from `EnergyResourceCommon/v1.1`: `serialNumber`, `inspection`, `aggregator`.

---

## Overview

`EnergyResourceStorage` represents stationary energy storage assets (BESS). `storageCapacity` (QuantitativeValue) is exclusive to this kind. EV charging stations are NOT storage; see `EnergyResourceEVCharger`.

---

## Files

| File | Description |
|------|-------------|
| [`attributes.yaml`](./attributes.yaml) | OpenAPI 3.1.1 schema |
| [`context.jsonld`](./context.jsonld) | JSON-LD 1.1 context |
| [`vocab.jsonld`](./vocab.jsonld) | RDF vocabulary |

---

## Type Discriminator

| `type` value | CIM class | Notes |
|---|---|---|
| `BESS` | `BatteryUnit` (IEC 61970-302) | Preferred; `BATTERY` deprecated |

---

## Attributes

### Common attributes (inherited from EnergyResourceCommon/v1.1)

| Field | Type | Description |
|-------|------|-------------|
| `maxExport` | QuantitativeValue | Max discharge rate. `unit: W\|kW\|MW` |
| `maxImport` | QuantitativeValue | Max charge rate. `unit: W\|kW\|MW` |
| `commissioningDate` | date-time | ISO 8601 |

### Storage-specific attributes

| Field | Type | CIM / standard | Description |
|-------|------|----------------|-------------|
| `storageCapacity` | QuantitativeValue | `BatteryUnit.ratedE` | Rated energy capacity. `unit: kWh\|MWh` |
| `storageType` | enum | — | `LithiumIon` · `LeadAcid` · `FlowBattery` · `NaS` · `NiCd` · `Flywheel` · `Other` |
| `stateOfHealthPct` | number 0–100 | — | State of health as % of original capacity |
| `roundTripEfficiencyPct` | number 0–100 | IEC 62933-2-1 | AC-to-AC round-trip efficiency over a full charge/discharge cycle. |

---

## Minimal valid example

```json
{
  "id": "did:web:utility.com:assets:bess:BESS-001",
  "type": "BESS",
  "attributes": {
    "maxExport": {"value": 5, "unit": "kW"},
    "maxImport": {"value": 5, "unit": "kW"},
    "storageCapacity": {"value": 10, "unit": "kWh"},
    "storageType": "LithiumIon",
    "stateOfHealthPct": 98,
    "roundTripEfficiencyPct": 92,
    "serialNumber": "PW3-7H2K9-44182",
    "aggregator": {"id": "did:web:exampleflex.in", "name": "ExampleFlex Aggregator", "controllable": true, "enrolledOn": "2025-04-01"}
  },
  "parentResources": ["did:web:utility.com:assets:meter:MET-001"]
}
```
