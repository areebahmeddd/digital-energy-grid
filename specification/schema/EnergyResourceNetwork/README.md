# EnergyResourceNetwork

Typed energy resource schema for grid-network infrastructure: distribution transformers (DT), busbars (BUS), feeders (FEEDER), and microgrids (MICROGRID). These resources act as topology anchors in the `EnergyResource` graph — meters and DERs hang behind them via `parentResources[]`.

`EnergyResourceNetwork` is one of the seven composable kinds that make up `EnergyResource` in the `ElectricityCredential`.

**Canonical IRI:** `https://schema.nfh.global/EnergyResourceNetwork/v1.0`

**CIM alignment:** `cim:PowerTransformer` (DT), `cim:BusbarSection` (BUS), `cim:Feeder` (FEEDER), `cim:Substation` (MICROGRID) — IEC 61970-301

**Tags:** `energy-resource` · `network` · `grid` · `infrastructure` · `energy` · `deg`

---

## Versions

| Version | Status | Notes |
|---------|--------|-------|
| [v1.0](./v1.0/) | Current | Initial typed kind for grid-network infrastructure, extracted from `ElectricityCredential/v1.2`. Adds `nominalVoltageKv`, `zone`, `substationId`, `feederCode` fields. |

---

## Type discriminators

| `type` value | CIM class | Description |
|---|---|---|
| `DT` | `cim:PowerTransformer` | Distribution transformer |
| `BUS` | `cim:BusbarSection` | Busbar section |
| `FEEDER` | `cim:Feeder` (EquipmentContainer) | Distribution feeder |
| `MICROGRID` | `cim:Substation` / custom container | Microgrid or substation boundary |

---

## Properties (v1.0)

### Common (EnergyResourceCommonAttributes)

| Property | Type | Description |
|----------|------|-------------|
| `make` | string | Manufacturer name |
| `model` | string | Model number |
| `ratedPowerKw` | number ≥0 | Nameplate peak power capacity, kW |
| `maxExportKw` | number ≥0 | Maximum grid export capacity, kW |
| `maxImportKw` | number ≥0 | Maximum grid import capacity, kW |
| `telemetryProvider` | string | Vendor API / data-source for telemetry |
| `commissioningDate` | string (date) | ISO 8601 commissioning date |
| `location` | object | Physical location — `{geo: GeoJSONGeometry, address: Address}` |

### Network-specific

| Property | Type | CIM alignment | Description |
|----------|------|---------------|-------------|
| `nominalVoltageKv` | number ≥0 | `BaseVoltage.nominalVoltage` | Nominal operating voltage, kV |
| `zone` | string | — | Operating zone / region identifier |
| `substationId` | string | — | Parent substation identifier per utility records |
| `feederCode` | string | — | Feeder code per utility records (relevant for FEEDER and DT) |

---

## Usage

- **ElectricityCredential/v1.2**: entries with network `type` values in `customerProfile.energyResources[]` conform to this schema. METER and DER resources that reference `did:web:...:assets:feeder:...` or `did:web:...:assets:dt:...` in their `parentResources[]` are referencing EnergyResourceNetwork entries.
- Asset IDs follow the IES DID pattern: `did:web:<discom-domain>:assets:<class>:<local-id>` (e.g. `did:web:bescom.karnataka.gov.in:assets:feeder:FDR-BLR-042`)

For full property tables and worked examples, see [v1.0/README.md](./v1.0/README.md).
