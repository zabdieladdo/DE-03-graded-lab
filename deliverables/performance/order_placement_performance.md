# Order Placement Performance Report

**Project:** Kloud Kart — DE-03 Graded Lab  
**Date:** 2026-11-26  
**Status:** Functional correctness, tested failure atomicity, official concurrency scenarios, initial flash-sale performance benchmark, independent concurrent purchase audit reconciliation and final fixture cleanup verified.

## Target

Process approximately 400 competing purchase attempts within ten seconds while maintaining transaction consistency, preventing overselling and returning clear refusals without unhandled contention errors.

The solution must also ensure that successful purchases create corresponding order, order item and inventory movement records.

The ten-second benchmark is derived from the client's reported flash-sale workload. The supplied race-test harness treats execution beyond ten seconds as a performance concern rather than an automatic correctness failure.

## Method

### Implementation under test

The `place_order()` function implements an atomic conditional stock update under Read Committed transaction isolation.

Stock deduction, order creation, order item creation and inventory movement recording are performed within the same transaction.

The stock deduction succeeds only when sufficient inventory is available. Expected business refusals return a clear message without creating purchase records.

### Environment

| Component | Configuration |
|---|---|
| Database | kloudkart_lab |
| Database engine | PostgreSQL 18.7 |
| Execution environment | Docker on WSL2 |
| Logical processors | 8 |
| Total WSL memory | Approximately 15 GiB |
| Available memory before testing | Approximately 12 GiB |
| Swap capacity | 4 GiB |
| Swap usage before testing | 0 B |
| Container memory limit | 15.49 GiB |
| Container memory usage before testing | 89.45 MiB |
| Container memory utilization | 0.56% |
| PostgreSQL maximum connections | 500 |
| Observed pg_stat_activity entries before testing | 9 |
| Python version | 3.14.4 |
| psycopg2 version | 2.9.13 |
| User process limit | 63,400 |
| Open file descriptor limit | 1,048,576 |
| Transaction isolation | Read Committed |

Environment measurements were captured on 26 November 2026 at 09:13:22 UTC.

### Test procedure

The supplied `race_test.py` harness was executed with verbose output against the isolated graded database.

Before execution, a safety preflight confirmed:

- The correct database and required purchase function were available.
- No previous race-test fixtures remained.
- The 28 planned fixture product identifiers did not overlap with historical inventory or order item references.
- PostgreSQL was configured with a maximum of 500 connections.

The flash-sale scenario used 400 competing buyers and 50 available units. Buyers were synchronized using a barrier to generate a concentrated burst of purchase requests.

Individual call latency was measured from immediately before query execution until the returned row was fetched. The flash-sale wall-clock measurement also included connection and thread overhead.

One complete harness execution was measured. Individual latency statistics were calculated from the 400 recorded flash-sale attempts using a reproducible Python analysis script.

The median uses the standard statistical median. The 95th percentile uses the nearest-rank method.

No additional database infrastructure or resource increases were introduced for this benchmark.

### Test harness identification

Recorded SHA-256 checksum:

`5f12a6697400dee3876dfa33a03fbdcc1dc906f665f3c0a6aaeffe73cdb27d00`

The checksum identifies the tested file. Comparison against the original distribution checksum remains to be confirmed.

## Results

### Functional correctness and failure atomicity

| Test suite | Checks passed | Result |
|---|---:|---|
| Purchase functional tests | 11/11 | PASS |
| Failure atomicity assertions | 10/10 | PASS |
| Official concurrency scenarios | 4/4 | PASS |
| Last-unit race rounds | 25/25 | PASS |
| Post-race baseline reconciliation | 6/6 | PASS |
| Reproducible performance analysis | Completed | PASS |

The functional tests verified successful purchases, insufficient-stock refusals, invalid quantities, nonexistent identifiers and NULL inputs.

The failure atomicity test deliberately rejected the final inventory write after stock deduction, order creation and order item creation had occurred.

