# ADR-005: Use live recursive category rollups with explicit exceptions

- **Status:** Accepted (subject to learner review)
- **Date:** 2026-11-27
- **Decision owner:** Lab author (confirm before submission)

## Context
Nana needs low-stock counts across nested categories in a couple of seconds. The baseline has 94 categories, of which 91 reach roots; two form a cycle and one has a missing parent. Products outside the rooted tree must remain visible.

## Decision
Use root-first recursive CTEs with ancestor paths and a visited-node guard, aggregate products by direct category and roll counts up to each ancestor. Use a configurable positive integer threshold (default 10, strictly below), count negative and zero stock separately, keep unknown stock separate and expose unrooted and uncategorised products as exceptions (D018, D033).

## Alternatives considered
### Alternative A: Fixed-depth joins
- **How it would work:** Join parent categories a predetermined number of times.
- **Why it is attractive:** Simple for a known small tree.
- **Why rejected:** New levels silently escape coverage; the brief forbids hardcoded depth.

### Alternative B: Persistent ancestor mapping or materialized rollup
- **How it would work:** Store ancestry or aggregate results and maintain them when source data changes.
- **Why it is attractive:** Potentially faster repeated reads at large scale.
- **Why rejected:** Adds maintenance and freshness risk without measured need; E053 ran in 1.461 ms.

## Consequences
- **What this buys:** Live counts at every rooted category, including directly assigned products; separate exception visibility and no fixed depth.
- **What this costs:** Recursive path processing and aggregation at read time; exception categories need human resolution.
- **What it costs the client if I am wrong:** A misleading threshold or omitted exception can misdirect replenishment; summing every level double-counts products. Ten units is a provisional business assumption, not a demand forecast.
- **What would make me revisit this:** Agreed product-specific thresholds, multiple-parent hierarchy, much larger tree or measured latency/freshness failure.

## What this survives
E052 deployment committed. E053 11 PASS, exit 0; independent ancestor counts at thresholds 1, 10, 20; reconciliation 591=584+7, 1949=1931+18, 2225=2203+22. Nine-level synthetic tree, direct parent assignment, boundary, cycle exclusion and rollback passed. At threshold 10, 15 uncategorised and three unrooted low-stock products are visible outside root totals. One EXPLAIN ANALYZE execution returned 91 rows in 1.461 ms; not a production percentile. No extra optimization justified now.
