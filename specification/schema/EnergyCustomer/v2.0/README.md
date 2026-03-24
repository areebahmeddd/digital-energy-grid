# EnergyCustomer — v2.0

Customer attributes for energy flows — meter ID, sanctioned load, and utility account for consumers, producers, and prosumers.

Part of the [DEG Schema](../../../specification/schema/) · [EnergyCustomer](../README.md)

## Files

| File | Description |
|------|-------------|
| [attributes.yaml](./attributes.yaml) | JSON Schema 2020-12 definition for `EnergyCustomer` |
| [context.jsonld](./context.jsonld) | JSON-LD context (namespace: `https://schema.beckn.io/deg/EnergyCustomer/v2.0/`) |
| [vocab.jsonld](./vocab.jsonld) | RDF vocabulary for `EnergyCustomer` terms |

## Properties

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `meterId` | `string` | ✅ | `der://meter/{id}` — delivery destination / customer identification |
| `sanctionedLoad` | `number` (kW) | | Approved load capacity |
| `utilityCustomerId` | `string` | | Utility account number |
| `utilityId` | `string` | | Utility/DISCOM ID for inter-utility trading (e.g., `TPDDL-DL`) |

## Changes from v0.3

- Extracted from combined `EnergyTrade/v0.3/attributes.yaml` into standalone schema
- Published as JSON Schema 2020-12 (was OpenAPI 3.1 component)
