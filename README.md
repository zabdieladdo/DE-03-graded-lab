# DE-03 — Kloud Kart PostgreSQL engineering lab

## Purpose and status
Prevent overselling, provide customer spending and nested low-stock reports, and record stock movements. The additional improvement checks publication readiness. Automated fresh-load functional acceptance passed on 2026-11-27 against a working-tree candidate based on `739e19c` (E077c). Verification of the final merged revision is pending. Performance limitations remain; no production guarantee or approved materiality limits.

## Deliverables
| Deliverable | Location |
|---|---|
| Diagnosis | [Data findings](deliverables/diagnosis/data_findings.md) |
| Working SQL | `sql/` and `tests/` |
| Decisions | `deliverables/decisions/` (ADR-001–007) |
| Client memo | [Memo](deliverables/memo/client_memo.md) |
| Improvement | [Publication readiness](deliverables/improvement/improvement.md) |
| Performance | `deliverables/performance/` |
| Supporting investigation | `deliverables/supporting/` |
| Traceability | [Evidence index](deliverables/EVIDENCE_INDEX.md), `evidence/` |

## Quick start — Windows to verified results

Use a disposable local database only. The runner refuses a nonempty or busy database; it is not a reset or upgrade tool. Do not use production credentials or a production endpoint. The original lab bundle is required separately. Commands below use Bash unless marked PowerShell. Stop on unexpected errors; do not paste the entire guide as one script.

### 1. Windows PowerShell and Docker Desktop

In administrator PowerShell, if WSL/Ubuntu is not installed:

```powershell
wsl --install -d Ubuntu
```

Restart if requested, launch Ubuntu and complete its user setup. In PowerShell verify:

```powershell
wsl --list --verbose
wsl --status
```

Ubuntu must show version 2 (if necessary, `wsl --set-version Ubuntu 2`). Install/start Docker Desktop for Windows using the WSL 2 engine. In Settings > Resources > WSL Integration enable Ubuntu and apply changes. Follow your organization's installation policy. In PowerShell enter Ubuntu:

```powershell
wsl -d Ubuntu
```

### 2. Ubuntu terminal — prerequisites and repository

```bash
sudo apt update
sudo apt install -y git python3 python3-venv
python3 --version
git --version
docker version
docker run --rm hello-world
```

The verified environment used Python 3.14.4 and PostgreSQL 18.7; other Python versions have not been independently acceptance-tested. If Docker is inaccessible, check Desktop is running and Ubuntu integration is enabled. If the socket is owned by `root:docker` and your user lacks membership, use `sudo usermod -aG docker "$USER"` only if permitted, then start a new login session. Docker group access is effectively root-equivalent; do not make the socket world-writable.

```bash
mkdir -p ~/projects/kloudkart-review
cd ~/projects/kloudkart-review
git clone https://github.com/zabdieladdo/DE-03-graded-lab.git graded-lab
mkdir -p shared-data
python3 -m venv .venv
source .venv/bin/activate
cd graded-lab
python -m pip install -r requirements.txt
python -m pip check
bash scripts/check_repo.sh
```

Use the submitted Git revision (and authorized GitHub access if private). An existing checkout or extracted submission can be used instead of cloning, but the runner requires a Git checkout. Keep the directory name `graded-lab` and its sibling `shared-data` because the container paths depend on them.

### 3. Original lab data

Extract the supplied original bundle into `../shared-data/` (copy from your actual download location). The required layout is:

```text
kloudkart-review/
  .venv/
  graded-lab/
  shared-data/
    schema.sql
    load.sql
    race_test.py
    data/
      categories.csv
      customers.csv
      inventory_log.csv
      order_items.csv
      orders.csv
      products.csv
```

```bash
export KLOUDKART_SOURCE_MANIFEST="$(realpath config/original-bundle.sha256)"
(cd ../shared-data && sha256sum --strict -c "$KLOUDKART_SOURCE_MANIFEST")
```

Expect nine OK results. Do not regenerate the manifest to make modified inputs pass. Raw source data is intentionally excluded from Git.

### 4. Create a new isolated PostgreSQL instance

From `graded-lab/` in the active virtual environment, choose an unused loopback port (5434 below) and a unique container/volume name. Verify existing containers, volumes and listeners first.

```bash
docker ps -a
docker volume ls
ss -ltn
export KLOUDKART_CONTAINER="kloudkart-review-$(date +%s)-$$"
export LAB_VOLUME="${KLOUDKART_CONTAINER}-pgdata"
export LAB_PORT=5434
export LAB_WORKSPACE="$(realpath ..)"
```

Stop if the selected port, container name or volume already exists. Use a new nonempty temporary password, not a work password.

