# UtilityCustomerCredential v2.0

**Schema ID:** `https://schema.beckn.io/UtilityCustomerCredential/v2.0`

**Status:** Current

---

## Overview

`UtilityCustomerCredential` is the barebones identity credential for utility customers. It is a subclass of [`EnergyCredential`](../../EnergyCredential/v2.0/).

The credential subject captures core identity attributes required for all DEG interactions: consumer number, full name, installation address, meter number, and service connection date. An optional masked government ID enables privacy-preserving verification.

All other DEG profile credentials (ConsumptionProfile, GenerationProfile, StorageProfile, ProgramEnrollment) link to this credential via the `credentialSubject.id` DID.

---

## Files

| File | Description |
|------|-------------|
| [`attributes.yaml`](./attributes.yaml) | JSON Schema 2020-12 — subclass of `EnergyCredential` |
| [`context.jsonld`](./context.jsonld) | JSON-LD context including nested `installationAddress` context |
| [`vocab.jsonld`](./vocab.jsonld) | RDF vocabulary — class and property definitions |

---

## Inheritance

```
beckn:Credential
  └── deg:EnergyCredential
        └── deg:UtilityCustomerCredential  ← this schema
```

---

## credentialSubject Properties

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `id` | `string` (URI) | ✅ | DID of the customer |
| `consumerNumber` | `string` | ✅ | Consumer account number |
| `fullName` | `string` | ✅ | Full name as per ID proof |
| `installationAddress` | `object` | ✅ | Installation address |
| `meterNumber` | `string` | ✅ | Unique meter serial number |
| `serviceConnectionDate` | `string` (date) | ✅ | Date connection was activated |
| `maskedIdNumber` | `string` | | Masked government ID |

### installationAddress

| Property | Required |
|----------|----------|
| `fullAddress` | ✅ |
| `postalCode` | ✅ |
| `country` (ISO 3166-1 alpha-2) | ✅ |
| `city` | |
| `district` | |
| `stateProvince` | |
