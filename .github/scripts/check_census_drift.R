# Census source coverage (ACS county context, SAIPE district child poverty) and value plausibility. Non-blocking;
# flags go to /tmp/drift_report.md. edjobs::check_census_step() (0.53.0): every county in salarymap2.csv /
# salarymap.csv should have ACS context and every district a SAIPE rate, apart from state_config(saipe_gaps = ).
source("state_config.R")
check_census_step()
