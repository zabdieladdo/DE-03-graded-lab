# DE-03 — Engineering Defence and Challenge Register

Purpose: Maintain a record of engineering reasoning, counterarguments, trade-offs and unresolved questions for the final lab review.

This register supports the ADRs but does not replace them.

## D-001 — Separate learning and graded environments

**Initial position:** Use separate databases and keep the graded repository independent of learning exercises.

**Challenge:** Maintaining separate environments introduces additional setup and configuration overhead.

**Response:** Separation prevents experimental changes from contaminating the assessed baseline and supports reproducibility.

**Evidence:** Setup verification, original bundle checksums and six-table baseline reconciliation.

**Status:** Verified locally.

## D-002 — Business value validation as the initial priority

**Initial position:** Accurate and consistent business values are essential for customer service, financial reporting and operational decisions.

**Strongest counterargument:** Correct starting data cannot prevent overselling when concurrent transactions are unsafe. Transaction safety may therefore represent a more immediate customer-facing risk.

**Response:** Both concerns require investigation. Priority should reflect business impact, urgency, likelihood and recoverability rather than the number of defective records alone.

**Evidence:** Client engagement brief, schema inspection and business value profiling.

**Outstanding question:** Which issue presents the greatest immediate exposure?

**Status:** Priority decision pending.

## D-003 — Preserve and flag unresolved historical records

**Decision:** Preserve historical records with broken relationships rather than deleting them or inventing replacement references.

**Reasoning:** Preservation retains facts that cannot currently be recovered and provides a reversible recovery path.

**Strongest counterargument:** Preserved orphaned records can continue to distort reports and prevent complete foreign key validation.

**Response:** Explicit exception reporting and appropriate controls for new records are required. Recovery must depend on trustworthy source evidence.

**Evidence:** 1,023 broken non-null references across four relationships.

**Related decision:** ADR-001.

**Outstanding question:** Which enforcement and exception-handling mechanism best supports this policy?

**Status:** Policy accepted; implementation and verification pending.

## D-004 — Normalize order statuses through the reporting layer

**Decision:** Preserve original historical status values and apply a centralized candidate normalization rule when reporting.

**Reasoning:** The mapping is reversible, preserves source evidence and can be revised when authoritative business definitions become available.

**Strongest counterargument:** Consumers bypassing the reporting layer may continue to produce inconsistent figures. An incorrect mapping could also misclassify valid transactions.

**Response:** Centralize the mapping, disclose its assumptions, identify unknown statuses and investigate validation rules for new transactions.

**Evidence:** 15 raw status representations potentially map to five business states. An exact lowercase completed filter would exclude 89,260 of 111,351 candidate completed orders, representing 273,128,670.24 in recorded order amounts.

**Limitation:** This is conditional reporting exposure, not proven revenue loss or a measured defect in the existing Monday report.

**Outstanding questions:** Are complete and completed equivalent? Which business states qualify as customer spending? What is the performance cost of normalization?

**Status:** Reporting-layer treatment selected; business semantics and implementation pending.

## D-005 — Distinguish suspicious values from genuine defects

**Position:** Investigate unusual records before modifying them or enforcing new constraints.

**Challenge:** Retaining unusual records may allow genuine errors to remain unresolved.

**Response:** Classify records using their business meaning, quantify their impact and disclose unresolved cases instead of applying unsupported corrections.

**Evidence:** Negative inventory movements align with sales, damage and corrections. Zero movements align with stock takes. Duplicate emails, zero item prices and large quantities require further investigation.

**Outstanding question:** Which unusual records can be established as legitimate using the available evidence?

**Status:** Investigation ongoing.

## Final review checklist

- [ ] Revisit every initial engineering position.
- [ ] Identify the strongest alternative to every accepted ADR.
- [ ] Distinguish measured evidence from assumptions.
- [ ] Explain the cost to the client if each decision is wrong.
- [ ] Verify that implemented solutions match accepted decisions.
- [ ] Identify residual risks and unresolved business questions.
- [ ] Reproduce the evidence from a fresh database load.
- [ ] Review all decisions against the official assessment rubric.
## D-006 — Measure sensitivity before settling spending semantics

**Initial position:** Run the customer spending report under
six combinations of vocabulary and order eligibility policies.

**Reasoning:** Authoritative business definitions are unavailable.
A controlled comparison can establish which unresolved decisions
have the greatest effect on business reporting.

**Strongest counterargument:** Stable top-100 membership does not
establish that spending definitions are financially low-risk.
Reported amounts may change significantly while rankings remain
stable.

**Additional challenge:** Exact-match exclusion of cancelled
and refunded orders can admit alternative spellings of those
same states.

**Response:** Measure attributed spending, unattributed amounts,
customer-level changes, top-100 overlap, entrants, exits and rank
movement. Compare both isolated and combined decision effects.

**Experimental controls:**
- Same source database and consistent snapshot.
- Same customer population.
- Same recorded order amount measure.
- Same historical time scope.
- Same deterministic ranking rule.
- No changes to stored historical records.

**Evidence:**
- sql/01_diagnosis/05_status_sensitivity.sql
- evidence/05_status_sensitivity.txt (pending execution)

**Limitation:** This experiment measures reporting sensitivity,
not actual revenue recognition or the correctness of the
existing Monday report.

**Related decision:** Proposed ADR-003.

**Status:** Experiment designed; results pending.

### D-006 — Measured experiment outcome

Date: 2026-11-25

Evidence:
- evidence/05_status_sensitivity.txt

Verification:
- All 11 comparisons returned successfully.
- Baseline control returned zero differences.
- Every comparison reconciled to zero.
- Top-100 entrants equalled exits.
- Top-100 overlap plus entrants equalled 100.
- Read-only transaction ended with ROLLBACK.

Measured findings:
- Normalizing completed statuses increased attributed
  spending by 272,799,568.15 (410.71%).
- 36,031 customer spending totals changed.
- 82 of the original top 100 customers were replaced.
- Including shipped orders after normalization increased
  attributed spending by 40,918,016.89 (12.06%).
- Including shipped and pending orders increased attributed
  spending by 89,262,456.02 (26.31%) relative to normalized
  completed-only spending.
- Exact exclusion admitted 12,721 additional orders and
  39,046,537.14 in additional attributed spending compared
  with normalized exclusion.

Conclusion:
Both business decisions materially affect reporting.
Vocabulary normalization has the larger measured effect
under completed-only and completed-plus-shipped policies.

Strongest remaining counterargument:
The largest numerical change does not necessarily represent
the greatest business harm. Transaction safety may remain
the more urgent operational priority.

Additional limitation:
The experiment does not establish which spending policy
is correct. It measures sensitivity to alternative rules.

Recommendation:
Clarify vocabulary first, then spending eligibility.
Centralize normalization and prefer explicit eligible
status lists over broad exclusion rules.

Status:
Experiment completed and verified.
Final spending eligibility decision pending.

## D-014 — Verify raw data before normalization

**Initial position:** Normalize order statuses to support consistent reporting.

**Challenge:** Normalization may conceal differences in the original data and introduce unverified assumptions about business meaning.

**Verification method:** Repeat the price anomaly and orphaned customer investigations using original stored status values without LOWER, TRIM or CASE transformations.

**Evidence:**
- 15 original status representations across 159,384 orders.
- Exact completed status: 22,091 orders.
- Formatting normalization only: 89,066 completed orders.
- Formatting and candidate vocabulary normalization: 111,351 completed orders.
- All 148 missing-price items and 152 zero-price items reconcile.
- All 210 orders without valid customers reconcile.
- Recorded unattributed order amounts reconcile to 665,180.61.
- Distinct missing customer counts must be recalculated at the intended aggregation level.

**Recommended treatment:** Preserve original status values and implement a documented reporting-layer mapping. Distinguish formatting standardization from vocabulary interpretation.

**Residual risk:** Numerical reconciliation does not establish semantic equivalence. The business meaning of complete versus completed remains unverified.

**Evidence file:** `evidence/07_raw_status_investigation.txt`

**Investigation status:** Passed.

**Business mapping approval:** Pending.


## D-015 — Prioritize transaction safety before the next flash sale

**Initial position:** Business value validation should receive the highest priority because unreliable data undermines reporting and decision-making.

**Revised position:** Transaction safety should receive the highest immediate implementation priority.

**Decision owner:** Lab author.

### Reasoning

- The upcoming flash sale creates an immediate risk of additional overselling.
- Kloud Kart has already experienced two reported overselling incidents.
- The expected workload of approximately 400 orders in ten seconds against one product creates substantial contention for the same stock.
- Historical reporting and integrity problems can be investigated later because the original records have been preserved.
- Refunds cannot completely reverse customer inconvenience or reputational damage.

### Supporting evidence

- The practice fixture demonstrated that two transactions under Read Committed could both read an available stock quantity of one, commit successful purchases and produce a lost update.
- Fourteen products have negative recorded stock.
- Thirteen of those products have negative stock quantities matching their net recorded movements.
- One negative-stock product has an unexplained four-unit reconciliation difference.

### Strongest counterargument

Status inconsistency represents substantial reporting exposure. Under the proposed completed-status mapping, an exact lowercase completed filter would overlook 89,260 orders with recorded amounts totalling 273,128,670.24.

Delaying reporting improvements could therefore result in additional incorrect business decisions.

### Response to the counterargument

The upcoming flash sale makes transaction safety more urgent. Historical reports can be recalculated from preserved source records, while the consequences of accepting orders for unavailable stock cannot be fully reversed.

Reporting risks remain significant and should be disclosed until corrected.

### Evidence limitations

- The concurrency experiment used a synthetic practice fixture.
- The historical negative-stock records have not been causally linked to concurrent purchases.
- The recorded financial exposure is not confirmed revenue loss.
- The graded purchase routine has not yet been implemented or tested.

### Decision

Prioritize transaction-safe order placement, followed by reporting correctness and the remaining integrity, auditability and performance improvements.

### Verification required

Demonstrate that concurrent purchases cannot oversell available stock, that unsuccessful purchases return a clear refusal, and that stock deductions, successful orders and inventory movement records remain consistent.

**Priority decision:** Accepted.

**Implementation verification:** Pending.

## D-016 — Define customer spending using completed orders only

**Decision owner:** Lab author.

**Date:** 2026-11-26

### Decision

Use candidate normalized completed orders as the provisional eligibility rule for customer spending reports.

Preserve the original order statuses and apply the eligibility rule in the reporting layer.

### Reasoning

Completed orders provide a conservative available basis for measuring recorded customer spending. Including shipped or pending orders would introduce additional assumptions about payment and transaction completion that cannot be verified from the supplied database.

### Alternatives considered

**A — Completed only (selected)**

Provides a conservative and reproducible reporting definition but may exclude legitimate payments associated with orders that have not reached completed status.

**B — Completed and shipped**

Could capture spending associated with dispatched goods but assumes that shipment is sufficient evidence of finalized spending.

**C — Completed, shipped and pending**

Provides a broader measure of order activity but may include transactions that have not been finalized.

### Supporting evidence

- Completed-only attributed spending: 339,220,585.14.
- Including shipped orders increases attributed spending by 40,918,016.89 (12.06%).
- Including shipped and pending orders increases attributed spending by 89,262,456.02 (26.31%).
- Including shipped orders changes 20 members of the baseline top-100 customer list.
- Including shipped and pending orders changes 33 members.
- Completed-only eligibility includes 111,351 orders, of which 144 cannot be attributed to existing customers.

### Strongest counterargument

Customers may already have paid for shipped or pending orders. Excluding these orders could understate actual customer payments and distort customer rankings.

### Response

The available database does not independently establish payment or settlement. Completed-only eligibility is therefore a conservative reporting assumption rather than a verified accounting definition.

Excluded order amounts should remain visible through separate reporting or reconciliation measures.

### Residual risks

- Completed status does not independently establish payment.
- The equivalence of complete and completed remains unverified.
- The database does not provide payment or completion timestamps.
- Historical monthly spending may change as order statuses change.
- Recorded checkout totals may contain unresolved inaccuracies.

### Revisit conditions

Reconsider the policy when authoritative payment records, documented order lifecycle rules or an approved business spending definition become available.

**Engineering decision:** Accepted.

**Client confirmation:** Unavailable.

**Implementation verification:** Pending.

## D-017 — Preserve and flag extreme order quantities

**Date:** 2026-11-26

**Decision owner:** Lab author.

### Decision

Preserve the original quantities of suspicious historical order items and expose them through data-quality flags. Do not automatically correct or exclude the records.

### Supporting evidence

- Six of 336,559 order items contain quantities of 999 or 9,999.
- All remaining quantities fall between 1 and 10.
- The six suspicious lines have combined calculated values of 3,073,441.59.
- Each suspicious line individually exceeds the recorded checkout total of its associated order.
- Two affected orders qualify under the candidate completed-only spending policy.
- Some checkout totals suggest plausible alternative quantities, but those quantities have not been independently verified.

### Alternatives considered

**A — Correct inferred quantities**

Could reduce apparent financial discrepancies but risks introducing unsupported historical values.

**B — Preserve and flag (selected)**

Retains original evidence and supports further investigation without inventing corrections.

**C — Preserve but exclude suspicious values**

Could reduce distortion in analytical calculations but risks excluding legitimate wholesale activity.

### Strongest counterargument

Preserving suspicious quantities allows them to continue distorting downstream calculations if analysts ignore or cannot access the quality flags.

### Response

