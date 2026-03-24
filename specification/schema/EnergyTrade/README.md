# EnergyTrade

> ⚠️ **Deprecated** — `EnergyTrade` is superseded by [`P2PTrade`](../P2PTrade/). Use `P2PTrade` for all new energy contract implementations on the DEG network.

> **Canonical IRI:** [`https://schema.beckn.io/EnergyTrade`](https://schema.beckn.io/EnergyTrade)
> **Tags:** `energy, p2p, trade, contract, prosumer, deg, beckn`
> **Namespace:** `https://schema.beckn.io/`
> Part of the [DEG Schema](../../README.md)

---

**P2P energy trade contract** — a subclass of [`Contract`](https://schema.beckn.io/Contract/v2.0) specialised for energy delivery between prosumers on a Digital Energy Grid (DEG) network. Represents the complete traded energy contract including offer terms, resource attributes, delivery tracking, and customer details.

> **Migration:** Replace `EnergyTrade` references with [`P2PTrade`](../P2PTrade/) and [`EnergyContract`](../EnergyContract/). Domain-specific attributes (offer, delivery, resource, customer) remain available via the companion schemas listed below.

Related domain schemas (split from the combined energy trade specification):

| Schema | Beckn Attachment Point | Description |
|--------|----------------------|-------------|
| [`EnergyTradeOffer`](../EnergyTradeOffer/README.md) | `Offer.offerAttributes` | Pricing model, validity/delivery windows, and optional gift parameters |
| [`EnergyGift`](../EnergyGift/README.md) | `EnergyTradeOffer.gift` | Gift energy — lookupHash, claim verifier, expiration |
| [`EnergyTradeOrder`](../EnergyTradeOrder/README.md) | `Order.orderAttributes` | Platform and utility identifiers for the trade order |
| [`EnergyTradeDelivery`](../EnergyTradeDelivery/README.md) | `orderItemAttributes.fulfillmentAttributes` | Real-time delivery tracking — status, meter readings, quantities |
| [`EnergyResource`](../EnergyResource/README.md) | `Item.itemAttributes` | Energy source characteristics (solar, wind, grid, etc.) |
| [`EnergyCustomer`](../EnergyCustomer/README.md) | `Buyer.buyerAttributes`, `Provider.providerAttributes` | Customer info: meterId, sanctionedLoad, utilityCustomerId |
| [`EnergyOrderItem`](../EnergyOrderItem/README.md) | `orderItemAttributes` | Order item wrapper combining resource, offer, and delivery |

## Versions

| Version | attributes.yaml | context.jsonld | vocab.jsonld | README | Status |
|---------|----------------|----------------|--------------|--------|--------|
| **v0.3** | [attributes.yaml](./v0.3/attributes.yaml) | [context.jsonld](./v0.3/context.jsonld) | [vocab.jsonld](./v0.3/vocab.jsonld) | [README](./v0.3/README.md) | ⚠️ Deprecated |
| **v2.0** | [attributes.yaml](./v2.0/attributes.yaml) | [context.jsonld](./v2.0/context.jsonld) | [vocab.jsonld](./v2.0/vocab.jsonld) | [README](./v2.0/README.md) | ⚠️ Deprecated · `owl:equivalentClass deg:P2PTrade` |

## Properties (latest: v2.0)

| Property | Type | Required | Description |
|----------|------|:--------:|-------------|
| `energyResource` | `EnergyResource` | — | Energy source characteristics for this trade. |
| `delivery` | `EnergyTradeDelivery` | — | Delivery tracking attributes for this energy trade. |
| `offer` | `EnergyTradeOffer` | — | Energy trade offer attributes (pricing model, windows). |
| `customer` | `EnergyCustomer` | — | Energy customer attributes (meter, utility, load). |

*Inherits all properties from [`Contract`](https://schema.beckn.io/Contract/v2.0) including `id`, `displayId`, `items`, `status`, `contractValue`, `participants`, `entitlements`, and `fulfillments`.*

## Linked Data

| Resource | URL |
|----------|-----|
| Canonical IRI | `https://schema.beckn.io/EnergyTrade` |
| JSON Schema (latest) | `https://schema.beckn.io/EnergyTrade/v2.0` |
| context.jsonld (latest) | `https://schema.beckn.io/EnergyTrade/v2.0/context.jsonld` |
| vocab.jsonld (latest) | `https://schema.beckn.io/EnergyTrade/v2.0/vocab.jsonld` |
| Root context.jsonld | `https://schema.beckn.io/context.jsonld` |
| Root vocab.jsonld | `https://schema.beckn.io/vocab.jsonld` |
