# P2P Wave 2 Observability

OpenTelemetry-based monitoring for the P2P Wave 2 devkit. Provides Grafana
dashboards backed by Prometheus (metrics), Loki (logs), and Zipkin (traces).

Observability is disabled in the default devkit startup to keep local memory
usage low. Enable it only when you explicitly need Grafana dashboards, metrics,
logs, or traces.

---

## Architecture Overview

```
ONIX adapter (×6)
  → companion OTel collector (one per adapter)
    → network OTel collector (single, shared)
      → Prometheus   (metrics)
      → Loki         (structured logs + audit logs)
      → Zipkin       (distributed traces)
        → Grafana    (dashboards + explore)

Docker container stdout/stderr
  → Promtail
    → Loki
      → Grafana Explore
```

Each ONIX adapter exports OTLP/gRPC telemetry to its own **companion
collector**. The companion collector:

- exposes app-level metrics on `:8889` for Prometheus to scrape directly.
- filters and forwards network-level metrics, traces, and logs to a shared
  **network collector**.

The network collector aggregates signals from all adapters, rewrites Beckn
`transaction_id` into a deterministic trace ID, and exports to Prometheus,
Zipkin, and Loki.

**Promtail** separately tails Docker container stdout/stderr via the Docker
socket and pushes those logs to Loki. This gives immediate container-log
visibility even before the ONIX `otelsetup` plugin emits OTel audit records.

### Adapter → Collector Mapping

| ONIX Adapter             | Companion Collector                  | Prometheus Port |
| ------------------------ | ------------------------------------ | --------------- |
| `onix-buyerapp`          | `otel-collector-buyerapp`            | `:8889`         |
| `onix-sellerapp`         | `otel-collector-sellerapp`           | `:8889`         |
| `onix-buyerdiscom`       | `otel-collector-buyerdiscom`         | `:8889`         |
| `onix-sellerdiscom`      | `otel-collector-sellerdiscom`        | `:8889`         |
| `onix-ledger-buyerdiscom`| `otel-collector-ledger-buyerdiscom`  | `:8889`         |
| `onix-ledger-sellerdiscom`| `otel-collector-ledger-sellerdiscom` | `:8889`         |

All companion collectors use the same config file
(`observability/otel-collector-node.yaml`), differentiated only by the
`OTEL_NODE_NAME` environment variable set in `docker-compose.observability.yml`.

---

## Quick Start

From `DEG/devkits/p2p-trading-ies-wave2/install`:

Start the normal devkit without observability:

```bash
docker compose up -d
```

Start the devkit with observability enabled:

```bash
docker compose -f docker-compose.yml -f docker-compose.observability.yml up -d
```

The observability override automatically runs
`observability/generate-configs.sh` in a short-lived helper container before
the ONIX adapters start.

Stop the observability-enabled stack:

```bash
docker compose -f docker-compose.yml -f docker-compose.observability.yml down
```

After changing observability compose/config files, recreate the
observability-enabled stack so stale containers and old mounted configs are
removed:

```bash
docker compose -f docker-compose.yml -f docker-compose.observability.yml down --remove-orphans
docker compose -f docker-compose.yml -f docker-compose.observability.yml up -d --force-recreate
```

### Observability UIs

These URLs are available only when the observability override is enabled.

| Service    | Local URL                    | Credentials     |
| ---------- | ---------------------------- | --------------- |
| Grafana    | <http://localhost:3005>       | `admin` / `admin` |
| Prometheus | <http://localhost:9090>       | —               |
| Loki       | <http://localhost:3100>       | —               |
| Zipkin     | <http://localhost:9411>       | —               |

Open Grafana → **Dashboards** → **P2P Wave 2** folder →
**P2P Wave 2 Observability**.

---

## What To Customise When You Fork / Deploy

> **If you are setting up this devkit for a new participant, network, or
> deployment environment, update the values listed below.** The observability
> configs ship with example placeholder values (`*.example.com`) that must
> match your actual Beckn subscriber IDs and network topology.

### 1. ONIX Adapter Configs — `otelsetup` Plugin Block

Each fragment YAML in `config/observability/fragments/` has a top-level
`plugins.otelsetup` section. The default adapter YAMLs remain the source of
truth and do not include this block, so normal `docker compose up -d` stays
lightweight. The observability override runs
`observability/generate-configs.sh` automatically before the ONIX adapters
start. The script combines each base adapter YAML with its fragment and writes
the generated YAML to `config/observability/`.

