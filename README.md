# Wyoming Education Jobs Dashboard

A live, weekly-updated dashboard of K-12 and higher education job openings across Wyoming, with salary and vacancy-rate data layered in for every district and institution.

**Live dashboard:** https://bostickmike-wyoming-education-jobs-dashboard.share.connect.posit.cloud

## What it does

- **Map** — every K-12 district and higher-ed institution with a current opening, plotted with two dimensions at once: circle size for number of openings, circle color for vacancy rate (openings as a share of teaching/faculty staff).
- **Home** — headline KPIs (with week-over-week deltas), top-hiring tables with 12-week trend sparklines, "biggest mover" callouts, and leaderboards for highest vacancy rate.
- **Jobs Tables** — every open posting, filterable and exportable (copy/CSV/print), per district or institution.
- **District Summary / Institution Summary** — one row per district or college with current openings, vacancy rate, and salary figures (including multi-year salary trends where the source data supports it), fully exportable.
- **Longitudinal Trends** — postings over time by subject/category, with a Simple (5-category) or Detailed (16-18 category) toggle so the chart stays readable either way.
- **Current Trends** — a compact table per category: current count, a trend sparkline, and change vs. a month/quarter/year ago.
- **New This Week** — postings that appeared since the previous weekly snapshot.

## Data sources

| Data | Source |
|---|---|
| K-12 job postings | Each district's own job board (AppliTrack, Red Rover, SchoolSpring, TedK12, Paylocity, and school-site CMSs: Apptegy, Edlio, SmartSites, Educational Networks, SchoolBlocks, plus a few district-specific sites), plus WSBA's statewide vacancy feed for districts without their own structured board |
| Higher ed job postings | Each institution's own job board (NEOGOV, PeopleAdmin) |
| K-12 salary | [WSBA](https://sites.google.com/wsba-wy.org/my-wsba/wy-education-salaries) (Wyoming School Boards Association) annual teacher salary settlement and superintendent salary documents |
| K-12 teacher staffing (for vacancy rate) | NCES Common Core of Data (CCD), via the [Urban Institute Education Data Portal](https://educationdata.urban.org) |
| Higher ed faculty salary | IPEDS (federal Integrated Postsecondary Education Data System), via the Urban Institute Education Data Portal |
| Higher ed faculty staffing (for vacancy rate) | IPEDS, same source |
| Higher ed fall enrollment (FTE) | IPEDS via the Urban Institute Education Data Portal, a different survey component from the two rows above — powers a students-per-faculty figure and a 5-year enrollment trend, the HE analogues of K-12's students-per-teacher and county population trend |
| Higher ed Pell Grant recipient share | US Dept. of Education, Federal Student Aid, via the Urban Institute Education Data Portal — the HE analogue of K-12's district child poverty rate (a different federal program, since SAIPE has no HE equivalent) |
| County-level context (median income, median rent, mining/energy employment share, 5-year population trend) | US Census Bureau, American Community Survey 5-Year Estimates, via the [Census Data API](https://www.census.gov/data/developers/data-sets/acs-5year.html) directly — joined onto each K-12 district's own county and, since 2026-08-06, each HE institution's own county too |
| District-level child poverty rate | US Census Bureau, [Small Area Income and Poverty Estimates (SAIPE)](https://www.census.gov/programs-surveys/saipe/data/datasets.html), via the same Census Data API — real per-district figures, not county-level like the row above |

WSBA publishes only the current year's salary settlement with no public archive, so multi-year K-12 salary history is captured and grown by this project's own weekly pipeline going forward, one snapshot per new settlement year. IPEDS is queryable by year directly, so higher-ed salary already shows multiple years back.

## Automation

A GitHub Actions workflow runs twice a week (Tuesdays and Fridays since 2026-11-17; Fridays only before), re-scrapes every source, regenerates every derived dataset, and commits + pushes if anything changed — which also triggers an automatic Posit Connect Cloud redeploy. Several non-blocking checks run alongside it:

- Full `testthat` suite must pass before any real data is touched.
- A sanity check compares the new pull against the previous run and refuses to commit if either side dropped more than half its postings.
- Drift detection flags any source whose posting count falls far below its own historical baseline, with a live `chromote` render of the page as corroboration before anything is filed as a GitHub Issue.
- Salary-source coverage checks compare each source (WSBA, CCD, IPEDS) with the last run's committed salary files and flag a source that comes back with values for fewer districts or colleges than before, or with values outside plausible bounds.
- The same coverage + value-plausibility checks run for the Census ACS/SAIPE sources (county income/rent/mining-share/population-trend, district child poverty) — flagging if fewer counties/districts come back than expected, or if a figure lands outside a generous sane range.
- A dedicated check watches for IPEDS starting to report Sheridan College and Gillette College as separate institutions (they currently share one combined figure, since the two are in the process of splitting into separate colleges).

## Repository layout

- `Wy_ED_Jobs.Rmd` — the single pipeline entry point: scrapes every source, classifies and cleans postings, and appends this week's newly derived rows onto the accumulated datasets in `Wy_Ed_Jobs/`.
- `Wy_Ed_Jobs/app.R` — the Shiny dashboard itself. Its tabs and most of its server come from edjobs (one function per tab, such as `home_tab_panel()`, and `dashboard_server_shared()`); app.R loads the data, passes Wyoming's text for each tab, and keeps the server blocks that still differ by state.
- `*_scrapers.R`, `k12_he_classification.R`, `drift_check.R`, `scrape_helpers.R` — Wyoming's own scrapers and its parts of classification and monitoring (name corrections, posting identity); each attaches edjobs, which holds the shared platform scrapers, classifier and checks.
- `EDJOBS_VERSION` — the [edjobs](https://github.com/bostickmike/edjobs) version this repo pins: the R package with the code Wyoming and Montana share (platform scrapers, classifier, posting spells, the weekly run's checks, the dashboard's tabs).
- `history_accumulator.R` — appends each week's newly classified rows onto the existing accumulated datasets (idempotent, schema-checked) instead of reprocessing the full raw archive every run.
- edjobs `fetch_census_county_context()` — county-level socioeconomic context from the Census Bureau's ACS 5-Year Estimates, joined onto each K-12 district's own county in `salarymap2.csv`.
- edjobs `fetch_census_saipe_child_poverty()` — district-level child poverty (by NCES id) rate from the Census Bureau's SAIPE program, joined directly onto each K-12 district (not county-level like the ACS fetch).
- `Archivek12_Data/`, `Archived_HE_Data/` — one dated raw snapshot per week, going back to August 2024, still written every run as the durable source of truth. `scripts/rebuild_*_history_from_archive.R` rebuild the accumulated datasets from these from scratch, for disaster recovery or to verify the incremental path hasn't drifted.
- `scripts/repair_uw_pagination_duplicates.R` — narrow, fail-closed repair for the historical UW Oracle pagination incident. Run `Rscript scripts/repair_uw_pagination_duplicates.R --dry-run`, review the report, then run it with `--apply` to repair verified repeated Oracle IDs and rebuild affected current/historical HE datasets.
- `tests/testthat/` — the test suite, built almost entirely on real captured fixtures (real scraped HTML, real downloaded PDFs, real API responses) rather than synthetic data.
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
