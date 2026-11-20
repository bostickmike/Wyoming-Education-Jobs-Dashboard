# Salary-source coverage, value plausibility, the pay estimates' reference tables and the Sheridan/Gillette split
# watch. Non-blocking; flags go to /tmp/drift_report.md. edjobs::salary_drift_step() (0.57.0): each source in
# state_config(salary_checks = ) is compared with last run's committed salarymap2.csv / salarymap.csv.
source("state_config.R")
source("ipeds_unitids.R")   # sheridan_gillette_split_lines(), the salary checks' `extra`
salary_drift_step()
