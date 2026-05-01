# BecknReportRequest — v1.0

OpenADR 3.1.0-aligned wrapper for telemetry report requests inside beckn payloads.

Part of the [DEG Schema](../../) · [BecknReportRequest](../README.md)

## Files

| File | Description |
|------|-------------|
| [attributes.yaml](./attributes.yaml) | OpenAPI 3.1.1 components.schemas.`BecknReportRequest` and `BecknReportPayload` (re-uses OpenADR3 `reportDescriptor` via `$ref`) |
| [context.jsonld](./context.jsonld) | JSON-LD context |
| [vocab.jsonld](./vocab.jsonld) | RDF vocabulary |

## When to use

Use `BecknReportRequest` when one party needs to ask another for a specific telemetry report — e.g. a DISCOM asking an aggregator for fulfillment status, with a precise specifier (which payloadType, which devices, what cadence). The companion `BecknReportPayload` carries reply-side correlation metadata; the actual report body travels as a [`BecknTimeSeries`](../../BecknTimeSeries/v1.0/) embedded in the parent schema's telemetry slot.

This is the request-side counterpart to `BecknTimeSeries` (which is the time-series body itself).

## Properties — `BecknReportRequest`

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `reportName` | string | — | Caller-defined name for the requested report (e.g. `VENDOR_TELEMETRY_USAGE`). |
| `eventId` | string | — | Caller-defined identifier of the event the report pertains to. |
| `reportDescriptors` | array | ✓ | One OpenADR3 `reportDescriptor` per requested signal. |

Each `reportDescriptor` (per OpenADR3) carries: `payloadType` (required), `readingType`, `units`, `targets[]`, `aggregate`, `historical`, `numIntervals`, `frequency`, `reportIntervals`, etc.

## Properties — `BecknReportPayload`

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `respondsTo` | string | ✓ | The `messageId` of the originating BecknReportRequest. |
| `reportName` | string | — | Echoes the request's `reportName`. |
| `eventId` | string | — | Echoes the request's `eventId`. |
| `intervalDuration` | string | — | ISO 8601 duration of intervals in the embedded BecknTimeSeries. |

## How to embed in a parent payload

Best practice: attach via `Contract.contractAttributes.reportRequest` (request side) and `Contract.contractAttributes.reportPayload` (reply side). The parent contract schema (`DEGContract` in DEG) declares those as optional sub-properties typed via `$ref` to BecknReportRequest / BecknReportPayload.

```yaml
# In DEGContract attributes.yaml
reportRequest:
  $ref: "https://raw.githubusercontent.com/beckn/DEG/refs/heads/main/specification/schema/BecknReportRequest/v1.0/attributes.yaml#/components/schemas/BecknReportRequest"

reportPayload:
  $ref: "https://raw.githubusercontent.com/beckn/DEG/refs/heads/main/specification/schema/BecknReportRequest/v1.0/attributes.yaml#/components/schemas/BecknReportPayload"
```

## Minimal example — DISCOM asks aggregator for vendor USAGE telemetry

```json
{
  "@type": "BecknReportRequest",
  "reportName": "VENDOR_TELEMETRY_USAGE",
  "eventId": "evt-2026-04-01-vendor-001",
  "reportDescriptors": [
    {
      "payloadType": "USAGE",
      "readingType": "DIRECT_READ",
      "units": "KW",
      "aggregate": false,
      "historical": true,
      "numIntervals": 4,
      "frequency": -1,
      "reportIntervals": "INTERVALS",
      "targets": ["ev://vehicle/VIN001", "ev://vehicle/VIN002", "ev://vehicle/VIN003"]
    }
  ]
}
```

## Why this lives in DEG

OpenADR's `reportDescriptor` is the most battle-tested shape for telemetry report requests in the energy domain. Vendoring its YAML at [`specification/external/openadr/3.1.0/`](../../../external/openadr/3.1.0/) and `$ref`-importing it gives DEG a uniform request-side idiom paired with `BecknTimeSeries` on the reply side.
