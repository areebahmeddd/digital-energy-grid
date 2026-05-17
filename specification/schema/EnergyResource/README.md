# EnergyResource

Canonical, technology-neutral class for any asset that produces, consumes, stores, or modulates energy — solar PV, wind, batteries / BESS, EVs and EVSE/V2G, controllable loads, the metering and connection points that anchor them, and aggregate sites that contain other resources.

Per the [DEG Hourglass architecture](https://github.com/beckn/DEG/issues/119), `EnergyResource` is one of the five core primitives at the neck of the hourglass — every higher-layer schema (P2P-trading, demand-flex, EV-charging, …) converges on this class to describe the assets a contract is about.

**Canonical IRI:** `https://schema.beckn.io/EnergyResource/v2.0`

**Namespace prefix:** `deg:` → `https://schema.beckn.io/deg/EnergyResource/v2.0/`

**Tags:** `energy-trade` · `p2p-trading` · `demand-flex` · `item` · `energy-resource`

---

## Versions

| Version | Status | Notes |
|---------|--------|-------|
| [v2.0](./v2.0/) | Current | Additive merge — original `{sourceType, meterId}` shape kept; new identity (`resourceId`, `resourceType`), dimensioning (`make`, `model`, `ratedPowerKw`, `energyCapacityKwh`), provenance (`telemetryProvider`), extensibility (`resourceAttributes`), and topology (`subResources`) fields added as optional. Absorbs the short-lived `DER/v1.0/` schema. |
| [v0.3](./v0.3/) | Deprecated | Original definition as a component in `EnergyTrade/v0.3/attributes.yaml`. Still referenced by P2P-trading wave1 fixtures via the `deg-1.0.1` tag. |

---

## Properties (v2.0)

No field is `required` at the schema level — domain profiles (demand-flex's network rego, p2p-trading's item gates) enforce their own cross-field expectations.

### Backward-compat (P2P-trading wave2)

| Property | Type | Description |
|----------|------|-------------|
| `sourceType` | enum | `SOLAR` \| `BATTERY` \| `GRID` \| `HYBRID` \| `RENEWABLE`. Closed set used by P2P-trading. |
| `meterId` | string | Identifier of the meter associated with this resource. Typically `der://meter/<id>`. |

### Identity + rated dimensioning (new)

| Property | Type | Description |
|----------|------|-------------|
| `resourceId` | string | Stable identifier; recommended URI scheme `der://<type>/<id>`. |
| `resourceType` | string (open) | Open-string asset class — `EV_CHARGER`, `EV_V2G`, `BATTERY`, `BESS`, `SOLAR_PV`, `WIND`, `BIOGAS`, `SMART_HVAC`, `SMART_WATER_HEATER`, `CONTROLLABLE_LOAD`, `GRID`, … |
| `make` / `model` | string | Manufacturer info. |
| `ratedPowerKw` | number ≥0 | Rated peak dispatchable power. |
| `energyCapacityKwh` | number ≥0 | Rated stored-energy capacity (storage-class only). |
| `telemetryProvider` | string | Vendor API / data-source identifier supplying telemetry. |
| `resourceAttributes` | object (open) | Type-specific extensible bag. |

### Topology

| Property | Type | Description |
|----------|------|-------------|
| `subResources` | array | Child resources. Each item is either a bare `resourceId` (FK to a sibling EnergyResource) or an inline-nested EnergyResource. |

---

## Linked Data

| Term | IRI |
|------|-----|
| `EnergyResource` | `deg:EnergyResource` |
| `sourceType` | `deg:sourceType` |
| `meterId` | `deg:meterId` |
| `resourceId` | `deg:resourceId` |
| `resourceType` | `deg:resourceType` |
| `make` | `deg:make` |
| `model` | `deg:model` |
| `ratedPowerKw` | `deg:ratedPowerKw` |
| `energyCapacityKwh` | `deg:energyCapacityKwh` |
| `telemetryProvider` | `deg:telemetryProvider` |
| `resourceAttributes` | `deg:resourceAttributes` |
| `subResources` | `deg:subResources` |
| `SOLAR` | `deg:SourceTypeSolar` |
| `BATTERY` | `deg:SourceTypeBattery` |
| `GRID` | `deg:SourceTypeGrid` |
| `HYBRID` | `deg:SourceTypeHybrid` |
| `RENEWABLE` | `deg:SourceTypeRenewable` |

---

## Usage

- **P2P-trading**: attached to `Item.itemAttributes` (or `Resource.resourceAttributes` for inter-DISCOM flows). Carries the minimal `{sourceType, meterId}` shape. Source-type verification occurs at onboarding but may change post-onboarding (e.g., switching from solar to diesel). Source type influences pricing but not workflow.
- **Demand-flex**: attached as objects in `offerAttributes.inputs[seller].inputs.energyResources[]` on the seller's commitment. Uses the identity + dimensioning fields. The settlement rego ignores resources entirely (settlement is on grid-meter actuals); these objects exist for proof-of-performance and reconciliation. See the [demand-flex devkit](../../../devkits/demand-flex/).
- **Future domains** (EV-charging, distribution-grid management) reuse the same class.

For full property tables, embedding patterns, and worked examples, see [v2.0/README.md](./v2.0/README.md).
