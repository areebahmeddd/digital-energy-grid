# ElectricityCredential v1.2

W3C Verifiable Credential (VC Data Model 2.0) issued per meter by electricity distribution utilities.

v1.2 introduces a **composable EnergyResource hierarchy**: each entry in `energyResources[]` is now discriminated by `type` into one of five typed kinds, each with a typed `attributes` bag. `storageCapacityKwh` is restricted to the Storage kind only.

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

Each kind is also published as a **standalone reusable schema** in `specification/schema/<Kind>/v1.0/`.

| Kind | Standalone schema | type enum values | CIM class (IEC 61970/61968) |
|------|-------------------|------------------|-----------------------------|
| `EnergyResourceMeter` | `EnergyResourceMeter/v1.0` | `METER` | `cim:Meter` / `cim:EndDevice` (IEC 61968-9) |
| `EnergyResourceGenerator` | `EnergyResourceGenerator/v1.0` | `SOLAR_PV`, `WIND`, `HYDRO`, `BIOGAS`, `CHP`, `FUEL_CELL` | `cim:GeneratingUnit` subtypes (IEC 61970-302) |
| `EnergyResourceStorage` | `EnergyResourceStorage/v1.0` | `BESS` | `cim:BatteryUnit` (IEC 61970-302) |
| `EnergyResourceEVCharger` | `EnergyResourceEVCharger/v1.0` | `EV_CHARGER`, `EV_V2G` | `cim:ElectricVehicleChargingStation` (CIM17+) |
| `EnergyResourceInverter` | `EnergyResourceInverter/v1.0` | `INVERTER` | `cim:PowerElectronicsConnection` (IEC 61970-302) |
| `EnergyResourceLoad` | `EnergyResourceLoad/v1.0` | `SMART_HVAC`, `SMART_WATER_HEATER`, `CONTROLLABLE_LOAD` | `cim:EnergyConsumer` / `cim:ConformLoad` (IEC 61970-301) |
| `EnergyResourceNetwork` | `EnergyResourceNetwork/v1.0` | `DT`, `BUS`, `FEEDER`, `MICROGRID` | `cim:PowerTransformer`, `cim:BusbarSection`, `cim:Feeder`, `cim:Substation` (IEC 61970-301) |

**Deprecated type aliases** (still valid in v1.2 for backward compatibility):
- `SOLAR` → use `SOLAR_PV` (CIM: `cim:PhotovoltaicUnit`)
- `BATTERY` → use `BESS` (CIM: `cim:BatteryUnit`)

## EnergyResourceCommonAttributes

Inherited by all seven kinds via `allOf`. Does **not** include `storageCapacityKwh`.

| Field | Type | CIM alignment | Description |
|-------|------|---------------|-------------|
| `make` | string | — | Manufacturer name |
| `model` | string | — | Model number |
| `ratedPowerKw` | number ≥0 | `GeneratingUnit.maxOperatingP` | Nameplate peak power kW — kept for backward compatibility; prefer `maxExportKw` for new payloads |
| `maxImportKw` | number ≥0 | `PowerElectronicsConnection.maxP` (absorption) | Max power drawn from grid (absorbed/charged), kW. Always ≥0. For BESS: max charge rate. For EV_V2G: max charge rate. Omit or 0 for pure generators. |
| `maxExportKw` | number ≥0 | `GeneratingUnit.maxOperatingP` / `PowerElectronicsConnection.maxP` | Max operating power kW (nameplate in principal direction); supersedes `ratedPowerKw` |
| `telemetryProvider` | string | — | Vendor API / data-source for telemetry |
| `commissioningDate` | string (date-time) | — | ISO 8601 commissioning date-time |
| `location` | object | — | `geo` (GeoJSONGeometry, coordinates [lon, lat]) + optional `address` (PostalAddress) |

## Kind-specific attributes

### EnergyResourceMeter (type: `METER`)

`meterType` (flat enum) is replaced in v1.2 with four orthogonal fields matching IEC 61968-9 / ESPI NAESB REQ.21 semantics. Each field is independent — a single meter can be `AMI` + `Bidirectional` + `["ToU","NetMetering"]` simultaneously. Physical location (`location`) moved to `EnergyResourceCommonAttributes` in v1.2.

