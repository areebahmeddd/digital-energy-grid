# GenerationProfileCredential v2.0

**Schema ID:** `https://schema.beckn.io/GenerationProfileCredential/v2.0`

**Status:** Current

---

## Overview

`GenerationProfileCredential` is a Verifiable Credential for DER (Distributed Energy Resource) generation capability. It is a subclass of [`EnergyCredential`](../../EnergyCredential/v2.0/).

The credential subject captures generation asset attributes: type (Solar/Wind/MicroHydro/Other), installed capacity in kW, and commissioning date — enabling renewable energy tracking, net metering, and P2P trading eligibility as an energy seller.

---

## Files

| File | Description |
|------|-------------|
| [`attributes.yaml`](./attributes.yaml) | JSON Schema 2020-12 — subclass of `EnergyCredential` |
| [`context.jsonld`](./context.jsonld) | JSON-LD context for GenerationProfileCredential terms |
| [`vocab.jsonld`](./vocab.jsonld) | RDF vocabulary — class and property definitions |

---

## Inheritance

```
beckn:Credential
  └── deg:EnergyCredential
        └── deg:GenerationProfileCredential  ← this schema
```

---

## credentialSubject Properties

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `id` | `string` (URI) | ✅ | DID of the customer |
| `consumerNumber` | `string` | ✅ | Consumer account number |
| `generationType` | `string` enum | ✅ | `Solar` \| `Wind` \| `MicroHydro` \| `Other` |
| `capacityKW` | `number` (0.1–10000) | ✅ | Installed generation capacity in kW |
| `commissioningDate` | `string` (date) | ✅ | Date generation system was activated |
| `fullName` | `string` | | Consumer name |
| `meterNumber` | `string` | | Meter serial number |
| `assetId` | `string` | | Generation asset unique ID |
| `manufacturer` | `string` | | Equipment manufacturer |
| `modelNumber` | `string` | | Equipment model number |
