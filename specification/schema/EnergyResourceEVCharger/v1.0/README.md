# EnergyResourceEVCharger v1.0

**Schema ID:** `https://schema.beckn.io/EnergyResourceEVCharger/v1.0`
**CIM:** `ElectricVehicleChargingStation` (CIM17+)
**Status:** Current

---

## Overview

`EnergyResourceEVCharger` is the typed attribute schema for EV charging station energy resources (`type = "EV_CHARGER"` or `type = "EV_V2G"`).

An `EV_CHARGER` is the EVSE (Electric Vehicle Supply Equipment) hardware at the grid connection point. It is a **flexible load** — NOT a storage resource. The EV battery is storage; the EVSE is the charge/discharge interface.

`EV_V2G` is a specialisation of `EV_CHARGER` with Vehicle-to-Grid capability per ISO 15118-20 / OCPP 2.1 BPT. For `EV_V2G`, set both `maxImportKw` (charge rate, ≥0) and `maxExportKw` (V2G discharge rate, ≥0) in the attributes bag.

---

## Files

| File | Description |
|------|-------------|
| [`attributes.yaml`](./attributes.yaml) | OpenAPI 3.1.1 schema — EnergyResourceEVCharger and its Attributes object |
| [`schema.json`](./schema.json) | Standalone JSON Schema 2020-12 (self-contained) |
| [`context.jsonld`](./context.jsonld) | JSON-LD 1.1 context mapping terms to semantic IRIs |
| [`vocab.jsonld`](./vocab.jsonld) | RDF vocabulary — class and property definitions |

---

## Type Discriminator

| `type` value | Description |
|---|---|
| `EV_CHARGER` | Unidirectional or AC bidirectional EVSE |
| `EV_V2G` | Vehicle-to-Grid capable EVSE (ISO 15118-20 / OCPP 2.1 BPT) |

---

## Attributes

### Common attributes (EnergyResourceCommonAttributes — all kinds)

| Field | Type | Description |
|-------|------|-------------|
| `make` | string | Manufacturer |
| `model` | string | Model number |
| `ratedPowerKw` | number ≥0 | Rated peak power, kW — backward compat; prefer `maxImportKw` |
| `maxImportKw` | number ≥0 | Max charge power drawn from grid, kW. CIM: `PowerElectronicsConnection.maxP` (absorption) |
| `maxExportKw` | number ≥0 | Max V2G discharge power injected to grid, kW. Set for `EV_V2G` only |
| `telemetryProvider` | string | Telemetry vendor / API identifier |
| `commissioningDate` | string (ISO 8601 date-time) | Date-time commissioned |
| `location` | object (beckn Location/2.0) | `geo` (GeoJSONGeometry) + `address` (PostalAddress) |

### EV charger-specific attributes

| Field | Type | Standard | Description |
|-------|------|----------|-------------|
| `connectorType` | enum | IEC 62196 / SAE J3400 | `Type1` · `Type2` · `CCS1` · `CCS2` · `CHAdeMO` · `GB_T` · `NACS` · `Other` |
| `controlProtocol` | enum | OCPP / ISO 15118 | `OCPP_1.6` · `OCPP_2.0.1` · `OCPP_2.1` · `ISO_15118_2` · `ISO_15118_20` · `Other` |
| `v2xProtocol` | enum | ISO 15118-20 | `CHAdeMO_V2G` · `CCS_BPT` · `ISO_15118_20_AC_BPT` · `ISO_15118_20_DC_BPT` · `Other` — present for `EV_V2G` only |

---

## Examples

**AC EV charger (7.4 kW, unidirectional):**
```json
{
  "id": "did:web:utility.com:assets:evse:EVSE-001",
  "type": "EV_CHARGER",
  "attributes": {
    "make": "ABB", "model": "Terra AC W22",
    "maxImportKw": 7.4,
    "connectorType": "Type2",
    "controlProtocol": "OCPP_2.0.1",
    "commissioningDate": "2025-03-01T00:00:00+05:30",
    "location": {"geo": {"type": "Point", "coordinates": [77.5946, 12.9716]}}
  },
  "parentResources": ["did:web:utility.com:assets:meter:MET-001"]
}
```

**V2G charger (11 kW charge / 7.4 kW discharge):**
```json
{
  "id": "did:web:utility.com:assets:evse:EVSE-V2G-001",
  "type": "EV_V2G",
  "attributes": {
    "make": "Wallbox", "model": "Quasar 2",
    "maxImportKw": 11, "maxExportKw": 7.4,
    "connectorType": "CCS2",
    "controlProtocol": "ISO_15118_20",
    "v2xProtocol": "ISO_15118_20_AC_BPT",
    "commissioningDate": "2025-06-01T00:00:00+05:30"
  },
  "parentResources": ["did:web:utility.com:assets:meter:MET-001"]
}
```
