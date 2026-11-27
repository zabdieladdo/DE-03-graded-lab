# ADR-004: Retain on-demand SQL reporting

- **Status:** Accepted
- **Date:** 2026-11-27
- **Decision owner:** Zabdiel

## Context

Nana needs the Monday report in seconds on the existing server. The original forty-minute query is unavailable, so no measured speedup against it can be claimed.

## Decision

Use shared eligibility definitions, set-based aggregation, window functions and direct customer-grain ranking. Generate the six report outputs in one read-only repeatable-read snapshot. Retain on-demand calculations at the tested volume.

## Alternatives considered

- **Rank from sparse monthly aggregates:** Reuses monthly activity but repeats aggregation. Equivalent direct ranking took a median 484.836 ms versus 930.033 ms for the sparse alternative (47.87% lower). Both reporting dates and ranking bases matched across 14 fields. Direct ranking remained faster with JIT disabled; this does not isolate aggregation grain as the sole cause.
- **Persist precomputed reporting results:** Could accelerate repeated reads but adds refresh, freshness, storage and maintenance obligations. No measured need justifies those costs at present.

## Consequences

- **What this buys:** Verified reporting semantics and consistent snapshots without additional persistent reporting objects or infrastructure. Integrated SQL workload measured 3.487 s alone and 4.227 s during checkout in one trial each.
- **What this costs:** Repeated calculations across interfaces, dense monthly output and temporary storage. Earlier integrated runs took 5.276–5.929 s and all four missed the provisional five-second target. The complete workflow is not a single physical scan.
- **What it costs the client if I am wrong:** Slow or unavailable reports, checkout contention or delayed decisions as volume grows.
- **What would make me revisit this:** Repeated target misses, growth, checkout degradation or changed freshness requirements. Verify equivalent outputs before adopting any alternative.

## What this survives

Correctness tests cover two cutoffs, monthly and running totals and deterministic ranking. The integrated checkout trial passed with 50 wins, 350 refusals and no errors. Different session setup and uncontrolled caches prevent a causal speedup claim. Consistent five-second compliance, projected growth and final fresh-load acceptance remain unverified. The full verified file publication is a separate workload (ADR-007).

See [customer reporting measurements](../performance/customer_reporting_performance.md) and [integrated workload measurements](../performance/integrated_workload_performance.md).

See [evidence and decision index](../EVIDENCE_INDEX.md) for checkpoint identifiers.
