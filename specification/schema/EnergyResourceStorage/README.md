# EnergyResourceStorage

Typed energy resource schema for storage DERs: battery energy storage systems (BESS), EV chargers, and vehicle-to-grid (V2G) capable chargers.

`EnergyResourceStorage` is one of the seven composable kinds that make up `EnergyResource` in the `ElectricityCredential`. It is the **only** kind that carries `storageCapacityKwh`.

**Canonical IRI:** `https://schema.nfh.global/EnergyResourceStorage/v1.0`

**CIM alignment:** `cim:BatteryUnit` (BESS/BATTERY), `cim:ElectricVehicleChargingStation` (EV_CHARGER/EV_V2G) — IEC 61970-302

**Tags:** `energy-resource` · `storage` · `bess` · `ev` · `v2g` · `energy` · `deg`

---

## Versions

| Version | Status | Notes |
|---------|--------|-------|
| [v1.0](./v1.0/) | Current | Initial typed kind for storage DERs, extracted from `ElectricityCredential/v1.2`. `storageCapacityKwh` replaces `energyCapacityKwh` from EnergyResource v1.1. Adds `stateOfHealthPct`, `maxChargeRateKw`, `maxDischargeRateKw`. `BATTERY` deprecated in favour of `BESS`. |

---

## Type discriminators

| `type` value | CIM class | Notes |
|---|---|---|
| `BESS` | `cim:BatteryUnit` | Preferred; replaces deprecated `BATTERY` |
| `BATTERY` | `cim:BatteryUnit` | **Deprecated** — use `BESS` |
| `EV_CHARGER` | `cim:ElectricVehicleChargingStation` | Unidirectional charger |
| `EV_V2G` | `cim:ElectricVehicleChargingStation` | Bidirectional, vehicle-to-grid capable |

---

## Properties (v1.0)

### Common (EnergyResourceCommonAttributes)

| Property | Type | Description |
|----------|------|-------------|
| `make` | string | Manufacturer name |
| `model` | string | Model number |
| `ratedPowerKw` | number ≥0 | Nameplate peak power, kW |
| `maxExportKw` | number ≥0 | Maximum grid export capacity, kW (≡ max discharge for BESS) |
| `maxImportKw` | number ≥0 | Maximum grid import capacity, kW (≡ max charge for BESS) |
| `telemetryProvider` | string | Vendor API / data-source for telemetry |
| `commissioningDate` | string (date) | ISO 8601 commissioning date |
| `location` | object | Physical location — `{geo: GeoJSONGeometry, address: Address}` |

### Storage-specific

| Property | Type | CIM alignment | Description |
|----------|------|---------------|-------------|
| `storageCapacityKwh` | number ≥0 | `BatteryUnit.ratedE` | **Storage-only** — rated energy capacity, kWh |
| `storageType` | enum | — | LithiumIon, LeadAcid, FlowBattery, NaS, NiCd, Flywheel, Other |
| `stateOfHealthPct` | number 0–100 | — | Battery SoH as % of original capacity |
| `maxChargeRateKw` | number ≥0 | — | Maximum charge rate, kW |
| `maxDischargeRateKw` | number ≥0 | — | Maximum discharge rate, kW |

---

## v1.1 → v1.2 migration note

`energyCapacityKwh` (on the common attributes in EnergyResource v1.1) was renamed to `storageCapacityKwh` and restricted exclusively to this kind.

---

## Usage

- **ElectricityCredential/v1.2**: entries with storage `type` values in `customerProfile.energyResources[]` conform to this schema. Storage DERs reference their parent METER via `parentResources[]`.
- **Demand-flex**: storage assets are eligible bid resources; `storageCapacityKwh` and `ratedPowerKw` inform bid-curve generation.
- Asset IDs follow the IES DID pattern: `did:web:<discom-domain>:assets:bess:<local-id>`

For full property tables and worked examples, see [v1.0/README.md](./v1.0/README.md).
