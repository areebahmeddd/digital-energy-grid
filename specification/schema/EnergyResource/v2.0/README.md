# EnergyResource — v2.0

Canonical, technology-neutral class for any asset that produces, consumes, stores, or modulates energy. Used by **P2P-trading** (`{id, type}` for the asset being sold), **demand-flex** (identity + dimensioning + topology), and **ElectricityCredential/v1.2** (`customerProfile.energyResources[]`).

Part of the [DEG Schema](../../) · [EnergyResource](../README.md)

## Files

| File | Description |
|------|-------------|
| [attributes.yaml](./attributes.yaml) | OpenAPI 3.1.1 — `EnergyResource` and `EnergyResourceCommon` |
| [context.jsonld](./context.jsonld) | JSON-LD context |
| [vocab.jsonld](./vocab.jsonld) | RDF vocabulary |

## Structure

`EnergyResource` inherits all fields from `EnergyResourceCommon` via `allOf`. Type-specific fields are set directly at the top level — no nested `attributes` bag.

```
EnergyResourceCommon
├── id                  — stable identifier
├── type                — asset class enum (see table below)
├── make / model        — manufacturer info
├── maxImportKw          — min power kW (negative = max discharge/export capacity)
├── maxExportKw          — max power kW (generation / charge / absorption)
├── energyCapacityKwh   — storage capacity kWh (storage resources only; omit for pure-flow)
├── telemetryProvider   — vendor API / data source
├── commissioningDate   — ISO 8601 commissioning date-time
├── location            — physical location (geo: GeoJSON Point + optional address)
├── subResources[]      — child resource ids or inline EnergyResource objects
└── parentResources[]   — parent resource ids (string FK refs — no cycle)

EnergyResource
└── allOf: [EnergyResourceCommon]   — plus additionalProperties: true
```

All fields are optional at the schema level.

## EnergyResourceCommon fields

| Field | Type | Notes |
|-------|------|-------|
| `id` | string | Stable identifier; meter serial for METER |
| `type` | string enum | See table below |
| `make` | string | Manufacturer |
| `model` | string | Model |
| `ratedPowerKw` | number ≥0 | Manufacturer-rated peak power kW — kept for backward compat; prefer `maxExportKw` for new payloads |
| `maxImportKw` | number | Min power kW; **negative = max discharge/export** (e.g. -5 for 5 kW V2G or BESS discharge); 0 for unidirectional |
| `maxExportKw` | number ≥0 | Max power kW (nameplate in principal direction); supersedes `ratedPowerKw` |
| `energyCapacityKwh` | number ≥0 | Storage capacity kWh; omit for pure-flow resources |
| `telemetryProvider` | string | Vendor API / data source |
| `commissioningDate` | string (date-time) | ISO 8601 |
| `location` | object | `geo` (GeoJSON, coordinates [lon, lat]) + optional `address` |
| `subResources` | array | Child ids or inline EnergyResource objects |
| `parentResources` | array of strings | FK refs to parent resources |

## `type` enum

| Category | Values | Notes |
|----------|--------|-------|
| Grid infrastructure | `METER`, `DT`, `BUS`, `FEEDER` | |
| Generation DERs | `SOLAR_PV`, `WIND`, `HYDRO`, `BIOGAS`, `CHP`, `FUEL_CELL` | |
| Storage | `BESS` | Stationary battery; use `energyCapacityKwh` for capacity |
| EV charging | `EV_CHARGER`, `EV_V2G` | `EV_CHARGER` is a **flexible load** (NOT storage); `EV_V2G` is a subtype with bidirectional ISO 15118-20 / OCPP 2.1 BPT capability — set `maxImportKw < 0` for discharge power |
| Power electronics | `INVERTER` | Grid-connected converter for VAr / frequency support (IEEE 1547) |
| Flexible loads | `SMART_HVAC`, `SMART_WATER_HEATER`, `CONTROLLABLE_LOAD` | |
| System | `MICROGRID` | |
| Deprecated | `SOLAR` → `SOLAR_PV` · `BATTERY` → `BESS` | Still accepted for backward compat |

### INVERTER type

`INVERTER` represents a grid-connected power-electronics converter without a dedicated fuel source: standalone battery inverters, virtual power plant aggregation points, grid-forming inverters in microgrids. Common type-specific fields (set at top level):

