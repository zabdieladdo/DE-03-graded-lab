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