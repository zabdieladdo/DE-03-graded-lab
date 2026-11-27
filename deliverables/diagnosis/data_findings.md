# Data findings — Kloud Kart Ltd.

**Date:** 2026-11-26  
**Scope:** DE-03 graded baseline, `kloudkart_lab`, PostgreSQL 18  
**Status:** Baseline diagnosis complete; subsequent implementation and local verification are documented separately. Final fresh-load acceptance remains pending.

## Summary

Kloud Kart's most urgent risk is accepting purchases for unavailable stock. The engagement reports two overselling incidents and an anticipated flash-sale workload of approximately 400 orders in ten seconds against one product. Stock reliability and auditability rank next, followed by inconsistent order statuses. The existing schema permits invalid relationships and values: it has six primary keys but no foreign keys, business CHECK constraints, additional unique constraints, non-primary-key indexes or public-table triggers. Twenty-five non-primary-key columns are nullable. These omissions establish what the database permits, not the cause of every historical anomaly or the absence of application-level safeguards.

The baseline contains 822,832 rows across six tables. Read-only investigations identified 1,023 broken non-null references, 14 negative-stock products, 144 stock-to-movement reconciliation differences, 15 raw order status representations, and 2,279 orders with discrepancies between complete item values and recorded checkout totals. The financial figures below are recorded amounts or calculated exposure, not verified losses, payments or recognized revenue. Exposures overlap and must not be added together. Monetary figures are in the dataset's recorded currency units; currency has not been independently confirmed.

The accepted approach is to prevent new damage, preserve and flag historical exceptions, normalize statuses in the reporting layer, use completed-only recorded spending at customer-account level, and make the low-stock threshold configurable (provisional default 10). No historical correction is authorized. The work must remain on the existing PostgreSQL server, with no additional production infrastructure or recurring bill.

**Evidence convention:** Paths below are relative to the graded repository unless identified as learning evidence. Counts are from learner-supplied baseline SQL outputs; business incidents and original report duration are from the engagement brief. Practice experiments are not graded implementation tests. Findings describe the original baseline. See the implementation update below for subsequent verification.

## Reconciliation

| Stage | Rows | Delta | Reason |
|---|---:|---:|---|
| Categories: expected → loaded | 94 | 0 | Baseline count matches supplied data |
| Products: expected → loaded | 4,023 | 0 | Baseline count matches supplied data |
| Customers: expected → loaded | 40,420 | 0 | Baseline count matches supplied data |
| Orders: expected → loaded | 159,384 | 0 | Baseline count matches supplied data |
| Order items: expected → loaded | 336,559 | 0 | Baseline count matches supplied data |
| Inventory log: expected → loaded | 282,352 | 0 | Baseline count matches supplied data |
| Combined baseline | 822,832 | 0 | All six table counts reconcile |
| Orders: raw → candidate normalized grouping | 159,384 | 0 | Classification only; 15 representations grouped into five candidate statuses |
| Order items: quantity distribution | 336,559 | 0 | 336,553 quantities from 1 to 10 plus six extreme quantities |
| Orders: checkout/item reconciliation | 159,384 | 0 | 156,958 exact matches + 2,279 discrepancies + 147 incomplete item valuations |
| Products: stock-to-movement comparison | 4,023 | 0 | 3,879 matches + 144 differences |
| Categories: ancestry classification | 94 | 0 | 91 root reachable + two cycle encountered + one missing ancestor |

Baseline evidence: `evidence/00_baseline_load.txt`, `evidence/00_baseline_reconciliation.txt`. Investigation evidence: `evidence/02_referential_integrity.txt`, `evidence/03_business_value_validation.txt`, `evidence/04_business_impact.txt`, `evidence/06_exception_investigation.txt`, `evidence/07_raw_status_investigation.txt`. Zero delta means the relevant population reconciles; it does not establish that all values are correct. A post-implementation baseline preservation check remains pending.

### Relationship reconciliation

| Relationship | Total | Matched | NULL reference | Broken non-null reference |
|---|---:|---:|---:|---:|
| Order items → orders | 336,559 | 335,867 | 0 | 692 |
| Orders → customers | 159,384 | 159,174 | 0 | 210 |
| Inventory log → products | 282,352 | 282,232 | 0 | 120 |
| Categories → parent categories | 94 | 86 | 7 | 1 |
| Order items → products | 336,559 | 336,559 | 0 | 0 |
| Products → categories | 4,023 | 3,986 | 37 | 0 |

