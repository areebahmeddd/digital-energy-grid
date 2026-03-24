# EnergyProgramEnrollment

> **Canonical IRI:** [`https://schema.beckn.io/EnergyProgramEnrollment`](https://schema.beckn.io/EnergyProgramEnrollment)
> **Tags:** `energy, enrollment, program, demand-response, vpp, p2p, beckn, deg`
> **Namespace:** `https://schema.beckn.io/`
> Part of the [DEG Schema](../../README.md)

---

**Credential-based program enrollment attributes** for Digital Energy Programs (VPPs, demand response, P2P trading, community solar, special tariffs). Composes with the core Beckn `Fulfillment` and `Contract` entities — attached to `Fulfillment.fulfillmentAttributes` (init requests) and `Contract.orderAttributes` (responses and confirmations).

> **Migration from EnergyEnrollment:** `deg:EnergyProgramEnrollment owl:equivalentClass deg:EnergyEnrollment`. The `EnergyEnrollment/v0.2` and `EnergyEnrollment/v2.0` schemas are deprecated and preserved for backward compatibility. Use `EnergyProgramEnrollment/v2.0` for all new implementations.

## Versions

| Version | attributes.yaml | context.jsonld | vocab.jsonld | README | Status |
|---------|----------------|----------------|--------------|--------|--------|
| **v2.0** | [attributes.yaml](./v2.0/attributes.yaml) | [context.jsonld](./v2.0/context.jsonld) | [vocab.jsonld](./v2.0/vocab.jsonld) | [README](./v2.0/README.md) | ✅ Current |

## Properties (v2.0)

| Property | Type | Required | Description |
|----------|------|:--------:|-------------|
| `userAuth` | `UserAuthRequest` \| `UserAuthResponse` | — | User authentication (OTP or OAuth2/OIDC) for enrollment verification |
| `meters` | `MeterEnrollment[]` | — | Meter identifiers to enroll in the program |
| `ders` | `DER[]` | — | Distributed Energy Resources (DERs) to enroll |
| `credentials` | `VerifiableCredential[]` | — | Verifiable Credentials proving meter ownership, program eligibility, or DER certification |
| `existingEnrollments` | `VerifiableCredential[]` | — | Existing enrollment credentials for conflict checking |
| `credentialVerification` | `CredentialVerification` | — | Results of BPP credential verification |
| `conflictCheck` | `ConflictCheck` | — | Results of conflict checking with existing enrollments |
| `credential` | `VerifiableCredential` | — | Enrollment credential issued upon successful confirmation |
| `consentRevocation` | `ConsentRevocation` | — | Consent revocation request for program data collection |
| `unenrollment` | `Unenrollment` | — | Unenrollment request for active programs |

## Linked Data

| Property | JSON-LD Mapping |
|----------|----------------|
| Class | `deg:EnergyProgramEnrollment rdfs:subClassOf schema:ProgramMembership` |
| Equivalent | `deg:EnergyProgramEnrollment owl:equivalentClass deg:EnergyEnrollment` |
| Root OWL | `beckn:Order owl:equivalentClass beckn:Contract` |
| Namespace | `deg: "https://schema.beckn.io/deg/EnergyProgramEnrollment/v2.0/"` |
