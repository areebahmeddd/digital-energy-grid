# DemandFlexBuyOffer

Offer attributes for demand-flex contracts.

**Canonical IRI:** `https://schema.nfh.global/DemandFlexBuyOffer/v2.0`

**Namespace prefix:** `deg:` → `https://schema.nfh.global/deg/DemandFlexBuyOffer/v2.0/`

---

## Versions

| Version | Status | Notes |
|---------|--------|-------|
| [v2.0](./v2.0/) | Current | Behavioral demand-response buy-offer attributes (utility-side curtailment intents). |

---

## Properties

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `contractAttributes` | `object` |  | Portable DEGContract template. Present only in catalog/discover. Promoted to Contract.c... |
| `inputs` | `array` | ✅ | One entry per role. participantId is null until the role is bound (e.g. seller is null ... |
