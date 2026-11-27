#!/usr/bin/env bash
set -euo pipefail
# Run from the repository root and inspect tracked state.
cd "$(dirname "$0")/.."
printf 'Git root: '; git rev-parse --show-toplevel
printf '\nGit status:\n'; git status --short
printf '\nRemote(s):\n'; git remote -v
printf '\nTracked file list:\n'; git ls-files
# Database checks are separate: use scripts/check_setup.sh.
