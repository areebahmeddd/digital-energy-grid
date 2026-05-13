# Data Exchange Devkit

Beckn Protocol v2.0 devkit demonstrating **inline data delivery** via DDM's `DatasetItem` schema. Datasets are embedded directly in beckn messages through the `dataPayload` attribute rather than fetched from external URLs.

For the shared stack topology, prerequisites, Quick Start, transaction flow, hosting, ngrok notes, and cleanup, see [../README.md](../README.md).

## Use Cases

| Use Case | BPP (Provider) | BAP (Consumer) | dataPayload | Description |
|----------|---------------|----------------|-------------|-------------|
| [uc1-meter-data](./uc1-meter-data/) | IntelliGrid AMI Services (AMISP) | BESCOM (discom) | `IES_Report` — 15-min kWh meter readings | AMI meter data exchange under existing contract |
| [uc2-regulatory-data](./uc2-regulatory-data/) | BESCOM (discom) | APERC (state regulator) | `IES_ARR_Filing` — cost line items, fiscal years | ARR filing submission under regulatory mandate |
| [uc3-tariff-policy](./uc3-tariff-policy/) | MERC (state regulator) | MeraShehar (discom) | `IES_Policy` — energy slabs + time-of-day surcharges | Retail tariff policy distribution under public-disclosure norms |
| [uc4-streaming](./uc4-streaming/) | IntelliGrid AMI Services (AMISP) | BESCOM (discom) | `DatasetFulfillment` — MQTT / Kafka / API / S3 datalake credentials | Real-time stream delivery; credentials in `on_confirm`, rotation via `update` |

All use cases share the same docker stack, adapter configs, and runner.

## Postman

Each use case ships BAP and BPP Postman collections under `postman/`:

- `uc1-meter-data/postman/data-exchange-uc1-meter-data.{BAP,BPP}-DEG.postman_collection.json`
- `uc2-regulatory-data/postman/data-exchange-uc2-regulatory-data.{BAP,BPP}-DEG.postman_collection.json`
- `uc3-tariff-policy/postman/data-exchange-uc3-tariff-policy.{BAP,BPP}-DEG.postman_collection.json`
- `uc4-streaming/postman/data-exchange-uc4-streaming.{BAP,BPP}-DEG.postman_collection.json`

Import a collection into Postman and hit Send. Default request URLs point at `localhost:8081`/`8082` (BAP/BPP caller endpoints); change them to your ngrok URL to send over the tunnel. Collections are regenerated with `python3 scripts/generate_postman_collection.py --role BAP|BPP [--usecase uc1-meter-data|uc2-regulatory-data|uc3-tariff-policy]`.

## Related

- [DDM DatasetItem Schema](https://github.com/beckn/DDM/tree/main/specification/schema/DatasetItem/v1) — `dataPayload` and `accessMethod`
- [IES Core Schemas](https://github.com/beckn/DEG/tree/ies-specs/specification/external/schema/ies/core) — IES_Report, IES_Program, IES_Policy, EnergySlab, SurchargeTariff (OpenADR 3.1.0)
- [IES tariff specification example (ies-docs)](https://github.com/India-Energy-Stack/ies-docs/blob/main/implementation-guides/data_exchange/examples/tariff_specification_example.jsonld) — source for uc3-tariff-policy `IES_Policy` payload
- [IES ARR Schemas](https://github.com/beckn/DEG/tree/ies-specs/specification/external/schema/ies/arr) — IES_ARR_Filing, IES_ARR_FiscalYear, IES_ARR_LineItem
- beckn/beckn-onix#655 — ONIX regex engine issue with OpenADR duration patterns
