# ElectricityCredential v1.2

W3C Verifiable Credential (VC Data Model 2.0) issued per meter by electricity distribution utilities.

v1.2 introduces a **composable EnergyResource hierarchy**: each entry in `energyResources[]` is discriminated by `type` into one of seven typed kinds, each with a typed `attributes` bag. All power and capacity fields use **QuantitativeValue `{value, unit}`** with short unit aliases (`kW`, `kWh`, `kVA`, `kVAR`, `kV`, `MW`, `MWh`, `MVA`, `MVAR`, `V`, `W`) mapped to QUDT IRIs via JSON-LD context.

## Structure

```
credentialSubject
├── id                         (optional — customer DID)
├── customerProfile            (required — non-PII)
│   ├── customerNumber         (required — CA number)
│   ├── idRef                  (optional — external identity reference)
│   ├── energyResources[]      (required — all physical assets, min 1)
│   │   ├── id                 (meter serial for METER; stable id for DERs)
│   │   ├── type               (discriminator — see kinds below)
│   │   ├── attributes         (kind-specific bag inheriting EnergyResourceCommonAttributes)
│   │   ├── subResources[]     (child resource ids or inline objects)
│   │   └── parentResources[]  (parent resource ids — e.g. the meter a DER sits behind)
│   └── consumptionProfiles[]  (optional — tariff/load per meter, linked via meterId)
└── customerDetails            (optional — PII)
    ├── fullName               (PII — only here)
    ├── installationAddress
    └── serviceConnectionDate
```

## EnergyResource kinds

Each kind is also published as a **standalone reusable schema** in `specification/schema/<Kind>/v1.1/`.

| Kind | Standalone schema | type enum values | CIM class (IEC 61970/61968) |
|------|-------------------|------------------|-----------------------------|
| `EnergyResourceMeter` | `EnergyResourceMeter/v1.1` | `METER` | `cim:Meter` / `cim:EndDevice` (IEC 61968-9) |
| `EnergyResourceGenerator` | `EnergyResourceGenerator/v1.1` | `SOLAR_PV`, `WIND`, `HYDRO`, `BIOGAS`, `CHP`, `FUEL_CELL` | `cim:GeneratingUnit` subtypes (IEC 61970-302) |
| `EnergyResourceStorage` | `EnergyResourceStorage/v1.1` | `BESS` | `cim:BatteryUnit` (IEC 61970-302) |
| `EnergyResourceEVCharger` | `EnergyResourceEVCharger/v1.1` | `EV_CHARGER`, `EV_V2G` | `cim:ElectricVehicleChargingStation` (CIM17+) |
| `EnergyResourceInverter` | `EnergyResourceInverter/v1.1` | `INVERTER` | `cim:PowerElectronicsConnection` (IEC 61970-302) |
| `EnergyResourceLoad` | `EnergyResourceLoad/v1.1` | `SMART_HVAC`, `SMART_WATER_HEATER`, `CONTROLLABLE_LOAD` | `cim:EnergyConsumer` / `cim:ConformLoad` (IEC 61970-301) |
| `EnergyResourceNetwork` | `EnergyResourceNetwork/v1.1` | `DT`, `BUS`, `FEEDER`, `MICROGRID` | `cim:PowerTransformer`, `cim:BusbarSection`, `cim:Feeder`, `cim:Substation` (IEC 61970-301) |

**Deprecated type aliases** (still valid in v1.2 for backward compatibility):
- `SOLAR` → use `SOLAR_PV` (CIM: `cim:PhotovoltaicUnit`)
- `BATTERY` → use `BESS` (CIM: `cim:BatteryUnit`)

## EnergyResourceCommonAttributes

Inherited by all seven kinds via `allOf`. All power fields are `QVPower {value, unit: W|kW|MW}`.

