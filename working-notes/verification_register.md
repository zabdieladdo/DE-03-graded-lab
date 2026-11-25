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
| V-009 | Revised setup scripts | PASS | Both database endpoints passed; evidence/00_setup_verification.txt |
| V-010 | Credential exclusions | PASS | Local exclusion and credential review completed |
| V-011 | Initial Git commit | PASS | Verified commit 5a12818 |
| V-012 | Official submission requirements | BLOCKED | Evalu8 confirmation needed |
| V-013 | Graded baseline data load | PASS | evidence/00_baseline_load.txt |
| V-014 | Six-table row reconciliation | PASS | 822832 records; all six differences zero |
| V-015 | Graded acceptance tests | NOT STARTED | Pending |
