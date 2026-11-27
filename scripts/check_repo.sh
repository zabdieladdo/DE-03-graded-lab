#!/usr/bin/env bash
set -euo pipefail
# Run from the repository root and inspect tracked state.
cd "$(dirname "$0")/.."
printf 'Git root: '; git rev-parse --show-toplevel
printf '\nGit status:\n'; git status --short
printf '\nRemote(s):\n'; git remote -v
printf '\nTracked file list:\n'; git ls-files
# Inspect the existing local PostgreSQL instance.
printf '\nPostgreSQL settings:\n'
docker exec kloudkart psql -U postgres -tAc 'SHOW server_version; SHOW max_connections;'
printf '\nDatabases:\n'
docker exec kloudkart psql -U postgres -tAc "SELECT datname FROM pg_database WHERE datname IN ('kloudkart_learning','kloudkart_lab') ORDER BY datname;"
