# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

An R pipeline + Shiny dashboard that scrapes K-12 and higher-ed job postings across Wyoming weekly, layers in salary/vacancy-rate/socioeconomic context from federal and state sources, and republishes a live dashboard. Runs unattended via GitHub Actions twice a week, Tuesdays and Fridays (Fridays only before 2026-11-17; Montana runs Mondays and Thursdays because the two share one `CENSUS_API_KEY`). Originally built by Mark Perkins, substantially rewritten since.

**Shared code lives in the `edjobs` package** ([bostickmike/edjobs](https://github.com/bostickmike/edjobs); migration plan in the workspace's `claude-notes/2026-11-10_r-package-migration-plan.md`). This repo pins a tagged version in `EDJOBS_VERSION`; every workflow that runs the tests installs it (`weekly-scrape.yml`, and `.github/actions/setup-r-env` for the PR, Copilot and Claude auto-fix workflows). Locally: `pak::pak(paste0("bostickmike/edjobs@v", readLines("EDJOBS_VERSION")))`, or `devtools::load_all("../edjobs")` while changing the package. `test-run-expectations.R` fails if the installed version isn't the pinned one. A function that has moved to the package is deleted here in the same change: a local copy would mask the package's. Bump `EDJOBS_VERSION` only after the package's tag passes its own check and a full rehearsal; the weekly run doesn't gate a bump (when unsure, test-dispatch the weekly workflow on a branch copy and discard its data). In the package since phase 2 (2026-11-11): the classifier and posted pay, IPEDS staff salaries, the shared drift/data-quality/auto-fix helpers, `check_file_schema()`, `check_total_matches_parts()`, `rebuild_parity_row()`; this repo's `k12_he_classification.R`, `drift_check.R`, `schema_check.R` and `history_accumulator.R` keep the state's own parts and attach edjobs. Phase 3 (2026-11-11, edjobs 0.5.0) moved the shared platform code (AppliTrack fetch/parse, SchoolSpring details and ending reasons, PeopleAdmin page pay and dates, NEOGOV card pay); `direct_api_scrapers.R` attaches edjobs. Phase 4 began 2026-11-11 (edjobs 0.6.0): the posting-spells engine (`build_posting_spells()`, bridging, durations, the first-seen lookup) is in edjobs; this repo's `posting_spells.R` keeps the panels that read its archives and the `spell_rules()` it builds under (WY_SPELL_RULES). A scraper-autofix issue whose fetch function is an edjobs export gets a companion issue on edjobs, assigned to Copilot there (`COPILOT_TOKEN` covers edjobs); if it's still flagged later, the Claude fallback runs from this repo with edjobs checked out at the pinned tag in `.edjobs/` and opens its fix PR on edjobs. After an edjobs fix merges: tag, and bump `EDJOBS_VERSION` in both states. Phase 4, 2026-11-12 (edjobs 0.11.0): the platform fetchers both states call (SchoolSpring list, TedK12, PeopleAdmin feed, NEOGOV classic careers page with each posting's page for its dates, `parse_jobposting_jsonld()`, `assign_shared_board_institutions()`) are in edjobs; `direct_api_scrapers.R` keeps only this state's own platforms.

## Commands

Install deps (two separate sets — pipeline vs. dashboard):
```r
install.packages(c(
  "rmarkdown", "dplyr", "purrr", "readr", "readxl", "rvest",
  "stringr", "tidyverse", "writexl", "xml2", "jsonlite",
  "httr2", "lubridate", "chromote", "rsconnect", "testthat",
  "withr", "here", "pdftools",
  "shiny", "bslib", "shinyWidgets", "DT", "data.table",
  "leaflet", "plotly", "scales", "shinycssloaders"
))
```

Run the full test suite:
```r
testthat::test_dir("tests/testthat")
```
Run a single test file: `testthat::test_file("tests/testthat/test-k12-classification.R")`.

Run the dashboard against data already committed (no scraping):
```r
shiny::runApp("Wy_Ed_Jobs")
```

Re-run the full scrape/build pipeline (slow, hits every live source):
```r
rmarkdown::render("Wy_ED_Jobs.Rmd")
```
Needs a `CENSUS_API_KEY` env var (`.Renviron` locally) for the Census ACS chunk only — everything else runs without it.

Post-pipeline checks the CI workflow runs, in order (useful to run manually when debugging a bad pipeline run):
```r
Rscript .github/scripts/sanity_check.R      # blocking: refuses if either dataset lost >50% of rows
Rscript .github/scripts/verify_schema.R     # blocking: every column app.R expects is still present
Rscript .github/scripts/check_drift.R       # diagnostic only: per-source count vs. historical baseline
Rscript .github/scripts/check_salary_drift.R   # diagnostic: WSBA/CCD/IPEDS coverage vs. last run's committed files (edjobs salary_drift_step())
Rscript .github/scripts/check_census_drift.R   # diagnostic: ACS/SAIPE coverage + value plausibility
Rscript .github/scripts/check_pay_coverage.R   # diagnostic: sources whose posted pay went missing vs. their own history, plus implausible amounts blanked this run
Rscript .github/scripts/check_title_quality.R  # diagnostic: titles that aren't job titles (page text, summaries, pay Posted Pay lacks), and sources whose Other share jumped vs. their last 8 weeks
Rscript .github/scripts/check_silent_sources.R  # diagnostic: sources with no rows in their last weekly runs (less silent_sources_acknowledged.csv)
Rscript .github/scripts/check_frozen_boards.R   # diagnostic (the state check): boards whose posting set hasn't changed in 12+ weeks
Rscript .github/scripts/check_rebuild_parity.R  # diagnostic: a rebuild from the raw archives reproduces the committed files
RUN_DATE=2026-11-13 Rscript .github/scripts/check_run_expectations.R  # diagnostic: this run's files against run_expectations.csv
```
`run_expectations.csv` holds one row per thing a person expects after a change lands (file, R filter, R measure, min/max, the run dates it applies to; logic in the `edjobs` package). Write expectations for the next run there rather than as a hand-read watch-list; `test-run-expectations.R` validates the file and the pinned `edjobs` version, and failures go in the drift issue. A `guard` job ahead of the scrape skips a *scheduled* run when main already has that day's `Automated weekly data refresh` commit (GitHub starts the cron hours late, after a manual dispatch has pushed); manual dispatches always run, and `concurrency` keeps two runs from overlapping.
`check_salary_drift.R` also flags the pay-estimate reference tables (OEWS, QCEW, IPEDS staff pay, UW salary book) whose refresh failed, was rejected by `write_reference_file()`, didn't run, or went stale (edjobs `reference_table_status()`).

Disaster-recovery / verification rebuilds (reprocess the full raw archive from scratch, bypassing the incremental accumulator):
```r
source("scripts/rebuild_k12_history_from_archive.R"); rebuild_k12_history_from_archive()
source("scripts/rebuild_he_history_from_archive.R"); rebuild_he_history_from_archive()
```
The rebuild reproduces the committed files exactly (`Rscript .github/scripts/check_rebuild_parity.R`, also a non-blocking weekly step), because `build_k12_combinedclean()` / `build_k12_teacher_rows()` (`history_accumulator.R`) are shared with the pipeline. The classifier lives in edjobs (`R/k12_he_classification.R`) since phase 2 (2026-11-11). After changing it there (or this repo's `k12_he_classification.R`, which keeps only the state's name corrections and posting identity), reclassify the committed data with `Rscript scripts/reclassify_committed_data.R --edjobs ../edjobs` (dry run; `--apply` writes; run it with the pinned tag installed: it compares the pinned tag with the edjobs checkout, and when the checkout's `R/` differs it rebuilds in a child process with the checkout installed in a temporary library, since the rebuild runs in edjobs's namespace): `test-weekly-data-quality.R` fails until every committed bucket equals what the classifier gives its title (and the posting spells' `Position`). Review a classifier change with `Rscript scripts/classifier_archive_diff.R --edjobs ../edjobs` (pinned tag vs. checkout; add `--also ../<sibling repo>` for both states' archives): it lists every archived title whose bucket moves, and every line should be intended; the reclassify script prints it too. A bare word in a pattern matches inside other words ("Aide" in "Raiders", "Para" in "Paradise"): anchor with `\b`, and add a golden-set guard row.

One-off repair scripts follow a `--dry-run` then `--apply` pattern, e.g.:
```
Rscript scripts/repair_uw_pagination_duplicates.R --dry-run
Rscript scripts/repair_uw_pagination_duplicates.R --apply
```

## Architecture

**`Wy_ED_Jobs.Rmd` is the single pipeline entry point.** It's a linear sequence of knitr chunks: scrape every K-12 platform (AppliTrack, TedK12, SchoolSpring/RedRoverK12, misc-district registry, WSBA statewide feed) → combine/classify/dedupe → K-12 salary (WSBA PDFs) → K-12 staffing (CCD via Urban Institute) → Census ACS/SAIPE context → then the same shape again for Higher Ed (per-institution scrapers → combine/classify → IPEDS salary/enrollment → FSA Pell → Census ACS). Every scrape call is wrapped in `safe_scrape()` (`scrape_helpers.R`) so one source failing degrades to "missing from this week" instead of aborting the whole run, and logs to `scrape_log.csv`.

**Shared logic lives outside the Rmd** specifically so it can't drift between "what the notebook produces next run" and "what a from-archive rebuild produces now": `k12_he_classification.R` (this state's name corrections and posting identity; it attaches edjobs, which holds the title-encoding repair and position/subject/category classification since phase 2, 2026-11-11), `scrape_helpers.R` (`safe_scrape`/logging), `schema_check.R` (column-presence contract for every shipped file), `drift_check.R` (baseline-vs-current count comparison).

**Stale board ads are flagged, not counted (edjobs 0.90.0, 2026-11-24).** In the combine chunk, `flag_stale_k12_rows()` (`misc_district_scrapers.R`) runs edjobs `flag_stale_board_postings()` (the rule is `state_config(stale_rule = )`, package default) on the board rows and the district-website rows: a posting whose posted date, or a stated closing date that parses, is before the July 1 that began the previous school year gets `Stale_Reason`, except standing pools and ongoing roles (bus, para/aide, custodial/maintenance, food service, athletic coaches). WSBA rows aren't judged by their dates, but one that is the same ad as a flagged posting (`wsba_duplicates_direct()`) is split off with `STALE_FEED_LINK_REASON` before `remove_wsba_direct_duplicates()` (which then sees only unflagged board rows) and before the WSBA page checks, so it can't come back through WSBA. The raw archive keeps all of them; `combinedclean` is built from `drop_stale_rows(combined)`, and `rebuild_k12_history_from_archive()` drops them the same way (archives before the rule have no column: forward-only, METHODS.md "Old board ads"). The posting spells keep flagged board rows (a spell follows what the board listed) and leave out the WSBA copies, which earlier runs never archived. Measured in the workspace's `claude-notes/2026-11-24_stale-ats-ads/README.md`; built in `claude-notes/2026-11-24_stale-rule/`.

**`history_accumulator.R` is the incremental-append layer.** Most datasets in `Wy_Ed_Jobs/` are *accumulated* (grow by one week's rows per run, idempotent on same-day re-runs) rather than rebuilt from scratch every time — `append_weekly_rows()` fails loudly on a column mismatch rather than silently writing a jagged file. `combinedclean.csv`, `hedata.xlsx`, `allnow.csv`, `allnow_he.csv` are the exceptions: current-week-only snapshots, rebuilt fresh every run. `DATA_DICTIONARY.md` (and `Wy_Ed_Jobs/data_dictionary.csv`, tested against the files) documents every shipped file's columns and `METHODS.md` how the numbers are made — treat `schema_check.R`'s `REQUIRED_SCHEMAS` as the enforced source of truth if the two ever disagree.

**Two independent durable archives are the disaster-recovery source of truth**: `Archivek12_Data/*.csv` and `Archived_HE_Data/*.xlsx`, one dated raw snapshot per week since August 2024, written every run regardless of the incremental path. `scripts/rebuild_*_history_from_archive.R` reprocess these from scratch and must stay equivalent to what `history_accumulator.R`'s incremental path produces — `tests/testthat/test-history-accumulator.R` is the test that enforces that equivalence.

**`Wy_Ed_Jobs/app.R`** is the deployed Shiny dashboard, and is deployed *standalone* to Posit Connect Cloud (only that subfolder is bundled, not the repo root) — it cannot `source()` anything at the repo root. Its shared helpers come from the edjobs package instead (`library(edjobs)`; manifest.json installs it from GitHub at the pinned tag), including the schema guard (`validate_and_pad_schema()` — missing columns become NA-backfilled plus a Home-tab banner, not a crash; the app's `note_load_issue()` collects the banner text) and HE appointment classification (`classify_he_appointment()`), since edjobs 0.36.0/0.37.0 (package phase 6). Since step 7 of the package review (edjobs 0.60.0-0.68.0, 2026-11-21) the tabs are edjobs functions (`home_tab_panel()`, `map_tab_panel()`, `jobs_tab_panel()`, `k12_trends_panel()`, `k12_districts_panel()`, `he_trends_panel()`, `he_colleges_panel()`, the Listing Duration and Data tabs) that take the state's text as arguments, and `dashboard_server_shared()` holds the server blocks both states had alike; app.R keeps the data loading, the state's text and settings, and its `DISTRICT_SPEC` (edjobs `district_spec()`, 0.71.0): the Districts tab's pay and budget columns, their map popup lines, the compare plot's bars and the footnote's source paragraphs. Since 0.71.0 every server block is in edjobs apart from Wyoming's WDE staff download. The map's opening view and the Institution Summary's settings are `dashboard_server_shared()` arguments (edjobs 0.69.0), and K-12 "new this week" is edjobs `find_k12_new_postings()` (0.70.0): a new `Posting_ID`, less ID changes (a new ID replacing, one for one, a gone posting with the same title, location and district). A change to a tab's layout goes in edjobs; check it with the shinytest2 parity scripts (`claude-notes/2026-11-21_step7-slice1/app_parity.R`).

**Tests are built on real captured fixtures** (real scraped HTML, downloaded PDFs, API responses) rather than synthetic data — `tests/testthat/helper-setup.R` sources every scraper/classifier/repair module before any test file runs. `test-data-integrity.R` reads the actual committed summary CSVs (not fixtures) as a live data-contract check.

**CI (`.github/workflows/weekly-scrape.yml`)**, since 2026-11-20 a short caller of edjobs's reusable `.github/workflows/weekly-run.yml` at the `EDJOBS_VERSION` tag (`test-weekly-workflow-ref.R`; this repo's part is its cron, secrets, `check_frozen_boards.R` as its state check and its own commit files, all as inputs), runs the full test suite first (blocks on failure) → renders the pipeline → `sanity_check.R`, `verify_schema.R` and the data-quality sweep (`test-weekly-data-quality.R`), all blocking → the diagnostic checks (`continue-on-error: true`: drift with live corroboration, salary and Census coverage, posted-pay coverage, title quality, silent sources, frozen boards, rebuild parity, run expectations, the presence check's recency; results filed as a GitHub Issue) → a meta-check that a diagnostic step *crashing* (vs. cleanly finding nothing) is still surfaced despite `continue-on-error` → regenerates and validates the Connect Cloud manifest → commits and pushes changed data files, which triggers the Connect Cloud redeploy.

## Git conventions and gotchas

- This repo is a fork of `MPerk78/Wyoming-Education-Jobs-Dashboard` (`git remote -v` shows both `origin` and `upstream`).
- The weekly CI run commits and pushes automatically with the message `Automated weekly data refresh (YYYY-MM-DD)`, touching only the specific `Wy_Ed_Jobs/*`, `Archived_HE_Data/*.xlsx`, and `Archivek12_Data/*.csv` paths listed explicitly in `weekly-scrape.yml`'s commit step — don't assume other generated files get picked up the same way.
- **Never commit `OneDrive_1_8-4-2026/`** — it's gitignored specifically because it contains a live OpenAI API key (`OpenAI.txt`) plus large RSelenium binaries; it's Mark's old working folder, kept locally for reference only.
- Root-level `all_direct_k12_job_listings.csv` (and the `.Rproj` file) are untracked local artifacts, not pipeline output — the real accumulated datasets live under `Wy_Ed_Jobs/`, not the repo root.
- K-12 scraping is driven by `k12_district_registry.csv`, one row per scrape target, in the schema both states share since 2026-11-16 (`District, NCES_LEAID, City, County, Latitude, Longitude, Platform, Platform_Key, Job_Link, List_Start, List_Stop, List_Skip`; `Platform_Key` is AppliTrack's tenant path, SchoolSpring's domain, Red Rover's numeric org id or Paylocity's company id; the AppliTrack and SchoolSpring keys must equal what the Rmd's loop derives from `Job_Link`, which `test-drift-check.R` checks). It holds the direct boards (AppliTrack/TedK12/SchoolSpring/RedRoverK12, scraped in the Rmd's registry loop via `read_direct_board_registry()`), the 13 districts and charter schools scraped from their own pages (`misc_district_registry` in `misc_district_scrapers.R` is those rows; until 2026-11-16 it was a data frame there) and Laramie Montessori. It replaced three separately-maintained link CSVs (`Frontline_job_links.csv`, `tedk12_job_links.csv`, `springer_job_links.csv`) which, in practice, had come to carry the same district under three different misspellings. The colleges are rows of `he_institution_registry.csv` (until 2026-11-16, nine hard-coded calls in the Rmd). Its `Town` column is the main campus's Census place; `places.csv` (every Census place in Wyoming: Town, County, internal point; 2024 Gazetteer + county boundaries) lets edjobs `place_he_postings()` put a college posting whose Location names another town (CWC Jackson, LCCC Laramie, UW Extension offices) on its own map dot (`Campus_*`, `Place_Basis` in hedata.xlsx; 2026-11-16). Stage 2 (edjobs 0.34.0): a title marker ("(Rock Springs Campus)") or an explicit sentence on a PeopleAdmin page ("This position is located in Wright, WY", "at the Green River Center") also places a posting; several towns stay at the main campus.

## Working with scraped-title text

Sources mix UTF-8 and raw Windows-1252 bytes in job titles (e.g. en dashes in time ranges). `fix_title_encoding()` (edjobs) is the single point where this is repaired — applied once at ingestion in `Wy_ED_Jobs.Rmd`, not just inside the classifier functions — because a private copy fixed only for regex matching and then discarded still leaves the mangled bytes in what gets archived and displayed. Never re-add per-source encoding handling; route through this function.
