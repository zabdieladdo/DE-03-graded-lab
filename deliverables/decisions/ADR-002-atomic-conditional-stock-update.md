# ADR-002: Use atomic conditional stock updates for transaction-safe order placement

- **Status:** Accepted
- **Date:** 2026-11-26
- **Decision owner:** Zabdiel

## Context

Kloud Kart has experienced incidents in which competing customers successfully purchased the same last available unit. These incidents resulted in refunds, customer complaints and reduced confidence in inventory availability.

The client also reported flash-sale workloads involving approximately 400 purchase attempts within ten seconds for a single product.

A purchase must perform four related operations consistently:

1. Deduct the purchased quantity from available stock.
2. Create the order.
3. Create the corresponding order item.
4. Record the inventory movement.

Reading stock availability and subsequently updating stock using the previously retrieved value introduces a race condition. Multiple transactions can observe the same available stock before either completes its update.

An isolated learning exercise reproduced this failure under Read Committed isolation: two competing purchases succeeded against one available unit.

The solution must prevent overselling, provide clear insufficient-stock responses, preserve transaction atomicity and operate within the client's existing database infrastructure.

## Decision

I implemented an atomic conditional stock update under Read Committed isolation, using the stock availability condition directly in the UPDATE statement.

I placed stock deduction, order creation, order item creation and inventory movement recording inside the same transactional purchase function so that all required changes succeed together or are reversed when an unexpected failure occurs.

The stock availability condition is:

```sql
UPDATE products
SET stock_quantity = stock_quantity - p_quantity
WHERE product_id = p_product_id
  AND stock_quantity >= p_quantity
RETURNING price;
```

This excerpt illustrates the concurrency mechanism. The complete implementation includes additional input validation and financial safeguards.

Expected business refusals return a false success indicator, a NULL order identifier and an explanatory message.

Unexpected database errors propagate to the caller rather than being concealed as ordinary purchase refusals.

The caller retains control of transaction commitment and rollback.

## Alternatives considered

### Alternative A: Explicit row locking

- **How it would work:** Retrieve the product using SELECT FOR UPDATE, validate the available quantity while holding the row lock, deduct stock and create the related purchase records within the same transaction.

- **Why it is attractive:** The validation and locking sequence is explicit and relatively easy to understand. It can accommodate more complex business rules, detailed refusal classification and future multi-product purchases.

- **Why rejected:** The current single-product purchase workflow does not require a separate locking and stock-validation statement. The conditional update combines these operations directly. An unconditional explicit locking approach may also acquire product-row locks for requests that ultimately fail because stock is unavailable.

This alternative remains technically valid. An explicit FOR NO KEY UPDATE implementation could provide similar compatibility with foreign-key KEY SHARE locks. An isolated comparison against `SELECT FOR NO KEY UPDATE` followed by `UPDATE` passed all 12 trials. At 40 buyers, median wall time was 108.7 ms (conditional) versus 104.0 ms (explicit); at 400 buyers, 835.7 ms versus 938.1 ms. The conditional approach was 10.9% faster at the larger workload median, but did not win every trial. Retain it for simplicity and demonstrated correctness; the experiment does not compare complete purchase transactions. See the [locking comparison](../performance/locking_comparison.md).

### Alternative B: Atomic conditional stock update — selected

- **How it would work:** Update stock only when the available quantity satisfies the requested quantity. Use the returned row to determine whether the purchase can proceed. Perform the remaining purchase operations within the same transaction.

- **Why it is attractive:** Stock validation and deduction are combined in one statement. PostgreSQL re-evaluates the update condition when necessary after competing row modifications. Requests encountering already committed insufficient stock may avoid unnecessary product-row update locks.

- **Why selected:** It directly addresses the single-product overselling problem, works under Read Committed isolation and avoids introducing application-level serialization retry handling for the tested workload.

The measured results support the implementation's correctness and initial performance. They do not establish that it is faster than every alternative.

### Alternative C: Serializable transactions with retries

- **How it would work:** Execute purchases under Serializable isolation and retry transactions when PostgreSQL detects serialization conflicts.

- **Why it is attractive:** Serializable isolation provides stronger protection against complex transaction anomalies and may simplify reasoning about interactions involving multiple rows or tables.

- **Why rejected:** The current stock deduction problem can be addressed using a conditional update under Read Committed isolation. Serializable transactions would introduce additional retry handling, contention-related failures and uncertainty around repeated requests unless the application also implements appropriate idempotency controls.

The supplied race-test caller does not implement a general serialization retry mechanism.

### Alternative D: Rely on constraints and triggers alone

- **How it would work:** Use stock constraints and triggers to reject invalid inventory values or record inventory changes automatically.

- **Why it is attractive:** Database-level controls can protect multiple write paths and provide centralized enforcement of selected integrity rules.

- **Why rejected:** A non-negative stock constraint alone does not prevent every overselling scenario. Two transactions can create separate purchase records while writing the same previously calculated stock value, leaving a non-negative final balance despite selling more units than were available.

Triggers can participate in a safe transactional design, but their existence alone does not establish concurrency safety.

Constraints remain valuable as an additional defensive layer rather than a replacement for the selected transaction strategy.

## Consequences

