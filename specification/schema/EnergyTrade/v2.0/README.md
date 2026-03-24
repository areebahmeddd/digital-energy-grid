# EnergyTrade — v2.0

> ⚠️ **Deprecated** — This schema is preserved for backward compatibility. Use [`P2PTrade/v2.0`](../../P2PTrade/v2.0/) for all new implementations.
>
> **OWL Migration:** `deg:EnergyTrade owl:equivalentClass deg:P2PTrade` · `beckn:Order owl:equivalentClass beckn:Contract`
> See [vocab.jsonld](./vocab.jsonld) for the machine-readable deprecation declaration.

P2P energy trade contract — a subclass of [`Contract`](https://schema.beckn.io/Contract/v2.0) specialised for energy delivery between prosumers on a DEG network.

Part of the [DEG Schema](../../../README.md) · [EnergyTrade](../README.md)

## Files

| File | Description |
|------|-------------|
| [attributes.yaml](./attributes.yaml) | JSON Schema 2020-12 definition for `EnergyTrade` (subclass of `Contract`) |
| [context.jsonld](./context.jsonld) | JSON-LD context mapping properties to `deg:` and `schema:` IRIs |
| [vocab.jsonld](./vocab.jsonld) | RDF vocabulary for EnergyTrade domain terms |

## Root linked-data files

| File | Description |
|------|-------------|
| [schema/context.jsonld](../../context.jsonld) | Root JSON-LD context (all schemas) |
| [schema/vocab.jsonld](../../vocab.jsonld) | Root RDF vocabulary (all schemas) |

## Design

`EnergyTrade` is a subclass of `Contract` (via `allOf`) and adds domain-specific energy trading properties by referencing individual domain schemas at their canonical URIs:

| Property | References | Description |
|----------|-----------|-------------|
| `energyResource` | [`EnergyResource/v2.0`](https://schema.beckn.io/EnergyResource/v2.0) | Energy source characteristics |
| `delivery` | [`EnergyTradeDelivery/v2.0`](https://schema.beckn.io/EnergyTradeDelivery/v2.0) | Delivery tracking attributes |
| `offer` | [`EnergyTradeOffer/v2.0`](https://schema.beckn.io/EnergyTradeOffer/v2.0) | Offer terms (pricing model, windows) |
| `customer` | [`EnergyCustomer/v2.0`](https://schema.beckn.io/EnergyCustomer/v2.0) | Customer info (meter, utility, load) |

## Properties

| Property | Type | Required | Description |
|----------|------|:--------:|-------------|
| `energyResource` | `EnergyResource` | — | Energy source characteristics for this trade. |
| `delivery` | `EnergyTradeDelivery` | — | Delivery tracking attributes. |
| `offer` | `EnergyTradeOffer` | — | Energy trade offer attributes. |
| `customer` | `EnergyCustomer` | — | Energy customer attributes. |

*Plus all inherited `Contract` properties: `id`, `displayId`, `items`, `status`, `contractValue`, `participants`, `entitlements`, `fulfillments`.*

## Vocabulary Migration Path

This table maps deprecated `EnergyTrade/v2.0` concepts to their successors in `P2PTrade/v2.0`:

| Deprecated Term | Old Beckn Attachment | Successor Schema | New Beckn Attachment | OWL Relation |
|-----------------|---------------------|-----------------|---------------------|-------------|
| `deg:EnergyTrade` class | `beckn:Order` subclass | `deg:P2PTrade` | `beckn:Contract` subclass | `owl:equivalentClass` |
| `EnergyTradeDelivery.*` | `orderItemAttributes.fulfillmentAttributes` | [`EnergyTradeDelivery/v2.0`](../../EnergyTradeDelivery/v2.0/) | `Contract.items[].fulfillment.attributes` | `rdfs:seeAlso` |
| `EnergyOrderItem.*` | `orderItemAttributes` | [`EnergyOrderItem/v2.0`](../../EnergyOrderItem/v2.0/) | `Contract.items[]` | `rdfs:seeAlso` |
| `EnergyCustomer.*` | `Buyer.buyerAttributes` | [`EnergyCustomer/v2.0`](../../EnergyCustomer/v2.0/) | `Contract.buyer.buyerAttributes` | `rdfs:seeAlso` |

**Root OWL declaration:** `beckn:Order owl:equivalentClass beckn:Contract` — see [`schemas/schema/Contract/v2.0/vocab.jsonld`](https://github.com/beckn/schemas/blob/main/schema/Contract/v2.0/vocab.jsonld)

## Changes from v0.3

- **Format**: Converted from OpenAPI 3.1 combined file to JSON Schema 2020-12 single-schema file
- **Structure**: `EnergyTrade` is now a proper subclass of `Contract` via `allOf`
- **Domain schemas**: Each of the 7 sub-schemas from the v0.3 combined file is now an independent schema folder under `specification/schema/`
- **References**: Internal schemas use canonical `https://schema.beckn.io/<SchemaName>/v2.0` URIs
