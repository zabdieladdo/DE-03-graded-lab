# Integrated performance verification

`sql/06_optimization/01_integrated_reporting_workload.sql` is a read-only benchmark, not a migration. Run via `scripts/verify_integrated_workload.py` from repository root with DATABASE_URL set securely and official bundle available. Requires completed schema, reporting and audit deployment. Inspect printed gates separately from exit code. See [measurement report](integrated_workload_performance.md).
