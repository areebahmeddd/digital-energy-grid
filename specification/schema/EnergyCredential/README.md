# EnergyCredential

Base class for all DEG energy-sector Verifiable Credentials issued by electricity distribution utilities.

**Canonical IRI:** `https://schema.beckn.io/EnergyCredential/v2.0`

**Namespace prefix:** `deg:` → `https://schema.beckn.io/deg/EnergyCredential/v2.0/`

**Tags:** `energy` · `credential` · `verifiable-credential`

---

## Versions

| Version | Status | Notes |
|---------|--------|-------|
| [v2.0](./v2.0/) | Current | Initial JSON Schema release |

---

## Inheritance

```
beckn:Credential
  └── deg:EnergyCredential  ← this schema
        ├── deg:ConsumptionProfileCredential
        ├── deg:GenerationProfileCredential
        ├── deg:StorageProfileCredential
        ├── deg:ProgramEnrollmentCredential
        └── deg:UtilityCustomerCredential
```

---

## Properties

`EnergyCredential` adds energy-sector-specific properties to the base `beckn:Credential` envelope:

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `issuer` | `object` | | The electricity distribution utility issuing this credential |
| `issuer.id` | `string` (URI) | ✅ | DID of the issuing utility |
| `issuer.name` | `string` | ✅ | Name of the distribution utility |
| `issuer.licenseNumber` | `string` | ✅ | Regulatory license number from the energy regulator |
| `issuanceDate` | `string` (date-time) | | Timestamp when the credential was issued |
| `expirationDate` | `string` (date-time) | | Optional expiration date |
| `credentialStatus` | `object` | | Revocation status via DeDi registry |
| `credentialStatus.id` | `string` (URI) | ✅ | URL to query revocation status |
| `credentialStatus.type` | `string` (`dediregistry`) | ✅ | Status check mechanism type |
| `proof` | `object` | | Cryptographic proof/signature |

---

## Linked Data

| Term | IRI |
|------|-----|
| `EnergyCredential` | `deg:EnergyCredential` |
| `issuer` | `schema:issuer` |
| `issuanceDate` | `schema:dateCreated` |
| `expirationDate` | `schema:expires` |
| `credentialStatus` | `deg:credentialStatus` |
| `proof` | `sec:proof` |

---

## Subclasses

| Schema | Description |
|--------|-------------|
| [ConsumptionProfileCredential](../ConsumptionProfileCredential/) | Connection and load characteristics credential |
| [GenerationProfileCredential](../GenerationProfileCredential/) | DER generation capability credential |
| [StorageProfileCredential](../StorageProfileCredential/) | Battery/energy storage capability credential |
| [ProgramEnrollmentCredential](../ProgramEnrollmentCredential/) | Energy program enrollment credential |
| [UtilityCustomerCredential](../UtilityCustomerCredential/) | Barebones utility customer identity credential |