Make the exceptions visible through a documented data-quality reporting mechanism. Require relevant reports to disclose how suspicious values are treated.

Use recorded checkout totals for the proposed completed-order spending metric rather than automatically recalculating spending from suspicious item quantities.

### Constraints

Do not impose a maximum quantity of 10 based solely on the observed distribution. The threshold is investigative, not an approved business restriction.

New purchases must be validated against available stock.

### Residual risks

- Suspicious quantities may still distort item-level sales and demand analysis.
- Legitimate wholesale transactions may be flagged.
- Recorded checkout totals may themselves contain inaccuracies.
- The relationship between these quantities and historical inventory movements remains unverified.

### Revisit conditions

Reconsider historical corrections when authoritative purchase records or approved business rules become available.

**Engineering decision:** Accepted.

**Implementation verification:** Pending.

**Evidence:** `evidence/06_exception_investigation.txt` and `evidence/04_business_impact.txt`.


## D-018 — Use a configurable low-stock threshold

**Date:** 2026-11-26

**Decision owner:** Lab author.

### Decision

Implement a configurable low-stock threshold with a provisional default of 10 units.

Classify products as low stock when their recorded stock quantity is strictly below the effective threshold.

The threshold is an operational reporting assumption, not a verified optimal reorder point.

### Supporting evidence

- The learning-environment investigation identified 1,949 low-stock products out of 4,023 at a threshold of 10.
- Fourteen products have negative recorded stock.
- There are 577 products with zero stock.
- Fifteen low-stock products have no assigned category.
- Three low-stock products belong to categories that cannot reach a valid root.
- Product-specific demand and replenishment requirements have not been independently established.

### Alternatives considered

**A — Fixed threshold of 10**

Simple and consistent but embeds an unverified business assumption into the reporting logic.

**B — Configurable threshold with a default of 10 (selected)**

Provides immediate reporting functionality while allowing the business to adjust the threshold without rewriting the underlying query.

**C — Product-specific thresholds**

Could provide more accurate replenishment recommendations but requires reliable demand, supplier lead-time and safety-stock information.

### Strongest counterargument

A configurable global threshold still assumes that products have comparable replenishment requirements. At the provisional threshold of 10, nearly half the catalogue qualifies as low stock, potentially creating excessive alerts.

### Response

The threshold is explicitly provisional and adjustable. The report should disclose the effective threshold and distinguish negative stock, zero stock and ordinary low-stock conditions.

Product-specific replenishment rules can be introduced when sufficient business evidence becomes available.

### Proposed implementation requirements

- Use a positive integer threshold.
- Default to 10 when no threshold is supplied.
- Reject invalid threshold values.
- Display the effective threshold in the report.
- Support nested categories without hardcoded hierarchy depth.
- Prevent infinite recursion caused by category cycles.
- Preserve visibility of uncategorised and unrooted products.
- Reconcile the overall low-stock population without double-counting products across hierarchy levels.

### Residual risks

- The default threshold may generate excessive or insufficient alerts.
- A global threshold cannot account for individual product demand.
- Different threshold selections may produce inconsistent reports.
- Historical inventory quantities may contain unresolved inaccuracies.

### Revisit conditions

Reconsider the default or introduce product-specific thresholds when verified demand patterns, replenishment lead times or approved inventory policies become available.

**Engineering decision:** Accepted.

**Client approval of threshold:** Unavailable.

**Graded implementation verification:** Pending.


## D-019 — Preserve customer identities and flag potential duplicates

**Date:** 2026-11-26

**Decision owner:** Lab author.

### Decision

Preserve separate customer IDs and their existing order relationships. Calculate customer spending at the recorded customer-account level.

Identify shared normalized email addresses as potential identity exceptions without automatically merging accounts or consolidating their spending.

### Supporting evidence

- The database contains 40,420 customer records.
- There are 533 duplicate normalized email groups affecting 1,068 customer records.
- All 533 groups share the same normalized customer name.
- All 533 groups contain different trimmed phone numbers.
- In 206 groups, the normalized cities differ.
- Enforcing one record per normalized email would identify 535 excess records, but these are not confirmed duplicate individuals.

### Alternatives considered

**A — Merge accounts sharing email and name**

Could resolve fragmented customer spending but risks incorrectly combining different individuals and reassigning historical transactions.

**B — Preserve separate customer IDs and flag potential duplicates (selected)**

Preserves recorded order attribution and historical evidence while making identity uncertainty visible.

**C — Consolidate matching emails in spending reports**

Avoids modifying historical records but still introduces an unverified assumption about personal identity.

### Strongest counterargument

If multiple accounts belong to the same person, account-level reporting understates that person's combined spending and may distort loyalty rankings and customer-level metrics.

### Response

The supplied database establishes account-level identity but does not independently establish personal identity. Reporting by customer ID is therefore the most defensible available approach.

Potential duplicates should be exposed through data-quality reporting, and the spending report should explicitly describe its account-level reporting scope.

### Implementation requirements

- Preserve original customer IDs and order relationships.
- Calculate spending using customer ID.
- Flag shared normalized emails.
- Avoid introducing unverified email uniqueness constraints.
- Ensure quality assessment joins do not duplicate spending records.
- Disclose unresolved identity uncertainty.

### Residual risks

- Spending may be fragmented across accounts belonging to the same individual.
- Account-level customer counts may overstate the number of unique people.
- Customer rankings may differ from verified person-level rankings.
- The actual ranking impact of email consolidation has not been measured.

### Revisit conditions

Reconsider account consolidation when authoritative customer identity information, verified account ownership or approved business identity rules become available.

Any future consolidation must preserve historical traceability.

**Engineering decision:** Accepted.

**Client identity policy confirmation:** Unavailable.

**Implementation verification:** Pending.

**Evidence:** `evidence/03_business_value_validation.txt` and `evidence/06_exception_investigation.txt`.


## D-020 — Final diagnosis risk ranking

**Date:** 2026-11-26

**Decision owner:** Lab author.

### Accepted ranking

1. Unsafe concurrent order placement — Critical
2. Inventory accuracy and auditability — High
3. Inconsistent order statuses — High
4. Broken relational references — High
5. Financial value anomalies — High
6. Slow customer spending reports — High
7. Broken category hierarchy — Medium–High
8. Potential duplicate customer identities — Medium
9. Ambiguous but potentially legitimate values — Review

### Reasoning

Prioritize the prevention of new customer harm and the reliability of stock information ahead of historical reporting corrections.

Inventory accuracy and auditability rank second because transaction safety alone does not establish that recorded stock is trustworthy.

Reporting correctness remains a high priority and must precede performance optimization.

Historical exceptions should remain visible without unsupported corrections.

### Strongest counterargument

The measured financial reporting exposure is substantial and could justify prioritizing reporting correctness above inventory reconciliation.

### Response

Risk priority considers urgency, reversibility, business consequences and evidence confidence, not monetary exposure alone.

The expected flash-sale workload makes transaction safety and stock reliability particularly urgent.

### Deliverable

`deliverables/diagnosis/data_findings.md`

**Risk ranking:** Accepted.

**Implementation and regression verification:** Pending.

### D021 — Selective foreign key validation

**Date:** 2026-11-26

**Decision:** Add foreign keys for all six intended relationships. Use NOT VALID for the four relationships with existing orphan records and fully validated constraints for the two clean relationships.

**Reasoning:** Prevent new relational integrity defects while preserving historical records. This implements the historical preservation policy using standard PostgreSQL mechanisms with minimal additional complexity.

**Alternatives considered:** Repair historical references before adding constraints, or enforce relationships only through application functions.

**Strongest counterargument:** Historical violations remain unresolved, and foreign key enforcement introduces additional write checks.

**Defence:** Historical repairs cannot be justified without authoritative evidence. Preventing new defects provides immediate protection without inventing historical relationships. The performance cost will be assessed through testing.

**Scope boundary:** Reuse the existing diagnostic scripts and findings as the exceptions register. Do not introduce dedicated exception tables, automated repair mechanisms or additional infrastructure.

**Residual risk:** Existing orphan records may still affect reporting. Foreign keys do not prevent NULL references, category cycles or concurrent overselling.

**Verification required:** Confirm all six constraints exist, four are initially unvalidated, two are validated, new invalid references are rejected and historical records remain unchanged.

**Status:** Engineering decision accepted; implementation and verification pending.

#### D021 — Implementation and verification update

**Date:** 2026-11-26

**Implementation:** Six foreign key constraints introduced through a single transactional migration. Four constraints use NOT VALID, and two are fully validated. Default non-cascading deletion and update behaviour retained.

**Measured results:**
- Total foreign keys: 6.
- Fully validated foreign keys: 2.
- Initially unvalidated foreign keys: 4.
- Historical orphan references before migration: 1,023.
- Historical orphan references after migration: 1,023.
- Total baseline records: 822,832, unchanged.
- Relationship reconciliation differences: 0 across all six relationships.
- Both verification scripts completed successfully with exit code 0.

**Evidence:**
- `evidence/08_foreign_key_migration.txt`
- `evidence/09_foreign_key_verification.txt`
- `evidence/10_post_migration_integrity.txt`

**Residual risk:** Historical violations remain unresolved. Foreign keys do not independently prevent NULL references, invalid business values, category cycles or concurrent overselling.

**Status:** Implemented. Constraint definitions and historical count preservation verified. Negative-write regression tests pending.

### D022 — Essential numerical value constraints

**Date:** 2026-11-26

**Decision:** Introduce five CHECK constraints covering order item quantities, product stock, product prices, order item prices and order totals. Explicitly reject NULL values in these essential numerical fields.

**Reasoning:** These fields directly affect stock availability, purchase correctness and financial reporting. Database-level enforcement protects multiple write paths without introducing custom validation mechanisms.

**Alternatives considered:** Restrict validation to the purchase function, introduce only quantity and stock constraints, or comprehensively constrain all business fields.

**Strongest counterargument:** Some business rules remain unconfirmed, and NOT VALID check constraints may prevent unrelated updates to historical rows containing invalid values.

**Defence:** Preserve historical exceptions, permit legitimate zero values, avoid unsupported maximum quantities and restrict enforcement to essential numerical fields.

**Historical treatment:** Preserve the 14 negative-stock products and 148 missing-price order items using NOT VALID constraints. Do not automatically correct their values.

**Residual risk:** Positive but incorrect quantities and prices remain possible. Constraints do not independently prevent concurrent overselling or guarantee financial reconciliation.

**Revisit when:** The client confirms alternative stock, pricing, backorder or financial adjustment rules, or authoritative evidence permits historical remediation.

**Status:** Engineering decision accepted; implementation and verification pending.

#### D022 — Implementation and verification update

**Date:** 2026-11-26

**Implementation:** Five numerical CHECK constraints introduced in one transactional migration. Three constraints are fully validated and two use NOT VALID.

**Measured results:**
- Total CHECK constraints: 5.
- Fully validated constraints: 3.
- Initially unvalidated constraints: 2.
- Historical negative-stock products: 14, unchanged.
- Historical missing-price order items: 148, unchanged.
- Zero-stock products: 577, unchanged.
- Zero-priced order items: 152, unchanged.
- Zero inventory movements: 90, unchanged.
- Combined ALTER TABLE execution time: 32.716 ms.
- Migration and verification exit codes: 0.

**Evidence:**
- `evidence/11_value_constraint_migration.txt`
- `evidence/12_value_constraint_verification.txt`

**Conclusion:** Constraint definitions and historical exception preservation match the accepted design. No historical data corrections were performed by the migration.

**Residual risk:** Existing invalid values remain unresolved. Positive but incorrect values remain possible. NOT VALID check constraints can restrict updates to historical rows that still violate them.

**Status:** Implemented; metadata and historical exception counts verified. Negative-write regression tests pending.

### D023 — Concurrency-safe identifier generation

**Date:** 2026-11-26

**Proposed decision:** Add GENERATED BY DEFAULT AS IDENTITY to the existing primary keys of orders, order_items and inventory_log.

**Measured evidence:** All three identifiers are non-nullable integers without defaults or identity generation. Their current maximum values are 659384, 1236559 and 982487 respectively.

**Reasoning:** Concurrent purchases require distinct identifiers without relying on unsafe MAX(id) + 1 calculations during individual transactions.

**Alternatives considered:** Manual identifier allocation, standalone sequences, GENERATED ALWAYS AS IDENTITY, UUIDs and custom counter tables.

**Strongest counterargument:** GENERATED BY DEFAULT permits explicit identifier assignment, which can cause future collisions if the associated sequence is not synchronized.

**Defence:** Identity columns provide native concurrency-safe allocation while retaining compatibility with historical identifiers and controlled imports. The purchase function will use automatically generated identifiers.

**Implementation approach:** Calculate starting values from the actual maximum identifiers during the migration while preventing concurrent writes to the affected tables.

**Residual risk:** Sequence gaps, integer exhaustion and incorrectly managed explicit identifier imports remain possible. Identity generation does not prevent concurrent overselling.

**Evidence:** `evidence/13_identifier_inspection.txt`

**Status:** Design proposed; implementation and verification pending.

#### D023 — Implementation and verification update

**Date:** 2026-11-26

**Implementation:** Three GENERATED BY DEFAULT AS IDENTITY columns configured for orders, order_items and inventory_log.