```yaml
plugins:
  otelsetup:
    id: otelsetup
    config:
      serviceName: "p2p-wave2-buyerapp"           # ① unique per adapter
      producer: "buyerapp.example.com"             # ② your subscriber ID
      producerType: "bap"                          # ③ "bap" or "bpp"
      otlpEndpoint: "otel-collector-buyerapp:4317" # ④ collector hostname
      enableMetrics: "true"
      enableTracing: "true"
      enableLogs: "true"
      auditFieldsConfig: "/app/config/audit-fields.yaml"
```

Here is what each of the four key fields means and when you need to change it:

---

#### ① `serviceName` — "Who am I in Grafana?"

This is the **display name** that appears on every metric, trace, and log
record emitted by this adapter. Grafana uses it to let you filter dashboards
to a specific adapter.

- Must be **unique across all adapters** in the stack. If two adapters share
  the same `serviceName`, their metrics will be mixed together and you won't
  be able to tell them apart in Grafana.
- Can be any string you like — it's purely for human readability.
- Convention: `p2p-wave2-<role>` (e.g. `p2p-wave2-buyerapp`,
  `p2p-wave2-sellerapp`).

**Where it shows up:**

- Grafana → Loki log panel → `service_name` label
- Grafana → Prometheus → `service` label on metrics
- Zipkin → `serviceName` in trace explorer

**When to change:** Always set this to something meaningful for your
deployment. The default values work for the demo, but in a multi-team setup
you'll want names that identify the operator.

---

#### ② `producer` — "What is my Beckn subscriber ID?"

This is the **most important field to change** when you fork the devkit.

The `producer` value must be your **Beckn subscriber ID** — the exact same
value you set as `networkParticipant` in the `keyManager` plugin section of
the same config file. For example, if your key manager says:

```yaml
keyManager:
  id: simplekeymanager
  config:
    networkParticipant: buyerapp.yourcompany.com   # ← this value
```

then your otelsetup must say:

```yaml
producer: "buyerapp.yourcompany.com"               # ← must match
```

**Why it matters:** The network observer (the central entity monitoring all
participants) uses `producer` to **attribute telemetry to a specific
participant**. If all adapters have the same producer value (e.g. the
default `"beckn"`), the network observer sees all traffic as coming from one
participant and cannot distinguish buyer from seller.

**What happens if you get it wrong:**

- If `producer` doesn't match your actual subscriber ID → network-level
  dashboards will show an unknown participant name and cross-node correlation
  will break.
- If all adapters share the same `producer` → all traffic merges into one
  bucket in the network view.

---

#### ③ `producerType` — "Am I a BAP or BPP?"

Tells the network observer whether this adapter is a **buyer-side (BAP)** or
**seller-side (BPP)** participant.

| Value | Meaning | Use for |
| ----- | ------- | ------- |
| `"bap"` | Beckn Application Platform (buyer side) | `buyerapp`, `ledger-buyerdiscom` |
| `"bpp"` | Beckn Provider Platform (seller side) | `sellerapp`, `sellerdiscom`, `buyerdiscom`, `ledger-sellerdiscom` |

> **Note:** Some adapters (like `buyerapp`) have both `/bap/` and `/bpp/`
> modules. The `producerType` reflects the adapter's **primary network
> identity**, not every module it happens to host.

**What happens if you get it wrong:** Network dashboards will miscategorise
the participant. A seller will show up in the buyer section or vice versa.
This doesn't break data flow, but makes monitoring confusing.

---

#### ④ `otlpEndpoint` — "Where do I send my telemetry?"

This is the hostname and port of the **companion OTel collector** that
receives this adapter's telemetry over OTLP/gRPC.

- In the local Docker Compose setup, this is the **Docker service name** of
  the companion collector container (e.g. `otel-collector-buyerapp:4317`).
  Docker DNS resolves this automatically inside the compose network.
- Port `4317` is the standard OTLP/gRPC port.

**When to change:**

- **Local observability compose:** Don't change. The Docker service names in
  `docker-compose.observability.yml` already match.
- **Remote/VM deployment:** Replace the Docker service name with the
  collector's reachable hostname or IP address:
  ```yaml
  otlpEndpoint: "otel-collector.your-vm.internal:4317"
  ```
- **Renamed collectors:** If you rename a collector service in
  `docker-compose.observability.yml`, update this to match.

**What happens if you get it wrong:** The adapter will fail to connect to
the collector. You'll see gRPC connection errors in the adapter container
logs and no telemetry will appear in Grafana.

---

#### Putting It All Together — Example

Suppose you're forking this devkit for a company called "GreenGrid" with
subscriber IDs registered on the Beckn network. Here's what you'd change
for the buyer app:

**Before (default demo values):**

```yaml
config:
  serviceName: "p2p-wave2-buyerapp"
  producer: "buyerapp.example.com"
  producerType: "bap"
  otlpEndpoint: "otel-collector-buyerapp:4317"
```

