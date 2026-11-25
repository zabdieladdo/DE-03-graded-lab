# Customer Spending Sensitivity Analysis

Date: 2026-11-25

## Business question

How sensitive are customer spending totals and top-100 rankings to alternative order vocabulary and spending eligibility rules?

## Method

Six scenarios were evaluated against the same graded database snapshot using consistent customer populations, historical time scope, recorded order amounts and deterministic ranking rules.

The experiment was executed in a repeatable-read, read-only transaction.

## Results

| Scenario | Eligible orders | Attributed spending | Top-100 overlap with S1 |
|---|---:|---:|---:|
| S1: Exact completed | 22,091 | 66,421,016.99 | 100 |
| S2: Normalized completed | 111,351 | 339,220,585.14 | 18 |
| S3: Exact completed and shipped | 28,607 | 86,593,522.42 | 76 |
| S4: Normalized completed and shipped | 124,199 | 380,138,602.03 | 15 |
| S5: Exact exclusion | 152,929 | 467,529,578.30 | 14 |
| S6: Normalized exclusion | 140,208 | 428,483,041.16 | 15 |

## Key findings

### Vocabulary normalization

Normalizing completed statuses increased attributed spending by 272,799,568.15, equivalent to 410.71% relative to the exact-match baseline.

The change affected 36,031 customer spending totals and replaced 82 of the original top 100 customers.

### Spending eligibility

Including shipped orders after normalization increased attributed spending by 40,918,016.89 and replaced 20 of the normalized completed-only top 100 customers.

Including shipped and pending orders increased attributed spending by 89,262,456.02 and replaced 33 of those customers.

### Exact-match exclusion

Exact exclusion admitted 12,721 additional orders compared with normalized exclusion.

The difference in attributed spending was 39,046,537.14.

Under the candidate vocabulary mapping, these additional orders represent cancelled or refunded status variants that escaped exact-match filtering.

## Reconciliation

All 11 comparisons reconciled to zero.

The baseline control returned zero spending differences and 100 overlapping customers.

Unattributed order amounts were measured separately rather than silently assigned to existing customers.

## Business implications

Customer spending and customer prioritization are highly sensitive to the selected reporting rules.

Vocabulary normalization should receive early clarification, followed by spending eligibility.

The results support centralized status interpretation and explicit eligibility rules.

## Limitations

- Candidate status equivalence has not been approved by the client.
- Recorded order amounts are not independently verified accounting revenue.
- The currency is assumed to be GHS.
- The actual existing Monday report query was not available.
- All available order history was used.
- Monthly spending and running totals were not evaluated in this experiment.
- Financial differences must not be interpreted as actual losses.
- Ranking sensitivity does not establish priority over transaction safety.

## Reproduction

Script: `sql/01_diagnosis/05_status_sensitivity.sql`

Evidence: `evidence/05_status_sensitivity.txt`

No historical data was modified.