# ElectricityCredential v1.1

W3C Verifiable Credential (VC Data Model 2.0) issued per meter by electricity distribution utilities.

## Structure

```
credentialSubject
├── id                         (optional — customer DID)
├── customerProfile            (required — non-PII; shareable without customerDetails)
│   ├── customerNumber         (required — CA number)
│   ├── idRef                  (optional — external identity reference)
│   ├── energyResources[]      (required — all physical assets, min 1)
│   │   ├── METER              (grid connection point; resourceId = meter serial number)
│   │   ├── SOLAR / WIND / …   (generation DERs; parentResources → meter)
│   │   └── BATTERY / BESS / … (storage DERs; parentResources → meter)
│   └── consumptionProfiles[]  (optional — tariff/load per meter, linked via meterId)
└── customerDetails            (optional — PII)
    ├── fullName               (PII — only here, never in energyResources)
    ├── installationAddress
    └── serviceConnectionDate
```

## Multiple topologies

A single `customerNumber` can span arbitrary asset topologies. Examples:

**Single meter, one DER:**
```json
"energyResources": [
  {"resourceId": "MET001", "resourceType": "METER", ...},
  {"resourceId": "der://solar/PV001", "resourceType": "SOLAR", "parentResources": ["MET001"]}
]
```

**Two meters at different premises:**
```json
"energyResources": [
  {"resourceId": "MET001", "resourceType": "METER", "resourceAttributes": {"meterType": "AMI", ...}},
  {"resourceId": "MET002", "resourceType": "METER", "resourceAttributes": {"meterType": "NetMeter", ...}},
  {"resourceId": "der://solar/PV001", "resourceType": "SOLAR", "parentResources": ["MET001"]},
  {"resourceId": "der://battery/BAT001", "resourceType": "BATTERY", "parentResources": ["MET002"]}
],
"consumptionProfiles": [
  {"meterId": "MET001", "sanctionedLoadKW": 5, "tariffCategoryCode": "RES-01"},
  {"meterId": "MET002", "sanctionedLoadKW": 20, "tariffCategoryCode": "COM-03"}
]
```

## customerProfile fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `customerNumber` | string | Yes | Utility CA number |
| `idRef` | object | No | External identity linkage (`issuedBy` DID + `subjectId`) |
| `energyResources` | array | Yes | EnergyResource/v2.0 entries (min 1) |
| `consumptionProfiles` | array | No | Tariff/load profiles, one per meter |

## energyResources entries

Each entry follows [EnergyResource/v2.0](../../EnergyResource/v2.0/attributes.yaml).

For **METER** entries:
- `resourceId` = meter serial number (bare, no URI prefix)
- `resourceAttributes` conforms to [MeterAttributes](../../EnergyResource/v2.0/attributes.yaml) — all fields optional: `meterType`, `gps`, `location`, `feeder`, `bus`

For **DER** entries (SOLAR, WIND, BATTERY, …):
- `parentResources[]` lists the meter serial number(s) this DER sits behind
- `ratedPowerKw`, `make`, `model` from the EnergyResource base class
- Type-specific fields in `resourceAttributes` (e.g., `commissioningDate`, `storageType`)

## ConsumptionProfile

Administrative tariff and load data for a meter connection. Kept separate from `MeterAttributes` because tariff data is regulatory and changes independently of physical assets.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `meterId` | string | Yes | Meter serial number — matches `resourceId` of a METER in `energyResources[]` |
| `sanctionedLoadKW` | number | Yes | Utility-approved load in kW |
| `tariffCategoryCode` | string | Yes | Utility billing/tariff category code |
| `premisesType` | enum | No | Residential, Commercial, Industrial, Agricultural |
| `connectionType` | enum | No | Single-phase, Three-phase |

## customerDetails (PII)

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `fullName` | string | Yes | Full name as per ID proof — **only here** |
| `installationAddress` | object | Yes | Beckn Location shape |
| `serviceConnectionDate` | date-time | Yes | Connection activation date (with timezone) |

## Minimal valid credential

```json
{
  "@context": ["https://www.w3.org/ns/credentials/v2", "https://schema.beckn.io/ElectricityCredential/v1.1/context.jsonld"],
  "id": "urn:uuid:…",
  "type": ["VerifiableCredential", "ElectricityCredential"],
  "issuer": {"id": "did:web:bescom.karnataka.gov.in", "name": "BESCOM"},
  "validFrom": "2025-01-13T10:30:00+05:30",
  "credentialSubject": {
    "customerProfile": {
      "customerNumber": "UTIL-2025-001234567",
      "energyResources": [
        {"resourceId": "MET2025789456123", "resourceType": "METER"}
      ]
    }
  }
}
```

## v1.0 → v1.1 migration

| v1.0 field | v1.1 location |
|------------|---------------|
| `customerProfile.meterNumber` | `energyResources[METER].resourceId` |
| `customerProfile.meterType` | `energyResources[METER].resourceAttributes.meterType` |
| `consumptionProfiles[].sanctionedLoadKW` | `consumptionProfiles[].sanctionedLoadKW` |
| `consumptionProfiles[].tariffCategoryCode` | `consumptionProfiles[].tariffCategoryCode` |
| `consumptionProfiles[].premisesType` | `consumptionProfiles[].premisesType` |
| `consumptionProfiles[].connectionType` | `consumptionProfiles[].connectionType` |
| `generationProfiles[].assetId` | `energyResources[DER].resourceId` |
| `generationProfiles[].generationType` | `energyResources[DER].resourceType` (SOLAR, WIND, …) |
| `generationProfiles[].capacityKW` | `energyResources[DER].ratedPowerKw` |
| `generationProfiles[].manufacturer` | `energyResources[DER].make` |
| `generationProfiles[].modelNumber` | `energyResources[DER].model` |
| `storageProfiles[].storageCapacityKWh` | `energyResources[DER].energyCapacityKwh` |
| `storageProfiles[].powerRatingKW` | `energyResources[DER].ratedPowerKw` |
| `storageProfiles[].storageType` | `energyResources[DER].resourceAttributes.storageType` |
| `fullName` (in each profile entry) | `customerDetails.fullName` (once, PII section) |
| `consumerNumber` (in each profile entry) | `customerProfile.customerNumber` |

## Files

| File | Description |
|------|-------------|
| `attributes.yaml` | OpenAPI 3.1.1 schema |
| `schema.json` | Bundled JSON Schema (draft 2020-12) — self-contained |
| `context.jsonld` | JSON-LD context |
| `vocab.jsonld` | RDF vocabulary |
| `examples/example.json` | Full example: 1 meter + 2 generation + 2 storage DERs + 1 consumption profile |
