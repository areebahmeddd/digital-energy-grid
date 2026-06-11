# EnergyResourceNetwork v1.1

**Schema ID:** `https://schema.beckn.io/EnergyResourceNetwork/v1.1`
**CIM:** `PowerTransformer`, `BusbarSection`, `Feeder`, `Substation` (IEC 61970-301)
**Status:** Current

---

## v1.1 changes

Inherits `EnergyResourceCommon/v1.1`. Common power fields renamed to `QuantitativeValue`:
`ratedPowerKw → ratedPower`, `maxExportKw → maxExport`, `maxImportKw → maxImport`.
Network-specific: `nominalVoltageKv → nominalVoltage` (unit: `V|kV`).

---

## Overview

`EnergyResourceNetwork` represents distribution network topology elements used for hierarchical grid modelling and feeder-level aggregation.

---

## Files

| File | Description |
|------|-------------|
| [`attributes.yaml`](./attributes.yaml) | OpenAPI 3.1.1 schema |
| [`context.jsonld`](./context.jsonld) | JSON-LD 1.1 context |
| [`vocab.jsonld`](./vocab.jsonld) | RDF vocabulary |

---

## Type Discriminator

| `type` value | CIM class | Description |
|---|---|---|
| `DT` | `PowerTransformer` | Distribution transformer |
| `BUS` | `BusbarSection` | Busbar / bus section |
| `FEEDER` | `Feeder` | Distribution feeder |
| `MICROGRID` | `Substation` / custom | Microgrid or sub-grid island |

---

## Attributes

### Common attributes (inherited from EnergyResourceCommon/v1.1)

| Field | Type | Description |
|-------|------|-------------|
| `make` | string | Manufacturer |
| `model` | string | Model |
| `commissioningDate` | date-time | ISO 8601 |

### Network-specific attributes

| Field | Type | CIM | Description |
|-------|------|-----|-------------|
| `nominalVoltage` | QuantitativeValue | `BaseVoltage.nominalVoltage` | Nominal operating voltage. `unit: V\|kV` |
| `zone` | string | — | Operating zone or region identifier |
| `substationId` | string | — | Parent substation identifier |
| `feederCode` | string | — | Feeder code per utility network records |

---

## Minimal valid example

```json
{
  "id": "did:web:utility.com:assets:feeder:FDR-BLR-042",
  "type": "FEEDER",
  "attributes": {
    "nominalVoltage": {"value": 11, "unit": "kV"},
    "feederCode": "FDR-042",
    "substationId": "SS-BLR-NORTH-01"
  }
}
```
