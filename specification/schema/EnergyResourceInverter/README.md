# EnergyResourceInverter

Typed energy resource schema for grid-connected power-electronics inverters. An `INVERTER` resource is a grid-connected converter without a dedicated fuel source — capturing reactive-power and frequency-support capabilities per IEEE 1547-2018 and SunSpec DER Models 702–714.

**Canonical IRI:** `https://schema.nfh.global/EnergyResourceInverter/v1.0`

**CIM alignment:** `PowerElectronicsConnection` (IEC 61970-302)

**Tags:** `energy-resource` · `inverter` · `energy` · `deg`

---

## Versions

| Version | Status | Notes |
|---------|--------|-------|
| [v1.0](./v1.0/) | Current | Initial typed kind for INVERTER resources. Introduces IEEE 1547-2018 ride-through categories, `operatingMode` (GridFollowing / GridForming / Standby), `voltVarEnabled`, `freqDroopEnabled`, reactive power fields, and `enterServiceRampTimeSec`. |

---

## Type discriminator

| `type` value | CIM class | Description |
|---|---|---|
| `INVERTER` | `PowerElectronicsConnection` (IEC 61970-302) | Grid-connected power-electronics converter |

---

## Usage

- **ElectricityCredential/v1.2**: entries with `type: "INVERTER"` in `customerProfile.energyResources[]` conform to this schema.
- Typical use cases: standalone battery inverters, VPP aggregation points, grid-forming inverters for microgrid islanding.
- Asset IDs follow the IES DID pattern: `did:web:<domain>:assets:inverter:<local-id>`

For full property tables and worked examples, see [v1.0/README.md](./v1.0/README.md).
