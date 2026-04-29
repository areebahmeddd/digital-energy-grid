# DemandFlexPerformance

Attribute schemas for demand-flex M&V (Performance.performanceAttributes).

**Canonical IRI:** `https://schema.beckn.io/DemandFlexPerformance/v2.0`

**Namespace prefix:** `deg:` → `https://schema.beckn.io/deg/DemandFlexPerformance/v2.0/`

---

## Versions

| Version | Status | Notes |
|---------|--------|-------|
| [v2.0](./v2.0/) | Current | Performance / delivery attributes for behavioral demand-response — per-meter `BecknTimeSeries` telemetry (BASELINE pre-event, BASELINE+USAGE post-event). |

---

## Properties

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `eventId` | `string` |  | Identifier of the flex event being measured. |
| `methodology` | `string` |  | Baseline methodology used across all meters (e.g., "5of10"). |
| `meters` | `array` |  | Per-meter M&V — each entry binds a `meterId` to a `telemetry` BecknTimeSeries. |
