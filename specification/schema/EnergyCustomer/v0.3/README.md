# EnergyCustomer — v0.3

> ⚠️ **Deprecated** — `EnergyCustomer` v0.3 is superseded by [`EnergyCustomer/v2.0`](../v2.0/). See [EnergyCustomer root README](../README.md) for details.

Customer attributes for energy flows — meter ID, sanctioned load, and utility account information.

Part of the [DEG Schema](../../../README.md) · [EnergyCustomer](../README.md)

## Files

| File | Description |
|------|-------------|
| [attributes.yaml](./attributes.yaml) | OpenAPI 3.1.1 schema definition for `EnergyCustomer` (extracted from `EnergyTrade/v0.3/`) |
| [context.jsonld](./context.jsonld) | JSON-LD context (namespace: `beckn:` → `EnergyTrade/v0.3/`) |
| [vocab.jsonld](./vocab.jsonld) | RDF vocabulary for `EnergyCustomer` terms |

## Properties

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `meterId` | `string` | ✅ | Meter ID in DER address format (`der://meter/{id}`) |
| `sanctionedLoad` | `number` (kW) | | Approved electrical load capacity |
| `utilityCustomerId` | `string` | | Customer's account number with their utility |
| `utilityId` | `string` | | Utility/DISCOM identifier (e.g., `TPDDL-DL`) for inter-utility trading |

## Notes

This schema was originally defined as a component inside the combined `EnergyTrade/v0.3/attributes.yaml`.
It has been extracted here as a standalone versioned schema for reference and backward compatibility.
