# Demand Flex Devkit

Beckn Protocol v2.0 devkit for **behavioral demand response**. A utility publishes flexibility needs (peak demand reduction), and aggregators discover, commit to, and deliver demand flexibility — with settlement based on measured performance.

## Scenario

**TPDDL** (Tata Power Delhi Distribution, the utility) publishes a 500 kW curtailment need during a peak event window. **GreenFlex Aggregator** discovers the opportunity, enrolls participating meters, and commits to providing 150 kW of demand reduction. After the event, TPDDL publishes baselines, measured actuals, and computes settlement (e.g., 150 kWh x 3.5 INR/kWh = 525 INR).

## Key Schemas

| Schema | Slot | Description |
|--------|------|-------------|
| [DemandFlexNeed](../../specification/schema/DemandFlexNeed/v2.0/) | `resourceAttributes` | Direction (REDUCE/INCREASE), event window, capacity type, location |
| [DemandFlexBuyOffer](../../specification/schema/DemandFlexBuyOffer/v2.0/) | `offerAttributes` | Incentive per kWh, baseline methodology, penalty rate |
| [DEGContract](../../specification/schema/DEGContract/v2.0/) | `contractAttributes` | Roles (buyer/seller), policy reference, revenue flows |
| [DemandFlexPerformance](../../specification/schema/DemandFlexPerformance/v2.0/) | `performanceAttributes` | M&V baselines and actuals per meter |

## Transaction Flow

```
BPP (TPDDL Utility)  Catalog Service    Discovery Service    BAP (GreenFlex Agg)
    |                      |                   |                     |
    |-- publish ---------->|                   |                     |
    |   (DemandFlexNeed    |                   |                     |
    |    + BuyOffer)       |                   |                     |
    |                      |<-- subscribe -----|                     |
    |                      |   (catalog updates)                    |
    |                      |                   |                     |
    |                      |                   |<---- discover ------|
    |                      |                   |    (CURTAILMENT +   |
    |                      |                   |     REDUCE filter)  |
    |                      |                   |---- on_discover --->|
    |                      |                   |                     |
    |------------------------------------------------------+--------|
    |                Direct BAP <-> BPP negotiation        |        |
    |                                                               |
    |<---- select (150 kW of 500 kW needed) ------------------------|
    |---- on_select (DRAFT contract) ------------------------------>|
    |                                                               |
    |<---- init (aggregator identity + 2 meters) -------------------|
    |---- on_init (DRAFT, identity acknowledged) ------------------>|
    |                                                               |
    |<---- confirm (contract ACTIVE) -------------------------------|
    |---- on_confirm (ACTIVE) ------------------------------------->|
    |                                                               |
    |<---- update (opt-in meter 003, adjust to 120 kW) -------------|
    |                                                               |
    |  +- Pre-event: Baselines -----------------------------------+ |
    |  | on_status (BASELINE_PUBLISHED)                            | |
    |  |   meters: [{ baselineKw: 45 }, { 38 }, { 52 }]           |>|
    |  +-----------------------------------------------------------+ |
    |                                                               |
    |  +- Post-event: Actuals ------------------------------------+ |
    |  | on_status (DELIVERY_COMPLETE)                             | |
    |  |   meters: [{ actualKw: 20 }, { 15 }, { 25 }]             |>|
    |  +-----------------------------------------------------------+ |
    |                                                               |
    |  +- Settlement ---------------------------------------------+ |
    |  | on_status (SETTLED)                                       | |
    |  |   revenueFlows: 150 kWh x 3.5 INR/kWh = 525 INR         |>|
    |  +-----------------------------------------------------------+ |
```

## Prerequisites

- Git, Docker, Docker Compose
- Postman (optional, for manual testing)

## Quick Start

