# DemandFlexNeed

Attribute schemas for demand-flex needs (Resource.resourceAttributes). Describes what the utility needs from the network: direction, event timing, capacity, and location.

**Canonical IRI:** `https://schema.nfh.global/DemandFlexNeed/v2.0`

**Namespace prefix:** `deg:` → `https://schema.nfh.global/deg/DemandFlexNeed/v2.0/`

---

## Versions

| Version | Status | Notes |
|---------|--------|-------|
| [v2.0](./v2.0/) | Current | Resource-attribute schema describing what a utility needs from the network — direction, event timing, capacity. |

---

## Properties

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `direction` | `string` enum | ✅ | Whether the utility needs demand increase or demand reduction. REDUCE = curtailment (ty... |
| `eventWindow` | `object` | ✅ | The time window during which the flex event occurs. All times MUST be in UTC (ISO 8601 ... |
| `capacityType` | `string` enum |  | Type of flex capacity. CURTAILMENT = reduce consumption. SHIFT = move consumption to di... |
| `maxCapacityKw` | `number` | ✅ | Maximum flex capacity needed in kW. |
| `location` | `object` |  | Geographic area where flex is needed (GeoJSON). |
