## Reporting optimization backlog

Identified during Stage 04 through evidence 34 and 35.

| ID | Optimization candidate | Evidence | Verification required |
|---|---|---|---|
| OPT-01 | Investigate SQL function inlining | Function Scan and temporary blocks | Exact result equivalence and execution-plan comparison |
| OPT-02 | Simplify the eligibility predicate and improve selectivity estimates | Direct view estimates 790 versus 111334 actual rows | Estimated versus actual cardinality |
| OPT-03 | Investigate set-based financial reconciliation | 111334 customer index searches | Buffer-access and execution-time comparison |
| OPT-04 | Investigate aggregation memory requirements | Five hash batches and 3368 kB disk usage | Controlled session-level memory comparison |
| OPT-05 | Evaluate targeted reporting indexes | Existing reporting indexes are primary keys only | Read benefit, storage and write overhead |
| OPT-06 | Evaluate dense report generation and consumption | 485040 rows, 80.89% zero-order months | Database execution and full-result transfer |
| OPT-07 | Evaluate ordinary versus materialized reporting objects | Repeated normalization and aggregation | Performance, freshness and refresh cost |

### Optimization acceptance criteria

- Preserve all accepted reporting semantics.
- Preserve exact customer-level and financial results.
- Measure before-and-after execution under comparable conditions.
- Avoid unnecessary persistent resource increases.
- Document storage, write, freshness and maintenance trade-offs.
- Do not introduce additional infrastructure.

No optimization candidate is accepted solely because it appears faster in one preliminary execution.


## Additional optimization findings — Evidence 39 and 40

| ID | Candidate | Measured evidence | Priority |
|---|---|---|---|
| OPT-08 | Push customer filtering into reporting logic | 485028 rows discarded to return 12; 737.480 ms | High |
| OPT-09 | Investigate dense function cardinality estimation | 1000 estimated versus 485040 actual rows | High |
| OPT-10 | Reduce nested function materialization and temporary-file activity | Dense: 14259 temporary blocks read and 4975 written | High |
| OPT-11 | Optimize wide export generation | 980.055 ms and 7439 temporary blocks written | Medium |
| OPT-12 | Compare controlled session-level work_mem settings | Current work_mem is 4 MB; substantial temporary block activity | Medium |
| OPT-13 | Test ten-times-growth scalability | Projected 4850400 dense rows; runtime unmeasured | Medium |

### Candidate improvement beyond the brief

Provide an efficient targeted customer-history reporting interface that applies customer selection before aggregation and calendar expansion.

Compare its exact results against the canonical dense report. Measure execution time, rows processed, buffer accesses and temporary block activity.

Do not claim a performance improvement until verified through controlled before-and-after measurements.

# Integrated workload verification

`01_integrated_reporting_workload.sql` exports six report results to a local discard sink. It is a benchmark, not a migration. Run through `scripts/verify_integrated_workload.py` with the official race harness available and `DATABASE_URL` configured. See [performance report](../../deliverables/performance/integrated_workload_performance.md).
