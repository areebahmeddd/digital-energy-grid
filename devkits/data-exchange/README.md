# Data Exchange Devkit

Beckn Protocol v2.0 devkit demonstrating **inline data delivery** via DDM's `DatasetItem` schema. Datasets are embedded directly in beckn messages through the `dataPayload` attribute rather than fetched from external URLs.

## Use Cases

| Use Case | BPP (Provider) | BAP (Consumer) | dataPayload | Description |
|----------|---------------|----------------|-------------|-------------|
| [uc1-meter-data](./uc1-meter-data/) | IntelliGrid AMI Services (AMISP) | BESCOM (discom) | `IES_Report` — 15-min kWh meter readings | AMI meter data exchange under existing contract |
| [uc2-regulatory-data](./uc2-regulatory-data/) | BESCOM (discom) | APERC (state regulator) | `IES_ARR_Filing` — cost line items, fiscal years | ARR filing submission under regulatory mandate |

Both use cases share the same docker stack, adapter configs, and runner.

## Stack Topology

```
               internet (optional, via ngrok)
                          │
                  https://<public-host>/
                          │
                     :9000 (host)
                          │
                    ┌──beckn-router──┐   (Caddy; the only container on both networks)
                    │                │
              /bap/* │                │ /bpp/*
                    │                │
   ┌── bap_side ────┘                └──── bpp_side ──┐
   │  onix-bap:8081                   onix-bpp:8082   │
   │  sandbox-bap:3001                sandbox-bpp:3002│
   │  redis                           redis           │
   └──────────────────────────────────────────────────┘
```

BAP-side and BPP-side services sit on independent docker networks; the Caddy router on `:9000` is the sole bridge. All BAP↔BPP traffic passes through it, so the same container image/config runs unchanged whether you're hitting the router locally or through a public tunnel.

## Prerequisites

Git, Docker, Docker Compose, (optional) Postman, (optional) ngrok.

## Quick Start

```bash
cd install
docker compose up -d

# Pick a mode for the Arazzo runner:
#   (a) Strictly local — default if PUBLIC_URL is unset or empty.
#       Caddy bridges BAP↔BPP inside docker, no internet.
export PUBLIC_URL=
#   (b) Over the public internet via ngrok — set PUBLIC_URL to the tunnel URL.
#       cp ngrok.yml.example ngrok.yml  # paste your authtoken
#       ngrok start --all --config ngrok.yml
# export PUBLIC_URL=https://<your-subdomain>.ngrok-free.dev

cd ../uc1-meter-data/workflows
PUBLIC_URL=$PUBLIC_URL ./run-arazzo.sh -w select-through-status -v

cd ../../uc2-regulatory-data/workflows
PUBLIC_URL=$PUBLIC_URL ./run-arazzo.sh -w select-through-status -v
```

`./run-arazzo.sh` with no args runs all workflows for the use case. Available workflows: `publish-catalog`, `discover`, `select-through-status`, `data-exchange-cancellation`.

## Postman

Each use case ships BAP and BPP Postman collections under `postman/`:

- `uc1-meter-data/postman/data-exchange-uc1-meter-data.{BAP,BPP}-DEG.postman_collection.json`
- `uc2-regulatory-data/postman/data-exchange-uc2-regulatory-data.{BAP,BPP}-DEG.postman_collection.json`

Import a collection into Postman and hit Send. Default request URLs point at `localhost:8081`/`8082` (BAP/BPP caller endpoints); change them to your ngrok URL to send over the tunnel. Collections are regenerated with `python3 scripts/generate_postman_collection.py --role BAP|BPP [--usecase uc1-meter-data|uc2-regulatory-data]`.

## Hosting the site (beyond this devkit)

`PUBLIC_URL` is the beckn-facing URL your BAP/BPP expose; in production it's just your real hostname (TLS terminated at your edge, forwarded to `beckn-router:9000`). The rest of the work is **identity**, not infrastructure:

1. **Create DeDi registry records** for your subscriber — one record per role (BAP, BPP) per network. See [docs.beckn.io](https://docs.beckn.io/) for the current record schema and where in the protocol flow the registry is consulted (sign/verify during every message).
2. **Update your onix config** (`config/local-simple-*.yaml`) so the identity fields match your DeDi record. The mapping:

   | DeDi registry field | Onix config field |
   |---------------------|-------------------|
   | `recordId`          | `keyId`           |
   | `subscriberId`      | `networkParticipant` |
   | `domain`            | `allowedNetworkIDs` entry (network ID in beckn context) |

3. **Ask the network namespace owner** (e.g. for `nfh.global/testnet-deg`, that's `nfh.global`) to add your subscriber record to the network's beckn reference registry. This is required whenever a network's `allowedNetworkIDs` on the adapter is non-empty — adapters reject messages from subscribers not listed there.

One beckn server can belong to multiple networks: list each one in `allowedNetworkIDs` and register a corresponding DeDi record per network.

## Over-the-internet notes

Run the stack, start ngrok, set `PUBLIC_URL=https://<tunnel>.ngrok-free.dev`, run the arazzo scripts. The runner materialises a tmpdir with a copy of the arazzo file and patched example payloads (`bapUri`/`bppUri` rewritten to the public URL) and invokes Respect against it, so sources on disk stay untouched. Watch the tunnel at `http://localhost:4040` — each transactional step shows three hops: `your curl → BAP`, `BAP → BPP`, `BPP → BAP callback`.

The `discover` step calls an external discovery service (`34.14.221.66.sslip.io`); its outcome is independent of this devkit's topology. The catalog-service subscription is a one-time network setup call (not part of the transactional flow); see `scripts/subscribe-catalog.sh`.

## Cleanup

```bash
cd install
docker compose down
pkill -f 'ngrok start'   # if ngrok was running
```

## Related

- [DDM DatasetItem Schema](https://github.com/beckn/DDM/tree/main/specification/schema/DatasetItem/v1) — `dataPayload` and `accessMethod`
- [IES Core Schemas](https://github.com/beckn/DEG/tree/ies-specs/specification/external/schema/ies/core) — IES_Report, IES_Program, IES_Policy (OpenADR 3.1.0)
- [IES ARR Schemas](https://github.com/beckn/DEG/tree/ies-specs/specification/external/schema/ies/arr) — IES_ARR_Filing, IES_ARR_FiscalYear, IES_ARR_LineItem
- [docs.beckn.io](https://docs.beckn.io/) — DeDi registry, subscriber identity, message signing
- beckn/beckn-onix#655 — ONIX regex engine issue with OpenADR duration patterns
