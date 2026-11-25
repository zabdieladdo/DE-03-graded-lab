#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

command -v docker >/dev/null || {
    echo "Docker CLI missing"
    exit 1
}

# Support an active environment, a standalone clone,
# or the shared local learning environment.
if [[ -n "${VIRTUAL_ENV:-}" ]]; then
    echo "Using active Python virtual environment"
elif [[ -f .venv/bin/activate ]]; then
    source .venv/bin/activate
elif [[ -f ../.venv/bin/activate ]]; then
    source ../.venv/bin/activate
else
    echo "No virtual environment found."
    echo "Run: python3 -m venv .venv"
    echo "Then install requirements.txt."
    exit 1
fi

printf '\n--- Docker container ---\n'
docker ps --filter name='^/kloudkart$'

printf '\n--- PostgreSQL readiness ---\n'
docker exec kloudkart pg_isready -U postgres

printf '\n--- PostgreSQL settings ---\n'
docker exec kloudkart psql -U postgres -Atc 'SHOW server_version;'
docker exec kloudkart psql -U postgres -Atc 'SHOW max_connections;'

printf '\n--- Both database connections ---\n'
python scripts/verify_setup.py
