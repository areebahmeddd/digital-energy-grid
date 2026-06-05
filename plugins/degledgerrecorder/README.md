# DEG Ledger Recorder Plugin

A Beckn-ONIX Step plugin that records trade data to the DEG Ledger after `on_confirm` calls.

## Overview

This plugin intercepts Beckn protocol messages and records or cascades them to the DEG Ledger service. Legacy ledger writes remain asynchronous. Wave 2 `ledgerApi: beckn` `on_confirm` writes are blocking by default, so ONIX forwards the original `on_confirm` only after the DISCOM ledger has ACKed the ledger entry.

## Features

- Automatically detects `on_confirm` actions
- Maps beckn protocol fields to DEG Ledger format
- Creates one ledger record per order item
- Asynchronous operation for legacy writes and status/on_status cascades
- Blocking Wave 2 Beckn `on_confirm` ledger writes before onward forwarding
- Configurable role (BUYER, SELLER, BUYER_DISCOM, SELLER_DISCOM)
- **Beckn-style signature authentication** (same as beckn-onix outgoing messages)
- Detailed request/response logging for debugging

## Building

```bash
# From DEG repository root - builds Docker image with plugin included
./build/build-multiarch.sh --load
```

This builds the `onix-adapter-deg` Docker image with the plugin included.

## Configuration

Add to your ONIX handler configuration:

```yaml
plugins:
  steps:
    - id: degledgerrecorder
      config:
        # Required mode flags — no code defaults; behavior must be visible here.
        payloadShape: wave2          # wave1 | wave2
        ledgerUriSource: payload     # config | payload
        ledgerApi: legacy_ledger     # legacy_ledger | beckn
        # ledgerHost: "https://ledger.example.org"  # required only when ledgerUriSource=config
        role: "BUYER"        # BUYER, SELLER, BUYER_DISCOM, or SELLER_DISCOM
        enabled: "true"      # Enable/disable the plugin
        asyncTimeout: "5000" # Timeout in milliseconds
        retryCount: "0"      # Retries after the first attempt (0 = no retry)
        retryMaxTTL: "10m"   # Maximum lifetime for one Beckn retry sequence
        retryBackoff: "5s"   # Fixed delay between failed attempts
steps:
  - validateSign
  - addRoute
  - degledgerrecorder      # Add after addRoute
  - validateSchema
```

### Configuration Options

#### Mode Flags (all required, no code defaults)

| Option | Values | Description |
|--------|--------|-------------|
| `payloadShape` | `wave1`, `wave2` | Which on_confirm body the mapper expects. `wave1` = `beckn:Order`/`orderItems` (p2p-trading-ies-wave1). `wave2` = `message.contract.commitments` (p2p-trading-ies-wave2, P2PTrade/v2.0). |
| `ledgerUriSource` | `config`, `payload` | Where to find the target ledger base URL. `config` reads `ledgerHost`. `payload` reads `participants[role=buyerDiscom\|sellerDiscom].participantAttributes.ledgerUrl` from the on_confirm body — required for wave2 since the URL varies per discom. |
| `ledgerApi` | `legacy_ledger`, `beckn` | API style. `legacy_ledger` POSTs to `<uri>/ledger/put` with the custom JSON body. `beckn` POSTs the original on_confirm verbatim (with rewritten context) to `<uri>/on_confirm` and expects a beckn ACK envelope wrapping the legacy ledger response. |

#### Core Settings

| Option | Required | Default | Description |
|--------|----------|---------|-------------|
| `ledgerHost` | When `ledgerUriSource=config` | - | Base URL of the DEG Ledger service |
| `role` | No | `BUYER` | Role for ledger records (see below) |
| `actions` | No | `on_confirm` | Comma-separated list of actions to trigger recording |
| `enabled` | No | `true` | Enable/disable plugin |
| `asyncTimeout` | No | `5000` | API call timeout (ms) |
| `retryCount` | No | `0` | Retries after the first attempt |
| `retryMaxTTL` | No | `10m` | Maximum total lifetime for one Beckn ACK retry sequence |
| `retryBackoff` | No | `5s` | Fixed delay between failed Beckn ACK attempts |
| `debugLogging` | No | `false` | Enable verbose request/response logging |

#### Per-call ledger URI from payload