Each relationship reconciles independently. The 1,023 broken references are relationship violations, not a count of unique affected business entities. The 44 NULL references are not automatically defects.

### Completed-only spending reconciliation

| Component | Orders | Recorded amount |
|---|---:|---:|
| Candidate normalized completed orders | 111,351 | 339,609,366.03 |
| Less: orders with no matching customer | 144 | 388,780.89 |
| Attributed completed orders | 111,207 | 339,220,585.14 |

37,900 customer accounts have eligible orders; 2,520 do not; together they reconcile to 40,420 accounts. The spending sensitivity investigation reconciled all 11 comparisons with zero monetary difference between eligible amounts and attributed plus unattributed amounts. This is an all-history baseline, not yet the final monthly report.

## Findings, ranked by risk

### F-01: Unsafe concurrent order placement — Severity: Critical

- **What it is:** The brief reports simultaneous purchases of the same last unit on two occasions. A read-check-write sequence without adequate concurrency control can approve both purchases against the same stock. The baseline schema has no business constraint against negative stock; a constraint alone would not prevent every lost-update scenario.
- **How I detected it:** Engagement incident description; schema inspection (`evidence/01_schema_inspection.txt`); learner-reported synthetic Read Committed practice experiment in which two sessions read one available unit, both committed sales, and only one unit was deducted. The practice result is not a production trace or a graded race-test result.
- **Scale:** Two reported historical incidents; approximately 400 orders in ten seconds expected on one product. Historical incident quantities and refund amounts are unknown.
- **Effect on the client's number:** Stock can be overstated or understated relative to accepted sales, and customers can pay for unavailable goods. Refunds, support work and reputational harm follow. The direct cost cannot be calculated without refund, handling and incident records. A final stock of zero does not prove that overselling did not occur.
- **What I did about it:** Ranked transaction safety first. Planned a single atomic purchase operation with concurrency-safe stock validation/deduction, order and item creation, and movement recording. Require a clear out-of-stock refusal and the supplied unmodified race test, plus independent atomicity checks. The routine was subsequently verified; see ADR-002 and the order-placement performance report.
- **Residual risk:** Actual production purchase code and historical cause are unverified. The chosen implementation must be tested at last-unit and flash-sale contention, including rollback and other stock-writing paths.

### F-02: Inventory accuracy and auditability — Severity: High

- **What it is:** Negative recorded stock, differences between stock snapshots and net logged movements, and movements without valid product references undermine inventory confidence. A movement history existing for a product does not prove it is complete.
- **How I detected it:** Negative-stock filter, movement aggregation by product, comparison of stock to net movement, and anti-join to products (`evidence/02_referential_integrity.txt`, `03_business_value_validation.txt`, `04_business_impact.txt`, `06_exception_investigation.txt` under `evidence/`).
- **Scale:** 14 negative-stock products, combined deficit 27 units, indicative catalogue value 20,627.76. All 4,023 products have movement history; 3,879 match net movement and 144 differ (3.58%). Thirteen of the 14 negative-stock products match their net movement. Product 6295 has stock −1, net movement +3 and residual −4. Separately, 120 orphaned sale movements reference 111 missing product IDs, with net quantity −120.
- **Effect on the client's number:** Availability, replenishment and audit reports may be unreliable. The catalogue valuation is an indicative deficit measure, not inventory cost, a refund total or proven loss. The residual −4 is not proof of four missing sales.
- **What I did about it:** Accepted preservation and flagging of historical records (ADR-001). Planned atomic stock movement recording for new purchases and auditable restocks/corrections. Retain negative balances as exceptions; do not overwrite snapshots with net movement without verified opening balances. Prevent new invalid movements and disclose orphaned history.
- **Residual risk:** Opening balances, movement completeness, historical backorders and the causes of negative stock are unknown. Audit coverage and concurrency safety of all new stock-writing paths remain to be tested.

### F-03: Inconsistent order statuses — Severity: High

