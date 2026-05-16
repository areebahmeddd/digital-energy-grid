# DER

Distributed Energy Resource — a controllable / observable energy asset behind a grid meter (EV chargers, batteries, solar PV, smart HVAC, water heaters, …).

**Canonical IRI:** `https://schema.beckn.io/DER/v1.0`

**Namespace prefix:** `der:` → `https://schema.beckn.io/deg/`

---

## Versions

| Version | Status | Notes |
|---------|--------|-------|
| [v1.0](./v1.0/) | Current | Initial — stable identity + rated dimensioning; per-event state lives in BecknTimeSeries telemetry. |

---

## Properties

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `derId` | string (URI) | ✓ | `der://<derType>/<id>` |
| `derType` | string | ✓ | Asset class (`EV_CHARGER`, `BATTERY`, `SOLAR_PV`, …) |
| `behindMeter` | string | ✓ | URI of the grid meter this DER sits behind |
| `make` / `model` | string | | Manufacturer info |
| `ratedPowerKw` | number | | Rated peak dispatchable power |
| `energyCapacityKwh` | number | | Rated stored-energy capacity (storage DERs only) |
| `telemetryProvider` | string | | Vendor API / data-source for this DER's telemetry |
| `derAttributes` | object | | Type-specific extensible bag |

---

## When to use

- A DEG contract enumerates the assets a seller is dispatching (demand-flex offers, P2P-trading enrollments, EV-charging service catalogs).
- Each asset sits behind a grid meter (`behindMeter` FK) and carries identity + rated dimensioning.
- For per-event STATE (current SOC, instantaneous power, GPS at time T) use [BecknTimeSeries](../BecknTimeSeries/) on the performance record — DER is the static frame, BecknTimeSeries is the moving picture.

See [v1.0/README.md](./v1.0/README.md) for the full property table, URI scheme, and embedding pattern.
