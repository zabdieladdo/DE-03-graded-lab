#!/usr/bin/env bash
# Fresh, disposable local lab only. Never resets or drops an existing database.
set -euo pipefail
umask 077
cd "$(dirname "$0")/.."
[[ $# == 1 && $1 == --fresh-load ]] || { echo 'Usage: bash scripts/run_fresh_acceptance.sh --fresh-load'; exit 2; }
: "${KLOUDKART_CONTAINER:?Select disposable container}"
: "${DATABASE_URL:?Set lab DSN securely}"
: "${KLOUDKART_EXPECTED_SYSTEM_ID:?Set independently inspected cluster identifier}"
: "${KLOUDKART_SOURCE_MANIFEST:?Set absolute path to original bundle SHA256 manifest}"
[[ $KLOUDKART_EXPECTED_SYSTEM_ID =~ ^[0-9]+$ && $KLOUDKART_SOURCE_MANIFEST == /* ]] || exit 2
root=$(pwd -P)
source_dir=$(realpath ../shared-data)
logdir=$(mktemp -d "$root/generated/acceptance-XXXXXXXX" 2>/dev/null || { mkdir -p "$root/generated"; mktemp -d "$root/generated/acceptance-XXXXXXXX"; })
exec > >(tee "$logdir/runner.txt") 2>&1
trap 'rc=$?; echo "Runner exit: $rc; evidence: $logdir"; if (( rc != 0 )); then echo "STOP: inspect partial state; do not retry on this database."; fi' EXIT
run() { local label=$1; shift; local rc=0; echo "=== $label ==="; "$@" 2>&1 | tee "$logdir/$label.txt" || rc=$?; echo "Exit code: $rc" | tee -a "$logdir/$label.txt"; return "$rc"; }
psql_cmd=(docker exec -i "$KLOUDKART_CONTAINER" psql -X -U postgres -d kloudkart_lab -v ON_ERROR_STOP=1)
sql() { run "${1//\//_}" "${psql_cmd[@]}" -f "/workspace/graded-lab/$1"; }
check_mount() { local host=$1 guest=$2 h g; h=$(sha256sum "$host"); g=$(docker exec "$KLOUDKART_CONTAINER" sha256sum "$guest"); [[ ${h%% *} == "${g%% *}" ]] || { echo "Mount mismatch: $host"; return 1; }; printf '%s  %s\n' "${h%% *}" "$guest"; }
steps=(sql/02_schema/01_foreign_keys.sql sql/02_schema/02_value_constraints.sql sql/02_schema/03_identifier_generation.sql tests/01_schema_integrity_test.sql sql/03_order_placement/01_place_order.sql tests/02_place_order_functional_test.sql tests/03_place_order_atomicity_test.sql sql/04_reporting/03_reporting_foundation.sql sql/04_reporting/04_customer_spending_summary.sql sql/04_reporting/08_customer_monthly_spending.sql sql/04_reporting/12_customer_running_spending.sql sql/04_reporting/16_customer_ranking.sql tests/08_reporting_foundation_test.sql tests/09_customer_spending_summary_test.sql tests/10_customer_monthly_spending_test.sql tests/11_customer_running_spending_test.sql tests/12_customer_ranking_test.sql sql/05_inventory/01_low_stock_rollup.sql sql/05_inventory/02_stock_movement_audit.sql tests/13_low_stock_rollup_test.sql tests/14_stock_movement_audit_test.sql tests/04_race_preflight.sql tests/05_race_cleanup_verification.sql)
source_files=(schema.sql load.sql race_test.py data/categories.csv data/products.csv data/customers.csv data/orders.csv data/order_items.csv data/inventory_log.csv)
echo "UTC: $(date -u +%FT%TZ)"; git rev-parse HEAD; git status --short; python --version
run setup bash scripts/check_setup.sh
actual=$("${psql_cmd[@]}" -Atc 'SELECT system_identifier FROM pg_control_system()')
[[ $actual == "$KLOUDKART_EXPECTED_SYSTEM_ID" ]] || { echo 'Unexpected cluster identifier'; exit 1; }
# Require a genuinely empty lab; refuse even a partial earlier load.
empty=$("${psql_cmd[@]}" -Atc "SELECT NOT EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname NOT IN ('pg_catalog','information_schema') AND n.nspname NOT LIKE 'pg_toast%' AND n.nspname NOT LIKE 'pg_temp_%') AND NOT EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname NOT IN ('pg_catalog','information_schema') AND n.nspname NOT LIKE 'pg_toast%' AND n.nspname NOT LIKE 'pg_temp_%') AND NOT EXISTS (SELECT 1 FROM pg_stat_activity WHERE datname=current_database() AND pid<>pg_backend_pid())")
[[ $empty == t ]] || { echo 'Refusing nonempty or busy lab database'; exit 1; }
(cd "$source_dir"; sha256sum --strict -c "$KLOUDKART_SOURCE_MANIFEST") | tee "$logdir/source-integrity.txt"
# Require manifest coverage for every consumed source file, not merely a successful check of a subset.
for f in "${source_files[@]}"; do
    grep -Eq "^[0-9a-fA-F]{64} [ *](\./)?${f//./\\.}$" "$KLOUDKART_SOURCE_MANIFEST" || { echo "Missing manifest entry: $f"; exit 1; }
    check_mount "$source_dir/$f" "/workspace/shared-data/$f"
done
for f in "${steps[@]}"; do check_mount "$root/$f" "/workspace/graded-lab/$f"; done
run readiness_unit python -u tests/test_report_readiness.py
run baseline docker exec -w /workspace/shared-data -i "$KLOUDKART_CONTAINER" psql -X -U postgres -d kloudkart_lab -v ON_ERROR_STOP=1 --single-transaction -f schema.sql -f load.sql
for f in "${steps[@]}"; do
    if [[ $f == tests/05_race_cleanup_verification.sql ]]; then
        run official_race python -u ../shared-data/race_test.py --verbose
    fi
    sql "$f"
done
run readiness_reference python -u scripts/probe_readiness_reference.py
for cutoff in 2026-08-31 2026-11-26 2025-08-01; do
    run "publication_$cutoff" python -u scripts/generate_monday_report.py --as-of "$cutoff"
    run "package_$cutoff" python -E - "$logdir/publication_$cutoff.txt" "$cutoff" <<'PY'
import csv, hashlib, json, re, sys
from pathlib import Path
log, cutoff = sys.argv[1:]
matches = re.findall(r'^Run: ([0-9a-f-]{36}) Status: (PASS|WARN) Action: ', Path(log).read_text(), re.M)
if len(matches) != 1: raise SystemExit('Missing or ambiguous publication result')
uid, status = matches[0]
out = Path('generated') / uid
m = json.loads((out/'manifest.json').read_text()); r = json.loads((out/'readiness.json').read_text())
expected_status = 'PASS' if cutoff == '2025-08-01' else 'WARN'
counts = {'customer_summary.csv':40420,'monthly_running.csv':485040,'top100.csv':0 if cutoff=='2025-08-01' else 100,'ranking_metadata.csv':1,'reconciliation.csv':1,'period_metadata.csv':1}
expected = set(counts) | {'readiness.json'}
assert set(m['output_checksums']) == expected and {p.name for p in out.iterdir()} == expected | {'manifest.json'}
assert m['run_id']==r['run_id']==uid and m['as_of_date']==r['as_of_date']==cutoff
assert m['overall_status']==r['overall_status']==status==expected_status
assert m['publication_action']==('NORMAL REVIEW' if status=='PASS' else 'REVIEW AND DISCLOSE')
assert m['db']=='kloudkart_lab' and m['read_only']=='on' and m['isolation']=='repeatable read'
for name, digest in m['output_checksums'].items(): assert hashlib.sha256((out/name).read_bytes()).hexdigest()==digest, name
for name, count in counts.items():
    with (out/name).open(newline='',encoding='utf-8') as f: assert sum(1 for _ in csv.DictReader(f))==count, name
print(f'PASS: {cutoff} {status}; seven output hashes and six CSV row counts verified')
PY
done
echo 'PASS: fresh-load functional acceptance and publication package checks completed.'
echo 'Performance repeatability is separate; run verify_integrated_workload.py only if needed.'
