# EnergyResourceInverter v1.1

**Schema ID:** `https://schema.beckn.io/EnergyResourceInverter/v1.1`
**CIM:** `cim:PowerElectronicsConnection` (IEC 61970-302)
**Status:** Current

---

## v1.1 changes

Inherits `EnergyResourceCommon/v1.1`. All power fields renamed to `QuantitativeValue`:
- Common: `ratedPowerKw → ratedPower`, `maxExportKw → maxExport`, `maxImportKw → maxImport` (unit: `W|kW|MW`)
- Inverter-specific: `ratedApparentPowerKva → ratedApparentPower` (unit: `kVA|MVA`), `maxReactivePowerKvar → maxReactivePower`, `minReactivePowerKvar → minReactivePower` (unit: `kVAR|MVAR`)

---

## Overview

`EnergyResourceInverter` represents grid-connected power-electronics inverters without a dedicated fuel source. Captures reactive-power and frequency-support capabilities per **IEEE 1547-2018** and **SunSpec DER Models 702–714**. Use cases: standalone battery inverters, VPP aggregation points, grid-forming inverters.

---

## Files

| File | Description |
|------|-------------|
| [`attributes.yaml`](./attributes.yaml) | OpenAPI 3.1.1 schema |
| [`context.jsonld`](./context.jsonld) | JSON-LD 1.1 context |
| [`vocab.jsonld`](./vocab.jsonld) | RDF vocabulary |

---

## Type Discriminator

| `type` value | CIM class |
|---|---|
| `INVERTER` | `PowerElectronicsConnection` (IEC 61970-302) |

---

## Attributes

### Common attributes (inherited from EnergyResourceCommon/v1.1)

| Field | Type | Description |
|-------|------|-------------|
| `maxExport` | QuantitativeValue | Max active power export. `unit: W\|kW\|MW` |
| `maxImport` | QuantitativeValue | Max active power import. `unit: W\|kW\|MW` |

### Inverter-specific attributes

| Field | Type | Standard | Description |
|-------|------|----------|-------------|
| `ratedApparentPower` | QuantitativeValue | SunSpec 702 `maxVA` | Rated apparent power. `unit: kVA\|MVA` |
| `maxReactivePower` | QuantitativeValue | SunSpec 702 `maxVar` | Max reactive injection (leading). `unit: kVAR\|MVAR` |
| `minReactivePower` | QuantitativeValue | SunSpec 702 `maxVarNeg` | Max reactive absorption (lagging). `unit: kVAR\|MVAR`. Value typically negative |
| `rideThroughCategory` | enum | IEEE 1547-2018 | `CategoryI` / `CategoryII` / `CategoryIII` |
| `operatingMode` | enum | CIM `inverterMode` | `GridFollowing` / `GridForming` / `Standby` |
| `voltVarEnabled` | boolean | IEEE 2030.5 / SunSpec 705 | Volt-VAr curve active |
| `freqDroopEnabled` | boolean | SunSpec 711 / IEEE 1547 | Frequency-Watt droop active |
| `enterServiceRampTimeSec` | number ≥0 | SunSpec 703 `ESRmpTms` | Ramp-up time after reconnect, seconds |

---

## Minimal valid example

```json
{
  "id": "did:web:utility.com:assets:inv:INV-001",
  "type": "INVERTER",
  "attributes": {
    "maxExport": {"value": 10, "unit": "kW"},
    "maxImport": {"value": 10, "unit": "kW"},
    "ratedApparentPower": {"value": 12, "unit": "kVA"},
    "maxReactivePower": {"value": 6, "unit": "kVAR"},
    "operatingMode": "GridForming",
    "voltVarEnabled": true,
    "freqDroopEnabled": true,
    "rideThroughCategory": "CategoryIII"
  },
  "parentResources": ["did:web:utility.com:assets:meter:MET-001"]
}
```
