# DemandFlexBuyOffer — v2.0

Offer attributes for demand-flex contracts. Contains an inputs array of DemandFlexRoleInput — one entry per role. At catalog time, entries have null participantId. As the contract progresses through init/confirm, participantIds and role-specific inputs are filled in.

Part of the [DEG Schema](../../) · [DemandFlexBuyOffer](../README.md)

## Files

| File | Description |
|------|-------------|
| [attributes.yaml](./attributes.yaml) | OpenAPI 3.1.1 components.schemas.`DemandFlexBuyOffer` (JSON Schema 2020-12 body) |
| [context.jsonld](./context.jsonld) | JSON-LD context (namespace `https://schema.beckn.io/deg/DemandFlexBuyOffer/v2.0/`) |
| [vocab.jsonld](./vocab.jsonld) | RDF vocabulary for `DemandFlexBuyOffer` terms |

## Properties

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `contractAttributes` | `object` |  | Portable DEGContract template. Present only in catalog/discover. Promoted to Contract.c... |
| `inputs` | `array` | ✅ | One entry per role. participantId is null until the role is bound (e.g. seller is null ... |
