# Evidence and decision index

`D` identifiers refer to internal engineering decisions; `E` identifiers refer to recorded verification exercises. They are not course or rubric identifiers. Formal decisions are in `deliverables/decisions/`. Evidence paths are relative to the repository root; Historical filenames were checked against the supplied evidence archive; new retry and benchmark paths follow the terminal commands and should be confirmed in the final checkout.

| Decision | Meaning | Formal record |
|---|---|---|
| D014 | Preserve raw statuses and normalize for reporting | ADR-003 |
| D016 | Completed-only eligibility | ADR-003 |
| D017 | Preserve extreme quantities | ADR-001 / data findings |
| D018 | Configurable low-stock threshold | ADR-005 |
| D019 | Preserve customer IDs | ADR-003 |
| D021–D024 | Constraints, identity allocation and atomic purchase | ADR-001 / ADR-002 |
| D025–D031 | Header totals, cutoff, monthly grain, running totals and ranking | ADR-003 |
| D032 / D035 | Retain on-demand reporting provisionally | ADR-004 |
| D033–D034 | Recursive rollup and movement audit | ADR-005 / ADR-006 |
| D036–D037 | Publication readiness and retained export architecture | ADR-007 |

| Exercise | Meaning | Evidence locator (under `evidence/`) |
|---|---|---|
| E019–E020 | Purchase functional and failure atomicity tests | `19_place_order_functional_test.txt` / `20_place_order_atomicity_test.txt` |
| E022 | Original official race harness | `22_race_test_verbose.txt` |
| E025–E027 | Retained audit race, reconciliation, cleanup | `25_audit_race_retained.txt` / `26_inventory_audit_reconciliation.txt` / `27_retained_audit_cleanup.txt` |
| E031 | Reporting foundation tests | `31_reporting_foundation_verification.txt` |
| E033–E034 | Customer summary correctness and timing | `33_customer_summary_verification.txt` / `34_customer_summary_baseline.txt` |
| E038–E040 | Monthly tests, plans and export timing | `38_monthly_reporting_verification.txt` / `39_monthly_reporting_baseline.txt` / `40_monthly_export_measurement.txt` |
| E043–E044 | Running totals correctness and timing | `43_running_spending_verification.txt` / `44_running_spending_baseline.txt` |
| E047–E049 | Ranking correctness, alternative comparison and JIT sensitivity | `47_customer_ranking_verification.txt` / `48_customer_ranking_baseline.txt` / `49_customer_ranking_jit_sensitivity.txt` |
| E050 | Integrated six-output report | `50_monday_report_integration.txt` |
| E052–E053 | Recursive rollup deployment and verification | `52_low_stock_rollup_deployment.txt` / `53_low_stock_rollup_test.txt` |
| E055–E057 | Audit deployment, tests and official race regression | `55_stock_movement_audit_deployment.txt` / `56_stock_movement_audit_test.txt` / `57_race_test_audit_regression.txt` |
| E058 | Integrated reporting and checkout | `58_integrated_workload.txt` |
| E060a | Independent reference | `60a_readiness_reference.txt` |
| E060c | August and November publication | `60c_01_readiness_august.txt`, `60c_02_readiness_november.txt`, `60c_03_november_package_integrity.txt` |
| E061 | Readiness fault injection | `61_readiness_fault_injection.txt` |
| E062 | Paired delivery benchmark | `62_readiness_performance.txt` |
| E061 regression | 33 tests passed after comment-only revisions | `61b_readiness_regression.txt` |
| E064a–E064b | Isolated conditional update versus explicit locking | `64a_locking_comparison.txt` / `64b_locking_comparison.txt` |
| E065a | R12 regression: 38 tests passed | `65a_readiness_r12_regression.txt` |
| E065b | R12 normal population: WARN, 111,334 eligible orders | `65b_readiness_r12_august.txt` |
| E065c | Earliest eligible date and empty population: PASS | `65c_01_earliest_eligible_order.txt` / `65c_02_readiness_empty_population.txt` |
| E065d | Both packages verified: 14 checksums | `65d_readiness_package_integrity.txt` |

November retry and integrity verification both exited 0. Earlier failures remain in `60c_02a_november_failed.txt`, `60c_03a_november_integrity_failed.txt` and `64a_01_missing_database_url.txt`. No private defence notes are needed to interpret this index.

## Stage 08 closeout

| Decision / exercise | Result | Original evidence locator (under `evidence/`) |
|---|---|---|
| D038 / E075a | Explicit container and cluster identity guard | `75a_01_identity_mismatch.txt`, `75a_02_identity_match.txt`, `75a_03_missing_container.txt` |
| D039 / E075b–d | Retain architecture; all six concurrent five-second misses disclosed | `75b_acceptance_integrated_workload.txt`, `75d_01_workload.txt` through `75d_05_workload.txt` and corresponding cleanup files |
| E067–E074 | Independent manual fresh-load verification | `67a_fresh_clone_readiness_regression.txt` through `74d_acceptance_race_cleanup.txt` |
| E076 | Three publication packages and independent checks | `76a_acceptance_readiness_reference.txt` through `76e_acceptance_package_integrity.txt` |
| E077b | Portable setup and cleanup corrections | `77b_01_cleanup_regression.txt` through `77b_05_repo_inspection.txt`; before-patch failures retained |
| E077c | Nonempty guard and automated candidate fresh-load PASS | `77c_01_runner_nonempty_guard.txt`, `77c_02_guard_cleanup_check.txt`, `77c_03_automated_fresh_acceptance.txt` |

The candidate run was based on 739e19c with uncommitted verification changes. Final merged revision verification is pending. Original evidence names remain stable identifiers. The consolidated evidence index maps all 148 original transcripts to their current files and line ranges.

## Consolidated evidence navigation

Use the [consolidated evidence index](../evidence/README.md) to locate original transcript identifiers and verified line ranges. Historical filenames in the tables above are identifiers, not standalone repository paths.
