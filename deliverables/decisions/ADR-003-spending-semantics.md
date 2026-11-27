# ADR-003: Define customer spending from eligible recorded order totals

- **Status:** Accepted
- **Date:** 2026-11-27
- **Decision owner:** Zabdiel Addo (review before submission)

## Context

Kloud Kart needs consistent customer spending, counts, monthly totals, running balances and top-100 rankings. The extract contains inconsistent status spelling, orphan orders, financial discrepancies, sparse recent activity and duplicate customer emails. Nana is unavailable to confirm definitions. The decisions below consolidate D016, D019 and D025–D031; they are engineering assumptions, not client-approved accounting policy.

## Decision

I count normalized completed orders through an explicit reporting date using their recorded order-header totals, attribute them by customer ID, and report unattributed eligible amounts separately. I retain all current customers, a twelve-calendar-month window including the cutoff month, explicit opening balances and deterministic top-100 selection, with recorded-history and transaction-level alternatives available.

- Normalize case and whitespace; treat `complete` and `completed` as completed. Exclude shipped, pending, cancelled, refunded and unknown statuses from spending. This is recorded spending, not independently verified cash receipts or recognized revenue.
- Use `orders.total_amount` rather than reconstructing totals from item prices. Preserve and flag discrepancies and missing prices; do not silently repair history.
- Use the customer primary key, not email. Retain customers without eligible orders with zero totals and counts; dates without activity remain NULL. Do not invent customers for orphan orders.
- Include timestamps strictly before midnight following the supplied date. The twelve-month window begins on the first day of the month eleven months before the cutoff month. Flag partial months; preserve and separately identify missing or post-cutoff dates. Use 2026-08-31 as the fixed headline and 2026-11-26 as sensitivity, not as proof of extract completeness.
- Provide sparse monthly activity and dense monthly output with twelve rows per current customer, including zero-activity months. A wide export is supplementary. Zero means no eligible record found, not verified absence of business.
- Compute monthly and transaction running balances using explicit ROWS frames; transaction ordering is timestamp then order ID. Add pre-window opening spending once to the window cumulative amount. Recorded history is not proven lifetime history; pre-window transaction window cumulative is NULL.
- Rank positive-spending customers by exact numeric spending. Default to trailing twelve months; recorded history is optional. Use ROW_NUMBER ordered by spending descending then customer ID ascending for up to 100 selections; use RANK by spending alone for true ties across the full qualifying population. Report cutoff ties, selected/excluded counts and amounts separately. Customer ID is an arbitrary reproducible tie-break, not a reward fairness policy.

## Alternatives considered

### Alternative A: Include shipped or pending orders

- **How it would work:** Expand eligible statuses.
- **Why it is attractive:** May represent fulfilled or expected business earlier.
- **Why rejected:** No payment or completion evidence establishes that these amounts are realized. Unrestricted completed+shipped adds GHS 40,918,016.89 to attributed spending (12.06%); adding pending as well adds GHS 89,262,456.01 (26.31%). Ranking membership changes materially (80 and 67 of the original top 100 retained respectively).

### Alternative B: Reconstruct spending from line items

- **How it would work:** Sum quantity times unit price per order.
- **Why it is attractive:** Provides item-level traceability.
- **Why rejected:** 148 missing item prices affect 147 orders; 2,279 comparable orders disagree with headers, with GHS 3,760,997.98 absolute difference. Discounts, fees and corrections are unverified. Neither measure proves actual revenue or loss.

### Alternative C: Merge by email or omit inactive customers

- **How it would work:** Deduplicate identities by email and report only customers with activity.
- **Why it is attractive:** Smaller outputs and apparently cleaner identities.
- **Why rejected:** 533 duplicate email groups affect 1,068 customers; identity equivalence is unverified. Omitting inactive customers violates the per-customer report intent.

### Alternative D: Rolling 365 days, sparse-only months, or window-only running balances

- **How it would work:** Use day-based boundaries, omit inactive months and start cumulative balances at zero.
- **Why it is attractive:** Fewer rows and simpler calculations.
- **Why rejected:** Calendar buckets support monthly comparisons; opening balances matter (GHS 4,542,077.88 at headline, GHS 26,170,939.50 at sensitivity). Dense output costs more but preserves explicit months; sparse and window-only measures remain available.

### Alternative E: Include all cutoff ties using RANK <= 100

- **How it would work:** Return every customer tied at the boundary.
- **Why it is attractive:** Avoids arbitrary exclusion among equal spenders.
- **Why rejected:** May exceed 100 customers. Deterministic selection plus tie metadata preserves both the requested size and transparency. If used for rewards, obtain a client-approved tie policy.

## Consequences

- **What this buys:** Reconciled definitions, reproducible dates, complete current customer coverage and transparent exceptions. E031/E033/E038/E043/E047 and E050 support correctness; E050 passed six cross-report assertions across both dates. At headline, attributed history GHS 339,176,836.88 plus unattributed GHS 388,780.89 equals eligible GHS 339,565,617.77; attributed opening plus window GHS 334,634,759.00 equals attributed history. E047 synthetic ties verified one selected and two excluded among three customers tied at cutoff.
- **What this costs:** Dense monthly output is 485,040 rows, 80.89% with zero orders at headline. Multiple scopes, metadata and exceptions require maintenance and explanation.
- **What it costs the client if I am wrong:** Spending may be misstated, customer priorities or rewards may change, and apparent inactivity may be mistaken for missing data or declining sales. Incorrect opening balances can distort customer history. Header/line differences are not established financial losses.
- **What would make me revisit this:** Confirmed payment/refund rules, verified identity mapping, authoritative accounting adjustments, earlier history, agreed period or tie policy, or verified extract completeness.

## What this survives

Changes in order volume, month boundaries, customers with no orders, opening-only customers, cutoff ties and post-cutoff records without silently changing definitions. It does not reconstruct historical customer populations or status changes; the extract contains current values. Fresh-load and final operational acceptance remain pending.
