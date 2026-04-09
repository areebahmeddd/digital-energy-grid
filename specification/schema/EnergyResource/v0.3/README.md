# EnergyResource — v0.3

> ⚠️ **Deprecated** — `EnergyResource` v0.3 is superseded by [`EnergyResource/v2.0`](../v2.0/). See [EnergyResource root README](../README.md) for details.

Item attributes for energy resources in P2P trading — source type and source meter identifier.

Part of the [DEG Schema](../../../README.md) · [EnergyResource](../README.md)

## Files

| File | Description |
|------|-------------|
| [attributes.yaml](./attributes.yaml) | OpenAPI 3.1.1 schema definition for `EnergyResource` (extracted from `EnergyTrade/v0.3/`) |
| [context.jsonld](./context.jsonld) | JSON-LD context (namespace: `beckn:` → `EnergyTrade/v0.3/`) |
| [vocab.jsonld](./vocab.jsonld) | RDF vocabulary for `EnergyResource` terms |

## Properties

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `sourceType` | `string` enum | | Energy source: `SOLAR` \| `BATTERY` \| `GRID` \| `HYBRID` \| `RENEWABLE` |
| `meterId` | `string` | | Source meter ID in DER address format (`der://meter/{id}`) |

## Notes

This schema was originally defined as a component inside the combined `EnergyTrade/v0.3/attributes.yaml`.
It has been extracted here as a standalone versioned schema for reference and backward compatibility.