| Field | Type | CIM / standard alignment | Description |
|-------|------|--------------------------|-------------|
| `meterCapability` | enum | `AmiBillingReadyKind` (IEC 61968-9) | Communication/capability tier: `Electromechanical` · `CMRI` · `AMR` · `AMI` |
| `energyDirection` | enum | `FlowDirectionKind` (ESPI NAESB REQ.21) | `Forward` (default) · `Reverse` · `Bidirectional` · `Net` |
| `functions` | array of enum | `EndDeviceFunction[0..*]` (IEC 61968-9) | Bag of active capabilities: `ToU` · `NetMetering` · `MaxDemand` · `LoadControl` · `TamperDetection` · `PowerQuality` · `EventLogging` |
| `feeder` | string | — | Feeder identifier this meter is supplied from |
| `bus` | string | — | Busbar identifier |
| `communicationTechnology` | enum | — | Physical layer: `PLC` · `RF_Mesh` · `GPRS` · `NB-IoT` · `LoRa` · `ZigBee` · `Other` |
| `applicationProtocol` | enum | IEC 62056 / ANSI C12 | Application layer: `DLMS_COSEM` · `ANSI_C12_18` · `IEC_61850` · `Modbus` · `Other` |

`paymentMode` (`POSTPAID` \| `PREPAID`) is an administrative attribute and lives on `ConsumptionProfile`, not the meter (aligns with ESPI `UsagePoint.amiBillingReady`).

### EnergyResourceGenerator (type: `SOLAR_PV` | `WIND` | `HYDRO` | `BIOGAS` | `CHP` | `FUEL_CELL`)

| Field | Type | CIM alignment | Description |
|-------|------|---------------|-------------|
| `nominalPowerKw` | number | `GeneratingUnit.nominalP` | Nominal output power, kW (when distinct from peak) |
| `efficiency` | number (0–100) | — | Conversion efficiency, % |

### EnergyResourceStorage (type: `BESS`)

Stationary battery. `storageCapacityKwh` is exclusive to this kind. Discharge rate: `maxExportKw` (≥0). Charge rate: `maxImportKw` (≥0). Both in common attributes.

| Field | Type | CIM alignment | Description |
|-------|------|---------------|-------------|
| `storageCapacityKwh` | number | `BatteryUnit.ratedE` | **Storage-only** — rated energy capacity, kWh |
| `storageType` | enum | — | LithiumIon, LeadAcid, FlowBattery, NaS, NiCd, Flywheel, Other |
| `stateOfHealthPct` | number (0–100) | — | Battery SoH as % of original capacity |

### EnergyResourceEVCharger (type: `EV_CHARGER` | `EV_V2G`)

EV charging station (EVSE) — a **flexible load**, not a storage resource. The EV battery is storage; the EVSE is the charge/discharge interface. `EV_V2G` is a specialisation of `EV_CHARGER` with ISO 15118-20 / OCPP 2.1 BPT bidirectional capability. V2G discharge: `maxExportKw` (≥0). Charge rate: `maxImportKw` (≥0).

| Field | Type | Standard | Description |
|-------|------|----------|-------------|
| `connectorType` | enum | IEC 62196 / CCS | Type1, Type2, CCS1, CCS2, CHAdeMO, GB_T, NACS, Other |
| `controlProtocol` | enum | OCPP / ISO 15118 | OCPP_1.6, OCPP_2.0.1, OCPP_2.1, ISO_15118_2, ISO_15118_20, Other |
| `v2xProtocol` | enum | ISO 15118-20 | CHAdeMO_V2G, CCS_BPT, ISO_15118_20_AC_BPT, ISO_15118_20_DC_BPT, Other — present for EV_V2G only |

### EnergyResourceInverter (type: `INVERTER`)

Grid-connected power-electronics converter without a dedicated fuel source. Captures reactive-power and frequency-support capabilities per IEEE 1547-2018 and SunSpec DER Models 702–714. Use cases: standalone battery inverters, VPP aggregation points, grid-forming inverters for microgrid islanding.

