# MeterServiceProfile

Tariff, regulatory load, and connection profile for a single meter connection point.

**Canonical IRI:** `https://schema.beckn.io/MeterServiceProfile/v1.0`  
**CIM:** `cim:UsagePoint` (IEC 61968-9)

---

## Versions

| Version | Status | Notes |
|---------|--------|-------|
| [v1.0](./v1.0/) | Current | Extracted from `ElectricityCredential/v1.2` `ConsumptionProfile`. Backward-compat alias preserved. |

---

## Purpose

`MeterServiceProfile` captures the regulatory connection limits and billing terms associated with a meter connection point. Each profile links to a `METER` resource via `meterId` and is carried inside `ElectricityCredential/v1.2` `consumptionProfiles[]`.

It covers three concerns that `EnergyResourceMeter` intentionally omits (physical asset) and `CustomerDetails` intentionally omits (PII boundary):

- **Regulatory limits** — `sanctionedLoadKw`, `sanctionedExportLoadKw`, `contractMaxDemandKw`
- **Tariff classification** — `tariffCategoryCode`, `premisesType`
- **Connection / billing terms** — `connectionType`, `paymentMode`, `billingCycleDay`

> **Backward compatibility:** `ConsumptionProfile` in `ElectricityCredential/v1.2` is now an alias for `MeterServiceProfile/v1.0`. Existing payloads using that name remain valid.

See [v1.0/README.md](./v1.0/README.md) for the full field table and example.
