# EnergyResourceGenerator v1.1

**Schema ID:** `https://schema.nfh.global/EnergyResourceGenerator/v1.1`
**CIM:** `GeneratingUnit` subtypes (IEC 61970-302)
**Status:** Current

---

## v1.1 changes

Inherits `EnergyResourceCommon/v1.1`. Common power fields renamed to `QuantitativeValue`:
`ratedPowerKw → ratedPower`, `maxExportKw → maxExport`, `maxImportKw → maxImport`.
Generator-specific: `nominalPowerKw → nominalPower` (unit: `W|kW|MW`).

Optional admin attribute added (non-breaking; optional):

| Field | Standard | Notes |
|---|---|---|
| `dcArrayCapacity` | IS 16221; IEC 61727 | DC-side PV array nameplate at STC (industry "kWp"). Distinct from AC-side `maxExport`. Relevant for SOLAR_PV. |

Common-attribute additions inherited from `EnergyResourceCommon/v1.1`: `serialNumber`, `inspection`, `aggregator`.

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

| Field | Type | CIM / standard | Description |
|-------|------|----------------|-------------|
| `nominalPower` | QuantitativeValue | `GeneratingUnit.nominalP` | Nominal rated output. `unit: W\|kW\|MW` |
| `efficiency` | number 0–100 | — | Conversion efficiency %; relevant for FUEL_CELL, CHP |
| `dcArrayCapacity` | QuantitativeValue | IS 16221; IEC 61727 | DC-side PV array nameplate at STC (industry "kWp"). PV systems are typically DC-oversized vs AC `maxExport`. SOLAR_PV. QUDT unit `kW`; STC/peak semantic documented, not encoded. |

---

## Minimal valid example

```json
{
  "id": "did:web:utility.com:assets:solar:DER-SOLAR-001",
  "type": "SOLAR_PV",
  "attributes": {
    "maxExport": {"value": 5, "unit": "kW"},
    "dcArrayCapacity": {"value": 6.2, "unit": "kW"},
    "make": "Waaree",
    "model": "WS-400M",
    "serialNumber": "WS-400M-78821",
    "commissioningDate": "2025-02-10T00:00:00+05:30",
    "inspection": {"date": "2025-02-08", "result": "pass", "inspectorId": "INSP-KA-204"}
  },
  "parentResources": ["did:web:utility.com:assets:meter:MET-001"]
}
```
