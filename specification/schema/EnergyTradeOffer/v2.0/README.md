# EnergyTradeOffer — v2.0

Offer attributes for P2P energy trading. Attached to `Offer.offerAttributes`.

Part of the [DEG Schema](../../../specification/schema/) · [EnergyTradeOffer](../README.md)

## Files

| File | Description |
|------|-------------|
| [attributes.yaml](./attributes.yaml) | OpenAPI 3.1.1 schema for `EnergyTradeOffer` |
| [context.jsonld](./context.jsonld) | JSON-LD context (namespace: `https://schema.nfh.global/deg/EnergyTradeOffer/v2.0/`) |
| [vocab.jsonld](./vocab.jsonld) | RDF vocabulary for `EnergyTradeOffer` terms |

## Design: commitmentAttributes as the contract table

All interval data (price, quantities, allocations) lives in two BecknTimeSeries:

1. **`offerAttributes.commitmentAttributes`** — the seller's immutable offer declaration, published at catalog time. Carries `PRICE_PER_KWH` + `AVAILABLE_QTY` intervals and declares the full contract table schema via `payloadDescriptors`, each annotated with `insertedBy`.

2. **`Commitment.commitmentAttributes`** — the live/growing contract record (sibling of `offer`). Starts with PRICE_PER_KWH + REQUESTED_QTY and accumulates discom columns and FINAL_ALLOC as the lifecycle progresses.

| Lifecycle stage | Who adds to `Commitment.commitmentAttributes` |
|-----------------|-----------------------------------------------|
| init / confirm | buyer appends `REQUESTED_QTY` |
| post-delivery | discoms append `BUYER_DISCOM_ALLOC`, `BUYER_DISCOM_STATUS`, `SELLER_DISCOM_ALLOC`, `SELLER_DISCOM_STATUS`, `FINAL_ALLOC` |

## Properties

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `validityWindow` | `TimePeriod` | | Window during which the offer can be selected/accepted. Present at catalog publish. |
| `contractAttributes` | `object` (JSON-LD) | | DEGContract terms at catalog publish. Only parties with known `participantId` are included — unknown parties (null) are omitted. Mirrors `Contract.contractAttributes` — NPs promote this field verbatim at init. |
| `commitmentAttributes` | `TimeSeries` (JSON-LD) | ✓ | Seller's offer declaration: full payloadDescriptor schema with `insertedBy` + seller's initial intervals. Immutable after publish. |

## commitmentAttributes.payloadDescriptors

Each descriptor declares one column in the shared contract table:

| payloadType | objectType | insertedBy | units/currency |
|-------------|-----------|------------|----------------|
| `PRICE_PER_KWH` | `EVENT_PAYLOAD_DESCRIPTOR` | `seller` | currency: INR |
| `AVAILABLE_QTY` | `EVENT_PAYLOAD_DESCRIPTOR` | `seller` | units: KWH |
| `REQUESTED_QTY` | `EVENT_PAYLOAD_DESCRIPTOR` | `buyer` | units: KWH |
| `BUYER_DISCOM_ALLOC` | `REPORT_PAYLOAD_DESCRIPTOR` | `buyerDiscom` | units: KWH |
| `BUYER_DISCOM_STATUS` | `REPORT_PAYLOAD_DESCRIPTOR` | `buyerDiscom` | units: STRING |
| `SELLER_DISCOM_ALLOC` | `REPORT_PAYLOAD_DESCRIPTOR` | `sellerDiscom` | units: KWH |
| `SELLER_DISCOM_STATUS` | `REPORT_PAYLOAD_DESCRIPTOR` | `sellerDiscom` | units: STRING |
| `FINAL_ALLOC` | `REPORT_PAYLOAD_DESCRIPTOR` | `sellerDiscom` | units: KWH |

`insertedBy` answers "why is this column here?" — it names the role responsible for
populating that column. Any column whose `insertedBy` party is not yet known at publish
time (buyer, discoms) is still declared in `payloadDescriptors` but has no interval data
until that party participates.

## Consistency requirement

Every `payloadType` in `Commitment.commitmentAttributes.intervals[*].payloads[*].type`
MUST appear in `Commitment.commitmentAttributes.payloadDescriptors`, and vice versa.
