# ProgramEnrollmentCredential

Verifiable Credential for energy program enrollment. Issued by distribution utilities when consumers enroll in programs such as P2P energy trading, demand flexibility, virtual power plants, or time-of-use tariffs.

**Canonical IRI:** `https://schema.beckn.io/ProgramEnrollmentCredential/v2.0`

**Namespace prefix:** `deg:` → `https://schema.beckn.io/deg/ProgramEnrollmentCredential/v2.0/`

**Tags:** `energy` · `credential` · `verifiable-credential` · `program-enrollment`

---

## Versions

| Version | Status | Notes |
|---------|--------|-------|
| [v2.0](./v2.0/) | Current | Migrated from energy-credentials/program-enrollment-vc |

---

## Inheritance

```
beckn:Credential
  └── deg:EnergyCredential
        └── deg:ProgramEnrollmentCredential  ← this schema
```

---

## credentialSubject Properties

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `id` | `string` (URI) | ✅ | DID of the consumer/credential subject |
| `consumerNumber` | `string` | ✅ | Consumer account number |
| `programName` | `string` | ✅ | Human-readable program name (e.g., "Peer-to-Peer Energy Trading") |
| `programCode` | `string` | ✅ | Unique program identifier code |
| `enrollmentDate` | `string` (date) | ✅ | Date when consumer enrolled in the program |
| `fullName` | `string` | | Consumer name (optional) |
| `validUntil` | `string` (date) | | Enrollment expiration date (optional) |

---

## Linked Data

| Term | IRI |
|------|-----|
| `ProgramEnrollmentCredential` | `deg:ProgramEnrollmentCredential` |
| `programName` | `deg:programName` |
| `programCode` | `deg:programCode` |
| `enrollmentDate` | `deg:enrollmentDate` |
| `validUntil` | `schema:validUntil` |

---

## Usage

Issued by electricity distribution utilities when consumers are enrolled in special energy programs. Used for:
- Verifying eligibility for P2P trading, demand flexibility, VPP, or ToU programs
- On-chain proof of program participation in beckn flows
- Regulatory compliance and audit trails
