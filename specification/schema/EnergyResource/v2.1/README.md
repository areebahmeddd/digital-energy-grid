# EnergyResource — v2.1

Canonical, technology-neutral class for any asset that produces, consumes, stores, or modulates energy. Used by P2P-trading, demand-flex, and `ElectricityCredential/v1.2` (`customerProfile.energyResources[]`).

Part of the [DEG Schema](../../) · [EnergyResource](../README.md)

## v2.1 changes

All power and capacity fields now use `QuantitativeValue {value, unit}` with short unit aliases (`W`, `kW`, `MW`, `kWh`, `MWh`, `kVA`, `MVA`, `kVAR`, `MVAR`, `V`, `kV`) mapped to QUDT IRIs via JSON-LD context.

| v2.0 (scalar) | v2.1 (QuantitativeValue) | unit enum |
|---|---|---|
| `ratedPowerKw` | `ratedPower` | `W \| kW \| MW` |
| `maxExportKw` | `maxExport` | `W \| kW \| MW` |
| `maxImportKw` | `maxImport` | `W \| kW \| MW` |
| `nominalPowerKw` | `nominalPower` | `W \| kW \| MW` |
| `storageCapacityKwh` | `storageCapacity` | `kWh \| MWh` |
| `ratedApparentPowerKva` | `ratedApparentPower` | `kVA \| MVA` |
| `maxReactivePowerKvar` / `minReactivePowerKvar` | `maxReactivePower` / `minReactivePower` | `kVAR \| MVAR` |
| `nominalVoltageKv` | `nominalVoltage` | `V \| kV` |

Inherits `EnergyResourceCommon/v1.1` (was v1.0 in v2.0).

## Files

| File | Description |
|------|-------------|
| [attributes.yaml](./attributes.yaml) | OpenAPI 3.1.1 — `EnergyResource` discriminated union and all typed kinds |
| [context.jsonld](./context.jsonld) | JSON-LD context |
| [vocab.jsonld](./vocab.jsonld) | RDF vocabulary |

## Architecture

`EnergyResource` is a discriminated union (`oneOf`) of seven typed kinds. Each kind does `allOf [EnergyResourceCommon]` and refines the `attributes` bag with kind-specific fields.

```
EnergyResourceCommonAttributes   ← attributes bag base (make, model, power, location…)
        ↑ allOf
EnergyResourceCommon             ← envelope (id, type, subResources, parentResources, attributes)
        ↑ allOf  (each kind)
EnergyResourceMeter        (METER)
EnergyResourceGenerator    (SOLAR_PV | WIND | HYDRO | BIOGAS | CHP | FUEL_CELL)
EnergyResourceStorage      (BESS)
EnergyResourceEVCharger    (EV_CHARGER | EV_V2G)
EnergyResourceInverter     (INVERTER)
EnergyResourceLoad         (SMART_HVAC | SMART_WATER_HEATER | CONTROLLABLE_LOAD)
EnergyResourceNetwork      (DT | BUS | FEEDER | MICROGRID)
        ↑ oneOf
EnergyResource
```

## Typed kinds

| Kind | `type` values | CIM alignment |
|------|--------------|---------------|
| `EnergyResourceMeter` | `METER` | `Meter` / `EndDevice` (IEC 61968-9) |
| `EnergyResourceGenerator` | `SOLAR_PV`, `WIND`, `HYDRO`, `BIOGAS`, `CHP`, `FUEL_CELL` | `GeneratingUnit` subtypes (IEC 61970-302) |
| `EnergyResourceStorage` | `BESS` | `BatteryUnit` (IEC 61970-302) |
| `EnergyResourceEVCharger` | `EV_CHARGER`, `EV_V2G` | `ElectricVehicleChargingStation` (CIM17+) |
| `EnergyResourceInverter` | `INVERTER` | `PowerElectronicsConnection` (IEC 61970-302) |
| `EnergyResourceLoad` | `SMART_HVAC`, `SMART_WATER_HEATER`, `CONTROLLABLE_LOAD` | `EnergyConsumer` / `ConformLoad` (IEC 61970-301) |
| `EnergyResourceNetwork` | `DT`, `BUS`, `FEEDER`, `MICROGRID` | `PowerTransformer`, `BusbarSection`, `Feeder` (IEC 61970-301) |

Deprecated values still accepted: `SOLAR` → use `SOLAR_PV`; `BATTERY` → use `BESS`.

## Envelope fields (EnergyResourceCommon)

| Field | Type | Notes |
|-------|------|-------|
| `id` | string | Stable identifier; meter serial for METER |
| `type` | string enum | Discriminator — see table above |
| `subResources` | array | Child ids (string) or inline `EnergyResource` objects |
| `parentResources` | array of strings | FK refs to parent resources |
| `attributes` | object | `EnergyResourceCommonAttributes` + kind-specific fields |

## Common attributes (EnergyResourceCommonAttributes)

All live inside the `attributes` bag. No field is required at the schema level.

| Field | Type | Notes |
|-------|------|-------|
| `make` | string | Manufacturer |
| `model` | string | Model |
| `ratedPower` | QuantitativeValue | Backward compat; prefer `maxExport`. `unit: W\|kW\|MW` |
| `maxExport` | QuantitativeValue | Max power injected to grid (generation / discharge). `unit: W\|kW\|MW` |
| `maxImport` | QuantitativeValue | Max power drawn from grid (load / charge). `unit: W\|kW\|MW` |
| `telemetryProvider` | string | Vendor API / data source |
| `commissioningDate` | string (date-time) | ISO 8601 |
| `location` | object | `geo` (GeoJSON, coordinates [lon, lat]) + optional `address` |