When `ledgerUriSource=payload`, the plugin picks the URI based on `role`:
- `BUYER` → `participants[role=buyerDiscom].participantAttributes.ledgerUrl`
- `SELLER` → `participants[role=sellerDiscom].participantAttributes.ledgerUrl`

A platform instance (BAP or BPP) only writes to its own side's discom ledger. The same trade is logged in two ledgers (one per discom) at the system level, with each platform contacting only its own; if the two discoms share a TSP, both calls land at the same URL.

The discom `ledgerUrl` is carried via the [`DiscomLedgerProvider/v1.0`](../../specification/schema/DiscomLedgerProvider/v1.0/) schema.

#### `ledgerApi: beckn` mode

In beckn mode the plugin forwards the original `on_confirm` body verbatim — except for the `context` block, which is rewritten so the ledger TSP receives it as a BPP→BAP call:

| Field | Rewritten to |
|-------|--------------|
| `context.bppUri` | `<senderHost>/bpp/caller` |
| `context.bapUri` | `<discomLedgerUri>/bap/receiver` |

`senderHost` resolution order:
1. `senderHost` config option (e.g., `https://bap.example.com`).
2. Falls back to the host portion of `context.bapUri` (BUYER role) or `context.bppUri` (SELLER role) from the incoming payload.

The plugin then POSTs the rewritten body to `<discomLedgerUri>/bap/receiver/on_confirm` and expects a Beckn ACK envelope back:

```json
{
  "message": {
    "status":    "ACK",
    "messageId": "8153a419-35b1-4ec8-bd23-16fcff1b7964",
    "ledger":    { "success": true, "recordId": "rec-...", "creationTime": "...", "rowDigest": "sha256:..." }
  }
}
```

The `status` field lives directly under `message` — there is no nested `ack`
object. The inner `message.ledger` block carries the same fields the legacy
`/ledger/put` API used to return; the plugin surfaces it identically so
call-site logging stays uniform across the two modes.

For Wave 2 `ledgerApi: beckn`, every Beckn send must receive HTTP 2xx with `message.status = "ACK"` (flat — no nested `ack` object). Network errors, timeouts, non-2xx responses, malformed bodies, missing ACK, and NACK are retried using `retryCount` and `retryMaxTTL`.

Each send attempt waits up to `asyncTimeout` for ACK. `asyncTimeout` defaults to `5000` ms and is configurable in the plugin YAML. `retryBackoff` is only the wait between failed attempts and defaults to `5s`.

```yaml
retryBackoff: "5s"
```

Wave 2 `on_confirm` is synchronous. The ONIX step returns `nil` only after the DISCOM ledger returns ACK. If the ledger write is still not ACKed after retry exhaustion, or the target `ledgerUrl` cannot be resolved from the contract participants, the step returns an error and ONIX does not forward the original `on_confirm` to the next trading platform.

Wave 2 `status` and `on_status` cascades remain asynchronous. The plugin keeps the pending payload in memory only while retrying and removes it after ACK or final failure. If an async `on_status` cascade exhausts retries, the plugin sends a best-effort error `on_status` callback back to the original sender with `error.code = "DEG_ASYNC_ACK_TIMEOUT"`.

Stable failure prefixes:
- `DEG_LEDGER_URI_MISSING`: the target DISCOM ledger URI could not be resolved.
- `DEG_LEDGER_CONTEXT_REWRITE_FAILED`: the Beckn context could not be rewritten for the DISCOM ledger leg.
- `DEG_LEDGER_ACK_INVALID`: the DISCOM ledger returned HTTP 200 without `message.status = "ACK"` (flat check).
- `DEG_LEDGER_WRITE_FAILED`: the DISCOM ledger request failed or returned a non-2xx response.

| Option | Required | Default | Description |
|--------|----------|---------|-------------|
| `senderHost` | When `ledgerApi=beckn` and you want to override the derived value | derived from incoming context | Base URL (`scheme://host[:port]`) advertised as the BPP-side caller in the rewritten context |

#### Actions and Roles

| Action | Ledger Endpoint | Supported Roles | Description |
|--------|-----------------|-----------------|-------------|
| `on_confirm` | `/ledger/put` or Beckn `/bap/receiver/on_confirm` | BUYER, SELLER | Records trade agreement |
| `on_status` | `/ledger/record` | BUYER_DISCOM, SELLER_DISCOM | Records meter readings/validation metrics |

