# Working Decision Log

Minor engineering and implementation decisions.
Significant architectural decisions are recorded separately as ADRs.

## WD-001 — Separate the graded Git repository

Date: 2026-11-25

- Need: Submit only relevant assessed work.
- Evidence: Git was initially initialized in the parent workspace,
  exposing learning exercises and supplied datasets as untracked files.
- Choice: Initialize a standalone repository inside graded-lab.
- Alternative: Maintain one repository with extensive exclusions.
- Reason: A separate repository provides a clearer submission boundary.
- Proof: Git root verified as graded-lab; only 11 original scaffold
  files appeared before additional preparation files were created.
- Residual risk: The final repository layout must comply with Evalu8.

## WD-002 — Preserve the original Evalu8 bundle

Date: 2026-11-25

- Need: Maintain a reproducible source baseline.
- Choice: Keep the original bundle outside the graded repository.
- Proof: All nine files matched the previously recorded SHA-256 hashes.
- Limitation: Local hashes establish unchanged files, not publisher
  authenticity.
- Revisit: If official submission instructions require bundling the files.

## WD-003 — Externalize database credentials

Date: 2026-11-25

- Need: Avoid committing database passwords.
- Choice: Obtain credentials from environment configuration or
  a secure interactive prompt.
- Alternative: Retain a hard-coded training password.
- Reason: Reduce credential exposure and support different environments.
- Proof: Pending execution of the revised verification script.

## WD-004 — Support multiple virtual environment locations

Date: 2026-11-25

- Need: Support the existing workspace and a standalone repository clone.
- Choice: Accept an active environment, repository-local .venv,
  or parent workspace .venv.
- Proof: Pending execution of the revised setup script.

### Verification update — 2026-11-25

WD-003 and WD-004 verified successfully.

- Both database endpoints passed Python connectivity checks.
- Password supplied through an interactive prompt.
- Active Python virtual environment detected successfully.
- PostgreSQL 18.7 confirmed.
- Maximum connections: 500.
- Transaction isolation: read committed.

Evidence: evidence/00_setup_verification.txt
