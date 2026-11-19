# Blocking schema-drift check, run right after sanity_check.R (before anything gets committed) -- see
# schema_check.R's header for why this has to be a hard gate. The check is edjobs::check_app_schemas() (0.50.0);
# the required columns are this state's REQUIRED_SCHEMAS / REQUIRED_SCHEMAS_XLSX.
source("state_config.R")
source("schema_check.R")
check_app_schemas(REQUIRED_SCHEMAS, REQUIRED_SCHEMAS_XLSX)
