# DemandFlexNeed — v2.0

Attribute schemas for demand-flex needs (Resource.resourceAttributes). Describes what the utility needs from the network: direction, event timing, capacity, and location.

Part of the [DEG Schema](../../) · [DemandFlexNeed](../README.md)

## Files

| File | Description |
|------|-------------|
| [attributes.yaml](./attributes.yaml) | OpenAPI 3.1.1 components.schemas.`DemandFlexNeed` (JSON Schema 2020-12 body) |
| [context.jsonld](./context.jsonld) | JSON-LD context (namespace `https://schema.beckn.io/deg/DemandFlexNeed/v2.0/`) |
| [vocab.jsonld](./vocab.jsonld) | RDF vocabulary for `DemandFlexNeed` terms |

## Properties

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `direction` | `string` enum | ✅ | Whether the utility needs demand increase or demand reduction. REDUCE = curtailment (ty... |
| `eventWindow` | `object` | ✅ | The time window during which the flex event occurs. All times MUST be in UTC (ISO 8601 ... |
| `capacityType` | `string` enum |  | Type of flex capacity. CURTAILMENT = reduce consumption. SHIFT = move consumption to di... |
| `maxCapacityKw` | `number` | ✅ | Maximum flex capacity needed in kW. |
| `location` | `object` |  | Geographic area where flex is needed (GeoJSON). |
