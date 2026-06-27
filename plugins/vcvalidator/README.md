# vcvalidator — Verifiable Credential validator middleware

A beckn-onix HTTP middleware plugin that verifies the Verifiable Credentials
embedded in a request body. When enabled it gates the configured beckn
action(s) and rejects the request with a **NACK** if any embedded credential
fails verification.

In the DEG data-exchange flow the credential is the `MeterDataRequestCredential`
carried in the `confirm` message's receiver participant
(`message.contract.participants[].participantAttributes`).

## What it checks

For every embedded credential (any JSON object carrying both `proof` and
`credentialSubject`):

1. **Proof signature** — verifies a VC-JWT (`proof.jwt`) signature against the
   issuer's public key, resolved from the issuer DID. Supported DID methods:
   - `did:key` — `ed25519` (`z6Mk…`), `P-256` (`zDn…`), `secp256k1` (`zQ3…`)
   - `did:jwk` — embedded JWK
   - `did:web` — fetches `https://<host>/[path/]did.json` and reads the
     verification method's `publicKeyJwk` / `publicKeyMultibase`
2. **Issuer binding** — the JWT signer (`kid` controller DID) must equal the
   credential's declared `issuer`. A credential signed by anyone other than its
   issuer is rejected (`ISSUER_MISMATCH`). This is how the "signed by the
   `did:web` id" requirement is enforced when the issuer is a web-accessible
   `did:web`.
3. **Validity window** — `validFrom`/`validUntil` and the JWT `nbf`/`exp`.
4. **Revocation** — if `credentialStatus` is present: StatusList2021 /
   BitstringStatusList bitstring lookup, or a DEDI / generic revoked indicator.

### A note on JSON-LD Data Integrity proofs

Proofs of type `Ed25519Signature2020`/`DataIntegrityProof` (with a `proofValue`
rather than a `jwt`) require RDF canonicalisation (URDNA2015), which this plugin
does **not** implement. With `requireProof: true` (default) such credentials are
rejected; with `requireProof: false` the signature step is skipped (only
expiry/revocation and verification-method resolvability are checked).

## NACK error codes

| code | meaning |
|------|---------|
| `INVALID_CREDENTIAL` | malformed credential / missing issuer (HTTP 400) |
| `INVALID_PROOF` | signature invalid, missing, or alg mismatch (HTTP 401) |
| `ISSUER_MISMATCH` | proof signer ≠ declared issuer (HTTP 401) |
| `CREDENTIAL_EXPIRED` | outside validity window (HTTP 401) |
| `DID_RESOLUTION_FAILED` | could not resolve issuer/VM DID (HTTP 401) |
| `CREDENTIAL_REVOKED` | revoked per credentialStatus (HTTP 403) |

The NACK body matches beckn-onix's v2 shape:
`{"message":{"status":"NACK","messageId":"…","error":{"code":"…","message":"…"}}}`.

## Configuration

Wired as a `middleware` entry on a module handler:

```yaml
middleware:
  - id: vcvalidator
    config:
      enabled: "true"           # master switch
      actions: "confirm"        # REQUIRED — comma list of gated beckn actions
      allowedDidMethods: "key,jwk,web"
      checkExpiry: "true"
      checkRevocation: "true"
      requireProof: "true"      # reject proofs this plugin can't verify
      failOpen: "false"         # on did:web/revocation network errors: false=reject
      httpTimeout: "10"         # seconds
      debugLogging: "true"
```

`actions` is required when `enabled` — there is no hidden default, so the gated
messages are always visible from the config.

## Testing

Unit tests (offline, including the real flockenergy `did:key` VC fixture):

```bash
cd plugins && go test ./vcvalidator/
```

End-to-end against the running data-exchange devkit:

```bash
cd devkits/data-exchange/uc1-meter-data/workflows
./run-vc-validation.sh
```
