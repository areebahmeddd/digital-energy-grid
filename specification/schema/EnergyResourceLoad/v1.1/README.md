# EnergyResourceLoad v1.1

**Schema ID:** `https://schema.beckn.io/EnergyResourceLoad/v1.1`
**CIM:** `cim:EnergyConsumer` / `cim:ConformLoad` (IEC 61970-301)
**Status:** Current

---

## v1.1 changes

Inherits `EnergyResourceCommon/v1.1`. Common power fields renamed to `QuantitativeValue`:
`ratedPowerKw → ratedPower`, `maxExportKw → maxExport`, `maxImportKw → maxImport` (unit: `W|kW|MW`).

---

## Overview

`EnergyResourceLoad` represents controllable electrical loads including smart HVAC, smart water heaters, and generic demand-response loads.

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
| `SMART_HVAC` | `EnergyConsumer` / `ConformLoad` |
| `SMART_WATER_HEATER` | `EnergyConsumer` / `ConformLoad` |
| `CONTROLLABLE_LOAD` | `EnergyConsumer` / `ConformLoad` |

---

## Attributes

### Common attributes (inherited from EnergyResourceCommon/v1.1)

| Field | Type | Description |
|-------|------|-------------|
| `maxImport` | QuantitativeValue | Rated load draw. `unit: W\|kW\|MW` |
| `commissioningDate` | date-time | ISO 8601 |

### Load-specific attributes

| Field | Type | Description |
|-------|------|-------------|
| `controlProtocol` | enum | `OpenADR_2.0b`, `OCPP_2.0.1`, `SunSpec_Modbus`, `EEBus`, `Modbus`, `Other` |
| `loadCategory` | enum | `Heating`, `Cooling`, `WaterHeating`, `Lighting`, `EV`, `Industrial`, `Other` |

---

## Minimal valid example

```json
{
  "id": "did:web:utility.com:assets:hvac:HVAC-001",
  "type": "SMART_HVAC",
  "attributes": {
    "maxImport": {"value": 3, "unit": "kW"},
    "loadCategory": "Heating",
    "controlProtocol": "OpenADR_2.0b"
  },
  "parentResources": ["did:web:utility.com:assets:meter:MET-001"]
}
```
