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
| `EnergyResourceStorage` | `EnergyResourceStorage/v1.0` | `BESS`, `EV_CHARGER`, `EV_V2G` | `cim:BatteryUnit`, `cim:ElectricVehicleChargingStation` (IEC 61970-302) |
| `EnergyResourceLoad` | `EnergyResourceLoad/v1.0` | `SMART_HVAC`, `SMART_WATER_HEATER`, `CONTROLLABLE_LOAD` | `cim:EnergyConsumer` / `cim:ConformLoad` (IEC 61970-301) |
| `EnergyResourceNetwork` | `EnergyResourceNetwork/v1.0` | `DT`, `BUS`, `FEEDER`, `MICROGRID` | `cim:PowerTransformer`, `cim:BusbarSection`, `cim:Feeder`, `cim:Substation` (IEC 61970-301) |

**Deprecated type aliases** (still valid in v1.2 for backward compatibility):
- `SOLAR` → use `SOLAR_PV` (CIM: `cim:PhotovoltaicUnit`)
- `BATTERY` → use `BESS` (CIM: `cim:BatteryUnit`)

## EnergyResourceCommonAttributes

Inherited by all five kinds. Does **not** include `storageCapacityKwh`.

| Field | Type | CIM alignment | Description |
|-------|------|---------------|-------------|
| `make` | string | — | Manufacturer name |
| `model` | string | — | Model number |
| `ratedPowerKw` | number | `GeneratingUnit.maxOperatingP` | Nameplate peak power, kW |
| `telemetryProvider` | string | — | Vendor API / data-source for telemetry |
| `commissioningDate` | string | — | ISO 8601 commissioning date |
| `gps` | string | — | `"lat,lng"` coordinates |

## Kind-specific attributes

### EnergyResourceMeter (type: `METER`)

`meterType` (flat enum) is replaced in v1.2 with four orthogonal fields matching IEC 61968-9 / ESPI NAESB REQ.21 semantics. Each field is independent — a single meter can be `AMI` + `Bidirectional` + `["ToU","NetMetering"]` simultaneously.

| Field | Type | CIM / standard alignment | Description |
|-------|------|--------------------------|-------------|
| `meterCapability` | enum | `AmiBillingReadyKind` (IEC 61968-9) | Communication/capability tier: `Electromechanical` · `CMRI` · `AMR` · `AMI` |
| `energyDirection` | enum | `FlowDirectionKind` (ESPI NAESB REQ.21) | `Forward` (default) · `Reverse` · `Bidirectional` · `Net` |
| `functions` | array of enum | `EndDeviceFunction[0..*]` (IEC 61968-9) | Bag of active capabilities: `ToU` · `NetMetering` · `MaxDemand` · `LoadControl` · `TamperDetection` · `PowerQuality` · `EventLogging` |
| `feeder` | string | — | Feeder identifier this meter is supplied from |
| `bus` | string | — | Busbar identifier |
| `location` | object | beckn Location/2.0 | `geo` (GeoJSON Point) + `address` (PostalAddress) |
| `communicationTechnology` | enum | — | Physical layer: `PLC` · `RF_Mesh` · `GPRS` · `NB-IoT` · `LoRa` · `ZigBee` · `Other` |
| `applicationProtocol` | enum | IEC 62056 / ANSI C12 | Application layer: `DLMS_COSEM` · `ANSI_C12_18` · `IEC_61850` · `Modbus` · `Other` |

`billingMode` (`Postpaid` \| `Prepaid`) is an administrative attribute and lives on `ConsumptionProfile`, not the meter (aligns with ESPI `UsagePoint.amiBillingReady`).

### EnergyResourceGenerator (type: `SOLAR_PV` | `WIND` | `HYDRO` | `BIOGAS` | `CHP` | `FUEL_CELL`)

| Field | Type | CIM alignment | Description |
|-------|------|---------------|-------------|
| `nominalPowerKw` | number | `GeneratingUnit.nominalP` | Nominal output power, kW (when distinct from peak) |
| `efficiency` | number (0–100) | — | Conversion efficiency, % |

### EnergyResourceStorage (type: `BESS` | `EV_CHARGER` | `EV_V2G`)

| Field | Type | CIM alignment | Description |
|-------|------|---------------|-------------|
| `storageCapacityKwh` | number | `BatteryUnit.ratedE` | **Storage-only** — rated energy capacity, kWh |
| `storageType` | enum | — | LithiumIon, LeadAcid, FlowBattery, NaS, NiCd, Flywheel, Other |
| `stateOfHealthPct` | number (0–100) | — | Battery SoH as % of original capacity |
| `maxChargeRateKw` | number | — | Maximum charge rate, kW |
| `maxDischargeRateKw` | number | — | Maximum discharge rate, kW |

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
  {"meterId": "MET-IMPORT", "sanctionedLoadKW": 10, "tariffCategoryCode": "DS-I"},
  {"meterId": "MET-EXPORT", "sanctionedLoadKW": 5,  "tariffCategoryCode": "FIT-SOLAR-01"}
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
| `sanctionedLoadKW` | number | Yes | Utility-approved load in kW |
| `contractMaxDemandKw` | number | No | Maximum demand contracted with the utility, kW |
| `tariffCategoryCode` | string | Yes | Billing/tariff category code |
| `premisesType` | enum | No | Residential, Commercial, Industrial, Agricultural |
| `connectionType` | enum | No | Single-phase, Three-phase |
| `billingMode` | enum | No | Postpaid, Prepaid — administrative; placed here (not on meter) per ESPI `UsagePoint.amiBillingReady` (IEC 61968-9) |

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
| Storage capacity field renamed | `attributes.energyCapacityKwh` | `attributes.storageCapacityKwh` |
| SOLAR deprecated | `type: "SOLAR"` | `type: "SOLAR_PV"` (preferred) |
| BATTERY deprecated | `type: "BATTERY"` | `type: "BESS"` (preferred) |
| EnergyResource now typed | single flat schema | `oneOf` 5 composable kinds |
| storageCapacityKwh scope | on EnergyResourceCommonAttributes | exclusive to EnergyResourceStorage |
| New storage fields | — | `stateOfHealthPct`, `maxChargeRateKw`, `maxDischargeRateKw` |
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
