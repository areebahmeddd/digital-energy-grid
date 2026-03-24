# EnergyTradeOffer

Offer attributes for P2P energy trading, specifying pricing model, availability windows, and optional gift parameters.

**Canonical IRI:** `https://schema.beckn.io/EnergyTradeOffer/v2.0`

**Namespace prefix:** `deg:` → `https://schema.beckn.io/deg/EnergyTradeOffer/v2.0/`

**Tags:** `energy-trade` · `p2p-trading` · `offer`

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
| `pricingModel` | `string` enum | ✅ | Pricing model classification: `PER_KWH`, `TIME_OF_DAY`, `SUBSCRIPTION`, `FIXED` |
| `validityWindow` | [TimePeriod](https://schema.beckn.io/TimePeriod/v2.0) | | Time window when this offer can be selected/accepted |
| `deliveryWindow` | [TimePeriod](https://schema.beckn.io/TimePeriod/v2.0) | | Actual time window when energy delivery occurs (UTC) |
| `gift` | [EnergyGift](https://schema.beckn.io/EnergyGift/v2.0) | | Optional gift parameters for energy gifting flows |

---

## Linked Data

| Term | IRI |
|------|-----|
| `EnergyTradeOffer` | `deg:EnergyTradeOffer` |
| `pricingModel` | `deg:pricingModel` |
| `validityWindow` | `deg:validityWindow` |
| `deliveryWindow` | `deg:deliveryWindow` |
| `gift` | `deg:gift` |
| `PER_KWH` | `deg:PricingModelPerKwh` |
| `TIME_OF_DAY` | `deg:PricingModelTimeOfDay` |
| `SUBSCRIPTION` | `deg:PricingModelSubscription` |
| `FIXED` | `deg:PricingModelFixed` |

---

## Usage

`EnergyTradeOffer` is attached to `Offer.offerAttributes` in P2P energy trading beckn flows.
The beckn `Offer.price` object holds the per-unit price; `price.applicableQuantity` specifies
the maximum energy quantity for the delivery window.
