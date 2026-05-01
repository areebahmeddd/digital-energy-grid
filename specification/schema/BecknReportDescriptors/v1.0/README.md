# BecknReportDescriptors — v1.0

Minimal OpenADR 3.1.0-aligned sidecar declaring what telemetry a seller commits to providing under a contract.

Part of the [DEG Schema](../../) · [BecknReportDescriptors](../README.md)

## Files

| File | Description |
|------|-------------|
| [attributes.yaml](./attributes.yaml) | OpenAPI 3.1.1 components.schemas.`BecknReportDescriptors` (array) and `BecknReportPayloadDescriptor` (allOf OpenADR3 reportPayloadDescriptor + cardinality) |
| [context.jsonld](./context.jsonld) | JSON-LD context |
| [vocab.jsonld](./vocab.jsonld) | RDF vocabulary |

## What this is

A flat array of OpenADR3 [`reportPayloadDescriptor`](https://app.swaggerhub.com/apis/openadr3/OpenADR-3.0.0/3.1.0#/schemas/reportPayloadDescriptors) objects, with one DEG extension — `cardinality` — to disambiguate signals reported every interval (USAGE, POWER, SOC_END) from signals reported once per event (GPS_LAT/LON).

The descriptors live in the seller's input on the offer. Pairs with [`BecknTimeSeries`](../../BecknTimeSeries/v1.0/), which carries the values themselves.

## Where it sits in a payload

`offerAttributes.inputs[seller].inputs.reportDescriptors: BecknReportDescriptors | null`

`null` means the contract requires no telemetry. When non-null, the seller commits to delivering a `BecknTimeSeries` whose `payloadDescriptors` cover every entry in this list.

## Per-descriptor fields

| Field | OpenADR3? | Required | Description |
|---|---|---|---|
| `objectType` | yes | ✓ | Always `"REPORT_PAYLOAD_DESCRIPTOR"`. |
| `payloadType` | yes | ✓ | Open string — see canonical vocabulary below. |
| `readingType` | yes | — | E.g. `DIRECT_READ`. |
| `units` | yes | — | E.g. `KW`, `PERCENT`, `DEGREES`. |
| `accuracy` | yes | — | Numeric — quantification of accuracy. |
| `confidence` | yes | — | Integer 0–100. |
| `cardinality` | **DEG** | — | `PER_INTERVAL` (default) or `PER_EVENT`. |

## Canonical `payloadType` vocabulary (demand-flex EV vendor telemetry)

| payloadType | units | readingType | cardinality | what it means |
|---|---|---|---|---|
| `BASELINE` | `KW` | `DIRECT_READ` | `PER_INTERVAL` | Reference (vendor-rated) charge power per interval |
| `USAGE` | `KW` | `DIRECT_READ` | `PER_INTERVAL` | Measured charge power per interval during the event |
| `POWER` | `KW` | `DIRECT_READ` | `PER_INTERVAL` | Signed instantaneous power (charge=+, discharge=−) |
| `SOC_END` | `PERCENT` | `DIRECT_READ` | `PER_INTERVAL` | State of charge at end of each interval |
| `GPS_LAT` | `DEGREES` | `DIRECT_READ` | `PER_EVENT` | Vehicle latitude at start of event |
| `GPS_LON` | `DEGREES` | `DIRECT_READ` | `PER_EVENT` | Vehicle longitude at start of event |

This list is open — extend it for other devices (heat pumps, batteries, etc.) by adding entries.

## How `PER_EVENT` values appear in the time-series

Per-interval values (`BASELINE`, `USAGE`, `POWER`, `SOC_END`) appear in **every** `intervals[*].payloads[*]` row. Per-event values (`GPS_LAT`, `GPS_LON`) appear **only on interval 0**. Consumers iterate intervals normally; per-event rows are simply absent on subsequent intervals. This is enforced by the network rego.

## Minimal example — what a seller commits to provide for an EV curtailment

```json
[
  { "objectType": "REPORT_PAYLOAD_DESCRIPTOR", "payloadType": "BASELINE", "readingType": "DIRECT_READ", "units": "KW",      "cardinality": "PER_INTERVAL" },
  { "objectType": "REPORT_PAYLOAD_DESCRIPTOR", "payloadType": "USAGE",    "readingType": "DIRECT_READ", "units": "KW",      "cardinality": "PER_INTERVAL" },
  { "objectType": "REPORT_PAYLOAD_DESCRIPTOR", "payloadType": "POWER",    "readingType": "DIRECT_READ", "units": "KW",      "cardinality": "PER_INTERVAL" },
  { "objectType": "REPORT_PAYLOAD_DESCRIPTOR", "payloadType": "SOC_END",  "readingType": "DIRECT_READ", "units": "PERCENT", "cardinality": "PER_INTERVAL" },
  { "objectType": "REPORT_PAYLOAD_DESCRIPTOR", "payloadType": "GPS_LAT",  "readingType": "DIRECT_READ", "units": "DEGREES", "cardinality": "PER_EVENT" },
  { "objectType": "REPORT_PAYLOAD_DESCRIPTOR", "payloadType": "GPS_LON",  "readingType": "DIRECT_READ", "units": "DEGREES", "cardinality": "PER_EVENT" }
]
```

## Set to `null` when no telemetry is needed

For a contract that doesn't require vendor reports (e.g. a tariff-only opt-in), the seller's input is:

```json
{ "role": "seller", "participantId": "…", "inputs": { "reportDescriptors": null, … } }
```

This is the explicit "no report" signal — distinct from "field omitted, ask later".
