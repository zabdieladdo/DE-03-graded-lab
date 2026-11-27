"""E058: solo report and report concurrent with unmodified official test 2.
Run from graded-lab, with DATABASE_URL set. No credentials printed.
"""
import os
import re
import subprocess
import sys
import tempfile
import time
from pathlib import Path
import psycopg2

ROOT = Path.cwd()
REPORT = ['docker', 'exec', '-i', 'kloudkart', 'psql', '-X', '-U', 'postgres',
          '-d', 'kloudkart_lab', '-v', 'ON_ERROR_STOP=1', '-f',
          '/workspace/graded-lab/sql/06_optimization/01_integrated_reporting_workload.sql']
RACE = [sys.executable, '-u', '../shared-data/race_test.py', '--test', '2', '--verbose']
TABLES = ('categories', 'products', 'customers', 'orders', 'order_items', 'inventory_log')
EXPECTED = (94, 4023, 40420, 159384, 336559, 282352)

# Capture baseline table counts and named fixture count.
def state(cur):
    cur.execute('SELECT ' + ', '.join(f'(SELECT count(*) FROM public.{t})' for t in TABLES))
    counts = cur.fetchone()
    cur.execute("SELECT count(*) FROM public.products WHERE product_name LIKE 'RACE TEST FIXTURE%'")
    return counts, cur.fetchone()[0]

# Extract the report timing from the saved log.
def report_ms(log):
    match = re.search(r'^\s*1\s*\|\s*2026-08-31\s*\|\s*([\d.]+)\s*$', log, re.M)
    if not match:
        raise RuntimeError('Report timing missing')
    return float(match.group(1))

# Read captured subprocess output.
def readlog(f):
    f.seek(0)
    return f.read().decode(errors='replace')

# Coordinate the command-line workflow and its validation.
def main():
    if not (ROOT / '../shared-data/race_test.py').is_file():
        raise RuntimeError('Run from graded-lab with official bundle available')
    conn = psycopg2.connect(os.environ['DATABASE_URL'], application_name='de03_e058_observer')
    conn.autocommit = True
    try:
        with conn.cursor() as cur:
            cur.execute('SELECT current_database(), current_date, current_setting(\'max_connections\')')
            db, today, maximum = cur.fetchone()
            print('Environment:', db, today, 'max_connections', maximum, flush=True)
            if db != 'kloudkart_lab' or str(today) <= '2026-08-31':
                raise RuntimeError('Wrong database or synthetic orders may enter historical report')
            before = state(cur)
            print('Baseline counts / fixtures:', before, flush=True)
            if before != (EXPECTED, 0):
                raise RuntimeError('Baseline differs; investigate before running')
            solo = subprocess.run(REPORT, capture_output=True, text=True, timeout=750)
            print('=== SOLO REPORT ===\n' + solo.stdout + solo.stderr, flush=True)
            if solo.returncode:
                raise RuntimeError('Solo report failed')
            solo_ms = report_ms(solo.stdout)
            with tempfile.TemporaryFile() as report_log, tempfile.TemporaryFile() as race_log:
                env = dict(os.environ, PGAPPNAME='de03_e058_checkout')
                report = subprocess.Popen(REPORT, stdout=report_log, stderr=subprocess.STDOUT)
                race = None
                overlap = peak = 0
                try:
                    while report.poll() is None or (race is not None and race.poll() is None):
                        cur.execute("""SELECT count(*) FILTER (WHERE application_name='de03_e058_report' AND state='active' AND query LIKE 'COPY%'),
                            count(*) FILTER (WHERE application_name='de03_e058_checkout' AND state='active' AND query LIKE '%FROM place_order(%')
                            FROM pg_stat_activity WHERE datname=current_database()""")
                        active_report, active_buyers = cur.fetchone()
                        if race is None and active_report:
                            race = subprocess.Popen(RACE, env=env, stdout=race_log, stderr=subprocess.STDOUT)
                        if active_report and active_buyers:
                            overlap += 1
                            peak = max(peak, active_buyers)
                        time.sleep(.05)
                finally:
                    # Allow official harness to finish and clean up even if observer fails.
                    report.wait()
                    if race is not None:
                        race.wait()
                    rlog, clog = readlog(report_log), readlog(race_log)
                    print('=== CONCURRENT REPORT ===\n' + rlog, flush=True)
                    print('=== OFFICIAL TEST 2 ===\n' + clog, flush=True)
                    print('Observed overlap samples:', overlap, 'peak active checkout calls during report:', peak, flush=True)
                    after = state(cur)
                    print('Final counts / fixtures:', after, flush=True)
                if after != before:
                    raise RuntimeError('Cleanup/count reconciliation failed')
                if report.returncode or race is None or race.returncode:
                    raise RuntimeError('Report or race process failed/not started')
                m = re.search(r'50 sold, 350 refused, 0 errored, wall clock ([\d.]+)s', clog)
                if not m or 'PASSED' not in clog:
                    raise RuntimeError('Expected race result missing')
                concurrent_ms = report_ms(rlog)
                print(f'Solo report ms: {solo_ms:.3f}; concurrent report ms: {concurrent_ms:.3f}; checkout wall s: {m[1]}')
                print(f'Report change: {(concurrent_ms/solo_ms-1)*100:.2f}%')
                print('Report provisional 5000ms gate:', 'PASS' if concurrent_ms <= 5000 else 'MISS')
                print('Checkout 10s gate:', 'PASS' if float(m[1]) <= 10 else 'MISS')
                if not overlap:
                    raise RuntimeError('No simultaneous active queries observed; contention result inconclusive')
                print('PASS: workload execution, observed overlap, race correctness and cleanup counts')
    finally:
        conn.close()

if __name__ == '__main__':
    main()
