# Meter Data Credential

A credential for historical time-series meter readings, enabling tamper-evident custody of interval data aligned with Green Button (ESPI/NAESB) semantics.

## Purpose

This credential captures historical interval meter readings for a single meter. It is:
- **Issued by** the distribution utility that owns the metering infrastructure
- **Held by** the customer (prosumer/consumer)
- **Presented to** trading apps, demand-response platforms, or forecasting services

Key use cases:
- Single-meter demand forecasting for P2P trading
- Verifiable consumption history for energy programs
- Portable meter data across utility boundaries

## Fields

### credentialSubject

| Field | Type | Required | Description | Green Button Source |
|-------|------|----------|-------------|---------------------|
| `id` | string (DID) | Yes | Customer DID (links to customer) | — |
| `consumerNumber` | string | Yes | Utility account number (links to customer record) | — |
| `meterNumber` | string | Yes | Meter serial number | — |
| `serviceKind` | enum | Yes | electricity / gas / water | `UsagePoint.ServiceKind` |
| `timeZone` | string | Yes | IANA time-zone (e.g., "Asia/Kolkata") | — |
| `readingType` | object | Yes | What is being measured | `MeterReading.ReadingType` |
| `coveragePeriod` | object | Yes | Summary date range of data | — |
| `intervalBlocks` | array | Yes | Blocks of interval readings | `IntervalBlock` |

### readingType

| Field | Type | Description | ESPI Element |
|-------|------|-------------|--------------|
| `commodity` | enum | Commodity being metered | `CommodityKind` |
| `flowDirection` | enum | forward / reverse / net | `FlowDirectionKind` |
| `uom` | enum | Unit of measure (Wh, kWh, W, kW, ...) | `UnitOfMeasure` |
| `powerOfTenMultiplier` | integer | Scale factor (0 = ×1, 3 = ×1000) | `UnitMultiplierKind` |
| `accumulationBehaviour` | enum | How values accumulate (deltaData, cumulative, ...) | `AccumulationBehaviourKind` |
| `intervalLength` | integer | Interval length in seconds (e.g., 900 = 15 min) | `intervalLength` |

### intervalBlocks[].intervalReadings[]

| Field | Type | Description | ESPI Element |
|-------|------|-------------|--------------|
| `timePeriod.start` | datetime | Start of reading interval (ISO 8601) | `DateTimeInterval.start` |
| `timePeriod.duration` | integer | Duration in seconds | `DateTimeInterval.duration` |
| `value` | integer | Raw reading value (scaled by powerOfTenMultiplier + uom) | `IntervalReading.value` |

## Interpreting Values

The raw `value` field is an integer. To compute the physical quantity:

```
physical_value = value × 10^powerOfTenMultiplier  [in units of uom]
```

**Example:** `value: 375`, `powerOfTenMultiplier: 0`, `uom: "Wh"` → 375 Wh consumed in that interval.

## Green Button Alignment

This credential uses human-readable string enum values instead of Green Button's integer codes. The mapping is documented in the Green Button reference schema at `external/schema/green-button/attributes.yaml`.

| JSON Property | Green Button Source | ESPI Element |
|---|---|---|
| `serviceKind` | UsagePoint.ServiceKind | `espi:ServiceKind` |
| `readingType` | MeterReading.ReadingType | `espi:ReadingType` |
| `commodity` | ReadingType.commodity | `espi:CommodityKind` |
| `flowDirection` | ReadingType.flowDirection | `espi:FlowDirectionKind` |
| `uom` | ReadingType.uom | `espi:UnitOfMeasure` |
| `powerOfTenMultiplier` | ReadingType.powerOfTenMultiplier | `espi:UnitMultiplierKind` |
| `accumulationBehaviour` | ReadingType.accumulationBehaviour | `espi:AccumulationBehaviourKind` |
| `intervalLength` | ReadingType.intervalLength | `espi:intervalLength` |
| `intervalBlocks` | IntervalBlock | `espi:IntervalBlock` |
| `intervalReadings` | IntervalReading | `espi:IntervalReading` |
| `timePeriod` | IntervalReading.timePeriod | `espi:DateTimeInterval` |
| `value` | IntervalReading.value | `espi:value` |

## Credential Linkage

This credential links to the Utility Customer Credential via the `credentialSubject.id` (customer DID), `consumerNumber` (utility account number), and `meterNumber` fields. A customer may have multiple Meter Data Credentials covering different time periods or meters.

## Files

- `attributes.yaml` - OpenAPI 3.1.1 schema definition
- `context.jsonld` - JSON-LD context for semantic interoperability
- `vocab.jsonld` - RDF vocabulary definitions
- `example.json` - Sample credential with 15-minute residential data
- `readme.md` - This documentation

## Usage

```json
{
  "@context": [
    "https://www.w3.org/2018/credentials/v1",
    "https://schema.org/",
    "https://nfh-trust-labs.github.io/vc-schemas/energy-credentials/meter-data-vc/context.jsonld"
  ],
  "type": ["VerifiableCredential", "MeterDataCredential"],
  "credentialSubject": {
    "id": "did:example:consumer:abc123",
    "consumerNumber": "UTIL-2025-001234567",
    "meterNumber": "MET2025789456123",
    "serviceKind": "electricity",
    "timeZone": "Asia/Kolkata",
    "readingType": {
      "commodity": "electricitySecondaryMetered",
      "flowDirection": "forward",
      "uom": "Wh",
      "powerOfTenMultiplier": 0,
      "accumulationBehaviour": "deltaData",
      "intervalLength": 900
    },
    "coveragePeriod": {
      "start": "2025-07-14T18:30:00Z",
      "end": "2025-07-14T19:30:00Z"
    },
    "intervalBlocks": [ ... ]
  }
}
```
