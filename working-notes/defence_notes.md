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