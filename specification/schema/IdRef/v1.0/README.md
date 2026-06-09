# IdRef v1.0

External identity reference — links an issuing authority (DID or URI) to a subject identifier within that authority's namespace.

## Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `issuedBy` | string (URI) | Yes | DID or URI of the issuing authority |
| `subjectId` | string | Yes | Subject identifier in `authority-domain:id-value` format |

`subjectId` pattern: `^[A-Za-z0-9._-]+:[A-Za-z0-9X_-]+$`

## CIM alignment

| Field | CIM |
|-------|-----|
| `issuedBy` | — (DEG-specific; DID-based authority link) |
| `subjectId` | — (DEG-specific; scoped identifier) |

## Minimal example

```json
{
  "issuedBy": "did:example:utility-regulatory-authority",
  "subjectId": "MSEDCL:CA123456789"
}
```

## Usage

`IdRef` is an optional field on customer profiles (`EnergyCustomerProfile`, `ElectricityCredential` v1.1+). It allows a utility to cross-reference a customer account number to an external registry or regulatory body.

## Files

| File | Purpose |
|------|---------|
| `attributes.yaml` | OpenAPI 3.1.1 source of truth |
| `schema.json` | Bundled JSON Schema 2020-12 |
| `context.jsonld` | JSON-LD 1.1 context (flat, importable) |
| `vocab.jsonld` | RDF vocabulary |
| `README.md` | This file |
