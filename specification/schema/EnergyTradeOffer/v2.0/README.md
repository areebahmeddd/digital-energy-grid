# EnergyTradeOffer — v2.0

Offer attributes for P2P energy trading, specifying pricing model, validity window, delivery window, and optional gift parameters.

Part of the [DEG Schema](../../../specification/schema/) · [EnergyTradeOffer](../README.md)

## Files

| File | Description |
|------|-------------|
| [attributes.yaml](./attributes.yaml) | JSON Schema 2020-12 definition for `EnergyTradeOffer` |
| [context.jsonld](./context.jsonld) | JSON-LD context (namespace: `https://schema.beckn.io/deg/EnergyTradeOffer/v2.0/`) |
| [vocab.jsonld](./vocab.jsonld) | RDF vocabulary for `EnergyTradeOffer` terms |

## Properties

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `pricingModel` | `string` enum | ✅ | `PER_KWH` \| `TIME_OF_DAY` \| `SUBSCRIPTION` \| `FIXED` |
| `validityWindow` | [TimePeriod](https://schema.beckn.io/TimePeriod/v2.0) | | Time window when this offer can be selected/accepted |
| `deliveryWindow` | [TimePeriod](https://schema.beckn.io/TimePeriod/v2.0) | | Actual energy delivery time window (UTC, ISO 8601 with Z suffix required) |
| `gift` | [EnergyGift](https://schema.beckn.io/EnergyGift/v2.0) | | Gift metadata for energy gifting flows (price = 0 on catalog) |

## Changes from v0.3

- Extracted from combined `EnergyTrade/v0.3/attributes.yaml` into standalone schema
- Published as JSON Schema 2020-12 (was OpenAPI 3.1 component)
- External refs now use canonical `https://schema.beckn.io/` URIs
- `gift` property references `EnergyGift` as an independent canonical schema
