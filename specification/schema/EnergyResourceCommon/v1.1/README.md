# EnergyResourceCommon v1.1

Canonical base schemas shared by all typed `EnergyResource` kinds.

**Canonical IRI:** `https://schema.beckn.io/EnergyResourceCommon/v1.1`

---

## v1.1 changes

Power dimensioning fields now use `QuantitativeValue {value, unit}` instead of plain numbers with unit-suffixed names:

| v1.0 (scalar) | v1.1 (QuantitativeValue) | unit enum |
|---|---|---|
| `ratedPowerKw` | `ratedPower` | `W \| kW \| MW` |
| `maxExportKw` | `maxExport` | `W \| kW \| MW` |
| `maxImportKw` | `maxImport` | `W \| kW \| MW` |

Unit aliases (`W`, `kW`, `MW`, `kWh`, `MWh`, `kVA`, `MVA`, `kVAR`, `MVAR`, `V`, `kV`) are defined in the JSON-LD context and mapped to QUDT IRIs.

---

## Schemas

### `EnergyResourceCommon`

The structural envelope inherited by every kind via `allOf`. Defines:

| Field | Type | Description |
|---|---|---|
| `id` | string | Stable asset identifier (IES DID convention) |
| `type` | string | Asset class discriminator — constrained to a kind-specific `enum` or `const` |
| `subResources` | array | Downward topology — child resource ids or inline EnergyResource objects |
| `parentResources` | array | Upward topology — ids of parent resources (string refs only) |
| `attributes` | object | Attribute bag — inherits `EnergyResourceCommonAttributes` via `allOf` |

### `EnergyResourceCommonAttributes`

The attribute bag base inherited inside every kind's `<Kind>Attributes` object via `allOf`. No field is required at this level.

| Field | Type | Description |
|---|---|---|
| `make` | string | Manufacturer (free text) |
| `model` | string | Model (free text) |
| `ratedPower` | QuantitativeValue | Nameplate power. Deprecated; prefer `maxExport` |
| `maxExport` | QuantitativeValue | Max power injected to grid (discharge / generation). `unit: W\|kW\|MW` |
| `maxImport` | QuantitativeValue | Max power drawn from grid (charge / load). `unit: W\|kW\|MW` |
| `telemetryProvider` | string | Vendor API / data-source identifier |
| `commissioningDate` | date-time | ISO 8601 asset commissioning date-time |
| `location` | object | beckn Location/2.0 shape — `geo` (GeoJSON, required) + `address` (postal, optional) |

---

## Inheritance pattern

**Kind envelope:**

```yaml
EnergyResourceMeter:
  allOf:
    - $ref: "https://schema.beckn.io/EnergyResourceCommon/v1.1#/components/schemas/EnergyResourceCommon"
    - type: object
      properties:
        type:
          const: "METER"
        attributes:
          $ref: "#/components/schemas/EnergyResourceMeterAttributes"
```

**Kind attributes bag:**

```yaml
EnergyResourceMeterAttributes:
  allOf:
    - $ref: "https://schema.beckn.io/EnergyResourceCommon/v1.1#/components/schemas/EnergyResourceCommonAttributes"
    - type: object
      additionalProperties: true
      properties:
        # Kind-specific fields only — common fields inherited above
        meterCapability: ...
```

---

## Kinds that inherit this schema

| Kind | Canonical IRI | Types |
|---|---|---|
| EnergyResourceMeter | `schema.beckn.io/EnergyResourceMeter/v1.1` | `METER` |
| EnergyResourceGenerator | `schema.beckn.io/EnergyResourceGenerator/v1.1` | `SOLAR_PV`, `WIND`, `HYDRO`, `BIOGAS`, `CHP`, `FUEL_CELL` |
| EnergyResourceStorage | `schema.beckn.io/EnergyResourceStorage/v1.1` | `BESS` |
| EnergyResourceEVCharger | `schema.beckn.io/EnergyResourceEVCharger/v1.1` | `EV_CHARGER`, `EV_V2G` |
| EnergyResourceInverter | `schema.beckn.io/EnergyResourceInverter/v1.1` | `INVERTER` |
| EnergyResourceLoad | `schema.beckn.io/EnergyResourceLoad/v1.1` | `SMART_HVAC`, `SMART_WATER_HEATER`, `CONTROLLABLE_LOAD` |
| EnergyResourceNetwork | `schema.beckn.io/EnergyResourceNetwork/v1.1` | `DT`, `BUS`, `FEEDER`, `MICROGRID` |
