# EnergyResourceCommon

Canonical base schemas shared by all typed `EnergyResource` kinds.

**Canonical IRI:** `https://schema.beckn.io/EnergyResourceCommon/v1.0`

---

## Versions

| Version | Status | Notes |
|---------|--------|-------|
| [v1.0](./v1.0/) | Current | Initial release. Contains `EnergyResourceCommon` (structural envelope) and `EnergyResourceCommonAttributes` (attributes bag base). |

---

## Purpose

`EnergyResourceCommon` eliminates field duplication across the seven typed `EnergyResource` kind schemas by providing a single canonical home for:

- **`EnergyResourceCommon`** — the structural envelope (`id`, `type`, `subResources`, `parentResources`, `attributes`)
- **`EnergyResourceCommonAttributes`** — the attributes bag base (`make`, `model`, `ratedPowerKw`, `maxExportKw`, `maxImportKw`, `telemetryProvider`, `commissioningDate`, `location`)

All kind schemas inherit these via `allOf` external `$ref` and only define their own kind-specific fields.

See [v1.0/README.md](./v1.0/README.md) for the full field tables and inheritance pattern.
