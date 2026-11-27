"""E060a: exercise independent base-table references without report functions."""
import os
from datetime import date
from decimal import Decimal
from pathlib import Path
from time import perf_counter
import psycopg2
from psycopg2.extras import RealDictCursor

ROOT = Path(__file__).resolve().parents[1]
SQL = ROOT / 'sql' / '07_improvement'
BASELINES = {
    date(2026, 8, 31): (111334, '339565617.77', 111190, '339176836.88', 144, '388780.89', 109702, '334634759.00', '14781340.27'),
    date(2026, 11, 26): (111339, '339573765.42', 111195, '339184984.53', 144, '388780.89', 102463, '313014045.03', '14329991.90'),
}


# Reject invalid state before proceeding.
def require(condition, message):
    if not condition:
        raise RuntimeError(message)


# Coordinate the command-line workflow and its validation.
def main():
    conn = psycopg2.connect(os.environ['DATABASE_URL'], connect_timeout=10, application_name='de03_e060a')
    try:
        conn.set_session(isolation_level='REPEATABLE READ', readonly=True, autocommit=False)
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute("SET LOCAL statement_timeout = '120s'")
            cur.execute("SET LOCAL lock_timeout = '5s'")
            cur.execute("SELECT current_database() AS db, current_setting('transaction_isolation') AS isolation, current_setting('transaction_read_only') AS read_only")
            env = cur.fetchone()
            require(env['db'] == 'kloudkart_lab', 'Wrong database')
            print('Environment:', dict(env))
            for cutoff, baseline in BASELINES.items():
                print(f'=== {cutoff} ===')
                started = perf_counter()
                cur.execute((SQL / '01_reference_customers.sql').read_text(), {'as_of_date': cutoff})
                rows = cur.fetchall()
                print(f'Customer reference: {len(rows)} rows, {(perf_counter()-started)*1000:.3f} ms (query + fetch)')
                started = perf_counter()
                cur.execute((SQL / '02_reference_exceptions.sql').read_text(), {'as_of_date': cutoff})
                ex = cur.fetchone()
                require(ex is not None and cur.fetchone() is None, 'Expected exactly one exception summary')
                print(f'Exception reference: {(perf_counter()-started)*1000:.3f} ms (query + fetch)')
                require(len(rows) == 40420 and len({r['customer_id'] for r in rows}) == len(rows), 'Customer population differs from baseline')
                require(all(len(r['months']) == len(r['monthly_amounts']) == len(r['monthly_counts']) == 12 and len(set(r['months'])) == 12 for r in rows), 'Invalid monthly reference shape')
                require(all(r['history_amount'] == r['opening_amount'] + sum(r['monthly_amounts']) and r['history_count'] == r['opening_count'] + sum(r['monthly_counts']) for r in rows), 'Per-customer opening/window reconciliation failed')
                require(ex['null_header_amount_orders'] == 0, 'Eligible NULL header amount requires review')
                require(ex['eligible_orders'] == ex['attributed_orders'] + ex['unattributed_orders'] and ex['eligible_value'] == ex['attributed_value'] + ex['unattributed_value'], 'Financial reference reconciliation failed')
                require(sum(r['history_count'] for r in rows) == ex['attributed_orders'] and sum(r['history_amount'] for r in rows) == ex['attributed_value'], 'Customer reference differs from financial reference')
                ranked = sorted(((sum(r['monthly_amounts']), r['customer_id']) for r in rows if sum(r['monthly_amounts']) > 0), key=lambda r: (-r[0], r[1]))
                window_n = sum(sum(r['monthly_counts']) for r in rows)
                window_value = sum(sum(r['monthly_amounts']) for r in rows)
                top_value = sum((r[0] for r in ranked[:100]), Decimal(0))
                observed = (ex['eligible_orders'], ex['eligible_value'], ex['attributed_orders'], ex['attributed_value'], ex['unattributed_orders'], ex['unattributed_value'], window_n, window_value, top_value)
                expected = tuple(Decimal(x) if isinstance(x, str) else x for x in baseline)
                require(observed == expected, f'Historical baseline differs: {observed!r} vs {expected!r}')
                print(f'Window orders: {window_n}; window amount: {window_value}; qualifying customers: {len(ranked)}; top100 amount: {top_value}')
                for key, value in ex.items():
                    print(f'{key}: {value}')
                print(f'PASS: independent reference matches historical baseline and internal identities ({cutoff})')
        conn.rollback()
        print('PASS: E060a reference probe complete; read-only transaction rolled back')
    finally:
        conn.close()


if __name__ == '__main__':
    main()