| Field | Type | Standard | Description |
|-------|------|----------|-------------|
| `ratedApparentPowerKva` | number | SunSpec 702 `maxVA` | Rated apparent power, kVA |
| `maxReactivePowerKvar` | number | IEEE 1547 / SunSpec `maxVar` | Max reactive power injection (leading), kVAr |
| `minReactivePowerKvar` | number | SunSpec `maxVarNeg` | Max reactive power absorption (lagging); usually negative |
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
| `nominalVoltageKv` | number | `BaseVoltage.nominalVoltage` | Nominal voltage, kV |
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
  {"id": "ROOFTOP-101",  "type": "SOLAR_PV", "attributes": {"ratedPowerKw": 2},  "parentResources": ["MET-UNIT-101"]}
]
```

**Parallel metering** — import meter + export meter for solar FIT:
```json
"energyResources": [
  {"id": "MET-IMPORT", "type": "METER",    "attributes": {"meterCapability": "AMI", "energyDirection": "Forward"},  "parentResources": ["DEL-F08"]},
  {"id": "MET-EXPORT", "type": "METER",    "attributes": {"meterCapability": "AMI", "energyDirection": "Reverse"}},
  {"id": "SOLAR-001",  "type": "SOLAR_PV", "attributes": {"ratedPowerKw": 5},      "parentResources": ["MET-EXPORT"]}
],
"consumptionProfiles": [
  {"meterId": "MET-IMPORT", "sanctionedLoadKw": 10, "tariffCategoryCode": "DS-I"},
  {"meterId": "MET-EXPORT", "sanctionedLoadKw": 5,  "tariffCategoryCode": "FIT-SOLAR-01"}
]
```

**Storage with full attributes**:
```json
{"id": "BESS-001", "type": "BESS", "attributes": {"ratedPowerKw": 5, "storageCapacityKwh": 10, "storageType": "LithiumIon", "stateOfHealthPct": 95}, "parentResources": ["MET-001"]}
```

## ConsumptionProfile

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `meterId` | string | Yes | Matches `id` of a METER entry in `energyResources[]` |
| `sanctionedLoadKw` | number | Yes | Utility-approved load in kW |
| `sanctionedExportLoadKw` | number | No | Sanctioned/approved grid export limit in kW |
| `billingCycleDay` | integer (1–31) | No | Day of month on which the billing cycle resets |
| `contractMaxDemandKw` | number | No | Maximum demand contracted with the utility, kW |
| `tariffCategoryCode` | string | Yes | Billing/tariff category code |
| `premisesType` | enum | No | Residential, Commercial, Industrial, Agricultural |
| `connectionType` | enum | No | Single-phase, Three-phase |
| `paymentMode` | enum | No | POSTPAID, PREPAID — administrative; placed here (not on meter) per ESPI `UsagePoint.amiBillingReady` (IEC 61968-9) |

## customerDetails (PII)

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `fullName` | string | Yes | Full name — **only here** |
| `installationAddress` | object | Yes | Beckn Location shape |
| `serviceConnectionDate` | date-time | Yes | Connection activation date (with timezone) |

## Minimal valid credential

```json
{
  "@context": ["https://www.w3.org/ns/credentials/v2", "https://schema.beckn.io/ElectricityCredential/v1.2/context.jsonld"],
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

| Change | v1.1 | v1.2 |
|--------|------|------|
| Power fields extended | `attributes.ratedPowerKw` | `ratedPowerKw` retained; add `attributes.maxExportKw` (≥0, grid injection) and `attributes.maxImportKw` (≥0, grid absorption) |
| Storage capacity field renamed | `attributes.energyCapacityKwh` | `attributes.storageCapacityKwh` |
| EV kind separated from storage | `EnergyResourceStorage (EV_CHARGER, EV_V2G)` | new `EnergyResourceEVCharger` kind |
| Storage charge/discharge rates | `maxChargeRateKw`, `maxDischargeRateKw` on storage | `maxExportKw` (discharge, ≥0) and `maxImportKw` (charge, ≥0) in common attributes |
| SOLAR deprecated | `type: "SOLAR"` | `type: "SOLAR_PV"` (preferred) |
| BATTERY deprecated | `type: "BATTERY"` | `type: "BESS"` (preferred) |
| EnergyResource now typed | single flat schema | `oneOf` 7 composable kinds |
| storageCapacityKwh scope | on EnergyResourceCommonAttributes | exclusive to EnergyResourceStorage |
| New EV kind | — | `EnergyResourceEVCharger` with `connectorType`, `controlProtocol`, `v2xProtocol` |
| New inverter kind | — | `EnergyResourceInverter` with `ratedApparentPowerKva`, `rideThroughCategory`, `operatingMode`, `voltVarEnabled`, `freqDroopEnabled`, etc. |
| New generator fields | — | `nominalPowerKw`, `efficiency` |
| New meter fields | — | `communicationTechnology` |
| New network fields | — | `nominalVoltageKv`, `zone`, `substationId`, `feederCode` |
| New load fields | — | `controlProtocol`, `loadCategory` |

## Files

| File | Description |
|------|-------------|
| `attributes.yaml` | OpenAPI 3.1.1 schema with composable EnergyResource hierarchy |
| `schema.json` | Bundled JSON Schema (draft 2020-12) — self-contained |
| `context.jsonld` | JSON-LD context |
| `vocab.jsonld` | RDF vocabulary with CIM class alignments |
| `examples/example.json` | Single meter + SOLAR_PV + WIND + 2× BESS |
| `examples/example-submetering.json` | Building main meter + 2 tenant sub-meters + rooftop solar |
| `examples/example-parallel-metering.json` | Import meter + export meter (solar FIT) |
