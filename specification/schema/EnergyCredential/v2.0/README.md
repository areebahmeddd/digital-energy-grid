# EnergyCredential v2.0

**Schema ID:** `https://schema.beckn.io/EnergyCredential/v2.0`

**Status:** Current

---

## Overview

`EnergyCredential` is the base class for all DEG energy-sector Verifiable Credentials. It is a subclass of `beckn:Credential` and adds common envelope properties shared by all DEG energy credentials:
- A structured `issuer` object with a regulatory `licenseNumber`
- `issuanceDate` and `expirationDate` timestamps
- `credentialStatus` using the DeDi registry for on-chain revocation
- A W3C-style `proof` object

All five DEG energy VC schemas (`ConsumptionProfileCredential`, `GenerationProfileCredential`, `StorageProfileCredential`, `ProgramEnrollmentCredential`, `UtilityCustomerCredential`) subclass `EnergyCredential`.

---

## Files

| File | Description |
|------|-------------|
| [`attributes.yaml`](./attributes.yaml) | JSON Schema 2020-12 — subclass of `beckn:Credential` |
| [`context.jsonld`](./context.jsonld) | JSON-LD context with `schema:`, `sec:`, `deg:` namespace mappings |
| [`vocab.jsonld`](./vocab.jsonld) | RDF vocabulary — class and property definitions |

---

## Inheritance

```
beckn:Credential
  └── deg:EnergyCredential  ← this schema
        ├── deg:ConsumptionProfileCredential
        ├── deg:GenerationProfileCredential
        ├── deg:StorageProfileCredential
        ├── deg:ProgramEnrollmentCredential
        └── deg:UtilityCustomerCredential
```

---

## Properties

| Property | Type | Required | Linked Data IRI |
|----------|------|----------|-----------------|
| `issuer` | `object` | | `schema:issuer` |
| `issuer.id` | `string` (URI) | ✅ | `@id` |
| `issuer.name` | `string` | ✅ | `schema:name` |
| `issuer.licenseNumber` | `string` | ✅ | `deg:licenseNumber` |
| `issuanceDate` | `string` (date-time) | | `schema:dateCreated` |
| `expirationDate` | `string` (date-time) | | `schema:expires` |
| `credentialStatus` | `object` | | `deg:credentialStatus` |
| `proof` | `object` | | `sec:proof` |
