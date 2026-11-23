# Wyoming Education Jobs Dashboard

A live dashboard of K-12 and higher education job openings across Wyoming, with salary and vacancy-rate data layered in for every district and institution. Updated twice a week.

**Live dashboard:** https://bostickmike-wyoming-education-jobs-dashboard.share.connect.posit.cloud

## What it does

- **Home**: open K-12 and college postings, each with a 12-week trend line and the change since the last update; the five districts, colleges, K-12 job types and college job types with the most postings, each with its own 12-week line; and a switch that leaves out substitute, coaching and part-time jobs.
- **Map**: every district and college with a current opening (districts and charter schools posting only on WSBA's statewide list included). Circle size is current openings; color is the vacancy rate (openings as a share of teaching or faculty staff).
- **K-12 and Higher Ed menus**, each with:
  - **Jobs**: every open posting, filterable and exportable, with posted pay where the posting states it. A "New this week" filter shows postings that appeared since the previous update.
  - **Districts** / **Colleges**: a directory with openings, vacancy rate, pay (including multi-year salary trends where the source supports it) and community context per district or college, and a head-to-head comparison of up to four.
  - **Trends**: current counts by category with sparklines and change over a month, quarter or year, and multi-year charts with a Simple or Detailed category toggle.
  - **Listing Duration**: how long postings stay listed, by job type.
- **Data**: every dataset as a download, with the data dictionary and where each source comes from.

## Data sources

| Data | Source |
|---|---|
| K-12 job postings | Each district's own job board (AppliTrack, Red Rover, SchoolSpring, TedK12, Paylocity, and school-site CMSs: Apptegy, Edlio, SmartSites, Educational Networks, SchoolBlocks, plus a few district-specific sites), plus WSBA's statewide vacancy feed for districts without their own structured board |
| Higher ed job postings | Each institution's own job board (NEOGOV, PeopleAdmin, and the University of Wyoming's own Oracle careers site) |
| K-12 salary | [WSBA](https://sites.google.com/wsba-wy.org/my-wsba/wy-education-salaries) (Wyoming School Boards Association) annual teacher salary settlement and superintendent salary documents |
| K-12 staff salaries by position | Wyoming Dept. of Education's WDE602 staff salary collection (`wde602_district_staff_salaries.csv`) |
| K-12 teacher staffing (for vacancy rate) | NCES Common Core of Data (CCD), via the [Urban Institute Education Data Portal](https://educationdata.urban.org) |
| Higher ed faculty salary | IPEDS (federal Integrated Postsecondary Education Data System), via the Urban Institute Education Data Portal |
| Higher ed faculty staffing (for vacancy rate) | IPEDS, same source |
| Higher ed fall enrollment (FTE) | IPEDS via the Urban Institute Education Data Portal, a different survey component from the two rows above — powers a students-per-faculty figure and a 5-year enrollment trend, the HE analogues of K-12's students-per-teacher and county population trend |
| Higher ed Pell Grant recipient share | US Dept. of Education, Federal Student Aid, via the Urban Institute Education Data Portal — the HE analogue of K-12's district child poverty rate (a different federal program, since SAIPE has no HE equivalent) |
| County-level context (median income, median rent, mining/energy employment share, 5-year population trend) | US Census Bureau, American Community Survey 5-Year Estimates, via the [Census Data API](https://www.census.gov/data/developers/data-sets/acs-5year.html) directly — joined onto each K-12 district's own county and, since 2026-08-06, each HE institution's own county too |
| District-level child poverty rate | US Census Bureau, [Small Area Income and Poverty Estimates (SAIPE)](https://www.census.gov/programs-surveys/saipe/data/datasets.html), via the same Census Data API — figures for each district, not for its county like the row above |

WSBA publishes only the current year's salary settlement with no public archive, so this project keeps its own multi-year K-12 salary history (`k12_salary_history.csv`): one snapshot for each new settlement year. IPEDS is queryable by year directly, so higher-ed salary already shows multiple years back.

## Automation

A GitHub Actions workflow runs twice a week (Tuesdays and Fridays since 2026-11-17; Fridays only before; never on Montana's Mondays and Thursdays, since the two projects share one `CENSUS_API_KEY`), re-scrapes every source, regenerates every derived dataset, and commits and pushes if anything changed, which also redeploys the dashboard on Posit Connect Cloud. The workflow is a short caller of edjobs's reusable `weekly-run.yml`.

These steps stop the run before anything is committed:

- The full `testthat` suite, before any real data is touched.
- A sanity check against the previous run: refuses to commit if either K-12 or higher ed lost more than half its postings.
- A schema check (every column the dashboard reads is still there) and a data-quality sweep over the new files.

These only report (in a rolling "Scraper drift check" GitHub issue), so one finding never blocks the data:

- Drift: a source whose posting count falls far below its own history, corroborated by a live browser render of the page; a source that looks broken gets its own auto-fix issue.
- Salary and Census sources: coverage against the last run's files, and values outside plausible bounds. One check watches for IPEDS starting to report Sheridan College and Gillette College separately (they share one figure while the two split into separate colleges).
- Posted pay that stopped arriving from a source, titles that aren't job titles, sources with no rows in recent runs, and frozen boards (a board whose list hasn't changed in weeks).
- A rebuild from the raw archives must reproduce the committed files; the run is checked against `run_expectations.csv`; and a meta-check reports any of these steps that crashed.

Two smaller workflows: `presence.yml` records once a day which postings the platform boards and WSBA's statewide list carry (list pages only; nothing uses it yet: the plan is to date postings' endings to the day), and `upkeep.yml` keeps the schedule from being switched off by GitHub's 60-day inactivity rule and warns before a token expires.

## Repository layout

- `Wy_ED_Jobs.Rmd` — the single pipeline entry point: scrapes every source, classifies and cleans postings, and adds each update's new rows to the accumulated datasets in `Wy_Ed_Jobs/`.
- `Wy_Ed_Jobs/app.R` — the Shiny dashboard itself. Its tabs and most of its server come from edjobs (one function per tab, such as `home_tab_panel()`, and `dashboard_server_shared()`); app.R loads the data, passes Wyoming's text and settings, and keeps the one server block only Wyoming has (the WDE staff salary download).
- `*_scrapers.R`, `k12_he_classification.R`, `drift_check.R`, `scrape_helpers.R` — Wyoming's own scrapers and its parts of classification and monitoring (name corrections, posting identity); each attaches edjobs, which holds the shared platform scrapers, classifier and checks.
- `EDJOBS_VERSION` — the [edjobs](https://github.com/bostickmike/edjobs) version this repo pins: the R package with the code Wyoming and Montana share (platform scrapers, classifier, posting spells, the weekly run's checks, the dashboard's tabs).
- `METHODS.md` — how the numbers are made: what counts as a posting, WSBA de-duplication, categories, pay, vacancy rate, listing duration, context data.
- `DATA_DICTIONARY.md` (and `Wy_Ed_Jobs/data_dictionary.csv`, shown on the dashboard's Data tab) — every published file and column.
- `history_accumulator.R` — adds each update's newly classified rows to the accumulated datasets (a same-day re-run replaces that day's rows; a column mismatch stops the run) instead of reprocessing the whole raw archive each time.
- Census context comes from edjobs: `fetch_census_county_context()` (ACS 5-Year Estimates, by county) and `fetch_census_saipe_child_poverty()` (SAIPE child poverty, by district's NCES id), both joined onto each K-12 district in `salarymap2.csv`.
- `Archivek12_Data/`, `Archived_HE_Data/` — one dated raw snapshot per update (weekly until 2026-11-17, twice a week since), going back to August 2024: the durable source of truth. `scripts/rebuild_*_history_from_archive.R` rebuild the accumulated datasets from these from scratch, for disaster recovery or to check that the incremental path matches a full rebuild (each update checks this too).
- `scripts/repair_uw_pagination_duplicates.R` — a one-time repair for an old University of Wyoming problem: its careers site's paging repeated postings, so some were counted twice. Run it with `--dry-run` and read the report, then with `--apply`; it changes only postings whose Oracle ID repeats and rebuilds the college files they touch.
- `tests/testthat/` — the test suite, built almost entirely on fixtures captured from the live sources (scraped HTML, downloaded PDFs, API responses) rather than made-up data.
- `.github/workflows/weekly-scrape.yml` — the automation described above: a short caller of edjobs's reusable `weekly-run.yml` at the pinned tag, holding Wyoming's cron, secrets and state check.

## Running locally

Requirements: R (>= 4.5.0), the version edjobs requires.

```r
install.packages(c(
  # Pipeline (Wy_ED_Jobs.Rmd) dependencies
  "rmarkdown", "dplyr", "purrr", "readr", "readxl", "rvest",
  "stringr", "tidyverse", "writexl", "xml2", "jsonlite",
  "httr2", "lubridate", "chromote", "rsconnect", "testthat",
  "withr", "here", "pdftools",
  # Dashboard (Wy_Ed_Jobs/app.R) dependencies
  "shiny", "bslib", "shinyWidgets", "DT", "data.table",
  "leaflet", "plotly", "scales", "shinycssloaders"
))
```

Install the pinned edjobs (the app and the pipeline both load it):

```r
pak::pak(paste0("bostickmike/edjobs@v", readLines("EDJOBS_VERSION")))
```

To run the dashboard against the data already committed in the repo (no scraping needed):

```r
shiny::runApp("Wy_Ed_Jobs")
```

To re-run the full scrape/build pipeline (takes a while, hits every live source):

```r
rmarkdown::render("Wy_ED_Jobs.Rmd")
```

The Census county-context chunk needs a free `CENSUS_API_KEY` environment variable (get one at https://api.census.gov/data/key_signup.html and set it in `.Renviron` locally, or as a GitHub Actions secret for the weekly workflow) — every other chunk runs fine without it, but that one step will fail loudly and leave `salarymap2.csv`'s county-context columns untouched if it's missing.

## Testing

```r
testthat::test_dir("tests/testthat")
```

## Licensing

- Source code is licensed under the MIT License — see `LICENSE`.
- Processed datasets and archived CSV files are licensed under Creative Commons Attribution 4.0 International (CC BY 4.0) — see `DATA_LICENSE.md`.

## Contact

Created by Michael Bostick. Originally built by [Mark Perkins](https://github.com/MPerk78/Wyoming-Education-Jobs-Dashboard); this repository has been substantially rewritten and extended since.
