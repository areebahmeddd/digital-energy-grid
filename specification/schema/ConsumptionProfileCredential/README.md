# ConsumptionProfileCredential

Verifiable Credential for electricity connection and consumption characteristics. Issued by distribution utilities to consumers and prosumers for load management and tariff determination.

**Canonical IRI:** `https://schema.beckn.io/ConsumptionProfileCredential/v2.0`

**Namespace prefix:** `deg:` → `https://schema.beckn.io/deg/ConsumptionProfileCredential/v2.0/`

**Tags:** `energy` · `credential` · `verifiable-credential` · `consumption`

---

## Versions

| Version | Status | Notes |
|---------|--------|-------|
| [v2.0](./v2.0/) | Current | Migrated from energy-credentials/consumption-profile-vc |

---

## Inheritance

```
beckn:Credential
  └── deg:EnergyCredential
        └── deg:ConsumptionProfileCredential  ← this schema
```

---

## credentialSubject Properties

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `id` | `string` (URI) | ✅ | DID of the customer/credential subject |
| `consumerNumber` | `string` | ✅ | Consumer account number assigned by the utility |
| `fullName` | `string` | ✅ | Consumer name |
| `premisesType` | `string` enum | ✅ | `Residential`, `Commercial`, `Industrial`, `Agricultural` |
| `connectionType` | `string` enum | ✅ | `Single-phase` or `Three-phase` |
| `sanctionedLoadKW` | `number` | ✅ | Sanctioned/approved electrical load in kW (0.5–10000) |
| `tariffCategoryCode` | `string` | ✅ | Billing/tariff category code |
| `meterNumber` | `string` | | Meter serial number (optional) |

---

## Linked Data

| Term | IRI |
|------|-----|
| `ConsumptionProfileCredential` | `deg:ConsumptionProfileCredential` |
| `consumerNumber` | `deg:consumerNumber` |
| `premisesType` | `deg:premisesType` |
| `connectionType` | `deg:connectionType` |
| `sanctionedLoadKW` | `deg:sanctionedLoadKW` |
| `tariffCategoryCode` | `deg:tariffCategoryCode` |
| `meterNumber` | `deg:meterNumber` |
| `fullName` | `schema:name` |

---

## Usage

Issued by electricity distribution utilities to consumers/prosumers. Used for:
- Load management and demand response
- Tariff determination and billing classification
- P2P energy trading eligibility verification
