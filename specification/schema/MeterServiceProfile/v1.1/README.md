# MeterServiceProfile v1.1

**Schema ID:** `https://schema.nfh.global/MeterServiceProfile/v1.1`
**CIM:** `cim:UsagePoint` (IEC 61968-9)
**Status:** Current

---

## v1.1 changes

`sanctionedLoad`, `sanctionedExportLoad`, and `contractMaxDemand` are now `QuantitativeValue {value, unit}` (unit: `W | kW | MW`) instead of plain numbers with unit-suffixed names:

| v1.0 (scalar) | v1.1 (QuantitativeValue) |
|---|---|
| `sanctionedLoadKw` | `sanctionedLoad` |
| `sanctionedExportLoadKw` | `sanctionedExportLoad` |
| `contractMaxDemandKw` | `contractMaxDemand` |

Optional admin attribute added (non-breaking; optional):

| Field | Standard | Notes |
|---|---|---|
| `serviceStatus` | CIM `UsagePoint.status` (IEC 61968-9) | Lifecycle state of the service connection (the UsagePoint), not of the meter device. Values: `active` \| `suspended` \| `closed`. |

---

## Overview

`MeterServiceProfile` describes the tariff, regulatory load, and connection terms for a single electricity meter connection point. One profile per meter; linked via `meterId` to a `METER` entry in `customerProfile.energyResources[]`.

Carried in `ElectricityCredential/v1.2` as `consumptionProfiles[]`.

---

## Files

| File | Description |
|------|-------------|
| [`attributes.yaml`](./attributes.yaml) | OpenAPI 3.1.1 schema |
| [`schema.json`](./schema.json) | JSON Schema 2020-12 (bundled) |
| [`context.jsonld`](./context.jsonld) | JSON-LD 1.1 term → IRI mappings |
| [`vocab.jsonld`](./vocab.jsonld) | RDF vocabulary — class and property definitions |

---

## Fields

| Field | Required | Type | Description |
|-------|----------|------|-------------|
| `meterId` | ✅ | string | Matches `id` of a `METER` entry in `energyResources[]` |
| `sanctionedLoad` | ✅ | QuantitativeValue | Sanctioned import load. `unit: W\|kW\|MW` |
| `tariffCategoryCode` | ✅ | string | Utility-assigned tariff/billing category code |
| `sanctionedExportLoad` | — | QuantitativeValue | Sanctioned grid export limit. `unit: W\|kW\|MW` |
| `billingCycleDay` | — | integer 1–31 | Day of month the billing cycle resets |
| `contractMaxDemand` | — | QuantitativeValue | Contracted maximum demand. `unit: W\|kW\|MW` |
| `premisesType` | — | enum | `Residential`, `Commercial`, `Industrial`, `Agricultural` |
| `connectionType` | — | enum | `Single-phase` or `Three-phase` |
| `paymentMode` | — | enum | `POSTPAID` or `PREPAID` |
| `serviceStatus` | — | enum | `active`, `suspended`, `closed`. CIM `UsagePoint.status`. State of the connection, not of the meter device. |

---

## Minimal valid example

```json
{
  "meterId": "did:web:bescom.karnataka.gov.in:assets:meter:MET-001",
  "sanctionedLoad": {"value": 5, "unit": "kW"},
  "tariffCategoryCode": "LT-2A"
}
```

## Full example

```json
{
  "meterId": "did:web:bescom.karnataka.gov.in:assets:meter:MET-001",
  "sanctionedLoad": {"value": 5, "unit": "kW"},
  "sanctionedExportLoad": {"value": 3, "unit": "kW"},
  "billingCycleDay": 1,
  "contractMaxDemand": {"value": 5, "unit": "kW"},
  "tariffCategoryCode": "LT-2A",
  "premisesType": "Residential",
  "connectionType": "Single-phase",
  "paymentMode": "POSTPAID",
  "serviceStatus": "active"
}
```
