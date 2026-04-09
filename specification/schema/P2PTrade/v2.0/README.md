# P2PTrade v2.0

**Schema ID:** `https://schema.beckn.io/P2PTrade/v2.0`

**Status:** Current

---

## Overview

`P2PTrade` is the current recommended schema for Peer-to-Peer energy trading contracts on the DEG network. It is a subclass of [`EnergyContract`](../../EnergyContract/v2.0/) (which is itself a subclass of `beckn:Contract`).

`P2PTrade` inherits all properties from the Contract hierarchy. The full domain-specific attributes for P2P energy trading — pricing model, delivery windows, meter readings, energy resource and customer data — are defined in the companion [`EnergyTrade`](../../EnergyTrade/v2.0/) schema.

---

## Files

| File | Description |
|------|-------------|
| [`attributes.yaml`](./attributes.yaml) | JSON Schema 2020-12 — subclass of `EnergyContract` |
| [`context.jsonld`](./context.jsonld) | JSON-LD context mapping `P2PTrade` to `deg:P2PTrade` |
| [`vocab.jsonld`](./vocab.jsonld) | RDF vocabulary — class definition with `rdfs:subClassOf deg:EnergyContract` |

---

## Inheritance

```
beckn:Contract
  └── deg:EnergyContract
        └── deg:P2PTrade  ← this schema
```

---

## Related Schemas

| Schema | Relationship | Description |
|--------|-------------|-------------|
| [`EnergyContract`](../../EnergyContract/v2.0/) | Parent | Intermediate base class for DEG energy contracts |
| [`EnergyTrade`](../../EnergyTrade/v2.0/) | Domain attributes (deprecated) | Full P2P trade attributes — deprecated, see P2PTrade subclasses |
| [`EnergyTradeOffer`](../../EnergyTradeOffer/v2.0/) | Referenced | Pricing and delivery window attributes |
| [`EnergyTradeDelivery`](../../EnergyTradeDelivery/v2.0/) | Referenced | Meter readings and delivery tracking |