**Measured results:**
- Identity columns configured: 3.
- Associated sequences: 3.
- Orders starting identifier: 659385.
- Order items starting identifier: 1236560.
- Inventory log starting identifier: 982488.
- Sequence increment: 1 for all three.
- Sequence cycling: disabled.
- Historical row counts and identifier ranges: unchanged.
- Verification exit code: 0.

**Evidence:**
- `evidence/13_identifier_inspection.txt`
- `evidence/14_identifier_migration.txt`
- `evidence/15_identifier_verification.txt`

**Conclusion:** Automatic identifier generation is configured above the historical maximum identifiers without changing existing primary key values.

**Residual risk:** Explicit identifier assignment can interfere with future sequence allocation. Sequence gaps are acceptable. Concurrent purchase correctness remains untested.

**Status:** Implemented; configuration verified. Functional and concurrency tests pending.

### Stage 02 — Combined schema integrity verification

**Date:** 2026-11-26

**Decisions verified:** D021, D022 and D023.

**Testing method:** Transactional SQL regression tests using PL/pgSQL exception handling, constraint-name verification and SQLSTATE assertions. All temporary record changes were rolled back.

**Measured results:**

| Test category | Passed | Expected |
|---|---:|---:|
| Foreign key rejection | 6 | 6 |
| Invalid numerical value rejection | 5 | 5 |
| NULL numerical value rejection | 5 | 5 |
| Automatic identifier generation | 3 | 3 |
| Permitted zero values | 5 | 5 |
| Baseline table reconciliation | 6 | 6 |

**Functional test execution time:** 17.898 ms.

**Baseline preservation:** All six table counts remain unchanged, totalling 822,832 records.

**Sequence behaviour:** Three identifiers were consumed during testing. Their associated records were rolled back. Sequence gaps are expected and accepted.

**Evidence:** `evidence/16_schema_integrity_test.txt`

**Limitations:** The rejection tests exercise invalid updates rather than every possible write path. Concurrent identifier allocation, concurrent stock protection and atomic purchase processing remain untested.

**Conclusion:** The implemented schema protection mechanisms passed all executed functional tests. The database is ready for transaction-safe purchase function development.
#### D024 — Concurrency strategy verification

**Date:** 2026-11-26

**Decision:** Retain strategy B — atomic conditional stock updates under Read Committed transaction isolation.

**Decision status:** Accepted and implemented.

**Verification status:** Functional correctness, tested failure atomicity, official concurrency scenarios, initial performance benchmark and post-test cleanup verified. Detailed independent concurrent inventory audit reconciliation remains pending.

##### Original reasoning

The conditional-update strategy was selected because it combines stock availability validation and stock deduction within one database statement.

The strategy avoids the unsafe separation of reading stock and subsequently updating it using a previously retrieved value.

It also provides the following potential advantages:

- Requests encountering already committed insufficient stock can avoid taking an unnecessary product-row update lock.
- Updates that do not modify key columns can use a row-lock mode compatible with foreign-key KEY SHARE locks.
- The stock availability condition is expressed directly in the statement responsible for stock deduction.
- The implementation avoids introducing application-level serialization retry logic for the tested Read Committed workload.
- Related purchase operations remain within one transaction.

These advantages informed the engineering decision. They do not establish measured superiority over every alternative concurrency strategy.

##### Measured functional and atomicity evidence

| Measurement | Result |
|---|---|
| Functional purchase tests | 11/11 passed |
| Successful functional purchases | 2 |
| Correct functional refusals | 9 |
| Functional purchase financial difference | 0.00 |
| Functional inventory movement | -5 units |
| Failure atomicity assertions | 10/10 passed |
| Stock before injected failure | 3 units after deduction |
| Stock restored after failure | 5 units |
| Partial order count difference | 0 |
| Partial order item count difference | 0 |
| Inventory log count difference | 0 |
| Recovery purchase | Successful |

The failure-injection test demonstrated that an unexpected inventory insertion error reversed preceding stock, order and order item changes.

##### Measured concurrency evidence

| Measurement | Result |
|---|---:|
| Official concurrency scenarios passed | 4/4 |
| Last-unit race rounds passed | 25/25 |
| Total purchase attempts | 463 |
| Successful purchases | 80 |
| Clean refusals | 383 |
| Unhandled purchase errors | 0 |
| Flash-sale attempts | 400 |
| Flash-sale available units | 50 |
| Flash-sale successful purchases | 50 |
| Flash-sale clean refusals | 350 |
| Flash-sale remaining stock | 0 |
| Flash-sale oversold units | 0 |
| Audit scenario successful purchases | 5 |
| Audit scenario inventory movements | 5 |
| Official harness exit code | 0 |

##### Measured performance evidence

| Measurement | Result |
|---|---:|
| Flash-sale wall-clock time | 1.89 seconds |
| Reference workload benchmark | 10.00 seconds |
| Time below benchmark | 8.11 seconds |
| Percentage below benchmark | 81.10% |
| Average attempt throughput | 211.64 attempts/second |
| Successful purchase throughput | 26.46 purchases/second |
| Refusal throughput | 185.19 refusals/second |
| Overall minimum latency | 133.20 ms |
| Overall median latency | 730.90 ms |
| Overall p95 latency | 1055.00 ms |
| Overall maximum latency | 1088.90 ms |
| Successful purchase median | 338.15 ms |
| Successful purchase p95 | 432.60 ms |
| Successful purchase maximum | 444.00 ms |
| Refused purchase median | 786.10 ms |
| Refused purchase p95 | 1057.70 ms |
| Refused purchase maximum | 1088.90 ms |

The measured attempt throughput was approximately 5.29 times the reference workload rate of 40 attempts per second.

This comparison is against the workload benchmark, not against the performance of another implementation.

The reproducible Python analysis independently verified 400 distinct flash-sale attempts, 50 unique successful order identifiers, 350 valid refusal responses and zero recorded errors.

The performance analysis script returned exit code 0.

##### Counterargument supported by the evidence

The original decision emphasized the potential efficiency of the sold-out refusal path.

However, refused buyers experienced a median latency of 786.10 ms compared with 338.15 ms for successful buyers.

The median refusal latency was approximately 2.32 times the successful purchase median, a difference of 447.95 ms.

A conditional update can avoid unnecessary product-row locking when insufficient stock is already visible to the statement. However, buyers arriving while stock is still available may wait for competing transactions before PostgreSQL re-evaluates the stock condition.

The observed latency difference is consistent with contention and scheduling effects, but individual lock-wait durations were not measured. The exact cause of the difference cannot therefore be established from this execution.

The results challenge any assumption that the conditional-update strategy guarantees faster refusals.

An explicit row-locking strategy remains a valid alternative, particularly where complex validation, multiple products or detailed refusal classification are required.

An explicit `FOR NO KEY UPDATE` approach could also provide the relevant foreign-key lock compatibility advantage.

No equivalent benchmark was conducted for these alternatives.

##### Independent cleanup and historical preservation

| Verification | Result |
|---|---|
| Baseline tables reconciled | 6/6 |
| Historical baseline rows | 822,832 |
| Post-test rows | 822,832 |
| Row-count difference | 0 |
| Planned race fixture product IDs remaining | 0 |
| Generated race orders remaining | 0 |
| Associated fixture order items remaining | 0 |
| Associated fixture inventory movements remaining | 0 |
| Historical negative-stock products retained | 14 |
| Last allocated order identifier | 659469 |
| Cleanup verification exit code | 0 |

The post-test verification confirmed that the 80 generated race orders and associated fixture records were removed.

The original 14 negative-stock anomalies were preserved in accordance with ADR-001.

The identifier sequence was not reset because sequence gaps resulting from rolled-back or deleted transactions are legitimate.

The matching baseline counts and targeted fixture checks provide evidence of successful cleanup. They do not constitute complete field-level historical data verification.

##### Evidence classification

| Claim | Evidence status |
|---|---|
| Conditional updates prevent overselling under the tested workload | Measured and verified |
| The last available unit is sold to exactly one competing buyer | Measured and verified across 25 rounds |
| Expected refusals return NULL order identifiers and clear messages | Measured and verified |
| Unexpected inventory write failure reverses preceding purchase changes | Measured and verified |
| Flash-sale execution meets the ten-second benchmark | Measured and verified in one run |
| Historical baseline counts reconcile after testing | Measured and verified |
| Sold-out requests can avoid unnecessary row locking | Technically supported |
| Non-key updates can reduce conflicts with foreign-key checks | Technically supported |
| Strategy B is faster than explicit row locking | Not measured |
| Refusal latency is always lower than successful purchase latency | Not supported by measured results |
| Every concurrent inventory movement reconciles to its individual order | Detailed independent verification pending |
| Performance remains consistent across repeated runs | Not measured |
| Production workload performance matches the lab benchmark | Not verified |

##### Evidence references

- `evidence/17_place_order_deployment.txt`
- `evidence/18_place_order_verification.txt`
- `evidence/19_place_order_functional_test.txt`
- `evidence/20_place_order_atomicity_test.txt`
- `evidence/21_race_preflight.txt`
- `evidence/21a_race_environment.txt`
- `evidence/22_race_test_verbose.txt`
- `evidence/23_race_cleanup.txt`
- `evidence/24_race_performance_analysis.txt`
- `scripts/analyze_race_results.py`
- `deliverables/performance/order_placement_performance.md`

##### What this buys the client

The implemented purchase workflow prevents the tested overselling scenario without introducing additional database infrastructure.

Customers receive controlled insufficient-stock responses rather than successful confirmations for unavailable stock.

The tested failure atomicity protects against partial purchase records when inventory logging fails.

These properties reduce exposure to stock inconsistencies, avoidable refunds, customer complaints and manual reconciliation.

The financial value of these avoided incidents has not been independently quantified.

##### Residual risks

- Other contention patterns and production workloads may produce different performance.
- Direct database writes bypassing the purchase function may violate the intended business workflow.
- Different transaction isolation levels may introduce serialization failures requiring retry handling.
- Future multi-product purchases may introduce additional locking and deadlock risks.
- Long-running transactions may increase contention and refusal latency.
- Repeated client requests are not independently protected by an idempotency mechanism.
- Detailed independent concurrent inventory audit reconciliation remains incomplete.
- The official benchmark has been measured only once.
- Original test harness checksum comparison remains unconfirmed.

##### What would make me revisit this decision

The decision should be reconsidered if:

- Repeated benchmarks reveal unacceptable purchase or refusal latency.
- Production workloads exceed the tested concurrency assumptions.
- Multi-product purchase requirements introduce complex locking dependencies.
- Direct stock modifications undermine purchase consistency.
- Detailed audit reconciliation identifies incorrect or missing movement records.
- Comparative testing establishes a material advantage for another concurrency strategy.
- The business introduces stronger transaction isolation or idempotency requirements.

##### Conclusion

Retain the atomic conditional-update strategy under Read Committed isolation.

The selected implementation satisfies the tested functional correctness, failure atomicity, concurrency and initial flash-sale performance requirements.

All four official concurrency scenarios passed, including 25 last-unit races and a 400-buyer flash sale completed in 1.89 seconds without overselling or unhandled purchase errors.

Independent cleanup verification reconciled all 822,832 historical records and confirmed removal of the 80 generated race orders.

The evidence supports retaining the implementation but does not establish performance superiority over alternative locking strategies.

**Final status:** Accepted; implemented; functional correctness, tested failure atomicity, official concurrency testing, initial performance benchmark and cleanup verified. Detailed concurrent inventory audit reconciliation and Stage 03 Git closure remain pending.

### D024 — Atomic conditional stock deduction

**Date:** 2026-11-26

**Status:** Accepted; implementation and testing pending.

**Decision:** Use an atomic conditional UPDATE under PostgreSQL's Read Committed isolation level to validate stock availability and deduct the requested quantity.

**Reasoning:**

1. Requests that observe already committed insufficient stock can avoid acquiring a product row lock. This is particularly relevant to the expected flash-sale workload, where 350 of 400 requests should be refused.
2. Updating the non-key stock column uses a row-lock mode compatible with foreign key KEY SHARE locks.
3. The availability condition is expressed directly in the stock-changing statement.
4. The approach requires no additional infrastructure or application-level serialization retry mechanism under the intended isolation level.

**Strongest counterargument:** Explicit locking with SELECT FOR NO KEY UPDATE provides similar foreign key lock compatibility and makes complex validation and refusal classification easier.

**Qualifications:** Requests that observe an earlier stock version may still wait for concurrent transactions. The performance advantage over explicit locking has not been measured. The stock availability predicate and the nonnegative stock CHECK constraint enforce complementary, rather than identical, guarantees.

**Defence:** For a single-product purchase, conditional stock deduction provides a compact and sufficient concurrency mechanism. The stock deduction, order, order item and inventory movement will participate in the same transaction.

**Residual risks:** Long-running caller transactions, competing stock-writing mechanisms, inconsistent lock ordering and future multi-product purchases may require additional concurrency controls.

**Required evidence:** Functional tests, injected-failure atomicity tests, the unmodified race-test harness and post-test reconciliation.


#### D024 — Deployment and configuration verification

**Date:** 2026-11-26

**Implementation:** The place_order function has been deployed using atomic conditional stock deduction under Read Committed isolation.

**Measured results:**
- Deployment exit code: 0.
- Verification exit code: 0.
- Function creation time: 5.319 ms.
- Required function signature: confirmed.
- Required return types: confirmed.
- Public function overload count: 1.
- Transaction isolation: Read Committed.
- Maximum connections: 500.
- Security mode: SECURITY INVOKER.
- Volatility: VOLATILE.

