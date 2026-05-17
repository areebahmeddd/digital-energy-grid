# EnergyResource — v2.0

Canonical, technology-neutral class for any asset that produces, consumes, stores, or modulates energy. Used today by **P2P-trading** (minimal `{sourceType, meterId}` shape) and **demand-flex** (richer identity + rated dimensioning + topology). Both shapes are valid against the same schema — every new field is optional.

Part of the [DEG Schema](../../) · [EnergyResource](../README.md)

## Files

| File | Description |
|------|-------------|
| [attributes.yaml](./attributes.yaml) | OpenAPI 3.1.1 `components.schemas.EnergyResource` |
| [context.jsonld](./context.jsonld) | JSON-LD context — `EnergyResource` → `deg:EnergyResource` |
| [vocab.jsonld](./vocab.jsonld) | RDF vocabulary |

## Properties

No field is `required` at the schema level — domain profiles (demand-flex's network rego, p2p-trading's item gates) enforce their own cross-field expectations.

### Backward-compat (P2P-trading wave2)

| Property | Type | Description |
|----------|------|-------------|
| `sourceType` | enum | `SOLAR` \| `BATTERY` \| `GRID` \| `HYBRID` \| `RENEWABLE`. Closed set used by P2P-trading. |
| `meterId` | string | Identifier of the meter associated with this resource. In P2P-trading, the source meter; in demand-flex, the meter the resource sits behind. Typically `der://meter/<id>` but format is open. |

### Identity + rated dimensioning (new in v2.0 additive merge)

| Property | Type | Description |
|----------|------|-------------|
| `resourceId` | string | Stable resource identifier; recommended URI scheme `der://<type>/<id>`. |
| `resourceType` | string (open) | Open-string asset class — `EV_CHARGER`, `EV_V2G`, `BATTERY`, `BESS`, `SOLAR_PV`, `WIND`, `BIOGAS`, `SMART_HVAC`, `SMART_WATER_HEATER`, `CONTROLLABLE_LOAD`, `GRID`, … |
| `make` / `model` | string | Manufacturer info. |
| `ratedPowerKw` | number ≥0 | Manufacturer-rated peak dispatchable power, kW. |
| `energyCapacityKwh` | number ≥0 | Rated stored-energy capacity, kWh — populated for storage-class resources, omitted for pure-flow. |
| `telemetryProvider` | string | Identifier of the vendor API / data source supplying telemetry (e.g. `tata-evp-telematics`). |
| `resourceAttributes` | object (open) | Type-specific extensible bag (EV VIN/chargingProtocol; battery chemistry/cycleCount; …). |

### Topology

| Property | Type | Description |
|----------|------|-------------|
| `subResources` | array | Child resources. Each item is **either** a bare `resourceId` (FK to a sibling EnergyResource in the same payload) **or** an inline-nested EnergyResource. |

## Wave2 P2P-trading payload (unchanged shape, valid as-is)

```jsonc
{
  "@type": "EnergyResource",
  "sourceType": "SOLAR",
  "meterId": "TEST_METER_SELLER_001"
}
```

## Demand-flex DR payload (uses the new identity + dimensioning fields)

```jsonc
{
  "@type": "EnergyResource",
  "resourceId": "der://ev/VIN001",
  "resourceType": "EV_CHARGER",
  "meterId": "der://meter/001",
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

## Topology example — microgrid as parent of solar + BESS + EV

```jsonc
{
  "@type": "EnergyResource",
  "resourceId": "der://site/MICROGRID01",
  "resourceType": "MICROGRID",
  "meterId": "der://meter/001",
  "subResources": [
    "der://solar/PV001",
    "der://battery/BAT001",
    {
      "@type": "EnergyResource",
      "resourceId": "der://ev/VIN001",
      "resourceType": "EV_CHARGER",
      "ratedPowerKw": 7.0
    }
  ]
}
```

The first two children are bare `resourceId` strings — they're enumerated as peer resources elsewhere in the same offer. The third is inline-nested because it only exists in this topological context.

## Changes from v0.3 → v2.0

- v0.3 → v2.0 (original release): extracted from combined `EnergyTrade/v0.3/attributes.yaml` into a standalone schema. Two fields: `sourceType`, `meterId`.
- v2.0 (additive merge, this revision): added identity (`resourceId`, `resourceType`), dimensioning (`make`, `model`, `ratedPowerKw`, `energyCapacityKwh`), provenance hint (`telemetryProvider`), extensible bag (`resourceAttributes`), and topology (`subResources`). Absorbs and supersedes the short-lived [`DER/v1.0/`](../../DER/v1.0/) schema that was introduced and removed in the same release cycle. No fields are `required`; wave2 payloads continue to validate unchanged.
