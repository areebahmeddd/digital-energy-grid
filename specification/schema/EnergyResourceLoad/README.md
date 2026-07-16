# EnergyResourceLoad

Typed energy resource schema for controllable load DERs: smart HVAC, smart water heaters, and generic controllable loads participating in demand-response and demand-flexibility programs.

`EnergyResourceLoad` is one of the seven composable kinds that make up `EnergyResource` in the `ElectricityCredential`.

**Canonical IRI:** `https://schema.nfh.global/EnergyResourceLoad/v1.0`

**CIM alignment:** `cim:EnergyConsumer` / `cim:ConformLoad` (IEC 61970-301)

**Tags:** `energy-resource` · `load` · `demand-response` · `demand-flexibility` · `energy` · `deg`

---

## Versions

| Version | Status | Notes |
|---------|--------|-------|
| [v1.0](./v1.0/) | Current | Initial typed kind for controllable load DERs, extracted from `ElectricityCredential/v1.2`. Adds `controlProtocol` and `loadCategory` fields. |

---

## Type discriminators

| `type` value | CIM class | Description |
|---|---|---|
| `SMART_HVAC` | `cim:ConformLoad` (Heating/Cooling) | Controllable heating or cooling system |
| `SMART_WATER_HEATER` | `cim:ConformLoad` (WaterHeating) | Controllable water heater |
| `CONTROLLABLE_LOAD` | `cim:ConformLoad` | Generic controllable load |

---

## Properties (v1.0)

### Common (EnergyResourceCommonAttributes)

| Property | Type | Description |
|----------|------|-------------|
| `make` | string | Manufacturer name |
| `model` | string | Model number |
| `ratedPowerKw` | number ≥0 | Nameplate peak power draw, kW |
| `maxExportKw` | number ≥0 | Maximum grid export capacity, kW |
| `maxImportKw` | number ≥0 | Maximum grid import capacity, kW |
| `telemetryProvider` | string | Vendor API / data-source for telemetry |
| `commissioningDate` | string (date) | ISO 8601 commissioning date |
| `location` | object | Physical location — `{geo: GeoJSONGeometry, address: Address}` |

### Load-specific

| Property | Type | Description |
|----------|------|-------------|
| `controlProtocol` | enum | OpenADR_2.0b, OCPP_2.0.1, SunSpec_Modbus, EEBus, Modbus, Other |
| `loadCategory` | enum | Heating, Cooling, WaterHeating, Lighting, EV, Industrial, Other |

---

## Usage

- **ElectricityCredential/v1.2**: entries with load `type` values in `customerProfile.energyResources[]` conform to this schema. Load DERs reference their parent METER via `parentResources[]`.
- **Demand-flex**: controllable loads are eligible shed/shift resources; `controlProtocol` determines the dispatch pathway.
- Asset IDs follow the IES DID pattern: `did:web:<discom-domain>:assets:load:<local-id>`

For full property tables and worked examples, see [v1.0/README.md](./v1.0/README.md).
