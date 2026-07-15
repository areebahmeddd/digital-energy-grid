# EnergyResourceEVCharger v1.1

**Schema ID:** `https://schema.nfh.global/EnergyResourceEVCharger/v1.1`
**CIM:** `ElectricVehicleChargingStation` (CIM17+)
**Status:** Current

---

## v1.1 changes

Inherits `EnergyResourceCommon/v1.1`. Common power fields renamed to `QuantitativeValue`:
`ratedPowerKw → ratedPower`, `maxExportKw → maxExport`, `maxImportKw → maxImport` (unit: `W|kW|MW`).

---

## Overview

`EnergyResourceEVCharger` represents EV charging stations (EVSE). It is a **flexible load** — NOT a storage resource. The EV battery is storage; the EVSE is the charge/discharge interface.

`EV_V2G` is a specialisation of `EV_CHARGER` with ISO 15118-20 / OCPP 2.1 BPT bidirectional capability. Set `maxImport` (charge) and `maxExport` (V2G discharge) in the `attributes` bag.

---

## Files

| File | Description |
|------|-------------|
| [`attributes.yaml`](./attributes.yaml) | OpenAPI 3.1.1 schema |
| [`context.jsonld`](./context.jsonld) | JSON-LD 1.1 context |
| [`vocab.jsonld`](./vocab.jsonld) | RDF vocabulary |

---

## Type Discriminator

| `type` value | Description |
|---|---|
| `EV_CHARGER` | Unidirectional EV charging station |
| `EV_V2G` | Bidirectional V2G-capable EVSE (ISO 15118-20 / OCPP 2.1 BPT) |

---

## Attributes

### Common attributes (inherited from EnergyResourceCommon/v1.1)

| Field | Type | Description |
|-------|------|-------------|
| `maxImport` | QuantitativeValue | Max charge rate. `unit: W\|kW\|MW` |
| `maxExport` | QuantitativeValue | Max V2G discharge rate (EV_V2G only). `unit: W\|kW\|MW` |
| `commissioningDate` | date-time | ISO 8601 |

### EV-specific attributes

| Field | Type | Description |
|-------|------|-------------|
| `connectorType` | enum | `Type1`, `Type2`, `CCS1`, `CCS2`, `CHAdeMO`, `GB_T`, `NACS`, `Other` (IEC 62196 / J3400) |
| `controlProtocol` | enum | `OCPP_1.6`, `OCPP_2.0.1`, `OCPP_2.1`, `ISO_15118_2`, `ISO_15118_20`, `Other` |
| `v2xProtocol` | enum | `CHAdeMO_V2G`, `CCS_BPT`, `ISO_15118_20_AC_BPT`, `ISO_15118_20_DC_BPT`, `Other` — present for EV_V2G |

---

## Examples

**EV_CHARGER:**
```json
{
  "id": "did:web:utility.com:assets:evse:EVSE-001",
  "type": "EV_CHARGER",
  "attributes": {
    "maxImport": {"value": 7.4, "unit": "kW"},
    "connectorType": "Type2",
    "controlProtocol": "OCPP_2.0.1"
  },
  "parentResources": ["did:web:utility.com:assets:meter:MET-001"]
}
```

**EV_V2G:**
```json
{
  "id": "did:web:utility.com:assets:evse:EVSE-V2G-001",
  "type": "EV_V2G",
  "attributes": {
    "maxImport": {"value": 7.4, "unit": "kW"},
    "maxExport": {"value": 3.7, "unit": "kW"},
    "connectorType": "Type2",
    "controlProtocol": "ISO_15118_20",
    "v2xProtocol": "ISO_15118_20_AC_BPT"
  },
  "parentResources": ["did:web:utility.com:assets:meter:MET-001"]
}
```
