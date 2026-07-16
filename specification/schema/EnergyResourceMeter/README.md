# EnergyResourceMeter

Typed energy resource schema for metering points. A `METER` resource anchors all DER sub-resources topologically behind it, carrying the physical installation location, feeder/bus references, and communication technology.

`EnergyResourceMeter` is one of the seven composable kinds that make up `EnergyResource` in the `ElectricityCredential`.

**Canonical IRI:** `https://schema.nfh.global/EnergyResourceMeter/v1.0`

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
| `maxExportKw` | number ≥0 | Maximum grid export capacity, kW |
| `maxImportKw` | number ≥0 | Maximum grid import capacity, kW |
| `telemetryProvider` | string | Vendor API / data-source for telemetry |
| `commissioningDate` | string (date) | ISO 8601 commissioning date |
| `location` | object | Physical location — `{geo: GeoJSONGeometry, address: Address}` |

### Meter-specific

| Property | Type | Description |
|----------|------|-------------|
| `meterCapability` | enum | `Electromechanical` · `CMRI` · `AMR` · `AMI`. CIM: `AmiBillingReadyKind` (IEC 61968-9) |
| `energyDirection` | enum | `Forward` (default) · `Reverse` · `Bidirectional` · `Net`. CIM: `FlowDirectionKind` (ESPI NAESB REQ.21) |
| `functions` | array | `ToU` · `NetMetering` · `MaxDemand` · `LoadControl` · `TamperDetection` · `PowerQuality` · `EventLogging` |
| `feeder` | string | Feeder identifier this meter is supplied from |
| `bus` | string | Busbar identifier at the meter's connection point |
| `communicationTechnology` | enum | Physical layer: `PLC` · `RF_Mesh` · `GPRS` · `NB-IoT` · `LoRa` · `ZigBee` · `Other` |
| `applicationProtocol` | enum | Application layer: `DLMS_COSEM` · `ANSI_C12_18` · `IEC_61850` · `Modbus` · `Other` |

---

## Usage

- **ElectricityCredential/v1.2**: each entry with `type: "METER"` in `customerProfile.energyResources[]` conforms to this schema. METER entries anchor `consumptionProfiles[]` via `meterId` and serve as `parentResources` for DER entries.
- Asset IDs follow the IES DID pattern: `did:web:<discom-domain>:assets:meter:<local-id>`

For full property tables and worked examples, see [v1.0/README.md](./v1.0/README.md).
