# EnergyResourceMeter v1.1

**Schema ID:** `https://schema.nfh.global/EnergyResourceMeter/v1.1`
**CIM:** `cim:Meter` extends `cim:EndDevice` (IEC 61968-9)
**Status:** Current

---

## v1.1 changes

Inherits `EnergyResourceCommon/v1.1`. Common power fields renamed to `QuantitativeValue`:
`ratedPowerKw → ratedPower`, `maxExportKw → maxExport`, `maxImportKw → maxImport` (unit: `W|kW|MW`).

---

## Overview

`EnergyResourceMeter` is the typed attribute schema for metering-point energy resources (`type = "METER"`). It anchors all DER sub-resources in the topology tree and carries the physical installation location, feeder/bus references, and communication technology.

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
| `METER` | `cim:Meter` (IEC 61968-9) |

---

## Attributes

### Common attributes (inherited from EnergyResourceCommon/v1.1)

| Field | Type | Description |
|-------|------|-------------|
| `make` | string | Manufacturer |
| `model` | string | Model number |
| `ratedPower` | QuantitativeValue | Rated peak power. `unit: W\|kW\|MW` |
| `maxExport` | QuantitativeValue | Max grid export capacity. `unit: W\|kW\|MW` |
| `maxImport` | QuantitativeValue | Max grid import capacity. `unit: W\|kW\|MW` |
| `telemetryProvider` | string | Telemetry vendor / API identifier |
| `commissioningDate` | date-time | ISO 8601 |
| `location` | object | `geo` (GeoJSONGeometry) + optional `address` |

### Meter-specific attributes

| Field | Type | CIM | Description |
|-------|------|-----|-------------|
| `meterCapability` | enum | `AmiBillingReadyKind` (IEC 61968-9) | `Electromechanical` · `CMRI` · `AMR` · `AMI` |
| `energyDirection` | enum | `FlowDirectionKind` (ESPI NAESB REQ.21) | `Forward` (default) · `Reverse` · `Bidirectional` · `Net` |
| `functions` | array of enum | `EndDeviceFunction[0..*]` (IEC 61968-9) | `ToU` · `NetMetering` · `MaxDemand` · `LoadControl` · `TamperDetection` · `PowerQuality` · `EventLogging` |
| `feeder` | string | — | Feeder identifier this meter is supplied from |
| `bus` | string | — | Busbar identifier at the connection point |
| `communicationTechnology` | enum | — | `PLC` · `RF_Mesh` · `GPRS` · `NB-IoT` · `LoRa` · `ZigBee` · `Other` |
| `applicationProtocol` | enum | IEC 62056 / ANSI C12 | `DLMS_COSEM` · `ANSI_C12_18` · `IEC_61850` · `Modbus` · `Other` |

---

## Minimal valid example

```json
{
  "id": "did:web:bescom.karnataka.gov.in:assets:meter:MET-001",
  "type": "METER",
  "attributes": {
    "meterCapability": "AMI",
    "energyDirection": "Forward",
    "location": {"geo": {"type": "Point", "coordinates": [77.5946, 12.9716]}},
    "feeder": "FDR-BLR-042",
    "communicationTechnology": "NB-IoT",
    "applicationProtocol": "DLMS_COSEM"
  },
  "parentResources": ["did:web:bescom.karnataka.gov.in:assets:feeder:FDR-BLR-042"]
}
```
