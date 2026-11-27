# Inventory and audit performance report

## Target
Recursive low-stock rollup in a couple of seconds (provisional 2 s). Flash sale: 400 buyers competing for 50 units, no oversell or unexpected errors, within 10 s workload window.

## Method
Existing Windows/WSL2 Docker PostgreSQL lab (32 GB host RAM, 8 logical processors; resource settings not remeasured for these runs). E053 EXPLAIN ANALYZE on deployed rollup after correctness tests; one execution, not end-to-end delivery. E057 original race harness --verbose against kloudkart_lab; harness wall clock for flash sale and per-attempt displayed times. One run per architecture, uncontrolled warm/cold state. Reproduce the rollup using `tests/13_low_stock_rollup_test.sql`. With `DATABASE_URL` set privately, run the supplied race harness:

```bash
set -o pipefail
python -u ../shared-data/race_test.py --verbose 2>&1 | tee generated/57_race_test_audit_regression_rerun.txt
echo $?
unset DATABASE_URL
```

## Results
| Scenario | Runs | Observed time | Target met? |
|---|---:|---:|---|
| Rollup E053 | 1 | 1.461 ms | Yes, observed |
| Flash-sale wall E057 | 1 | 2.10 s | Yes, observed |

| Attempt population | Calls | Median | p95 | Worst |
|---|---:|---:|---:|---:|
| All | 400 | 870.45 ms | 1215.2 ms | 1260.3 ms |

Attempt p95 uses nearest rank on rounded verbose timings. Successful attempts (50): median 388.3 ms, p95 520.4 ms, worst 527.6 ms. Refusals (350): median 920.2 ms, p95 1219.4 ms, worst 1260.3 ms.

## Before / after
| Query / stage | Before | After | Change |
|---|---:|---:|---:|
| Flash-sale wall clock E022 vs E057 | 1.89 s | 2.10 s | +0.21 s (+11.11%) |
| Flash-sale attempt median | 730.90 ms | 870.45 ms | +139.55 ms |

## Caveats
Single workload runs do not isolate trigger overhead or establish production percentiles. No original inventory rollup timing available. E057 passed all four scenarios; cleanup subsequently confirmed. Concurrent reporting was subsequently tested (see integrated workload report); candidate fresh-load functional acceptance passed (E077c); final merged revision verification remains pending. Evidence: 53_low_stock_rollup_test.txt, 57_race_test_audit_regression.txt and earlier 22_race_test_verbose.txt.

See [evidence and decision index](../EVIDENCE_INDEX.md) for checkpoint identifiers.
