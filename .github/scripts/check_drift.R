# Tier 1 of the drift-alert system: each source's posting count against its own baseline.
# Non-blocking. Writes /tmp/drift_flagged.csv (header only when nothing is flagged).
# The check is edjobs::check_drift_step() (0.51.0; the source naming, floor and registry are in state_config.R).
source("k12_he_classification.R")   # canonicalize_k12_district(), which state_config's k12_source_names uses
source("drift_check.R")   # attaches edjobs; state_config.R
check_drift_step()
