# EnergyTradeOffer — v0.3

> ⚠️ **Deprecated** — `EnergyTradeOffer` v0.3 is superseded by [`EnergyTradeOffer/v2.0`](../v2.0/). See [EnergyTradeOffer root README](../README.md) for details.

Offer attributes for P2P energy trading — pricing model, validity window, delivery window, and optional gift parameters.

Part of the [DEG Schema](../../../README.md) · [EnergyTradeOffer](../README.md)

## Files

| File | Description |
|------|-------------|
| [attributes.yaml](./attributes.yaml) | OpenAPI 3.1.1 schema definition for `EnergyTradeOffer` (extracted from `EnergyTrade/v0.3/`) |
| [context.jsonld](./context.jsonld) | JSON-LD context (namespace: `beckn:` → `EnergyTrade/v0.3/`) |
| [vocab.jsonld](./vocab.jsonld) | RDF vocabulary for `EnergyTradeOffer` terms |

## Properties

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `pricingModel` | `string` enum | ✅ | `PER_KWH` \| `TIME_OF_DAY` \| `SUBSCRIPTION` \| `FIXED` |
| `validityWindow` | TimePeriod | | Time window when this offer can be selected/accepted |
| `deliveryWindow` | TimePeriod | | Actual energy delivery time window (UTC, ISO 8601 with Z suffix required) |
| `gift` | EnergyGift | | Gift metadata for energy gifting flows (price = 0 on catalog) |

## Notes

This schema was originally defined as a component inside the combined `EnergyTrade/v0.3/attributes.yaml`.
It has been extracted here as a standalone versioned schema for reference and backward compatibility.
