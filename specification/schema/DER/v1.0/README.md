# DER — v1.0

Distributed Energy Resource — a controllable / observable energy asset behind a grid meter.

Part of the [DEG Schema](../../) · [DER](../README.md)

## Files

| File | Description |
|------|-------------|
| [attributes.yaml](./attributes.yaml) | OpenAPI 3.1.1 `components.schemas.DER` |
| [context.jsonld](./context.jsonld) | JSON-LD context — term `DER` maps to `deg:DER` |
| [vocab.jsonld](./vocab.jsonld) | RDF vocabulary |

## Properties

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `derId` | string (URI) | ✓ | `der://<derType>/<id>`. Type-discriminated identifier, distinct from grid-meter URIs. |
| `derType` | string | ✓ | Asset class — `EV_CHARGER`, `BATTERY`, `SOLAR_PV`, `SMART_HVAC`, `SMART_WATER_HEATER`, … Open-ended; unknown values pass through. |
| `behindMeter` | string | ✓ | URI of the grid meter this DER sits behind. FK into the contract's `participatingMeters[*]`. Many-to-one. |
| `make` | string | | Manufacturer (free text). |
| `model` | string | | Model (free text). |
| `ratedPowerKw` | number | | Rated peak dispatchable power, kW. |
| `energyCapacityKwh` | number | | Rated stored-energy capacity, kWh. Populated for storage DERs; omitted for pure-flow DERs (solar, HVAC). |
| `telemetryProvider` | string | | Vendor API / data-source identifier supplying telemetry for this DER. Free text. |
| `derAttributes` | object | | Type-specific attribute bag (EV VIN/chargingProtocol; battery chemistry/cycleCount; solar panelCount; …). |

## URI scheme

DERs use a type-discriminated URI scheme — `der://<derType>/<id>` — so the type can be parsed without dereferencing the schema:

| derType | URI pattern | Example |
|---|---|---|
| `EV_CHARGER` | `der://ev/<vin>` | `der://ev/VIN001` |
| `BATTERY` | `der://battery/<serial>` | `der://battery/BAT001` |
| `SOLAR_PV` | `der://solar/<serial>` | `der://solar/PV001` |
| `SMART_HVAC` | `der://hvac/<serial>` | `der://hvac/HVAC001` |
| `SMART_WATER_HEATER` | `der://water-heater/<serial>` | `der://water-heater/WH001` |

The `<derType>` segment is the lowercased / hyphen-cased form of `derType`. Consumers MAY parse it; the canonical type is still `derType` on the object.

`der://meter/...` — grid-meter URIs in DEG today — is a separate (legacy) use of the `der://` namespace that pre-dates this schema. A future cleanup may split that into `meter://...` or `grid://meter/...`; out of scope here.

## Identity vs state

The DER class fixes **stable identity + rated dimensioning**:

```jsonc
{
  "derId": "der://ev/VIN001",
  "derType": "EV_CHARGER",
  "behindMeter": "der://meter/001",
  "make": "Tata",
  "model": "Nexon EV",
  "ratedPowerKw": 7.0,
  "energyCapacityKwh": 30.0,
  "telemetryProvider": "tata-evp-telematics",
  "derAttributes": {
    "vin": "MAT123456789012345",
    "chargingProtocol": "OCPP_2_0_1"
  }
}
```

It does NOT carry per-event state (current SOC, instantaneous power, GPS position at time T). That belongs in the [BecknTimeSeries](../../BecknTimeSeries/v1.0/) telemetry attached to the performance record. The DER provides the static frame; the timeseries provides the moving picture.

## Embedding pattern

Carrier schemas reference the DER class via `$ref`:

```yaml
# In the carrier schema's attributes.yaml
ders:
  type: array
  items:
    $ref: "https://schema.beckn.io/DER/v1.0#/components/schemas/DER"
  description: DERs enrolled in this contract.
```

A typical seller-side enrollment block on a demand-flex offer:

```jsonc
{
  "role": "seller",
  "participantId": "greenflex-agg",
  "inputs": {
    "plannedDemandChange": { "@type": "Quantity", "unitCode": "KWH", "unitQuantity": 150.0 },
    "participatingMeters": ["der://meter/001", "der://meter/002", "der://meter/003"],
    "ders": [
      { "derId": "der://ev/VIN001", "derType": "EV_CHARGER", "behindMeter": "der://meter/001", "make": "Tata", "model": "Nexon EV", "ratedPowerKw": 7.0, "energyCapacityKwh": 30.0, "telemetryProvider": "tata-evp-telematics" },
      { "derId": "der://ev/VIN002", "derType": "EV_CHARGER", "behindMeter": "der://meter/002", "make": "MG", "model": "ZS EV", "ratedPowerKw": 7.0, "energyCapacityKwh": 44.5, "telemetryProvider": "mg-imotion" }
    ],
    "reportDescriptors": [ /* … */ ]
  }
}
```

## Why this lives at the top of schema/

DER is a real-world energy concept, not a Beckn protocol construct, and is referenced by multiple domains in DEG (demand-flex offers, EV-charging services, P2P-trading enrollments, distribution-grid management). Lives at the top of `specification/schema/` so any DEG schema can `$ref`-embed it without reinventing the asset class.