**After (your deployment):**

```yaml
config:
  serviceName: "greengrid-buyerapp"
  producer: "bap.greengrid.energy"
  producerType: "bap"
  otlpEndpoint: "otel-collector-buyerapp:4317"   # unchanged for local compose
```

You'd do the same for each of the 6 adapter config files, matching the
`producer` to the subscriber ID in that adapter's `keyManager` section.

---

**Fragment files to update (one per adapter):**

| File | `producer` should match | `producerType` |
| ---- | ----------------------- | -------------- |
| `config/observability/fragments/local-p2p-trading-buyerapp.yaml` | Your buyer app subscriber ID | `bap` |
| `config/observability/fragments/local-p2p-trading-sellerapp.yaml` | Your seller app subscriber ID | `bpp` |
| `config/observability/fragments/local-p2p-trading-buyerdiscom.yaml` | Your buyer discom subscriber ID | `bpp` |
| `config/observability/fragments/local-p2p-trading-sellerdiscom.yaml` | Your seller discom subscriber ID | `bpp` |
| `config/observability/fragments/local-p2p-trading-ledger-buyerdiscom.yaml` | Your buyer discom ledger subscriber ID | `bap` |
| `config/observability/fragments/local-p2p-trading-ledger-sellerdiscom.yaml` | Your seller discom ledger subscriber ID | `bpp` |

The generated `config/observability/local-p2p-trading-*.yaml` files are
ignored by Git. Regenerate them after changing a base adapter config or an
observability fragment.

### 2. Docker Compose — OTLP Endpoint Environment Variables

Each ONIX adapter service receives OTLP environment variables from
`install/docker-compose.observability.yml`:

```yaml
environment:
  OTEL_EXPORTER_OTLP_ENDPOINT: otel-collector-buyerapp:4317
  OTEL_EXPORTER_OTLP_INSECURE: "true"
```

**When to change:**
- If you move the collector to a **remote host/VM**, replace the Docker
  service name with the collector's reachable hostname or IP
  (e.g. `otel-collector.yourvm.internal:4317`).
- If you enable **TLS** on the collector, set
  `OTEL_EXPORTER_OTLP_INSECURE: "false"`.

### 3. Audit Fields — `config/audit-fields.yaml`

Controls which Beckn payload fields are exported in audit logs and which
sensitive fields are masked.

**When to change:**
- Add fields you want to see in Grafana log panels
  (e.g. `message.contract.commitments[*].quantity`).
- Add masking rules for new sensitive fields specific to your domain.

### 4. Prometheus Scrape Config — `observability/prometheus.yml`

Lists all collector scrape targets. **Only change if** you add/remove
adapters or rename collector services.

### 5. Grafana Dashboard — `observability/grafana/provisioning/dashboards/json/`

The provisioned dashboard JSON auto-loads on startup. If you add custom
panels or modify queries, edit the JSON directly or export from the Grafana
UI and replace the file. Grafana will pick up changes within 30 seconds
(configured via `updateIntervalSeconds` in `dashboards.yml`).

### 6. Collector Configs (Rarely Changed)

| File | Purpose | Change when… |
| ---- | ------- | ------------ |
| `observability/otel-collector-node.yaml` | Shared per-node collector config | You need to add app-level trace/log exporters, change batch sizes, or adjust network filters |
| `observability/otel-collector-network.yaml` | Shared network collector config | You switch trace backend (e.g. Zipkin → Jaeger), change Loki endpoint, or adjust the `transform/beckn_ids` processor |

---

## Telemetry Flow in Detail

```
1. Beckn request → ONIX adapter
2. otelsetup plugin emits metrics + traces + audit logs via OTLP/gRPC
3. Companion collector receives on :4317
   ├── metrics/app   → Prometheus scrapes :8889 (all metrics, full fidelity)
   ├── metrics/network → filtered (only http_request_count) → network collector
   ├── traces/network  → filtered (only spans with transaction_id/sender.id) → network collector
   └── logs/network    → all logs → network collector
4. Network collector
   ├── metrics → Prometheus scrapes :8890
   ├── traces  → transform/beckn_ids (tx_id → TraceID) → Zipkin
   └── logs    → Loki (OTLP HTTP)
5. Grafana reads from Prometheus + Loki + Zipkin
```

Separately:

```
Docker container stdout/stderr → Promtail → Loki → Grafana Explore
```

---

## Grafana Dashboard Panels

The **P2P Wave 2 Observability** dashboard includes:

| Panel | Data Source | What It Shows |
| ----- | ----------- | ------------- |
| Request rate by Beckn action | Prometheus | `confirm`, `on_confirm`, `status`, `on_status` request rates |
| Request rate by node and status | Prometheus | Per-adapter breakdown with HTTP status codes |
| Participant traffic | Prometheus | Sender → recipient traffic flows |
| ONIX step p95 latency | Prometheus | 95th percentile latency for each ONIX processing step |
| ONIX logs by transaction ID | Loki | Filtered audit logs — use the `transactionId` variable |

**Template variables:**
- `transactionId` — textbox filter for log panel. Paste a Beckn
  `transaction_id` to narrow logs to one transaction.

**External links:**
- Zipkin traces — click the "Zipkin traces" link in the dashboard header to
  open the Zipkin UI for distributed trace investigation.

---

## Loki Queries (Grafana Explore)

Select the **Loki** datasource in Grafana Explore. Useful queries:

```logql
# All P2P Wave 2 container logs (via Promtail)
{compose_project="install"}

# Specific adapter container logs
{service="onix-buyerapp"}
{service="onix-sellerapp"}

# All ONIX adapter logs
{service=~"onix-.*"}

# Filter by Beckn action
{service=~"onix-.*"} |= "confirm"

# Filter by transaction ID
{service=~"onix-.*"} |= "your-transaction-id-here"

# OTel audit logs from the network collector
{service_name=~"p2p-wave2-.*"}

# Collector internal logs
{service="otel-collector-network"}
```

---

## Verification Checklist

After starting the observability-enabled stack and running a P2P flow:

- [ ] `observability-config-generator` completed successfully and generated adapter configs exist
- [ ] `docker compose -f docker-compose.yml -f docker-compose.observability.yml ps` — all services are `Up`
- [ ] Prometheus (`http://localhost:9090/targets`) — all 7 scrape targets
      show `UP`
- [ ] Grafana dashboard shows non-zero request rate panels
- [ ] Loki returns results for `{compose_project="install"}`
- [ ] Zipkin shows traces when searching by `serviceName`

### Common Problems

| Symptom | Likely Cause | Fix |
| ------- | ------------ | --- |
| Dashboard panels are empty | Time range doesn't include test requests | Set Grafana time range to "Last 15 minutes" and run a flow |
| Prometheus targets show `DOWN` | Collector containers not running | `docker compose ps` — check collector containers are `Up` |
| No Loki labels in Explore | Promtail not running or Docker socket not mounted | Check `p2p-wave2-promtail` is running; confirm `/var/run/docker.sock` is accessible |
| Zipkin shows no traces | ONIX image missing `otelsetup` plugin | Verify the adapter image (`fidedocker/onix-adapter-deg:v2`) includes the plugin |
| Collector logs show "unknown exporter" | Exporter name typo in collector YAML | Ensure exporters use `otlphttp` (no underscore), not `otlp_http` |
| Logs appear in Promtail but not in OTel audit panel | Loki label mismatch for OTLP-ingested logs | Query with `{service_name=~"p2p-wave2-.*"}` (underscore) instead of `{service=~"..."}` |

---

## VM / Remote Deployment

For hosting the receiver stack on a VM (e.g. the ledger-service VM):

1. Run only the receiver services on the VM: `otel-collector-network`,
   `prometheus`, `loki`, `promtail`, `zipkin`, `grafana`.
2. Keep collector, Prometheus, Loki, and Zipkin ports **internal** (not
   exposed to the public internet).
3. Expose only Grafana through the VM's existing public ingress (e.g.
   nginx/Caddy on `:3000`).
4. Update each ONIX adapter's `otelsetup.otlpEndpoint` to point to the
   VM-hosted collector:
   ```yaml
   otlpEndpoint: "otel-collector.your-vm.internal:4317"
   ```
5. Ensure port `4317` (OTLP/gRPC) is reachable from ONIX nodes to the
   collector host.
6. For TLS: configure the collector to serve TLS and set
   `OTEL_EXPORTER_OTLP_INSECURE: "false"` on each ONIX adapter.

---

## File Reference

```
install/
├── docker-compose.yml                     ← default lightweight devkit
├── docker-compose.observability.yml       ← explicit observability override
└── observability/
    ├── README.md                          ← this file
    ├── otel-collector-node.yaml           ← shared per-adapter collector config
    ├── otel-collector-network.yaml        ← network-level collector config
    ├── prometheus.yml                     ← Prometheus scrape targets
    ├── loki-config.yml                    ← Loki storage and schema config
    ├── promtail-config.yml                ← Promtail Docker log tailing config
    └── grafana/
        └── provisioning/
            ├── datasources/
            │   └── datasources.yml        ← Prometheus + Loki + Zipkin datasources
            └── dashboards/
                ├── dashboards.yml         ← dashboard auto-discovery config
                └── json/
                    └── p2p-wave2-dashboard.json ← pre-built Grafana dashboard
```