## Kind-specific attributes

### EnergyResourceMeter

| Field | Type | Notes |
|-------|------|-------|
| `meterCapability` | enum | `Electromechanical` · `CMRI` · `AMR` · `AMI` |
| `energyDirection` | enum | `Forward` (default) · `Reverse` · `Bidirectional` · `Net` |
| `functions` | string[] | `ToU`, `NetMetering`, `MaxDemand`, `LoadControl`, `TamperDetection`, `PowerQuality`, `EventLogging` |
| `feeder` | string | Feeder ID |
| `bus` | string | Busbar ID |
| `communicationTechnology` | enum | `PLC`, `RF_Mesh`, `GPRS`, `NB-IoT`, `LoRa`, `ZigBee`, `Other` |
| `applicationProtocol` | enum | `DLMS_COSEM`, `ANSI_C12_18`, `IEC_61850`, `Modbus`, `Other` |

### EnergyResourceGenerator

| Field | Type | Notes |
|-------|------|-------|
| `nominalPower` | QuantitativeValue | Nominal rated output. `unit: W\|kW\|MW`. CIM: `GeneratingUnit.nominalP` |
| `efficiency` | number 0–100 | Conversion efficiency %; relevant for FUEL_CELL, CHP |

### EnergyResourceStorage

| Field | Type | Notes |
|-------|------|-------|
| `storageCapacity` | QuantitativeValue | Rated energy capacity. `unit: kWh\|MWh`. CIM: `BatteryUnit.ratedE` |
| `storageType` | enum | `LithiumIon` · `LeadAcid` · `FlowBattery` · `NaS` · `NiCd` · `Flywheel` · `Other` |
| `stateOfHealthPct` | number 0–100 | State of health as % of original capacity |

### EnergyResourceEVCharger

| Field | Type | Notes |
|-------|------|-------|
| `connectorType` | enum | `Type1`, `Type2`, `CCS1`, `CCS2`, `CHAdeMO`, `GB_T`, `NACS`, `Other` |
| `controlProtocol` | enum | `OCPP_1.6`, `OCPP_2.0.1`, `OCPP_2.1`, `ISO_15118_2`, `ISO_15118_20`, `Other` |
| `v2xProtocol` | enum | `CHAdeMO_V2G`, `CCS_BPT`, `ISO_15118_20_AC_BPT`, `ISO_15118_20_DC_BPT`, `Other` — EV_V2G only |

### EnergyResourceInverter

| Field | Type | Notes |
|-------|------|-------|
| `ratedApparentPower` | QuantitativeValue | Rated apparent power. `unit: kVA\|MVA`. SunSpec 702 `maxVA` |
| `maxReactivePower` | QuantitativeValue | Max reactive injection (leading). `unit: kVAR\|MVAR`. SunSpec 702 `maxVar` |
| `minReactivePower` | QuantitativeValue | Max reactive absorption (lagging). `unit: kVAR\|MVAR`. Value typically negative |
| `rideThroughCategory` | enum | `CategoryI` / `CategoryII` / `CategoryIII` (IEEE 1547-2018) |
| `operatingMode` | enum | `GridFollowing` / `GridForming` / `Standby` |
| `voltVarEnabled` | boolean | Volt-VAr curve active |
| `freqDroopEnabled` | boolean | Frequency-Watt droop active |
| `enterServiceRampTimeSec` | number ≥0 | Ramp-up time after reconnect, seconds |

### EnergyResourceLoad

| Field | Type | Notes |
|-------|------|-------|
| `controlProtocol` | enum | `OpenADR_2.0b`, `OCPP_2.0.1`, `SunSpec_Modbus`, `EEBus`, `Modbus`, `Other` |
| `loadCategory` | enum | `Heating`, `Cooling`, `WaterHeating`, `Lighting`, `EV`, `Industrial`, `Other` |

### EnergyResourceNetwork

| Field | Type | Notes |
|-------|------|-------|
| `nominalVoltage` | QuantitativeValue | Nominal voltage. `unit: V\|kV`. CIM: `BaseVoltage.nominalVoltage` |
| `zone` | string | Operating zone or region identifier |
| `substationId` | string | Parent substation identifier |
| `feederCode` | string | Feeder code per utility network records |

## Examples

**SOLAR DER behind a meter:**
```json
{
  "id": "did:web:utility.com:assets:solar:DER-SOLAR-001",
  "type": "SOLAR_PV",
  "attributes": {"maxExport": {"value": 5, "unit": "kW"}, "make": "Waaree", "model": "WS-400M"},
  "parentResources": ["did:web:utility.com:assets:meter:MET001"]
}
```

**BESS (5 kW / 10 kWh):**
```json
{
  "id": "did:web:utility.com:assets:bess:BESS-001",
  "type": "BESS",
  "attributes": {"maxExport": {"value": 5, "unit": "kW"}, "maxImport": {"value": 5, "unit": "kW"}, "storageCapacity": {"value": 10, "unit": "kWh"}},
  "parentResources": ["did:web:utility.com:assets:meter:MET001"]
}
```
