# EnergyResource — v2.0

Canonical, technology-neutral class for any asset that produces, consumes, stores, or modulates energy. Used by **P2P-trading** (`{resourceId, resourceType}` for the asset being sold), **demand-flex** (richer identity + dimensioning + topology to enumerate the assets behind a contract), and reused by every future DEG domain.

Part of the [DEG Schema](../../) · [EnergyResource](../README.md)

## Files

| File | Description |
|------|-------------|
| [attributes.yaml](./attributes.yaml) | OpenAPI 3.1.1 `components.schemas.EnergyResource` |
| [context.jsonld](./context.jsonld) | JSON-LD context — `EnergyResource` → `deg:EnergyResource` |
| [vocab.jsonld](./vocab.jsonld) | RDF vocabulary |

## Properties

No field is `required` at the schema level — domain profiles (demand-flex's network rego, p2p-trading's item gates) enforce their own cross-field expectations.

### Identity + rated dimensioning

| Property | Type | Description |
|----------|------|-------------|
| `resourceId` | string | Stable identifier. For `METER` resources: the bare meter serial number (e.g., `"MET001"`). For DERs: recommended scheme `der://<type>/<id>`. |
| `resourceType` | string (open) | Open-string asset class — `METER`, `SOLAR`, `SOLAR_PV`, `WIND`, `HYDRO`, `BIOGAS`, `EV_CHARGER`, `EV_V2G`, `BATTERY`, `BESS`, `SMART_HVAC`, `SMART_WATER_HEATER`, `CONTROLLABLE_LOAD`, … |
| `make` / `model` | string | Manufacturer info. |
| `ratedPowerKw` | number ≥0 | Manufacturer-rated peak dispatchable power, kW. |
| `energyCapacityKwh` | number ≥0 | Rated stored-energy capacity, kWh — populated for storage-class resources, omitted for pure-flow. |
| `telemetryProvider` | string | Identifier of the vendor API / data source supplying telemetry (e.g. `tata-evp-telematics`). |
| `resourceAttributes` | object (open) | Type-specific extensible bag (EV VIN/chargingProtocol; battery chemistry/cycleCount; …). |

### Topology

| Property | Type | Description |
|----------|------|-------------|
| `subResources` | array | Child resources. Each item is **either** a bare `resourceId` string (FK to a sibling EnergyResource in the same payload) **or** an inline-nested EnergyResource. |
| `parentResources` | array of strings | Parent resources — `resourceId`s of EnergyResources this one sits behind (typically a meter or aggregation point). **String form only** — parents are enumerated elsewhere; inlining them inside a child would be a definitional cycle. |

## P2P-trading payload (wave2)

```jsonc
{
  "@type": "EnergyResource",
  "resourceId": "der://meter/TEST_METER_SELLER_001",
  "resourceType": "SOLAR"
}
```

## Demand-flex DR payload (richer identity + parent linkage)

```jsonc
{
  "@type": "EnergyResource",
  "resourceId": "der://ev/VIN001",
  "resourceType": "EV_CHARGER",
  "parentResources": ["der://meter/001"],
  "make": "Tata",
  "model": "Nexon EV",
  "ratedPowerKw": 7.0,
  "energyCapacityKwh": 30.0,
  "telemetryProvider": "tata-evp-telematics",
  "resourceAttributes": {
    "vin": "MAT123456789012345",
    "chargingProtocol": "OCPP_2_0_1"
  }
}
```

`parentResources: ["der://meter/001"]` declares this EV sits behind grid meter `der://meter/001`, which is enumerated separately in the contract's `participatingMeters[*]`. The schema does not enforce that the FK resolves — domain profiles do.

## Topology example — microgrid with mixed inline + reference children

```jsonc
{
  "@type": "EnergyResource",
  "resourceId": "der://site/MICROGRID01",
  "resourceType": "MICROGRID",
  "subResources": [
    "der://solar/PV001",
    "der://battery/BAT001",
    {
      "@type": "EnergyResource",
      "resourceId": "der://ev/VIN001",
      "resourceType": "EV_CHARGER",
      "parentResources": ["der://site/MICROGRID01"],
      "ratedPowerKw": 7.0
    }
  ]
}
```

`subResources` (string or inline) and `parentResources` (string only) together form the directed graph. Inline children may also carry an explicit `parentResources` back-pointer if the consumer needs symmetry.

## MeterAttributes (`resourceType: METER`)

`resourceAttributes` shape for grid connection points. All fields are optional — the bag is open-ended. `resourceId` of the EnergyResource **is** the meter serial number.

| Field | Type | Description |
|-------|------|-------------|
| `meterType` | enum | AMR, AMI, Electromechanical, Forward, Reverse, Bidirectional, Prepaid, NetMeter, Other |
| `gps` | string | `"lat,lng"` coordinates of the physical meter |
| `location` | object | Postal location (beckn Location shape) |
| `feeder` | string | Distribution feeder ID or name |
| `bus` | string | Substation bus reference |

```jsonc
{
  "@type": "EnergyResource",
  "resourceId": "MET2025789456123",
  "resourceType": "METER",
  "resourceAttributes": {
    "meterType": "AMI",
    "gps": "12.9716,77.5946",
    "feeder": "BAN-NR-F22",
    "bus": "BUS-11kV-001"
  }
}
```

## Changes from earlier v2.0 (breaking)

- **`sourceType` removed** — use `resourceType` (open string, accepts every value the enum did and more).
- **`meterId` removed** — split into:
  - `resourceId` for the resource's own identifier (P2P-trading wave2 used `meterId` here),
  - `parentResources[]` for upward topology (demand-flex used `meterId` for the meter-FK semantic).

Wave2 P2P-trading + demand-flex devkit fixtures migrated alongside this schema revision.
