# EvChargingOffer

> **Canonical IRI:** [`https://schema.beckn.io/EvChargingOffer`](https://schema.beckn.io/EvChargingOffer)
> **Tags:** `ev-charging, offer, tariff, pricing, idle-fee, energy, beckn`
> **Namespace:** `https://schema.beckn.io/`
> Part of the [DEG Schema](../../README.md)

---

**EV charging offer attributes** attached to `Offer.attributes` in a Beckn EV-charging catalog. Captures tariff details beyond core price fields — including per-kWh or time-based pricing models, idle fee policies, and accepted payment methods.

## Versions

| Version | attributes.yaml | context.jsonld | vocab.jsonld | README |
|---------|----------------|----------------|--------------|--------|
| **v1.0** | [attributes.yaml](./v1.0/attributes.yaml) | [context.jsonld](./v1.0/context.jsonld) | [vocab.jsonld](./v1.0/vocab.jsonld) | [README](./v1.0/README.md) |
| **v2.0** | [attributes.yaml](./v2.0/attributes.yaml) | [context.jsonld](./v2.0/context.jsonld) | [vocab.jsonld](./v2.0/vocab.jsonld) | [README](./v2.0/README.md) |

## Properties (latest: v2.0)

| Property | Type | Required | Description |
|----------|------|:--------:|-------------|
| `tariffModel` | `string` (enum) | — | Tariff model classification: `PER_KWH`, `PER_MINUTE`, `SUBSCRIPTION`, `TIME_OF_DAY`. |
| `idleFeePolicy` | `PriceSpecification` | — | Idle fee policy — charge applied after session ends but vehicle remains plugged in. |
| `buyerFinderFee` | `object` | — | Commission payable by the provider to the BAP for this offer. |
| `eligibleQuantity` | `Quantity` | — | Energy quantity limits (min/max kWh) applicable to this offer. |
| `acceptedPaymentMethods` | `array<string>` | — | List of accepted payment method codes (e.g., `UPI`, `CARD`). |

## Linked Data

| Resource | URL |
|----------|-----|
| Canonical IRI | `https://schema.beckn.io/EvChargingOffer` |
| JSON Schema (latest) | `https://schema.beckn.io/EvChargingOffer/v2.0` |
| context.jsonld (latest) | `https://schema.beckn.io/EvChargingOffer/v2.0/context.jsonld` |
| vocab.jsonld (latest) | `https://schema.beckn.io/EvChargingOffer/v2.0/vocab.jsonld` |
| Root context.jsonld | `https://schema.beckn.io/context.jsonld` |
| Root vocab.jsonld | `https://schema.beckn.io/vocab.jsonld` |
