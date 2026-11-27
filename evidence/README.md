# Consolidated evidence index

Status: consolidated submission evidence. Local privacy review confirmed; final merged revision verification pending.

Primary functional proof: `02_fresh_acceptance.txt`.

Historical transcripts retain their original identifiers.
Earlier failures and performance misses are preserved.
Functional acceptance is not performance certification.

## Evidence locations

| Original filename | Consolidated file | Lines |
|---|---|---|
| `00_baseline_load.txt` | `01_data_diagnosis.txt` | 7-45 |
| `00_baseline_reconciliation.txt` | `01_data_diagnosis.txt` | 52-60 |
| `00_bundle_verification.txt` | `01_data_diagnosis.txt` | 67-75 |
| `00_database_before_load.txt` | `01_data_diagnosis.txt` | 82-91 |
| `00_setup_verification.txt` | `01_data_diagnosis.txt` | 98-115 |
| `01_schema_inspection.txt` | `01_data_diagnosis.txt` | 122-210 |
| `02_referential_integrity.txt` | `01_data_diagnosis.txt` | 217-236 |
| `03_business_value_validation.txt` | `01_data_diagnosis.txt` | 243-315 |
| `04_business_impact.txt` | `01_data_diagnosis.txt` | 322-419 |
| `05_status_sensitivity.txt` | `01_data_diagnosis.txt` | 426-448 |
| `06_exception_investigation.txt` | `01_data_diagnosis.txt` | 455-557 |
| `07_raw_status_investigation.txt` | `01_data_diagnosis.txt` | 564-639 |
| `08_foreign_key_migration.txt` | `06_safety_and_recovery.txt` | 7-24 |
| `09_foreign_key_verification.txt` | `06_safety_and_recovery.txt` | 31-56 |
| `10_post_migration_integrity.txt` | `06_safety_and_recovery.txt` | 63-82 |
| `11_value_constraint_migration.txt` | `06_safety_and_recovery.txt` | 89-104 |
| `12_value_constraint_verification.txt` | `06_safety_and_recovery.txt` | 111-153 |
| `13_identifier_inspection.txt` | `06_safety_and_recovery.txt` | 160-184 |
| `14_identifier_migration.txt` | `06_safety_and_recovery.txt` | 191-210 |
| `15_identifier_verification.txt` | `06_safety_and_recovery.txt` | 217-249 |
| `16_schema_integrity_test.txt` | `06_safety_and_recovery.txt` | 256-309 |
| `17_place_order_deployment.txt` | `06_safety_and_recovery.txt` | 316-325 |
| `18_place_order_verification.txt` | `06_safety_and_recovery.txt` | 332-370 |
| `19_place_order_functional_test.txt` | `06_safety_and_recovery.txt` | 377-441 |
| `20_place_order_atomicity_test.txt` | `06_safety_and_recovery.txt` | 448-513 |
| `21_race_preflight.txt` | `04_concurrent_workload.txt` | 7-35 |
| `21a_race_environment.txt` | `04_concurrent_workload.txt` | 42-60 |
| `22_race_test_verbose.txt` | `04_concurrent_workload.txt` | 67-550 |
| `23_race_cleanup.txt` | `06_safety_and_recovery.txt` | 520-566 |
| `24_race_performance_analysis.txt` | `03_performance_comparison.txt` | 7-26 |
| `25_audit_race_retained.txt` | `06_safety_and_recovery.txt` | 573-595 |
| `26_inventory_audit_reconciliation.txt` | `06_safety_and_recovery.txt` | 602-655 |
| `27_retained_audit_cleanup.txt` | `06_safety_and_recovery.txt` | 662-725 |
| `28_reporting_profile.txt` | `03_performance_comparison.txt` | 33-122 |
| `29_reporting_date_investigation.txt` | `01_data_diagnosis.txt` | 646-729 |
| `30_reporting_foundation_deployment.txt` | `06_safety_and_recovery.txt` | 732-764 |
| `31_reporting_foundation_verification.txt` | `06_safety_and_recovery.txt` | 771-861 |
| `32_customer_summary_deployment.txt` | `06_safety_and_recovery.txt` | 868-885 |
| `33_customer_summary_verification.txt` | `06_safety_and_recovery.txt` | 892-978 |
| `34_customer_summary_baseline.txt` | `03_performance_comparison.txt` | 129-218 |
| `35_customer_summary_plan_investigation.txt` | `03_performance_comparison.txt` | 225-334 |
| `36_monthly_reporting_density.txt` | `03_performance_comparison.txt` | 341-390 |
| `37_monthly_reporting_deployment.txt` | `06_safety_and_recovery.txt` | 985-1012 |
| `38_monthly_reporting_verification.txt` | `06_safety_and_recovery.txt` | 1019-1127 |
| `38a_monthly_reporting_initial_failure.txt` | `06_safety_and_recovery.txt` | 1134-1191 |
| `38b_monthly_reporting_interrupted.txt` | `06_safety_and_recovery.txt` | 1198-1246 |
| `38c_monthly_reporting_timeout.txt` | `06_safety_and_recovery.txt` | 1253-1411 |
| `39_monthly_reporting_baseline.txt` | `03_performance_comparison.txt` | 397-532 |
| `40_monthly_export_measurement.txt` | `03_performance_comparison.txt` | 539-569 |
| `41_running_total_investigation.txt` | `03_performance_comparison.txt` | 576-618 |
| `41a_running_total_supplement.txt` | `03_performance_comparison.txt` | 625-666 |
| `42_running_spending_deployment.txt` | `06_safety_and_recovery.txt` | 1418-1438 |
| `42a_running_spending_inspection.txt` | `06_safety_and_recovery.txt` | 1445-1534 |
| `43_running_spending_verification.txt` | `06_safety_and_recovery.txt` | 1541-1603 |
| `44_running_spending_baseline.txt` | `03_performance_comparison.txt` | 673-867 |
| `45_customer_ranking_investigation.txt` | `03_performance_comparison.txt` | 874-938 |
| `46_customer_ranking_deployment.txt` | `06_safety_and_recovery.txt` | 1610-1642 |
| `46a_customer_ranking_inspection.txt` | `06_safety_and_recovery.txt` | 1649-1745 |
| `47_customer_ranking_verification.txt` | `06_safety_and_recovery.txt` | 1752-1864 |
| `48_customer_ranking_baseline.txt` | `03_performance_comparison.txt` | 945-1573 |
| `49_customer_ranking_jit_sensitivity.txt` | `03_performance_comparison.txt` | 1580-2537 |
| `50_monday_report_integration.txt` | `03_performance_comparison.txt` | 2544-2683 |
| `52_low_stock_rollup_deployment.txt` | `06_safety_and_recovery.txt` | 1871-1892 |
| `53_low_stock_rollup_test.txt` | `06_safety_and_recovery.txt` | 1899-1994 |
| `55_stock_movement_audit_deployment.txt` | `06_safety_and_recovery.txt` | 2001-2029 |
| `56_stock_movement_audit_test.txt` | `06_safety_and_recovery.txt` | 2036-2077 |
| `57_race_test_audit_regression.txt` | `04_concurrent_workload.txt` | 557-1038 |
| `57a_race_fixture_cleanup.txt` | `04_concurrent_workload.txt` | 1045-1049 |
| `58_integrated_workload.txt` | `04_concurrent_workload.txt` | 1056-1558 |
| `60a_readiness_reference.txt` | `05_publication_improvement.txt` | 7-56 |
| `60c_01_readiness_august.txt` | `05_publication_improvement.txt` | 63-83 |
| `60c_02_readiness_november.txt` | `05_publication_improvement.txt` | 90-110 |
| `60c_02a_november_failed.txt` | `05_publication_improvement.txt` | 117-120 |
| `60c_03_november_package_integrity.txt` | `05_publication_improvement.txt` | 127-135 |
| `60c_03a_november_integrity_failed.txt` | `05_publication_improvement.txt` | 142-150 |
| `61_readiness_fault_injection.txt` | `05_publication_improvement.txt` | 157-194 |
| `61b_readiness_regression.txt` | `05_publication_improvement.txt` | 201-238 |
| `62_readiness_performance.txt` | `05_publication_improvement.txt` | 245-260 |
| `64a_01_missing_database_url.txt` | `06_safety_and_recovery.txt` | 2084-2092 |
| `64a_locking_comparison.txt` | `03_performance_comparison.txt` | 2690-2701 |
| `64b_locking_comparison.txt` | `03_performance_comparison.txt` | 2708-2719 |
| `65a_readiness_r12_regression.txt` | `05_publication_improvement.txt` | 267-309 |
| `65b_readiness_r12_august.txt` | `05_publication_improvement.txt` | 316-337 |
| `65c_01_earliest_eligible_order.txt` | `05_publication_improvement.txt` | 344-350 |
| `65c_02_readiness_empty_population.txt` | `05_publication_improvement.txt` | 357-378 |
| `65d_readiness_package_integrity.txt` | `05_publication_improvement.txt` | 385-414 |
| `67a_fresh_clone_readiness_regression.txt` | `06_safety_and_recovery.txt` | 2099-2141 |
| `67b_fresh_clone_source_integrity.txt` | `06_safety_and_recovery.txt` | 2148-2156 |
| `68_acceptance_environment.txt` | `06_safety_and_recovery.txt` | 2163-2192 |
| `69_acceptance_baseline_load.txt` | `06_safety_and_recovery.txt` | 2199-2237 |
| `70a_acceptance_foreign_keys.txt` | `06_safety_and_recovery.txt` | 2244-2262 |
| `70b_acceptance_value_constraints.txt` | `06_safety_and_recovery.txt` | 2269-2285 |
| `70c_acceptance_identifiers.txt` | `06_safety_and_recovery.txt` | 2292-2312 |
| `70d_acceptance_schema_regression.txt` | `06_safety_and_recovery.txt` | 2319-2373 |
| `71a_acceptance_place_order_deployment.txt` | `06_safety_and_recovery.txt` | 2380-2390 |
| `71b_acceptance_place_order_functional.txt` | `06_safety_and_recovery.txt` | 2397-2462 |
| `71c_acceptance_place_order_atomicity.txt` | `06_safety_and_recovery.txt` | 2469-2535 |
| `72a_acceptance_reporting_foundation.txt` | `06_safety_and_recovery.txt` | 2542-2575 |
| `72b_acceptance_spending_summary.txt` | `06_safety_and_recovery.txt` | 2582-2600 |
| `72c_acceptance_monthly_spending.txt` | `06_safety_and_recovery.txt` | 2607-2635 |
| `72d_acceptance_running_spending.txt` | `06_safety_and_recovery.txt` | 2642-2663 |
| `72e_acceptance_customer_ranking.txt` | `06_safety_and_recovery.txt` | 2670-2703 |
| `72f_acceptance_reporting_foundation_test.txt` | `06_safety_and_recovery.txt` | 2710-2801 |
| `72g_acceptance_spending_summary_test.txt` | `06_safety_and_recovery.txt` | 2808-2895 |
| `72h_acceptance_monthly_spending_test.txt` | `06_safety_and_recovery.txt` | 2902-3011 |
| `72i_acceptance_running_spending_test.txt` | `06_safety_and_recovery.txt` | 3018-3081 |
| `72j_acceptance_customer_ranking_test.txt` | `06_safety_and_recovery.txt` | 3088-3201 |
| `73a_acceptance_low_stock_deployment.txt` | `06_safety_and_recovery.txt` | 3208-3230 |
| `73b_acceptance_stock_audit_deployment.txt` | `06_safety_and_recovery.txt` | 3237-3266 |
| `73c_acceptance_low_stock_regression.txt` | `06_safety_and_recovery.txt` | 3273-3369 |
| `73d_acceptance_stock_audit_regression.txt` | `06_safety_and_recovery.txt` | 3376-3418 |
| `74a_acceptance_race_preflight.txt` | `04_concurrent_workload.txt` | 1565-1594 |
| `74b_acceptance_connection_identity.txt` | `04_concurrent_workload.txt` | 1601-1605 |
| `74c_acceptance_official_race.txt` | `04_concurrent_workload.txt` | 1612-2094 |
| `74d_acceptance_race_cleanup.txt` | `04_concurrent_workload.txt` | 2101-2148 |
| `75a_01_identity_mismatch.txt` | `04_concurrent_workload.txt` | 2155-2169 |
| `75a_02_identity_match.txt` | `04_concurrent_workload.txt` | 2176-2182 |
| `75a_03_missing_container.txt` | `04_concurrent_workload.txt` | 2189-2196 |
| `75b_acceptance_integrated_workload.txt` | `04_concurrent_workload.txt` | 2203-2711 |
| `75c_acceptance_integrated_cleanup.txt` | `04_concurrent_workload.txt` | 2718-2765 |
| `75d_01_cleanup.txt` | `04_concurrent_workload.txt` | 2772-2819 |
| `75d_01_workload.txt` | `04_concurrent_workload.txt` | 2826-3347 |
| `75d_02_cleanup.txt` | `04_concurrent_workload.txt` | 3354-3401 |
| `75d_02_workload.txt` | `04_concurrent_workload.txt` | 3408-3929 |
| `75d_03_cleanup.txt` | `04_concurrent_workload.txt` | 3936-3983 |
| `75d_03_workload.txt` | `04_concurrent_workload.txt` | 3990-4511 |
| `75d_04_cleanup.txt` | `04_concurrent_workload.txt` | 4518-4565 |
| `75d_04_workload.txt` | `04_concurrent_workload.txt` | 4572-5093 |
| `75d_05_cleanup.txt` | `04_concurrent_workload.txt` | 5100-5147 |
| `75d_05_workload.txt` | `04_concurrent_workload.txt` | 5154-5675 |
| `76a_acceptance_readiness_reference.txt` | `05_publication_improvement.txt` | 421-471 |
| `76b_acceptance_readiness_august.txt` | `05_publication_improvement.txt` | 478-500 |
| `76c_acceptance_readiness_november.txt` | `05_publication_improvement.txt` | 507-529 |
| `76d_acceptance_readiness_empty.txt` | `05_publication_improvement.txt` | 536-558 |
| `76e_acceptance_package_integrity.txt` | `05_publication_improvement.txt` | 565-641 |
| `77a_cleanup_boundary_inspection.txt` | `06_safety_and_recovery.txt` | 3425-3462 |
| `77b_01_cleanup_regression.txt` | `06_safety_and_recovery.txt` | 3469-3517 |
| `77b_01_cleanup_regression_before_patch.txt` | `06_safety_and_recovery.txt` | 3524-3571 |
| `77b_02_portable_setup.txt` | `06_safety_and_recovery.txt` | 3578-3589 |
| `77b_02_portable_setup_before_patch.txt` | `06_safety_and_recovery.txt` | 3596-3612 |
| `77b_03_setup_identity_mismatch.txt` | `06_safety_and_recovery.txt` | 3619-3629 |
| `77b_03_setup_identity_mismatch_before_patch.txt` | `06_safety_and_recovery.txt` | 3636-3652 |
| `77b_04_setup_missing_container.txt` | `06_safety_and_recovery.txt` | 3659-3661 |
| `77b_04_setup_missing_container_before_patch.txt` | `06_safety_and_recovery.txt` | 3668-3684 |
| `77b_05_repo_inspection.txt` | `06_safety_and_recovery.txt` | 3691-3959 |
| `77c_01_runner_nonempty_guard.txt` | `06_safety_and_recovery.txt` | 3966-4052 |
| `77c_02_guard_cleanup_check.txt` | `06_safety_and_recovery.txt` | 4059-4107 |
| `77c_03_automated_fresh_acceptance.txt` | `02_fresh_acceptance.txt` | 1-1990 |