```bash
# 1. Start infrastructure
cd install
docker compose -f docker-compose-demand-flex.yml up -d

# 2. Verify services
curl http://localhost:8081/health   # BAP adapter
curl http://localhost:8082/health   # BPP adapter
curl http://localhost:3001/api/health  # BAP sandbox
curl http://localhost:3002/api/health  # BPP sandbox

# 3. Import Postman collections from postman/ directory
#    or run the Arazzo workflow:
cd ..
npx @redocly/cli respect workflows/demand-flex.arazzo.yaml \
  --severity 'SCHEMA_CHECK=off' -v
```

## Repository Structure

```
demand-flex/
├── config/                              # Onix adapter configs
│   ├── local-demand-flex-bap.yaml       #   BAP adapter (port 8081)
│   ├── local-demand-flex-bpp.yaml       #   BPP adapter (port 8082)
│   └── local-demand-flex-routing-*.yaml #   Routing rules
├── install/
│   └── docker-compose-demand-flex.yml   # Docker services
├── postman/
│   ├── demand-flex.BAP-DEG.postman_collection.json
│   └── demand-flex.BPP-DEG.postman_collection.json
└── workflows/
    └── demand-flex.arazzo.yaml          # Arazzo 1.0.1 workflow spec
```

Example payloads live at the repo root: [`examples/demand-flex/v2/`](../../examples/demand-flex/v2/)

## Network Configuration

| Parameter | Value |
|-----------|-------|
| Domain | `beckn.one:deg:demand-flex:2.0.0` |
| Network | `beckn.one/testnet` |
| BAP ID | `greenflex-agg.example.com` |
| BPP ID | `tpddl-utility.example.com` |
| BAP Adapter | `http://localhost:8081/bap/caller` |
| BPP Adapter | `http://localhost:8082/bpp/caller` |

## Workflow Steps

| # | Action | Who | Description |
|---|--------|-----|-------------|
| 1 | `catalog/publish` | BPP | Utility publishes flex catalog (500 kW curtailment need) |
| 2 | `catalog/subscribe` | Discover Service | Discover service subscribes to catalog updates |
| 3 | `discover` | BAP | Aggregator discovers CURTAILMENT + REDUCE offers |
| 4 | `select` | BAP | Aggregator selects 150 kW of the 500 kW offer |
| 5 | `on_select` | BPP | Utility returns DRAFT contract |
| 6 | `init` | BAP | Aggregator provides identity + 2 participating meters |
| 7 | `on_init` | BPP | Utility acknowledges (DRAFT) |
| 8 | `confirm` | BAP | Aggregator confirms contract (ACTIVE) |
| 9 | `on_confirm` | BPP | Utility confirms ACTIVE status |
| 10 | `update` | BAP | Aggregator opts in meter 003, adjusts to 120 kW |
| 11 | `on_status` (baselines) | BPP | Utility publishes baseline values per meter |
| 12 | `on_status` (actuals) | BPP | Utility publishes measured actuals |
| 13 | `on_status` (settled) | BPP | Utility computes settlement: 525 INR payable |

## Policy Enforcement

Uses OPA (Open Policy Agent) via the `opapolicychecker` plugin. Current policy is a noop — replace the `location` URL in the config with a real policy as network rules mature.

## Regenerating Postman Collections

```bash
# From repo root
python3 scripts/generate_postman_collection.py \
  --devkit demand-flex --role BAP \
  --output-dir devkits/demand-flex/postman \
  --name "demand-flex:BAP-DEG" --validate

python3 scripts/generate_postman_collection.py \
  --devkit demand-flex --role BPP \
  --output-dir devkits/demand-flex/postman \
  --name "demand-flex:BPP-DEG" --validate
```

## Related

- [DemandFlexNeed Schema](../../specification/schema/DemandFlexNeed/v2.0/) — Flex resource attributes
- [DemandFlexBuyOffer Schema](../../specification/schema/DemandFlexBuyOffer/v2.0/) — Incentive and policy terms
- [Demand Flexibility Implementation Guide](../../docs/implementation-guides/v2/Demand_Flexibility/Demand_Flexibility.md) — Detailed protocol flows and schema mappings
- [Data Exchange Devkit](../data-exchange/) — Companion devkit for energy data delivery
