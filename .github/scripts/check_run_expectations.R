# Run expectations: every row of run_expectations.csv against this run's files. Non-blocking and informational;
# writes the step summary and /tmp/run_expectations.csv, and adds to /tmp/drift_report.md when a row failed or
# errored. The step is edjobs::run_expectations_step() (0.50.0).
suppressPackageStartupMessages(library(edjobs))   # pinned in EDJOBS_VERSION
run_expectations_step()
