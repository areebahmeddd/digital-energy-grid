# EnergyOrderItem — v2.0

Order item wrapper for P2P energy trading — provider attributes and optional fulfillment tracking.

Part of the [DEG Schema](../../../specification/schema/) · [EnergyOrderItem](../README.md)

## Files

| File | Description |
|------|-------------|
| [attributes.yaml](./attributes.yaml) | JSON Schema 2020-12 definition for `EnergyOrderItem` |
| [context.jsonld](./context.jsonld) | JSON-LD context (namespace: `https://schema.beckn.io/deg/EnergyOrderItem/v2.0/`) |
| [vocab.jsonld](./vocab.jsonld) | RDF vocabulary for `EnergyOrderItem` terms |

## Properties

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `providerAttributes` | object (`@type: EnergyCustomer`) | ✅ | Provider/customer info — meter ID and utility account |
| `fulfillmentAttributes` | object (`@type: EnergyTradeDelivery`) | | Delivery tracking — only in `on_status`/`on_update` responses |

## Changes from v0.3

- Extracted from combined `EnergyTrade/v0.3/attributes.yaml` into standalone schema
- Published as JSON Schema 2020-12 (was OpenAPI 3.1 component)