**Evidence:**
- `evidence/17_place_order_deployment.txt`
- `evidence/18_place_order_verification.txt`

**Conclusion:** The function has been successfully deployed and its interface matches the required contract.

**Status:** Implemented; configuration verified. Functional correctness, failure atomicity and concurrency safety remain unverified.

#### D024 — Functional purchase verification

**Date:** 2026-11-26

**Method:** Eleven sequential purchase scenarios executed against a controlled product fixture with five units of stock and a unit price of 100.00.

**Measured results:**
- Functional tests passed: 11/11.
- Successful purchases: 2.
- Correct refusals: 9.
- Generated order IDs: 659386 and 659387.
- Units sold: 5.
- Closing stock: 0.
- Recorded order value: 500.00.
- Calculated item value: 500.00.
- Financial difference: 0.00.
- Inventory movements: 2.
- Net inventory movement: -5.
- Functional test block execution time: 628.063 ms.
- Baseline table reconciliation: 6/6.
- Remaining test products: 0.
- Exit code: 0.

**Evidence:** `evidence/19_place_order_functional_test.txt`

**Conclusion:** The purchase function correctly processes the tested sequential purchases and controlled refusals. Successful purchases reconcile across stock, orders, order items and inventory movements.

**Limitations:** Sequential functional testing does not establish concurrency safety or atomicity under unexpected failures. Execution time includes test instrumentation and is not a purchase latency benchmark.

**Status:** Functional verification passed. Failure atomicity and concurrency testing pending.



#### D024 — Failure atomicity verification

**Date:** 2026-11-26

**Method:** A temporary BEFORE INSERT trigger on inventory_log deliberately rejected the final inventory write of a purchase. The deployed place_order function was not modified.

**Measured results:**
- Atomicity assertions passed: 10/10.
- Stock deduction observed before failure: 5 to 3.
- Order 659388 and its order item existed before the injected failure.
- Expected exception propagated: SQLSTATE P0001, DE03_INJECTED_INVENTORY_FAILURE.
- Stock restored after failure: 5.
- Order count difference: 0.
- Order item count difference: 0.
- Inventory log count difference: 0.
- Recovery purchase: successful, order 659389, remaining stock 3.
- Failure test block: 69.169 ms.
- Recovery test block: 25.631 ms.
- Baseline reconciliation: 6/6, 822,832 historical records.
- Temporary test objects removed: confirmed.
- Exit code: 0.

**Evidence:** `evidence/20_place_order_atomicity_test.txt`

**Conclusion:** The deployed purchase function demonstrated atomic rollback when its final inventory write failed. No partial purchase records remained, and the stock deduction was reversed.

**Limitations:** This test covers an injected SQL failure during inventory insertion. It does not establish crash recovery, concurrent purchase safety or behaviour under every possible failure mode.

**Status:** Functional correctness and tested failure atomicity verified. Concurrency testing pending.







### Transaction safety — concurrency, reconciliation and performance

**Date:** 26 November 2026

**What I implemented:** An atomic conditional stock update followed by order creation, order item creation and inventory movement recording within the same transaction.

**What I verified:**

- All 11 functional purchase tests passed.
- All 10 failure atomicity assertions passed.
- All 25 last-unit races produced exactly one successful purchase.
- The 400-buyer flash sale completed in 1.89 seconds, with 50 successful purchases, 350 clean refusals and zero unhandled errors.
- The complete official harness processed 463 attempts, producing 80 successful purchases and 383 refusals.
- Independent cleanup verification reconciled all 822,832 historical records.
- The original 14 negative-stock anomalies were preserved.
- A reproducible Python analysis confirmed the flash-sale median of 730.90 ms and p95 of 1055.00 ms.

**What I learned:**

1. Atomicity ensures that related changes succeed or fail together.
2. Concurrency safety requires controlling competing modifications, not merely checking stock before an update.
3. A correct refusal is a successful business outcome, not a system error.
4. Sequence values are not reclaimed when transactions roll back or records are deleted.
5. Wall-clock throughput and individual response latency measure different aspects of performance.
6. Conditional updates do not guarantee that refused buyers avoid all waiting.
7. An audit trail must reconcile individual transactions and quantities, not just record counts.
8. Passing a supplied test harness is necessary evidence but does not establish correctness for every possible workload.

**Decision D024:** Retain the conditional-update strategy. Correctness and the initial performance benchmark have been verified. Comparative performance against explicit row locking remains unmeasured.

**Remaining work:** Independently reconcile the retained audit fixture, remove test records, finalize ADR-002 and merge the transaction-safe order placement branch.

#### D024 — Independent concurrent inventory audit verification

**Date:** 2026-11-26

**Decision:** Retain the atomic conditional-update strategy under Read Committed isolation.

**Method:** The original race-test harness was executed independently for Test 4 using verbose output and retained fixtures. A separate read-only SQL verification reconciled the resulting purchases, order items, stock balance and inventory movements.

**Measured evidence:**

- Supplementary purchase attempts: 12.
- Successful purchases: 5.
- Clean refusals: 7.
- Unhandled errors: 0.
- Initial stock: 5.
- Remaining stock: 0.
- Distinct orders: 5.
- Order items: 5.
- Units sold: 5.
- Inventory movements: 5.
- Net inventory movement: -5.
- Recorded order value: 500.00.
- Calculated item value: 500.00.
- Financial difference: 0.00.
- Independent audit assertions: 12/12 passed.
- Generated order identifiers: 659470–659474.
- Generated order item identifiers: 1236645–1236649.
- Generated inventory log identifiers: 982573–982577.
- Race-test exit code: 0.
- Reconciliation exit code: 0.

**Individual traceability:** Every successful purchase had exactly one corresponding inventory movement. Each movement recorded the correct product, quantity of -1, sale reason and order reference.

**Supplementary performance:**

- Overall median latency: 34.35 ms.
- Overall p95 latency: 46.50 ms.
- Overall maximum latency: 46.50 ms.
- Successful purchase median: 22.90 ms.
- Refused purchase median: 40.40 ms.
- Refusal-to-success median latency ratio: approximately 1.76.

These results provide additional evidence that refused buyers do not necessarily receive faster responses during contention. They do not establish the cause of the latency difference or comparative superiority over explicit locking.

**Cumulative concurrency evidence:**

- Original official harness: 463 attempts, 80 successes, 383 refusals and zero errors.
- Supplementary audit race: 12 attempts, five successes, seven refusals and zero errors.
- Combined concurrency testing: 475 attempts, 85 successes, 390 refusals and zero errors.

**What this buys the client:** Successful purchases can be traced individually from the recorded order to the purchased item and corresponding stock deduction. This provides evidence for investigating stock discrepancies and reconciling purchase records.

**Residual risks:**

- The order reference in the inventory movement is textual rather than a dedicated foreign-key relationship.
- Direct stock changes that bypass the purchase function are not covered by this test.
- Restocks, corrections and other inventory movements require additional audit controls.
- The supplementary test uses a small, single-product workload.
- The 400-buyer performance benchmark has not been independently repeated.

**Evidence:**

- `evidence/25_audit_race_retained.txt`
- `evidence/26_inventory_audit_reconciliation.txt`
- `tests/06_inventory_audit_reconciliation.sql`

**Conclusion:** The selected concurrency strategy has passed functional testing, failure atomicity testing, all official concurrency scenarios and detailed independent purchase audit reconciliation.

**Status:** Accepted, implemented and technically verified for the tested purchase workflow. Final retained-fixture cleanup, ADR-002 finalization and Git closure remain pending.

#### D024 — Final cleanup and decision closure

**Date:** 2026-11-26

**Decision:** Retain the atomic conditional-update strategy under Read Committed isolation.

**Final cleanup evidence:**

- Expected retained fixture records: 16.
- Verified retained fixture records: 16.
- Deleted fixture products: 1.
- Deleted fixture orders: 5.
- Deleted fixture order items: 5.
- Deleted fixture inventory movements: 5.
- Total deleted fixture records: 16.
- Pre-cleanup records: 822,848.
- Post-cleanup records: 822,832.
- Historical baseline row-count difference: 0.
- Historical tables reconciled: 6/6.
- Historical negative-stock products preserved: 14.
- Remaining retained fixture records: 0.
- Transaction commitment: successful.
- Cleanup exit code: 0.

**Final sequence state:**

- Orders: 659474.
- Order items: 1236649.
- Inventory log: 982577.

All three sequences reported is_called = true and were intentionally left unchanged.

**Engineering reasoning:** Targeted cleanup using verified identifiers is safer than broad deletion based only on fixture names. Transactional deletion and pre-commit assertions ensure that unexpected changes can prevent the cleanup from committing.

**Counterargument:** Matching historical table counts cannot independently prove that every historical field remains unchanged. Complete historical equivalence would require stronger record-level comparison against the original dataset.

**Final evidence classification:**

| Requirement | Verification |
|---|---|
| Functional correctness | 11/11 passed |
| Failure atomicity | 10/10 passed |
| Official concurrency scenarios | 4/4 passed |
| Last-unit purchase safety | 25/25 passed |
| Initial flash-sale benchmark | 1.89 seconds |
| Combined concurrency attempts | 475 |
| Combined successful purchases | 85 |
| Combined clean refusals | 390 |
| Combined unhandled errors | 0 |
| Independent purchase audit | 12/12 passed |
| Original fixture cleanup | PASS |
| Supplementary fixture cleanup | PASS |
| Historical baseline reconciliation | PASS |

**Evidence:** `evidence/27_retained_audit_cleanup.txt`

**Final decision:** Accepted, implemented and technically verified for the tested single-product purchase workflow.

**Residual risks:** Production performance, repeated flash-sale benchmarks, alternative locking performance, idempotency, multi-product transactions and direct writes bypassing the purchase function remain unverified.

General inventory auditability for restocks and corrections will be addressed in Stage 05.

**Closure status:** Database implementation and verification complete. ADR-002 finalized. Repository documentation and Git integration must be completed before closing Stage 03 administratively.

#### V028 — Reporting profile and date anomaly discovery

**Date:** 2026-11-26

**Stage:** 04.1 — Reporting requirements and data profiling.

**Objective:** Reconfirm spending eligibility, customer coverage, reporting date boundaries and the existing performance configuration before implementing customer spending reports.

**Measured evidence:**

- Total orders: 159,384.
- Eligible orders: 111,351.
- Eligible recorded order value: 339,609,366.03.
- Attributed eligible orders: 111,207.
- Attributed eligible value: 339,220,585.14.
- Unattributed eligible orders: 144.
- Unattributed eligible value: 388,780.89.
- Total customers: 40,420.
- Customers with eligible orders: 37,900.
- Customers without eligible orders: 2,520.
- Earliest order: 2025-08-02 05:00:54.
- Latest order: 2027-08-20 19:30:00.
- Missing order dates: 0.
- Future-dated orders as of 2026-11-26: 15.
- Existing reporting-related indexes: three primary-key B-tree indexes.
- Additional reporting indexes: none on customers, orders or order_items.
- Reporting profile exit code: 0.

**Derived evidence:**

- Orders recorded through August 2026: 159,360.
- Orders recorded after August 2026: 24.
- Percentage of orders recorded through August 2026: approximately 99.985%.
- Eligible orders after August 2026: 17.
- Eligible recorded value after August 2026: 43,748.26.
- Future-dated eligible orders: 12.
- Future-dated eligible recorded value: 35,600.61.

All monthly order counts and eligible recorded values reconcile to the unrestricted historical totals.

**New finding:** The order distribution falls from 36,357 orders in August 2026 to five orders in September 2026. Fifteen orders occur after the execution date.

**Interpretation:** August 2026 may represent the end of the main dataset period. This is an inference, not a confirmed business cutoff.

**Business impact:** Automatically anchoring trailing twelve-month reports to the maximum recorded order date could produce a misleading reporting period. Future-dated completed orders may also inflate current customer spending.

**Proposed treatment:** Preserve original records, introduce a configurable reporting date and separately identify transactions outside the reporting cutoff.

**Counterargument:** Future-dated transactions may represent legitimate scheduled activity, and the sparse distribution after August 2026 may reflect dataset coverage rather than corruption. Exclusion from an as-of report must not be interpreted as proof that a record is invalid.

**Performance observation:** Individual profiling queries completed between 4.178 ms and 130.430 ms. These measurements establish the current diagnostic environment but do not constitute final reporting benchmarks.

**Evidence:**

- sql/04_reporting/01_reporting_profile.sql
- evidence/28_reporting_profile.txt

**Status:** Reporting profile verified. Date anomaly investigation and reporting policy decisions pending.

#### V029 — Reporting date anomaly investigation

**Date:** 2026-11-26

**Stage:** 04.1B — Reporting date investigation.

**Objective:** Establish the financial, relational and reporting implications of suspicious order dates before implementing the customer reporting layer.

**Investigation parameters:**

- Reporting date: 2026-11-26.
- Reporting cutoff exclusive: 2026-11-27 00:00:00.
- Provisional main dataset period end: 2026-08-31.

**Measured evidence:**

- Orders investigated: 24.
- Valid customer references: 24.
- Detected customer registration-date conflicts: 0.
- Orders without items: 0.
- Orders with missing item prices: 0.
- Orders with financial discrepancies: 0.
- Orders with quantities exceeding 10: 0.
- Future-dated orders: 15.
- Future-dated eligible orders: 12.
- Future-dated eligible recorded value: 35,600.61.
- Future-dated attributed eligible value: 35,600.61.
- Future-dated unattributed eligible value: 0.00.
- Distinct affected existing customers: 12.