- **What this buys:**

  The implementation prevents the tested last-unit overselling scenario and returns controlled insufficient-stock responses.

  Related purchase records are created atomically, and successful purchases can be traced to their corresponding inventory movements.

  The solution operates within the existing database infrastructure without introducing additional services or increasing the current resource allocation.

  Measured verification:

  | Verification | Result |
  |---|---|
  | Functional purchase tests | 11/11 passed |
  | Failure atomicity assertions | 10/10 passed |
  | Official concurrency scenarios | 4/4 passed |
  | Last-unit races | 25/25 passed |
  | Original official harness attempts | 463 |
  | Original successful purchases | 80 |
  | Original clean refusals | 383 |
  | Supplementary audit-race attempts | 12 |
  | Supplementary successful purchases | 5 |
  | Supplementary clean refusals | 7 |
  | Combined concurrency attempts | 475 |
  | Combined successful purchases | 85 |
  | Combined clean refusals | 390 |
  | Combined unhandled errors | 0 |
  | Independent purchase audit assertions | 12/12 passed |

  Flash-sale performance:

  | Measurement | Result |
  |---|---:|
  | Purchase attempts | 400 |
  | Available units | 50 |
  | Successful purchases | 50 |
  | Clean refusals | 350 |
  | Remaining stock | 0 |
  | Oversold units | 0 |
  | Wall-clock execution time | 1.89 seconds |
  | Reference benchmark | 10 seconds |
  | Time below benchmark | 81.10% |
  | Average attempt throughput | 211.64/s |
  | Median call latency | 730.90 ms |
  | p95 call latency | 1055.00 ms |
  | Worst call latency | 1088.90 ms |

  The supplementary audit race independently verified five successful orders, five order items and five matching inventory movements. Five units were deducted, recorded order and item values both totalled 500.00, and the financial discrepancy was zero.

  Both concurrency-test executions completed successfully. All retained test fixtures were subsequently removed, all six historical table counts reconciled to 822,832 records, and the 14 original negative-stock products were preserved.

- **What this costs:**

  Purchases targeting the same product must still coordinate competing row modifications. Contention cannot be eliminated entirely.

  The original flash-sale benchmark measured a median refusal latency of 786.10 ms compared with 338.15 ms for successful purchases.

  Refusals therefore experienced approximately 2.32 times the median latency of successful purchases.

  The supplementary audit race showed a similar direction of difference, with median refusal latency of 40.40 ms compared with 22.90 ms for successful purchases.

  These measurements challenge the assumption that conditional updates guarantee faster sold-out responses. Individual lock-wait durations were not measured. End-to-end call latency includes execution, scheduling, lock waits and other overhead; the exact cause of the difference remains unverified.

  The implementation also introduces maintenance responsibility for the purchase function, its integrity constraints and its transactional tests.

  Inventory movements currently reference orders through a textual note rather than a dedicated foreign-key relationship.

- **What it costs the client if I am wrong:**

  If the concurrency strategy fails under an untested workload, the client may experience further overselling, refunds, customer complaints and manual reconciliation.

  If contention increases beyond acceptable levels, customers may experience delayed purchase confirmations or refusals.

  If other applications bypass the purchase function, stock changes may occur without corresponding purchase records. The later audit trigger records ordinary existing-stock updates but cannot supply missing business context (see ADR-006).

  If future multi-product purchases are introduced without consistent locking rules, deadlocks or incomplete business operations may become possible.

  These risks could undermine confidence in inventory availability and financial reporting. Their financial impact has not been independently quantified.

- **What would make me revisit this:**

  - Repeated flash-sale benchmarks exceed the acceptable execution-time target.
  - Production measurements reveal unacceptable purchase or refusal latency.
  - Purchase requirements expand to multiple products per transaction.
  - Additional applications modify stock outside the controlled purchase workflow.
  - The business requires stronger isolation or idempotent purchase requests.
  - Audit reconciliation identifies missing or incorrect movement records.
  - Comparative testing establishes a material advantage for another concurrency strategy.

## What this survives

The implementation has demonstrated correctness under the following tested conditions:

- Valid and invalid sequential purchase requests.
- Insufficient available stock.
- Zero, negative and NULL requested quantities.
- Missing and NULL customer or product identifiers.
- Repeated competition for the last available unit.
- A synchronized burst of 400 competing purchase attempts against 50 available units.
- An unexpected SQL failure during inventory movement insertion after preceding purchase operations had occurred.
- Successful recovery following the injected failure.
- Concurrent purchases requiring individually reconcilable order, item and inventory movement records.
- Removal of temporary test records while preserving the historical baseline counts.

The evidence does not establish protection against every possible workload or failure.

The following remain outside the verified scope:

- Database crashes and disaster recovery.
- Repeated client requests following an uncertain transaction outcome.
- Arbitrary direct database writes bypassing the purchase function.
- Multi-product transaction deadlocks.
- Other transaction isolation levels.
- Production-scale mixed workloads.
- Sustained repeatability across independent runs under controlled conditions.
- General inventory auditability was outside this original purchase test; subsequent restock and correction tests are documented in ADR-006.

The original flash-sale benchmark was measured once for the original explicit-log implementation. Later audit-trigger and integrated workload trials are documented separately. The isolated stock-allocation comparison now covers explicit row locking, but not full purchase transactions or Serializable transactions. Exact lock-wait durations remain unmeasured.

Historical row-count reconciliation and targeted fixture checks do not establish complete field-level historical equivalence.

The original supplied harness checksum comparison remains unconfirmed; verify against the original distribution before final acceptance.

### Supporting evidence

- `evidence/17_place_order_deployment.txt`
- `evidence/18_place_order_verification.txt`
- `evidence/19_place_order_functional_test.txt`
- `evidence/20_place_order_atomicity_test.txt`
- `evidence/21_race_preflight.txt`
- `evidence/21a_race_environment.txt`
- `evidence/22_race_test_verbose.txt`
- `evidence/23_race_cleanup.txt`
- `evidence/24_race_performance_analysis.txt`
- `evidence/25_audit_race_retained.txt`
- `evidence/26_inventory_audit_reconciliation.txt`
- `evidence/27_retained_audit_cleanup.txt`
- `deliverables/performance/order_placement_performance.md`

See [evidence and decision index](../EVIDENCE_INDEX.md) for checkpoint identifiers.
