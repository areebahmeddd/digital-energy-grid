# EnergyTrade — v0.3

> ⚠️ **Deprecated** — `EnergyTrade` v0.3 is superseded by [`P2PTrade/v2.0`](../../P2PTrade/v2.0/). The combined OpenAPI 3.1.1 schema has been split into 7 independent domain schemas. See the [EnergyTrade root README](../README.md) for the migration guide.

Combined attribute schemas for P2P energy trading (OpenAPI 3.1.1 format). Preserved for backward compatibility.

Part of the [DEG Schema](../../../README.md) · [EnergyTrade](../README.md)

## Files

| File | Description |
|------|-------------|
| [attributes.yaml](./attributes.yaml) | OpenAPI 3.1.1 combined attribute schemas for all EnergyTrade domain types |
| [context.jsonld](./context.jsonld) | JSON-LD context mapping all properties to `deg:` and `schema:` IRIs |
| [vocab.jsonld](./vocab.jsonld) | RDF vocabulary for EnergyTrade domain terms |

## Schemas Defined

This version uses a **combined file** containing all energy trade domain schemas:

| Schema | Beckn Attachment Point | Description |
|--------|----------------------|-------------|
| `EnergyTradeOffer` | `Offer.offerAttributes` | Pricing models, delivery windows, and optional gift parameters |
| `EnergyGift` | `EnergyTradeOffer.gift` | Gift energy — lookupHash, claim verifier, expiration |
| `EnergyTradeOrder` | `Contract.orderAttributes` | Platform and utility identifiers for the trade contract (formerly `Order.orderAttributes` — see `beckn:Order owl:equivalentClass beckn:Contract`) |
| `EnergyTradeDelivery` | `orderItemAttributes.fulfillmentAttributes` | Real-time delivery tracking |
| `EnergyResource` | `Item.itemAttributes` | Energy source characteristics |
| `EnergyCustomer` | `Buyer.buyerAttributes`, `Provider.providerAttributes` | Customer info: meterId, sanctionedLoad, utilityCustomerId |
| `EnergyOrderItem` | `orderItemAttributes` | Order item wrapper |

> **Note:** In v2.0, each of these schemas has been moved to its own dedicated schema folder following the standard DEG schema structure.

## Properties — EnergyTradeOffer

| Property | Type | Required | Description |
|----------|------|:--------:|-------------|
| `pricingModel` | `string` (enum) | ✓ | Pricing model: `PER_KWH`, `TIME_OF_DAY`, `SUBSCRIPTION`, `FIXED`. |
| `validityWindow` | `TimePeriod` | — | Time window during which this offer can be selected. |
| `deliveryWindow` | `TimePeriod` | — | Specific time period when energy delivery occurs. |
| `gift` | `EnergyGift` | — | Optional gift parameters for energy gifting. |
