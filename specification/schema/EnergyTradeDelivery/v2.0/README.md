# EnergyTradeDelivery — v2.0

Fulfillment attributes for P2P energy trade deliveries — tracks delivery status, time-windowed meter readings, and curtailment data.

Part of the [DEG Schema](../../../specification/schema/) · [EnergyTradeDelivery](../README.md)

## Files

| File | Description |
|------|-------------|
| [attributes.yaml](./attributes.yaml) | JSON Schema 2020-12 definition for `EnergyTradeDelivery` |
| [context.jsonld](./context.jsonld) | JSON-LD context (namespace: `https://schema.beckn.io/deg/EnergyTradeDelivery/v2.0/`) |
| [vocab.jsonld](./vocab.jsonld) | RDF vocabulary for `EnergyTradeDelivery` terms |

## Properties

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `deliveryStatus` | `string` enum | | `PENDING` \| `IN_PROGRESS` \| `COMPLETED` \| `FAILED` |
| `deliveryMode` | `string` enum | | `EV_CHARGING` \| `BATTERY_SWAP` \| `V2G` \| `GRID_INJECTION` |
| `deliveredQuantity` | `number` (kWh) | | Total energy delivered so far |
| `meterReadings` | `array` | | Time-windowed readings: `beckn:timeWindow`, `consumedEnergy`, `producedEnergy`, `allocatedEnergy`, `unit` |
| `curtailedQuantity` | `number` (kWh) | | Energy curtailed from contracted amount |
| `curtailmentReason` | `string` enum | | `GRID_OUTAGE` \| `EMERGENCY` \| `CONGESTION` \| `MAINTENANCE` \| `OTHER` |
| `lastUpdated` | `string` (date-time UTC) | | Last update timestamp (`schema:dateModified`) |

## Changes from v0.3

- Extracted from combined `EnergyTrade/v0.3/attributes.yaml` into standalone schema
- Published as JSON Schema 2020-12 (was OpenAPI 3.1 component)