```bash
read -rsp 'Temporary PostgreSQL password: ' POSTGRES_PASSWORD; echo
export POSTGRES_PASSWORD
```

```bash
docker volume create "$LAB_VOLUME" && docker run -d \
  --name "$KLOUDKART_CONTAINER" \
  --publish "127.0.0.1:$LAB_PORT:5432" \
  --env POSTGRES_PASSWORD --env POSTGRES_DB=kloudkart_lab \
  --mount "type=bind,source=$LAB_WORKSPACE,target=/workspace,readonly" \
  --mount "type=volume,source=$LAB_VOLUME,target=/var/lib/postgresql" \
  postgres:18.7 -c max_connections=500
```

The tested image was PostgreSQL 18.7. If the exact tag is unavailable, obtain an authorized PostgreSQL 18 image and disclose the version difference. Stop on Docker errors. Repeat the readiness check until it succeeds:

```bash
docker exec "$KLOUDKART_CONTAINER" pg_isready -U postgres -d kloudkart_lab
```

```bash
export DATABASE_URL="$(python -c 'import os; from urllib.parse import quote; print("postgresql://postgres:"+quote(os.environ["POSTGRES_PASSWORD"],safe="")+"@127.0.0.1:"+os.environ["LAB_PORT"]+"/kloudkart_lab")')"
unset POSTGRES_PASSWORD
export KLOUDKART_EXPECTED_SYSTEM_ID="$(docker exec "$KLOUDKART_CONTAINER" psql -X -U postgres -d kloudkart_lab -v ON_ERROR_STOP=1 -Atc 'SELECT system_identifier FROM pg_control_system()')"
bash scripts/check_setup.sh
```

Expect matching Docker/Python cluster identifiers, PostgreSQL 18, read committed and at least 405 connections (configured 500). Keep the database exclusively for this run. The temporary password remains visible to users with Docker inspection privileges; never publish the container environment or DSN.

### 5. Automated acceptance — one command

```bash
unset PYTHONOPTIMIZE
set -o pipefail
bash scripts/run_fresh_acceptance.sh --fresh-load
```

The runner creates `generated/acceptance-<unique-id>/runner.txt` and per-step logs. It verifies source and mount checksums, loads the baseline, applies 11 migrations in order, runs SQL and Python regressions, the unmodified official race harness, cleanup, independent reference checks and three publication packages. Expect overall exit 0, 38 Python tests, four official race tests, 50 wins/350 refusals/zero errors in the 400-buyer flash sale, all six baseline counts restored, and publication WARN/WARN/PASS for August, November and the empty cutoff respectively. The three package checks cover 21 output hashes and 18 CSV row counts. WARN is review-and-disclose, not automatic publication approval.

The runner does not execute the historical diagnosis or performance repeatability experiments. See the evidence index and performance reports for those results. The generated publication packages contain customer-level data; keep them private.

If a step fails, preserve its logs and inspect the partial state. Do not retry on that database. Create a new disposable container and volume for a fresh run. No automatic destructive reset is performed.

### 6. Optional manual inspection and cleanup

Keep the selected container running for report queries or the optional integrated workload (`python -u scripts/verify_integrated_workload.py`); the latter creates temporary race fixtures and requires the same exclusive lab and cleanup checks. Do not run the manual deployment steps below after successful automated deployment; they are an alternative route for a separate empty instance.

When finished, stop only your disposable container with `docker stop "$KLOUDKART_CONTAINER"`. Keep its volume if investigation is needed. Unset credentials and selectors:

```bash
unset DATABASE_URL POSTGRES_PASSWORD KLOUDKART_EXPECTED_SYSTEM_ID KLOUDKART_SOURCE_MANIFEST KLOUDKART_CONTAINER LAB_PORT LAB_VOLUME LAB_WORKSPACE
```

Never use `docker system prune` or delete another project's volume as part of this guide.

## Fresh-load deployment order
The supplied schema is destructive. Back up the current lab and confirm the disposable target before loading; do not run against an existing working database without explicit approval. Use the original supplied bundle unchanged. The following is the ordered migration list **after** successful baseline load (94 categories, 4,023 products, 40,420 customers, 159,384 orders, 336,559 items, 282,352 movements; total 822,832).

1. `sql/02_schema/01_foreign_keys.sql`
2. `sql/02_schema/02_value_constraints.sql`
3. `sql/02_schema/03_identifier_generation.sql`
4. `sql/03_order_placement/01_place_order.sql`
5. `sql/04_reporting/03_reporting_foundation.sql`
6. `sql/04_reporting/04_customer_spending_summary.sql`
7. `sql/04_reporting/08_customer_monthly_spending.sql`
8. `sql/04_reporting/12_customer_running_spending.sql`
9. `sql/04_reporting/16_customer_ranking.sql`
10. `sql/05_inventory/01_low_stock_rollup.sql`
11. `sql/05_inventory/02_stock_movement_audit.sql`

