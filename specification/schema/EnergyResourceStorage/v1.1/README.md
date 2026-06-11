# EnergyResourceStorage v1.1

**Schema ID:** `https://schema.beckn.io/EnergyResourceStorage/v1.1`
**CIM:** `cim:BatteryUnit` (IEC 61970-302)
**Status:** Current

---

## v1.1 changes

Inherits `EnergyResourceCommon/v1.1`. Common power fields renamed to `QuantitativeValue`:
`ratedPowerKw → ratedPower`, `maxExportKw → maxExport`, `maxImportKw → maxImport`.
Storage-specific: `storageCapacityKwh → storageCapacity` (unit: `kWh|MWh`).

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

| Field | Type | CIM | Description |
|-------|------|-----|-------------|
| `storageCapacity` | QuantitativeValue | `BatteryUnit.ratedE` | Rated energy capacity. `unit: kWh\|MWh` |
| `storageType` | enum | — | `LithiumIon` · `LeadAcid` · `FlowBattery` · `NaS` · `NiCd` · `Flywheel` · `Other` |
| `stateOfHealthPct` | number 0–100 | — | State of health as % of original capacity |

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
    "storageType": "LithiumIon"
  },
  "parentResources": ["did:web:utility.com:assets:meter:MET-001"]
}
```
