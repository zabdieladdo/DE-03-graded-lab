# Verification Register

Status definitions: NOT STARTED, IN PROGRESS, PASS, FAIL, BLOCKED.

| ID | Verification | Status | Evidence |
|---|---|---|---|
| V-001 | PostgreSQL major version 18 | PASS | Observed 18.7 |
| V-002 | Maximum connections 500 | PASS | PostgreSQL and Python output |
| V-003 | Learning and graded databases exist | PASS | Database setup output |
| V-004 | Python graded database connection | PASS | kloudkart_lab connection verified |
| V-005 | Default transaction isolation | PASS | read committed |
| V-006 | Original bundle unchanged | PASS | Nine checksum matches |
| V-007 | Graded database pre-load inspection | PASS | No visible tables or public functions |
| V-008 | Standalone Git repository | PASS | Verified repository root |
| V-009 | Revised setup scripts | PASS | Both database endpoints passed; evidence/01_data_diagnosis.txt (original: 00_setup_verification.txt; lines 98-115) |
| V-010 | Credential exclusions | PASS | Local exclusion and credential review completed |
| V-011 | Initial Git commit | PASS | Verified commit 5a12818 |
| V-012 | Official submission requirements | BLOCKED | Evalu8 confirmation needed |
| V-013 | Graded baseline data load | PASS | `evidence/01_data_diagnosis.txt (original: 00_baseline_load.txt; lines 7-45)` (confirm local file) |
| V-014 | Six-table row reconciliation | PASS | 822832 records; all six differences zero |
| V-015 | Candidate fresh-load functional acceptance | PASS | E067–E074 manual; E077c automated exit 0 |
| V-016 | Schema migration and tests | PASS | evidence 08–16; 24 checks |
| V-017 | Purchase and rollback | PASS | evidence 19–20; 11 and 10 checks |
| V-018 | Official race harness | PASS | evidence 22 and 57; four scenarios each |
| V-019 | Reporting correctness | PASS | evidence 31, 33, 38, 43, 47, 50 |
| V-020 | Provisional five-second concurrent reporting gate | FAIL | E075: 0/6; D039 retains architecture with limitation |
| V-021 | Inventory rollup and audit | PASS | evidence 53, 56, 57 |
| V-022 | Independent publication reference | PASS | evidence 60a, both cutoffs |
| V-023 | August publication | PASS | evidence 60c_01; WARN is a business review status |
| V-024 | November publication and integrity | PASS | evidence 60c_02 and 60c_03; successful retry; original failures preserved |
| V-025 | Readiness tests and benchmark | PASS | E061-E062: 33 tests and six matching exports; E065a: 38 regression tests; E065b-E065d: normal and empty populations and package integrity |
| V-026 | Isolated locking comparison | PASS | successful terminal outputs 64a/64b; confirm local files |
| V-027 | Final merged revision verification and submission | IN PROGRESS | Candidate passed; local privacy review confirmed; merged revision and packaging pending |

PASS refers to the stated test scope, not production certification. Earlier setup entries are historical; verify their original evidence before final submission.
