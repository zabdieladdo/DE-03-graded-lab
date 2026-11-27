# ADR-004: Retain verified on-demand reporting and defer further optimization until justified

- **Status:** Accepted
- **Date:** 2026-11-27
- **Decision owner:** Zabdiel Addo (review before submission)

## Context

Nana wants the Monday report in seconds on an ordinary laptop, without new infrastructure. The historical forty-minute report is client-reported; its original query is unavailable. D029–D032 considered monthly grain, direct ranking, precomputation and shared execution. The learner subsequently prioritized completing mandatory lab requirements over supplementary optimization.

## Decision

I retain the verified on-demand SQL reporting interfaces (Architecture A) as the working implementation, using shared eligibility/window definitions, set-based aggregation, explicit window functions and direct customer-grain ranking. I execute the core outputs in one read-only repeatable-read snapshot and defer shared intermediate computation (B) and persistent precomputation (C) until mandatory work is complete and measured need justifies them.

This accepts the implementation choice, not final performance acceptance. E050 missed the provisional 5-second combined workload target in all four runs. That target and 10x growth scenario were engineering assumptions, not numerical client commitments. Do not change the target retrospectively or claim it passed. Revisit the conditional gate during final performance work if time permits or if required acceptance fails.

## Alternatives considered

### Alternative A: Rank from sparse monthly aggregates plus opening balances

- **How it would work:** Aggregate monthly rows again by customer and calculate opening balances separately.
- **Why it is attractive:** Reuses monthly calculations and could simplify shared report semantics.
- **Why rejected:** E048 verified identical 14-field outputs for both dates and bases; direct median 484.836 ms versus sparse 930.033 ms (47.87% reduction). E049 direct remained faster with JIT disabled (546.396 versus 1,110.108 ms). Different function boundaries and estimates prevent attributing the entire difference to aggregation grain alone.

### Alternative B: Share intermediate calculations across report statements

- **How it would work:** Prototype a temporary ranked population for top-100 and metadata, then broader shared aggregates only if needed.
- **Why it is attractive:** E050 ranking plus metadata median 1,912.950 ms; repeated computation is a credible optimization opportunity.
- **Why rejected for now:** E051 is unexecuted; creation, scanning, cleanup and metadata equivalence costs are unmeasured. Further complexity would delay mandatory inventory and audit work. The performance gate remains open, not waived.

### Alternative C: Persistent materialized results

- **How it would work:** Store and refresh reporting results, potentially with indexes.
- **Why it is attractive:** May accelerate repeated reads.
- **Why rejected for now:** Adds freshness, refresh contention, storage and maintenance obligations. No equivalent graded workload evidence establishes a need. Consider only if simpler approaches cannot satisfy agreed requirements.

### Alternative D: Change global configuration or add infrastructure

- **How it would work:** Disable JIT globally, raise memory settings or provision more resources.
- **Why it is attractive:** Could reduce compilation or temporary I/O.
- **Why rejected:** E049 is report-specific; global tuning can harm other workloads. No new infrastructure is permitted. Report-local changes need evidence and concurrent checkout testing.

## Consequences

- **What this buys:** Verified existing interfaces, consistent snapshots, no new persistent reporting objects, and a measured full workload of 5.276–5.929 seconds at headline. Six E050 integration checks passed. Running totals and rankings use set-based window calculations rather than procedural per-customer loops.
- **What this costs:** Separate report calls repeat work; dense monthly output and temporary storage remain substantial. E044 monthly running median 1,292.742 ms (server execution), E050 monthly/running component median 2,633.804 ms (sorted CSV transfer). Function scans can prevent early filtering and obscure internal plans. The complete workload is not a single physical scan; the rubric's one-pass objective is not claimed across all interfaces.
- **What it costs the client if I am wrong:** Reporting may slow checkout or become too slow as volume grows; stale or unavailable reports could delay decisions. Premature materialization could introduce stale figures and operational burden.
- **What would make me revisit this:** Final performance gate failure, unacceptable checkout degradation, changed report frequency/freshness, growth beyond measured volume, or a demonstrably equivalent improvement. If A meets agreed current and projected budgets and operational checks, stop; otherwise prototype B, and consider C only if B remains insufficient. Correctness failures must be fixed first.

## What this survives

The architecture can evolve without changing the spending contract in ADR-003. Existing correctness tests provide a reference for equivalent alternatives. Final fresh-load, concurrent report/checkout, growth and actual delivery performance remain unverified. No claim of measured forty-minute-to-seconds improvement is made.


## Addendum — 2026-11-27 (E058 / proposed D035)

Observed current-volume gates passed: solo 3.487239 s, concurrent 4.227007 s, 400 checkout attempts in 2.05 s, 50 wins, 350 refusals, no overselling/errors, 19 overlap samples and restored counts. E050 misses remain valid. Different setup and uncontrolled cache/load preclude causal speedup claims. Retain A provisionally; defer B/C under mandatory-first decision. Consistent and projected-volume compliance unverified; revisit repeatable misses or growth. No physical one-pass claim. Final fresh-load acceptance pending. See integrated_workload_performance.md. Learner review required.