**Role behavior:**
- `BUYER` / `SELLER`: Platform roles, use `/ledger/put` for trade records
- `BUYER_DISCOM` / `SELLER_DISCOM`: Discom roles, use `/ledger/record` for validation metrics
  - `BUYER_DISCOM`: Maps `allocatedEnergy` → `ACTUAL_PULLED`
  - `SELLER_DISCOM`: Maps `allocatedEnergy` → `ACTUAL_PUSHED`

#### Authentication Options

The plugin supports two authentication methods:

**Option 1: Beckn-style Signature Authentication (Recommended)**

Uses the same ed25519 + BLAKE2b-512 signing mechanism as beckn-onix for outgoing messages. This generates an `Authorization` header with a cryptographic signature.

| Option | Alias (simplekeymanager-style) | Required | Default | Description |
|--------|-------------------------------|----------|---------|-------------|
| `signingPrivateKey` | (same) | Yes* | - | Base64-encoded ed25519 private key seed |
| `subscriberId` | `networkParticipant` | Yes* | - | Subscriber ID (e.g., `bap.example.org`) |
| `uniqueKeyId` | `keyId` | Yes* | - | Unique key ID |
| `signatureValiditySeconds` | - | No | `30` | How long the signature is valid |

*Required if using Beckn-style signing. If any signing field is set, all three must be set.

**Config key aliases:** You can use the same config keys as `simplekeymanager` (`networkParticipant`, `keyId`) for easy copy-paste.

**Option 2: Simple API Key Authentication**

| Option | Required | Default | Description |
|--------|----------|---------|-------------|
| `apiKey` | No | - | API key for ledger service authentication |
| `authHeader` | No | `X-API-Key` | Header name for the API key |

### Example 1: Zero-Config with Environment Variables (Recommended)

If you already have environment variables set for `simplekeymanager`, the plugin will **automatically** use them - no additional config needed:

```bash
# Environment variables (same as beckn-onix simplekeymanager)
export SIGNING_PRIVATE_KEY="<base64-encoded-ed25519-seed>"
export SUBSCRIBER_ID="bap.example.org"
export UNIQUE_KEY_ID="bap.example.org.k1"
```

```yaml
# Plugin config - no signing config needed!
plugins:
  steps:
    - id: degledgerrecorder
      config:
        payloadShape: wave1
        ledgerUriSource: config
        ledgerApi: legacy_ledger
        ledgerHost: "https://ledger.example.org"
        role: "BUYER"
        # Signing config automatically loaded from env vars
```

This approach is **compatible with**:
- **HashiCorp Vault** - secrets injected via Vault Agent
- **Kubernetes Secrets** - mounted as env vars
- **Docker Secrets** - exposed as env vars
- **AWS Secrets Manager** - via ECS/Lambda env injection
- **Azure Key Vault** - via env injection

### Example 2: Platform Recording (on_confirm only)

```yaml
plugins:
  steps:
    - id: degledgerrecorder
      config:
        payloadShape: wave1
        ledgerUriSource: config
        ledgerApi: legacy_ledger
        ledgerHost: "https://ledger.example.org"
        role: "BUYER"                    # Platform role
        actions: "on_confirm"            # Default, records trade agreements
        signingPrivateKey: "${SIGNING_PRIVATE_KEY}"
        networkParticipant: "bap.example.org"
        keyId: "bap.example.org.k1"
```

### Example 2a: Wave 2 — payload-sourced ledger URI

For p2p-trading-ies-wave2 the ledger URL is read per-call from the on_confirm payload:

```yaml
plugins:
  steps:
    - id: degledgerrecorder
      config:
        payloadShape: wave2
        ledgerUriSource: payload         # read from participants[role=*Discom].participantAttributes.ledgerUrl
        ledgerApi: legacy_ledger         # flip to "beckn" once the TSP is upgraded
        # ledgerHost intentionally omitted — the URI comes from the payload
        role: "BUYER"                    # BUYER on BAP side reads buyerDiscom; SELLER on BPP reads sellerDiscom
        actions: "on_confirm"
        signingPrivateKey: "${SIGNING_PRIVATE_KEY}"
        networkParticipant: "bap.example.com"
        keyId: "bap.example.com.k1"
```

The on_confirm payload must carry, in `message.contract.participants`:

