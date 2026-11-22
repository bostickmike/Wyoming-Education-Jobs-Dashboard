# Registry sources with no rows in any of their last 4 weekly runs (edjobs 0.74.0, test-kit plan item 1).
# Non-blocking; adds to /tmp/drift_report.md. Known-empty sources: silent_sources_acknowledged.csv.
source("drift_check.R")   # attaches edjobs; state_config.R
source("k12_he_classification.R")   # canonicalize_k12_district(), which state_config's k12_source_names uses
check_silent_sources_step()
