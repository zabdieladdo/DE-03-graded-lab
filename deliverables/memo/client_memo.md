# Memo to Nana

**From:** Zabdiel (Data Engineer)  
**Date:** 27 November 2026  
**Subject:** Protect stock sales and restore confidence in Monday reporting

## What I found
Your two reported overselling incidents are the most urgent risk. The supplied records also contain 14 products with negative stock, 1,023 broken links between records and 2,279 orders whose complete item values disagree with checkout totals. These are warning signs, not verified financial losses. I preserved the historical records rather than guess corrections.

## What I built
| What you asked for | Status | Evidence |
|---|---|---|
| Prevent overselling | Passed lab tests | All four supplied tests passed; 400 competing attempts produced 50 purchases, 350 refusals and no errors in 2.10 seconds. |
| Fast customer report | Working; speed varies | Report exports took 3.49 seconds alone and 4.23 during checkout in one trial each; earlier runs took 5.28–5.93 seconds. Checked delivery took 13–14 seconds in three August trials; a November generation took about 22 seconds. |
| Low-stock visibility | Passed lab tests | Nested categories checked; one measured calculation took under 0.002 seconds. Unassigned products are flagged separately. |
| Stock movement trail | Passed lab tests | New sales, restocks and corrections record before/after quantities and a reason; failed purchases leave no movement. |

## What I recommend
Use the existing server and review the Monday report before release. The new report check flagged 1,624 orders at both the August 31 and November 26 cutoffs whose item and checkout values disagree; their absolute differences total 2,074,053.86 in recorded units, not proven loss. Agree on the spending definition, currency and warning limits with finance. Investigate negative stock and unmatched records before correcting them. Retest if delivery repeatedly exceeds 20 seconds, report volume doubles or checkout slows.

## What I could not stand behind
I cannot certify historical stock, actual payments, complete source records or the original forty-minute report timing. The speed figures are local tests, not production guarantees. The proposed warning limits need approval. A final rebuild from the supplied data remains to be verified before release.
