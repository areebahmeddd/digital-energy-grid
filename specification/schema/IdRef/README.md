# IdRef

Reusable external identity reference schema.

## Versions

| Version | Status | Notes |
|---------|--------|-------|
| [v1.0](v1.0/README.md) | Current | Initial extraction from ElectricityCredential/EnergyCustomerProfile |

## Purpose

Links a utility customer account to an external identity authority. `issuedBy` is the DID or URI of the authority; `subjectId` is the subject's identifier within that authority's namespace.

Used by: `EnergyCustomerProfile/v1.0`, `ElectricityCredential/v1.1`, `ElectricityCredential/v1.2`
