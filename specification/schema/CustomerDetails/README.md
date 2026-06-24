# CustomerDetails

PII identity and address details for a utility service customer.

**Canonical IRI:** `https://schema.beckn.io/CustomerDetails/v1.0`  
**CIM:** `cim:Customer` (IEC 61968-1)

---

## Versions

| Version | Status | Notes |
|---------|--------|-------|
| [v1.0](./v1.0/) | Current | Extracted from `ElectricityCredential/v1.2` `customerDetails`. Reusable across any utility credential carrying customer PII. |

---

## Purpose

`CustomerDetails` carries the personally-identifiable information (PII) for a utility customer. It is intentionally kept separate from `CustomerProfile` (which is non-PII) so that credentials can be issued with or without the PII section depending on the data-sharing context.

Three concerns:

- **Identity** — `fullName` (as per ID proof), optional `careOf` (head of household, for disambiguation)
- **Location** — `installationAddress` (GeoJSON + PostalAddress via beckn Location/2.0)
- **Tenure** — `serviceConnectionDate` (when the connection was activated)

> `fullName` appears **only** here — never in `customerProfile` or any `energyResources` entry.

## Usage

Carried as `credentialSubject.customerDetails` in `ElectricityCredential/v1.2`. May be reused by any utility credential (gas, water) that needs to carry customer PII.

See [v1.0/README.md](./v1.0/README.md) for the full field table and example.
