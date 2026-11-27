# Customer reporting performance report

## Target

Client: customer spending reports in seconds on an ordinary laptop.

Provisional engineering target: complete core workload <= 5 seconds; not client-confirmed.

Final acceptance pending. No additional infrastructure.

## Method

Windows/WSL2, Docker PostgreSQL 18.7, host 32 GB RAM and 8 logical processors (previously reported); E050 database settings: work_mem 4 MiB, shared_buffers 128 MiB, effective_cache_size 4 GiB, JIT on, max_parallel_workers_per_gather 2, 8 KiB blocks, track_io_timing off. Actual CPU load and container resource limits were not independently captured for E050.

Baseline 159,384 orders, 40,420 customers. Headline cutoff 2026-08-31; sensitivity 2026-11-26. E048/E049 use EXPLAIN ANALYZE BUFFERS for equivalent top-100 outputs, three repetitions per configuration. E050 uses one read-only repeatable-read transaction, six correctness gates before timing, then three headline runs and one sensitivity run. Each workload includes six sorted where applicable CSV outputs to local psql discarded to /dev/null; clock_timestamp measures combined elapsed time. Excludes correctness verification, connection startup, persistent file writing, remote delivery and spreadsheet rendering. Repeated/warmed execution, not controlled cold cache.

Reproduce from graded-lab after deploying reporting definitions:

```bash
set -o pipefail
docker exec -i "${KLOUDKART_CONTAINER:?Select the disposable test container}" psql -X -U postgres -d kloudkart_lab -v ON_ERROR_STOP=1 -f /workspace/graded-lab/sql/04_reporting/20_monday_report_integration.sql 2>&1 | sed -u 's/[[:blank:]]*$//' | tee generated/50_monday_report_integration_rerun.txt
```

Preserve original evidence before rerunning; use a new filename for a new run.

E048 and E049 use scripts `sql/04_reporting/18_customer_ranking_baseline.sql` and `sql/04_reporting/19_customer_ranking_jit_sensitivity.sql` respectively with the same psql invocation.

## Results

| Scenario | Runs | Median ms | Worst ms | Target met? |
|---|---:|---:|---:|---|
| E048 direct ranking | 3 | 484.836 | 500.371 | Individual query; no separate target |
| E048 sparse ranking | 3 | 930.033 | 982.288 | Alternative |
| E049 direct JIT on | 3 | 593.868 | 854.036 | Individual query |
| E049 sparse JIT on | 3 | 1742.890 | 1743.836 | Alternative |
| E049 direct JIT off | 3 | 546.396 | 584.284 | Individual query |
| E049 sparse JIT off | 3 | 1110.108 | 1409.747 | Alternative |
| E050 headline core workload | 3 | 5371.877 | 5929.448 | No, provisional 5 s |
| E050 sensitivity core workload | 1 | 5727.490 | 5727.490 | No, provisional 5 s |

E050 headline runs 5371.877, 5929.448, 5276.166 ms. Six correctness assertions passed; four workloads completed, rollback and exit 0. Core expected output 525,563 data rows across six interfaces (not counted from discarded CSV). Component medians: summary 404.475, monthly/running 2633.804, top100 867.696, ranking metadata 959.293, financial reconciliation 477.070, period metadata 0.423 ms. Median combined ranking+metadata 1912.950 ms. Component medians need not sum to workload median.

## Before / after

| Query / stage | Before (alternative) | After (retained implementation) | Change |
|---|---:|---:|---|
| E048 equivalent ranking | Sparse + opening 930.033 ms | Direct 484.836 ms | 47.87% lower median, 1.92x ratio |
| E049 equivalent ranking, JIT on | Sparse 1742.890 ms | Direct 593.868 ms | 65.93% lower median |
| E049 equivalent ranking, JIT off | Sparse 1110.108 ms | Direct 546.396 ms | 50.78% lower median |

These are measured alternative-versus-retained comparisons, not chronological production deployment improvements. E048 four equivalence gates passed for both dates and bases across 14 fields. E049 gate completion inferred from fail-fast exit 0; result rows omitted in submitted excerpt. E048 shared hits 222,767 vs 1,797; median temp blocks read/written 3,402/3,980 vs 2,594/2,947. Buffer accesses are not physical disk reads. Visible JIT and function boundaries confound causal attribution.

Other baselines: E034 summary 209.979/270.880 ms; E039 sparse 333.709 ms, dense 677.892/634.192 ms, wide 980.055 ms; E044 dense reference median 724.309 ms, monthly running 1292.742 ms, transaction running 374.235 ms. These outputs differ in functionality; do not label them equivalent speedups. E044 single-customer monthly filter discarded 485,028 rows. E048 single-customer totals discarded 40,419 rows. These are potential improvement candidates, not implemented fixes.

## Caveats

The original client-reported forty-minute query is unavailable; no measured speedup against it. E050 misses the provisional budget by 7.44% at median and 18.59% at worst. No controlled growth proof. Candidate fresh-load functional acceptance passed (E077c); final merged revision verification remains pending. Later concurrent checkout and actual delivery measurements are in the integrated workload and readiness performance reports; their different timing boundaries must be respected.

See [evidence and decision index](../EVIDENCE_INDEX.md) for checkpoint identifiers.
