# EnergyTradeOrder — v0.3

This is the current version of EnergyTradeOrder. Originally defined as a component inside the combined `EnergyTrade/v0.3/attributes.yaml`.

Order attributes for P2P energy trading — BAP/BPP participant identification and total contracted energy quantity.

Part of the [DEG Schema](../../../README.md) · [EnergyTradeOrder](../README.md)

## Files

| File | Description |
|------|-------------|
| [attributes.yaml](./attributes.yaml) | JSON Schema 2020-12 definition for `EnergyTradeOrder` (extracted from `EnergyTrade/v0.3/`) |
| [context.jsonld](./context.jsonld) | JSON-LD context (namespace: `beckn:` → `EnergyTrade/v0.3/`) |
| [vocab.jsonld](./vocab.jsonld) | RDF vocabulary for `EnergyTradeOrder` terms |

## Properties

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `bap_id` | `string` | ✅ | BAP subscriber ID (buyer platform) |
| `bpp_id` | `string` | ✅ | BPP subscriber ID (seller platform) |
| `total_quantity` | Quantity | | Total energy in kWh (`unitText: kWh`, `unitCode: KWH`) |

## Notes

This schema was originally defined as a component inside the combined `EnergyTrade/v0.3/attributes.yaml`.
It has been extracted here as a standalone versioned schema for reference and backward compatibility.
