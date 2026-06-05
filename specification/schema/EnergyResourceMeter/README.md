# EnergyResourceMeter

Typed energy resource schema for metering points. A `METER` resource anchors all DER sub-resources topologically behind it, carrying the physical installation location, feeder/bus references, and communication technology.

Per the [DEG Hourglass architecture](https://github.com/beckn/DEG/issues/119), `EnergyResourceMeter` is one of the five composable kinds that make up `EnergyResource` in the `ElectricityCredential`.

**Canonical IRI:** `https://schema.beckn.io/EnergyResourceMeter/v1.0`

**CIM alignment:** `cim:Meter` extends `cim:EndDevice` (IEC 61968-9)

**Tags:** `energy-resource` · `meter` · `energy` · `deg`

---

## Versions

| Version | Status | Notes |
|---------|--------|-------|
| [v1.0](./v1.0/) | Current | Initial typed kind for METER resources, extracted from `ElectricityCredential/v1.2`. Adds `communicationTechnology` field. |

---

## Type discriminator

| `type` value | CIM class | Description |
|---|---|---|
| `METER` | `cim:Meter` (IEC 61968-9) | Physical metering point (AMR, AMI, electromechanical, etc.) |

---

## Properties (v1.0)

### Common (EnergyResourceCommonAttributes)

| Property | Type | Description |
|----------|------|-------------|
| `make` | string | Manufacturer name |
| `model` | string | Model number |
| `ratedPowerKw` | number ≥0 | Nameplate peak power, kW |
| `telemetryProvider` | string | Vendor API / data-source for telemetry |
| `commissioningDate` | string (date) | ISO 8601 commissioning date |
| `gps` | string | `"lat,lng"` coordinates |

### Meter-specific

| Property | Type | Description |
|----------|------|-------------|
| `meterType` | enum | AMR, AMI, Electromechanical, Forward, Reverse, Bidirectional, Prepaid, NetMeter, Other |
| `feeder` | string | Feeder identifier this meter is supplied from |
| `bus` | string | Busbar identifier at the meter's connection point |
| `location` | object | Postal location (beckn Location shape) |
| `communicationTechnology` | enum | PLC, RF_Mesh, GPRS, NB-IoT, LoRa, ZigBee, Other |

---

## Usage

- **ElectricityCredential/v1.2**: each entry with `type: "METER"` in `customerProfile.energyResources[]` conforms to this schema. METER entries anchor `consumptionProfiles[]` via `meterId` and serve as `parentResources` for DER entries.
- Asset IDs follow the IES DID pattern: `did:web:<discom-domain>:assets:meter:<local-id>`

For full property tables and worked examples, see [v1.0/README.md](./v1.0/README.md).