**Reporting sensitivity:**

| Scenario | Eligible orders | Eligible value | Attributed value |
|---|---:|---:|---:|
| S1 — Unrestricted | 111351 | 339609366.03 | 339220585.14 |
| S2 — As-of history | 111339 | 339573765.42 | 339184984.53 |
| S3 — Current month plus previous eleven | 102592 | 313335526.79 | 313014045.03 |
| S4 — Twelve completed months | 105621 | 322057238.99 | 321720802.05 |
| S5 — Main dataset period | 109846 | 335023539.89 | 334634759.00 |
| S6 — Latest order month | 17 | 43748.26 | 43748.26 |

**Ranking sensitivity:**

- Unrestricted top-100 customers: 100.
- As-of top-100 customers: 100.
- Retained top-100 membership: 100.
- Customers leaving: 0.
- Customers entering: 0.
- Customers with changed spending: 12.
- Excluded attributed value: 35,600.61.

Top-100 membership remained unchanged. Exact internal ranking positions were not compared.

**Performance observations:**

| Investigation query | Duration |
|---|---:|
| Individual date anomaly investigation | 39.018 ms |
| Future-dated status distribution | 6.309 ms |
| Future-dated eligible attribution | 8.644 ms |
| Six-scenario reporting sensitivity | 1639.856 ms |
| Top-100 ranking sensitivity | 182.575 ms |

These measurements describe diagnostic queries rather than final reporting benchmarks.

**Interpretation:** Suspicious dates are not accompanied by the tested financial or relational inconsistencies. Automatic date correction is therefore unsupported.

Using the latest recorded order as the reporting anchor creates a materially different reporting period and could mislead the client.

**Proposed decisions:**

- D025: Use recorded order totals as the spending measure.
- D026: Use an explicit reporting date and twelve calendar-month buckets, including the current partial month.
- D027: Preserve future-dated orders, exclude them from as-of reports and flag them separately.

**Counterargument:** Future-dated orders may be legitimate, and the observed monthly distribution may reflect the supplied dataset's coverage rather than actual trading activity.

Historical as-of reports also use currently stored statuses because status-transition history is unavailable.

**Evidence:**

- sql/04_reporting/02_reporting_date_investigation.sql
- evidence/29_reporting_date_investigation.txt

**Verification:** Read-only transaction rolled back successfully. Exit code 0.

**Status:** Investigation complete. Reporting policy acceptance pending.


## D025 — Financial reporting measure

**Date:** 2026-11-26

**Status:** Accepted.

**Decision:** Use orders.total_amount as the primary measure of recorded spending on eligible orders.

**Reasoning:** Recorded checkout totals provide a consistent order-level measure without requiring reconstruction from historical order items containing missing prices and suspicious quantities.

**Measured evidence:**

- Total orders: 159,384.
- Financially comparable orders: 159,237.
- Comparable orders with matching values: 156,958.
- Comparable orders with inconsistent values: 2,279.
- Comparable-order mismatch rate: approximately 1.431%.
- Orders with incomplete item prices: 147.
- Order items with missing unit prices: 148.
- Extreme-quantity order items: 6.
- Combined extreme-quantity line value: 3,073,441.59.
- Absolute discrepancies across comparable inconsistent orders: 3,760,997.98.
- Absolute discrepancies attributable to the five comparable extreme-quantity orders: 1,929,389.97, representing approximately 51.30% of the comparable discrepancy value.

The sixth extreme-quantity order contains an incomplete item-price calculation and is excluded from the comparable discrepancy concentration.

**Strongest counterargument:** Recorded order totals may themselves be incorrect. Discounts, taxes, shipping charges or source-data errors could explain some differences, but these explanations remain unverified.

**Safeguard:** Preserve financial anomalies, report reconciliation information separately and describe the measure as recorded eligible order spending rather than verified payments.

**Cost if wrong:** Customer spending and rankings may be misstated. The measured financial discrepancy is not a confirmed loss or an upper bound on possible financial error.

**Revisit if:** Verified payment records, financial adjustments or authoritative transaction totals become available.

---

## D026 — Reporting date and trailing twelve-month convention

**Date:** 2026-11-26

**Status:** Accepted.

**Decision:** Use an explicit as-of date and twelve calendar-month buckets, including the as-of month and the preceding eleven months.

**Reporting boundaries:**

- Start inclusive: first day of the month eleven months before the as-of month.
- End exclusive: midnight immediately following the as-of date.
- Exactly twelve calendar-month buckets.
- Label the as-of month as partial when the reporting date is not the final calendar day of that month.
- Preserve a separate warning concerning unverified source-data coverage.

**Demonstration dates:**

- Primary lab demonstration: 2026-08-31.
- Operational sensitivity comparison: 2026-11-26.

The primary demonstration date is an engineering assumption supported by the concentration of 99.985% of orders through August 2026. It is not a confirmed business reporting cutoff.

**Reasoning:** This convention includes the complete as-of day, supports month-end and mid-month reporting, and avoids deriving the reporting anchor from suspicious maximum order dates.

**Strongest counterargument:** A partial current month can appear to show declining business activity when compared with completed months.

**Safeguard:** Display the reporting date, period boundaries, partial-month indicator and source-data coverage warning.

**Residual limitation:** Historical as-of reports use currently stored order statuses. They cannot reconstruct the exact historical status of an order without status-transition history.

**Revisit if:** Nana or Adwoa requires completed calendar months only or provides an authoritative reporting calendar.

---

## D027 — Orders beyond the reporting cutoff

**Date:** 2026-11-26

**Status:** Accepted.

**Decision:** Preserve original orders, exclude orders beyond the selected reporting cutoff from as-of reports and expose excluded records separately.

**Measured evidence:**

As of 2026-11-26:

- Future-dated orders: 15.
- Future-dated eligible orders: 12.
- Eligible recorded value excluded: 35,600.61.
- Affected existing customers: 12.
- Top-100 membership changes: 0.

As of 2026-08-31:

- Orders beyond the reporting cutoff: 24.
- Eligible orders beyond the reporting cutoff: 17.
- Eligible recorded value excluded: 43,748.26.

All 24 investigated orders had valid customer references, complete item prices, matching recorded and calculated financial values and no detected registration-date conflicts.

**Strongest counterargument:** Some future-dated records may represent legitimate scheduled transactions.

**Safeguard:** Exclusion is a reporting boundary, not a declaration that a record is invalid. Preserve the original dates and expose exceptions without modifying historical data.

**Cost if wrong:** Legitimate future activity may be omitted from the current report. The measured November exclusion represents approximately 0.01049% of unrestricted attributed eligible spending.

**Revisit if:** The business provides verified order dates, booking semantics or a separate forward-looking reporting requirement.

**Evidence for D025–D027:**

- evidence/04_business_impact.txt
- evidence/06_exception_investigation.txt
- evidence/28_reporting_profile.txt
- evidence/29_reporting_date_investigation.txt

**Approval classification:** Engineering decisions supported by measured evidence; client confirmation remains outstanding.

#### V031 — Reporting foundation verification

**Date:** 2026-11-26

**Stage:** 04.2 — Status normalization and reusable eligibility layer.

**Decisions implemented:** D016, D025, D026 (as-of cutoff component) and D027.

**Verification results:**

- Normalized order records: 159,384.
- Distinct normalized order identifiers: 159,384.
- Raw status variations: 15.
- Canonical status categories present: 5.
- Unrestricted eligible orders: 111,351.
- Unrestricted eligible recorded value: 339,609,366.03.
- Automated verification groups: 14/14 passed.
- Individual PASS notices: 17.
- Historical table counts reconciled: 6/6.
- Historical baseline records: 822,832.
- Verification exit code: 0.

**As-of reporting results:**

| Measurement | 2026-08-31 | 2026-11-26 |
|---|---:|---:|
| Eligible orders | 111334 | 111339 |
| Eligible value | 339565617.77 | 339573765.42 |
| Attributed orders | 111190 | 111195 |
| Attributed value | 339176836.88 | 339184984.53 |
| Unattributed orders | 144 | 144 |
| Unattributed value | 388780.89 | 388780.89 |
| Customers with eligible orders | 37900 | 37900 |
| Excluded eligible orders | 17 | 12 |
| Excluded eligible value | 43748.26 | 35600.61 |

**Engineering reasoning:** Centralizing status normalization and eligibility prevents inconsistent spending definitions across downstream reports. Separating status eligibility from date filtering allows unrestricted reconciliation and parameterized historical reporting.

**Counterargument:** Additional reporting views and functions introduce abstraction and maintenance overhead. Repeated normalization may also increase query execution costs.

**Response:** Ordinary views avoid persistent duplicated data and refresh requirements. Actual reporting execution plans will determine whether additional optimization is necessary.

**Performance observation:** Individual reporting foundation queries completed between 10.459 ms and 503.493 ms. The complete automated assertion block took 2161.201 ms.

**Evidence:**

- sql/04_reporting/03_reporting_foundation.sql
- tests/08_reporting_foundation_test.sql
- evidence/31_reporting_foundation_verification.txt

**Limitations:** Original-field comparison verifies the normalized view against the current source table, not complete equivalence with the original CSV files. Synthetic unknown-status and missing-date cases have not been exhaustively tested. NULL date arguments return no rows.

**Status:** Reporting foundation deployed and verified. Monthly window construction, completeness indicators and downstream customer reports remain pending.

## D028 — Complete customer account coverage

**Date:** 2026-11-26

**Status:** Implemented and verified.

**Decision:** Return one record per existing customer account, including customers without eligible orders. Use zero spending and zero order counts for customers without qualifying purchases, while retaining NULL first and last order dates.

**Reasoning:** The client requires spending information for every customer. Excluding customers without eligible orders would produce an incomplete account-level report.

**Alternatives considered:**

- Return only customers with eligible orders.
- Include unidentified customer identifiers from historical orders as artificial customer accounts.

**Why rejected:** The first alternative excludes legitimate customer accounts. The second introduces customer identities that cannot be verified.

**Measured evidence:**

- Existing customers: 40,420.
- Customers with eligible orders: 37,900.
- Customers without eligible orders: 2,520.
- Customers registered after the headline reporting date: 0.
- Customers with missing registration dates: 0.

**Strongest counterargument:** Including every customer increases reporting output and may introduce accounts that did not exist at a historical reporting date.

**Response:** Complete account coverage is an explicit reporting requirement. The current dataset contains no customers registered after the headline date. Historical population reconstruction remains outside the current reporting contract.

**Residual risk:** Current customer records and current order statuses cannot reconstruct the exact historical business state.

---

## V033 — Customer spending summary verification

**Date:** 2026-11-26

**Status:** Passed.

**Results:**

- Automated verification groups: 12/12.
- Individual PASS notices: 20.
- Customer-date records independently reconciled: 80,840.
- Historical table counts reconciled: 6/6.
- Verification exit code: 0.

| Measurement | 2026-08-31 | 2026-11-26 |
|---|---:|---:|
| Customer rows | 40420 | 40420 |
| Attributed spending | 339176836.88 | 339184984.53 |
| Attributed orders | 111190 | 111195 |
| Customers with eligible orders | 37900 | 37900 |
| Customers without eligible orders | 2520 | 2520 |
| Unattributed orders | 144 | 144 |
| Unattributed value | 388780.89 | 388780.89 |

The independent verification calculated spending directly from the original orders and customers tables using a different query structure. Every reported customer record matched the independently calculated result.

**Evidence:** evidence/33_customer_summary_verification.txt

---

## V034 — Preliminary customer reporting performance

**Date:** 2026-11-26

**Environment:** PostgreSQL 18.7, work_mem 4 MB, shared_buffers 128 MB, existing primary-key indexes only on the reporting tables.

| Scenario | Execution time |
|---|---:|
| Customer summary, run 1 | 209.979 ms |
| Customer summary, run 2 | 270.880 ms |
| Financial reconciliation | 196.383 ms |

**Customer summary mean and median:** 240.4295 ms.

**Observations:**

- Both customer summary executions returned 40,420 records.
- The outer planner estimated 1,000 records, underestimating actual cardinality by a factor of 40.42.
- Temporary block reads and writes occurred.
- The financial reconciliation recorded 223,963 shared-buffer hits.
- Function Scan nodes concealed the internal query execution strategies.

**Decision:** Investigate underlying query plans before adding indexes, increasing memory allocation or introducing materialized reporting objects.

**Limitations:** Two executions are insufficient for reliable percentile or production performance claims. Measurements exclude full client-side result transfer and rendering. Cache state was not independently controlled.

**Evidence:** evidence/34_customer_summary_baseline.txt


## V035 — Customer reporting execution-plan investigation

**Date:** 2026-11-26

**Status:** Investigation completed successfully.

**Evidence:** evidence/35_customer_summary_plan_investigation.txt

### Measured results

| Scenario | Execution time |
|---|---:|
| Extracted customer summary query | 197.864 ms |
| Extracted financial reconciliation query | 247.493 ms |
| Eligibility function | 111.522 ms |
| Direct eligibility view | 110.929 ms |

### Findings

