# Customer Credential

## Overview

The **Customer Credential** is a unified W3C Verifiable Credential (VC Data Model 2.0) that combines five equal-level profile sections into a single `credentialSubject` object. The customer's DID (`id`) is optional per the W3C VC Data Model, and the five profiles sit as equal-level sibling properties.

This credential is issued per meter — each meter will have its own credential.

## Credential Structure

```
credentialSubject
├── id                    (optional customer DID)
├── customerProfile       (required — identity: meter, customer number, masked ID)
├── customerDetails       (required — name, address, connection date)
├── consumptionProfile    (optional — premises, connection type, load, tariff)
├── generationProfile     (optional — DER type, capacity, commissioning)
└── storageProfile        (optional — battery capacity, power rating, type)
```

## Validity Period

Per the [W3C VC Data Model 2.0 validity period](https://www.w3.org/TR/2025/REC-vc-data-model-2.0-20250515/#validity-period), this credential uses:

- **`validFrom`** (required) — date and time from which the credential is valid
- **`validUntil`** (optional) — date and time until which the credential is valid

### customerProfile
Core customer identity fields:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `customerNumber` | string | Yes | Full customer account number assigned by the utility |
| `meterNumber` | string | Yes | Unique meter serial number |
| `meterType` | string | Yes | Type of meter (e.g., Smart, Conventional, Prepaid, Bidirectional, Forward, Reverse) |
| `maskedIdType` | string | No | Type of government-issued ID (e.g., SSN, Passport, NationalID) |
| `maskedIdNumber` | string | No | Masked government ID for privacy-preserving verification |

### customerDetails
Personal and address information:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `fullName` | string | Yes | Full name of the customer as per ID proof |
| `installationAddress` | object | Yes | Address of the installation (see below) |
| `serviceConnectionDate` | date | Yes | Date when the electricity connection was activated |

#### installationAddress

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `fullAddress` | string | Yes | Complete street address of the installation |
| `city` | string | No | City name |
| `district` | string | No | District or county name |
| `stateProvince` | string | No | State, province, or region name |
| `postalCode` | string | Yes | Postal or ZIP code (format varies by country) |
| `country` | string | Yes | ISO 3166-1 alpha-2 country code |
| `geo` | object | No | Geographic coordinates (`latitude`, `longitude` in decimal degrees, WGS84) |
| `openLocationCode` | string | No | Open Location Code (OLC) for the installation location |

The address object reuses [schema.org](https://schema.org/) vocabulary (`streetAddress`, `addressLocality`, `addressRegion`, `postalCode`, `addressCountry`, `geo`, `latitude`, `longitude`).

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

This credential is issued by energy providers identified by their URL and optional regulatory license number. Per the [W3C VC Data Model 2.0 issuer specification](https://www.w3.org/TR/2025/REC-vc-data-model-2.0-20250515/#issuer), the issuer uses the standard `issuer` property with `id` (URL) and `name`, plus an optional `licenseNumber`.

## Revocation

Credential revocation is managed via the DeDi Registry (`dediregistry` status type).
