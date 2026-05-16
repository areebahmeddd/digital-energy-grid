# BecknResourceRef

Content-addressed, BPP-hosted reference for delivering bulk JSON bodies off-protocol while keeping the on-protocol payload small and tamper-evident.

**Canonical IRI:** `https://schema.beckn.io/BecknResourceRef/v1.0`

**Namespace prefix:** `brr:` → `https://schema.beckn.io/core/v2.0/`

---

## Versions

| Version | Status | Notes |
|---------|--------|-------|
| [v1.0](./v1.0/) | Current | Initial — covers participatingMetersRef / vendorDevicesRef / metersRef use sites in demand-flex; reusable across DEG. |

---

## Properties

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `uri` | string (URI) | ✓ | HTTPS URL the receiver fetches. |
| `contentHash` | `sha256:<64-hex>` | ✓ | SHA-256 of the canonicalized body. The Beckn signature on the parent message commits the BPP to this exact hash. |
| `count` | integer | ✓ | Element count in the referenced collection (cheap pre-fetch cross-check). |
| `contentType` | string | | Defaults to `application/ld+json`. |
| `schemaContext` | string (URI) | | JSON-LD `@context` URL the body conforms to. |
| `expiresAt` | string (RFC 3339) | | Useful for signed-URL implementations. |
| `sizeBytes` | integer | | Pre-fetch budget hint. |

---

## When to use

- A collection is too large for both inline and paged-inline delivery — bind the on-protocol commitment to the body via `contentHash` and let the receiver fetch out-of-band.
- Two layers of guarantees: **integrity** (via `contentHash`, in spec), **access control** (signed URL / OAuth / mutual TLS, out of spec — BPP's call).

For paged on-protocol delivery (`pageInfo`), see [BecknPageInfo](../BecknPageInfo/). The two are mutually exclusive on a given collection.
