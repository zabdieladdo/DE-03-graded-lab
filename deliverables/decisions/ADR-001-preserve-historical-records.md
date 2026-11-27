# ADR-001: Preserve and flag unresolved historical records

- **Status:** Accepted
- **Date:** 2026-11-25
- **Decision owner:** Zabdiel

## Context

Kloud Kart's original database contains historical records that reference nonexistent entities.

The referential integrity investigation identified:

- 692 order items referencing missing orders.
- 210 orders referencing missing customers.
- 120 inventory movements referencing missing products.
- One category referencing a missing parent.

All six relationship investigations reconciled without unexplained row-count differences.

The available dataset does not establish the correct replacement references. Deleting or reassigning records would therefore risk destroying historical evidence or introducing unsupported business information.

## Decision

Preserve historical records with unresolved relationships and explicitly flag them as exceptions. Recover their relationships only when trustworthy source evidence becomes available, while introducing appropriate controls to prevent new violations. Implemented six foreign keys (two validated and four `NOT VALID`) and five numerical checks. Historical violations remain visible; new writes are checked.

## Alternatives considered

### Alternative A: Delete unresolved records

- **How it would work:** Remove records whose references cannot be resolved.
- **Why it is attractive:** Simplifies reporting and constraint enforcement.
- **Why rejected:** Removes historical evidence and could exclude financially significant transactions without justification.

### Alternative B: Reassign unresolved references

- **How it would work:** Associate affected records with existing customers, orders, products or categories.
- **Why it is attractive:** Restores apparent referential integrity.
- **Why rejected:** Introduces relationships that cannot be verified and could misattribute financial or operational activity.

### Alternative C: Create placeholder entities

- **How it would work:** Create replacement entities for missing references.
- **Why it is attractive:** Allows existing references to resolve without deleting dependent records.
- **Why rejected:** Risks presenting unknown entities as genuine business records and complicates interpretation.

## Consequences

- **What this buys:** Preservation of historical evidence, transparent exception reporting and a recoverable path to correcting relationships. Prevents the tested new integrity violations.
- **What this costs:** Additional exception-handling logic, reconciliation effort and potentially more complex integrity enforcement. Historical invalid rows may be difficult to update.
- **What it costs the client if I am wrong:** Unresolved records may continue to distort reports if exception handling is incomplete or misunderstood.
- **What would make me revisit this:** Availability of authoritative recovery information, evidence of unacceptable reporting overhead, or an approved business retention policy. Validate remaining constraints after verified remediation.

## What this survives

The decision accommodates future recovery of missing references, additional historical integrity findings and the gradual introduction of stronger database constraints.

The treatment does not depend on inventing replacement entities or permanently removing unresolved historical records.

Schema verification passed 24 assertions, including 16 rejection tests. Historical row counts remained unchanged. Final fresh-load acceptance remains pending.

Supporting evidence:

- `sql/01_diagnosis/02_referential_integrity.sql`
- `evidence/02_referential_integrity.txt`

See [evidence and decision index](../EVIDENCE_INDEX.md) for checkpoint identifiers.