The resulting exception restored stock from three units to five units and removed the partial purchase records. A subsequent recovery purchase succeeded.

### Official concurrency results

| Scenario | Attempts | Successful | Refused | Errors | Result |
|---|---:|---:|---:|---:|---|
| Last-unit races | 50 | 25 | 25 | 0 | PASS |
| Flash sale | 400 | 50 | 350 | 0 | PASS |
| Excessive quantity | 1 | 0 | 1 | 0 | PASS |
| Audit trail | 12 | 5 | 7 | 0 | PASS |
| **Total** | **463** | **80** | **383** | **0** | **PASS** |

All four official scenarios passed, and the harness returned exit code 0.

Every last-unit race produced exactly one successful purchase. The flash-sale scenario sold exactly 50 available units, refused the remaining 350 requests and finished with zero remaining stock.

The excessive-quantity request was refused without changing the available stock.

The audit-trail scenario recorded five inventory movements for five successful purchases. Detailed independent reconciliation of these concurrent movement records remains pending.

### Flash-sale latency

All latency measurements are expressed in milliseconds.

| Outcome | Calls | Minimum | Median | P95 | Worst |
|---|---:|---:|---:|---:|---:|
| All attempts | 400 | 133.20 | 730.90 | 1055.00 | 1088.90 |
| Successful | 50 | 133.20 | 338.15 | 432.60 | 444.00 |
| Refused | 350 | 440.90 | 786.10 | 1057.70 | 1088.90 |

The reproducible analysis independently verified:

- Exactly 400 distinct flash-sale attempts.
- Exactly 50 successful purchases.
- Exactly 350 refused purchases.
- Fifty unique successful order identifiers.
- NULL order identifiers for refused purchases.
- Insufficient-stock messages for refused purchases.
- Zero recorded purchase errors.

The analysis script returned exit code 0.

### Flash-sale throughput

| Measurement | Actual |
|---|---:|
| Wall-clock execution time | 1.89 seconds |
| Average attempt throughput | 211.64 attempts/second |
| Successful purchase throughput | 26.46 purchases/second |
| Refusal throughput | 185.19 refusals/second |
| Successful purchase proportion | 12.50% |
| Refused purchase proportion | 87.50% |
| Unhandled error proportion | 0.00% |

Throughput values are calculated using the reported wall-clock time of 1.89 seconds and are therefore approximate.

### Benchmark comparison

| Measure | Target | Measured | Target met? |
|---|---:|---:|---|
| Purchase attempts | 400 | 400 | Yes |
| Flash-sale wall-clock time | ≤10 seconds | 1.89 seconds | Yes |
| Average attempt throughput | ≥40/s | 211.64/s | Yes |
| Successful purchases | 50 | 50 | Yes |
| Clean refusals | 350 | 350 | Yes |
| Remaining fixture stock | 0 | 0 | Yes |
| Oversold units | 0 | 0 | Yes |
| Unhandled purchase errors | 0 | 0 | Yes |

The measured wall-clock time was 8.11 seconds, or 81.10%, below the ten-second benchmark.

The measured attempt throughput was approximately 5.29 times the reference rate of 40 attempts per second.

These figures represent performance against the workload benchmark, not a measured speedup over the previous implementation.

### Refusal latency analysis

The median refusal latency was 786.10 ms, compared with 338.15 ms for successful purchases.

Refused purchases therefore experienced approximately 2.32 times the median latency of successful purchases, a difference of 447.95 ms.

Although a conditional update can avoid taking an unnecessary product-row lock when the stock condition is already false, simultaneous requests may still wait for competing transactions before PostgreSQL re-evaluates the condition.

Connection scheduling, database execution and contention may also contribute to the measured latency.

The current measurements do not isolate these individual causes.

The results demonstrate that conditional updates do not guarantee faster responses for refused purchases.

## Post-test data reconciliation