- **What it is:** Free-text status contains capitalization, whitespace and vocabulary variants. Exact filters can produce materially different reports. Formatting differences are established; semantic equivalence of different words remains an assumption.
- **How I detected it:** Grouped raw statuses with quoted values and character lengths, compared LOWER/TRIM and candidate vocabulary mapping, and ran six spending scenarios with 11 comparisons (`evidence/03_business_value_validation.txt`, `evidence/05_status_sensitivity.txt`, `evidence/07_raw_status_investigation.txt`).
- **Scale:** 15 raw representations across 159,384 orders. Exact `completed` matches 22,091 orders; formatting-only normalization matches 89,066; including `complete` gives 111,351. The exact filter omits 89,260 candidate completed orders (80.16%) with recorded amounts of 273,128,670.24. Candidate status counts: completed 111,351; shipped 12,848; pending 16,009; cancelled 12,697; refunded 6,479.
- **Effect on the client's number:** Exact completed attributed spending is 66,421,016.99 versus 339,220,585.14 under the candidate completed mapping; only 18 of the exact-match top 100 remain in the normalized completed top 100. Including shipped adds 40,918,016.89 (12.06%) and changes 20 of the completed-only top 100; including shipped and pending adds 89,262,456.02 (26.31%) and changes 33. These are policy sensitivity results, not actual lost revenue or evidence of Adwoa's existing filter.
- **What I did about it:** Accepted preservation of raw statuses and centralized reporting normalization, including provisional mappings `complete` → `completed` and `canceled` → `cancelled`. Accepted completed-only eligibility, using an explicit allowlist rather than broad exclusion. Proposed `orders.total_amount` as the spending source, with unattributed amounts separately disclosed and unknown statuses flagged. Raw and normalized investigations reconcile all 148 missing-price items, 152 zero-price items and 210 orphaned orders.
- **Residual risk:** Client confirmation of status semantics and payment lifecycle is unavailable. Completed does not prove paid; shipped may already be paid. Order-date monthly attribution can change retrospectively as status changes. The actual Monday query is unavailable; the reporting definition is implemented (ADR-003); client confirmation remains outstanding.

### F-04: Broken relational references — Severity: High

- **What it is:** Non-null references point to absent parent records. Foreign keys are absent in the baseline. NULL references are assessed separately.
- **How I detected it:** Six relationship checks using LEFT JOIN/anti-join logic with separate matched, NULL and broken counts (`evidence/02_referential_integrity.txt`, `evidence/04_business_impact.txt`).
- **Scale:** 692 orphaned order items referencing 689 missing order IDs, with 968 recorded units and known line value 826,327.80; 210 orders without valid customers with recorded amounts 665,180.61 across all statuses (144 candidate completed orders, 388,780.89); 120 orphaned inventory movements; one category with a missing parent. No broken non-null order-item product or product-category references. Total: 1,023 broken non-null references.
- **Effect on the client's number:** Inner joins can silently drop sales lines, order amounts and movement history. Customer reports cannot reliably attribute orphaned orders. These recorded exposures are not verified losses; inventory and hierarchy findings overlap this finding.
- **What I did about it:** Accepted ADR-001: preserve and flag historical records, do not delete, fabricate parents or reassign without evidence. Plan appropriate foreign keys protecting new writes, considering NOT VALID for existing violations, with explicit validation status. Report unattributed and orphaned populations separately.
- **Residual risk:** Historical parents cannot be reconstructed from the available data. NOT VALID constraints do not certify existing rows, prevent cycles or disallow NULL by themselves. Local constraint tests passed; final fresh-load verification remains pending.

### F-05: Financial value anomalies — Severity: High

