# MeterServiceProfile v1.0

**Schema ID:** `https://schema.nfh.global/MeterServiceProfile/v1.0`  
**CIM:** `cim:UsagePoint` (IEC 61968-9)  
**Status:** Current

---

## Overview

`MeterServiceProfile` describes the tariff, regulatory load, and connection terms for a single electricity meter connection point. One profile per meter; linked via `meterId` to a `METER` entry in `customerProfile.energyResources[]`.

Carried in `ElectricityCredential/v1.2` as `consumptionProfiles[]`. The former inline `ConsumptionProfile` schema is now an alias for this schema — backward compatibility is preserved.

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

| Field | Required | Type | CIM mapping | Description |
|-------|----------|------|-------------|-------------|
| `meterId` | ✅ | string | — | Matches `id` of a `METER` entry in `energyResources[]` |
| `sanctionedLoadKw` | ✅ | number ≥ 0.5, ≤ 10000 | `UsagePoint` connection limit | Sanctioned import load in kW |
| `tariffCategoryCode` | ✅ | string | `UsagePoint.serviceCategory` | Utility-assigned tariff/billing category code |
| `sanctionedExportLoadKw` | — | number ≥ 0 | — | Sanctioned grid export limit in kW |
| `billingCycleDay` | — | integer 1–31 | — | Day of month the billing cycle resets |
| `contractMaxDemandKw` | — | number ≥ 0 | — | Contracted maximum demand in kW |
| `premisesType` | — | enum | — | `Residential`, `Commercial`, `Industrial`, `Agricultural` |
| `connectionType` | — | enum | `UsagePoint.phaseCode` | `Single-phase` or `Three-phase` |
| `paymentMode` | — | enum | ESPI `AmiBillingReadyKind` (IEC 61968-9) | `POSTPAID` or `PREPAID` |

### Notes on `paymentMode`

Administrative attribute placed on the profile (not the meter) because it can change via firmware update without hardware replacement. Aligns with ESPI `AmiBillingReadyKind` on `UsagePoint`.

---

## CIM alignment

| Field | CIM class / attribute | IEC standard |
|---|---|---|
| `MeterServiceProfile` | `cim:UsagePoint` | IEC 61968-9 |
| `sanctionedLoadKw` | `UsagePoint` connection rating (ratedCurrent × voltage) | IEC 61968-9 |
| `tariffCategoryCode` | `UsagePoint.serviceCategory` | IEC 61968-9 |
| `connectionType` | `UsagePoint.phaseCode` | IEC 61968-9 |
| `paymentMode` | ESPI `AmiBillingReadyKind` | IEC 61968-9 / NAESB REQ.21 |

---

## Minimal valid example

```json
{
  "meterId": "did:web:bescom.karnataka.gov.in:assets:meter:MET-001",
  "sanctionedLoadKw": 5,
  "tariffCategoryCode": "LT-2A"
}
```

## Full example

```json
{
  "meterId": "did:web:bescom.karnataka.gov.in:assets:meter:MET-001",
  "sanctionedLoadKw": 5,
  "sanctionedExportLoadKw": 3,
  "billingCycleDay": 1,
  "contractMaxDemandKw": 5,
  "tariffCategoryCode": "LT-2A",
  "premisesType": "Residential",
  "connectionType": "Single-phase",
  "paymentMode": "POSTPAID"
}
```
