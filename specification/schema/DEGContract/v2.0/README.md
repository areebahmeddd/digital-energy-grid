# DEGContract — v2.0

Standard contract schema for all DEG energy contracts.

Part of the [DEG Schema](../../) · [DEGContract](../README.md)

## Files

| File | Description |
|------|-------------|
| [attributes.yaml](./attributes.yaml) | OpenAPI 3.1.1 components.schemas.`DEGContract` (JSON Schema 2020-12 body) |
| [context.jsonld](./context.jsonld) | JSON-LD context (namespace `https://schema.beckn.io/deg/DEGContract/v2.0/`) |
| [vocab.jsonld](./vocab.jsonld) | RDF vocabulary for `DEGContract` terms |

## Properties

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `roles` | `array` | ✅ | Contract roles. The participantId key is required on every role entry, but its value MA... |
| `policy` | `object` | ✅ | OPA/Rego policy governing this contract. |
| `revenueFlows` | `array` |  | Optional. Settlement-time per-role flows written by the `contractpolicyenforcer` plugin when it i... |