- The extracted customer summary uses a HashAggregate followed by a Hash Left Join.
- The summary returns 40,420 customer records.
- The aggregation produces 38,036 distinct customer identifiers, including 136 unidentified historical customer references.
- The eligibility function estimates 1,000 rows but returns 111,334 rows.
- The aggregation estimates 200 groups but produces 38,036 groups.
- The direct eligibility view estimates 790 rows but returns 111,334 rows.
- The HashAggregate uses five batches, 8,257 kB memory and 3,368 kB disk.
- The extracted financial reconciliation uses a Nested Loop Left Join with 111,334 customer index searches.
- The customer index scan records 222,669 shared-buffer hits and zero heap fetches.
- The eligibility function writes 723 temporary blocks.
- The direct eligibility view reports no temporary-file activity.
- PostgreSQL block size is 8,192 bytes.

### Interpretation

The investigation identifies inaccurate cardinality estimates, repeated customer index lookups and intermediate-result materialization as optimization opportunities.

Direct view access eliminates observed temporary-file activity in this execution but does not establish a meaningful execution-time improvement.

### Decision

Retain the verified reporting architecture while completing functional requirements. Investigate function inlining, eligibility predicate estimation, set-based reconciliation, working-memory requirements and indexing during Stage 06.

### Limitations

Extracted query plans may differ from plans generated internally by the deployed functions. Single-run comparisons are insufficient to establish reliable performance improvements. Buffer hits represent accesses, not distinct pages or physical disk reads.

Verification exit code: 0.

---

## V036 — Monthly reporting density investigation

**Date:** 2026-11-26

**Status:** Investigation completed successfully.

**Evidence:** evidence/36_monthly_reporting_density.txt

### Measured results

| Measurement | 2026-08-31 | 2026-11-26 |
|---|---:|---:|
| Customers | 40420 | 40420 |
| Dense rows | 485040 | 485040 |
| Sparse rows | 92677 | 85681 |
| Zero-order months | 392363 | 399359 |
| Zero-order month percentage | 80.89% | 82.34% |
| Customers with window orders | 37816 | 37285 |
| Attributed orders | 109702 | 102463 |
| Attributed spending | 334634759.00 | 313014045.03 |

### Additional observations

- The headline dense report contains approximately 5.23 times as many rows as the sparse report.
- 2,604 customers have no eligible orders within the headline twelve-month window.
- 82.99% of customers have eligible orders in three months or fewer.
- The maximum observed number of active months is nine.
- All monthly financial totals reconcile to the previously measured reporting-date sensitivity results.

### Interpretation

Dense reporting provides explicit monthly coverage for every customer but increases output volume substantially.

Sparse reporting reduces output volume but requires consumers to reconstruct missing customer-month combinations.

### Business observation

Recorded monthly attributed spending increases from 5,313,423.07 in September 2025 to 76,665,230.57 in August 2026. The increase is associated with higher recorded order volume.

This observation describes the supplied dataset and is not independently verified business growth.

### Limitations

The investigation measures output density, not the execution time of the completed dense report. Actual result-transfer overhead remains unmeasured. Zero-order months indicate an absence of qualifying records, not independently verified absence of business activity.

D029 remains pending the decision owner's acceptance.

Verification exit code: 0.


## D029 — Dense monthly customer reporting

**Date:** 2026-11-26

**Status:** Accepted; implementation and verification pending.

**Decision:** Use dense long-format monthly reporting as the canonical reporting interface. Aggregate eligible orders to sparse customer-month grain before constructing the complete customer-month grid. Provide an optional wide-format export.

**Reasoning:** Explicit monthly records provide complete customer coverage, reduce downstream gap-filling errors and simplify chronological reporting and monthly running totals.

**Measured evidence:**

| Measurement | Headline | Sensitivity |
|---|---:|---:|
| Customer population | 40420 | 40420 |
| Dense monthly rows | 485040 | 485040 |
| Active customer-months | 92677 | 85681 |
| Zero-order months | 392363 | 399359 |
| Zero-order percentage | 80.89% | 82.34% |
| Attributed eligible orders | 109702 | 102463 |
| Attributed spending | 334634759.00 | 313014045.03 |

**Alternatives considered:**

- Sparse reporting only: smaller output but transfers gap-filling responsibility to consumers.
- Wide-format reporting only: convenient for spreadsheets but less flexible for chronological calculations and downstream analysis.
- Materialized dense reporting: potentially faster repeated reads but introduces storage, refresh and freshness costs.

**Strongest counterargument:** More than 80% of the dense output contains no eligible orders. Generating and transferring these records repeatedly may impose unnecessary computational and consumption costs.

**Response:** Aggregate before expanding the grid. Retain a reusable sparse layer and offer a wide-format export. Measure actual database execution and result-transfer costs before introducing materialization.

**Cost if wrong:** Slower reports, increased temporary-file activity, larger exports and potentially misleading interpretation of zero-order months.

**Safeguards:**

- Include monthly eligible order counts.
- Label partial calendar months.
- Retain source-data coverage warnings.
- Do not interpret zero-order months as independently verified customer inactivity.
- Keep customer-level ranking independent of expanded monthly records.
- Reconcile dense and sparse reporting totals.

**Revisit conditions:** Performance target missed, significant customer or order-volume growth, downstream consumption limitations, or revised client requirements. Evaluate scalability at ten times the current customer population and order volume.

**Evidence:** evidence/35_customer_summary_plan_investigation.txt and evidence/36_monthly_reporting_density.txt.

**Outstanding measurements:** Dense report execution time, full-result transfer time, wide-format export performance and scalability.

## V038 — Monthly reporting verification and initial failure

**Date:** 2026-11-26

**Status:** Aggregate reconciliation successful; automated verification pending correction.

**Evidence:** evidence/38a_monthly_reporting_initial_failure.txt

### Observed results

Both reporting dates produce 485040 rows, 40420 customers and twelve reporting months.

The headline report reconciles to 109702 attributed eligible orders and recorded spending of 334634759.00.

The sensitivity report reconciles to 102463 attributed eligible orders and recorded spending of 313014045.03.

The headline report has no partial-month rows. The sensitivity report has 40420 partial-month rows.

The wide-format sample returns the expected chronological monthly columns.

### Defect

The automated assertion block fails with a PL/pgSQL syntax error at the CASE expression in the M05 partial-month assertion.

Initial execution exit code: 3.

### Root cause

The CASE expression was not enclosed in parentheses within the IF condition, allowing the PL/pgSQL parser to misinterpret its internal THEN token.

### Corrective action

Enclose the complete CASE expression in parentheses and rerun the verification script.

Preserve the initial failed execution as break/fix evidence.

### Residual verification requirement

The displayed aggregates reconcile, but none of the automated assertions can be counted as passed until the corrected DO block executes successfully.

---

## V039 — Monthly reporting performance baseline

**Date:** 2026-11-26

**Status:** Preliminary performance measurements completed.

**Evidence:** evidence/39_monthly_reporting_baseline.txt

### Environment

- PostgreSQL 18.7
- work_mem: 4 MB
- shared_buffers: 128 MB
- hash_mem_multiplier: 2
- max_parallel_workers_per_gather: 2
- Block size: 8192 bytes

### Results

| Scenario | Rows | Execution time (ms) |
|---|---:|---:|
| Sparse headline | 92677 | 333.709 |
| Dense headline, first run | 485040 | 677.892 |
| Dense headline, second run | 485040 | 634.192 |
| Wide headline | 40420 | 980.055 |
| Dense sensitivity | 485040 | 660.498 |
| Single customer | 12 | 737.480 |

Mean headline dense execution time: 656.042 ms.

### Findings

- Both headline dense executions complete in less than one second.
- Dense reporting generates approximately 5.23 times the sparse output rows at approximately 1.97 times the measured execution time.
- All reporting functions appear as Function Scan nodes.
- Full dense output is estimated at 1000 rows but returns 485040 rows.
- The single-customer query generates the full dense report and discards 485028 rows.
- The wide-format function reports the highest cumulative temporary block-access volume.
- No persistent configuration changes or reporting indexes were introduced during this measurement.

### Interpretation

The current dense reporting architecture has promising preliminary performance at the supplied dataset size.

Selective customer access remains inefficient and requires investigation.

### Limitations

Measurements are based on one or two executions per scenario. They do not establish p95 latency, cold-cache performance, concurrent workload performance or ten-times-growth scalability.

Verification exit code: 0.

---

## V040 — Monthly reporting export measurement

**Date:** 2026-11-26

**Status:** Completed successfully.

**Evidence:** evidence/40_monthly_export_measurement.txt

| Format | Data rows | CSV bytes | Wall time (s) |
|---|---:|---:|---:|
| Sparse | 92677 | 3557871 | 0.480 |
| Dense | 485040 | 17475947 | 0.981 |
| Wide | 40420 | 3110942 | 1.027 |

All CSV line counts reconcile to the expected data rows plus one header line.

The wide export reduces file size by approximately 82.20% compared with the dense export.

The measurement includes database execution, CSV serialization, Docker client communication and local file writing.

Temporary CSV exports were removed automatically after measurement.

### Decision

Retain D029. Do not introduce materialization without measured justification.

### Limitations

One export was measured per format. Production network transfer, spreadsheet loading, dashboard rendering and concurrent workload effects remain unmeasured.

Verification exit code: 0.

### Second verification attempt — Performance failure

**Date:** 2026-11-26

**Evidence:** evidence/38c_monthly_reporting_timeout.txt

The M05 syntax correction succeeded. Assertions M01 through M06 passed for the headline reporting date.

M07 exceeded the 120-second statement timeout. The script terminated with exit code 3.

A concurrent pg_stat_activity inspection showed the verification session active after 81.98 seconds, with no reported wait event and no blocking transactions.

The exact M07 execution plan was not captured. However, earlier reporting plans demonstrated substantial function cardinality underestimation, making inefficient join planning a credible explanation.

**Corrective action:** Replace join-based comparisons in M06, M07 and M09 with bidirectional EXCEPT ALL comparisons. Independently construct the expected dense report using zero-valued customer-month contributions, original eligible orders, UNION ALL and aggregation.

**Reasoning:** Preserve complete record-level verification while avoiding the problematic three-way join. Improve duplicate detection and reduce dependency on the reporting functions being tested.

**Verification status:** Revision 3 execution pending.

**Data protection:** The failed verification ran inside a read-only transaction. No historical data changes were introduced.

### V038 — Final verification outcome

**Date:** 2026-11-26

**Status:** Passed — revision 3.

**Evidence:** evidence/38_monthly_reporting_verification.txt

All 21 individual assertions across 12 verification groups passed.

Both the headline and sensitivity reporting dates were successfully verified.

### Corrective implementation

- Replaced expensive join-based comparisons with bidirectional EXCEPT ALL.
- Independently constructed expected dense records from original eligible orders and zero-valued customer-month contributions.
- Verified complete sparse, dense and wide-format results.
- Preserved duplicate detection and financial reconciliation.
- Retained the 120-second statement timeout and read-only transaction.

### Measured results

- Automated assertion block: 13318.573 ms.
- Sum of displayed statement timings: 16702.209 ms.
- Previous verification attempt: timed out at 120 seconds.
- Final transaction: ROLLBACK.
- Exit code: 0.

### Conclusion

The monthly reporting implementation satisfies the tested correctness requirements at the supplied dataset size.

D029 is retained. No materialized reporting objects are currently justified by the preliminary performance measurements.

### Residual limitations

The exact execution plan responsible for the earlier timeout was not captured. Historical baseline counts reconcile, but count equality alone does not establish complete source-data equality.

Concurrent workload performance, growth scalability and final performance optimization remain outstanding.

## V041 — Running total investigation

**Date:** 2026-11-26

**Status:** Passed.

**Evidence:** evidence/41_running_total_investigation.txt

**Script:** sql/04_reporting/10_running_total_investigation.sql

### Purpose

Determine the financial and customer-level consequences of choosing window-based versus lifetime cumulative spending.

Investigate transaction timestamp ties before implementing deterministic running totals.

### Measured results

| Measurement | Headline | Sensitivity |
|---|---:|---:|
| Customers | 40420 | 40420 |
| Customers with opening balances | 1461 | 7856 |
| Opening-only customers | 84 | 615 |
| Opening orders | 1488 | 8732 |
| Opening spending | 4542077.88 | 26170939.50 |
| Window orders | 109702 | 102463 |
| Window spending | 334634759.00 | 313014045.03 |
| Lifetime spending | 339176836.88 | 339184984.53 |

All measured financial totals reconcile to the previously verified reporting results.

### Customer-level observation

Customer 100001 has no opening spending, four eligible orders and final cumulative spending of 122.07.

Zero-order months correctly retain the preceding cumulative balance in the investigation query.

### Timestamp investigation

No duplicate customer-order timestamp groups were found among attributed eligible orders through the headline cutoff.

A unique order identifier remains appropriate as a defensive tie-breaker for transaction-level cumulative calculations.

### Business implications

Window-only spending excludes historical balances for 1461 headline customers and 7856 sensitivity customers.

Of these, 84 headline customers and 615 sensitivity customers have historical eligible purchases but no purchases within their respective reporting windows.

A zero window balance must not be interpreted as evidence that a customer has never purchased.

### Execution

Opening balance investigation: 385.275 ms.

Customer sample: 608.023 ms.

Timestamp investigation: 151.684 ms.

Sum of displayed statement timings: 1146.655 ms.

Transaction outcome: ROLLBACK.

Exit code: 0.

### Limitations

The investigation verifies aggregate opening balances and one customer-level cumulative example. It does not yet verify a deployed running-total reporting function.