- **What it is:** Recorded checkout totals and calculated item totals disagree for some orders; missing prices prevent complete valuations; extreme quantities create unusually large line values. A discrepancy is established, but the correct historical value and the cause are not.
- **How I detected it:** Numeric profiling, item aggregation per order, missing-price checks, absolute and signed discrepancy bands, and examination of extreme quantities in order context (`evidence/03_business_value_validation.txt`, `evidence/04_business_impact.txt`, `evidence/06_exception_investigation.txt`, `evidence/07_raw_status_investigation.txt`).
- **Scale:** 156,958 exact matches; 1,341 checkout totals below complete item totals; 938 above; 147 incomplete item valuations. Across 2,279 complete-value discrepancies, absolute difference is 3,760,997.98 and signed checkout-minus-item difference is −2,670,101.54. The 319 differences above 1,000 contribute 3,385,377.66 (about 90% of absolute discrepancy). There are 148 missing-price items across 147 orders (226 units), including 95 candidate completed items (155 units). Six extreme quantities (four 999 and two 9,999) total 23,994 recorded units and 3,073,441.59 in calculated line value. Every extreme line exceeds its order's recorded checkout total; two affected orders are candidate completed. One extreme-quantity order also has missing item pricing.
- **Effect on the client's number:** Item-based spending, demand and inventory analysis can be distorted. Missing prices make totals incomplete; SUM ignores NULL values. The absolute discrepancy is not a loss estimate; discounts, taxes, shipping or other adjustments may explain some differences. Extreme line values overlap discrepancy exposure and must not be added to it.
- **What I did about it:** Accepted policy: preserve and flag extreme quantities; no unsupported maximum of 10. Preserve missing prices and expose incomplete valuations; do not replace NULL with zero or current catalogue prices. Proposed recorded checkout totals for completed-order spending, with quality caveats. No inferred historical corrections made.
- **Residual risk:** Invoices, adjustments, original quantities and payment records are unavailable. Checkout totals may themselves be wrong. Flags and report handling remain to be implemented; the link between extreme quantities and stock movements is unverified.

### F-06: Slow customer spending reports — Severity: High

- **What it is:** Adwoa's Monday report reportedly takes about 40 minutes and sometimes fails to finish. The baseline has only primary-key indexes. This is a confirmed reported service problem; its production query plan and root cause are not established.
- **How I detected it:** Engagement brief and baseline index inspection (`evidence/01_schema_inspection.txt`). Learning-path query experiments demonstrated that repeated correlated scans can be expensive and set-based aggregation can reduce work, but those are not measurements of the actual Monday report.
- **Scale:** Approximately 40 minutes per reported completed run, 40,420 customer accounts and 159,384 baseline orders. At one completed run per week for 52 weeks, illustrative elapsed waiting time is 34 hours 40 minutes per year (52 × 40 minutes). This is not measured staff labour; incomplete runs are not included.
- **Effect on the client's number:** Nana reports making decisions without the report. Labour cost would require verified active staff time and loaded hourly rate; opportunity cost requires evidence of decisions and outcomes. Neither is available.
- **What I did about it:** Prioritized correctness before optimization. Plan set-based customer aggregation, monthly and running totals, deterministic top-100 ranking and evidence-driven index/query tuning on the existing server. Measure equivalent before/after outputs and timings, including write costs where relevant.
- **Residual risk:** Actual Monday SQL, production workload and resource contention are unknown. Later graded performance measurements are reported separately; the original production query remains unavailable.

### F-07: Broken category hierarchy — Severity: Medium–High

- **What it is:** The category structure is not a fully rooted tree. Cycles and missing ancestors can make recursive reporting non-terminating or incomplete.
- **How I detected it:** Recursive ancestry traversal starting from all categories with visited-path tracking and terminal classification (`evidence/06_exception_investigation.txt`), supported by parent anti-join (`evidence/02_referential_integrity.txt`).
- **Scale:** Of 94 categories, 91 reach a root, two encounter a cycle, and one encounters a missing ancestor. Seven categories have NULL parent IDs (valid root candidates). Thirty-seven products have no assigned category; 15 of those have recorded stock below 10. In the separate learning environment, threshold 10 produced 1,949 low-stock products: 1,931 under valid roots, 15 uncategorised and three in unrooted categories. The graded rollup subsequently reproduced these counts (ADR-005).
- **Effect on the client's number:** Root-only reporting can omit products and naive recursion can fail to terminate. Summing parent and descendant totals double-counts products. Missing visibility can delay replenishment.
- **What I did about it:** Accepted configurable threshold with provisional default 10, strict stock < threshold. Plan cycle-safe recursion without hardcoded hierarchy depth, explicit exception groups, effective threshold disclosure and distinct negative/zero/unknown stock handling. Preserve category relationships pending verified correction.
- **Residual risk:** The optimal replenishment threshold and correct historical parent assignments are unknown. Graded hierarchy and invalid-threshold tests passed; one rollup execution took 1.461 ms. Production performance remains unverified. A global threshold is not a product-specific reorder model.

