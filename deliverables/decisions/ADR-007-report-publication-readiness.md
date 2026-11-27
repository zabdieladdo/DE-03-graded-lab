# ADR-007: Verify the Monday publication independently and retain the current export architecture

- **Status:** Accepted
- **Date:** 2026-11-27
- **Decision owner:** Zabdiel

## Context
A fast report can still be wrong. The extract contains missing customer relationships and conflicting item and checkout amounts. The report uses completed-status recorded checkout totals, not independently verified revenue. Adwoa needs a visible release decision without a new server. Independent reference totals, six report-output comparisons, 33 synthetic tests (including the successful regression) and paired delivery measurements support this decision.

## Decision
Generate six CSVs and independently compare their typed source rows against raw-table calculations in one read-only repeatable-read transaction. Record the readiness decision, caveats, policy and checksums. Retain the current Python fetch-and-write architecture at the tested volume. Do not automatically release any package.

- Use exact internal comparisons (R01–R04).
- Screen attribution, complete valuation discrepancies and incomplete valuations (R05–R07) using proposed strict greater-than 1% count OR 1% monetary limits. Denominators are eligible recorded history through cutoff; respective monetary numerators are unattributed header value, sum of absolute header/item differences, and header value associated with incomplete valuations.
- Absolute limits disabled until currency and business materiality are confirmed. Policy 1.0-proposed, review 2027-02-25.
- Exceptions remain visible below thresholds. R09–R11 and D01 distinguish information and standing limitations from severity. Zero recorded spending does not establish absence of activity.
- ERROR > FAIL > WARN > PASS; missing required entries or disclosure hold publication. PASS means internal checks satisfied, not financial certification. WARN requires review and disclosure; FAIL/ERROR hold. Any exceptional human release must be documented separately, not relabelled PASS.

## Alternatives considered

### Alternative A: Release the fast report without independent checks
- **How it would work:** Export the existing reporting functions and trust their outputs.
- **Why it is attractive:** Lower latency and implementation effort.
- **Why rejected:** A shared calculation defect or missing customer could go undetected.

### Alternative B: Warn on every historical exception
- **How it would work:** Treat every exception or standing limitation as a warning.
- **Why it is attractive:** Simple conservative rule.
- **Why rejected:** Permanent warnings obscure meaningful changes; disclosures must remain visible even on PASS. Proposed thresholds are screening limits, not permission to ignore exceptions.

### Alternative C: COPY-based export
- **How it would work:** Use database-native export, then validate the actual exported data against the independent reference.
- **Why it is attractive:** Potentially lower serialization overhead.
- **Why rejected:** Not yet benchmarked for this workflow; requires renewed equivalence and packaging tests. Current weekly delivery is acceptable provisionally.

### Alternative D: Streaming validation
- **How it would work:** Compare ordered batches rather than retain all rows.
- **Why it is attractive:** Potentially lower peak memory at growth.
- **Why rejected:** More complex failure handling and comparison logic; no current measured resource failure.

## Consequences
- **What this buys:** Explicit release guidance, independent row comparisons, repeatable output and traceability without additional production infrastructure. August and November WARN results were driven by count shares of 1.4587% and 1.4586%, respectively, despite a monetary share of 0.6108% in both.
- **What this costs:** The paired delivery benchmark measured median paired overhead 3.902 s; full median 13.933 s, worst 14.046 s, peak Python median 961.867 MiB for 28,799,469 CSV bytes. Export-only peak already 962.930 MiB. A separate November generation recorded 21.886 s internal elapsed time; this is one observation above the proposed 20 s review trigger, not a repeated breach or a directly comparable wall-clock measurement. Maintenance of independent definitions, policy and evidence; human review remains necessary.
- **What it costs the client if I am wrong:** Memory pressure or checkout interference as volume grows; late decisions or misleading financial confidence if checks or thresholds are inadequate. No verified monetary loss estimate.
- **What would make me revisit this:** Repeated full runs above 20 s, Python RSS above 1.5 GiB, doubled report volume, observed checkout degradation, faster client delivery requirement, or changed business semantics/currency. Proposed engineering triggers, not SLAs. Review policy by 2027-02-25 or earlier if evidence changes. Rebenchmark COPY first for delivery latency, streaming for memory pressure; preserve independent correctness.

## What this survives
- August and November actual output comparisons (R01–R04): zero differences across 525,563 report rows per cutoff. Both returned WARN / REVIEW AND DISCLOSE.
- November retry succeeded (run `5f8b6b6e-aa70-4469-80bb-1a247af2f91c`); all seven output checksums, exact file coverage, run identity, cutoff and status independently verified. The earlier failed attempt is superseded, not erased.
- All 33 synthetic tests passed again, including fault injection, boundaries and mocked query failure (`evidence/61b_readiness_regression.txt`).
- Three paired August runs yielded identical six CSV hashes and verified packages.

This does not prove live timeout handling, concurrent snapshot behaviour under writes, authenticity, source completeness, production growth, or full publication under checkout contention. Clean-tree fresh-load acceptance is pending. The agreed zero-eligible-orders informational entry (R12) is not implemented as a separate entry; this remains a disclosed design gap. HTML interfaces are separate presentation work.

See [evidence and decision index](../EVIDENCE_INDEX.md) for checkpoint identifiers.