Timestamp ties were investigated only through the headline cutoff. Synthetic tie tests remain outstanding.

### Decision status

D030 pending final decision on accumulation scope and reporting grain.

## D030 — Running spending semantics and reporting grain

**Date:** 2026-11-26

**Status:** Accepted design; implementation and verification pending.

**Related decisions:** D016, D019, D025, D026, D027, D028, D029.

**Evidence:** E041, E041a.

### Context

The engagement requires a running per-customer total but does not define its accumulation starting point or reporting grain.

The official rubric requires judgement calls to be named, defended and supported by evidence, including the cost to Kloud Kart if the decision is wrong.

### Decision

Provide both window cumulative spending and cumulative spending since the beginning of the available order history.

Expose these measures through separate monthly and transaction-level reporting functions.

The monthly report includes every customer and twelve calendar months, including months without eligible orders.

The transaction report includes one row per attributed eligible order through the reporting cutoff.

Use chronological ordering by order_date and order_id with an explicit ROWS window frame.

For transactions preceding the reporting window, window cumulative spending is NULL because the measure is not applicable.

### Evidence and reasoning

At the headline reporting date, 1461 customers have opening balances representing 1488 orders and GHS 4542077.88 in recorded spending.

At the sensitivity date, 7856 customers have opening balances representing 8732 orders and GHS 26170939.50.

There are 84 headline customers and 615 sensitivity customers with historical eligible orders but no orders within the respective reporting windows.

E041a establishes that 40388 of 40420 customers registered before the earliest observed order. Customer registration records begin in July 2022, while observed order records begin in August 2025.

Consequently, the historical cumulative measure is named cumulative_since_extract_start rather than lifetime spending. Earlier purchases or missing transactions cannot be independently established.

Among 111190 headline attributed eligible orders, 660 records differ between day-level accumulation strategies, affecting 651 customers.

A further comparison found 688 differences between calendar-day and identifier ordering versus timestamp and identifier ordering.

No exact customer-timestamp ties were observed at either reporting cutoff. The unique order identifier remains a defensive tie-breaker.

### Alternatives considered

**Window cumulative spending only:** Simpler, but excludes historical balances and may lead to incorrect interpretations of customers with no recent purchases.

**Recorded-history cumulative spending only:** Preserves available historical spending but does not directly show accumulation within the reporting period.

**Monthly interface only:** Lower maintenance cost and likely sufficient for some Monday reporting requirements. However, it cannot expose the progression of individual purchases.

**Transaction interface only:** Provides detailed accumulation but omits explicit zero-order months and customers without eligible orders.

### Consequences

The selected design supports both reporting-period analysis and detailed customer spending history without combining incompatible reporting grains.

It introduces additional reporting functions, output columns, execution costs and verification responsibilities.

The marginal computational cost has not yet been measured.

### Cost to Nana if wrong

Incorrect accumulation boundaries could omit or double-count historical spending.

Misinterpreting a zero window balance as no purchase history could lead to incorrect customer segmentation.

Unnecessary reporting interfaces could increase maintenance costs and database workload.

Expensive cumulative queries could compete with the website and flash-sale transactions on the existing server.

### Conditions for revisiting

Revisit if earlier order history becomes available, the analyst requires only one interface, eligibility rules change, measured reporting performance exceeds the agreed budget, or transaction growth makes repeated cumulative calculations expensive.

### Residual limitations

The available extract cannot establish complete customer purchasing history or actual payments received.

The reporting population uses current customer records.

The deterministic tie-breaker does not establish the real chronological sequence of simultaneous transactions.

Synthetic timestamp-tie verification and performance measurements remain outstanding.

The top-100 ranking period is a separate decision under D031.

## V041a — Supplementary running-total investigation

**Date:** 2026-11-26

**Status:** Passed.

**Script:** sql/04_reporting/11_running_total_supplement.sql

**Evidence:** evidence/41a_running_total_supplement.txt

### Observed history

- Total orders: 159384.
- Earliest order: 2025-08-02 05:00:54.
- Earliest eligible order: 2025-08-02 06:13:51.
- Latest recorded order: 2027-08-20 19:30:00.
- Earliest customer registration: 2022-07-29 06:09:00.
- Customers registered before first observed order: 40388 of 40420 (99.92%).
- Customers registered before August 2025: 40353.
- Missing registration dates: 0.

### Window calculation comparison

Headline attributed eligible orders: 111190.

Sensitivity attributed eligible orders: 111195.

Both reporting dates produced:

- 660 day-level accumulation differences.
- 0.5936% differing records.
- 651 affected customers.
- 688 differences between day/identifier and timestamp/identifier ordering.
- Zero exact customer-timestamp ties.

### Execution results

| Investigation | Runtime (ms) |
|---|---:|
| Order history coverage | 71.903 |
| Registration coverage | 34.813 |
| Window calculation comparison | 761.166 |
| Exact timestamp ties | 243.543 |

Transaction outcome: ROLLBACK.

Exit code: 0.

### Interpretation

Registration history predates the observed order history for nearly the entire customer population.

This establishes a coverage limitation, not proof of missing historical transactions.

The observed window calculation differences justify explicit chronological ordering and ROWS frame semantics.

### Decision impact

D030 retains both cumulative measures and both reporting grains.

The historical cumulative measure is named cumulative_since_extract_start.

The implementation will use order_date and order_id for deterministic transaction ordering.


## V042a — Running spending functional inspection

**Date:** 2026-11-26

**Status:** Initial functional inspection passed.

**Evidence:** evidence/42a_running_spending_inspection.txt

**Related decision:** D030.

### Results

Both monthly and transaction-level running spending functions returned the expected results.

The final monthly balances reconcile across 40420 customers:

- Opening spending: GHS 4542077.88.
- Window spending: GHS 334634759.00.
- Cumulative since extract start: GHS 339176836.88.
- Reconciliation difference: GHS 0.00.

The transaction report returned 111190 attributed eligible orders across 37900 customers, comprising 1488 opening orders and 109702 window orders.

No pre-window transaction had an invalid non-NULL window cumulative balance.

### Customer-level evidence

| Customer | Opening | Window | Since extract start |
|---|---:|---:|---:|
| 100001 | 0.00 | 122.07 | 122.07 |
| 100014 | 28870.72 | 315.85 | 29186.57 |
| 101702 | 696.67 | 0.00 | 696.67 |

Customer 100014 demonstrates the significance of historical opening balances. Approximately 98.92% of this customer's recorded spending precedes the reporting window.

Customer 101702 demonstrates that zero window spending does not establish an absence of earlier purchases.

### Preliminary performance

| Inspection | Runtime (ms) |
|---|---:|
| Monthly sample | 1273.413 |
| Transaction sample | 319.259 |
| Opening balance sample | 1619.475 |
| Opening-only sample | 1398.200 |
| Monthly reconciliation | 1413.915 |
| Transaction reconciliation | 375.133 |

Combined inspection query timings: 6399.395 ms.

Transaction outcome: ROLLBACK.

Exit code: 0.

### Conclusion

D030 is implemented and has passed initial functional inspection.

Complete record-level verification and controlled performance measurements remain outstanding.

The E042 deployment log has not been separately reviewed, although successful execution of both functions establishes that they are available in the database.

## V043 — Comprehensive running spending verification

**Date:** 2026-11-26

**Status:** Passed.

**Decision:** D030.

**Script:** tests/11_customer_running_spending_test.sql

**Evidence:** evidence/43_running_spending_verification.txt

### Verification results

- Check groups: 13.
- Expected successful assertions: 22.
- Actual successful assertions: 22.
- Failed assertions: 0.
- Verification block runtime: 22816.541 ms.
- Statement timeout: 120 seconds.
- Transaction outcome: ROLLBACK.
- Exit code: 0.

### Record-level verification

Independent raw-order calculations were compared against both deployed reporting functions using bidirectional EXCEPT ALL comparisons.

The monthly comparisons covered 970080 records across two reporting dates.

The transaction comparisons covered 222385 records across two reporting dates.

Total report records compared: 1192465.

All comparisons passed without detected differences.

### Financial reconciliation

| Measurement | 2026-08-31 | 2026-11-26 |
|---|---:|---:|
| Opening spending | 4542077.88 | 26170939.50 |
| Window spending | 334634759.00 | 313014045.03 |
| Recorded cumulative spending | 339176836.88 | 339184984.53 |
| Attributed orders | 111190 | 111195 |
| Opening-only customers | 84 | 615 |

All expected financial balances, population counts and intermediate cumulative calculations passed verification.

### Edge cases

Empty historical windows, NULL reporting dates, inactive customers, opening-only customers and pre-window NULL semantics passed.

The synthetic timestamp-tie expression correctly accumulated transactions using timestamp and order-ID ordering.

All six historical baseline table counts reconciled.

### Engineering significance

Independent calculations and duplicate-sensitive set comparisons provide stronger evidence than aggregate reconciliation alone.

The verification completed successfully using set-based comparisons without the timeout encountered during E038.

### Residual limitations

The synthetic timestamp-tie test verifies the calculation expression rather than the deployed function against inserted fixtures.

Baseline row counts do not establish complete historical data equality.

The verification runtime is not an individual reporting benchmark.

Historical data completeness, actual payments and concurrent reporting performance remain unverified.

### Decision impact

D030 is implemented and has passed comprehensive correctness verification.

Controlled performance measurement under E044 remains outstanding.


## V044 — Running spending performance baseline

**Date:** 2026-11-26

**Status:** Passed.

**Decision:** D030.

**Script:** sql/04_reporting/14_running_spending_baseline.sql

**Evidence:** evidence/44_running_spending_baseline.txt

### Environment

PostgreSQL 18.7, work_mem 4 MB, shared_buffers 128 MB, effective_cache_size 4 GB, hash_mem_multiplier 2, block size 8192 bytes, JIT enabled, I/O timing disabled.

### Repeated headline execution times

| Report | Run 1 (ms) | Run 2 (ms) | Run 3 (ms) | Median (ms) |
|---|---:|---:|---:|---:|
| Dense monthly | 724.309 | 774.494 | 693.844 | 724.309 |
| Monthly running | 1281.889 | 1292.742 | 1420.831 | 1292.742 |
| Transaction running | 466.113 | 372.770 | 374.235 | 374.235 |

Monthly running reporting adds 568.433 ms to the median dense monthly execution time, representing 78.48% overhead and a runtime ratio of 1.78.

This measures additional functionality rather than an optimization between equivalent queries.

### Sensitivity measurements

Monthly running: 1472.815 ms for 485040 records.

Transaction running: 389.511 ms for 111195 records.

### Single-customer filtering

Monthly running returned 12 records in 1290.041 ms after discarding 485028 records.

Transaction running returned 4 records in 361.731 ms after discarding 111186 records.

The execution plans establish that external customer filtering occurs after full function result generation.

### Temporary block activity

| Report | Median temp reads | Median temp writes |
|---|---:|---:|
| Dense monthly | 14259 | 4975 |
| Monthly running | 20105 | 10829 |
| Transaction running | 1946 | 1947 |

Monthly running increases temporary block reads by 41.00% and writes by 117.67%.

Temporary block activity does not establish peak storage usage or physical disk traffic.

### Cardinality estimation

Unfiltered functions estimate 1000 rows despite returning up to 485040 records.

This creates potential planning risks when reporting functions participate in larger queries.

### Execution outcome

- Expected execution plans: 13.
- Completed execution plans: 13.
- Transaction outcome: ROLLBACK.
- Exit code: 0.

### Decision impact

Retain both running spending interfaces and both cumulative measures.

The observed standalone execution times support the reporting requirement on the supplied baseline.

Do not introduce persistent reporting storage or global memory configuration changes without further evidence.

### Residual limitations

Three repeated headline measurements do not establish a reliable latency distribution.

Cold-cache performance, client export latency, larger datasets and concurrent flash-sale performance remain unverified.

The original 40-minute report has not been independently reproduced.

Equivalent-query before/after optimization remains outstanding.

### D030 — Implementation closure

**Status:** Accepted, implemented, correctness verified and performance baseline established.

**Supporting evidence:** E041, E041a, E042a, E043 and E044.

Both monthly and transaction-level cumulative reporting functions are operational.

Comprehensive verification passed all 22 assertions across 13 check groups, covering 1192465 report records across two reporting dates.

The monthly running report has a measured headline median execution time of 1292.742 ms. The transaction running report has a median of 374.235 ms.

The additional monthly cumulative functionality introduces 568.433 ms of median execution overhead relative to the dense monthly report.

This cost is acceptable for the current standalone reporting workload.

Single-customer filtering remains inefficient and is recorded for optimization.

The design does not establish complete lifetime purchasing history, actual payment receipt, end-to-end client latency or performance during concurrent flash-sale activity.

Revisit the decision if reporting costs increase materially, earlier historical data becomes available, client requirements change or concurrent workload testing identifies unacceptable interference.

Stage 04.5 is complete. Final performance optimization and fresh-load verification remain project-level requirements.


## V045 — Customer ranking investigation

**Date:** 2026-11-26

**Status:** Passed.

**Decision:** D031 — Pending final acceptance.

**Script:** sql/04_reporting/15_customer_ranking_investigation.sql

**Evidence:** evidence/45_customer_ranking_investigation.txt

### Objective

Investigate ranking-period sensitivity, customer eligibility, spending concentration and ranking boundary ties before implementing the top-100 customer report.

### Population reconciliation

