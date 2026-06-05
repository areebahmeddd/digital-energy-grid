# EnergyResourceGenerator v1.0

**Schema ID:** `https://schema.beckn.io/deg/EnergyResource/EnergyResourceGenerator/v1.0`
**CIM:** `cim:GeneratingUnit` and subtypes (IEC 61970-301/302)
**Status:** Current

---

## Overview

`EnergyResourceGenerator` is the typed attribute schema for generation DER energy resources. It covers solar PV, wind, hydro, biogas, CHP, and fuel cell assets.

This schema is one of five composable `EnergyResource` kinds extracted from `ElectricityCredential v1.2`.

---

## Files

| File | Description |
|------|-------------|
| [`attributes.yaml`](./attributes.yaml) | OpenAPI 3.1.1 schema — EnergyResourceGenerator and its Attributes object |
| [`context.jsonld`](./context.jsonld) | JSON-LD 1.1 context mapping terms to semantic IRIs |
| [`vocab.jsonld`](./vocab.jsonld) | RDF vocabulary — class and property definitions with CIM seeAlso links |

---

## Type Discriminator

| `type` value | CIM class | Notes |
|---|---|---|
| `SOLAR_PV` | `cim:PhotovoltaicUnit` | Preferred value |
| `SOLAR` | `cim:PhotovoltaicUnit` | Deprecated alias for SOLAR_PV |
| `WIND` | `cim:WindGeneratingUnit` | |
| `HYDRO` | `cim:HydroGeneratingUnit` | |
| `BIOGAS` | `cim:ThermalGeneratingUnit` | |
| `CHP` | `cim:ThermalGeneratingUnit` | Combined heat and power |
| `FUEL_CELL` | IEC 62933-2 fuel cell unit | |

---

## Attributes

### Common attributes (EnergyResourceCommonAttributes — all kinds)

| Field | Type | CIM | Description |
|-------|------|-----|-------------|
| `make` | string | — | Manufacturer |
| `model` | string | — | Model number |
| `ratedPowerKw` | number ≥ 0 | `GeneratingUnit.maxOperatingP` | Rated peak power, kW |
| `telemetryProvider` | string | — | Telemetry vendor / API identifier |
| `commissioningDate` | string (ISO 8601 date) | — | Date commissioned |
| `gps` | string (lat,lng) | — | GPS coordinates |

### Generator-specific attributes

| Field | Type | CIM | Description |
|-------|------|-----|-------------|
| `nominalPowerKw` | number ≥ 0 | `GeneratingUnit.nominalP` | Nameplate nominal power, kW |
| `efficiency` | number 0–100 | — | Conversion efficiency %, esp. for FUEL_CELL/CHP |

---

## Minimal valid example

```json
{
  "id": "did:web:bescom.karnataka.gov.in:assets:solar:SOL-001",
  "type": "SOLAR_PV",
  "attributes": {
    "make": "Waaree",
    "model": "WS-440",
    "ratedPowerKw": 5,
    "nominalPowerKw": 5,
    "commissioningDate": "2023-06-15",
    "gps": "12.9716,77.5946",
    "telemetryProvider": "SolarEdge"
  },
  "parentResources": ["did:web:bescom.karnataka.gov.in:assets:meter:MET-001"]
}
```
