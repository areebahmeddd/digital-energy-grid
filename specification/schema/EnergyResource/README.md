# EnergyResource

Canonical, technology-neutral class for any asset that produces, consumes, stores, or modulates energy — solar PV, wind, batteries / BESS, EVs and EVSE/V2G, controllable loads, the metering and connection points that anchor them, and aggregate sites that contain other resources.

`EnergyResource` is the shared asset-description class used by every DEG domain schema — P2P-trading, demand-flex, EV-charging, and ElectricityCredential all reference it to describe the physical asset a transaction or credential is about.

**Canonical IRI:** `https://schema.nfh.global/EnergyResource/v2.0`

**Namespace prefix:** `deg:` → `https://schema.nfh.global/deg/EnergyResource/v2.0/`

**Tags:** `energy-trade` · `p2p-trading` · `demand-flex` · `item` · `energy-resource`

---

## Versions

| Version | Status | Notes |
|---------|--------|-------|
| [v2.0](./v2.0/) | Current | Canonical class — `resourceId`, `resourceType`, plus optional dimensioning (`make`, `model`, `ratedPowerKw`, `energyCapacityKwh`), provenance (`telemetryProvider`), extensibility (`resourceAttributes`), and topology (`subResources` + `parentResources`). Original `{sourceType, meterId}` shape was replaced in this revision — see [v2.0/README.md](./v2.0/README.md). Absorbs the short-lived `DER/v1.0/` schema. |
| [v0.3](./v0.3/) | Deprecated | Original definition as a component in `EnergyTrade/v0.3/attributes.yaml`. Still referenced by P2P-trading wave1 fixtures via the `deg-1.0.1` tag. |

---

## Properties (v2.0)

No field is `required` at the schema level — domain profiles (demand-flex's network rego, p2p-trading's item gates) enforce their own cross-field expectations.

### Identity + rated dimensioning

| Property | Type | Description |
|----------|------|-------------|
| `resourceId` | string | Stable identifier; recommended URI scheme `der://<type>/<id>`. |
| `resourceType` | string (open) | Open-string asset class — `SOLAR`, `SOLAR_PV`, `WIND`, `BIOGAS`, `EV_CHARGER`, `EV_V2G`, `BATTERY`, `BESS`, `SMART_HVAC`, `SMART_WATER_HEATER`, `CONTROLLABLE_LOAD`, `GRID`, `GRID_METER`, … |
| `make` / `model` | string | Manufacturer info. |
| `ratedPowerKw` | number ≥0 | Rated peak dispatchable power. |
| `energyCapacityKwh` | number ≥0 | Rated stored-energy capacity (storage-class only). |
| `telemetryProvider` | string | Vendor API / data-source identifier supplying telemetry. |
| `resourceAttributes` | object (open) | Type-specific extensible bag. |

### Topology

| Property | Type | Description |
|----------|------|-------------|
| `subResources` | array | Child resources. Each item is either a bare `resourceId` (FK to a sibling EnergyResource) or an inline-nested EnergyResource. |
| `parentResources` | array of strings | Parent resources — `resourceId`s this resource sits behind (typically a meter or aggregation point). String-form only; parents are enumerated elsewhere. |

---

## Linked Data

| Term | IRI |
|------|-----|
| `EnergyResource` | `deg:EnergyResource` |
| `resourceId` | `deg:resourceId` |
| `resourceType` | `deg:resourceType` |
| `make` | `deg:make` |
| `model` | `deg:model` |
| `ratedPowerKw` | `deg:ratedPowerKw` |
| `energyCapacityKwh` | `deg:energyCapacityKwh` |
| `telemetryProvider` | `deg:telemetryProvider` |
| `resourceAttributes` | `deg:resourceAttributes` |
| `subResources` | `deg:subResources` |
| `parentResources` | `deg:parentResources` |

---

## Usage

- **P2P-trading**: attached to `Item.itemAttributes` (or `Resource.resourceAttributes` for inter-DISCOM flows). Carries `{resourceId, resourceType}` to identify the asset being sold. Resource-type verification occurs at onboarding but may change post-onboarding (e.g., switching from solar to diesel). Resource type influences pricing but not workflow.
- **Demand-flex**: attached as objects in `offerAttributes.inputs[seller].inputs.energyResources[]` on the seller's commitment. Uses the identity + dimensioning fields plus `parentResources[]` to point each DER back at its grid meter (enumerated in `participatingMeters[*]`). The settlement rego ignores resources entirely (settlement is on grid-meter actuals); these objects exist for proof-of-performance and reconciliation. See the [demand-flex devkit](../../../devkits/demand-flex/).
- **Future domains** (EV-charging, distribution-grid management) reuse the same class.

For full property tables, embedding patterns, and worked examples, see [v2.0/README.md](./v2.0/README.md).
