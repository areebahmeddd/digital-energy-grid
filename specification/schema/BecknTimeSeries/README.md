# BecknTimeSeries

OpenADR 3.1.0-aligned time-series envelope for beckn payloads.

**Canonical IRI:** `https://schema.nfh.global/BecknTimeSeries/v1.0`

**Namespace prefix:** `bts:` → `https://schema.nfh.global/deg/BecknTimeSeries/v1.0/`

---

## Versions

| Version | Status | Notes |
|---------|--------|-------|
| [v1.0](./v1.0/) | Current | Initial — wraps OpenADR3 `interval`/`intervalPeriod`/`valuesMap` via `$ref`. |

---

## Properties

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `intervalPeriod` | object | ✓ | Default `{start, duration}` (ISO 8601) for the series. |
| `payloadDescriptors` | array | | Optional `{payloadType, units, currency, …}` per signal. |
| `intervals` | array | ✓ | Series rows; each `{id, [intervalPeriod], payloads[]}`. |