Independent cleanup verification confirmed that all race-test fixture products, associated order items, inventory movements and 80 generated orders were removed.

| Table | Baseline rows | Post-test rows | Difference | Result |
|---|---:|---:|---:|---|
| Categories | 94 | 94 | 0 | PASS |
| Customers | 40,420 | 40,420 | 0 | PASS |
| Inventory log | 282,352 | 282,352 | 0 | PASS |
| Order items | 336,559 | 336,559 | 0 | PASS |
| Orders | 159,384 | 159,384 | 0 | PASS |
| Products | 4,023 | 4,023 | 0 | PASS |
| **Total** | **822,832** | **822,832** | **0** | **PASS** |

Additional verification established:

- All 28 planned race fixture product identifiers were absent.
- All 80 generated race orders were absent.
- No associated fixture order items remained.
- No associated fixture inventory movements remained.
- All 14 historical negative-stock products remained.
- The last allocated order identifier was 659469.
- The cleanup verification script returned exit code 0.

The order identifier sequence was intentionally not reset. Sequence values consumed by successful, rolled-back or subsequently deleted purchases are not reclaimed.

Preserving the historical negative-stock anomalies is consistent with ADR-001, which requires retaining unresolved historical data while preventing new integrity violations.

Matching row counts and targeted fixture checks establish baseline reconciliation but do not independently prove that every historical field remained unchanged.
### Supplementary concurrent inventory audit verification

**Date:** 2026-11-26

Following the successful official concurrency benchmark, Test 4 was executed independently with verbose output and retained fixtures to permit detailed database-level reconciliation.

The supplementary test used 12 competing buyers, five available units and a unit price of 100.00.

| Measurement | Expected | Actual | Result |
|---|---:|---:|---|
| Purchase attempts | 12 | 12 | PASS |
| Successful purchases | 5 | 5 | PASS |
| Clean refusals | 7 | 7 | PASS |
| Unhandled errors | 0 | 0 | PASS |
| Initial stock | 5 | 5 | PASS |
| Remaining stock | 0 | 0 | PASS |
| Distinct orders | 5 | 5 | PASS |
| Order items | 5 | 5 | PASS |
| Units sold | 5 | 5 | PASS |
| Inventory movements | 5 | 5 | PASS |
| Net inventory movement | -5 | -5 | PASS |
| Recorded order value | 500.00 | 500.00 | PASS |
| Calculated item value | 500.00 | 500.00 | PASS |
| Financial difference | 0.00 | 0.00 | PASS |

All 12 independent audit assertions passed.

#### Individual transaction reconciliation

| Order ID | Order item ID | Inventory log ID | Quantity | Movement |
|---:|---:|---:|---:|---:|
| 659470 | 1236645 | 982573 | 1 | -1 |
| 659471 | 1236646 | 982574 | 1 | -1 |
| 659472 | 1236647 | 982575 | 1 | -1 |
| 659473 | 1236648 | 982576 | 1 | -1 |
| 659474 | 1236649 | 982577 | 1 | -1 |

Each successful purchase had exactly one matching inventory movement, with the correct quantity, sale reason and order reference.

All five orders had the expected customer, completed status and recorded value of 100.00.

#### Supplementary audit-race latency

All latency measurements are expressed in milliseconds.

| Outcome | Calls | Minimum | Median | P95 | Worst |
|---|---:|---:|---:|---:|---:|
| All attempts | 12 | 14.90 | 34.35 | 46.50 | 46.50 |
| Successful | 5 | 14.90 | 22.90 | 31.20 | 31.20 |
| Refused | 7 | 33.20 | 40.40 | 46.50 | 46.50 |

The p95 uses the nearest-rank method. These small samples provide descriptive measurements rather than reliable estimates of long-term tail latency.

The median refusal latency was approximately 1.76 times the successful purchase median.

These results are consistent with the earlier observation that conditional updates do not guarantee lower refusal latency during contention.

