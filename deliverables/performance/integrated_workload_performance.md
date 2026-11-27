# Integrated reporting and checkout performance report

## Target
Client: reports in seconds on an ordinary laptop; around 400 flash-sale orders in ten seconds without overselling.

Provisional engineering gates: six-output report <=5 s, checkout <=10 s, 50 wins/350 refusals/zero errors, observed overlap and restored counts. Not client-approved SLAs.

## Method
Windows/WSL2 laptop, previously recorded 32 GB installed RAM and 8 logical CPUs, Docker PostgreSQL 18.7. E058 recorded max_connections 500, repeatable read, JIT on, work_mem 4 MB. Current allocation and background load not captured. 159384 orders, 40420 customers. One solo then one concurrent report at 2026-08-31; cache uncontrolled. Six CSV outputs transferred to psql inside container and discarded. SQL clock timestamps bracket workload, excluding setup, connection, rollback, persistent delivery and rendering. Original race harness --test 2 --verbose launched on active report COPY. pg_stat_activity sampled with 50 ms sleep; active includes waiting sessions. Reproduce from graded-lab with official bundle and deployed routines, securely set DATABASE_URL for kloudkart_lab, run the following commands, then inspect the printed gates.

```bash
set -o pipefail
python -u scripts/verify_integrated_workload.py 2>&1 | tee evidence/58_integrated_workload_rerun.txt
echo $?
unset DATABASE_URL
```
 Script prints performance misses without failing exit status and checks concurrent report gate only; inspect solo separately.

## Results
| Scenario | Runs | Median (s) | Worst (s) | Target met? |
|---|---:|---:|---:|---|
| E050 headline report | 3 | 5.371877 | 5.929448 | No |
| E050 Nov 26 sensitivity | 1 | 5.727490 | 5.727490 | No |
| E058 solo report | 1 | 3.487239 | 3.487239 | Yes, observed |
| E058 concurrent report | 1 | 4.227007 | 4.227007 | Yes, observed |
| E057 checkout alone | 1 | 2.10 | 2.10 | Yes, observed |
| E058 concurrent checkout | 1 | 2.05 | 2.05 | Yes, observed |

E058 50 distinct successful order IDs, 350 refusals, no errors or overselling per official test 2. 19 overlap samples, peak 399 active checkout calls. Before/after counts (94,4023,40420,159384,336559,282352), zero named race fixtures, exit 0. Count reconciliation is not full row equality. E058 only ran test 2 despite generic final banner; E057 passed all four.

## Before / after
| Component | Solo ms | Concurrent ms | Change |
|---|---:|---:|---:|
| Summary | 269.051 | 362.135 | +34.60% |
| Monthly/running | 1660.012 | 2707.513 | +63.10% |
| Top 100 | 806.067 | 502.543 | -37.66% |
| Ranking metadata | 508.782 | 464.768 | -8.65% |
| Reconciliation | 242.067 | 188.837 | -21.99% |
| Period metadata | 0.302 | 0.403 | +33.44% |
| Whole report | 3487.239 | 4227.007 | +21.21% |

| Checkout attempt metric (ms) | E057 solo | E058 concurrent |
|---|---:|---:|
| Median | 870.45 | 759.95 |
| Nearest-rank p95 | 1215.2 | 1111.1 |
| Maximum | 1260.3 | 1149.9 |

E058 all 400 min 162.5 ms; 50 wins median 374.5, p95 472.4, max 482.1; 350 refusals median 817.95, p95 1118.9, max 1149.9. Wall time -2.38% versus E057, not proof reporting improves checkout. Concurrent report headroom 772.993 ms; monthly/running 64.05% of total.

## Caveats
E050 and E058 same six outputs but different session setup: E050 ran integration assertions first in one snapshot; E058 separate sessions without assertions. No controlled causal speedup or consistent five-second guarantee. Historical cutoff excludes synthetic November sales, not a test of current-day inclusion. Sampling does not establish exact overlap duration. No projected-volume or sustained production test. Original 40-minute SQL unavailable; no historical speedup claimed. No agreed checkout degradation percentage. Retain on-demand reporting provisionally. E050 misses remain valid; revisit repeatable misses or growth. Fresh-load acceptance pending.

See [evidence and decision index](../EVIDENCE_INDEX.md) for checkpoint identifiers.
