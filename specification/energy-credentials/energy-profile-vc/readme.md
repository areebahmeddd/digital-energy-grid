# Energy Profile Credential

## Overview

The **Energy Profile Credential** is a unified W3C Verifiable Credential that combines five equal-level subjects into a single credential using the `credentialSubject` array pattern from the W3C VC Data Model. It consolidates what was previously four separate credentials (Utility Customer, Consumption Profile, Generation Profile, Storage Profile) into one cohesive energy profile.

## Credential Structure

The `credentialSubject` is an array of five equal-level subjects, each identified by `type` and linked to the same consumer DID via `id`.

### ConsumerProfile
Core consumer identity fields:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | URI (DID) | Yes | DID of the customer/credential subject |
| `type` | string | Yes | `"ConsumerProfile"` |
| `consumerNumber` | string | Yes | Full consumer account number assigned by the utility |
| `meterNumber` | string | Yes | Unique meter serial number |
| `maskedIdNumber` | string | No | Masked government ID for privacy-preserving verification |

### ConsumerDetails
Personal and address information:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | URI (DID) | Yes | DID of the customer/credential subject |
| `type` | string | Yes | `"ConsumerDetails"` |
| `fullName` | string | Yes | Full name of the customer as per ID proof |
| `installationAddress` | object | Yes | Address of the installation (fullAddress, city, district, stateProvince, postalCode, country) |
| `serviceConnectionDate` | date | Yes | Date when the connection was activated |

### ConsumptionProfile
Connection and consumption characteristics:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | URI (DID) | Yes | DID of the customer/credential subject |
| `type` | string | Yes | `"ConsumptionProfile"` |
| `premisesType` | enum | Yes | Residential, Commercial, Industrial, or Agricultural |
| `connectionType` | enum | Yes | Single-phase or Three-phase |
| `sanctionedLoadKW` | number | Yes | Sanctioned electrical load in kW |
| `tariffCategoryCode` | string | Yes | Billing/tariff category code |

### GenerationProfile
DER generation capability:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | URI (DID) | Yes | DID of the customer/credential subject |
| `type` | string | Yes | `"GenerationProfile"` |
| `assetId` | string | No | Unique identifier for the generation asset |
| `generationType` | enum | Yes | Solar, Wind, MicroHydro, or Other |
| `capacityKW` | number | Yes | Installed generation capacity in kW |
| `commissioningDate` | date | Yes | Date when the system was activated |
| `manufacturer` | string | No | Equipment manufacturer |
| `modelNumber` | string | No | Equipment model number |

### StorageProfile
Battery/energy storage capability:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | URI (DID) | Yes | DID of the customer/credential subject |
| `type` | string | Yes | `"StorageProfile"` |
| `assetId` | string | No | Unique identifier for the storage asset |
| `storageCapacityKWh` | number | Yes | Storage capacity in kWh |
| `powerRatingKW` | number | Yes | Charge/discharge power rating in kW |
| `commissioningDate` | date | Yes | Date when the system was activated |
| `storageType` | enum | No | LithiumIon, LeadAcid, FlowBattery, or Other |

## Files

| File | Description |
|------|-------------|
| `context.jsonld` | JSON-LD context defining semantic mappings for all five subject types |
| `schema.json` | JSON Schema (draft 2020-12) for credential validation |
| `example.json` | Sample credential with all five subjects populated |

## Issuer

This credential is issued by electricity distribution utilities identified by their DID (`did:web:`) and regulatory license number.

## Revocation

Credential revocation is managed via the DeDi Registry (`dediregistry` status type).
