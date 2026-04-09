# ConsumptionProfileCredential v2.0

**Schema ID:** `https://schema.beckn.io/ConsumptionProfileCredential/v2.0`

**Status:** Current

---

## Overview

`ConsumptionProfileCredential` is a Verifiable Credential for electricity connection and consumption characteristics. It is a subclass of [`EnergyCredential`](../../EnergyCredential/v2.0/).

The credential subject captures connection-specific attributes: premises type, connection type, sanctioned load in kW, and tariff category code — enabling load management, demand response, and tariff determination.

---

## Files

| File | Description |
|------|-------------|
| [`attributes.yaml`](./attributes.yaml) | JSON Schema 2020-12 — subclass of `EnergyCredential` |
| [`context.jsonld`](./context.jsonld) | JSON-LD context for ConsumptionProfileCredential terms |
| [`vocab.jsonld`](./vocab.jsonld) | RDF vocabulary — class and property definitions |

---

## Inheritance

```
beckn:Credential
  └── deg:EnergyCredential
        └── deg:ConsumptionProfileCredential  ← this schema
```

---

## credentialSubject Properties

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `id` | `string` (URI) | ✅ | DID of the customer |
| `consumerNumber` | `string` | ✅ | Consumer account number |
| `fullName` | `string` | ✅ | Consumer name |
| `premisesType` | `string` enum | ✅ | `Residential` \| `Commercial` \| `Industrial` \| `Agricultural` |
| `connectionType` | `string` enum | ✅ | `Single-phase` \| `Three-phase` |
| `sanctionedLoadKW` | `number` (0.5–10000) | ✅ | Approved electrical load in kW |
| `tariffCategoryCode` | `string` | ✅ | Billing/tariff category code |
| `meterNumber` | `string` | | Meter serial number |