### F-08: Potential duplicate customer identities — Severity: Medium

- **What it is:** Shared normalized emails and names suggest possible duplicate accounts, but do not establish personal identity.
- **How I detected it:** Grouped LOWER/TRIM email values and compared normalized names, trimmed phones and normalized cities (`evidence/03_business_value_validation.txt`, `evidence/06_exception_investigation.txt`).
- **Scale:** 533 groups affect 1,068 of 40,420 customer records (2.64%). All 533 groups share normalized names and contain differing trimmed phone numbers; 206 groups contain differing normalized cities. A one-account-per-email assumption would identify 535 excess records, not confirmed duplicate people.
- **Effect on the client's number:** Spending may be fragmented across accounts belonging to one person, or falsely combined if shared emails are treated as identity. Account-level rankings may differ from person-level rankings even when total spending reconciles.
- **What I did about it:** Accepted account-identity policy: preserve separate customer IDs and existing order attribution; flag potential duplicates. Do not impose email uniqueness or merge by email/name. Plan one spending summary per existing customer ID and quality joins that do not multiply orders.
- **Residual risk:** Personal identity remains unresolved. Actual ranking impact of email consolidation has not been measured. Reports must describe account-level rather than unique-person metrics.

### F-09: Ambiguous but potentially legitimate values — Severity: Review

- **What it is:** Zero-priced items and products without categories may be legitimate business cases, not necessarily defects.
- **How I detected it:** Numeric profiling, raw/normalized status analysis and NULL-category checks (`evidence/03_business_value_validation.txt`, `evidence/04_business_impact.txt`, `evidence/06_exception_investigation.txt`, `evidence/07_raw_status_investigation.txt`).
- **Scale:** 152 zero-price items across 151 orders and 229 units, including 102 candidate completed items (150 units). Thirty-seven uncategorised products hold 3,112 recorded stock units; 15 are below the provisional threshold and none has negative stock.
- **Effect on the client's number:** Zero prices could represent promotions or erroneous pricing; treating all as faults could invent revenue. Omitting uncategorised products from category reports hides inventory. No monetary loss is established.
- **What I did about it:** Preserve both populations. Recommend separate quality visibility for zero prices and an uncategorised reporting group. Do not substitute catalogue prices or invent categories. These treatments follow the accepted preservation policy; uncategorised products are now exposed separately.
- **Residual risk:** Promotion rules and category assignment policies are unavailable. Some records may require correction after authoritative verification.

### F-10 — Suspicious order dates and reporting period distortion

**Severity:** Medium — reporting accuracy risk.

**What it is**

The order dataset contains a small number of records dated substantially later than the main concentration of historical orders. Fifteen orders occur after the reporting date of 26 November 2026.

**How I detected it**

I profiled the minimum and maximum order timestamps, monthly order distributions and future-dated order counts.

I then investigated all 24 orders recorded after August 2026, checking customer references, registration dates, order items, item prices, quantities and financial reconciliation.

I also measured six alternative reporting windows and compared unrestricted customer spending with spending restricted to the reporting date.

**Scale**

- Total orders: 159,384.
- Earliest order: 2025-08-02 05:00:54.
- Latest order: 2027-08-20 19:30:00.
- Missing order dates: 0.
- Orders recorded through August 2026: 159,360.
- Orders recorded after August 2026: 24.
- Future-dated orders as of 2026-11-26: 15.
- Future-dated eligible orders: 12.
- Future-dated eligible recorded value: 35,600.61.
- Total recorded value of all future-dated orders: 40,871.60.
- Existing customers affected by future-dated eligible orders: 12.

All 24 investigated orders had valid customer references, no detected registration-date conflicts, complete item prices and matching recorded and calculated order values.

**Effect on the client's number**

Including future-dated eligible orders increases unrestricted attributed customer spending by 35,600.61 compared with spending restricted to 26 November 2026.

Excluding these orders changes the spending values of 12 customers but does not change top-100 membership.