The supplementary test is not an equivalent repetition of the 400-buyer flash-sale benchmark.

#### Cumulative concurrency testing

| Execution | Attempts | Successful | Refused | Errors |
|---|---:|---:|---:|---:|
| Original official harness | 463 | 80 | 383 | 0 |
| Supplementary retained audit race | 12 | 5 | 7 | 0 |
| Total | 475 | 85 | 390 | 0 |

The original flash-sale performance results remain unchanged.

#### Evidence

- `evidence/25_audit_race_retained.txt`
- `evidence/26_inventory_audit_reconciliation.txt`
- `tests/06_inventory_audit_reconciliation.sql`

Both the supplementary race test and the independent reconciliation script returned exit code 0.

#### Conclusion

The supplementary test verifies individual purchase auditability under the tested concurrent workload, including stock reconciliation, financial consistency and one-to-one correspondence between successful purchases and inventory movements.

General auditability of restocks, corrections and direct inventory modifications remains outside the scope of this purchase-specific test.

Final cleanup of the retained supplementary fixtures remains pending verification.
## Before and after

A previous isolated learning exercise reproduced an unsafe last-unit purchase race under Read Committed isolation. Two competing purchases succeeded against one available unit.

The implemented conditional-update strategy subsequently passed all 25 last-unit race rounds and the 400-buyer flash-sale scenario in the graded environment.

| Measure | Before implementation | After implementation |
|---|---|---|
| Last-unit purchase safety | Unsafe behaviour reproduced in an isolated learning exercise | 25/25 official race rounds passed |
| Flash-sale correctness | No equivalent baseline benchmark | 50 successful purchases, 350 refusals, zero errors |
| Flash-sale execution time | Not measured | 1.89 seconds |
| Unexpected failure atomicity | No equivalent implementation benchmark | 10/10 assertions passed |
| Purchase audit consistency | Historical inconsistencies identified | Functional audit checks passed; detailed concurrent audit reconciliation pending |

No equivalent performance benchmark was recorded for the unsafe implementation or the alternative explicit-locking strategy.

Consequently, a comparative execution-time improvement or superiority over alternative locking strategies cannot be claimed.

## Reproduction

The benchmark can be reproduced using the original supplied race-test harness and the following procedure:

1. Load the original graded dataset and apply the documented schema migrations.
2. Deploy the `place_order()` function.
3. Activate the project Python virtual environment.
4. Verify the database configuration and fixture safety.
5. Configure `DATABASE_URL` securely for the isolated graded database.
6. Execute the original harness with verbose output.
7. Run the independent cleanup verification.
8. Analyze the saved execution log.

### Execute the harness

```bash
set -o pipefail

python -u ../shared-data/race_test.py --verbose \
    2>&1 | tee evidence/22_race_test_verbose.txt

race_exit=$?

printf '\nRace test exit code: %s\n' "$race_exit" \
    | tee -a evidence/22_race_test_verbose.txt

unset DATABASE_URL
```

### Reproduce the performance analysis

```bash
set -o pipefail

python scripts/analyze_race_results.py \
    evidence/22_race_test_verbose.txt \
    2>&1 | tee evidence/24_race_performance_analysis.txt

echo $?
```

The cleanup verification script `tests/05_race_cleanup_verification.sql` contains fixture identifiers specific to the recorded execution. Future executions must use their corresponding fixture and generated order identifiers.

## Evidence

| Evidence file | Purpose |
|---|---|
| `evidence/17_place_order_deployment.txt` | Purchase function deployment |
| `evidence/18_place_order_verification.txt` | Function signature and database configuration |
| `evidence/19_place_order_functional_test.txt` | Eleven functional purchase tests |
| `evidence/20_place_order_atomicity_test.txt` | Ten failure atomicity assertions |
| `evidence/21_race_preflight.txt` | Fixture collision and database safety checks |
| `evidence/21a_race_environment.txt` | Hardware and execution environment measurements |
| `evidence/22_race_test_verbose.txt` | Official concurrency results and individual latency measurements |
| `evidence/23_race_cleanup.txt` | Independent fixture cleanup and baseline reconciliation |
| `evidence/24_race_performance_analysis.txt` | Reproducible latency and throughput calculations |

