# BecknPageInfo

Domain-neutral pagination envelope embedded alongside any collection that needs multi-message delivery.

**Canonical IRI:** `https://schema.beckn.io/BecknPageInfo/v1.0`

**Namespace prefix:** `bpi:` → `https://schema.beckn.io/core/v2.0/`

---

## Versions

| Version | Status | Notes |
|---------|--------|-------|
| [v1.0](./v1.0/) | Current | Initial — covers both BPP-push and BAP-pull patterns. |

---

## Properties

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `sequence` | integer | ✓ | Monotonic page index (0..N-1) within a `(transactionId, collectionId)` pair. |
| `isLast` | boolean | ✓ | `true` on the final page only. Receivers gate aggregate actions on this flag. |
| `pageSize` | integer | | Nominal per-page element count. |
| `total` | integer | | Expected element count across all pages. |
| `cursor` | string | | Opaque page identifier (pull mode). |
| `nextCursor` | string \| null | | Token for next pull request; `null` on final page. |
| `collectionId` | string | | Disambiguates multiple paginated collections in one envelope. |

---

## When to use

- The collection riding the message exceeds the wire budget for a single Beckn payload (rule of thumb: > 10k elements).
- Either the BPP pushes pages back-to-back (no BAP involvement beyond assembly), or the BAP pulls pages via `status` calls carrying a `pageCursor` tag.
- Omit entirely when one message suffices — absence of `pageInfo` is the protocol signal that the message is self-contained.

For collections too large to page sanely on-protocol, see [BecknResourceRef](../BecknResourceRef/) — content-addressed off-protocol delivery.