The larger reporting risk concerns the automatic selection of reporting dates. Anchoring a twelve-month report to the latest recorded order produces only 17 eligible orders worth 43,748.26.

By comparison, the twelve months ending August 2026 contain 109,846 eligible orders worth 335,023,539.89.

These different reporting periods are not directly comparable measures of business performance. The comparison demonstrates the sensitivity of the report to its date anchor.

**What I did about it**

Preserved the original records and investigated their financial and relational consistency.

Implemented an explicit configurable reporting date, exclusion of orders beyond the reporting cutoff and separate visibility of excluded records (ADR-003).

No dates were corrected, and no historical orders were deleted.

**Residual risk**

The correct business dates remain unverified. Future-dated orders may represent legitimate scheduled transactions or source-data errors.

The sparse order distribution after August 2026 may indicate dataset coverage rather than an actual decline in business activity.

The available data does not contain sufficient status history to reconstruct the exact historical state of an order at an earlier reporting date.

**Evidence**

- `sql/04_reporting/01_reporting_profile.sql`
- `sql/04_reporting/02_reporting_date_investigation.sql`
- `evidence/28_reporting_profile.txt`
- `evidence/29_reporting_date_investigation.txt`

**Status:** Investigated; reporting treatment accepted, implemented and locally verified. Correct business dates remain unverified.

## Subsequent implementation update

- Schema protections and purchase routine: ADR-001 and ADR-002.
- Spending definitions and reporting performance: ADR-003 and ADR-004.
- Inventory rollup and movement audit: ADR-005 and ADR-006.
- Independent publication checks: ADR-007.
- Final fresh-load acceptance remains pending.

## Looked wrong, is not wrong

| Apparent problem | Why it looks wrong | Why it is actually fine |
|---|---|---|
| 262,646 negative inventory movement quantities | Negative quantities resemble invalid stock balances | Signed outward movements are legitimate: 262,088 sales, 290 negative corrections and 268 damage movements. Negative movement is not negative stock. |
| 90 zero-quantity stock-take movements | A movement with zero change looks redundant | A stock take can record a check with no quantity adjustment; zero alone does not establish a defect. |
| 577 products with zero stock | No available units may look like a missing value | Zero is a valid out-of-stock state, distinct from NULL or negative stock. |
| Seven categories with NULL parent | A missing parent field resembles an orphan | NULL parent identifies a root in the supplied hierarchy model; a non-null missing parent is different. |
| 37 products with NULL category | An incomplete relationship may appear invalid | Products may be deliberately uncategorised; no non-null category reference is broken. Preserve and report separately pending policy confirmation. |
| 152 zero-priced items | A sale without price may appear invalid | Free items or promotions are plausible; no evidence establishes that every zero is wrong. Unlike NULL, zero is a recorded value. |
| Shared emails and names | They look like duplicate people | Multiple accounts or shared contact details are possible; identity is unverified. Do not merge on this evidence alone. |

## Could not verify

- Production order-placement SQL, historical concurrency traces, actual refund amounts and the causal link between overselling and negative stock. The synthetic practice experiment is learner-reported; its exact execution log should be retained separately.
- Opening stock balances, completeness of historical inventory movements, physical inventory counts and authoritative stock corrections.
- The business meaning of `complete` versus `completed`, actual payment/settlement state, refund amounts, partial refunds and payment/completion dates. The completed-only definition is an accepted provisional engineering policy, not a client-approved accounting rule.
- Original invoices, discounts, taxes, shipping charges, correct historical quantities/prices and whether zero prices are legitimate promotions. Recorded monetary units have not been independently confirmed.
- Personal identity and account ownership, actual effect of identity consolidation on the top 100, correct missing parent records and category assignments.
- Product-specific demand, replenishment lead times and optimal low-stock thresholds. The graded rollup reproduced the threshold-10 counts; the business threshold remains provisional.
- The actual Monday report SQL and production performance, active staff waiting time, loaded hourly rates and the financial cost of decisions made without reports.
- Final fresh-load regression, production performance and complete audit coverage across all possible write paths. Local implementation and unmodified race-test results are documented in the ADRs and performance reports.
- Local repository evidence-file presence, current Git state and final Evalu8 submission requirements have not been independently inspected here. Confirm the referenced files and authoritative rubric/deadline before submission.
