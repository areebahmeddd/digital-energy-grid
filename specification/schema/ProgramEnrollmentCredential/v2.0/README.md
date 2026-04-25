# ProgramEnrollmentCredential v2.0

**Schema ID:** `https://schema.beckn.io/ProgramEnrollmentCredential/v2.0`

**Status:** Current

---

## Overview

`ProgramEnrollmentCredential` is a Verifiable Credential for energy program enrollment. It is a subclass of [`EnergyCredential`](../../EnergyCredential/v2.0/).

The credential subject captures enrollment attributes: the specific program name and code, enrollment date, and optional expiry — enabling on-chain proof of eligibility for programs like P2P trading, demand flexibility, VPP, or time-of-use tariffs.

---

## Files

| File | Description |
|------|-------------|
| [`attributes.yaml`](./attributes.yaml) | JSON Schema 2020-12 — subclass of `EnergyCredential` |
| [`context.jsonld`](./context.jsonld) | JSON-LD context for ProgramEnrollmentCredential terms |
| [`vocab.jsonld`](./vocab.jsonld) | RDF vocabulary — class and property definitions |

---

## Inheritance

```
beckn:Credential
  └── deg:EnergyCredential
        └── deg:ProgramEnrollmentCredential  ← this schema
```

---

## credentialSubject Properties

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `id` | `string` (URI) | ✅ | DID of the consumer |
| `consumerNumber` | `string` | ✅ | Consumer account number |
| `programName` | `string` | ✅ | Human-readable program name |
| `programCode` | `string` | ✅ | Unique program identifier code |
| `enrollmentDate` | `string` (date) | ✅ | Date consumer enrolled in program |
| `fullName` | `string` | | Consumer name |
| `validUntil` | `string` (date) | | Enrollment expiration date |
