# RevenueFlow

Settlement-time revenue-flow attributes for energy contracts.

**Canonical IRI:** `https://schema.beckn.io/RevenueFlow/v2.0`

**Namespace prefix:** `deg:` → `https://schema.beckn.io/deg/RevenueFlow/v2.0/`

---

## Versions

| Version | Status | Notes |
|---------|--------|-------|
| [v2.0](./v2.0/) | Current | Settlement-time revenue-flow attributes (sums to zero across roles). Lives on Contract.consideration[*].considerationAttributes. |

---

## Properties

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `revenueFlows` | `array` | ✅ | Per-role signed revenue-flow entries computed by the contract policy after settlement. ... |
