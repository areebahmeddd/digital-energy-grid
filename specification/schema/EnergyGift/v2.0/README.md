# EnergyGift — v2.0

Gift parameters for P2P energy gifting via privacy-preserving discovery and shared-secret claim verification.

Part of the [DEG Schema](../../../specification/schema/) · [EnergyGift](../README.md)

## Files

| File | Description |
|------|-------------|
| [attributes.yaml](./attributes.yaml) | JSON Schema 2020-12 definition for `EnergyGift` |
| [context.jsonld](./context.jsonld) | JSON-LD context (namespace: `https://schema.beckn.io/deg/EnergyGift/v2.0/`) |
| [vocab.jsonld](./vocab.jsonld) | RDF vocabulary for `EnergyGift` terms |

## Properties

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `lookupHash` | `string` (64-char hex) | ✅ | SHA-256 of recipient phone (E.164) for catalog discovery |
| `claimVerifier` | `string` (64-char hex) | ✅ | SHA-256 of shared secret; recipient proves claim with pre-image |
| `expiresAt` | `string` (date-time UTC) | ✅ | Expiry — offer removed from catalog after this timestamp |

## Changes from v0.3

- Extracted from combined `EnergyTrade/v0.3/attributes.yaml` into standalone schema
- Published as JSON Schema 2020-12 (was OpenAPI 3.1 component)