For the manual route, first perform setup and source verification above, then load the supplied bundle **only into the independently confirmed empty disposable database**:

```bash
docker exec -w /workspace/shared-data -i "$KLOUDKART_CONTAINER" psql -X -U postgres -d kloudkart_lab -v ON_ERROR_STOP=1 --single-transaction -f schema.sql -f load.sql
```

Execute each file once with `psql -X -v ON_ERROR_STOP=1` and stop on failure. Example, **run in terminal** after baseline load:
```bash
docker exec -i "$KLOUDKART_CONTAINER" psql -X -U postgres -d kloudkart_lab -v ON_ERROR_STOP=1 -f /workspace/graded-lab/sql/02_schema/01_foreign_keys.sql
```

Investigation, verification and performance SQL are not migrations. Reference SQL in `sql/07_improvement/` is executed through Python, not directly through psql.

## Verification order
Run schema test 01 after schema migrations; purchase tests 02–03 after original purchase definition and **before** replacing it with the audit implementation. Test 03 injects a failure into the original log path. Run reporting tests 08–12 after reporting definitions; inventory tests 13–14 after inventory definitions. Use `tests/04_race_preflight.sql` before the official harness, `tests/05_race_cleanup_verification.sql` afterwards. Tests 06–07 are specific to historical retained fixtures, not generic fresh-load tests; do not run blindly. Run the unmodified official harness with `python ../shared-data/race_test.py --verbose` and no keep-fixtures flag. Run `python -u tests/test_report_readiness.py` and `python -u scripts/probe_readiness_reference.py`. Capture exit codes and new evidence; preserve old logs. The automated runner implements this order; the candidate execution passed (E077c).

## Report interfaces
See [reporting README](sql/04_reporting/README.md) for functions and semantics. Completed-only eligibility; explicit inclusive cutoff, trailing 12 calendar months, all current customer accounts, deterministic top 100. Recorded header totals are not verified cash revenue; currency unconfirmed. Low stock threshold 10 is configurable and provisional. Inventory audit covers new stock changes, not historical opening balances.

**Run in terminal:**
```bash
set -o pipefail
python -u scripts/generate_monday_report.py --as-of 2026-08-31
python -u scripts/generate_monday_report.py --as-of 2026-11-26
unset DATABASE_URL
```
Run separately and inspect exit codes. PASS/WARN exit 0, FAIL exit 2, ERROR exit 3. WARN requires review and disclosure; no automatic release. Generated private CSV/JSON files are ignored; do not commit or share them. Policy thresholds are proposed. August and November publications returned WARN with verified package integrity. R12 is implemented and verified for normal and empty eligible populations (E065a-E065d). All 38 regression tests passed. An empty-population PASS does not establish absence of business activity.

## Measured results and limitations
Official race tests passed; 400 attempts/50 wins/350 refusals, zero errors in tested runs. Development integrated SQL workload measured 3.487 s solo and 4.227 s concurrent (E058). Six independent acceptance-environment observations missed the provisional 5 s concurrent reporting target (5.041–8.665 s); all six checkout runs completed within 10 s (2.64–4.39 s), with zero overselling or unexpected errors. The 5 s target is internal, not a client-approved SLA. Earlier verified publication median was 13.933 s (three runs), approximately 962 MiB Python RSS. Latest automated full publication elapsed 20.236 s (August), 22.131 s (November), and 18.648 s (empty); two exceeded the proposed 20 s investigation threshold. Retain the current architecture with disclosed limitations; timings are environment-dependent, not a causal comparison. No agreed full-publication SLA. Isolated locking comparison passed 12 trials; not a full purchase benchmark. See performance reports for methods and limitations.

## Submission hygiene
Keep supporting questions, schema findings and verification register. Exclude private defence notes, learning journal, credentials, caches, raw data and generated reports. Preserve failure evidence. Final submission mechanics require confirmation. Preserve raw evidence privately and retain traceability to submitted claims. Verify the final merged revision before submission.

## Assessor navigation

- [Consolidated evidence index](evidence/README.md)
- [Primary fresh-load acceptance transcript](evidence/02_fresh_acceptance.txt)

The evidence package preserves all 148 original TXT transcripts in six consolidated files. Personal machine identifiers and local paths have been anonymized. Original evidence is preserved privately.

Before reproducing historical performance experiments, create the ignored output directory with `mkdir -p generated` and verify the disposable database target.
