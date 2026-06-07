# EnergyResourceEVCharger

Typed energy resource schema for EV charging stations. An `EV_CHARGER` resource is the EVSE hardware at the grid connection point — a **flexible load**, not a storage resource. `EV_V2G` is a specialisation with ISO 15118-20 / OCPP 2.1 BPT Vehicle-to-Grid capability.

**Canonical IRI:** `https://schema.beckn.io/EnergyResourceEVCharger/v1.0`

**CIM alignment:** `ElectricVehicleChargingStation` (CIM17+)

**Tags:** `energy-resource` · `ev-charger` · `energy` · `deg`

---

## Versions

| Version | Status | Notes |
|---------|--------|-------|
| [v1.0](./v1.0/) | Current | Initial typed kind for EV_CHARGER and EV_V2G resources. Introduces `connectorType`, `controlProtocol`, `v2xProtocol`. EV charging separated from storage (was previously grouped with BESS). |

---

## Type discriminator

| `type` value | Description |
|---|---|
| `EV_CHARGER` | Unidirectional or AC bidirectional EVSE (flexible load) |
| `EV_V2G` | Vehicle-to-Grid capable EVSE — `EV_CHARGER` specialisation |

---

## Usage

- **ElectricityCredential/v1.2**: entries with `type: "EV_CHARGER"` or `type: "EV_V2G"` in `customerProfile.energyResources[]` conform to this schema.
- For V2G: set `attributes.maxImportKw` (charge rate) and `attributes.maxExportKw` (V2G discharge rate), both ≥0.
- Asset IDs follow the IES DID pattern: `did:web:<domain>:assets:evse:<local-id>`

For full property tables and worked examples, see [v1.0/README.md](./v1.0/README.md).
