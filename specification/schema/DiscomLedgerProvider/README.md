# DiscomLedgerProvider

Identity attributes for a regulated discom ledger Technical Service Provider (TSP), used on `buyerDiscom` and `sellerDiscom` participants in a DEG contract.

**Canonical IRI:** `https://schema.nfh.global/DiscomLedgerProvider/v1.0`

**Namespace prefix:** `deg:` → `https://schema.nfh.global/deg/DiscomLedgerProvider/v1.0/`

---

## Versions

| Version | Status | Notes |
|---------|--------|-------|
| [v1.0](./v1.0/) | Current | Initial version. Identity and endpoint for a discom ledger TSP. |

---

## Properties

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `subscriberId` | `string` | ✓ | The discom node's beckn subscriber id (routing/signing). |
| `discomUri` | `URI` | ✓ | Base URL of the discom's own Beckn platform (init/cascade + allocation). |
| `ledgerId` | `string` | ✓ | Subscriber id of the discom's ledger TSP (a distinct party). |
| `ledgerUri` | `URI` | ✓ | Base URL of the discom ledger TSP endpoint. |

The participant `id` is the discom's UPADHI short code (e.g. `PVVNL`); the beckn routing identity is the `subscriberId` attribute.
