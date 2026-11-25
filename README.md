# DE-03 — Kloud Kart PostgreSQL Engineering Lab

AmaliTech DE-03 graded data engineering engagement.

## Current status — 25 November 2026

- PostgreSQL 18.7 environment provisioned.
- Maximum connections configured to 500.
- Learning and graded databases created separately.
- Original Evalu8 bundle received and inspected.
- Original file checksums verified against the local baseline.
- Learning database loaded and used for practice.
- Graded database inspected before its initial data load.
- Python connectivity to the graded database verified.
- Standalone graded Git repository initialized.
- Graded implementation and acceptance tests pending.

## Client requirements

Kloud Kart requires:

1. Safe concurrent order placement without overselling.
2. Fast customer spending and ranking reports.
3. Recursive low-stock reporting across nested categories.
4. An auditable record of stock movements.
5. Quantified data findings and defensible engineering decisions.
6. A client memo and an implemented additional improvement.

## Engineering approach

Understand the need → Gather evidence → Choose → Prove → Explain.

Significant architectural decisions are recorded as ADRs.
Smaller implementation decisions are recorded in working notes.

## Repository structure

| Directory | Purpose |
|---|---|
| sql/ | Reviewed SQL implementation |
| tests/ | Acceptance and regression tests |
| deliverables/ | Assessed documents and decisions |
| scripts/ | Setup and verification utilities |
| evidence/ | Sanitized execution and measurement evidence |
| working-notes/ | Assumptions, questions and working decisions |

## Local workspace separation

The graded repository is located inside a wider learning workspace.

- learning-path/: practice exercises and learning evidence.
- shared-data/: original Evalu8 bundle.
- graded-lab/: assessed work.
- .venv/: local Python environment.

The original bundle and learning workspace are outside this repository.
Obtain the original bundle through the authorized course source.

## Environment requirements

- Docker Engine or Docker Desktop.
- PostgreSQL 18 with max_connections=500.
- Python 3 and a virtual environment.
- Dependencies specified in requirements.txt.
- Original Evalu8 data and test bundle.

The local container is named kloudkart and publishes PostgreSQL
on 127.0.0.1:5432.

The learning database is kloudkart_learning.
The graded database is kloudkart_lab.

Both databases share one local PostgreSQL server.
Do not run learning workloads during graded performance measurements.

## Python dependencies

For a standalone clone:

    python3 -m venv .venv
    source .venv/bin/activate
    python -m pip install -r requirements.txt

An existing active virtual environment may also be used.

## Environment verification

With the PostgreSQL container running:

    bash scripts/check_setup.sh
    bash scripts/check_repo.sh

The setup verifier prompts for the local PostgreSQL password.

Optional connection configuration is supported through
DE03_DATABASE_BASE and PGPASSWORD.

Never commit actual credentials or local .env files.

## Original bundle

The supplied files must remain unchanged:

- schema.sql
- load.sql
- race_test.py
- data/categories.csv
- data/products.csv
- data/customers.csv
- data/orders.csv
- data/order_items.csv
- data/inventory_log.csv

The supplied race test must be executed without modification.

## Reproduction instructions

The complete fresh-load, implementation and acceptance-test
sequence will be documented as the graded work progresses.

Do not interpret environment verification as proof that the
graded implementation or acceptance tests have passed.

## Submission

Final file layout, repository destination and submission
requirements remain subject to the official Evalu8 instructions.
