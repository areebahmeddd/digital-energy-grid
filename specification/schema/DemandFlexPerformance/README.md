# DemandFlexPerformance

Attribute schemas for demand-flex M&V (Performance.performanceAttributes).

**Canonical IRI:** `https://schema.beckn.io/DemandFlexPerformance/v2.0`

**Namespace prefix:** `deg:` → `https://schema.beckn.io/deg/DemandFlexPerformance/v2.0/`

---

## Versions

| Version | Status | Notes |
|---------|--------|-------|
| [v2.0](./v2.0/) | Current | Performance / delivery attributes for behavioral demand-response — baseline and actuals. |

---

## Properties

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `eventId` | `string` |  | Identifier of the flex event being measured. |
| `methodology` | `string` |  | Baseline methodology used across all meters (e.g., "5of10" means average of 5 highest-c... |
| `meters` | `array` |  | Per-meter M&V data. Each entry contains the meter ID, its baseline, and (after the even... |
