# BecknTimeSeries — v1.0

Lightweight, OpenADR 3.1.0-aligned time-series envelope for beckn payloads.

Part of the [DEG Schema](../../) · [BecknTimeSeries](../README.md)

## Files

| File | Description |
|------|-------------|
| [attributes.yaml](./attributes.yaml) | OpenAPI 3.1.1 components.schemas.`BecknTimeSeries` (re-uses OpenADR3 types via `$ref`) |
| [context.jsonld](./context.jsonld) | JSON-LD context (namespace `https://schema.beckn.io/deg/BecknTimeSeries/v1.0/`) |
| [vocab.jsonld](./vocab.jsonld) | RDF vocabulary |

## Properties

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `intervalPeriod` | object | ✓ | Default `{start, duration}` (ISO 8601) for the series. |
| `payloadDescriptors` | array | | Optional sidecar — `{payloadType, units, currency, readingType, …}` per signal. |
| `intervals` | array | ✓ | Series rows; each `{id, [intervalPeriod], payloads[]}`. `payloads[]` is a list of `{type, values[]}` valuesMap rows. |

## Minimal example — single-signal, two intervals

```json
{
  "@context": "https://raw.githubusercontent.com/beckn/DEG/refs/heads/main/specification/schema/BecknTimeSeries/v1.0/context.jsonld",
  "@type": "BecknTimeSeries",
  "intervalPeriod": { "start": "2026-04-01T08:30:00Z", "duration": "PT1H" },
  "intervals": [
    { "id": 0, "payloads": [ {"type": "BASELINE", "values": [45.0]} ] },
    { "id": 1, "payloads": [ {"type": "BASELINE", "values": [44.0]} ] }
  ]
}
```

## Multi-signal example — scalar + 2-D point in the same interval

```json
{
  "@context": "https://raw.githubusercontent.com/beckn/DEG/refs/heads/main/specification/schema/BecknTimeSeries/v1.0/context.jsonld",
  "@type": "BecknTimeSeries",
  "intervalPeriod": { "start": "2026-04-01T08:30:00Z", "duration": "PT15M" },
  "payloadDescriptors": [
    { "objectType": "REPORT_PAYLOAD_DESCRIPTOR", "payloadType": "PRICE",         "units": "INR_PER_KWH", "currency": "INR" },
    { "objectType": "REPORT_PAYLOAD_DESCRIPTOR", "payloadType": "FORECAST_BAND", "units": "KW" }
  ],
  "intervals": [
    {
      "id": 0,
      "payloads": [
        { "type": "PRICE",         "values": [12] },
        { "type": "FORECAST_BAND", "values": [ {"x": 10, "y": 14} ] }
      ]
    }
  ]
}
```

## What the schema validator catches vs. what it doesn't

`BecknTimeSeries` reuses OpenADR3 shapes via `$ref`. The beckn-onix /
kin-openapi validator (OpenAPI 3.1 / JSON Schema 2020-12 subset) will flag:

- wrong types, missing `payloads` / `values`
- `intervals` shorter than `minItems: 1`
- malformed ISO datetime / ISO duration
- value elements that are neither number / string / boolean / `point`

It will **not** catch (kin-openapi does not implement `if/then/else`,
`prefixItems`, `dependentRequired`, `contains` from JSON Schema 2020-12):

- value-conditioned cardinality (e.g. "PRICE rows must have exactly one
  number, FORECAST_BAND must have exactly one point")
- cross-row alignment ("every interval carries the same set of `type`
  keys as `payloadDescriptors`")

These semantics belong in the policy layer (Rego) — see
`specification/policies/demand_flex_revenue.rego` for an example reading
`telemetry.intervals[].payloads`.

## Why this lives in DEG

OpenADR's `report.resources[].intervals[]` is the most battle-tested
shape for interval-aligned energy data. Vendoring its YAML at
[`specification/external/openadr/3.1.0/`](../../../external/openadr/3.1.0/)
and `$ref`-importing it gives DEG schemas a uniform time-series idiom
without copying types. Each domain schema (e.g. `DemandFlexPerformance`)
embeds `BecknTimeSeries` under whatever attribute carries series data
— typically `telemetry`.
