# StorageProfileCredential

Verifiable Credential for battery/energy storage capability. Issued by distribution utilities to customers with home batteries, EV batteries, or other storage assets for virtual power plant participation and demand response programs.

**Canonical IRI:** `https://schema.beckn.io/StorageProfileCredential/v2.0`

**Namespace prefix:** `deg:` → `https://schema.beckn.io/deg/StorageProfileCredential/v2.0/`

**Tags:** `energy` · `credential` · `verifiable-credential` · `storage` · `battery`

---

## Versions

| Version | Status | Notes |
|---------|--------|-------|
| [v2.0](./v2.0/) | Current | Migrated from energy-credentials/storage-profile-vc |

---

## Inheritance

```
beckn:Credential
  └── deg:EnergyCredential
        └── deg:StorageProfileCredential  ← this schema
```

---

## credentialSubject Properties

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `id` | `string` (URI) | ✅ | DID of the customer/credential subject |
| `consumerNumber` | `string` | ✅ | Consumer account number |
| `storageCapacityKWh` | `number` | ✅ | Battery storage capacity in kWh (0.1–10000) |
| `powerRatingKW` | `number` | ✅ | Charge/discharge power rating in kW (0.1–10000) |
| `commissioningDate` | `string` (date) | ✅ | Date when storage system was activated |
| `fullName` | `string` | | Consumer name (optional) |
| `meterNumber` | `string` | | Meter serial number (optional) |
| `assetId` | `string` | | Unique storage asset ID (optional) |
| `storageType` | `string` enum | | `LithiumIon`, `LeadAcid`, `FlowBattery`, `Other` (optional) |

---

## Linked Data

| Term | IRI |
|------|-----|
| `StorageProfileCredential` | `deg:StorageProfileCredential` |
| `storageCapacityKWh` | `deg:storageCapacityKWh` |
| `powerRatingKW` | `deg:powerRatingKW` |
| `storageType` | `deg:storageType` |

---

## Usage

Issued by electricity distribution utilities to customers with battery storage. Used for:
- Virtual power plant (VPP) participation
- Demand response and grid balancing
- P2P energy trading with V2G capability
