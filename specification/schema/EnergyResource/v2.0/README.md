# EnergyResource — v2.0

Canonical, technology-neutral class for any asset that produces, consumes, stores, or modulates energy. Used by **P2P-trading** (`{id, type}` for the asset being traded), **demand-flex** (identity + dimensioning + topology), and **ElectricityCredential/v1.2** (`customerProfile.energyResources[]`).

Part of the [DEG Schema](../../) · [EnergyResource](../README.md)

## Files

| File | Description |
|------|-------------|
| [attributes.yaml](./attributes.yaml) | OpenAPI 3.1.1 — `EnergyResource` discriminated union and all typed kinds |
| [context.jsonld](./context.jsonld) | JSON-LD context |
| [vocab.jsonld](./vocab.jsonld) | RDF vocabulary |

## Architecture

`EnergyResource` is a discriminated union (`oneOf`) of seven typed kinds. Each kind does `allOf [EnergyResourceCommon]` and refines the `attributes` bag with kind-specific fields. `make`, `model`, and all dimensioning fields live **inside the `attributes` bag**.

```
EnergyResourceCommonAttributes   ← attributes bag base (make, model, power, location…)
        ↑ allOf
EnergyResourceCommon             ← envelope (id, type, subResources, parentResources, attributes)
        ↑ allOf  (each kind)
EnergyResourceMeter        (METER)
EnergyResourceGenerator    (SOLAR_PV | WIND | HYDRO | BIOGAS | CHP | FUEL_CELL)
EnergyResourceBESS         (BESS)
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
| `EnergyResourceBESS` | `BESS` | `BatteryUnit` (IEC 61970-302) |
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

`subResources` uses a recursive `$ref: EnergyResource`, which is explicitly valid in JSON Schema 2020-12 and OpenAPI 3.1.

## Common attributes (EnergyResourceCommonAttributes)

All live inside the `attributes` bag. No field is required at the schema level.

| Field | Type | Notes |
|-------|------|-------|
| `make` | string | Manufacturer |
| `model` | string | Model |
| `ratedPowerKw` | number ≥0 | Backward compat; prefer `maxExportKw` |
| `maxExportKw` | number ≥0 | Max power injected to grid (generation / discharge). Always ≥0. Supersedes `ratedPowerKw`. CIM: `GeneratingUnit.maxOperatingP` |
| `maxImportKw` | number ≥0 | Max power drawn from grid (load / charge). Always ≥0. CIM: `PowerElectronicsConnection.maxP` (absorption) |
| `telemetryProvider` | string | Vendor API / data source |
| `commissioningDate` | string (date-time) | ISO 8601 |
| `location` | object | `geo` (GeoJSON, coordinates [lon, lat]) + optional `address` |

Power fields summary:

| Resource | `maxExportKw` | `maxImportKw` |
|----------|--------------|--------------|
| SOLAR_PV, WIND, HYDRO | peak generation | 0 or omit |
| BESS | max discharge rate | max charge rate |
| EV_CHARGER | 0 or omit | max charge rate |
| EV_V2G | max V2G discharge | max charge rate |
| INVERTER | max active power export | max active power import |
| SMART_HVAC, loads | 0 or omit | rated load draw |

## Kind-specific attributes

### EnergyResourceMeter

| Field | Type | Notes |
|-------|------|-------|
| `meterCapability` | enum | `Electromechanical` · `CMRI` · `AMR` · `AMI`. CIM: `AmiBillingReadyKind` |
| `energyDirection` | enum | `Forward` (default) · `Reverse` · `Bidirectional` · `Net`. CIM: `FlowDirectionKind` |
| `functions` | string[] | `ToU`, `NetMetering`, `MaxDemand`, `LoadControl`, `TamperDetection`, `PowerQuality`, `EventLogging` |
| `feeder` | string | Feeder ID |
| `bus` | string | Busbar ID |
| `communicationTechnology` | enum | `PLC`, `RF_Mesh`, `GPRS`, `NB-IoT`, `LoRa`, `ZigBee`, `Other` |
| `applicationProtocol` | enum | `DLMS_COSEM`, `ANSI_C12_18`, `IEC_61850`, `Modbus`, `Other` |

### EnergyResourceGenerator

| Field | Type | Notes |
|-------|------|-------|
| `nominalPowerKw` | number ≥0 | Nominal rated output (CIM: `GeneratingUnit.nominalP`) |
| `efficiency` | number 0–100 | Conversion efficiency %; relevant for FUEL_CELL, CHP |

### EnergyResourceBESS

| Field | Type | Notes |
|-------|------|-------|
| `storageCapacityKwh` | number ≥0 | Rated energy capacity kWh (exclusive to BESS). CIM: `BatteryUnit.ratedE` |
| `storageType` | enum | `LithiumIon` · `LeadAcid` · `FlowBattery` · `NaS` · `NiCd` · `Flywheel` · `Other` |
| `stateOfHealthPct` | number 0–100 | State of health as % of original capacity |

### EnergyResourceEVCharger

`EV_CHARGER` is the EVSE hardware at the grid connection point — a **flexible load**, not a storage resource. The EV battery is storage; use `BESS` for stationary batteries.

`EV_V2G` is a specialisation of `EV_CHARGER` with ISO 15118-20 / OCPP 2.1 BPT bidirectional capability. Set both `maxImportKw` (charge) and `maxExportKw` (V2G discharge) in the attributes bag.

| Field | Type | Notes |
|-------|------|-------|
| `connectorType` | enum | `Type1`, `Type2`, `CCS1`, `CCS2`, `CHAdeMO`, `GB_T`, `NACS`, `Other` (IEC 62196 / J3400) |
| `controlProtocol` | enum | `OCPP_1.6`, `OCPP_2.0.1`, `OCPP_2.1`, `ISO_15118_2`, `ISO_15118_20`, `Other` |
| `v2xProtocol` | enum | `CHAdeMO_V2G`, `CCS_BPT`, `ISO_15118_20_AC_BPT`, `ISO_15118_20_DC_BPT`, `Other` — present for EV_V2G |

### EnergyResourceInverter

Grid-connected power-electronics converter without a dedicated fuel source. Captures reactive-power and frequency-support capabilities per **IEEE 1547-2018** and **SunSpec DER Models 702–714**. Use cases: standalone battery inverters, VPP aggregation points, grid-forming inverters for microgrid islanding.

| Field | Type | Standard | Description |
|-------|------|----------|-------------|
| `ratedApparentPowerKva` | number ≥0 | SunSpec 702 `maxVA` | Rated apparent power, kVA |
| `maxReactivePowerKvar` | number ≥0 | SunSpec 702 `maxVar` | Max reactive injection (leading), kVAr |
| `minReactivePowerKvar` | number | SunSpec 702 `maxVarNeg` | Max reactive absorption (lagging); usually negative |
| `rideThroughCategory` | enum | IEEE 1547-2018 | `CategoryI` / `CategoryII` / `CategoryIII` |
| `operatingMode` | enum | CIM `inverterMode` | `GridFollowing` / `GridForming` / `Standby` |
| `voltVarEnabled` | boolean | IEEE 2030.5 `opModVoltVar` / SunSpec 705 | Volt-VAr curve active |
| `freqDroopEnabled` | boolean | SunSpec 711 / IEEE 1547 Freq-Watt | Frequency-Watt droop active |
| `enterServiceRampTimeSec` | number ≥0 | SunSpec 703 `ESRmpTms` | Ramp-up time after reconnect, seconds |

### EnergyResourceLoad

| Field | Type | Notes |
|-------|------|-------|
| `controlProtocol` | enum | `OpenADR_2.0b`, `OCPP_2.0.1`, `SunSpec_Modbus`, `EEBus`, `Modbus`, `Other` |
| `loadCategory` | enum | `Heating`, `Cooling`, `WaterHeating`, `Lighting`, `EV`, `Industrial`, `Other` |

### EnergyResourceNetwork

| Field | Type | Notes |
|-------|------|-------|
| `nominalVoltageKv` | number ≥0 | Nominal voltage, kV. CIM: `BaseVoltage.nominalVoltage` |
| `zone` | string | Operating zone or region identifier |
| `substationId` | string | Parent substation identifier |
| `feederCode` | string | Feeder code per utility network records |

## Topology

`parentResources` and `subResources` link resources by `id`. `subResources` items may be inline `EnergyResource` objects — the recursive `$ref` is valid in JSON Schema 2020-12. `parentResources` are always string references to avoid definitional cycles.

Typical patterns:
- DER behind a meter: DER `parentResources: [meterId]`
- Sub-meter: `parentResources: [buildingMeterId]`
- Parallel meters: both meters are siblings with no parent/child relationship
- Feeder topology: METER `parentResources: [feederId]`

## Examples

**METER:**
```json
{
  "id": "did:web:utility.com:assets:meter:MET001",
  "type": "METER",
  "attributes": {
    "meterCapability": "AMI",
    "energyDirection": "Forward",
    "location": {"geo": {"type": "Point", "coordinates": [77.5946, 12.9716]}}
  },
  "parentResources": ["did:web:utility.com:assets:feeder:BAN-NR-F22"]
}
```

**SOLAR DER behind a meter:**
```json
{
  "id": "did:web:utility.com:assets:solar:DER-SOLAR-001",
  "type": "SOLAR_PV",
  "attributes": {"maxExportKw": 5, "make": "Waaree", "model": "WS-400M", "commissioningDate": "2025-02-10T00:00:00+05:30"},
  "parentResources": ["did:web:utility.com:assets:meter:MET001"]
}
```

**BESS (5 kW charge / 5 kW discharge, 10 kWh):**
```json
{
  "id": "did:web:utility.com:assets:bess:BESS-001",
  "type": "BESS",
  "attributes": {"maxExportKw": 5, "maxImportKw": 5, "storageCapacityKwh": 10, "storageType": "LithiumIon"},
  "parentResources": ["did:web:utility.com:assets:meter:MET001"]
}
```

**EV_V2G charger (7.4 kW charge / 3.7 kW V2G discharge):**
```json
{
  "id": "did:web:utility.com:assets:evse:EVSE-001",
  "type": "EV_V2G",
  "attributes": {"maxImportKw": 7.4, "maxExportKw": 3.7, "connectorType": "Type2", "v2xProtocol": "ISO_15118_20_AC_BPT"},
  "parentResources": ["did:web:utility.com:assets:meter:MET001"]
}
```

**INVERTER (grid-forming, VAr + freq support):**
```json
{
  "id": "did:web:utility.com:assets:inv:INV-001",
  "type": "INVERTER",
  "attributes": {
    "maxExportKw": 10, "maxImportKw": 10,
    "ratedApparentPowerKva": 12, "maxReactivePowerKvar": 6,
    "operatingMode": "GridForming", "voltVarEnabled": true, "freqDroopEnabled": true,
    "rideThroughCategory": "CategoryIII"
  },
  "parentResources": ["did:web:utility.com:assets:meter:MET001"]
}
```

**P2P-trading (minimal):**
```json
{"id": "MET001", "type": "SOLAR_PV"}
```
