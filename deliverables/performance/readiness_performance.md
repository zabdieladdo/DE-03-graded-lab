# Publication readiness performance report

## Target
Measure incremental verification and end-to-end delivery costs without changing report contents. Original provisional SQL-only target 5 s remains separate. No agreed export/full-publication target; The accepted architecture decision (D037) retains current architecture provisionally.

## Method
Windows/WSL2 Docker PostgreSQL 18.7 lab; previously recorded host 32 GB RAM, 8 logical processors, current allocation not captured. August 31 cutoff, 40,420 customers, 525,563 report rows. Three alternating pairs A/B, B/A, A/B, separate Python processes; no explicit warmup/cache reset. Wall time includes child process startup and exit; report time includes queries, fetch and CSV writing. Full path includes independent references, evaluation and packaging. Peak RSS is Python process only, not database or whole machine. Set `DATABASE_URL` privately for `kloudkart_lab` and run:

**RUN IN TERMINAL**

```bash
set -o pipefail
python -u scripts/benchmark_readiness.py --pairs 3 2>&1 | tee generated/62_readiness_performance_rerun.txt
echo $?
unset DATABASE_URL
```
Evidence `evidence/05_publication_improvement.txt (original: 62_readiness_performance.txt; lines 245-260)`.

## Results
| Scenario | Runs | Median | Worst | Target met? |
|---|---:|---:|---:|---|
| Export only wall | 3 | 9.419 s | 10.224 s | No agreed target |
| Verified publication wall | 3 | 13.933 s | 14.046 s | No agreed target |
| Paired wall overhead | 3 | 3.902 s | 4.627 s | No agreed target |
| Export peak RSS | 3 | 962.930 MiB | 962.984 MiB | No agreed target |
| Full peak RSS | 3 | 961.867 MiB | 962.023 MiB | No agreed target |

| Pair | Export wall s | Full wall s | Delta s |
|---|---:|---:|---:|
| 1 | 10.224089 | 13.932681 | 3.708593 |
| 2 | 9.139927 | 13.042320 | 3.902393 |
| 3 | 9.419334 | 14.046193 | 4.626860 |

All six CSV hashes identical across all six runs, 28,799,469 CSV bytes per export; full packages verified, temporary exports removed, exit 0. Full run IDs c5cab9cb-1d0a-4d70-ac18-4f98c95e565a, de3697ac-a159-498a-8c5f-0d1ced776bb2, 924bc33c-5f7a-4a0b-bc35-ccdfdfd47f1e.

## Before / after
| Query / stage | Before | After | Change |
|---|---:|---:|---:|
| Export vs verified wall median | 9.419334 s | 13.932681 s | +4.513347 s (+47.92%) |
| Report phase median | 9.036412 s | 9.375933 s | +0.339521 s |
| Peak RSS median | 962.930 MiB | 961.867 MiB | -1.063 MiB (not causal) |

Full reference median 3.009490 s, evaluation median 1.209445 s, combined median 4.219 s. Paired wall delta median differs from difference of medians. E058 SQL discard workload 3.487 s solo/4.227 s concurrent is not directly comparable; E050 four misses remain valid. Original reported 40-minute query unavailable.

## November publication retry (26 November cutoff)

| Phase | Internal elapsed time |
|---|---:|
| Report query, fetch and CSV writing | 16.245 s |
| Independent reference | 4.000 s |
| Evaluation | 1.575 s |
| Total recorded internal elapsed | 21.886 s |

Run `5f8b6b6e-aa70-4469-80bb-1a247af2f91c`: WARN / REVIEW AND DISCLOSE, exit 0. All six output row counts matched expectations; R01–R04 had zero differences. All seven output checksums and package metadata independently verified. Evidence: `evidence/05_publication_improvement.txt (original: 60c_02_readiness_november.txt; lines 90-110)` and `evidence/05_publication_improvement.txt (original: 60c_03_november_package_integrity.txt; lines 127-135)`. This was the first of two recent observations above the proposed 20 s review trigger. Internal elapsed excludes final manifest writing and is not directly comparable to the August child-process wall time. No November RSS measurement was supplied.

## R12 live verification (E065b–E065d)

| Cutoff | Report | Reference | Evaluation | Internal elapsed | Status |
|---|---:|---:|---:|---:|---|
| 2026-08-31 | 14.596 s | 4.794 s | 2.347 s | 21.821 s | WARN |
| 2025-08-01 | 11.482 s | 2.117 s | 1.172 s | 14.823 s | PASS |

Both packages passed seven output checksum checks and metadata verification. The August run exceeded 20 s, as did the earlier November retry before R12. Stage 08 observations are below; the different workloads and uncontrolled conditions do not isolate R12 overhead. No RSS measurement was supplied for these runs.

## Caveats
No cache control, server memory, growth or concurrent checkout test for full package. Peak RSS roughly 35 times CSV size; not an allocation attribution. Same CSV hashes establish repeatability, not real-world financial accuracy. Retain A; see ADR-007 review triggers. Candidate fresh-load functional acceptance passed (E077c); final merged revision verification remains pending.

See [evidence and decision index](../EVIDENCE_INDEX.md) for checkpoint identifiers.

## Stage 08 acceptance publication (E076 and E077c)

| Cutoff | Manual internal elapsed (s) | Automated internal elapsed (s) | Readiness |
|---|---:|---:|---|
| 2026-08-31 | 16.768 | 20.236 | WARN |
| 2026-11-26 | 17.191 | 22.131 | WARN |
| 2025-08-01 | 12.086 | 18.648 | PASS |

All three automated packages passed seven output hashes and six CSV row counts each. Both latest nonempty runs exceeded the proposed 20 s review trigger; retain D037 provisionally, with latency investigation still warranted. No RSS measurement or controlled causal comparison for these runs. WARN reflects financial screening, not runtime. Final merged revision verification remains pending.
