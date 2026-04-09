# EnergyGift

Gift parameters for P2P energy gifting — enables privacy-preserving discovery and secret-based claim verification.

**Canonical IRI:** `https://schema.beckn.io/EnergyGift/v2.0`

**Namespace prefix:** `deg:` → `https://schema.beckn.io/deg/EnergyGift/v2.0/`

**Tags:** `energy-trade` · `p2p-trading` · `gifting`

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
| `lookupHash` | `string` (hex64) | ✅ | SHA-256 hash of recipient's phone (E.164) for privacy-preserving catalog discovery |
| `claimVerifier` | `string` (hex64) | ✅ | SHA-256 hash of a shared secret; recipient proves ownership by presenting the pre-image |
| `expiresAt` | `string` (date-time, UTC) | ✅ | Gift expiration — after this time the offer is no longer claimable |

---

## Linked Data

| Term | IRI |
|------|-----|
| `EnergyGift` | `deg:EnergyGift` |
| `lookupHash` | `deg:lookupHash` |
| `claimVerifier` | `deg:claimVerifier` |
| `expiresAt` | `deg:expiresAt` |

---

## Usage

`EnergyGift` appears as the `gift` property on an [`EnergyTradeOffer`](../EnergyTradeOffer/).
A prosumer publishes an offer with `gift` set; the offer is listed at price 0. The intended recipient
discovers the offer by hashing their phone number and matching it to `lookupHash`. They claim
the gift by presenting the shared secret (pre-image of `claimVerifier`) in the `select` message.