```json
{
  "role": "buyerDiscom",
  "participantId": "buyer-discom-ledger",
  "participantAttributes": {
    "@context": ".../specification/schema/DiscomLedgerProvider/v1.0/context.jsonld",
    "@type": "DiscomLedgerProvider",
    "utilityId": "BRPL-DL",
    "ledgerUrl": "https://ies-p2p-energy-ledger.beckn.io"
  }
}
```

### Example 3: Discom Recording (on_status with meter readings)

```yaml
plugins:
  steps:
    - id: degledgerrecorder
      config:
        payloadShape: wave1
        ledgerUriSource: config
        ledgerApi: legacy_ledger
        ledgerHost: "https://ledger.example.org"
        role: "BUYER_DISCOM"             # Discom role for validation metrics
        actions: "on_status"             # Record meter readings
        signingPrivateKey: "${SIGNING_PRIVATE_KEY}"
        networkParticipant: "discom-buyer.example.org"
        keyId: "discom-buyer.example.org.k1"
```

### Example 4: Both Actions (Platform + Discom in same instance)

```yaml
plugins:
  steps:
    - id: degledgerrecorder
      config:
        payloadShape: wave1
        ledgerUriSource: config
        ledgerApi: legacy_ledger
        ledgerHost: "https://ledger.example.org"
        role: "BUYER_DISCOM"             # Use discom role if handling both
        actions: "on_confirm,on_status"  # Handle both actions
        signingPrivateKey: "${SIGNING_PRIVATE_KEY}"
        networkParticipant: "example.org"
        keyId: "example.org.k1"
```

**Note:** When `on_status` is enabled, the role must be `BUYER_DISCOM` or `SELLER_DISCOM`.

### Environment Variables Reference

| Variable | Description |
|----------|-------------|
| `SIGNING_PRIVATE_KEY` | Base64-encoded ed25519 private key seed |
| `SUBSCRIBER_ID` | Subscriber ID (e.g., `bap.example.org`) |
| `UNIQUE_KEY_ID` | Unique key ID (e.g., `bap.example.org.k1`) |

### Generated Authorization Header

```
Authorization: Signature keyId="bap.example.org|bap.example.org.k1|ed25519",algorithm="ed25519",created="1706547600",expires="1706547630",headers="(created) (expires) digest",signature="<base64_signature>"
```

### Vault Integration Example

```hcl
# Vault Agent template
template {
  contents = <<EOF
SIGNING_PRIVATE_KEY={{ with secret "secret/beckn/signing" }}{{ .Data.data.private_key }}{{ end }}
SUBSCRIBER_ID={{ with secret "secret/beckn/identity" }}{{ .Data.data.subscriber_id }}{{ end }}
UNIQUE_KEY_ID={{ with secret "secret/beckn/identity" }}{{ .Data.data.key_id }}{{ end }}
EOF
  destination = "/app/.env"
}
```

## Field Mapping

| Ledger Field | Source |
|--------------|--------|
| `transactionId` | `context.transaction_id` |
| `orderItemId` | `beckn:acceptedOffer.beckn:id` |
| `platformIdBuyer` | `context.bap_id` |
| `platformIdSeller` | `context.bpp_id` |
| `discomIdBuyer` | `beckn:orderAttributes.utilityIdBuyer` |
| `discomIdSeller` | `beckn:orderAttributes.utilityIdSeller` |
| `buyerId` | `beckn:buyer.beckn:id` |
| `sellerId` | `beckn:seller` |
| `tradeTime` | `context.timestamp` |
| `deliveryStartTime` | `beckn:timeWindow.schema:startTime` |
| `deliveryEndTime` | `beckn:timeWindow.schema:endTime` |

## Requirements

- Go 1.24+
- Beckn-ONIX (for plugin interface)
- DEG Ledger service accessible from ONIX instance

## Development

### Project Structure

```
plugins/degledgerrecorder/
├── cmd/
│   └── plugin.go     # Plugin entry point
├── config.go         # Configuration handling
├── mapper.go         # Payload mapping logic
├── client.go         # HTTP client for ledger API
├── signer.go         # Beckn-style signature generation
├── recorder.go       # Main step implementation
└── README.md
```

### Testing

```bash
cd plugins
go test ./degledgerrecorder/...
```

## License

See repository LICENSE file.
