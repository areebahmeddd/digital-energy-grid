# P2PTrade

Schema for Peer-to-Peer energy trading contracts on the DEG network. P2PTrade is a subclass of [`EnergyContract`](../EnergyContract/), which is itself a subclass of `beckn:Contract`.

**Canonical IRI:** `https://schema.beckn.io/P2PTrade/v2.0`

**Namespace prefix:** `deg:` → `https://schema.beckn.io/deg/P2PTrade/v2.0/`

**Tags:** `energy-trade` · `p2p-trading` · `contract` · `energy`

---

## Versions

| Version | Status | Notes |
|---------|--------|-------|
| [v2.0](./v2.0/) | Current | Initial JSON Schema release |

---

## Inheritance

```
beckn:Contract
  └── deg:EnergyContract
        └── deg:P2PTrade  ← this schema
```

P2PTrade inherits all properties from `beckn:Contract` via `EnergyContract`. Domain-specific properties for P2P energy trading (offer, order, delivery, resource, customer data) are defined in the [`EnergyTrade`](../EnergyTrade/) schema which provides the concrete contract shape.

---

## Properties

`P2PTrade` inherits all properties from [`EnergyContract`](../EnergyContract/) and transitively from [`beckn:Contract`](https://schema.beckn.io/Contract/v2.0):

| Property | Inherited from | Required | Description |
|----------|---------------|----------|-------------|
| `@type` | [Contract](https://schema.beckn.io/Contract/v2.0) | ✅ | Must be a `beckn:` prefixed IRI |
| `participants` | [Contract](https://schema.beckn.io/Contract/v2.0) | ✅ | Contract participants (buyer, seller) |
| `items` | [Contract](https://schema.beckn.io/Contract/v2.0) | ✅ | Energy items/resources in the contract |
| `id` | [Contract](https://schema.beckn.io/Contract/v2.0) | | UUID for the P2P trade contract |
| `displayId` | [Contract](https://schema.beckn.io/Contract/v2.0) | | Human-readable contract identifier |
| `status` | [Contract](https://schema.beckn.io/Contract/v2.0) | | Current contract state |
| `contractValue` | [Contract](https://schema.beckn.io/Contract/v2.0) | | Total energy trade contract value |
| `entitlements` | [Contract](https://schema.beckn.io/Contract/v2.0) | | Contract entitlements |
| `fulfillments` | [Contract](https://schema.beckn.io/Contract/v2.0) | | Energy delivery fulfillment acts |

---

## Linked Data

| Term | IRI |
|------|-----|
| `P2PTrade` | `deg:P2PTrade` |

---

## Usage

`P2PTrade` is used as the `@type` for P2P energy trading contracts on the DEG network. For the full set of domain-specific attributes (offer pricing, delivery windows, meter readings, etc.), refer to the [`EnergyTrade`](../EnergyTrade/) schema which defines these as `contractAttributes`.
