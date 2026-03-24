# StorageProfileCredential v2.0

**Schema ID:** `https://schema.beckn.io/StorageProfileCredential/v2.0`

**Status:** Current

---

## Overview

`StorageProfileCredential` is a Verifiable Credential for battery/energy storage capability. It is a subclass of [`EnergyCredential`](../../EnergyCredential/v2.0/).

The credential subject captures storage asset attributes: capacity in kWh, power rating in kW, commissioning date, and optional storage technology type — enabling virtual power plant participation and demand response.

---

## Files

| File | Description |
|------|-------------|
| [`attributes.yaml`](./attributes.yaml) | JSON Schema 2020-12 — subclass of `EnergyCredential` |
| [`context.jsonld`](./context.jsonld) | JSON-LD context for StorageProfileCredential terms |
| [`vocab.jsonld`](./vocab.jsonld) | RDF vocabulary — class and property definitions |

---

## Inheritance

```
beckn:Credential
  └── deg:EnergyCredential
        └── deg:StorageProfileCredential  ← this schema
```

---

## credentialSubject Properties

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `id` | `string` (URI) | ✅ | DID of the customer |
| `consumerNumber` | `string` | ✅ | Consumer account number |
| `storageCapacityKWh` | `number` (0.1–10000) | ✅ | Storage capacity in kWh |
| `powerRatingKW` | `number` (0.1–10000) | ✅ | Charge/discharge power rating in kW |
| `commissioningDate` | `string` (date) | ✅ | Date storage system was activated |
| `fullName` | `string` | | Consumer name |
| `meterNumber` | `string` | | Meter serial number |
| `assetId` | `string` | | Storage asset unique ID |
| `storageType` | `string` enum | | `LithiumIon` \| `LeadAcid` \| `FlowBattery` \| `Other` |