| Field | Type | CIM alignment / standard | Description |
|-------|------|--------------------------|-------------|
| `make` | string | — | Manufacturer name |
| `model` | string | — | Model number |
| `ratedPower` | QVPower | `GeneratingUnit.maxOperatingP` | Nameplate peak power — kept for backward compatibility; prefer `maxExport` |
| `maxExport` | QVPower | `GeneratingUnit.maxOperatingP` / `PowerElectronicsConnection.maxP` | Max power injected to grid (generates/discharges). Always ≥0. |
| `maxImport` | QVPower | `PowerElectronicsConnection.maxP` (absorption) | Max power drawn from grid (absorbs/charges). Always ≥0. |
| `telemetryProvider` | string | — | Vendor API / data-source for telemetry |
| `commissioningDate` | string (date-time) | — | ISO 8601 commissioning date-time |
| `location` | object | — | `geo` (GeoJSONGeometry, coordinates [lon, lat]) + optional `address` (PostalAddress) |
| `serialNumber` | string | `EndDeviceInfo.serialNumber` (IEC 61968-9) | Equipment-nameplate device serial; distinct from the network DID in `id`. |
| `inspection` | object | IEEE 1547-2018 Cl. 11; CEA Connectivity Regs 2013 | Commissioning / safety inspection record: `{date, result: pass\|fail\|conditional, inspectorId}`. |
| `aggregator` | object | IEEE 2030.5; IEC 61850-7-420 | Demand-flex enrolment block: `{id (URI), name, controllable (bool), enrolledOn (date)}`. `controllable: false` = observation-only. |

## Kind-specific attributes

### EnergyResourceMeter (type: `METER`)

| Field | Type | CIM / standard alignment | Description |
|-------|------|--------------------------|-------------|
| `meterCapability` | enum | `AmiBillingReadyKind` (IEC 61968-9) | `Electromechanical` · `CMRI` · `AMR` · `AMI` |
| `energyDirection` | enum | `FlowDirectionKind` (ESPI NAESB REQ.21) | `Forward` (default) · `Reverse` · `Bidirectional` · `Net` |
| `functions` | array of enum | `EndDeviceFunction[0..*]` (IEC 61968-9) | `ToU` · `NetMetering` · `MaxDemand` · `LoadControl` · `TamperDetection` · `PowerQuality` · `EventLogging` |
| `feeder` | string | — | Feeder identifier |
| `bus` | string | — | Busbar identifier |
| `communicationTechnology` | enum | — | `PLC` · `RF_Mesh` · `GPRS` · `NB-IoT` · `LoRa` · `ZigBee` · `Other` |
| `applicationProtocol` | enum | IEC 62056 / ANSI C12 | `DLMS_COSEM` · `ANSI_C12_18` · `IEC_61850` · `Modbus` · `Other` |

### EnergyResourceGenerator (type: `SOLAR_PV` | `WIND` | `HYDRO` | `BIOGAS` | `CHP` | `FUEL_CELL`)

| Field | Type | CIM alignment / standard | Description |
|-------|------|--------------------------|-------------|
| `nominalPower` | QVPower | `GeneratingUnit.nominalP` | Nominal output power, unit: W\|kW\|MW |
| `efficiency` | number (0–100) | — | Conversion efficiency, % |
| `dcArrayCapacity` | QVPower | IS 16221; IEC 61727 | DC-side PV array nameplate at STC (industry "kWp"). SOLAR_PV. Distinct from AC `maxExport`. Unit: W\|kW\|MW. |

### EnergyResourceStorage (type: `BESS`)

Stationary battery. `storageCapacity` is **exclusive to this kind**. Discharge rate: `maxExport`. Charge rate: `maxImport`. Both in common attributes.

| Field | Type | CIM alignment / standard | Description |
|-------|------|--------------------------|-------------|
| `storageCapacity` | QVEnergy | `BatteryUnit.ratedE` | **Storage-only** — rated energy capacity, unit: kWh\|MWh |
| `storageType` | enum | — | LithiumIon, LeadAcid, FlowBattery, NaS, NiCd, Flywheel, Other |
| `stateOfHealthPct` | number (0–100) | — | Battery SoH as % of original capacity |
| `roundTripEfficiencyPct` | number (0–100) | IEC 62933-2-1 | AC-to-AC round-trip efficiency over a full charge/discharge cycle |

### EnergyResourceEVCharger (type: `EV_CHARGER` | `EV_V2G`)

EV charging station (EVSE) — a **flexible load**, not a storage resource. `EV_V2G` adds ISO 15118-20 / OCPP 2.1 BPT bidirectional capability.

| Field | Type | Standard | Description |
|-------|------|----------|-------------|
| `connectorType` | enum | IEC 62196 / CCS | Type1, Type2, CCS1, CCS2, CHAdeMO, GB_T, NACS, Other |
| `controlProtocol` | enum | OCPP / ISO 15118 | OCPP_1.6, OCPP_2.0.1, OCPP_2.1, ISO_15118_2, ISO_15118_20, Other |
| `v2xProtocol` | enum | ISO 15118-20 | CHAdeMO_V2G, CCS_BPT, ISO_15118_20_AC_BPT, ISO_15118_20_DC_BPT, Other |

