# GenerationProfileCredential

Verifiable Credential for DER (Distributed Energy Resource) generation capability. Issued by distribution utilities to prosumers with solar, wind, or other generation assets for grid management, net metering, and renewable energy tracking.

**Canonical IRI:** `https://schema.beckn.io/GenerationProfileCredential/v2.0`

**Namespace prefix:** `deg:` → `https://schema.beckn.io/deg/GenerationProfileCredential/v2.0/`

**Tags:** `energy` · `credential` · `verifiable-credential` · `generation` · `der`

---

## Versions

| Version | Status | Notes |
|---------|--------|-------|
| [v2.0](./v2.0/) | Current | Migrated from energy-credentials/generation-profile-vc |

---

## Inheritance

```
beckn:Credential
  └── deg:EnergyCredential
        └── deg:GenerationProfileCredential  ← this schema
```

---

## credentialSubject Properties

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `id` | `string` (URI) | ✅ | DID of the customer/credential subject |
| `consumerNumber` | `string` | ✅ | Consumer account number |
| `generationType` | `string` enum | ✅ | `Solar`, `Wind`, `MicroHydro`, `Other` |
| `capacityKW` | `number` | ✅ | Installed generation capacity in kW (0.1–10000) |
| `commissioningDate` | `string` (date) | ✅ | Date when generation system was activated |
| `fullName` | `string` | | Consumer name (optional) |
| `meterNumber` | `string` | | Meter serial number (optional) |
| `assetId` | `string` | | Unique generation asset ID (optional) |
| `manufacturer` | `string` | | Equipment manufacturer (optional) |
| `modelNumber` | `string` | | Equipment model number (optional) |

---

## Linked Data

| Term | IRI |
|------|-----|
| `GenerationProfileCredential` | `deg:GenerationProfileCredential` |
| `generationType` | `deg:generationType` |
| `capacityKW` | `deg:capacityKW` |
| `commissioningDate` | `deg:commissioningDate` |
| `assetId` | `deg:assetId` |
| `manufacturer` | `schema:manufacturer` |
| `modelNumber` | `schema:model` |

---

## Usage

Issued by electricity distribution utilities to prosumers with generation assets. Used for:
- Grid management and net metering
- Renewable energy certificate tracking
- P2P energy trading eligibility as a seller/provider
