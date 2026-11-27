# Isolated stock-allocation comparison

## Target and method
Compare conditional `UPDATE` with explicit `SELECT FOR NO KEY UPDATE` followed by `UPDATE` under Read Committed isolation. Three alternating pairs at each workload; each attempt requests one unit. Connections established before a barrier; wall timing starts at release and includes transaction completion. Scratch schemas removed after execution. No orders, payment or audit trigger. No cache control. Local lab, not production.

## Results
| Buyers / stock | Strategy | Runs | Min wall (s) | Median wall (s) | Max wall (s) | Median of first-statement medians (ms) |
|---|---|---:|---:|---:|---:|---:|
| 40 / 5 | Conditional | 3 | 0.1034 | 0.1087 | 0.1206 | 54.832 |
| 40 / 5 | Explicit | 3 | 0.0815 | 0.1040 | 0.1266 | 55.233 |
| 400 / 50 | Conditional | 3 | 0.7670 | 0.8357 | 1.0080 | 448.414 |
| 400 / 50 | Explicit | 3 | 0.7767 | 0.9381 | 1.0087 | 527.155 |

All 12 executions passed: 2,640 attempts, 330 wins, 2,310 refusals, zero remaining stock per trial, no reported errors. Both scratch schemas cleaned up; both exit codes 0. Explicit median wall time was 4.3% lower at 40 buyers; conditional median was 10.9% lower at 400. Neither won every trial. Retain conditional allocation; no universal performance claim. First-statement time includes execution and communication, not pure lock waiting. No full purchase comparison or percentile measurement.

## Reproduce
Set `DATABASE_URL` privately as described in the root README. **Run in terminal:**

```bash
set -o pipefail
python -u scripts/compare_stock_locking.py --buyers 40 --stock 5 --pairs 3 2>&1 | tee generated/64a_locking_comparison_rerun.txt
python -u scripts/compare_stock_locking.py --buyers 400 --stock 50 --pairs 3 2>&1 | tee generated/64b_locking_comparison_rerun.txt
unset DATABASE_URL
```

Stop if either run fails. Successful terminal outputs supplied on 27 November; ensure local `evidence/03_performance_comparison.txt (original: 64a_locking_comparison.txt; lines 2690-2701)` and `evidence/03_performance_comparison.txt (original: 64b_locking_comparison.txt; lines 2708-2719)` contain these successful runs. The uploaded ZIP predates the successful retry and contains the earlier missing-variable error. Preserve it separately.
