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