| Field | Type | Standard | Description |
|-------|------|----------|-------------|
| `ratedApparentPowerKva` | number | SunSpec Model 702 `maxVA` | Rated apparent power, kVA |
| `maxReactivePowerKvar` | number | IEEE 1547 / SunSpec `maxVar` | Max reactive power injection (leading), kVAr |
| `minReactivePowerKvar` | number | SunSpec `maxVarNeg` | Max reactive power absorption (lagging); usually negative |
| `rideThroughCategory` | enum | IEEE 1547-2018 | `CategoryI` / `CategoryII` / `CategoryIII` |
| `operatingMode` | enum | CIM `inverterMode` | `GridFollowing` / `GridForming` / `Standby` |
| `voltVarEnabled` | boolean | IEEE 2030.5 `opModVoltVar` | Volt-VAr curve active |
| `freqDroopEnabled` | boolean | SunSpec Model 711 | Frequency-Watt droop active |
| `enterServiceRampTimeSec` | number | SunSpec Model 703 `ESRmpTms` | Ramp-up time after reconnect, seconds |

### EV_CHARGER / EV_V2G clarification

`EV_CHARGER` is the EVSE (charge station) hardware at the grid connection point — it is a **flexible load**, not a storage resource. The EV battery is storage; use `BESS` for stationary batteries.

`EV_V2G` is a specialisation of `EV_CHARGER` with Vehicle-to-Grid capability. Express power range via:
- `maxExportKw`: max charge power (e.g. 7.4 for 7.4 kW AC)
- `maxImportKw`: discharge power as a negative value (e.g. -3.7 for 3.7 kW V2G export)

## Topology

`subResources` and `parentResources` reference other EnergyResources by `id`. `subResources` items may also be inline-nested EnergyResource objects — this is a recursive (`$ref: EnergyResource`) reference, which is explicitly valid in JSON Schema 2020-12 and OpenAPI 3.1. `parentResources` items are always string FKs to avoid cycles.

## Examples

**METER:**
```json
{
  "id": "MET2025789456123",
  "type": "METER",
  "meterCapability": "AMI",
  "location": {"geo": {"type": "Point", "coordinates": [77.5946, 12.9716]}},
  "parentResources": ["BAN-NR-F22"]
}
```

**SOLAR DER behind a meter:**
```json
{
  "id": "DER-SOLAR-001",
  "type": "SOLAR_PV",
  "maxExportKw": 3,
  "make": "Waaree", "model": "WS-300",
  "commissioningDate": "2025-01-12T00:00:00+05:30",
  "parentResources": ["MET2025789456123"]
}
```

**BESS (5 kW charge / 5 kW discharge):**
```json
{
  "id": "BESS-001",
  "type": "BESS",
  "maxExportKw": 5, "maxImportKw": -5,
  "energyCapacityKwh": 10,
  "storageType": "LithiumIon",
  "parentResources": ["MET2025789456123"]
}
```

**V2G EV charger (7.4 kW charge / 3.7 kW V2G discharge):**
```json
{
  "id": "EVSE-001",
  "type": "EV_V2G",
  "maxExportKw": 7.4, "maxImportKw": -3.7,
  "connectorType": "Type2",
  "v2xProtocol": "ISO_15118_20_AC_BPT",
  "parentResources": ["MET2025789456123"]
}
```

**INVERTER (grid-forming, VAr support, freq droop):**
```json
{
  "id": "INV-001",
  "type": "INVERTER",
  "maxExportKw": 10, "maxImportKw": -10,
  "ratedApparentPowerKva": 12,
  "maxReactivePowerKvar": 6,
  "operatingMode": "GridForming",
  "voltVarEnabled": true,
  "freqDroopEnabled": true,
  "rideThroughCategory": "CategoryIII",
  "parentResources": ["MET2025789456123"]
}
```

**P2P-trading (minimal):**
```json
{"id": "MET001", "type": "SOLAR_PV"}
```

**Microgrid topology:**
```json
{
  "id": "MICROGRID01", "type": "MICROGRID",
  "subResources": [
    "PV001", "BAT001",
    {"id": "EVSE-001", "type": "EV_V2G", "maxExportKw": 7.4, "maxImportKw": -3.7, "parentResources": ["MICROGRID01"]}
  ]
}
```

## Changes from earlier v2.0 (breaking)

- **`ratedPowerKw` retained; `maxImportKw` and `maxExportKw` added** — `ratedPowerKw` still accepted for backward compatibility. `maxExportKw` is the preferred field for new payloads (nameplate power in the principal direction); `maxImportKw` can be negative to express discharge/export capacity.
- **`attributes` bag removed** — common and type-specific fields are now at the top level via `allOf` inheritance. Migration: `attributes.make` → `make`, `attributes.ratedPowerKw` → `maxExportKw`, etc.
- **`location` elevated to `EnergyResourceCommon`** — was meter-specific; now applies to all resource types.
- **`gps` field removed** — use `location.geo` (GeoJSON Point, coordinates `[longitude, latitude]`).
- **`INVERTER` type added** — grid-connected power-electronics converters.
- **`EV_CHARGER` reclassified** — flexible load, not storage.
- **`SOLAR` and `BATTERY` deprecated** — use `SOLAR_PV` and `BESS` respectively.