## Caveats

- Results represent one complete official harness execution.
- Repeatability across multiple independent runs has not yet been measured.
- Cold-cache and warm-cache performance were not separately evaluated.
- Production hardware, network conditions and competing workloads may produce different results.
- The test uses a synchronized burst rather than evenly distributed arrivals.
- Peak resource consumption and individual lock-wait durations were not measured.
- The conditional-update strategy was not benchmarked against explicit row locking or Serializable isolation.
- The official audit scenario checks movement counts but does not fully reconcile movement quantities and individual order references.
- Detailed independent concurrent inventory audit reconciliation remains pending.
- Application-level response times outside the test harness were not measured.
- The failure-injection test covers an unexpected SQL error during inventory insertion, not every possible failure or crash-recovery scenario.
- The solution does not independently prevent every direct database write that bypasses the purchase function.
- The recorded test harness checksum has not yet been confirmed against the original distribution checksum.
- Baseline row-count reconciliation does not establish complete field-level historical equivalence.

## Conclusion

The atomic conditional-update implementation satisfies the tested transaction correctness and initial flash-sale performance requirements.

The solution processed 400 competing purchase attempts in 1.89 seconds, sold exactly the available 50 units, returned 350 clean refusals and produced zero unhandled purchase errors.

Sequential functional correctness, rollback after an injected inventory failure and post-test baseline reconciliation have also been verified.

The evidence supports retaining the selected concurrency strategy without increasing the current infrastructure allocation.

Further work is required to complete detailed concurrent inventory audit reconciliation and establish performance repeatability across multiple executions.


### Final supplementary fixture cleanup

Following the successful independent concurrent purchase audit, the retained fixture records were removed using a targeted transactional cleanup script.

The script verified the expected fixture identifiers, record values and table counts before performing any deletion.

Table locks prevented competing modifications during cleanup. All baseline and fixture-removal assertions were required to pass before the transaction committed.

| Table | Before cleanup | Removed | Final count |
|---|---:|---:|---:|
| Categories | 94 | 0 | 94 |
| Customers | 40,420 | 0 | 40,420 |
| Products | 4,024 | 1 | 4,023 |
| Orders | 159,389 | 5 | 159,384 |
| Order items | 336,564 | 5 | 336,559 |
| Inventory log | 282,357 | 5 | 282,352 |
| **Total** | **822,848** | **16** | **822,832** |

All cleanup assertions passed, the transaction committed successfully and the script returned exit code 0.

The 14 historical negative-stock products were preserved in accordance with ADR-001.

#### Cleanup measurements

| Operation | Duration |
|---|---:|
| Retained fixture verification | 56.636 ms |
| Fixture deletion | 87.513 ms |
| Pre-commit baseline verification | 49.291 ms |
| Commit | 2.794 ms |
| Post-commit baseline reconciliation | 16.190 ms |
| Sum of all reported statement durations | 214.958 ms |

The summed statement duration is not an independently measured end-to-end wall-clock time.

#### Final sequence state

| Sequence | Last allocated value | is_called |
|---|---:|---|
| Orders | 659474 | true |
| Order items | 1236649 | true |
| Inventory log | 982577 | true |

The identifier sequences were not reset.

The final baseline reconciliation confirmed that all six historical table counts were restored and all supplementary fixture records were absent.

This establishes successful targeted cleanup and row-count reconciliation, not complete field-level historical equivalence.

**Evidence:**

- `tests/07_retained_audit_cleanup.sql`
- `evidence/27_retained_audit_cleanup.txt`

**Result:** PASS — final supplementary fixture cleanup committed successfully.