| Measurement | 2026-08-31 | 2026-11-26 |
|---|---:|---:|
| Total customers | 40420 | 40420 |
| Positive history spenders | 37900 | 37900 |
| Positive window spenders | 37816 | 37285 |
| Zero-value purchasers | 0 | 0 |
| Negative-spending customers | 0 | 0 |
| History spending | 339176836.88 | 339184984.53 |
| Window spending | 334634759.00 | 313014045.03 |

All spending totals reconcile with previous reporting investigations.

### Ranking-period sensitivity

The headline history and window rankings retain 97 common customers. Three customers are replaced when changing ranking basis. Fifty positions remain unchanged and 47 retained customers change positions.

The sensitivity-date rankings retain 90 common customers. Ten customers are replaced. One position remains unchanged and 89 retained customers change positions.

The mean absolute rank changes among retained customers are 1.25 and 5.73 respectively.

### Ranking boundaries

All four investigated ranking scenarios return 100 customers under ROW_NUMBER, RANK and DENSE_RANK.

No ties occur at the 100th-position spending boundary.

The recorded-history boundary gap is GHS 25.38 on both dates. The window boundary gaps are GHS 238.43 and GHS 256.06.

The absence of observed ties does not remove the requirement for a deterministic future tie-handling policy.

### Spending concentration

| Date | Basis | Top-100 spending | Percentage |
|---|---|---:|---:|
| 2026-08-31 | Recorded history | 14836678.67 | 4.3743% |
| 2026-08-31 | Trailing 12 months | 14781340.27 | 4.4172% |
| 2026-11-26 | Recorded history | 14836678.67 | 4.3742% |
| 2026-11-26 | Trailing 12 months | 14329991.90 | 4.5781% |

The headline top ten customers have identical membership, spending and positions under both ranking bases.

### Investigation performance

- Population and spending: 332.068 ms.
- Boundary and concentration: 830.239 ms.
- Ranking sensitivity: 454.822 ms.
- Top-ten comparison: 268.725 ms.
- Combined query time: 1885.854 ms.

These are individual investigation timings rather than repeated production ranking benchmarks.

### Execution outcome

All four investigation sections completed.

Transaction outcome: ROLLBACK.

Exit code: 0.

### Decision impact

Ranking period materially affects customer selection.

Providing both ranking perspectives is supported by the observed membership and position differences.

Positive-spending eligibility excludes no observed eligible purchasers on either investigated date.

Deterministic ranking positions and separate spending ranks are proposed to address future ties.

### Residual limitations

Recorded spending does not establish profitability, actual payments or complete lifetime customer value.

The sparse activity after August 2026 limits interpretation of the sensitivity ranking.

The investigation does not verify the production ranking function, synthetic boundary ties, small candidate populations or concurrent reporting performance.

code working-notes/defence_notes.md


### D031 — Final architecture amendment and acceptance

**Date:** 2026-11-26

**Status:** Accepted; implementation pending.

Adopt a shared customer-level spending calculation as the foundation for customer ranking and as the target reusable calculation layer for the wider reporting system.

Calculate recorded-history, opening and trailing twelve-month spending and order counts directly at customer grain using the existing eligibility foundation and reporting-window metadata.

Use chained CTEs and window functions to rank the complete positive-spending candidate population before selecting up to 100 customers.

Expose deterministic ranking positions, equal-spending ranks and separate cutoff metadata.

The customer-ID tie-breaker is arbitrary but reproducible. Excluded cutoff ties must be disclosed.

Preserve existing verified reporting functions until controlled integration and regression testing establish that refactoring is beneficial.

The design applies the module's aggregation, CTE, window-function and reusable reporting principles. The layered architecture is an engineering synthesis rather than a mandatory module prescription.

The strongest counterargument is that additional function boundaries may cause repeated computation, poor cardinality estimates and inefficient filtering.

Measure these costs before introducing further abstractions or persistent reporting storage.

**Next evidence:** E046 deployment, E046a inspection, E047 verification and E048 performance baseline.

## V046a — Shared customer spending and ranking inspection

**Date:** 2026-11-26

**Status:** Passed functional inspection.

**Decision:** D031 — Accepted and implemented; comprehensive verification pending.

**Script:** sql/04_reporting/17_customer_ranking_inspection.sql

**Evidence:** evidence/46a_customer_ranking_inspection.txt

### Shared calculation results

The shared customer spending function returns 40420 customers.

Recorded-history spending is GHS 339176836.88 across 111190 eligible attributed orders.

Opening spending is GHS 4542077.88 across 1488 orders.

Window spending is GHS 334634759.00 across 109702 orders.

All 40420 customers satisfy the spending and order-count partition identities.

There are zero observed identity failures.

### Customer-level examples

Customers 100001, 100014 and 101702 reproduce their previously verified history, opening and window spending amounts.

These examples cover window-only, mixed-period and opening-only activity.

### Ranking inspection

Both headline rankings reproduce the E045 top-ten membership, positions and spending values.

All four ranking scenarios reproduce the expected qualifying populations, selected counts, cutoff amounts, selected spending and spending concentration.

Each scenario contains 100 distinct customer IDs, 100 distinct ranking positions and 100 distinct spending amounts.

No internal top-100 spending ties or cutoff exclusions were observed.

### Empty population

The 2025-01-31 ranking returns zero records.

Its metadata returns zero qualifying customers, zero selected customers, zero spending and zero cutoff exclusions.

Cutoff spending and spending percentage are NULL.

### Performance observations

| Inspection | Time (ms) |
|---|---:|
| Shared spending reconciliation | 668.315 |
| Three customer examples | 398.194 |
| Window top ten | 456.758 |
| History top ten | 537.008 |
| Four metadata scenarios | 2313.467 |
| Four uniqueness checks | 1905.974 |
| Empty ranking | 192.239 |
| Empty metadata | 195.859 |

These are functional inspection timings, not repeated production benchmarks.

### Execution outcome

All six inspection sections completed.

Transaction outcome: ROLLBACK.

Exit code: 0.

### Residual limitations

The separate E046 deployment transcript has not been reviewed. Successful operation of all four functions establishes that the required interfaces are present.

Exact full-population equality against independent raw calculations remains to be verified.

Actual cutoff ties, small qualifying populations and invalid parameter handling remain to be tested.

Performance under concurrent order placement and the final fresh-load procedure remain outstanding.

## V047 — Independent customer ranking verification

**Date:** 2026-11-26

**Decision:** D031.

**Status:** Implemented and functionally verified. Performance assessment pending.

**Script:** tests/12_customer_ranking_test.sql

**Evidence:** evidence/47_customer_ranking_verification.txt

### Verification outcome

49 of 49 expected PASS notices were observed.

Exit code: 0.

All three verification transactions completed with ROLLBACK.

### Independent baseline verification

Compared 80840 customer-date records against independently reconstructed raw-order calculations.

Compared all 14 output fields for 400 selected ranking records across two reporting dates and two ranking bases.

The shared calculation reconciles with D028 customer summaries, D029 monthly reports and D030 cumulative spending.

Ranking metadata independently matches the raw-order calculation.

All four financial reconciliation scenarios have zero differences.

### Synthetic edge-case verification

Inserted 103 controlled reporting-only orders within a transaction.

Both ranking bases correctly identified three customers sharing the GHS 100.00 cutoff.

One customer was selected using ascending customer ID and two were excluded.

The metadata explicitly disclosed both exclusions.

Exact numeric comparison distinguished GHS 99.99 from GHS 100.00.

The qualifying population spent GHS 20199.99, of which GHS 19900.00 was selected and GHS 299.99 remained.

Small populations returned two customers without padding.

Empty populations returned no ranking rows and meaningful metadata.

Invalid and NULL ranking bases were rejected with SQLSTATE 22023.

NULL reporting dates produced no records for the tested valid default basis.

### Baseline preservation

All synthetic orders and the temporary fixture table were removed by rollback.

All six original table counts were preserved.

The previously empty reporting period was restored.

### Performance observations

Independent baseline verification completed in 20660.614 ms.

Synthetic ranking verification completed in 1504.703 ms.

These are verification durations rather than report execution benchmarks.

### What this survives

The ranking does not depend on unique spending amounts, exactly 100 qualifying customers or a fixed reporting date.

Financial consistency across existing reporting interfaces is verified for both tested dates.

### Residual risks

The arbitrary customer-ID tie-breaker may be inappropriate for reward allocation.

Recorded spending does not establish audited revenue, profitability or complete lifetime customer value.

The shared calculation architecture may introduce repeated computation and function materialization costs.

Baseline count equality does not establish complete table-content equality.

Equivalent architecture benchmarking, concurrent workload testing and fresh-load reproduction remain outstanding.


## V048 — Equivalent customer ranking architecture benchmark

**Date:** 2026-11-26

**Decision:** D031

**Script:** sql/04_reporting/18_customer_ranking_baseline.sql

**Evidence:** evidence/48_customer_ranking_baseline.txt

**Status:** Benchmark passed; architecture retained provisionally.

### Correctness

All four equivalence comparisons returned zero differences across all 14 ranking output fields.

Twelve execution plans completed successfully. Read-only transaction rolled back. Exit code 0.

### Performance

Three direct execution times: 500.371, 478.791 and 484.836 ms.

Three sparse execution times: 886.918, 982.288 and 930.033 ms.

Direct median: 484.836 ms.

Sparse median: 930.033 ms.

Median execution time reduction: 445.197 ms, equivalent to 47.87%.

Speed ratio: 1.92x.

### Resource observations

Direct shared buffer hits: 1797.

Sparse shared buffer hits: 222767.

Median temporary blocks read: direct 2594, sparse 3402.

Median temporary blocks written: direct 2947, sparse 3980.

The sparse architecture introduces additional customer-month aggregation, opening-balance calculation and intermediate processing.

### Strongest counterargument

The sparse plan incurred a median visible JIT compilation duration of 385.832 ms, approximately 41.49% of its median execution time.

Poor cardinality estimates and different function boundaries may contribute to the measured performance difference.

The benchmark does not isolate aggregation grain as the sole causal variable.

### Additional findings

Single-customer totals returned one row after discarding 40419, taking 417.402 ms compared with 473.974 ms for all customers.

Top-100 selection discarded 37716 ranked records.

Metadata execution took 516.192 ms and materialized the ranked population.

These observations identify further optimization opportunities.

### Decision

Retain direct customer-level aggregation under the tested configuration.

Preserve the sparse monthly architecture for monthly reporting.

Investigate JIT sensitivity before making a stronger comparative performance claim.

Do not introduce persistent configuration changes, new infrastructure or materialized reporting objects without further evidence.

### Residual risks

Three repetitions do not establish production p95 latency.

Buffer accesses are not physical disk reads.

Internal direct-function execution plans are not exposed.

Concurrent checkout impact, growth sensitivity, end-to-end delivery and fresh-load reproduction remain outstanding.

The historical client-reported 40-minute duration is not a measured equivalent baseline.

## V049 — Controlled JIT sensitivity investigation

**Date:** 2026-11-26

**Decision:** D031

**Script:** sql/04_reporting/19_customer_ranking_jit_sensitivity.sql

**Evidence:** evidence/49_customer_ranking_jit_sensitivity.txt

**Status:** Execution passed. Architecture investigation complete.

### Objective

Determine whether the measured performance advantage of direct customer-level aggregation survives disabling JIT compilation.

### Method

Compare equivalent direct and sparse-plus-opening ranking implementations using three executions per architecture and JIT setting.

Use one read-only repeatable-read transaction and transaction-local configuration changes.

### Results

Twelve execution plans completed. Transaction rolled back successfully. Exit code 0.

Direct, JIT enabled: 854.036, 519.178, 593.868 ms.

Direct, JIT disabled: 584.284, 546.396, 490.099 ms.

Sparse, JIT enabled: 1743.836, 1676.199, 1742.890 ms.

Sparse, JIT disabled: 1110.108, 1099.445, 1409.747 ms.

Median execution times:

- Direct with JIT: 593.868 ms.
- Direct without JIT: 546.396 ms.
- Sparse with JIT: 1742.890 ms.
- Sparse without JIT: 1110.108 ms.

Direct aggregation reduced median execution time by 65.93% with JIT enabled and 50.78% with JIT disabled.

Disabling JIT reduced the sparse median by 36.31% and the direct median by 7.99%.

Visible sparse JIT compilation median: 693.703 ms.

### Interpretation

JIT contributes substantially to the sparse implementation's execution time but does not fully explain its performance disadvantage.

The direct implementation remained faster in every observed execution.

The sparse implementation retains additional aggregation, sorting, temporary storage and cardinality estimation problems with JIT disabled.

### Decision

Retain the direct customer-level ranking architecture.

Preserve sparse monthly aggregation for monthly reporting.

Do not change database-wide JIT settings.

Consider report-local tuning only if justified during final performance testing.

### Limitations

The submitted terminal excerpt begins partway through an execution plan. The four equivalence gate headers are visible, but their result rows are omitted. Successful gate completion is inferred from the fail-fast script and exit code 0.

Three repetitions per configuration do not establish production p95 latency.

Internal direct-function execution plans remain hidden.

The experiment compares complete implementations rather than isolating aggregation grain as the sole causal variable.

Concurrent checkout impact, growth sensitivity, end-to-end report delivery and fresh-load reproduction remain outstanding.

### Conclusion

E048 and E049 support D031 under the tested conditions. No further ranking architecture investigation is required at this stage.