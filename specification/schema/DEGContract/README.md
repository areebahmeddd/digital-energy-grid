# DEGContract

Standard contract schema for all DEG energy contracts.

**Canonical IRI:** `https://schema.nfh.global/DEGContract/v2.0`

**Namespace prefix:** `deg:` → `https://schema.nfh.global/deg/DEGContract/v2.0/`

---

## Versions

| Version | Status | Notes |
|---------|--------|-------|
| [v2.0](./v2.0/) | Current | DEG-wide standard contract schema. Roles + policy reference; revenue flows live separately on Contract.consideration[*].considerationAttributes (RevenueFlow JSON-LD). |

---

## Properties

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `roles` | `array` | ✅ | Contract roles. The participantId key is required on every role entry, but its value MA... |
| `policy` | `object` | ✅ | OPA/Rego policy governing this contract. |
| `revenueFlows` | `array` |  | Optional. Settlement-time per-role flows written by the `contractpolicyenforcer` plugin when it i... |
