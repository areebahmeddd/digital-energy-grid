# DiscomLimitCheck

Optional Phase-2 limit-check performance attributes for inter-discom P2P energy trades.

**Canonical IRI:** `https://schema.beckn.io/DiscomLimitCheck/v2.0`

**Namespace prefix:** `deg:` → `https://schema.beckn.io/deg/DiscomLimitCheck/v2.0/`

---

## Versions

| Version | Status | Notes |
|---------|--------|-------|
| [v2.0](./v2.0/) | Current | Optional Phase-2 limit-check performance attributes for inter-discom P2P trades. |

---

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
