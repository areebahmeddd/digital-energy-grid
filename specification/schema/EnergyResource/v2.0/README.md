# EnergyResource — v2.0

Item attributes for energy resources in P2P trading — source type and source meter identifier.

Part of the [DEG Schema](../../../specification/schema/) · [EnergyResource](../README.md)

## Files

| File | Description |
|------|-------------|
| [attributes.yaml](./attributes.yaml) | JSON Schema 2020-12 definition for `EnergyResource` |
| [context.jsonld](./context.jsonld) | JSON-LD context (namespace: `https://schema.beckn.io/deg/EnergyResource/v2.0/`) |
| [vocab.jsonld](./vocab.jsonld) | RDF vocabulary for `EnergyResource` terms |

## Properties

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `sourceType` | `string` enum | | `SOLAR` \| `BATTERY` \| `GRID` \| `HYBRID` \| `RENEWABLE` |
| `meterId` | `string` | | Source meter in DER address format `der://meter/{id}` |

## Changes from v0.3

- Extracted from combined `EnergyTrade/v0.3/attributes.yaml` into standalone schema
- Published as JSON Schema 2020-12 (was OpenAPI 3.1 component)
