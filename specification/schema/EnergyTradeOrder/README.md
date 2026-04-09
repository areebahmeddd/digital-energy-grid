# EnergyTradeOrder

Order attributes for P2P energy trading — identifies BAP/BPP participants and total contracted energy quantity.

**Canonical IRI:** `https://schema.beckn.io/EnergyTradeOrder/v0.3`

**Namespace prefix:** `beckn:` → `https://raw.githubusercontent.com/beckn/protocol-specifications-v2/refs/heads/main/schema/EnergyTrade/v0.3/#`

**Tags:** `energy-trade` · `p2p-trading` · `order`

---

## Versions

| Version | Status | Notes |
|---------|--------|-------|
| [v0.3](./v0.3/) | Current | Original definition as a component in `EnergyTrade/v0.3/attributes.yaml` |

---

## Properties

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `bap_id` | `string` | ✅ | Beckn Application Platform subscriber ID (buyer side) |
| `bpp_id` | `string` | ✅ | Beckn Provider Platform subscriber ID (seller side) |
| `total_quantity` | [Quantity](https://schema.beckn.io/Quantity/v2.0) | | Total energy quantity for the order (kWh) |

---

## Linked Data

| Term | IRI |
|------|-----|
| `EnergyTradeOrder` | `beckn:EnergyTradeOrder` |
| `bap_id` | `beckn:bap_id` |
| `bpp_id` | `beckn:bpp_id` |
| `total_quantity` | `beckn:total_quantity` |

---

## Usage

`EnergyTradeOrder` is attached to `Order.orderAttributes` in P2P energy trading beckn flows.
For inter-utility (inter-DISCOM) trades, buyer/seller utility IDs are captured separately in
`EnergyCustomer.utilityId` on the buyer and provider sides.