## Original archived transcript checksums

```text
48b5dac034adaeb32deb9b08daf0cab38b7d2345c6db851a8ef085c38b5b51a4  00_baseline_load.txt
28d56ec776ed172ce10d6562926de0f36c81a90598496494eb286bbf3e628230  00_baseline_reconciliation.txt
7b58cb7ccf178e1136a7329a999733cef9e67ef904b2af00cff61d4c0d8a1842  00_bundle_verification.txt
22cd3d6a4c9ef0f0d8ee417d38d408d6bff9b4c9fbb3a10c657e5957a115d602  00_database_before_load.txt
17eaae754346495c59ef8f35e1135a22abf209ac042138bfd944ac4b4ce59674  00_setup_verification.txt
948d0cef7544ad23062483562929b75df17318f5bd482f724b78bfc1c96fe284  01_schema_inspection.txt
bf65ccb4057f171d399c4dabe0ef83aff53415b49cfd1eb67d4945653f1e18b9  02_referential_integrity.txt
46263b8778c0c2022d99bdeab9b638b11bc78459d62abcc08bd9ee1d762b7c94  03_business_value_validation.txt
de7e1f3635606c5a023ee338773eac51a35873e93aff78c79026a037c65b64b4  04_business_impact.txt
10538fef4c89a00deaa981e2dc875a16c0e4ca416ef07b7eaea5252ffa4b5e2d  05_status_sensitivity.txt
0ad8510a13a4274b64e66733f19e92a70ae7bfb2fdf6ac9404a6626b7d6cd979  06_exception_investigation.txt
51fa61e20a5619a80b06b67c3410a70f2425734efe66c600dbca36ad045cb4c6  07_raw_status_investigation.txt
e59816410f110e485afbcbd74e2b6f960398301522b1498b1117850ad4919e07  08_foreign_key_migration.txt
b8478df6a271d007c3cdef8e49ab4ecf9ce77c70b8ba3c2907634febb6aa9567  09_foreign_key_verification.txt
bf65ccb4057f171d399c4dabe0ef83aff53415b49cfd1eb67d4945653f1e18b9  10_post_migration_integrity.txt
82f62477550a8064105feae4705eb78e57d94d862a8028394d9a0eaa8af726c0  11_value_constraint_migration.txt
331dfd6c0a7d626cd1400e1b2d090e5a291facc71c752d5356c94db765dc4b84  12_value_constraint_verification.txt
c9d7ea444694d3e23581b13fcc25be88de74255b20ad73f20516f3803438858d  13_identifier_inspection.txt
2278291c7901ef183cb940f70db269f358648c1438558d63ea2c22c8da2a0082  14_identifier_migration.txt
92804bfac7ae51cf8747f84a0e50e62c3ede3cbfd3678b161a8873a0eec22e23  15_identifier_verification.txt
e6b5dd56ad630e975be4313bc2e6a3ab2b3ca940b52133dfa637da2dd80c4c73  16_schema_integrity_test.txt
e4d9cf67d49f5dd28c271e4c13e6e8f1b3d20cf65bcb0ca470e51994c3b73dff  17_place_order_deployment.txt
52431dfd70abdc48694a003354d0027f5f9c9d0591482b93a4a04905dac6ed99  18_place_order_verification.txt
9f464f863614591871b15f9ffc444f72e9c0c5a78a6e82f5165d5d0297f421e6  19_place_order_functional_test.txt
257f124987d37771bff777d045c38c01764569324f4211ab644987ee86012e3c  20_place_order_atomicity_test.txt
05821d3bace040875028f8daba1350e71b6842b6981505e096cb7b4b0d00ddda  21_race_preflight.txt
4f7be84439e190b5e361910a4ea2835eef56b7bee7d4a5a9a02b6fae2fb1f2b3  21a_race_environment.txt
166a353a167d932b2cab4ea1480cf6e4da54e2bd9b37075737d5bb4b846d916f  22_race_test_verbose.txt
26f278abd00c3f0f14afc724189929ed8d682d8ea0b15ab7d0f84c62b849c020  23_race_cleanup.txt
5b7b3702151357368ee54283bd2b6f243893b8ee8d8ae90c3bd14b83e09a964f  24_race_performance_analysis.txt
67fbde6c7a98c7c7c2f92543b32b2bd3f38dde260a002a228a4109e5e099148e  25_audit_race_retained.txt
25335d7b9cdc5b4f162833a37022fafd0f4a44f7cea8e4c51063958f17aecfbf  26_inventory_audit_reconciliation.txt
a8b67b1e561cac4b34b63ba669f2a6cd4181ef7a3c5e69596081a6521b71b064  27_retained_audit_cleanup.txt
feaf4c349d8c88e3ccd00978eccee36a88577bf6387fe3a041eec96db74985ee  28_reporting_profile.txt
2ce10e8f3bd9728fd90d13d0fbb5046fffe07757e3ea78915ad8da54ec4c6cf8  29_reporting_date_investigation.txt
3ae9bfb79b46b0b4802ea37603197061bee6c716cf18d9b47ccd22171fb92b7c  30_reporting_foundation_deployment.txt
a49f6f845aae33456c6d621303ef507538b876c6c6a38211ea5c66b6c96f3537  31_reporting_foundation_verification.txt
c5e28e5844c5bff0097e7dc335789fad608957201b6937144fb06ba972e7f2e8  32_customer_summary_deployment.txt
eaf5eb18cff19830ecc077b9e2ef415b9b6d6d626c2e361c7eb8f0af57e228d5  33_customer_summary_verification.txt
35a4c0aec9eb43ce63fa73e089a3806f98453c9ba0690b97002b27edcc8bd0e5  34_customer_summary_baseline.txt
6e01b096fd4b1059a223fd833cd5bb8f5c2bffa360757473b639df395f7e8fbe  35_customer_summary_plan_investigation.txt
ac6576a21a355eba46b9a1426b642cd35412b41020754c621b102a38879840e8  36_monthly_reporting_density.txt
5c36e69dda4639e86c57c5887f8414e7db8a72925fccdf7ed5b3329600cc429d  37_monthly_reporting_deployment.txt
d4f0bd70130ef1754c184c9ad4c7f09072236b8b99eb80efe5f29663e85bcbdb  38_monthly_reporting_verification.txt
6b8765380dee262b63d26853a05399ecab53ef136b8b656ad70871768474672a  38a_monthly_reporting_initial_failure.txt
47a1baea500af3ee91cf6fa2441c76318124fb7da0de8a47b71166df31b4d764  38b_monthly_reporting_interrupted.txt
30ba7e304a0b57d912592962f1aa9d1c1005cdcebe8f3e58c87e6aa9236e5079  38c_monthly_reporting_timeout.txt
eb16bb8633351ba0800deafef3252b197ee842d90cdbe1251fca43d71e342a45  39_monthly_reporting_baseline.txt
90db5a5b54a986a59dc4e097ec6d3bc39c19b16907cd83ffc60e3cc346d4ff74  40_monthly_export_measurement.txt
fe055fe3c7a1651e6f4ec17b91b76149491635cd7d97f25a95c86a902cc7e949  41_running_total_investigation.txt
37e8bc0d79f47d5a9bdf00a76d421a00b57a0d4f4d9d1b545a6d987aea33dc90  41a_running_total_supplement.txt
24d8a5810ac96ec0b843bb7ac9aad91947e434bcb81bd3ca958de411c586ee84  42_running_spending_deployment.txt
7765f0cd7222d5348a8fdf8789b2b5b8122e60d0150fc146308dae2d975791d2  42a_running_spending_inspection.txt
5f33b647f8f5df9e1d918c82a0d2d9a707309b018fdc05cdd67d6efe096b85d8  43_running_spending_verification.txt
ddc4819c28759e98d65cc75b90617c03d484361ffead26a78c1fc8705171a29c  44_running_spending_baseline.txt
dc51b6fe9255f3a6b8bd489c1ec23bdcbbb6ede0cbdf03e51a48283486cec2f3  45_customer_ranking_investigation.txt
033b3dda93500a2bfbb21f5049ee62aca1221d1aa4fc91dc7dd7ba6a99b338d5  46_customer_ranking_deployment.txt
b37352a82c369716e0c1828c0543095eb9e1cfd2791906a1b08c3bd69ee468b9  46a_customer_ranking_inspection.txt
5b7fe54be66e390207e27abead2561bb03b4a2c2fd865ccdabb9f9a2b1a96776  47_customer_ranking_verification.txt
1c5ec51381277ea5ecdc94bd3c55807626540bd248614f61c8004bca3cfd3b9f  48_customer_ranking_baseline.txt
d95af9b6e5a56edf3e9859fdbf6eb1ebf81f41fdf58fe318b4f850aa6967124f  49_customer_ranking_jit_sensitivity.txt
407b4121dd3b684561d59b118faf5828817e7173ca91d4fe65b774d3f2c4286b  50_monday_report_integration.txt
b704f272264f3cbd1eba65c67ceae96f56f0db48fb1de7450af9cbf6b39a0103  52_low_stock_rollup_deployment.txt
e5e5b32f9c4a18e0e10b310dcce2ead88f703850430e718eb0d56ca2c3453ed0  53_low_stock_rollup_test.txt
be4a4dcd902a14b06d07c949791b424b04b9a4ab4ff3fd73537560bfb861fa57  55_stock_movement_audit_deployment.txt
bc57f99a9c142fed6c81094c7fd92ad99b54c54f5569aa67e1161bc15b8b3a44  56_stock_movement_audit_test.txt
454c31eb6e2d38aab592a1bb67e0df45dcefacd5ee63221284a869b9d6864508  57_race_test_audit_regression.txt
b979e03126f7bc5209f023de95fcc80eb553ba3afad9a16dbb23ba41852869e7  57a_race_fixture_cleanup.txt
bd811771ba718e923c2ff084c27b14f2354332eed9b09bd861f92b20b1dbb539  58_integrated_workload.txt
9478fad13f45d9b2f24a354ae980aa26a8fd8447848bf99932c030022b73c036  60a_readiness_reference.txt
64aaf66967cf7950092da6b802c34204f6c3109f736663d389b2b92e3787bc75  60c_01_readiness_august.txt
bec2e45d75a301304d4bd1caecebc08fa785701dd007282c1c407ddc49265dc5  60c_02_readiness_november.txt
c53c28d288b3df54993c3fd1e673cc788528823223980fee3ec0f0505d30a3b0  60c_02a_november_failed.txt
f4c2606c305b035c0c22f6b910e45e351ac10ad5afd80444656c8efa47b63c64  60c_03_november_package_integrity.txt
98cf0d665166e2044b94c7dbd95c1c9b3957f0fe82ee5192ed5af6dea6c9ada9  60c_03a_november_integrity_failed.txt
fd3c82fce05fd5df472e16cdcc4326be194884a69a11ed6d24f6c8e72896d9df  61_readiness_fault_injection.txt
27adefab0ee9f6d81a3c676cc6ffae5f8d479f827b1ca868b77be1a4cdc2e1fb  61b_readiness_regression.txt
1822595d56d3f1bbb50ca07b5618ec3fcdb07eb8c0438e004fb725f06ba7b95b  62_readiness_performance.txt
76b472f3f88580f7566132294387433937900f63ce61304baa8f4ae12b496367  64a_01_missing_database_url.txt
698ed8aedaa1a2b08e3936fa5db4ac6c03186a3ad8b5fd5d05d126988fde9d75  64a_locking_comparison.txt
afb320f06dfdefe4763aab34e966b9ab6c460d36aadc00a9e79cd65758e5f302  64b_locking_comparison.txt
d66508dbe7ffd7649a57700c104beec35d86ca0539d4a87a093a0bd550f31cd7  65a_readiness_r12_regression.txt
55b11f0b9b137173d2f7f83fa2ecaf405132f69804054a2a0739f534c409ce20  65b_readiness_r12_august.txt
0ce6e11ea1affeddad5a2ff83c466ea0e2d1842cd1b48c2e2fdf9778fc4ff4cb  65c_01_earliest_eligible_order.txt
365d49f00dc086eda0a7cad4d56b08b962314a117f71c454d22f22f4095ad7b8  65c_02_readiness_empty_population.txt
a03c23d007a26f7c462099d8ebc52d61ce233251638ebbda5b1b7c6f39becfa4  65d_readiness_package_integrity.txt
4f872a1de2e50088576de56235d2c25dd200d163ae71d9ffe8267b6d23b8c268  67a_fresh_clone_readiness_regression.txt
7b58cb7ccf178e1136a7329a999733cef9e67ef904b2af00cff61d4c0d8a1842  67b_fresh_clone_source_integrity.txt
37827b180c364fedee44b74d2a25b00c83613ddb6209f3d24d7e05a3021705a6  68_acceptance_environment.txt
4cc5d5da204dbdcb06af2fd9b8687c14fe048db24448e423d0a92c8692d45660  69_acceptance_baseline_load.txt
65f42a8c3041b1ee09fcb6d49d9ec9b2838341afd20116acfdb02f8b4ee07661  70a_acceptance_foreign_keys.txt
7d598cf1d8f5b4835f33b9cb338d00f3e30a6caf1b69ebf6e20ecc23a039408a  70b_acceptance_value_constraints.txt
e77c75b58235a4f0a3e39b5bea1112089c37b105cd35d152b955b84b53117ca2  70c_acceptance_identifiers.txt
52b21155f7fff38f7939bf1aa831c1c0f4f763dc027404bced395f987e6bdadd  70d_acceptance_schema_regression.txt
b60ce3d4e6dc8e38f435fb971887900a9d25866b2bdc265cba08db2c820e3e0f  71a_acceptance_place_order_deployment.txt
060d4e120d8ad1146a386bfc828e97b9710eacd0aba443d05c53902e00ec0bb6  71b_acceptance_place_order_functional.txt
77952420d1af4098c91160a42a6cafed23184077b9774a721d9cff203d4c70ac  71c_acceptance_place_order_atomicity.txt
48b3630aae2fc14da543df5c2ac965de492c47f898c67216115f3293758d330a  72a_acceptance_reporting_foundation.txt
d837e76a0201c50ce172a02116f62aa831deced1fed514f3ebb79a69ff600833  72b_acceptance_spending_summary.txt
61e28d9bd60b73f2986c6077804354f8db8c6a5c8d23f15bad192994c7227366  72c_acceptance_monthly_spending.txt
fc0a30cf9f54cddc9644e573d0aabcb375e3fb516939190514e5f9cece87761d  72d_acceptance_running_spending.txt
0b1ffb065433a2491a88108d70bf8e629bbffc05748a49ec29fdd9cc40aa0eb9  72e_acceptance_customer_ranking.txt
83ef1d3f519134c34dd109c8839185bab6ed411b890c90fbe1b862c1105c3ad9  72f_acceptance_reporting_foundation_test.txt
f8eb23d7da79df6aba64d88dc78a42ca7cc61da69158f626f38b7ef00a8643fa  72g_acceptance_spending_summary_test.txt
f3ba35324f03d0651e9296e42004d946378af53e38193740dc2c0c6f56dd66a3  72h_acceptance_monthly_spending_test.txt
e446c56f219719ac0a8388676b1aef0dbc03d5f2b69a2bc136fafa483445d3f5  72i_acceptance_running_spending_test.txt
53c432505dcdcec21e814799942967130bc8c0cb0f638a04b450facd9a73930c  72j_acceptance_customer_ranking_test.txt
606d077b078b4ec0c9177a7e3abaef6c21ec411a002421c05f3bba2baae43813  73a_acceptance_low_stock_deployment.txt
f8379cc390a11360e4db4100d64edfb8f1cdfa177694e5efa2e97e9be818a2fc  73b_acceptance_stock_audit_deployment.txt
b0188ed121988a2d017f9409d2d9f861fbe4dbd7aed6675cc88006a08b8c6c82  73c_acceptance_low_stock_regression.txt
7a55efa6e61e7a8c8a5239d7332ab65a156c92015e71173063c7f5a01e587c06  73d_acceptance_stock_audit_regression.txt
0ff7037825ead57a14760b8889c121d9e0bd75bb331b305a0d909bb3c9d2c98f  74a_acceptance_race_preflight.txt
74588e46c7ec7aa48b904a163597296d0ae172b8f4a2ecc5349482efb2405a86  74b_acceptance_connection_identity.txt
339cfd2941565bf00cdea41942beed0b7eb6e7b811b0d716ec677cf8156f27ad  74c_acceptance_official_race.txt
bd443267a1ce413a8e76adc9e10be379339230a06ead5a6f18fd4501f56e88e4  74d_acceptance_race_cleanup.txt
5e88cbfbe8e49bfef36dec70403d214afdc31837396a99c03d441b736f17a6cb  75a_01_identity_mismatch.txt
c93e052e28978c7283ee6510eb47233cf2a20f7953a3431d98df8f3cf8b8c38c  75a_02_identity_match.txt
985c81b3a24ac9b1ffc0abd283764ca22eca88ad408f508e14a9217487e54ff6  75a_03_missing_container.txt
1053449cc7fb8e99781ac64cf96d72904b2e1a5a8ade9584ade08bf6dad3e4ab  75b_acceptance_integrated_workload.txt
52b5aa910519373875e640e409c659a894fdfef621cc8d0c73a430bbfb4441ce  75c_acceptance_integrated_cleanup.txt
5d52178dabefd929b3bc64522cd86d65fe0f9d1acef22c36e6de2cf8aa1688b7  75d_01_cleanup.txt
021959e47604a8eb4134301bd0118c986f1a243bc6becd4588f9d7f5c2cb785b  75d_01_workload.txt
a860da3f93f971556e49383d5377845ed454e1b0bce137884d583bbb103ed0b1  75d_02_cleanup.txt
8550ed7501b39501f1e2e3b843e80e24adf68236d090f387fe82b7c6e606c6fe  75d_02_workload.txt
1aeb40cf05ca3d244730a008f29e2820501b8ba10268cf92698bc3d51ca42cfd  75d_03_cleanup.txt
962a1ced301da809282c9ebc9640d5a8e6aa6a41f45c456ac855c9f0bbe95701  75d_03_workload.txt
e0bcc3f2e9d8a70219bf881871fea90df3f5c9669420211bcab9d9e3d4d31746  75d_04_cleanup.txt
503e1866de9cb5ffa5956819fc211b17a0b8f4296e372ae4482320b3d53683aa  75d_04_workload.txt
b67d70a9a7cc49b683220ed1b129fded6c725b93d8b50c5c19404190e4065e76  75d_05_cleanup.txt
fa0e963108b2fc08791f8f83ff4b95ea49933ba75a22fbc4ccc73947aee15add  75d_05_workload.txt
fd6db5e7993b865082131829eb0319ba23579e10bf85cce227044a44ed9fceee  76a_acceptance_readiness_reference.txt
4cb37368dc4598048139813af4da89a0cc21d67c9a669fca0a184bcebbb60f73  76b_acceptance_readiness_august.txt
8e3ba8ddd3495f18ebd5a7f85dfac0327df968941083b562b36fed41303f4c67  76c_acceptance_readiness_november.txt
123dae7c3cfa99a077e4c3b42039a36a0125feee79aad2fd8987d8bbad4eb70b  76d_acceptance_readiness_empty.txt
e0aa069806782a778aea91246cbb0cbe32cc4a3f862b30051ff13bcc437fbebf  76e_acceptance_package_integrity.txt
29b033d1595ebaf72652569b732c7cf6c4e46b586227b2e3d15a7e923a06d3e3  77a_cleanup_boundary_inspection.txt
2dccd55be617f5923960befdf52cb73e654c2791db6f027642cf0fd70947e7e9  77b_01_cleanup_regression.txt
221d34ccdc738880f5912da658b01e0878aba9b5b47f93735cc9cf5f94aa68a5  77b_01_cleanup_regression_before_patch.txt
218d0fa25b85c3b595997de1cdd4bcad3d718ba23f9eb0efb9e9ff49f9f2f25b  77b_02_portable_setup.txt
2e365f7c3b416f5fe97548d618009b19adfb2a7f06bc2d99b91cbbf3f31cbf83  77b_02_portable_setup_before_patch.txt
b0d325196a810efdb226c0f9be0f201b4fad364c77262faabff0571c24d6266c  77b_03_setup_identity_mismatch.txt
2e365f7c3b416f5fe97548d618009b19adfb2a7f06bc2d99b91cbbf3f31cbf83  77b_03_setup_identity_mismatch_before_patch.txt
2b17e5d117d5312a2101cdd7d5d9dc792db453aba4944c2b252d5208fc0524e6  77b_04_setup_missing_container.txt
2e365f7c3b416f5fe97548d618009b19adfb2a7f06bc2d99b91cbbf3f31cbf83  77b_04_setup_missing_container_before_patch.txt
b20790f1ccd22897d2e26287e04598ca0f285f441f69362a76a12ef1c30de12b  77b_05_repo_inspection.txt
5b795823adca6b83bcbca09027c18b6b70f85379d66817dcfb09809f4796e4a3  77c_01_runner_nonempty_guard.txt
7c0eaef9b5aa53de0c42804a1cf5cb85c81bd5a1c5d8d58c2e5c09fa64b2846c  77c_02_guard_cleanup_check.txt
910861bc76030979da43af01323b2c97e95516cfe2e3aa1ce00df27d8c3ba228  77c_03_automated_fresh_acceptance.txt
```

## Anonymization notice

Personal filesystem paths and machine identifiers have been anonymized in these submission copies. Original archived transcript checksums identify the unmodified private evidence, not these copies. Test results and measurements have not been intentionally changed.

## Integrity verification

- Original archive: 149/149 files verified.
- Consolidated evidence: 148/148 transcripts verified.
- All original transcript line mappings verified.
- Local customer-information review confirmed.
- Targeted personal identifiers anonymized.

## Submission formatting normalization

Trailing spaces and tabs inherited from terminal output
were removed from the consolidated submission copies.

This formatting normalization preserves line counts,
evidence mappings, measurements and test outcomes.

Original archived transcript checksums refer to the
unmodified private records.
