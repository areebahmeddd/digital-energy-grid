# Utility Program Enrollment Credential

This credential is issued by electricity distribution utilities when a consumer enrolls in an energy program. Programs can include peer-to-peer trading, demand flexibility, virtual power plants, and other grid services.

## Use Cases

- **P2P Energy Trading**: Consumer is authorized to trade excess solar energy with neighbors
- **Demand Flexibility**: Consumer agrees to reduce consumption during peak hours for incentives
- **Virtual Power Plant**: Consumer's DER assets are aggregated for grid services
- **Time of Use**: Consumer opts into time-based pricing programs
- **Net Metering**: Consumer is enrolled in net metering for solar exports

## Credential Structure

```
credentialSubject
├── id                    (optional customer DID)
├── customerProfile       (optional: customer number, meter, masked ID)
├── customerDetails       (optional: name, address, connection date)
├── programName           (required)
├── programCode           (required)
├── enrollmentDate        (required)
└── enrollmentValidUntil  (optional)
```

## Validity Period

Per the [W3C VC Data Model 2.0 validity period](https://www.w3.org/TR/2025/REC-vc-data-model-2.0-20250515/#validity-period), this credential uses:

- **`validFrom`** (required) — date and time from which the credential is valid
- **`validUntil`** (optional) — date and time until which the credential is valid

### customerProfile (optional)
Core customer identity fields — same structure as [Electricity Credential](../electricity-credential/):

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `customerNumber` | string | Yes | Full customer account number assigned by the utility |
| `meterNumber` | string | No | Unique meter serial number |
| `meterType` | enum | No | Smart, Conventional, or Prepaid |
| `maskedIdType` | string | No | Type of government-issued ID (e.g., Aadhaar, SSN, Passport) |
| `maskedIdNumber` | string | No | Masked government ID for privacy-preserving verification |

### customerDetails (optional)
Personal and address information — same structure as [Electricity Credential](../electricity-credential/):

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `fullName` | string | Yes | Full name of the customer as per ID proof |
| `installationAddress` | object | No | Address of the installation |
| `serviceConnectionDate` | date | No | Date when the electricity connection was activated |

### Enrollment Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `programName` | string | Yes | Human-readable program name |
| `programCode` | string | Yes | Unique program identifier |
| `enrollmentDate` | date | Yes | Date of enrollment |
| `enrollmentValidUntil` | date | No | End date when enrollment expires |

## Files

| File | Description |
|------|-------------|
| `context.jsonld` | JSON-LD context defining semantic mappings |
| `schema.json` | JSON Schema (draft 2020-12) for credential validation |
| `example.json` | Sample P2P trading enrollment credential |

## Issuer

This credential is issued by electricity distribution utilities identified by their URL and regulatory license number. Per the [W3C VC Data Model 2.0 issuer specification](https://www.w3.org/TR/2025/REC-vc-data-model-2.0-20250515/#issuer), the issuer `id` is a URL (e.g., `https://example-utility.com/issuers/energy-dept`).

## Revocation

Credential revocation is managed via the DeDi Registry (`dediregistry` status type).
