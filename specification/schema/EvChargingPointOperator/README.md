# EvChargingPointOperator

> **Canonical IRI:** [`https://schema.beckn.io/EvChargingPointOperator`](https://schema.beckn.io/EvChargingPointOperator)
> **Tags:** `ev-charging, provider, operator, cpo, roaming, registry, energy, beckn`
> **Namespace:** `https://schema.beckn.io/`
> Part of the [DEG Schema](../../README.md)

---

**EV charging point operator attributes** attached to `Provider.attributes` in a Beckn EV-charging catalog. Captures operator identifiers, statutory registrations, roaming network membership, and extended contact details for the charging provider.

## Versions

| Version | attributes.yaml | context.jsonld | vocab.jsonld | README |
|---------|----------------|----------------|--------------|--------|
| **v1.0** | [attributes.yaml](./v1.0/attributes.yaml) | [context.jsonld](./v1.0/context.jsonld) | [vocab.jsonld](./v1.0/vocab.jsonld) | [README](./v1.0/README.md) |
| **v2.0** | [attributes.yaml](./v2.0/attributes.yaml) | [context.jsonld](./v2.0/context.jsonld) | [vocab.jsonld](./v2.0/vocab.jsonld) | [README](./v2.0/README.md) |

## Properties (latest: v2.0)

| Property | Type | Required | Description |
|----------|------|:--------:|-------------|
| `operatorName` | `string` | — | Operating company name (display). |
| `operatorCode` | `string` | — | Provider code as used in roaming/ops systems. |
| `identifier` | `string` | — | Provider identifier (URN/URL/code). |
| `sameAs` | `string` (uri) | — | Canonical reference (e.g., website, registry entry). |
| `supportEmail` | `string` (email) | — | Support email address. |
| `supportPhone` | `string` | — | Support phone number. |
| `gstNumber` | `string` | — | India GSTIN (if applicable). |
| `cin` | `string` | — | India CIN — corporate identification number. |
| `msme` | `string` | — | MSME/Udyam registration (if applicable). |
| `operatorContact` | `object` | — | Free-form contact blob for ops use. |

## Linked Data

| Resource | URL |
|----------|-----|
| Canonical IRI | `https://schema.beckn.io/EvChargingPointOperator` |
| JSON Schema (latest) | `https://schema.beckn.io/EvChargingPointOperator/v2.0` |
| context.jsonld (latest) | `https://schema.beckn.io/EvChargingPointOperator/v2.0/context.jsonld` |
| vocab.jsonld (latest) | `https://schema.beckn.io/EvChargingPointOperator/v2.0/vocab.jsonld` |
| Root context.jsonld | `https://schema.beckn.io/context.jsonld` |
| Root vocab.jsonld | `https://schema.beckn.io/vocab.jsonld` |
