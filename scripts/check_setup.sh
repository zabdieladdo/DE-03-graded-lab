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

# Require explicit selection; never silently inspect the learning cluster.
: "${KLOUDKART_CONTAINER:?Set KLOUDKART_CONTAINER explicitly}"
: "${DATABASE_URL:?Set DATABASE_URL securely}"
printf '\n--- PostgreSQL readiness ---\n'
docker exec "$KLOUDKART_CONTAINER" pg_isready -U postgres -d kloudkart_lab
printf '\n--- Lab endpoint and cluster identity ---\n'
python scripts/verify_setup.py
