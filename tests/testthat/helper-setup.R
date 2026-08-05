# Auto-sourced by testthat before any test-*.R file runs (test_dir/test_file/
# devtools::test() all pick up helper-*.R automatically). Loads the shared
# classification/canonicalization functions under test.
suppressMessages(library(here))
suppressMessages(library(dplyr))
source(here::here("k12_he_classification.R"))
source(here::here("scrape_helpers.R"))
source(here::here("eastern_wyoming_scraper.R"))
source(here::here("direct_api_scrapers.R"))
source(here::here("misc_district_scrapers.R"))
source(here::here("drift_check.R"))
source(here::here("salary_scrapers.R"))
