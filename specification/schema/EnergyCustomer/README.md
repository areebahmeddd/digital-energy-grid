# EnergyCustomer

Customer attributes for energy flows — meter ID, sanctioned load, and utility account information for consumers, producers, and prosumers.

**Canonical IRI:** `https://schema.beckn.io/EnergyCustomer/v2.0`

**Namespace prefix:** `deg:` → `https://schema.beckn.io/deg/EnergyCustomer/v2.0/`

**Tags:** `energy-trade` · `p2p-trading` · `energy-enrollment` · `customer`

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
| `meterId` | `string` | ✅ | Meter ID in DER address format (`der://meter/{id}`) |
| `sanctionedLoad` | `number` (kW) | | Approved electrical load capacity |
| `utilityCustomerId` | `string` | | Customer's account number with their utility |
| `utilityId` | `string` | | Utility/DISCOM identifier (e.g., `TPDDL-DL`) for inter-utility trading |

---

## Linked Data

| Term | IRI |
|------|-----|
| `EnergyCustomer` | `deg:EnergyCustomer` |
| `meterId` | `deg:meterId` |
| `sanctionedLoad` | `deg:sanctionedLoad` |
| `utilityCustomerId` | `deg:utilityCustomerId` |
| `utilityId` | `deg:utilityId` |

---

## Usage

`EnergyCustomer` is used in multiple contexts:
- **P2P Trading:** `orderItemAttributes` for delivery destination (init/confirm/on_status)
- **Enrollment:** `Buyer.buyerAttributes` with `meterId` and `sanctionedLoad` for customer identification

For inter-utility (inter-DISCOM) P2P trades, `utilityId` identifies the utility serving each party.
