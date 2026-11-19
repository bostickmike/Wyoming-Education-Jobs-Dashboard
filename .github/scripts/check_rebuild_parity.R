#!/usr/bin/env Rscript
# Classification safeguards item 12: rebuilds the K-12 and HE derived datasets from the raw archives (in memory;
# nothing is written to the app folder) and checks they reproduce the committed files, ignoring row order. A
# difference means the rebuild and the weekly pipeline have drifted apart, so the rebuild can no longer be trusted
# for disaster recovery or a reclassification. Non-blocking: differences go to /tmp/drift_report.md and
# /tmp/rebuild_parity.csv (edjobs::report_rebuild_parity(), 0.52.0).
# Usage (repo root): Rscript .github/scripts/check_rebuild_parity.R
suppressPackageStartupMessages({ library(dplyr); library(readxl) })
library(edjobs)
source("state_config.R")
for (f in c("k12_he_classification.R", "history_accumulator.R", "scripts/rebuild_k12_history_from_archive.R", "scripts/rebuild_he_history_from_archive.R")) source(f)
report_rebuild_parity(rebuild_k12_history_from_archive(), rebuild_he_history_from_archive())
