# Integrated performance verification

`01_integrated_reporting_workload.sql` is a read-only benchmark, not a migration. Run via `scripts/verify_integrated_workload.py` from repository root with DATABASE_URL set securely and official bundle available. Requires completed schema, reporting and audit deployment. Inspect printed gates separately from exit code. See [measurement report](../../deliverables/performance/integrated_workload_performance.md).
