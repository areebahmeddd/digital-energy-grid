# Energy Profile Vocabulary

**Namespace URI:** `https://nfh-trust-labs.github.io/vc-schemas/energy-credentials/energy-profile-vc/context.jsonld#`
**Preferred Prefix:** `energy`

This document defines all terms introduced by the Energy Profile Verifiable Credential specification. Terms reused from external vocabularies (schema.org, XSD) are noted accordingly.

---

## Classes

| Term | IRI | Description |
|------|-----|-------------|
| `ElectricityCredential` | `energy:ElectricityCredential` | A Verifiable Credential issued by an electricity distribution utility attesting to a customer's energy profile |
| `UtilityIssuer` | `energy:UtilityIssuer` | An electricity distribution utility that issues credentials |

---

## Properties — Customer Profile

| Term | IRI | Range | Description |
|------|-----|-------|-------------|
| `customerProfile` | `energy:customerProfile` | Object | Top-level property grouping core customer identity fields |
| `customerNumber` | `energy:customerNumber` | `xsd:string` | Full customer account number assigned by the utility |
| `meterNumber` | `energy:meterNumber` | `xsd:string` | Unique meter serial number |
| `meterType` | `energy:meterType` | `xsd:string` | Type of electricity meter installed (`Smart`, `Conventional`, `Prepaid`) |
| `maskedIdType` | `energy:maskedIdType` | `xsd:string` | Type of government-issued ID that has been masked (e.g., Aadhaar, SSN, Passport) |
| `maskedIdNumber` | `energy:maskedIdNumber` | `xsd:string` | Masked government ID for privacy-preserving verification (e.g., XXXX-XXXX-1234) |

---

## Properties — Customer Details

| Term | IRI | Range | Description |
|------|-----|-------|-------------|
| `customerDetails` | `energy:customerDetails` | Object | Top-level property grouping customer personal and address information |
| `fullName` | `schema:name` | `xsd:string` | Full name of the customer as per ID proof |
| `serviceConnectionDate` | `energy:serviceConnectionDate` | `xsd:date` | Date when the electricity connection was activated |
| `installationAddress` | `energy:installationAddress` | Object | Address of the electricity installation |
| `fullAddress` | `schema:streetAddress` | `xsd:string` | Complete street address of the installation |
| `city` | `schema:addressLocality` | `xsd:string` | City name |
| `district` | `energy:district` | `xsd:string` | District or county name |
| `stateProvince` | `schema:addressRegion` | `xsd:string` | State, province, or region name |
| `postalCode` | `schema:postalCode` | `xsd:string` | Postal or ZIP code |
| `country` | `schema:addressCountry` | `xsd:string` | ISO 3166-1 alpha-2 country code |

---

## Properties — Consumption Profile

| Term | IRI | Range | Description |
|------|-----|-------|-------------|
| `consumptionProfile` | `energy:consumptionProfile` | Object | Top-level property grouping connection and consumption characteristics |
| `premisesType` | `energy:premisesType` | `xsd:string` | Type of premises (`Residential`, `Commercial`, `Industrial`, `Agricultural`) |
| `connectionType` | `energy:connectionType` | `xsd:string` | Type of electrical connection (`Single-phase`, `Three-phase`) |
| `sanctionedLoadKW` | `energy:sanctionedLoadKW` | `xsd:decimal` | Sanctioned/approved electrical load in kilowatts (kW) |
| `tariffCategoryCode` | `energy:tariffCategoryCode` | `xsd:string` | Billing/tariff category code assigned by the utility |

---

## Properties — Generation Profile

| Term | IRI | Range | Description |
|------|-----|-------|-------------|
| `generationProfile` | `energy:generationProfile` | Object | Top-level property grouping DER generation capability |
| `assetId` | `energy:assetId` | `xsd:string` | Unique identifier for the generation asset |
| `generationType` | `energy:generationType` | `xsd:string` | Type of distributed energy generation (`Solar`, `Wind`, `MicroHydro`, `Other`) |
| `capacityKW` | `energy:capacityKW` | `xsd:decimal` | Installed generation capacity in kilowatts (kW) |
| `commissioningDate` | `energy:commissioningDate` | `xsd:date` | Date when the generation system was activated |
| `manufacturer` | `schema:manufacturer` | `xsd:string` | Equipment manufacturer |
| `modelNumber` | `energy:modelNumber` | `xsd:string` | Equipment model number |

---

## Properties — Storage Profile

| Term | IRI | Range | Description |
|------|-----|-------|-------------|
| `storageProfile` | `energy:storageProfile` | Object | Top-level property grouping battery/energy storage capability |
| `assetId` (storage) | `energy:storageAssetId` | `xsd:string` | Unique identifier for the storage asset |
| `storageCapacityKWh` | `energy:storageCapacityKWh` | `xsd:decimal` | Battery storage capacity in kilowatt-hours (kWh) |
| `powerRatingKW` | `energy:powerRatingKW` | `xsd:decimal` | Battery charge/discharge power rating in kilowatts (kW) |
| `commissioningDate` (storage) | `energy:storageCommissioningDate` | `xsd:date` | Date when the storage system was activated |
| `storageType` | `energy:storageType` | `xsd:string` | Type of battery storage technology (`LithiumIon`, `LeadAcid`, `FlowBattery`, `Other`) |

---

## Properties — Issuer

| Term | IRI | Range | Description |
|------|-----|-------|-------------|
| `name` | `schema:name` | `xsd:string` | Name of the distribution utility |
| `licenseNumber` | `energy:licenseNumber` | `xsd:string` | Regulatory license number issued by the local energy regulator |

---

## External Vocabularies Used

| Prefix | Namespace | Usage |
|--------|-----------|-------|
| `schema` | `https://schema.org/` | `name`, `streetAddress`, `addressLocality`, `addressRegion`, `postalCode`, `addressCountry`, `manufacturer` |
| `xsd` | `http://www.w3.org/2001/XMLSchema#` | Datatypes: `string`, `decimal`, `date` |
