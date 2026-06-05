# EnergyResourceMeter v1.0

**Schema ID:** `https://schema.beckn.io/deg/EnergyResource/EnergyResourceMeter/v1.0`
**CIM:** `cim:Meter` extends `cim:EndDevice` (IEC 61968-9)
**Status:** Current

---

## Overview

`EnergyResourceMeter` is the typed attribute schema for metering-point energy resources (`type = "METER"`). It anchors all DER sub-resources behind it in the topology tree and carries the physical installation location, feeder/bus references, and communication technology.

This schema is one of five composable `EnergyResource` kinds extracted from `ElectricityCredential v1.2`.

---

## Files

| File | Description |
|------|-------------|
| [`attributes.yaml`](./attributes.yaml) | OpenAPI 3.1.1 schema — EnergyResourceMeter and its Attributes object |
| [`context.jsonld`](./context.jsonld) | JSON-LD 1.1 context mapping terms to semantic IRIs |
| [`vocab.jsonld`](./vocab.jsonld) | RDF vocabulary — class and property definitions with CIM seeAlso links |

---

## Type Discriminator

| `type` value | CIM class |
|---|---|
| `METER` | `cim:Meter` (IEC 61968-9) |

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

### Meter-specific attributes

| Field | Type | CIM | Description |
|-------|------|-----|-------------|
| `meterType` | enum | `EndDevice.amrSystem` | AMR, AMI, Electromechanical, Forward, Reverse, Bidirectional, Prepaid, NetMeter, Other |
| `feeder` | string | — | Feeder identifier this meter is supplied from |
| `bus` | string | — | Busbar identifier at the connection point |
| `location` | object (beckn Location) | — | Postal/physical installation location |
| `communicationTechnology` | enum | — | PLC, RF_Mesh, GPRS, NB-IoT, LoRa, ZigBee, Other |

---

## Minimal valid example

```json
{
  "id": "did:web:bescom.karnataka.gov.in:assets:meter:MET-001",
  "type": "METER",
  "attributes": {
    "make": "Landis+Gyr",
    "model": "E350",
    "meterType": "AMI",
    "ratedPowerKw": 10,
    "commissioningDate": "2022-04-01",
    "gps": "12.9716,77.5946",
    "feeder": "FDR-BLR-042",
    "bus": "BUS-042-A",
    "communicationTechnology": "NB-IoT",
    "location": {
      "address": "12, MG Road",
      "city": { "name": "Bengaluru", "code": "BLR" },
      "state": { "name": "Karnataka", "code": "KA" },
      "country": { "code": "IN" },
      "area_code": "560001"
    }
  },
  "subResources": [],
  "parentResources": ["did:web:bescom.karnataka.gov.in:assets:feeder:FDR-BLR-042"]
}
```
