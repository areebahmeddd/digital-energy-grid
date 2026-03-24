# UtilityCustomerCredential

Barebones identity credential for privacy-preserving customer identification. Issued by distribution utilities as the base identity anchor for all other DEG energy credentials.

**Canonical IRI:** `https://schema.beckn.io/UtilityCustomerCredential/v2.0`

**Namespace prefix:** `deg:` → `https://schema.beckn.io/deg/UtilityCustomerCredential/v2.0/`

**Tags:** `energy` · `credential` · `verifiable-credential` · `identity`

---

## Versions

| Version | Status | Notes |
|---------|--------|-------|
| [v2.0](./v2.0/) | Current | Migrated from energy-credentials/utility-customer-vc |

---

## Inheritance

```
beckn:Credential
  └── deg:EnergyCredential
        └── deg:UtilityCustomerCredential  ← this schema
```

---

## credentialSubject Properties

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `id` | `string` (URI) | ✅ | DID of the customer/credential subject |
| `consumerNumber` | `string` | ✅ | Consumer account number |
| `fullName` | `string` | ✅ | Full name as per ID proof |
| `installationAddress` | `object` | ✅ | Installation address (fullAddress, postalCode, country required) |
| `meterNumber` | `string` | ✅ | Unique meter serial number |
| `serviceConnectionDate` | `string` (date) | ✅ | Date when the connection was activated |
| `maskedIdNumber` | `string` | | Masked government ID (optional, e.g., 'XXXX-XXXX-1234') |

### installationAddress Properties

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `fullAddress` | `string` | ✅ | Complete street address |
| `postalCode` | `string` | ✅ | Postal or ZIP code |
| `country` | `string` (ISO 3166-1 alpha-2) | ✅ | Country code |
| `city` | `string` | | City name |
| `district` | `string` | | District or county name |
| `stateProvince` | `string` | | State, province, or region |

---

## Linked Data

| Term | IRI |
|------|-----|
| `UtilityCustomerCredential` | `deg:UtilityCustomerCredential` |
| `maskedIdNumber` | `deg:maskedIdNumber` |
| `installationAddress` | `deg:installationAddress` |
| `serviceConnectionDate` | `deg:serviceConnectionDate` |
| `fullAddress` | `schema:streetAddress` |
| `city` | `schema:addressLocality` |
| `stateProvince` | `schema:addressRegion` |
| `postalCode` | `schema:postalCode` |
| `country` | `schema:addressCountry` |

---

## Usage

The base identity credential for DEG energy customers. All other profile credentials (Consumption, Generation, Storage, ProgramEnrollment) link to this credential via the `credentialSubject.id` (customer DID).
