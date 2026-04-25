# EnergyTradeDelivery

Fulfillment attributes for P2P energy trade deliveries — tracks delivery status, meter readings, and energy allocation.

**Canonical IRI:** `https://schema.beckn.io/EnergyTradeDelivery/v2.0`

**Namespace prefix:** `deg:` → `https://schema.beckn.io/deg/EnergyTradeDelivery/v2.0/`

**Tags:** `energy-trade` · `p2p-trading` · `fulfillment` · `delivery`

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
| `deliveryStatus` | `string` enum | | `PENDING` \| `IN_PROGRESS` \| `COMPLETED` \| `FAILED` |
| `deliveryMode` | `string` enum | | `EV_CHARGING` \| `BATTERY_SWAP` \| `V2G` \| `GRID_INJECTION` |
| `deliveredQuantity` | `number` (kWh) | | Total energy delivered so far |
| `meterReadings` | `array` | | Time-windowed meter readings with consumed/produced/allocated energy |
| `curtailedQuantity` | `number` (kWh) | | Quantity curtailed from original contracted amount |
| `curtailmentReason` | `string` enum | | `GRID_OUTAGE` \| `EMERGENCY` \| `CONGESTION` \| `MAINTENANCE` \| `OTHER` |
| `lastUpdated` | `string` (date-time UTC) | | Last delivery update timestamp |

---

## Linked Data

| Term | IRI |
|------|-----|
| `EnergyTradeDelivery` | `deg:EnergyTradeDelivery` |
| `deliveryStatus` | `deg:deliveryStatus` |
| `deliveryMode` | `deg:deliveryMode` |
| `deliveredQuantity` | `deg:deliveredQuantity` |
| `meterReadings` | `deg:meterReadings` |
| `consumedEnergy` | `deg:consumedEnergy` |
| `producedEnergy` | `deg:producedEnergy` |
| `allocatedEnergy` | `deg:allocatedEnergy` |
| `curtailedQuantity` | `deg:curtailedQuantity` |
| `curtailmentReason` | `deg:curtailmentReason` |
| `lastUpdated` | `schema:dateModified` |

---

## Usage

`EnergyTradeDelivery` is attached to `orderItemAttributes.fulfillmentAttributes` in P2P energy trading flows.
It is populated in `on_status` and `on_update` responses (not in `init`/`confirm` flows).

Energy direction convention: `consumedEnergy` = energy TO customer (IEC 61968 flowDirection=1);
`producedEnergy` = energy FROM customer to grid (IEC 61968 flowDirection=19).
