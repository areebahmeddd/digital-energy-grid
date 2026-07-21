# DiscomLedgerProvider — v1.0

Identity attributes for a discom acting as a `buyerDiscom` / `sellerDiscom` party in a P2P trade. Attached to `Contract.participants[*].participantAttributes` (and to the offer's `participants[]` at catalog publish).

The party's `id` is the discom's **UPADHI short code** (e.g. `PVVNL`, `TPDDL`, `BRPL`) — a stable, regulator-defined identifier — and is not repeated in these attributes. The attributes carry the discom's beckn `subscriberId` (routing/signing identity), its platform endpoint (`discomUri`), and its ledger (`ledgerId` + `ledgerUri`).

Part of the [DEG Schema](../../../specification/schema/) · [DiscomLedgerProvider](../README.md)

## Files

| File | Description |
|------|-------------|
| [attributes.yaml](./attributes.yaml) | JSON Schema 2020-12 definition for `DiscomLedgerProvider` |
| [context.jsonld](./context.jsonld) | JSON-LD context (namespace: `https://schema.nfh.global/deg/DiscomLedgerProvider/v1.0/`) |
| [vocab.jsonld](./vocab.jsonld) | RDF vocabulary for `DiscomLedgerProvider` terms |

## Properties

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `subscriberId` | `string` | ✅ | The discom node's beckn subscriber id (routing/signing; appears as bppId/bapId on cascade legs) |
| `discomUri` | `string` (uri) | ✅ | Base URL of the discom's own Beckn platform (init/cascade + unallocated-trade allocation) |
| `ledgerId` | `string` | ✅ | Subscriber id of the discom's ledger TSP (a distinct party) |
| `ledgerUri` | `string` (uri) | ✅ | Base URL of the discom ledger TSP where trades are recorded after `on_confirm` |

## Usage

The participant `id` is the discom's **UPADHI short code** (e.g. `PVVNL`), referenced from `contractAttributes.roles[role=buyerDiscom|sellerDiscom].participantId`; the beckn routing identity is the `subscriberId` attribute. Two discoms MAY share a `ledgerId`/`ledgerUri` if they use the same TSP; each platform still calls only its own side's discom: BAP → `buyerDiscom`, BPP → `sellerDiscom`.

The `degledgerrecorder` plugin resolves the discom participant via the role→id join and reads `ledgerUri` (where to record) and `discomUri` (where to route allocation).
