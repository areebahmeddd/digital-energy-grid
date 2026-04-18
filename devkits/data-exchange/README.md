# Data Exchange Devkit

Beckn Protocol v2.0 devkit demonstrating **inline data delivery** via DDM's `DatasetItem` schema. Instead of downloading datasets from external URLs, data is embedded directly in beckn messages using the `dataPayload` attribute.

## Use Cases

| Use Case | BPP (Provider) | BAP (Consumer) | dataPayload | Description |
|----------|---------------|----------------|-------------|-------------|
| [usecase1](./usecase1/) | IntelliGrid AMI Services (AMISP) | BESCOM (discom) | `IES_Report` — 15-min kWh meter readings | AMI meter data exchange under existing contract |
| [usecase2](./usecase2/) | BESCOM (discom) | APERC (state regulator) | `IES_ARR_Filing` — cost line items, fiscal years | ARR filing submission under regulatory mandate |

Both use cases share the same Docker infrastructure, adapter configs, and test scripts.

## Key Schemas

**DatasetItem** from [DDM](https://github.com/beckn/DDM) provides `dataPayload` for inline data delivery and `accessMethod` to declare delivery mode (`INLINE`, `DOWNLOAD`, `DATA_ENCLAVE`, `OFF_CHANNEL`).

**IES_Report** from [India Energy Stack](https://github.com/India-Energy-Stack/ies-docs) carries meter telemetry in OpenADR 3.1.0 format.

**IES_ARR_Filing** from [India Energy Stack](https://github.com/India-Energy-Stack/ies-docs) carries Aggregate Revenue Requirement filings with fiscal year line items.

## Transaction Flow

```
BPP (Provider)      Catalog Service     Discovery Service       BAP (Consumer)
    |                     |                    |                      |
    |                     |<-- subscribe ------|                      |
    |                     |   (catalog updates)|                      |
    |                     |                    |                      |
    |-- publish --------->|                    |                      |
    |   (DatasetItem      |                    |                      |
    |    catalog)         |                    |                      |
    |                     |                    |                      |
    |                     |                    |<---- discover -------|
    |                     |                    |     (search datasets)|
    |                     |                    |---- on_discover ---->|
    |                     |                    |     (catalog results)|
    |                     |                    |                      |
    |---------------------+--------------------+----------------------|
    |                  Direct BAP <-> BPP negotiation                 |
    |                                                                 |
    |<---- select (choose dataset + offer) --------------------------|
    |---- on_select (terms) ---------------------------------------->|
    |                                                                 |
    |<---- init (details) -------------------------------------------|
    |---- on_init (ready) ------------------------------------------>|
    |                                                                 |
    |<---- confirm --------------------------------------------------|
    |---- on_confirm (active) -------------------------------------->|
    |                                                                 |
    |<---- status (check delivery) ----------------------------------|
    |---- on_status (PROCESSING) ----------------------------------->|
    |                                                                 |
    |  +- Delivery mode A: URL download -------------------------+  |
    |  | on_status (DELIVERY_COMPLETE)                            |  |
    |  |   dataset:downloadUrl + dataset:checksum                 | >|
    |  +----------------------------------------------------------+  |
    |                                                                 |
    |  +- Delivery mode B: Inline dataPayload --------------------+  |
    |  | on_status (DELIVERY_COMPLETE)                            |  |
    |  |   dataPayload: IES_Report / IES_ARR_Filing               | >|
    |  +----------------------------------------------------------+  |
    |                                                                 |
    |<---- cancel ---------------------------------------------------|
    |---- on_cancel ------------------------------------------------>|
```

## Prerequisites

- Git, Docker, Docker Compose
- Postman (optional, for manual testing)

## Quick Start

```bash
# 1. Start infrastructure (shared across both use cases)
cd install
docker compose up -d   # local topology (docker-compose.override.yml auto-applied)

# 2. Verify services
curl http://localhost:8081/health   # BAP adapter
curl http://localhost:8082/health   # BPP adapter
curl http://localhost:3001/api/health  # BAP sandbox
curl http://localhost:3002/api/health  # BPP sandbox

# 3. Run the Arazzo workflows (one runner per usecase, lives next to its arazzo file)
cd ../usecase1/workflows && ./run-arazzo.sh    # AMI meter data
cd ../../usecase2/workflows && ./run-arazzo.sh # ARR filing

# Single workflow, verbose:
./run-arazzo.sh -w select-through-status -v
```

## Repository Structure

```
data-exchange/
├── config/                              # Shared Onix adapter configs
│   ├── local-simple-bap.yaml            #   BAP adapter (port 8081)
│   ├── local-simple-bpp.yaml            #   BPP adapter (port 8082)
│   └── local-simple-routing-*.yaml      #   Routing rules
├── install/
│   ├── docker-compose.yml               # Base: BAP + BPP adapters and sandboxes
│   ├── docker-compose.override.yml      # LOCAL topology (auto-applied: shared bridge)
│   ├── docker-compose.over-internet.yml # OVER_INTERNET topology (split nets + router)
│   ├── Caddyfile                        #   path router config (:9000)
│   └── ngrok.yml.example                #   template for ngrok agent
├── scripts/
│   ├── generate_postman_collection.py   # Postman collection generator
│   └── subscribe-catalog.sh             # one-time catalog-service subscribe (network setup)
├── usecase1/                            # AMISP → Discom (AMI meter data)
│   ├── examples/                        #   beckn 2.0 JSON payloads
│   ├── postman/                         #   data-exchange-usecase1.{BAP,BPP}-DEG
│   └── workflows/
│       ├── data-exchange.arazzo.yaml    #   Arazzo 1.0.1 workflow spec
│       └── run-arazzo.sh                #   Arazzo runner (local or PUBLIC_URL)
└── usecase2/                            # Discom → Regulator (ARR filing)
    ├── examples/
    ├── postman/
    └── workflows/
        ├── data-exchange.arazzo.yaml
        └── run-arazzo.sh
```

## Network Configuration

| Parameter | Value |
|-----------|-------|
| Network ID | `nfh.global/testnet-deg` |
| BAP ID | `bap.example.com` |
| BPP ID | `bpp.example.com` |
| BAP Adapter | `http://localhost:8081/bap/caller` |
| BPP Adapter | `http://localhost:8082/bpp/caller` |

## Run end-to-end over the public internet

By default (`docker-compose.override.yml`, auto-applied) BAP and BPP share a
docker bridge and reach each other by container DNS names (`onix-bap`,
`onix-bpp`). To exercise the protocol with both sides talking strictly over
the public internet, the devkit ships `docker-compose.over-internet.yml`
which, when layered on the base, puts the two sides on **separate, mutually
unreachable** docker networks and exposes them through a single ngrok tunnel.

```
                       internet
                          │
              https://<public-host>/  (ngrok)
                          │
                     :9000 (host)
                          │
                    ┌──beckn-router──┐  (only container on both nets)
                    │                │
              /bap/* │                │ /bpp/*
                    │                │
   ┌── bap_side ────┘                └──── bpp_side ──┐
   │  onix-bap:8081     ✕  no link  ✕    onix-bpp:8082│
   │  sandbox-bap:3001                   sandbox-bpp:3002
   │  redis                              redis        │
   └─────────────────────────────────────────────────-┘
```

Beckn URIs become:

```
bapUri = https://<public-host>/bap/receiver
bppUri = https://<public-host>/bpp/receiver
```

Body-digest signing is unaffected by the URL change, so registry entries for
`bap.example.com` / `bpp.example.com` keep working as-is.

### One-time prerequisites

1. ngrok account + authtoken (free plan is enough).
2. Copy the ngrok config template and fill in your token:

   ```bash
   mkdir -p "$HOME/Library/Application Support/ngrok"
   cp install/ngrok.yml.example "$HOME/Library/Application Support/ngrok/ngrok.yml"
   # edit the file: paste your authtoken; optionally set `domain:` to your
   # reserved ngrok-free.dev subdomain for a stable URL across restarts.
   ```

   Validate: `ngrok config check`.

### Per-session steps

```bash
# 1. Stop the default stack if it's running (the airtight stack uses the
#    same host ports 8081/8082/3001/3002; only one stack at a time).
cd install
docker compose down 2>/dev/null

# 2. Bring up the airtight stack (separate networks per side + router on :9000).
#    Passing -f disables auto-pickup of docker-compose.override.yml.
docker compose -f docker-compose.yml -f docker-compose.over-internet.yml up -d
curl -s http://localhost:9000   # → "beckn-router ok"

# 3. (Optional) Verify isolation: from inside bap_side, onix-bpp must be NXDOMAIN
docker run --rm --network install_bap_side busybox \
  sh -c 'nslookup onix-bpp; nc -zv -w 3 onix-bpp 8082'
# Expected: "can't find onix-bpp: NXDOMAIN" and "nc: bad address 'onix-bpp'"

# 4. Open the tunnel (foreground in its own terminal, or backgrounded)
ngrok start --all
# Note the public URL printed by ngrok; export it:
export PUBLIC_URL=https://<your-subdomain>.ngrok-free.dev

# 5. Run the Arazzo workflows over the public URL. Each usecase's runner sits
#    next to its arazzo file under workflows/. When PUBLIC_URL is set the
#    runner materialises a tmpdir with a copy of the arazzo file and patched
#    example payloads (docker-DNS bapUri/bppUri rewritten to the public URL)
#    before invoking Respect — example files on disk stay untouched.
cd ../usecase1/workflows
PUBLIC_URL=$PUBLIC_URL ./run-arazzo.sh

cd ../../usecase2/workflows
PUBLIC_URL=$PUBLIC_URL ./run-arazzo.sh

# Single workflow, verbose:
PUBLIC_URL=$PUBLIC_URL ./run-arazzo.sh -w select-through-status -v
```

A passing run proves end-to-end internet traversal: there is no docker-bridge
fallback between the two halves, so every BAP↔BPP hop must have travelled
through the public URL fronting the router.

### Verify the traffic really left the box

Open the ngrok inspector at `http://localhost:4040`. For each transactional
step you should see three rows recorded by the public tunnel:

| Direction | Path |
|---|---|
| your curl → BAP | `POST /bap/caller/<action>` |
| **BAP → BPP (over internet)** | `POST /bpp/receiver/<action>` |
| **BPP → BAP callback (over internet)** | `POST /bap/receiver/on_<action>` |

### Notes and limitations

- The two URIs share a hostname and differ only by path prefix because
  ngrok's free plan reserves a single domain per account. From the beckn
  protocol's point of view they are still two distinct URIs and the test is
  valid. For two truly distinct hostnames, switch the tunnel to Cloudflare
  Tunnel (`cloudflared tunnel --url http://localhost:8081` and `:8082`, two
  free random `*.trycloudflare.com` URLs) or move ngrok to a paid plan.
- The `discover` step calls out to an external discovery service
  (`34.14.221.66.sslip.io`); its outcome is independent of the over-internet
  wiring tested here. (The catalog-service subscription, also external, is
  not part of the transactional suite — see
  `scripts/subscribe-catalog.sh`.)

### Cleanup

```bash
cd install
docker compose -f docker-compose.yml -f docker-compose.over-internet.yml down
# kill the ngrok agent in its terminal (Ctrl-C) or:  pkill -f 'ngrok start'
```

## Regenerating Postman Collections

```bash
python3 scripts/generate_postman_collection.py --role BAP            # both use cases
python3 scripts/generate_postman_collection.py --role BPP            # both use cases
python3 scripts/generate_postman_collection.py --role BAP --usecase usecase1  # one use case
```

## Related

- [DDM DatasetItem Schema](https://github.com/beckn/DDM/tree/main/specification/schema/DatasetItem/v1) — `dataPayload` and `accessMethod`
- [IES Core Schemas](https://github.com/beckn/DEG/tree/ies-specs/specification/external/schema/ies/core) — IES_Report, IES_Program, IES_Policy (OpenADR 3.1.0)
- [IES ARR Schemas](https://github.com/beckn/DEG/tree/ies-specs/specification/external/schema/ies/arr) — IES_ARR_Filing, IES_ARR_FiscalYear, IES_ARR_LineItem
- [India Energy Stack (ies-docs)](https://github.com/India-Energy-Stack/ies-docs) — Upstream IES documentation
- beckn/beckn-onix#655 — ONIX regex engine issue with OpenADR duration patterns
