# EnergyResourceInverter v1.0

**Schema ID:** `https://schema.nfh.global/EnergyResourceInverter/v1.0`
**CIM:** `PowerElectronicsConnection` (IEC 61970-302)
**Status:** Current

---

## Overview

`EnergyResourceInverter` is the typed attribute schema for grid-connected power-electronics inverter energy resources (`type = "INVERTER"`).

An `INVERTER` resource is a grid-connected power-electronics converter without a dedicated fuel source. It captures reactive-power and frequency-support capabilities per **IEEE 1547-2018** and **SunSpec DER Models 702–714**.

Typical use cases:
- Standalone battery inverters
- Virtual power plant (VPP) aggregation points
- Grid-forming inverters for microgrid islanding
- Reactive power compensation (STATCOM-like operation)

---

## Files

| File | Description |
|------|-------------|
| [`attributes.yaml`](./attributes.yaml) | OpenAPI 3.1.1 schema — EnergyResourceInverter and its Attributes object |
| [`schema.json`](./schema.json) | Standalone JSON Schema 2020-12 (self-contained) |
| [`context.jsonld`](./context.jsonld) | JSON-LD 1.1 context mapping terms to semantic IRIs |
| [`vocab.jsonld`](./vocab.jsonld) | RDF vocabulary — class and property definitions with CIM / standards seeAlso links |

---

## Type Discriminator

| `type` value | CIM class | Description |
|---|---|---|
| `INVERTER` | `PowerElectronicsConnection` (IEC 61970-302) | Grid-connected power-electronics converter |

---

## Attributes

### Common attributes (EnergyResourceCommonAttributes — all kinds)

| Field | Type | Description |
|-------|------|-------------|
| `make` | string | Manufacturer |
| `model` | string | Model number |
| `ratedPowerKw` | number ≥0 | Rated peak active power, kW — backward compat; prefer `maxExportKw` |
| `maxExportKw` | number ≥0 | Max active power injected to grid, kW. SunSpec 702 `maxW`. CIM: `PowerElectronicsConnection.maxP` (injection) |
| `maxImportKw` | number ≥0 | Max active power absorbed from grid, kW. Set for four-quadrant inverters. CIM: `PowerElectronicsConnection.maxP` (absorption) |
| `telemetryProvider` | string | Telemetry vendor / API identifier |
| `commissioningDate` | string (ISO 8601 date-time) | Date-time commissioned |
| `location` | object (beckn Location/2.0) | `geo` (GeoJSONGeometry) + `address` (PostalAddress) |

### Inverter-specific attributes (IEEE 1547-2018 / SunSpec)

| Field | Type | Standard | Description |
|-------|------|----------|-------------|
| `ratedApparentPowerKva` | number ≥0 | SunSpec 702 `maxVA` | Rated apparent power, kVA. CIM: `ratedS` |
| `maxReactivePowerKvar` | number ≥0 | SunSpec 702 `maxVar` | Max reactive injection (leading / over-excited), kVAr. CIM: `maxQ` |
| `minReactivePowerKvar` | number | SunSpec 702 `maxVarNeg` | Max reactive absorption (lagging); usually negative. CIM: `minQ` |
| `rideThroughCategory` | enum | IEEE 1547-2018 | `CategoryI` (basic) · `CategoryII` (enhanced) · `CategoryIII` (advanced) |
| `operatingMode` | enum | CIM `inverterMode` | `GridFollowing` · `GridForming` · `Standby` |
| `voltVarEnabled` | boolean | IEEE 2030.5 `opModVoltVar` / SunSpec 705 | Volt-VAr curve active |
| `freqDroopEnabled` | boolean | SunSpec 711 / IEEE 1547 Freq-Watt | Frequency-Watt droop active |
| `enterServiceRampTimeSec` | number ≥0 | SunSpec 703 `ESRmpTms` | Ramp-up time after reconnect, seconds |

---

## Examples

**Grid-following inverter (10 kW export, VAr support):**
```json
{
  "id": "did:web:utility.com:assets:inverter:INV-001",
  "type": "INVERTER",
  "attributes": {
    "make": "SMA", "model": "Sunny Tripower 10.0",
    "maxExportKw": 10,
    "ratedApparentPowerKva": 10, "maxReactivePowerKvar": 4.8,
    "operatingMode": "GridFollowing",
    "voltVarEnabled": true,
    "rideThroughCategory": "CategoryII",
    "commissioningDate": "2025-01-15T00:00:00+05:30"
  },
  "parentResources": ["did:web:utility.com:assets:meter:MET-001"]
}
```

**Grid-forming inverter (microgrid, four-quadrant, full IEEE 1547 CategoryIII):**
```json
{
  "id": "did:web:utility.com:assets:inverter:INV-GF-001",
  "type": "INVERTER",
  "attributes": {
    "make": "Schneider Electric", "model": "Conext XW Pro 6848",
    "maxExportKw": 10, "maxImportKw": 10,
    "ratedApparentPowerKva": 12,
    "maxReactivePowerKvar": 6, "minReactivePowerKvar": -6,
    "operatingMode": "GridForming",
    "voltVarEnabled": true, "freqDroopEnabled": true,
    "rideThroughCategory": "CategoryIII",
    "enterServiceRampTimeSec": 30,
    "commissioningDate": "2025-04-01T00:00:00+05:30"
  },
  "parentResources": ["did:web:utility.com:assets:meter:MET-001"]
}
```
