# OpenADR 3.1.0 — Vendored Spec

OpenAPI 3.0 / JSON-Schema description of the OpenADR 3.1.0 protocol, vendored
here so DEG schemas can `$ref` its types (intervals, payloads, descriptors)
without re-defining time-series semantics.

**Upstream:** OpenADR Alliance — <https://www.openadr.org/>
**Mirror used:**
[`India-Energy-Stack/ies-docs/.../specs/openadr3.yaml`](https://github.com/India-Energy-Stack/ies-docs/tree/main/implementation-guides/data_exchange/specs)

---

## Files

| File | Description |
|------|-------------|
| [openadr3.yaml](./openadr3.yaml) | OpenADR 3.1.0 OpenAPI 3.0 spec, used as a `$ref` source |

---

## Why this lives in DEG

DEG schemas (e.g. `BecknTimeSeries`) re-use OpenADR's well-defined
time-series primitives — `interval`, `intervalPeriod`, `valuesMap`,
`reportPayloadDescriptor`, `point` — instead of inventing parallel shapes.
Vendoring the spec at a stable URL (`specification/external/openadr/3.1.0/`)
means DEG schemas can `$ref` it from any branch / tag without depending on
upstream availability.

## Usage from DEG schemas

```yaml
intervalPeriod:
  $ref: "https://raw.githubusercontent.com/beckn/DEG/refs/heads/main/specification/external/openadr/3.1.0/openadr3.yaml#/components/schemas/intervalPeriod"
```

beckn-onix's extended-schema validator (kin-openapi backed) follows external
`$ref`s, so embedded payloads marked with `@type: BecknTimeSeries` validate
end-to-end against the OpenADR shapes.
