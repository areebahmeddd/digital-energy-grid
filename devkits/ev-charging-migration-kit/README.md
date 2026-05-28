# EV Charging v2-rc to v2-lts Mapping Kit

This bundle adds request and response payload transformation for Beckn EV Charging flows moving between the v2-rc JSON-LD shape and the v2-lts shape.

The migration is done with the ONIX `reqmapper` payload transformer. No routing file changes are required for this bundle.

## Files

- `config/mappings.yaml`: JSONata mappings for EV Charging migration.
- `config/local-beckn-one-bap.yaml`: BAP adapter configuration with `payloadTransformer` enabled.
- `config/local-beckn-one-bpp.yaml`: BPP adapter configuration with `payloadTransformer` enabled.

## Supported Actions

The mapping file currently includes both request and callback mappings for:

- `discover`
- `on_discover`
- `select`
- `on_select`
- `init`
- `on_init`
- `confirm`
- `on_confirm`

Each action has both `bapMappings` and `bppMappings`. The adapter chooses the mapping direction from the configured transformer role.

## Configuration Changes

Add `payloadTransformer` to both BAP modules in `config/local-beckn-one-bap.yaml`.

```yaml
payloadTransformer:
  id: reqmapper
  config:
    role: bap
    mappingsFile: /app/config/mappings.yaml
```

Add `payloadTransformer` to both BPP modules in `config/local-beckn-one-bpp.yaml`.

```yaml
payloadTransformer:
  id: reqmapper
  config:
    role: bpp
    mappingsFile: /app/config/mappings.yaml
```

The role matters:

- Use `role: bap` inside BAP handlers.
- Use `role: bpp` inside BPP handlers.

## Step Changes

Add `transformPayload` to the handler steps wherever the transformer is configured.

For receiver modules, validate the original network payload first, then transform before forwarding to the local application.

```yaml
steps:
  - validateSign
  - addRoute
  - validateSchema
  - transformPayload
```

For caller modules, transform before signing and schema validation of the outgoing network payload.

```yaml
steps:
  - transformPayload
  - addRoute
  - sign
  - validateSchema
```

## Deployment

1. Copy these files into the target ONIX setup:

```text
config/local-beckn-one-bap.yaml
config/local-beckn-one-bpp.yaml
config/mappings.yaml
Readme.md
```

2. Make sure `config/mappings.yaml` is available inside the adapter container at:

```text
/app/config/mappings.yaml
```

3. Restart the BAP and BPP adapter containers so the new config and mappings are loaded.

## Verification

After restart, send an EV Charging flow request and check the adapter logs for messages like:

```text
Successfully transformed <action> request using bap mapping
Successfully transformed <action> request using bpp mapping
```

For BAP containers, the log should say `using bap mapping`. For BPP containers, it should say `using bpp mapping`.

If a BPP flow logs `using bap mapping`, the BPP config is using the wrong transformer role and payload fields may be dropped during transformation.
