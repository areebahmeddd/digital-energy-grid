# CustomerDetails v1.0

**Schema ID:** `https://schema.beckn.io/CustomerDetails/v1.0`  
**CIM:** `cim:Customer` (IEC 61968-1)  
**Status:** Current

---

## Overview

`CustomerDetails` carries the PII identity and address details for a utility service customer. It is separated from the non-PII `CustomerProfile` to allow credential issuers to control PII disclosure independently.

Extracted from `ElectricityCredential/v1.2` `customerDetails` and published as a standalone reusable schema.

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

| Field | Required | Type | CIM | Description |
|-------|----------|------|-----|-------------|
| `fullName` | ✅ | string | `Customer.name` | Full name as per ID proof |
| `installationAddress` | ✅ | Location/2.0 | `ServiceLocation` | GeoJSON Point + PostalAddress |
| `serviceConnectionDate` | ✅ | date-time | activation date | ISO 8601 with timezone offset |

---

## CIM alignment

| Field | CIM class / attribute | IEC standard |
|---|---|---|
| `CustomerDetails` | `cim:Customer` | IEC 61968-1 |
| `installationAddress` | `cim:ServiceLocation` | IEC 61968-1 |
| `serviceConnectionDate` | service connection activation date | IEC 61968-1 |

---

## Example

```json
{
  "fullName": "Ravi Kumar",
  "installationAddress": {
    "geo": {
      "type": "Point",
      "coordinates": [77.5946, 12.9716]
    },
    "address": {
      "streetAddress": "12 MG Road",
      "addressLocality": "Bengaluru",
      "addressRegion": "Karnataka",
      "postalCode": "560001",
      "addressCountry": "IN"
    }
  },
  "serviceConnectionDate": "2019-03-15T10:00:00+05:30"
}
```
