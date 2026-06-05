# EnergyResourceLoad v1.0

**Schema ID:** `https://schema.beckn.io/deg/EnergyResource/EnergyResourceLoad/v1.0`
**CIM:** `cim:EnergyConsumer` / `cim:ConformLoad` (IEC 61970-301)
**Status:** Current

---

## Overview

`EnergyResourceLoad` is the typed attribute schema for controllable load energy resources. It covers smart HVAC systems, smart water heaters, and generic controllable loads that participate in demand-response and demand-flexibility programs.

This schema is one of five composable `EnergyResource` kinds extracted from `ElectricityCredential v1.2`.

---

## Files

| File | Description |
|------|-------------|
| [`attributes.yaml`](./attributes.yaml) | OpenAPI 3.1.1 schema — EnergyResourceLoad and its Attributes object |
| [`context.jsonld`](./context.jsonld) | JSON-LD 1.1 context mapping terms to semantic IRIs |
| [`vocab.jsonld`](./vocab.jsonld) | RDF vocabulary — class and property definitions with CIM seeAlso links |

---

## Type Discriminator

| `type` value | CIM class | Description |
|---|---|---|
| `SMART_HVAC` | `cim:ConformLoad` | Smart heating/cooling system |
| `SMART_WATER_HEATER` | `cim:ConformLoad` | Smart water heater |
| `CONTROLLABLE_LOAD` | `cim:ConformLoad` | Generic demand-response controllable load |

---

## Attributes

### Common attributes (EnergyResourceCommonAttributes — all kinds)

| Field | Type | CIM | Description |
|-------|------|-----|-------------|
| `make` | string | — | Manufacturer |
| `model` | string | — | Model number |
| `ratedPowerKw` | number ≥ 0 | `GeneratingUnit.maxOperatingP` | Rated peak power draw, kW |
| `telemetryProvider` | string | — | Telemetry vendor / API identifier |
| `commissioningDate` | string (ISO 8601 date) | — | Date commissioned |
| `gps` | string (lat,lng) | — | GPS coordinates |

### Load-specific attributes

| Field | Type | CIM | Description |
|-------|------|-----|-------------|
| `controlProtocol` | enum | — | OpenADR_2.0b, OCPP_2.0.1, SunSpec_Modbus, EEBus, Modbus, Other |
| `loadCategory` | enum | `EnergyConsumer` classification | Heating, Cooling, WaterHeating, Lighting, EV, Industrial, Other |

---

## Minimal valid example

```json
{
  "id": "did:web:bescom.karnataka.gov.in:assets:load:HVAC-001",
  "type": "SMART_HVAC",
  "attributes": {
    "make": "Daikin",
    "model": "FTXS50KAVMA",
    "ratedPowerKw": 1.7,
    "controlProtocol": "OpenADR_2.0b",
    "loadCategory": "Cooling",
    "commissioningDate": "2023-03-20T00:00:00+05:30",
    "location": {"geo": {"type": "Point", "coordinates": [77.5946, 12.9716]}},
    "telemetryProvider": "Daikin D3NET"
  },
  "parentResources": ["did:web:bescom.karnataka.gov.in:assets:meter:MET-001"]
}
```
