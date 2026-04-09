# EnergyGift — v0.3

> ⚠️ **Deprecated** — `EnergyGift` v0.3 is superseded by [`EnergyGift/v2.0`](../v2.0/). See [EnergyGift root README](../README.md) for details.

Gift parameters for P2P energy gifting — enables privacy-preserving discovery and secret-based claim verification.

Part of the [DEG Schema](../../../README.md) · [EnergyGift](../README.md)

## Files

| File | Description |
|------|-------------|
| [attributes.yaml](./attributes.yaml) | OpenAPI 3.1.1 schema definition for `EnergyGift` (extracted from `EnergyTrade/v0.3/`) |
| [context.jsonld](./context.jsonld) | JSON-LD context (namespace: `beckn:` → `EnergyTrade/v0.3/`) |
| [vocab.jsonld](./vocab.jsonld) | RDF vocabulary for `EnergyGift` terms |

## Properties

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `lookupHash` | `string` (hex64) | ✅ | SHA-256 hash of recipient's phone (E.164) for privacy-preserving catalog discovery |
| `claimVerifier` | `string` (hex64) | ✅ | SHA-256 hash of a shared secret; recipient proves ownership by presenting the pre-image |
| `expiresAt` | `string` (date-time, UTC) | ✅ | Gift expiration — after this time the offer is no longer claimable |

## Notes

This schema was originally defined as a component inside the combined `EnergyTrade/v0.3/attributes.yaml`.
It has been extracted here as a standalone versioned schema for reference and backward compatibility.
