# Green Button / ESPI Schema

## attributes.yaml

OpenAPI 3.0 specification converted from the NAESB ESPI XML Schema Definition
(XSD) at https://naesb.org/espi.xsd using the
[xsd-to-openapi-jsonld](https://github.com/Beckn-One/xsd-to-openapi-jsonld) converter.

This is the **base** Green Button / ESPI schema — consumer-facing meter data
types as defined by NAESB REQ.21 ESPI (derived from IEC 61968-9).

## espi_with_cim_extn.yaml

**Optional** CIM extension for meter telemetry across all power-sector levels:
consumer (AMI), distribution transformer, and transmission / SCADA.

All types in this file are additive — the base ESPI types in `attributes.yaml`
are unchanged.  The extension brings in CIM classes from IEC 61968 (Metering,
Assets) and IEC 61970 (Base/Meas) that ESPI does not cover.

### What it adds

#### Device & metering infrastructure (IEC 61968 Metering)

| Schema | Purpose |
|--------|---------|
| `EndDevice` / `Meter` | Physical meter: serial number, AMR system, form number, virtual flag, smart-inverter flag |
| `EndDeviceInfo` + `EndDeviceCapability` | Nameplate data with 18 capability flags (DR, connect/disconnect, reverse flow, etc.) |
| `Channel` / `Register` | Physical measurement channels, dial counts, TOU tiers |
| `MeterMultiplier` | CT/PT ratios and other instrument-transformer corrections |
| `UsagePointCIM` | CIM-enriched usage point: `connectionState`, `phaseCode`, `nominalServiceVoltage`, `ratedCurrent`, `ratedPower`, `amiBillingReady`, outage region, read cycle/route |

#### Events (IEC 61968 Metering)

| Schema | Purpose |
|--------|---------|
| `EndDeviceEvent` | Outage, tamper, diagnostic, demand-response events with severity and structured type codes |
| `EndDeviceEventType` | Structured event code: `type.domain.subDomain.eventOrAction` (IEC 61968-9 Annex E) |
| `EndDeviceEventDetail` | Name-value detail pairs attached to events |

#### SCADA / transmission telemetry (IEC 61970 Base/Meas)

| Schema | Purpose |
|--------|---------|
| `Measurement` / `Analog` / `Discrete` | Measurement definitions with unit, multiplier, phases, and references to network resources and terminals |
| `AnalogValue` / `DiscreteValue` / `AccumulatorValue` | Timestamped telemetry values with quality flags and source attribution |
| `MeasurementValueQuality` | Validity (good/questionable/invalid) + source (SCADA/estimator/manual) |

#### Instrument transformers & power transformers (IEC 61968 Assets / IEC 61970 Wires)

| Schema | Purpose |
|--------|---------|
| `CurrentTransformerInfo` | CT accuracy class, ratio, burden, usage (metering/protection) |
| `PotentialTransformerInfo` | PT/VT accuracy class, ratio, type (inductive/capacitive) |
| `PowerTransformerInfo` / `PowerTransformerEnd` | Vector group, winding connection, rated S/U, impedance — contextualises transformer-level metering |

#### Enumerations (CIM additions beyond ESPI)

| Enum | Values |
|------|--------|
| `PhaseCode` | ABC, AB, AC, BC, A, B, C, N, ABCN, s1, s2, s12, … (22 values) |
| `UsagePointConnectedKind` | connected, logicallyDisconnected, physicallyDisconnected |
| `AmiBillingReadyKind` | amiCapable, amiDisabled, billingApproved, enabled, nonAmi, nonMetered, operable |
| `MeterMultiplierKind` | ctRatio, ptRatio, transformerRatio, kH, kR, kE |
| `WindingConnection` | D, Y, Z, Yn, Zn, A, I |
| `MeasurementValueSourceKind` | SCADA, estimator, manualEntry, calculated, defaultValue |
| `ComTechnologyKind` | cellular, ethernet, homePlug, pager, phone, plc, rf, rfMesh, zigbee |
| `ComDirectionKind` | biDirectional, fromDevice, toDevice |
| `ReadingReasonKind` | billing, demandReset, inquiry, installation, moveIn, moveOut, removal, … (12 values) |
| `MacroPeriodKind` | none, billingPeriod, daily, monthly, seasonal, weekly, specifiedPeriod |
| `MeasuringPeriodKind` | none, oneMinute … sixtyMinute, twentyfourHour, fixedBlock*, rollingBlock* (41 values) |
| `AggregateKind` | none, average, excess, maximum, minimum, nominal, normal, sum, … (15 values) |
| `ReadingQualityType` | valid, manuallyEdited, estimated, interpolated, failed, … (14 values) |

#### Integration type

| Schema | Purpose |
|--------|---------|
| `MeterTelemetryReading` | Composite wrapper that holds ESPI IntervalBlocks alongside CIM device context, instrument-transformer info, SCADA measurements, and events — works for any metering level |

### Sources

- [IEC 61968-9](https://webstore.iec.ch/en/publication/75041) — Metering (end device, events, channels, registers)
- [IEC 61970](https://webstore.iec.ch/en/publication/6034) — Base/Meas (SCADA telemetry: Analog, Discrete, Accumulator)
- [IEC 61968](https://webstore.iec.ch/en/publication/6196) — Assets (instrument transformers, multipliers)
- [Balijepalli & Khaparde, "Enablement of Consumer-Oriented Interoperable Systems With Integration of CIM and Green Button Standards"](https://ieeexplore.ieee.org/document/6516945), IEEE Systems Journal, 2013
- [NAESB ESPI XSD](https://naesb.org/espi.xsd) — source schema for `attributes.yaml`
- [TNO CIM Ontology Reference](https://ontology.tno.nl/IEC_CIM/) — CIM class and enum definitions
- [Zepben CIM100 Data Model](https://zepben.github.io/evolve/docs/cim/cim100/) — CIM class reference
- [CIM Users Group JSON-LD Syntax](https://github.com/cimug-org/CIM_JSON-LD_Syntax) — official CIM JSON-LD effort
- [Azure Digital Twins Energy Grid Ontology](https://github.com/Azure/opendigitaltwins-energygrid) — DTDL/JSON-LD CIM implementation
- [Green Button Alliance](https://www.greenbuttonalliance.org/) — ESPI standards and OpenADE
- [EPRI CIM Primer](https://msites.epri.com/rd/research/062333/common-information-model-primer/chapter-1-introduction-to-the-iec-cim) — introduction to IEC CIM

### Note on AMR system type

CIM's `EndDevice.amrSystem` is a **free-form string**, not a constrained enum.
The communication technology and direction are instead captured by:
- `ComTechnologyKind` (cellular, plc, rfMesh, zigbee, etc.)
- `ComDirectionKind` (biDirectional = two-way AMI, fromDevice = one-way AMR)