### EnergyResourceInverter (type: `INVERTER`)

Grid-connected power-electronics converter. IEEE 1547-2018 / SunSpec DER Models 702–714.

| Field | Type | Standard | Description |
|-------|------|----------|-------------|
| `ratedApparentPower` | QVApparentPower | SunSpec 702 `maxVA` | Rated apparent power, unit: kVA\|MVA |
| `maxReactivePower` | QVReactivePower | IEEE 1547 / SunSpec `maxVar` | Max reactive power injection (leading), unit: kVAR\|MVAR. Always ≥0. |
| `minReactivePower` | QVReactivePower | SunSpec `maxVarNeg` | Max reactive power absorption (lagging); value typically negative, unit: kVAR\|MVAR |
| `rideThroughCategory` | enum | IEEE 1547-2018 | CategoryI / CategoryII / CategoryIII |
| `operatingMode` | enum | CIM `inverterMode` | GridFollowing / GridForming / Standby |
| `voltVarEnabled` | boolean | IEEE 2030.5 `opModVoltVar` | Volt-VAr curve active |
| `freqDroopEnabled` | boolean | SunSpec Model 711 | Frequency-Watt droop active |
| `enterServiceRampTimeSec` | number | SunSpec 703 `ESRmpTms` | Ramp-up time after reconnect, seconds |

### EnergyResourceLoad (type: `SMART_HVAC` | `SMART_WATER_HEATER` | `CONTROLLABLE_LOAD`)

| Field | Type | Description |
|-------|------|-------------|
| `controlProtocol` | enum | OpenADR_2.0b, OCPP_2.0.1, SunSpec_Modbus, EEBus, Modbus, Other |
| `loadCategory` | enum | Heating, Cooling, WaterHeating, Lighting, EV, Industrial, Other |

### EnergyResourceNetwork (type: `DT` | `BUS` | `FEEDER` | `MICROGRID`)

| Field | Type | CIM alignment | Description |
|-------|------|---------------|-------------|
| `nominalVoltage` | QVVoltage | `BaseVoltage.nominalVoltage` | Nominal voltage, unit: V\|kV |
| `zone` | string | — | Operating zone / region identifier |
| `substationId` | string | — | Parent substation identifier |
| `feederCode` | string | — | Feeder code per utility records |

## Multiple topologies

A single `customerNumber` can span arbitrary asset topologies.

**Submetering** — building main meter + tenant sub-meters:
```json
"energyResources": [
  {"id": "MET-BLDG-001", "type": "METER",    "attributes": {"meterCapability": "AMI", "energyDirection": "Forward"}, "parentResources": ["BAN-NR-F22"]},
  {"id": "MET-UNIT-101", "type": "METER",    "attributes": {"meterCapability": "AMR", "energyDirection": "Forward"}, "parentResources": ["MET-BLDG-001"]},
  {"id": "MET-UNIT-102", "type": "METER",    "attributes": {"meterCapability": "AMR", "energyDirection": "Forward"}, "parentResources": ["MET-BLDG-001"]},
  {"id": "ROOFTOP-101",  "type": "SOLAR_PV", "attributes": {"maxExport": {"value": 2, "unit": "kW"}}, "parentResources": ["MET-UNIT-101"]}
]
```

**Parallel metering** — import meter + export meter for solar FIT:
```json
"energyResources": [
  {"id": "MET-IMPORT", "type": "METER",    "attributes": {"meterCapability": "AMI", "energyDirection": "Forward"}, "parentResources": ["DEL-F08"]},
  {"id": "MET-EXPORT", "type": "METER",    "attributes": {"meterCapability": "AMI", "energyDirection": "Reverse"}},
  {"id": "SOLAR-001",  "type": "SOLAR_PV", "attributes": {"maxExport": {"value": 5, "unit": "kW"}}, "parentResources": ["MET-EXPORT"]}
],
"consumptionProfiles": [
  {"meterId": "MET-IMPORT", "sanctionedLoad": {"value": 10, "unit": "kW"}, "tariffCategoryCode": "DS-I"},
  {"meterId": "MET-EXPORT", "sanctionedLoad": {"value": 5,  "unit": "kW"}, "tariffCategoryCode": "FIT-SOLAR-01"}
]
```

