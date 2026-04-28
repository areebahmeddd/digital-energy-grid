# DiscomLimitCheck — v2.0

Optional Phase-2 limit-check performance attributes for inter-discom P2P energy trades.

Part of the [DEG Schema](../../) · [DiscomLimitCheck](../README.md)

## Files

| File | Description |
|------|-------------|
| [attributes.yaml](./attributes.yaml) | OpenAPI 3.1.1 components.schemas.`DiscomLimitCheck` (JSON Schema 2020-12 body) |
| [context.jsonld](./context.jsonld) | JSON-LD context (namespace `https://schema.beckn.io/deg/DiscomLimitCheck/v2.0/`) |

## Properties

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `subject` | `string` enum |  | Which side of the trade this limit check is being requested against. Omitted in on_init... |
| `subjectMeterId` | `string` |  | Source meter identifier in DER address format (der://meter/{id}) for the subject prosumer. |
| `discomParticipantId` | `string` |  | Participant id of the discom ledger. |
| `deliveryWindow` | `object` |  | Delivery window for the limit check (UTC). |
| `tradeQuantity` | `object` |  | Trade quantity being limit-checked (Quantity object with unitCode and unitQuantity). |
| `buyerSide` | `object` |  | Buyer-side limit-check result; populated in on_init responses that report both sides. |
| `sellerSide` | `object` |  | Seller-side limit-check result; populated in on_init responses that report both sides. |
