# DemandFlexPerformance — v2.0

Attribute schemas for demand-flex M&V (Performance.performanceAttributes).

Part of the [DEG Schema](../../) · [DemandFlexPerformance](../README.md)

## Files

| File | Description |
|------|-------------|
| [attributes.yaml](./attributes.yaml) | OpenAPI 3.1.1 components.schemas.`DemandFlexPerformance` (JSON Schema 2020-12 body) |
| [context.jsonld](./context.jsonld) | JSON-LD context (namespace `https://schema.beckn.io/deg/DemandFlexPerformance/v2.0/`) |
| [vocab.jsonld](./vocab.jsonld) | RDF vocabulary for `DemandFlexPerformance` terms |

## Properties

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `eventId` | `string` |  | Identifier of the flex event being measured. |
| `methodology` | `string` |  | Baseline methodology used across all meters (e.g., "5of10" means average of 5 highest-c... |
| `meters` | `array` |  | Per-meter M&V data. Each entry contains the meter ID, its baseline, and (after the even... |
