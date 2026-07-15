# EnergyContract

Base class for energy contracts on the DEG network. EnergyContract specialises `beckn:Contract` for energy-sector use cases and is the parent of all DEG energy contract types including [`P2PTrade`](../P2PTrade/).

**Canonical IRI:** `https://schema.nfh.global/EnergyContract/v2.0`

**Namespace prefix:** `deg:` → `https://schema.nfh.global/deg/EnergyContract/v2.0/`

**Tags:** `energy` · `contract`

---

## Versions

| Version | Status | Notes |
|---------|--------|-------|
| [v2.0](./v2.0/) | Current | Initial JSON Schema release |

---

## Properties

`EnergyContract` inherits all properties from [`beckn:Contract`](https://schema.nfh.global/Contract/v2.0) and introduces no additional properties of its own. It serves as a semantic subclass marker for energy contracts in the DEG taxonomy.

| Property | Inherited from | Required | Description |
|----------|---------------|----------|-------------|
| `@type` | [Contract](https://schema.nfh.global/Contract/v2.0) | ✅ | Must be a `beckn:` prefixed IRI |
| `participants` | [Contract](https://schema.nfh.global/Contract/v2.0) | ✅ | Contract participants |
| `items` | [Contract](https://schema.nfh.global/Contract/v2.0) | ✅ | Contract items |
| `id` | [Contract](https://schema.nfh.global/Contract/v2.0) | | UUID string for the contract |
| `displayId` | [Contract](https://schema.nfh.global/Contract/v2.0) | | Human-readable identifier |
| `status` | [Contract](https://schema.nfh.global/Contract/v2.0) | | Current state of the contract |
| `contractValue` | [Contract](https://schema.nfh.global/Contract/v2.0) | | Total contract value |
| `entitlements` | [Contract](https://schema.nfh.global/Contract/v2.0) | | Entitlements in this contract |
| `fulfillments` | [Contract](https://schema.nfh.global/Contract/v2.0) | | Fulfillment acts |

---

## Linked Data

| Term | IRI |
|------|-----|
| `EnergyContract` | `deg:EnergyContract` |

---

## Subclasses

| Schema | Description |
|--------|-------------|
| [P2PTrade](../P2PTrade/) | Peer-to-Peer energy trading contract |
