# Investigation Questions

## Revenue and customer reporting

- Q01: Which order statuses should contribute to customer spending?
- Q02: Do different status spellings represent the same business state?
- Q03: Can every order be attributed to an existing customer?
- Q04: Does recorded order value agree with its order items?
- Q05: What should happen when a customer identity is ambiguous?

## Inventory and order placement

- Q06: Are any existing stock quantities negative or unknown?
- Q07: Can every order item be attributed to a valid order and product?
- Q08: Can every inventory movement be attributed to a valid product?
- Q09: What guarantees prevent two buyers purchasing the last unit?
- Q10: Can historical inventory movements explain current stock?

## Category hierarchy

- Q11: Does every non-root category have a valid parent?
- Q12: Are there cycles in the category hierarchy?
- Q13: How should uncategorised products be represented?
- Q14: What business threshold defines low stock?

## Reporting performance

- Q15: Which report operations consume the most time?
- Q16: Which indexes or query changes would improve performance?
- Q17: What additional costs would those changes introduce?

## Investigation rules

- Do not assume every unusual value is defective.
- Distinguish observed facts from business assumptions.
- Do not invent missing historical records.
- Do not delete or modify source data during diagnosis.
- Quantify the scale and business impact of confirmed findings.
- Record anything that cannot be verified.

## Investigation outcomes

| Questions | Outcome and remaining uncertainty | Evidence |
|---|---|---|
| Q01–Q05 | Normalize completed statuses; preserve IDs; disclose orphan attribution and valuation gaps. Finance must confirm currency and spending semantics. | [ADR-003](../decisions/ADR-003-spending-semantics.md), [findings](../diagnosis/data_findings.md) |
| Q06–Q10 | 14 negative stocks; broken references preserved; conditional update and movement audit verified. Historical opening stock remains unknown. | ADR-001, ADR-002, ADR-006 |
| Q11–Q14 | Cycles and missing parents excluded from rooted rollup; exceptions visible; threshold 10 provisional and configurable. | ADR-005 |
| Q15–Q17 | Dense monthly report is a major cost; direct ranking measured against sparse alternative. D039 retains on-demand architecture despite six concurrent target misses; D037 retains verified publication despite repeated 20 s trigger breaches. Client timing and materiality remain unconfirmed. | ADR-004, ADR-007 and performance reports |

Open business questions: authoritative currency, financial materiality, extract completeness, opening stock, customer identity and publication approval.
