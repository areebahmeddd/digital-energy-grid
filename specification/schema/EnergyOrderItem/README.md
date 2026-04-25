# EnergyOrderItem

Order item wrapper for P2P energy trading — links provider attributes and optional fulfillment tracking data.

**Canonical IRI:** `https://schema.beckn.io/EnergyOrderItem/v2.0`

**Namespace prefix:** `deg:` → `https://schema.beckn.io/deg/EnergyOrderItem/v2.0/`

**Tags:** `energy-trade` · `p2p-trading` · `order-item`

---

## Versions

| Version | Status | Notes |
|---------|--------|-------|
| [v2.0](./v2.0/) | Current | Initial JSON Schema release, split from combined EnergyTrade schema |
| [v0.3](./v0.3/) | Deprecated | Original definition as a component in `EnergyTrade/v0.3/attributes.yaml` |

---

## Properties

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `providerAttributes` | object (`@type: EnergyCustomer`) | ✅ | Provider/customer information including meter ID |
| `fulfillmentAttributes` | object (`@type: EnergyTradeDelivery`) | | Delivery status and meter readings (populated in `on_status`/`on_update` only) |

---

## Linked Data

| Term | IRI |
|------|-----|
| `EnergyOrderItem` | `deg:EnergyOrderItem` |
| `providerAttributes` | `deg:providerAttributes` |
| `fulfillmentAttributes` | `deg:fulfillmentAttributes` |

---

## Usage

`EnergyOrderItem` is attached to `beckn:orderItemAttributes` in P2P energy trading flows.
`providerAttributes` embeds an [`EnergyCustomer`](../EnergyCustomer/) object.
`fulfillmentAttributes` embeds an [`EnergyTradeDelivery`](../EnergyTradeDelivery/) object —
only populated in `on_status` and `on_update` responses, not in `init`/`confirm` flows.
