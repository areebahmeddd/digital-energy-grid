# Energy Credentials

Schemas for Verifiable Credentials in the energy sector.

## Overview

This collection provides schemas for credentials issued by energy providers to consumers and prosumers. The credentials are designed to be privacy-preserving and follow the W3C VC Data Model 2.0.

## Available Credentials

| Credential | Description | Purpose |
|------------|-------------|---------|
| [Customer Credential](./electricity-credential/) | Unified credential combining customer identity, consumption, generation, and storage profiles | Single credential per meter for consumer/prosumer identity |
| [Program Enrollment Credential](./program-enrollment-vc/) | Energy program participation | P2P trading, demand response, virtual power plants, ToU programs |

## Shared Data Objects

Both credentials share the same `customerProfile` and `customerDetails` object structures:

- **customerProfile** — customer number, meter number, meter type, masked government ID
- **customerDetails** — full name, installation address (with optional geo tagging and Open Location Code), service connection date

In the Customer Credential these are required; in the Program Enrollment Credential they are optional.

## Directory Structure

```
energy-credentials/
├── electricity-credential/       # Customer Credential (all profiles in one)
│   ├── schema.json
│   ├── context.jsonld
│   ├── example.json
│   └── readme.md
├── program-enrollment-vc/        # Program participation
│   ├── schema.json
│   ├── context.jsonld
│   ├── example.json
│   └── readme.md
└── readme.md                     # This file
```

## Schema Standards

All schemas follow:
- W3C Verifiable Credentials Data Model 2.0
- JSON-LD 1.1 for semantic interoperability
- JSON Schema (draft 2020-12) for validation
- Schema.org vocabulary where applicable
