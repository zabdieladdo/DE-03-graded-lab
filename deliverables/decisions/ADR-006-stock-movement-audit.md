# ADR-006: Automatically record existing-stock changes and enrich business context

- **Status:** Accepted
- **Date:** 2026-11-27
- **Decision owner:** Zabdiel

## Context
Sales already used an atomic conditional deduction and explicit inventory logging (ADR-002). Restocks, corrections and ordinary direct updates also need an audit trail. A second sale insert would double-count stock movement. Historical opening balances and individual employee identities are not verified.

## Decision
Use an AFTER UPDATE row trigger for changed existing stock values, recording signed delta, before/after, session user and timestamp. Preserve the atomic sale predicate and routine contract; enrich the exact trigger-generated record with the order reference or adjustment reason and explanation using a transaction-local log ID. Keep historical rows unchanged with nullable new columns.

## Alternatives considered
### Alternative A: Explicit logging in every business routine
- **How it would work:** Each routine inserts its own audit row, with permissions restricting other writes.
- **Why it is attractive:** Clear business context, fewer moving parts.
- **Why rejected:** Ordinary direct updates could bypass logging under current permissions; strict role design is not implemented.

### Alternative B: Ledger as sole source of stock
- **How it would work:** Derive current stock from opening balances and movements.
- **Why it is attractive:** Natural reconciliation and movement-based accounting.
- **Why rejected:** Requires a larger redesign and trustworthy opening balances that the supplied history does not establish.

## Consequences
- **What this buys:** One movement per changed row under normal operation, business context for controlled routines, generic correction for direct updates, atomic rollback with the purchase or adjustment.
- **What this costs:** Trigger insert and routine enrichment update; extra storage, coupling to the transaction-local pointer and trigger configuration. Unknown-stock transitions and unrepresentable integer deltas fail rather than invent an audit value. Direct updates lack a business explanation.
- **What it costs the client if I am wrong:** Missing or duplicate movements undermine audit trust; an audit failure can block a legitimate sale. A session account is not proof of individual identity. Privileged users can alter logs or disable triggers; product insertion/deletion is outside scope.
- **What would make me revisit this:** Measured checkout degradation, additional triggers modifying stock or the pointer, stronger audit retention/access requirements, verified opening balances, or need to track product creation/deletion. The pointer is not a security boundary; normal trigger execution is assumed.

## What this survives
E055 committed; E056 eight PASS including restock, negative correction, exact single sale movement with order ID, multi-row direct updates, no-op, refusals, injected failure and rollback. E057 official harness passed all four scenarios, 463 attempts, 80 successes, 383 refusals, zero errors; 400 buyers/50 units in 2.10 s, no oversell, five sales/five movements in audit scenario. Previous explicit logging run 1.89 s; observed +0.21 s, not isolated trigger overhead. Fixture cleanup was subsequently confirmed; candidate fresh-load functional acceptance passed (E077c); final merged revision verification remains pending. ADR-002's atomic allocation decision remains in force; its explicit logging implementation is amended by this ADR.

See [evidence and decision index](../EVIDENCE_INDEX.md) for checkpoint identifiers.
