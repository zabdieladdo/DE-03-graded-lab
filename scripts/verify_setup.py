#!/usr/bin/env python3
"""Read-only verification of the explicitly selected lab endpoint."""
import os
import subprocess
import sys
from contextlib import closing

import psycopg2


def main():
    container = os.environ.get("KLOUDKART_CONTAINER")
    dsn = os.environ.get("DATABASE_URL")
    if not container or not dsn:
        sys.exit("Set KLOUDKART_CONTAINER and DATABASE_URL explicitly.")
    try:
        result = subprocess.run(
            ["docker", "exec", container, "psql", "-X", "-U", "postgres",
             "-d", "kloudkart_lab", "-v", "ON_ERROR_STOP=1", "-Atc",
             "SELECT system_identifier FROM pg_control_system()"],
            capture_output=True, text=True, timeout=30, check=True,
        )
        docker_id = result.stdout.strip()
        with closing(psycopg2.connect(dsn, connect_timeout=5,
                     options="-c statement_timeout=10000 -c default_transaction_read_only=on")) as conn:
            with conn.cursor() as cur:
                cur.execute("""SELECT current_database(),
                    current_setting('server_version'),
                    current_setting('max_connections'),
                    current_setting('transaction_isolation'),
                    system_identifier::text FROM pg_control_system()""")
                db, version, maximum, isolation, python_id = cur.fetchone()
        print(f"Container: {container}; database: {db}; PostgreSQL {version}; "
              f"max_connections={maximum}; isolation={isolation}")
        print(f"Docker system identifier: {docker_id}")
        print(f"Python system identifier: {python_id}")
        if not (db == "kloudkart_lab" and version.split(".")[0] == "18"
                and int(maximum) >= 405 and isolation == "read committed"
                and docker_id.isdigit() and docker_id == python_id):
            sys.exit("FAIL: Lab configuration or cluster identity mismatch.")
    except (psycopg2.Error, OSError, subprocess.SubprocessError, ValueError) as exc:
        sys.exit(f"FAIL: Setup verification ({type(exc).__name__}); details suppressed.")
    print("PASS: Lab endpoint and cluster identity verified.")
    print("Imported data and graded tests are not verified by this script.")


if __name__ == "__main__":
    main()
