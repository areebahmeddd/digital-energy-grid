# EnergyResourceGenerator v1.1

**Schema ID:** `https://schema.beckn.io/EnergyResourceGenerator/v1.1`
**CIM:** `GeneratingUnit` subtypes (IEC 61970-302)
**Status:** Current

---

## v1.1 changes

Inherits `EnergyResourceCommon/v1.1`. Common power fields renamed to `QuantitativeValue`:
`ratedPowerKw → ratedPower`, `maxExportKw → maxExport`, `maxImportKw → maxImport`.
Generator-specific: `nominalPowerKw → nominalPower` (unit: `W|kW|MW`).

---

## Overview

`EnergyResourceGenerator` covers all electrical generation technologies: solar PV, wind, hydro, biogas, CHP, and fuel cell.

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
| `SOLAR_PV` | `PhotovoltaicUnit` | Preferred; `SOLAR` deprecated |
| `WIND` | `WindGeneratingUnit` | |
| `HYDRO` | `HydroGeneratingUnit` | |
| `BIOGAS` | `ThermalGeneratingUnit` (by fuel) | |
| `CHP` | `ThermalGeneratingUnit` (combined heat and power) | |
| `FUEL_CELL` | IEC 62933-2 | |

---

## Attributes

### Common attributes (inherited from EnergyResourceCommon/v1.1)

| Field | Type | Description |
|-------|------|-------------|
| `make` | string | Manufacturer |
| `model` | string | Model number |
| `maxExport` | QuantitativeValue | Peak generation capacity. `unit: W\|kW\|MW` |
| `telemetryProvider` | string | Telemetry vendor / API |
| `commissioningDate` | date-time | ISO 8601 |
| `location` | object | `geo` + optional `address` |

### Generator-specific attributes

| Field | Type | CIM | Description |
|-------|------|-----|-------------|
| `nominalPower` | QuantitativeValue | `GeneratingUnit.nominalP` | Nominal rated output. `unit: W\|kW\|MW` |
| `efficiency` | number 0–100 | — | Conversion efficiency %; relevant for FUEL_CELL, CHP |

---

## Minimal valid example

```json
{
  "id": "did:web:utility.com:assets:solar:DER-SOLAR-001",
  "type": "SOLAR_PV",
  "attributes": {
    "maxExport": {"value": 5, "unit": "kW"},
    "make": "Waaree",
    "model": "WS-400M",
    "commissioningDate": "2025-02-10T00:00:00+05:30"
  },
  "parentResources": ["did:web:utility.com:assets:meter:MET-001"]
}
```
