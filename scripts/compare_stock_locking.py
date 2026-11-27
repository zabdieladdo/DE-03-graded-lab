"""Optional isolated stock-allocation comparison; not the full purchase routine."""
import argparse
import os
import statistics
import threading
import time
import uuid
from concurrent.futures import ThreadPoolExecutor

import psycopg2
from psycopg2 import sql


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--buyers', type=int, default=40)
    parser.add_argument('--stock', type=int, default=5)
    parser.add_argument('--pairs', type=int, default=3)
    args = parser.parse_args()
    if not 1 <= args.stock < args.buyers <= 400 or not 1 <= args.pairs <= 10:
        parser.error('Require 1 <= stock < buyers <= 400 and 1 <= pairs <= 10')
    dsn = os.environ['DATABASE_URL']
    name = 'lock_probe_' + uuid.uuid4().hex[:16]
    table = sql.Identifier(name, 'stock')
    schema = sql.Identifier(name)
    admin = psycopg2.connect(dsn, connect_timeout=10)
    admin.autocommit = True
    created = False
    try:
        with admin.cursor() as cur:
            cur.execute("SELECT current_database(), current_setting('max_connections')::int")
            db, max_conn = cur.fetchone()
            if db != 'kloudkart_lab' or max_conn < args.buyers + 5:
                raise RuntimeError('Wrong database or insufficient connection headroom')
            cur.execute(sql.SQL('CREATE SCHEMA {}').format(schema)); created = True
            cur.execute(sql.SQL('CREATE TABLE {} (id int PRIMARY KEY, qty int NOT NULL CHECK(qty>=0))').format(table))
            cur.execute(sql.SQL('INSERT INTO {} VALUES (1, %s)').format(table), (args.stock,))
        print('Isolated allocation only; no orders, audit trigger, payment or official harness changes.')
        print(f'Scratch schema: {name}; buyers={args.buyers}; stock={args.stock}; pairs={args.pairs}')
        results = {'conditional': [], 'explicit': []}
        for pair in range(args.pairs):
            for mode in (('conditional','explicit') if pair % 2 == 0 else ('explicit','conditional')):
                with admin.cursor() as cur:
                    cur.execute(sql.SQL('UPDATE {} SET qty=%s WHERE id=1').format(table), (args.stock,))
                # Connect before the barrier so connection startup is outside attempt timing.
                released = []
                barrier = threading.Barrier(args.buyers + 1, action=lambda: released.append(time.perf_counter()), timeout=90)
                def attempt(_):
                    conn = None
                    try:
                        conn = psycopg2.connect(dsn, connect_timeout=10)
                        conn.set_session(isolation_level='READ COMMITTED')
                        with conn.cursor() as cur:
                            cur.execute("SET LOCAL statement_timeout='30s'")
                            cur.execute("SET LOCAL lock_timeout='25s'")
                            barrier.wait()
                            start = time.perf_counter()
                            if mode == 'conditional':
                                cur.execute(sql.SQL('UPDATE {} SET qty=qty-1 WHERE id=1 AND qty>=1 RETURNING qty').format(table))
                                won = cur.fetchone() is not None
                                first_ms = (time.perf_counter()-start)*1000
                            else:
                                cur.execute(sql.SQL('SELECT qty FROM {} WHERE id=1 FOR NO KEY UPDATE').format(table))
                                qty = cur.fetchone()[0]
                                first_ms = (time.perf_counter()-start)*1000
                                won = qty >= 1
                                if won:
                                    cur.execute(sql.SQL('UPDATE {} SET qty=qty-1 WHERE id=1').format(table))
                            conn.commit()
                            return won, (time.perf_counter()-start)*1000, first_ms
                    except BaseException:
                        barrier.abort()
                        if conn is not None: conn.rollback()
                        raise
                    finally:
                        if conn is not None: conn.close()
                with ThreadPoolExecutor(max_workers=args.buyers) as pool:
                    futures = [pool.submit(attempt, i) for i in range(args.buyers)]
                    barrier.wait()
                    start = released[0]
                    rows = [f.result() for f in futures]
                    wall = time.perf_counter()-start
                with admin.cursor() as cur:
                    cur.execute(sql.SQL('SELECT qty FROM {} WHERE id=1').format(table)); remaining = cur.fetchone()[0]
                wins = sum(r[0] for r in rows)
                if wins != args.stock or remaining != 0:
                    raise RuntimeError('Allocation correctness failed')
                results[mode].append(wall)
                print(f'Pair {pair+1} {mode}: wins={wins} refusals={len(rows)-wins} remaining={remaining} wall={wall:.4f}s '
                      f'median_attempt_ms={statistics.median(r[1] for r in rows):.3f} '
                      f'median_first_statement_ms={statistics.median(r[2] for r in rows):.3f}')
        for mode, times in results.items():
            print(f'{mode}: median wall={statistics.median(times):.4f}s; min={min(times):.4f}; max={max(times):.4f}')
        print('PASS: all isolated allocation correctness checks; statement time is NOT pure lock wait.')
    finally:
        try:
            if created:
                with admin.cursor() as cur:
                    cur.execute(sql.SQL('DROP SCHEMA {} CASCADE').format(schema))
                print(f'Cleaned scratch schema {name}')
        finally:
            admin.close()


if __name__ == '__main__':
    main()
