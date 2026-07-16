# CustomerProfile

> **Canonical IRI:** [`https://schema.nfh.global/EnergyCustomerProfile`](https://schema.nfh.global/EnergyCustomerProfile)
> **Tags:** `energy`, `identity`, `deg`
> **Namespace:** `https://schema.nfh.global/deg/`
> Part of the [DEG Specification](../../../README.md)

---

Core customer identity for energy credentials — links a utility account to a physical meter.

## Versions

| Version | attributes.yaml | context.jsonld | vocab.jsonld | README |
|---------|----------------|----------------|--------------|--------|
| **v1.0** | [attributes.yaml](./v1.0/attributes.yaml) | [context.jsonld](./v1.0/context.jsonld) | [vocab.jsonld](./v1.0/vocab.jsonld) | [README](./v1.0/README.md) |

## Properties (latest: v1.0)

| Property | Type | Required | Description |
|----------|------|:--------:|-------------|
| `customerNumber` | `string` | ✅ | Utility account number |
| `meterNumber` | `string` | ✅ | Unique meter serial number |
| `meterType` | `string` (enum) | ✅ | AMR, AMI, Electromechanical, Forward, Reverse, Bidirectional, Prepaid, NetMeter, Other |
| `idRef` | `object` | — | Identity reference: `issuedBy` (DID) + `subjectId` |

## Linked Data

| Resource | URL |
|----------|-----|
| Canonical IRI | `https://schema.nfh.global/EnergyCustomerProfile` |
| JSON Schema (latest) | `https://schema.nfh.global/EnergyCustomerProfile/v1.0` |
| context.jsonld (latest) | `https://schema.nfh.global/EnergyCustomerProfile/v1.0/context.jsonld` |
| vocab.jsonld (latest) | `https://schema.nfh.global/EnergyCustomerProfile/v1.0/vocab.jsonld` |
