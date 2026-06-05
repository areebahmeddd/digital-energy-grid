# EnergyResourceNetwork v1.0

**Schema ID:** `https://schema.beckn.io/deg/EnergyResource/EnergyResourceNetwork/v1.0`
**CIM:** `cim:PowerTransformer`, `cim:BusbarSection`, `cim:Feeder`, `cim:Substation` (IEC 61970-301)
**Status:** Current

---

## Overview

`EnergyResourceNetwork` is the typed attribute schema for grid-network infrastructure energy resources. It covers distribution transformers, busbars, feeders, and microgrids — the topology containers that anchor metering points and DER resources in the asset graph.

This schema is one of five composable `EnergyResource` kinds extracted from `ElectricityCredential v1.2`.

---

## Files

| File | Description |
|------|-------------|
| [`attributes.yaml`](./attributes.yaml) | OpenAPI 3.1.1 schema — EnergyResourceNetwork and its Attributes object |
| [`context.jsonld`](./context.jsonld) | JSON-LD 1.1 context mapping terms to semantic IRIs |
| [`vocab.jsonld`](./vocab.jsonld) | RDF vocabulary — class and property definitions with CIM seeAlso links |

---

## Type Discriminator

| `type` value | CIM class | Description |
|---|---|---|
| `DT` | `cim:PowerTransformer` | Distribution transformer |
| `BUS` | `cim:BusbarSection` | Busbar section |
| `FEEDER` | `cim:Feeder` (EquipmentContainer) | Distribution feeder |
| `MICROGRID` | `cim:Substation` / custom | Microgrid container |

---

## Attributes

### Common attributes (EnergyResourceCommonAttributes — all kinds)

| Field | Type | CIM | Description |
|-------|------|-----|-------------|
| `make` | string | — | Manufacturer |
| `model` | string | — | Model number |
| `ratedPowerKw` | number ≥ 0 | `GeneratingUnit.maxOperatingP` | Rated peak capacity, kW |
| `telemetryProvider` | string | — | Telemetry vendor / API identifier |
| `commissioningDate` | string (ISO 8601 date) | — | Date commissioned |
| `gps` | string (lat,lng) | — | GPS coordinates |

### Network-specific attributes

| Field | Type | CIM | Description |
|-------|------|-----|-------------|
| `nominalVoltageKv` | number ≥ 0 | `BaseVoltage.nominalVoltage` | Nominal operating voltage, kV |
| `zone` | string | — | Operating zone / region identifier |
| `substationId` | string | `Substation` | Parent substation identifier |
| `feederCode` | string | `Feeder` | Feeder code per utility records |

---

## Minimal valid example

```json
{
  "id": "did:web:bescom.karnataka.gov.in:assets:feeder:FDR-BLR-042",
  "type": "FEEDER",
  "attributes": {
    "nominalVoltageKv": 11,
    "zone": "BESCOM-BLR-SOUTH",
    "substationId": "SST-BLR-007",
    "feederCode": "FDR-BLR-042",
    "commissioningDate": "2018-09-01T00:00:00+05:30",
    "location": {"geo": {"type": "Point", "coordinates": [77.5938, 12.9250]}}
  },
  "subResources": [
    "did:web:bescom.karnataka.gov.in:assets:meter:MET-001",
    "did:web:bescom.karnataka.gov.in:assets:meter:MET-002"
  ],
  "parentResources": ["did:web:bescom.karnataka.gov.in:assets:substation:SST-BLR-007"]
}
```
