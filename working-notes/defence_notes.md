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