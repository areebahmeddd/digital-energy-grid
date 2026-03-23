# Energy Profile Credential

## Overview

The **Energy Profile Credential** is a unified W3C Verifiable Credential that combines five equal-level profile sections into a single `credentialSubject` object. The consumer's DID (`id`) appears once at the top level, and the five profiles sit as equal-level sibling properties.

## Credential Structure

```
credentialSubject
├── id                    (consumer DID — declared once)
├── consumerProfile       (identity: meter, consumer number, masked ID)
├── consumerDetails       (name, address, connection date)
├── consumptionProfile    (premises, connection type, load, tariff)
├── generationProfile     (DER type, capacity, commissioning)
└── storageProfile        (battery capacity, power rating, type)
```

### consumerProfile
Core consumer identity fields:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `consumerNumber` | string | Yes | Full consumer account number assigned by the utility |
| `meterNumber` | string | Yes | Unique meter serial number |
| `maskedIdNumber` | string | No | Masked government ID for privacy-preserving verification |

### consumerDetails
Personal and address information:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `fullName` | string | Yes | Full name of the customer as per ID proof |
| `installationAddress` | object | Yes | Address of the installation (fullAddress, city, district, stateProvince, postalCode, country) |
| `serviceConnectionDate` | date | Yes | Date when the connection was activated |

### consumptionProfile
Connection and consumption characteristics:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `premisesType` | enum | Yes | Residential, Commercial, Industrial, or Agricultural |
| `connectionType` | enum | Yes | Single-phase or Three-phase |
| `sanctionedLoadKW` | number | Yes | Sanctioned electrical load in kW |
| `tariffCategoryCode` | string | Yes | Billing/tariff category code |

### generationProfile
DER generation capability:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `assetId` | string | No | Unique identifier for the generation asset |
| `generationType` | enum | Yes | Solar, Wind, MicroHydro, or Other |
| `capacityKW` | number | Yes | Installed generation capacity in kW |
| `commissioningDate` | date | Yes | Date when the system was activated |
| `manufacturer` | string | No | Equipment manufacturer |
| `modelNumber` | string | No | Equipment model number |

### storageProfile
Battery/energy storage capability:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `assetId` | string | No | Unique identifier for the storage asset |
| `storageCapacityKWh` | number | Yes | Storage capacity in kWh |
| `powerRatingKW` | number | Yes | Charge/discharge power rating in kW |
| `commissioningDate` | date | Yes | Date when the system was activated |
| `storageType` | enum | No | LithiumIon, LeadAcid, FlowBattery, or Other |

## Files

| File | Description |
|------|-------------|
| `context.jsonld` | JSON-LD context defining semantic mappings for all five profile sections |
| `schema.json` | JSON Schema (draft 2020-12) for credential validation |
| `example.json` | Sample credential with all five profiles populated |

## Issuer

This credential is issued by electricity distribution utilities identified by their DID (`did:web:`) and regulatory license number.

## Revocation

Credential revocation is managed via the DeDi Registry (`dediregistry` status type).
