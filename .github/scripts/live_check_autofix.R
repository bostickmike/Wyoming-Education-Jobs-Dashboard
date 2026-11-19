# Live check for scraper-fix PRs (pr-tests.yml): re-runs the scraper the PR's linked auto-fix issue names against the
# live site with the PR's code, writes /tmp/live_check.md (posted as a PR comment) and exits non-zero only on the
# failures edjobs::summarize_live_check() defines. edjobs::live_check_autofix_step() (0.53.0); a PR with no linked
# auto-fix issue is not applicable. The scraper files are sourced here so the step can find the state's scrapers.
suppressMessages({ library(httr2); library(rvest); library(dplyr); library(chromote) })
library(edjobs)
for (f in c("direct_api_scrapers.R", "misc_district_scrapers.R", "drift_check.R")) source(f)
quit(status = if (live_check_autofix_step()) 0 else 1)
