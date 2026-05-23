# EnergyResource — v2.0

Canonical, technology-neutral class for any asset that produces, consumes, stores, or modulates energy. Used by **P2P-trading** (`{id, type}` for the asset being sold), **demand-flex** (richer identity + dimensioning + topology), and **ElectricityCredential/v1.1** (`customerProfile.energyResources[]`).

Part of the [DEG Schema](../../) · [EnergyResource](../README.md)

## Files

| File | Description |
|------|-------------|
| [attributes.yaml](./attributes.yaml) | OpenAPI 3.1.1 — `EnergyResource` and `CommonResourceAttributes` |
| [context.jsonld](./context.jsonld) | JSON-LD context |
| [vocab.jsonld](./vocab.jsonld) | RDF vocabulary |

## Structure

```
EnergyResource
├── id                  — stable identifier (meter serial number for METER resources)
├── type                — asset class enum (METER, DT, BUS, FEEDER, SOLAR, BATTERY, …)
├── attributes          — all other properties (open bag)
│   ├── CommonResourceAttributes: make, model, ratedPowerKw, energyCapacityKwh, telemetryProvider
│   └── type-specific:  meterType, gps, location, feeder, bus, commissioningDate, storageType, VIN, …
├── subResources[]      — child resource ids or inline objects (topology)
└── parentResources[]   — parent resource ids (topology)
```

All fields are optional at the schema level.

## CommonResourceAttributes

Dimensioning fields shared across all resource types. Live inside `attributes`.

| Field | Type | Description |
|-------|------|-------------|
| `make` | string | Manufacturer |
| `model` | string | Model |
| `ratedPowerKw` | number ≥0 | Rated peak power, kW |
| `energyCapacityKwh` | number ≥0 | Stored-energy capacity, kWh (storage-class only) |
| `telemetryProvider` | string | Vendor API / data source for telemetry |

## `type` enum

| Category | Values |
|----------|--------|
| Grid infrastructure | `METER`, `DT`, `BUS`, `FEEDER` |
| Generation DERs | `SOLAR`, `SOLAR_PV`, `WIND`, `HYDRO`, `BIOGAS`, `CHP`, `FUEL_CELL` |
| Storage | `BATTERY`, `BESS` |
| Flexible loads | `EV_CHARGER`, `EV_V2G`, `SMART_HVAC`, `SMART_WATER_HEATER`, `CONTROLLABLE_LOAD` |
| System | `MICROGRID` |

## Meter attributes (`type: METER`, inside `attributes`)

| Field | Type | Description |
|-------|------|-------------|
| `meterType` | enum | AMR, AMI, Electromechanical, Forward, Reverse, Bidirectional, Prepaid, NetMeter, Other |
| `gps` | string | `"lat,lng"` coordinates |
| `location` | object | Postal location (beckn Location shape) |

Grid topology (feeder, bus, DT) is expressed via `parentResources[]` — reference the id of a `FEEDER`, `BUS`, or `DT` resource.

## Examples

**METER:**
```json
{
  "id": "MET2025789456123",
  "type": "METER",
  "attributes": {"meterType": "AMI", "gps": "12.9716,77.5946"},
  "parentResources": ["BAN-NR-F22"]
}
```

**SOLAR DER behind a meter:**
```json
{
  "id": "DER-SOLAR-001",
  "type": "SOLAR",
  "attributes": {"ratedPowerKw": 3, "make": "Waaree", "model": "WS-300", "commissioningDate": "2025-01-12"},
  "parentResources": ["MET2025789456123"]
}
```

**P2P-trading (minimal):**
```json
{"id": "MET001", "type": "SOLAR"}
```

**Demand-flex (EV with parent meter):**
```json
{
  "id": "VIN001",
  "type": "EV_CHARGER",
  "attributes": {
    "make": "Tata", "model": "Nexon EV",
    "ratedPowerKw": 7.0, "energyCapacityKwh": 30.0,
    "telemetryProvider": "tata-evp-telematics",
    "vin": "MAT123456789012345",
    "chargingProtocol": "OCPP_2_0_1"
  },
  "parentResources": ["MET001"]
}
```

**Topology — microgrid:**
```json
{
  "id": "MICROGRID01",
  "type": "MICROGRID",
  "subResources": [
    "PV001",
    "BAT001",
    {
      "id": "VIN001",
      "type": "EV_CHARGER",
      "attributes": {"ratedPowerKw": 7.0},
      "parentResources": ["MICROGRID01"]
    }
  ]
}
```

## Topology

`subResources` and `parentResources` reference other EnergyResources by `id`. `subResources` items may also be inline-nested EnergyResource objects. `parentResources` items are always strings (FK references — inlining parents would create a cycle).

## Changes from earlier v2.0 (breaking)

- **`resourceId` → `id`**, **`resourceType` → `type`** — simpler names.
- **`resourceAttributes` → `attributes`** — renamed; still the open attribute bag.
- **`CommonResourceAttributes` added** — named sub-schema for make/model/ratedPowerKw/energyCapacityKwh/telemetryProvider; all live inside `attributes`.
- **Meter fields absorbed into `attributes`** — meterType, gps, location, feeder, bus are documented properties within the `attributes` bag for METER resources.
- **`@type` discriminator field removed** — no longer needed.
- **`sourceType` / `meterId`** — removed in the previous revision; still absent.
