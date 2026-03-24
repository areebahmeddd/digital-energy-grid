# EnergyContract v2.0

## Overview

`EnergyContract` is a JSON Schema 2020-12 document representing a DEG-specific subclass of `beckn:Contract`. It serves as the semantic base class for all energy contracts on the Digital Energy Grid (DEG) network — including peer-to-peer trading, demand flexibility, and EV charging service agreements.

This version introduces no additional properties beyond those inherited from `beckn:Contract`. Concrete subclasses (e.g., `P2PTrade`) define domain-specific attributes.

| Field       | Value                                              |
|-------------|----------------------------------------------------|
| **Schema ID** | `https://schema.beckn.io/EnergyContract/v2.0`    |
| **Version** | `2.0`                                              |
| **Status**  | Current                                            |
| **Extends** | `beckn:Contract`                                   |

---

## Schema Hierarchy

```
beckn:Contract
  └── EnergyContract          ← this schema
        └── P2PTrade           (active subclass)
```

---

## File Inventory

| File | Description |
|------|-------------|
| [`attributes.yaml`](./attributes.yaml) | JSON Schema 2020-12 — inherits from `beckn:Contract` |
| [`context.jsonld`](./context.jsonld) | JSON-LD context mapping properties to IRIs |
| [`vocab.jsonld`](./vocab.jsonld) | OWL/RDFS vocabulary declaring `EnergyContract` as an `rdfs:Class` |
| [`README.md`](./README.md) | This document |

---

## Inheritance

`EnergyContract` extends `beckn:Contract` via `allOf`:

```yaml
allOf:
  - $ref: "https://schema.beckn.io/Contract/v2.0"
```

All properties from `beckn:Contract` are inherited. No additional properties are defined at this level.

---

## Subclasses

| Schema | Status | Description |
|--------|--------|-------------|
| [`P2PTrade`](../../P2PTrade/v2.0/README.md) | Current | Peer-to-peer energy trading contract |
| [`EnergyTrade`](../../EnergyTrade/v2.0/README.md) | Deprecated | Replaced by `P2PTrade` |

---

## Namespace

| Prefix | IRI |
|--------|-----|
| `deg`  | `https://schema.beckn.io/deg/EnergyContract/v2.0/` |
| `beckn` | `https://schema.beckn.io/core/v2.0/` |

---

## Links

- [Root schema folder README](../README.md)
- [P2PTrade v2.0](../../P2PTrade/v2.0/README.md)
- [Beckn Protocol core specification](https://schema.beckn.io/core/v2.0)
