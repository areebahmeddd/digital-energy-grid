# EnergyResourceStorage v1.0

**Schema ID:** `https://schema.beckn.io/deg/EnergyResource/EnergyResourceStorage/v1.0`
**CIM:** `cim:BatteryUnit`, `cim:ElectricVehicleChargingStation` (IEC 61970-302)
**Status:** Current

---

## Overview

`EnergyResourceStorage` is the typed attribute schema for storage DER energy resources. It covers battery energy storage systems (BESS), EV chargers, and bidirectional V2G-capable EV chargers.

This schema is one of five composable `EnergyResource` kinds extracted from `ElectricityCredential v1.2`.

> **Migration note:** `storageCapacityKwh` replaces `energyCapacityKwh` used in `EnergyResource v1.1`.

---

## Files

| File | Description |
|------|-------------|
| [`attributes.yaml`](./attributes.yaml) | OpenAPI 3.1.1 schema — EnergyResourceStorage and its Attributes object |
| [`context.jsonld`](./context.jsonld) | JSON-LD 1.1 context mapping terms to semantic IRIs |
| [`vocab.jsonld`](./vocab.jsonld) | RDF vocabulary — class and property definitions with CIM seeAlso links |

---

## Type Discriminator

| `type` value | CIM class | Notes |
|---|---|---|
| `BESS` | `cim:BatteryUnit` | Preferred value |
| `BATTERY` | `cim:BatteryUnit` | Deprecated alias for BESS |
| `EV_CHARGER` | `cim:ElectricVehicleChargingStation` | Unidirectional |
| `EV_V2G` | `cim:ElectricVehicleChargingStation` | Bidirectional V2G capable |

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

### Storage-specific attributes

| Field | Type | CIM | Description |
|-------|------|-----|-------------|
| `storageCapacityKwh` | number ≥ 0 | `BatteryUnit.ratedE` | Rated stored-energy capacity, kWh |
| `storageType` | enum | — | LithiumIon, LeadAcid, FlowBattery, NaS, NiCd, Flywheel, Other |
| `stateOfHealthPct` | number 0–100 | — | Battery state-of-health % |
| `maxChargeRateKw` | number ≥ 0 | — | Maximum charge rate, kW |
| `maxDischargeRateKw` | number ≥ 0 | — | Maximum discharge rate, kW |

---

## Minimal valid example

```json
{
  "id": "did:web:bescom.karnataka.gov.in:assets:bess:BESS-001",
  "type": "BESS",
  "attributes": {
    "make": "Tesla",
    "model": "Powerwall 3",
    "ratedPowerKw": 11.5,
    "storageCapacityKwh": 13.5,
    "storageType": "LithiumIon",
    "maxChargeRateKw": 11.5,
    "maxDischargeRateKw": 11.5,
    "stateOfHealthPct": 98,
    "commissioningDate": "2024-01-10T00:00:00+05:30",
    "location": {"geo": {"type": "Point", "coordinates": [77.5946, 12.9716]}},
    "telemetryProvider": "Tesla Gateway"
  },
  "parentResources": ["did:web:bescom.karnataka.gov.in:assets:meter:MET-001"]
}
```
