# EnergyResource

Item attributes for energy resources in P2P trading — source type and source meter identifier.

**Canonical IRI:** `https://schema.beckn.io/EnergyResource/v2.0`

**Namespace prefix:** `deg:` → `https://schema.beckn.io/deg/EnergyResource/v2.0/`

**Tags:** `energy-trade` · `p2p-trading` · `item` · `energy-resource`

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
| `sourceType` | `string` enum | | Energy source: `SOLAR` \| `BATTERY` \| `GRID` \| `HYBRID` \| `RENEWABLE` |
| `meterId` | `string` | | Source meter ID in DER address format (`der://meter/{id}`) |

---

## Linked Data

| Term | IRI |
|------|-----|
| `EnergyResource` | `deg:EnergyResource` |
| `sourceType` | `deg:sourceType` |
| `meterId` | `deg:meterId` |
| `SOLAR` | `deg:SourceTypeSolar` |
| `BATTERY` | `deg:SourceTypeBattery` |
| `GRID` | `deg:SourceTypeGrid` |
| `HYBRID` | `deg:SourceTypeHybrid` |
| `RENEWABLE` | `deg:SourceTypeRenewable` |

---

## Usage

`EnergyResource` is attached to `Item.itemAttributes` in P2P energy trading beckn flows.
Source type verification occurs at onboarding but may change post-onboarding (e.g., switching
from solar to diesel). Source type influences pricing but not the trading workflow.
