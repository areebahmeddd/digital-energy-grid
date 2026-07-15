# EnergyResourceGenerator

Typed energy resource schema for generation DERs: solar PV, wind, hydro, biogas, CHP, and fuel cell assets.

`EnergyResourceGenerator` is one of the seven composable kinds that make up `EnergyResource` in the `ElectricityCredential`.

**Canonical IRI:** `https://schema.nfh.global/EnergyResourceGenerator/v1.0`

**CIM alignment:** `cim:GeneratingUnit` and subtypes — `PhotovoltaicUnit`, `WindGeneratingUnit`, `HydroGeneratingUnit`, `ThermalGeneratingUnit` (IEC 61970-301/302)

**Tags:** `energy-resource` · `generation` · `der` · `solar` · `wind` · `energy` · `deg`

---

## Versions

| Version | Status | Notes |
|---------|--------|-------|
| [v1.0](./v1.0/) | Current | Initial typed kind for generation DERs, extracted from `ElectricityCredential/v1.2`. Adds `nominalPowerKw` and `efficiency` fields. `SOLAR` deprecated in favour of `SOLAR_PV`. |

---

## Type discriminators

| `type` value | CIM class | Notes |
|---|---|---|
| `SOLAR_PV` | `cim:PhotovoltaicUnit` | Preferred; replaces deprecated `SOLAR` |
| `SOLAR` | `cim:PhotovoltaicUnit` | **Deprecated** — use `SOLAR_PV` |
| `WIND` | `cim:WindGeneratingUnit` | |
| `HYDRO` | `cim:HydroGeneratingUnit` | |
| `BIOGAS` | `cim:ThermalGeneratingUnit` | |
| `CHP` | `cim:ThermalGeneratingUnit` | Combined heat and power |
| `FUEL_CELL` | IEC 62933-2 fuel cell unit | |

---

## Properties (v1.0)

### Common (EnergyResourceCommonAttributes)

| Property | Type | Description |
|----------|------|-------------|
| `make` | string | Manufacturer name |
| `model` | string | Model number |
| `ratedPowerKw` | number ≥0 | Nameplate peak power, kW. CIM: `GeneratingUnit.maxOperatingP` |
| `maxExportKw` | number ≥0 | Maximum grid export capacity, kW |
| `maxImportKw` | number ≥0 | Maximum grid import capacity, kW |
| `telemetryProvider` | string | Vendor API / data-source for telemetry |
| `commissioningDate` | string (date) | ISO 8601 commissioning date |
| `location` | object | Physical location — `{geo: GeoJSONGeometry, address: Address}` |

### Generator-specific

| Property | Type | CIM alignment | Description |
|----------|------|---------------|-------------|
| `nominalPowerKw` | number ≥0 | `GeneratingUnit.nominalP` | Nominal output power, kW (DC STC for solar PV) |
| `efficiency` | number 0–100 | — | Conversion efficiency, % (most relevant for FUEL_CELL, CHP) |

---

## Usage

- **ElectricityCredential/v1.2**: entries with generator `type` values in `customerProfile.energyResources[]` conform to this schema. Generator DERs reference their parent METER via `parentResources[]`.
- Asset IDs follow the IES DID pattern: `did:web:<discom-domain>:assets:<class>:<local-id>` (e.g. `did:web:bescom.karnataka.gov.in:assets:solar:SOL-001`)

For full property tables and worked examples, see [v1.0/README.md](./v1.0/README.md).
