# Improvement beyond the brief: Monday report publication readiness gate

## The problem it solves
A report can arrive quickly yet mislead Nana. Historical orders have missing customer links, inconsistent valuations and incomplete item prices. Adwoa needs to distinguish a calculation defect from a known source limitation before releasing a report.

## What I built
`scripts/generate_monday_report.py` produces six CSVs, `readiness.json` and `manifest.json`.

- Two independent raw-table queries in `sql/07_improvement/` verify customer population, financial reconciliation, monthly and running totals, ranking and metadata within the same read-only snapshot.
- `config/readiness_policy.json` screens source exceptions. PASS means normal review; WARN means review and disclose; FAIL or ERROR means hold. No automatic release. The policy is proposed, not approved.
- The manifest records cutoff, run ID, snapshot, policy, Git state and hashes.
- `tests/test_report_readiness.py` passed 38 synthetic tests, including five focused R12 tests.
- The paired delivery benchmark verified identical CSV hashes across six executions.

## What it is worth to Nana or Adwoa
On 31 August the 525,563 report rows passed all four internal comparison checks. The gate warned about 1,624 discrepant orders (1.4587% of eligible orders), with absolute differences of 2,074,053.86 recorded monetary units (0.6108%); this is not proven loss. It also disclosed 144 unattributed orders worth 388,780.89 and 95 incomplete valuations associated with 455,904.42 in recorded checkout value. These exposures may overlap and must not be added. On 26 November, all four internal comparisons again passed across 525,563 rows; the same 1,624 discrepancies represented 1.4586% of 111,339 eligible orders. The report returned WARN / REVIEW AND DISCLOSE, with all seven output checksums and package identity independently verified. Adwoa can review a specific issue rather than trust a fast report blindly. Source completeness, historical status and currency remain unverified. No quantified savings or client approval claimed.

## What it cost
Three paired August runs: export-only median 9.419 s; full median 13.933 s; median paired additional time 3.902 s. Full peak Python RSS median 961.867 MiB. The November retry before R12 and August R12 generation took 21.886 s and 21.821 s internally; both exceed the proposed 20 s review trigger and were followed by Stage 08 automated results of 20.236 s (August), 22.131 s (November) and 18.648 s (empty); repeated breaches remain disclosed. No new production infrastructure required by the design. Maintenance, review and local data protection remain necessary. Retain current implementation at tested volume; see ADR-007 for revisit triggers. The original five-second SQL workload budget is separate and was missed in all six acceptance concurrent trials (D039). No agreed full-publication SLA. R12 now explicitly discloses empty eligible populations. Live verification returned WARN for 111,334 eligible orders and PASS for zero eligible orders; both packages passed integrity checks (E065a–E065d). PASS does not establish absence of business activity. Candidate fresh-load functional acceptance passed (E077c); final merged revision verification remains pending. HTML dashboards are future presentation work, not the implemented improvement claimed here.
