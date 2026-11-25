#!/usr/bin/env python3
"""Read-only verification of both DE-03 database endpoints."""

import os
import sys
from contextlib import closing
from getpass import getpass
from urllib.parse import urlparse, unquote

try:
    import psycopg2
except ImportError:
    sys.exit(
        "Missing psycopg2. Activate the virtual environment "
        "and install requirements.txt."
    )

base = os.environ.get(
    "DE03_DATABASE_BASE",
    "postgresql://postgres@127.0.0.1:5432"
)

parsed = urlparse(base)

if parsed.scheme not in ("postgresql", "postgres"):
    sys.exit("Invalid PostgreSQL connection scheme.")

if parsed.path not in ("", "/"):
    sys.exit("DE03_DATABASE_BASE must not include a database path.")

password = (
    unquote(parsed.password)
    if parsed.password is not None
    else os.environ.get("PGPASSWORD")
)

if password is None:
    password = getpass("Local PostgreSQL password: ")

for database in ("kloudkart_learning", "kloudkart_lab"):
    try:
        with closing(psycopg2.connect(
            host=parsed.hostname or "127.0.0.1",
            port=parsed.port or 5432,
            user=unquote(parsed.username or "postgres"),
            password=password,
            dbname=database,
            connect_timeout=5
        )) as conn:
            with conn.cursor() as cur:
                cur.execute("""
                    SELECT
                        current_database(),
                        current_setting('server_version'),
                        current_setting('max_connections'),
                        current_setting('transaction_isolation');
                """)

                actual, version, connections, isolation = cur.fetchone()

                passed = (
                    actual == database
                    and version.split(".")[0] == "18"
                    and connections == "500"
                    and isolation == "read committed"
                )

                status = "PASS" if passed else "FAIL"

                print(
                    f"{database}: {status} | "
                    f"PostgreSQL {version} | "
                    f"max_connections={connections} | "
                    f"isolation={isolation}"
                )

                if not passed:
                    sys.exit(1)

    except psycopg2.Error as exc:
        sys.exit(f"{database}: CONNECTION FAILED — {exc}")

print("Both database endpoints passed.")
print("Imported data and graded tests are not verified by this script.")
