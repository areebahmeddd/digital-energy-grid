# EnergyOrderItem — v0.3

> ⚠️ **Deprecated** — `EnergyOrderItem` v0.3 is superseded by [`EnergyOrderItem/v2.0`](../v2.0/). See [EnergyOrderItem root README](../README.md) for details.

Order item wrapper for P2P energy trading — links provider attributes and optional fulfillment tracking data.

Part of the [DEG Schema](../../../README.md) · [EnergyOrderItem](../README.md)

## Files

| File | Description |
|------|-------------|
| [attributes.yaml](./attributes.yaml) | OpenAPI 3.1.1 schema definition for `EnergyOrderItem` (extracted from `EnergyTrade/v0.3/`) |
| [context.jsonld](./context.jsonld) | JSON-LD context (namespace: `beckn:` → `EnergyTrade/v0.3/`) |
| [vocab.jsonld](./vocab.jsonld) | RDF vocabulary for `EnergyOrderItem` terms |

## Properties

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `providerAttributes` | object (`@type: EnergyCustomer`) | ✅ | Provider/customer information including meter ID |
| `fulfillmentAttributes` | object (`@type: EnergyTradeDelivery`) | | Delivery status and meter readings (populated in `on_status`/`on_update` only) |

## Notes

This schema was originally defined as a component inside the combined `EnergyTrade/v0.3/attributes.yaml`.
It has been extracted here as a standalone versioned schema for reference and backward compatibility.