**Storage with full attributes**:
```json
{"id": "BESS-001", "type": "BESS", "attributes": {"maxExport": {"value": 5, "unit": "kW"}, "maxImport": {"value": 5, "unit": "kW"}, "storageCapacity": {"value": 10, "unit": "kWh"}, "storageType": "LithiumIon", "stateOfHealthPct": 95}, "parentResources": ["MET-001"]}
```

## ConsumptionProfile (MeterServiceProfile/v1.1)

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `meterId` | string | Yes | Matches `id` of a METER entry in `energyResources[]` |
| `sanctionedLoad` | QVPower | Yes | Utility-approved load, unit: W\|kW\|MW |
| `sanctionedExportLoad` | QVPower | No | Sanctioned grid export limit, unit: W\|kW\|MW |
| `billingCycleDay` | integer (1–31) | No | Day of month the billing cycle resets |
| `contractMaxDemand` | QVPower | No | Maximum demand contracted with the utility, unit: W\|kW\|MW |
| `tariffCategoryCode` | string | Yes | Billing/tariff category code |
| `premisesType` | enum | No | Residential, Commercial, Industrial, Agricultural |
| `connectionType` | enum | No | Single-phase, Three-phase |
| `paymentMode` | enum | No | POSTPAID, PREPAID |
| `serviceStatus` | enum | No | `active`, `suspended`, `closed`. CIM `UsagePoint.status`. Lifecycle state of the service connection, not of the meter device. |

## customerDetails (PII)

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `fullName` | string | Yes | Full name — **only here** |
| `installationAddress` | object | Yes | Beckn Location shape |
| `serviceConnectionDate` | date-time | Yes | Connection activation date (with timezone) |

## Minimal valid credential

```json
{
  "@context": ["https://www.w3.org/ns/credentials/v2", "https://schema.nfh.global/ElectricityCredential/v1.2/context.jsonld"],
  "id": "urn:uuid:…",
  "type": ["VerifiableCredential", "ElectricityCredential"],
  "issuer": {"id": "did:web:bescom.karnataka.gov.in", "name": "BESCOM"},
  "validFrom": "2025-01-13T10:30:00+05:30",
  "credentialSubject": {
    "customerProfile": {
      "customerNumber": "UTIL-2025-001234567",
      "energyResources": [
        {"id": "MET2025789456123", "type": "METER", "attributes": {"meterCapability": "AMI"}}
      ]
    }
  }
}
```

## v1.1 → v1.2 migration

| Change | v1.1 (scalar) | v1.2 (QuantitativeValue) |
|--------|---------------|--------------------------|
| Power fields | `ratedPowerKw`, `maxExportKw`, `maxImportKw` (number) | `ratedPower`, `maxExport`, `maxImport` (`{value, unit: W\|kW\|MW}`) |
| Generator nameplate | `nominalPowerKw` (number) | `nominalPower` (`{value, unit: W\|kW\|MW}`) |
| Storage capacity | `storageCapacityKwh` (number) | `storageCapacity` (`{value, unit: kWh\|MWh}`) |
| Apparent power | `ratedApparentPowerKva` (number) | `ratedApparentPower` (`{value, unit: kVA\|MVA}`) |
| Reactive power | `maxReactivePowerKvar`, `minReactivePowerKvar` (number) | `maxReactivePower`, `minReactivePower` (`{value, unit: kVAR\|MVAR}`) |
| Network voltage | `nominalVoltageKv` (number) | `nominalVoltage` (`{value, unit: V\|kV}`) |
| Tariff load | `sanctionedLoadKw`, `contractMaxDemandKw` (number) | `sanctionedLoad`, `contractMaxDemand` (`{value, unit: W\|kW\|MW}`) |
| Kind versions | `EnergyResource*/v1.0` | `EnergyResource*/v1.1` |
| EnergyResource version | `EnergyResource/v2.0` | `EnergyResource/v2.1` |

## Files

| File | Description |
|------|-------------|
| `attributes.yaml` | OpenAPI 3.1.1 schema with composable EnergyResource hierarchy |
| `schema.json` | Bundled JSON Schema (draft 2020-12) — self-contained |
| `context.jsonld` | JSON-LD context with unit aliases (kW→qudt:KiloW, kWh→qudt:KiloW-HR, etc.) |
| `vocab.jsonld` | RDF vocabulary with CIM class alignments |
| `examples/example.json` | Single meter + SOLAR_PV + WIND + 2× BESS |
| `examples/example-submetering.json` | Building main meter + 2 tenant sub-meters + rooftop solar |
| `examples/example-parallel-metering.json` | Import meter + export meter (solar FIT) |
