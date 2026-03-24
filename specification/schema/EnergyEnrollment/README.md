# EnergyEnrollment

> **Canonical IRI:** [`https://schema.beckn.io/EnergyEnrollment`](https://schema.beckn.io/EnergyEnrollment)
> **Tags:** `energy, enrollment, program, vpp, demand-response, p2p, credentials, w3c-vc, beckn, deg`
> **Namespace:** `https://schema.beckn.io/`
> Part of the [DEG Schema](../../README.md)

---

**Credential-based program enrollment attributes** for Digital Energy Programs (VPPs, demand response, P2P trading, community solar, special tariffs). Composes with the core Beckn `Fulfillment` and `Order` entities — attached to `Fulfillment.fulfillmentAttributes` (init requests) and `Order.orderAttributes` (responses and confirmations).

The BPP verifies provided W3C Verifiable Credentials, checks for conflicts with existing enrollments, and issues enrollment credentials without performing initial eligibility or ownership checks.

## Versions

| Version | attributes.yaml | context.jsonld | vocab.jsonld | README |
|---------|----------------|----------------|--------------|--------|
| **v0.2** | [attributes.yaml](./v0.2/attributes.yaml) | [context.jsonld](./v0.2/context.jsonld) | [vocab.jsonld](./v0.2/vocab.jsonld) | [README](./v0.2/README.md) |
| **v2.0** | [attributes.yaml](./v2.0/attributes.yaml) | [context.jsonld](./v2.0/context.jsonld) | [vocab.jsonld](./v2.0/vocab.jsonld) | [README](./v2.0/README.md) |

## Properties (latest: v2.0)

| Property | Type | Required | Description |
|----------|------|:--------:|-------------|
| `userAuth` | `UserAuthRequest` \| `UserAuthResponse` | — | User authentication for enrollment verification (OTP or OAuth2/OIDC). |
| `meters` | `array<MeterEnrollment>` | — | Array of meter identifiers to enroll in the program. |
| `ders` | `array<DEREnrollment>` | — | Array of Distributed Energy Resource identifiers to enroll. |
| `credentials` | `array<VerifiableCredential>` | — | W3C Verifiable Credentials provided by calling entity (init request). |
| `existingEnrollments` | `array<VerifiableCredential>` | — | Existing enrollment credentials for conflict checking (init request). |
| `credentialVerification` | `CredentialVerification` | — | Results of credential verification performed by BPP (on_init response). |
| `conflictCheck` | `ConflictCheck` | — | Results of conflict checking with existing enrollments (on_init response). |
| `enrollmentId` | `string` | — | Unique enrollment identifier assigned by BPP (on_confirm response). |
| `status` | `string` (enum) | — | Enrollment lifecycle state: `ACTIVE`, `PENDING`, `CANCELLED`, `SUSPENDED`. |
| `programId` | `string` | — | Identifier of the digital energy program. |
| `startDate` | `string` (date-time) | — | Date and time when enrollment becomes active (ISO 8601 UTC). |
| `endDate` | `string` (date-time) | — | Date and time when enrollment expires or ends (ISO 8601 UTC). |
| `enrolledAt` | `string` (date-time) | — | Timestamp when enrollment was confirmed and logged by BPP. |
| `credential` | `VerifiableCredential` | — | Signed enrollment credential issued by BPP (on_confirm response). |
| `updateType` | `string` (enum) | — | Type of update: `CONSENT_REVOCATION`, `UNENROLLMENT`. |
| `consentRevocation` | `ConsentRevocation` | — | Consent revocation details (update request/response). |
| `unenrollment` | `Unenrollment` | — | Unenrollment details (update request/response). |

## Linked Data

| Resource | URL |
|----------|-----|
| Canonical IRI | `https://schema.beckn.io/EnergyEnrollment` |
| JSON Schema (latest) | `https://schema.beckn.io/EnergyEnrollment/v2.0` |
| context.jsonld (latest) | `https://schema.beckn.io/EnergyEnrollment/v2.0/context.jsonld` |
| vocab.jsonld (latest) | `https://schema.beckn.io/EnergyEnrollment/v2.0/vocab.jsonld` |
| Root context.jsonld | `https://schema.beckn.io/context.jsonld` |
| Root vocab.jsonld | `https://schema.beckn.io/vocab.jsonld` |
