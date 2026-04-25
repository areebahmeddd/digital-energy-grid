# EnergyTradeDelivery — v0.3

> ⚠️ **Deprecated** — `EnergyTradeDelivery` v0.3 is superseded by [`EnergyTradeDelivery/v2.0`](../v2.0/). See [EnergyTradeDelivery root README](../README.md) for details.

Fulfillment attributes for P2P energy trade deliveries — tracks delivery status, meter readings, and energy allocation.

Part of the [DEG Schema](../../../README.md) · [EnergyTradeDelivery](../README.md)

## Files

| File | Description |
|------|-------------|
| [attributes.yaml](./attributes.yaml) | OpenAPI 3.1.1 schema definition for `EnergyTradeDelivery` (extracted from `EnergyTrade/v0.3/`) |
| [context.jsonld](./context.jsonld) | JSON-LD context (namespace: `beckn:` → `EnergyTrade/v0.3/`) |
| [vocab.jsonld](./vocab.jsonld) | RDF vocabulary for `EnergyTradeDelivery` terms |

## Properties

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `deliveryStatus` | `string` enum | | `PENDING` \| `IN_PROGRESS` \| `COMPLETED` \| `FAILED` |
| `deliveryMode` | `string` enum | | `EV_CHARGING` \| `BATTERY_SWAP` \| `V2G` \| `GRID_INJECTION` |
| `deliveredQuantity` | `number` (kWh) | | Total energy delivered so far |
| `meterReadings` | `array` | | Time-windowed meter readings with consumed/produced/allocated energy |
| `curtailedQuantity` | `number` (kWh) | | Quantity curtailed from original contracted amount |
| `curtailmentReason` | `string` enum | | `GRID_OUTAGE` \| `EMERGENCY` \| `CONGESTION` \| `MAINTENANCE` \| `OTHER` |
| `lastUpdated` | `string` (date-time UTC) | | Last delivery update timestamp |

## Notes

This schema was originally defined as a component inside the combined `EnergyTrade/v0.3/attributes.yaml`.
It has been extracted here as a standalone versioned schema for reference and backward compatibility.
