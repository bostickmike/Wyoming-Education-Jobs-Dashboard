# Refuses to commit when K-12 or college postings fell by more than half since last run: safe_scrape() lets
# single sources fail, so every source failing at once would otherwise "succeed" with a near-empty dataset.
# The check is edjobs::check_run_row_counts() (0.50.0); the app folder comes from state_config.R.
source("state_config.R")
check_run_row_counts()
