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

DemandFlexNeed is an **OpenADR 3.1.0-aligned time series** (one interval per
tranche) — the single, unified Need shape for uc1 (monopsony, DISCOM fixes the
clearing price) and uc2 (pay-as-clear auction). Columns are open in the schema;
each contract policy rego imposes its own hard-`const` column set.

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `location` | Beckn Location |  | GeoJSON geometry (`geo`) + optional `address` |
| `intervalPeriod` | OpenADR intervalPeriod | ✅ | `start` + `duration` (e.g. `PT30M`) — the tranche grid |
| `payloadDescriptors` | array | ✅ | Buyer column descriptors (profile-specific; rego-locked) |
| `intervals` | OpenADR interval[] | ✅ | One row per tranche — `id` + typed `payloads` |
