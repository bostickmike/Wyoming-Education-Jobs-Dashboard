# Wyoming Education Jobs Dashboard — Project Progress Ledger

**Maintainers & Authors:** Mike Bostick & Mark Perkins  
**Target Environment:** Posit Connect Cloud (Shiny for R)  
**CI/CD Orchestration:** GitHub Actions (`.github/workflows/weekly-scrape.yml`)  
**Production Cadence:** Automated weekly scrape & build every Friday 05:00 UTC (and manual `workflow_dispatch`)  
**Repository Branch:** `main`

---

## 1. Executive Summary & Purpose

This ledger serves as the authoritative, version-controlled record of feature development, pipeline hardening, data schema evolution, and cross-state feature synchronization between the **Wyoming Education Jobs Dashboard** and its sister project, the **Montana Education Jobs Dashboard**.

Unlike ephemeral conversation logs or local scratch handoffs, this document lives within the repository root so any human contributor, collaborator, or autonomous coding agent can instantly understand the exact state of the system, what has been implemented, active guardrails, and upcoming priorities.

---

## 2. Feature & Architecture Parity Matrix (WY vs. MT)

| Capability / Module | Wyoming (`Wy_Ed_Jobs`) | Montana (`Mt_Ed_Jobs`) | Parity Status | Implementation Notes |
| :--- | :--- | :--- | :--- | :--- |
| **K-12 Active Jobs Table** | Implemented | Implemented | **Full Parity** | Filterable by district, position, subject, broad category; exportable. |
| **K-12 District Summary** | Implemented | Implemented | **Full Parity** | District profiles, student-teacher ratios, salary benchmarks. |
| **K-12 Longitudinal Trends** | Implemented | Implemented | **Full Parity** | Multi-year vacancy volume time series with rolling averages. |
| **K-12 Current Trends** | Implemented | Implemented | **Full Parity** | In-season bar/donut distributions by category & subject. |
| **K-12 New This Week** | Implemented | Implemented | **Full Parity** | Delta detection vs. prior week's scrape snapshot. |
| **K-12 Vacancy Spells & Time-to-Fill** | Implemented | Implemented | **Full Parity** | Interactive Shiny tab (`k12_spells`) with KPIs, histograms, and spell tables. |
| **Higher Ed Vacancy Spells & Time-to-Fill** | Implemented | Implemented | **Full Parity** | Interactive Shiny tab (`he_spells`) with KPIs, duration histograms, discipline breakdown, and spell table. |
| **Higher Ed Jobs Table** | Implemented | Implemented | **Full Parity** | Faculty, adjunct, and institutional staff postings. |
| **Higher Ed Summary & Trends** | Implemented | Implemented | **Full Parity** | IPEDS instructional salary benchmarks & enrollment. |
| **Geographic Leaflet Map** | Implemented | Implemented | **Full Parity** | Cluster-mapped district & college vacancy pins. |
| **Data Sources & Codebook Tab** | Implemented | Implemented | **Full Parity** | Direct CSV download buttons and interactive schemas. |
| **Federal NCES LEA IDs** | Embedded (48/48) | Embedded (191/191) | **Full Parity** | 7-digit `NCES_LEAID` in registry, `salarymap2.csv`, and `job_duration_spells.csv`. |
| **Federal IPEDS UNITIDs** | Embedded (8/8) | Embedded (23/23) | **Full Parity** | 6-digit `IPEDS_UNITID` in higher ed institutional registry and `salarymap.csv`. |
| **Pipeline Dry-Run Test Harness** | Implemented | Implemented | **Full Parity** | Evaluates scrape combination chunks against mock data frames in CI. |
| **Pipeline AST Defensive Linting**| Implemented | Implemented | **Full Parity** | Blocks syntax typos and enforces date coercions. |
| **Connect Cloud Manifest Engine** | Implemented | Implemented | **Full Parity** | Enforces literal `null` metadata and users blocks for Connect Cloud. |

---

## 3. Implementation Chronology & Milestones

### Milestone 1: Core Architecture & Vacancy Spells Model (Wyoming Origin)
* **K-12 Vacancy Spells & Duration Panel:**
  * Pioneered the empirical duration spell panel (`job_duration_spells.csv`) tracking time-to-fill, right-censored vacancies, and subject-area shortages across Wyoming school districts.
  * Designed the interactive `k12_spells` dashboard module featuring:
    - 4 reactive summary KPIs (Median Days Open, Long-Duration Vacancies, Active vs. Closed).
    - Density/histogram distributions and role-level duration box plots.
    - Exportable tabular panel for labor economists and empirical education policy analysts.
* **Federal Universal Identifiers Integration:**
  * Embedded official 7-digit `NCES_LEAID` Local Education Agency identifiers from NCES CCD into `k12_district_registry.csv`, `salarymap2.csv`, and `job_duration_spells.csv`.
  * Embedded 6-digit `IPEDS_UNITID` for all Wyoming community colleges and the University of Wyoming in `salarymap.csv`.
* **State Staffing Matrix Integration:**
  * Integrated Wyoming Department of Education (WDE602) staffing salary reports, providing role-specific district average total compensation benchmarks (`Role_Avg_Salary`) alongside WSBA minimum base teacher salaries.

### Milestone 2: Cross-State Scraper Defensive Engineering (October 2026)
* **`safe_scrape()` Enhancements:**
  * Hardened `safe_scrape()` in `scrape_helpers.R` to enforce character coercion on `date_posted` and `Posted_Date` fields upon return. This guarantees compatibility with `empty_df()` and blocks `bind_rows()` type collisions across heterogeneous scrapers.
* **Pipeline Dry-Run Test Harness:**
  * Implemented `tests/testthat/test-pipeline-orchestration-dryrun.R` executing mock chunk evaluations of data combination logic in ~0.3s.
* **Attribution Harmonization:**
  * Standardized project authorship across dashboard headers, data dictionaries, and codebooks to:  
    *"Developed by Mike Bostick and Mark Perkins"*.

### Milestone 3: Higher Education Vacancy Duration Spells & Script Parity
* **Collegiate Vacancy Spells & Time-to-Fill (`he_job_duration_spells.csv` & `he_spells`):**
  * Derived longitudinal collegiate duration spell panels from `facultydata.csv` tracking time-to-fill, right-censored vacancies, and academic discipline indicators across all Wyoming colleges and UW (711 spells).
  * Implemented interactive `he_spells` module in `Wy_Ed_Jobs/app.R`:
    - 4 reactive summary KPIs: Median Vacancy Duration (Days), Currently Open Searches, Persistent Searches (≥90d), Longest Duration Discipline.
    - 4 reactive user filters: Vacancy Status, Appointment Type (Regular vs Adjunct), Academic Focus (STEM, Health Sciences, CTE), Institution Picker.
    - 2 Plotly interactive visualizations: Median Days Open by Discipline horizontal bar chart and binned duration distribution histogram.
    - Searchable DT data table with CSV and Excel export buttons.
    - Direct CSV download button in the *Data Sources & Open Research Downloads* tab (`he_job_duration_spells.csv`).
  * Created standalone automated generator scripts `scripts/generate_he_job_duration_spells.R` and `scripts/generate_job_duration_spells.R`.
  * Added `he_job_duration_spells.csv` to `REQUIRED_SCHEMAS` in `schema_check.R`, verified with `test-schema-check.R`.
  * Documented all schema variables in `DATA_DICTIONARY.md`, `data_dictionary.csv`, and `DATA_COOKBOOK.md`.
  * Integrated automated spell generation step into `.github/workflows/weekly-scrape.yml`.

### Milestone 4: Interactive Spells Hardening, Research Downloads Parity & UX Polish
* **Interactive Vacancy Spells Resiliency:**
  * Added zero-row / empty filter state handling across both K-12 and Higher Ed vacancy spells modules (`k12_spells`, `he_spells`):
    - Reactive KPIs return clean zero counts (`0 Days`, `0 Open Spells`, `0 Persistent Spells`, `None`) instead of NaN or errors.
    - Plotly duration and distribution charts render clean, informative placeholder notifications (`"No vacancy spells match the selected filter criteria"`) instead of leaving an empty white canvas.
    - Duration distribution histograms regularized with `tidyr::complete()` across all 5 standard duration bins (`1–14 Days`, `15–30 Days`, `31–60 Days`, `61–90 Days`, `90+ Days` for K-12; `1–30 Days`, `31–60 Days`, `61–90 Days`, `91–180 Days`, `180+ Days` for Higher Ed), guaranteeing consistent axes and comparable geometries under dynamic filtering.
    - Searchable DT spell tables render clean empty states without `req()` blocking.
* **Homepage Interactive Drill-Down:**
  * Enhanced "Top K-12 Hiring Districts This Week" and "Top Higher Ed Hiring Institutions This Week" tables with clickable employer action links.
  * Clicking any top employer automatically selects that employer, switches to the filtered `k12_table` or `he_table`, and displays all active positions.
  * Hardened `observeEvent(input$popup_view_jobs)` to seamlessly handle mapped institutions, direct scrape LEAs, and statewide locations.
* **Open Research Downloads Completeness:**
  * Added direct CSV downloads for both **K-12 Weekly Vacancies** (`download_weekly_totals`, serving `k12_district_weekly_totals.csv`) and **Higher Ed Weekly Vacancies** (`download_he_weekly_totals`, serving `he_institution_weekly_totals.csv`).
  * Documented both series in `Wy_Ed_Jobs/data_dictionary.csv` and `DATA_DICTIONARY.md`.
* **Data Quality Test Suite Expansion:**
  * Registered `job_duration_spells.csv` and `he_job_duration_spells.csv` into `ALL_OUTPUT_CSVS` in `test-weekly-data-quality.R`, enforcing automated verification against NaN, Inf, and literal string leakage across 1,296 passing tests.
* **Attribution Harmonization:**
  * Harmonized home tab footer attribution to `"Developed by Mike Bostick and Mark Perkins"`.

### Milestone 5: Tab Navigation Consolidation & Head-to-Head Comparator Modules
* **Sidebar Navigation Consolidation:**
  * Streamlined sidebar navigation from 16 tabs down to 10 tabs, removing sidebar clutter while preserving 100% of underlying analytical modules.
  * Replaced flat tab list with organized `tabBox` subtab navigation:
    - **Profiles & Compare** (`k12_summary` / `he_summary`): Subtab 1: Directory Table, Subtab 2: Head-to-Head Comparator.
    - **Current Trends & New** (`k12_current` / `he_current`): Subtab 1: Category & Discipline Breakdown, Subtab 2: New This Week Postings.
    - **Trends & Duration Spells** (`k12_trends` / `he_trends`): Subtab 1: Longitudinal Hiring Trends, Subtab 2: Vacancy Spells & Time-to-Fill.
* **Side-by-Side District & College Comparator:**
  * Built interactive Head-to-Head Comparators allowing users to select and benchmark up to 4 districts or colleges simultaneously.
  * Dynamic comparative cards display active openings, vacancy rates, compensation (starting base, average total pay, IPEDS faculty compensation), student enrollment, student-to-staff ratios, and community socioeconomic metrics.
  * Comparative Plotly visualizations for salary benchmarks, staffing scale, and appointment distributions.
  * Real-time filtered openings table showing active postings across the selected employers.
  * One-touch quick presets for "Top Hiring" and "Largest Enrollment" employers.
* **Test Suite Expansion & Zero-Warning Cleanliness:**
  * Added automated reactive tests in `test-app-reactives.R` verifying comparator card rendering, Plotly graphics, tabular filters, and preset button event handlers.
  * Updated `LEAF_TABS` contract in `test-app-boot-smoke.R` to reflect the 10 consolidated destination tabs.
  * Verified 1,312 passing tests (0 fails, 0 warnings, 1 skip on CRAN).

### Milestone 6: Map Multi-Dimensional Filtering & Responsive Navigation (2026-10-28)
* **Multi-Dimensional Map Filter Panel:**
  * Built an integrated responsive control panel directly above the interactive Leaflet map featuring:
    - **Employer Type:** Toggle K-12 Districts, Higher Ed Institutions, or both.
    - **County Filter:** Dropdown populated from all 23 Wyoming counties with clean user-facing labels (e.g., "Albany County", "Laramie County").
    - **Salary Benchmark Tier:** Filter by average educator compensation ($70,000+ Average Pay, $60,000 - $70,000, Under $60,000) harmonizing district teacher average pay (with starting base fallback) and IPEDS faculty average pay.
    - **Posting Volume & Urgency:** Filter by employer hiring intensity (All Active Locations, High Volume 5+ openings, Multiple Openings 2+, New Postings This Week).
    - **1-Click Reset:** Single-click "Reset Filters" action button restoring all controls to default statewide view.
* **Dynamic Filter Result Badge:**
  * Real-time indicator displaying matching location counts and cumulative active openings across the filtered locations (`Showing X of Y active locations (Z current openings across filtered locations)`).
  * Informative warning state with guidance to broaden filters when zero locations match the selected criteria.
* **Responsive Geo-Spatial Viewport Centering:**
  * Automatically pans and bounds-zooms the Leaflet map viewport to the selected county when a user chooses a county filter, and smoothly returns to the statewide Wyoming view when reset.
* **Defensive Marker Lifecycle & Zero-Row Guarding:**
  * Ensured `leafletProxy` reliably clears markers without generating orphaned popups or JavaScript errors on 0-row filter states.
* **Automated Reactive Test Coverage:**
  * Added comprehensive tests in `test-app-reactives.R` verifying default filtering, single and combined filter attributes, county zoom coordinates, empty state handling, and reset triggers (20 new tests, 1,332 total tests passing with 0 fails and 0 warnings).

### Milestone 7: Research Data Dictionary Completeness & Automated Codebook Invariants (2026-10-28)
* **100% Data Dictionary & Codebook Column Coverage:**
  * Expanded `Wy_Ed_Jobs/data_dictionary.csv` to 131 variables across all 10 public research download CSVs on the Data Sources tab.
  * Resolved documentation drift for `k12jobanalysis.csv` (76,000+ historical records), Census ACS variables (`Median_Household_Income`, `Median_Gross_Rent`, `Population`, `Mining_Employment_Share`), WDE staffing subgroups, and IPEDS historical faculty compensation.
  * Synchronized [`DATA_DICTIONARY.md`](file:///Users/mikebostick/Jobs_Dash_repos/Wyoming-Education-Jobs-Dashboard/DATA_DICTIONARY.md) markdown codebook with complete markdown tables and universal identifier definitions (`NCES_LEAID`, `IPEDS_UNITID`).
* **Automated Codebook Invariant Test Harness:**
  * Created [`tests/testthat/test-data-dictionary.R`](file:///Users/mikebostick/Jobs_Dash_repos/Wyoming-Education-Jobs-Dashboard/tests/testthat/test-data-dictionary.R) enforcing:
    - 100% column documentation: every column in every public download CSV must exist in `data_dictionary.csv`.
    - Zero phantom columns: every documented column must exist in the target dataset.
    - Non-empty descriptions and valid data types.
    - Synchronized dataset inventories between Shiny UI download handlers and `data_dictionary.csv`.
* **Data Quality Test Suite Registration:**
  * Added `data_dictionary.csv` to `ALL_OUTPUT_CSVS` in `tests/testthat/test-weekly-data-quality.R`.
  * Verified 1,390 passing tests across the entire test suite (0 fails, 0 warnings, 1 skip on CRAN).

### Milestone 7: Categorization Engine Overhaul & Modernized UX Navigation Sync (2026-10-28)
* **Categorization Engine & Precedence Overhaul:**
  * Synchronized classification engine in `k12_he_classification.R` with comprehensive precedence overhaul:
    - Prioritized Clerical (`Secretary`, `Clerk`, `Registrar`) before `Teacher`.
    - Prioritized paraprofessionals (`Teacher Assistant`, `Teaching Assistant`, `Instructional Assistant`) into Paraprofessional rather than inflating Teacher counts.
    - Prioritized Higher Ed administrative/Provost leadership roles (`Faculty Affairs`, `Faculty Development`, `Faculty Director`) before faculty classifications.
    - Fixed misclassifications: `Zoology` now routed to `Science` instead of `Specialist`, `Political Science` and `Social Sciences` routed to `Social Science` instead of `Science`, and `Health Science`/`CNA` routed to CTE/Health instead of general Science.
    - Expanded subject definitions: `Elementary Education` (`K-[1-6]`), `English Language Arts` (`Intervention Teacher`), `Language Education` (`Culture Teacher`), `Substitute Teaching` (`Guest Teacher`), `Health Science` (`CNA`, `Certified Nursing Assistant`), and Higher Ed faculty fields (`leadership fellows`, `financial planning`, `family financial`, `iv&v`, `verification & validation`).
  * Rebuilt historical and current datasets from durable raw archives (`Archivek12_Data/` and `Archived_HE_Data/`):
    - **Wyoming Higher Ed:** Uncategorized postings dropped from 3,522 (18.6%) down to **2,576 (13.6%)** (86.4% categorized).
    - **Wyoming K-12:** Uncategorized dropped from 1,068 (8.1%) down to **518 (3.9%)** (96.1% categorized).
    - Recovered and accurately categorized **1,496 postings** in Wyoming previously lost in generic or misclassified buckets.
* **Shiny Dashboard UI/UX Overhaul:**
  * **Simplified Information Architecture:** Streamlined sidebar navigation to eliminate ambiguous labels ("Profiles & Compare") in favor of clear, intuitive domain entities: `Home`, `Map`, `All Postings`, `Districts` / `Colleges & Universities`, `New Postings`, `Current Trends`, `Longitudinal Trends`, `Data`, `Report Mistake`.
  * **1-Click Quick Filter Toolbar:** Added an instant filter button bar (`radioGroupButtons`: `[ 📋 All Active Postings ]` | `[ 🟢 New This Week ]`) directly above the primary DataTables on both K-12 and Higher Ed postings pages.
  * **Elimination of Nested Sub-tabs:** Removed inner `tabBox` views inside the Current Trends pages in favor of clean single-card layouts.
  * **Responsive Table Containment:** Applied `.trends-table-container` CSS bounding table widths to `980px`, adding clean borders, auto margins, styled headers, and fixed-width sparkline columns, eliminating horizontal table sprawling and whitespace overflow.
  * **Dedicated New Postings Tabs:** Implemented dedicated `k12_new` and `he_new` sidebar views.
* **Test Suite Verification & Parity:**
  * Full test suite passing with 0 failures and 0 warnings.
  * Connect Cloud manifest regenerated via `rsconnect::writeManifest(appDir = "Wy_Ed_Jobs")`.

---

## 4. Key Architectural Contracts & Invariants

1. **Pipeline / Dashboard Decoupling:**
   * `Wy_ED_Jobs.Rmd` is the sole pipeline entry point; it scrapes, munges, and saves derived CSVs to `Wy_Ed_Jobs/`.
   * `Wy_Ed_Jobs/app.R` is the Shiny dashboard reading committed CSVs. It **never** scrapes live pages.
2. **Posting Identity Contract (`Posting_ID`):**
   * Assigned once prior to deduplication, longitudinal accumulation, or spell calculations.
   * Uses real per-posting URLs when available; falls back to `title + location + date_posted` with an occurrence suffix.
3. **Schema Integrity:**
   * Every CSV consumed by `app.R` must be registered in `REQUIRED_SCHEMAS` inside `schema_check.R` and tested in `test-schema-check.R`.
4. **Posit Connect Cloud Manifest Safety:**
   * Empty lists in R become `{}` in JSON via `jsonlite::toJSON()`, which Connect Cloud rejects. Post-processing forces `metadata` and `users` to literal `null`.

---

## 5. Active & Upcoming Workstreams

- [x] Initial design and release of Vacancy Spells panel.
- [x] Universal `NCES_LEAID` and `IPEDS_UNITID` integration across all data layers.
- [x] Harmonize attribution to Mike Bostick & Mark Perkins.
- [x] Harden `safe_scrape()` against heterogeneous date type collisions.
- [x] Add pipeline dry-run and AST linting tests to CI test suite.
- [x] Create reproducible generator scripts `scripts/generate_job_duration_spells.R` and `scripts/generate_he_job_duration_spells.R`.
- [x] Expand Higher Ed analytics to include vacancy duration metrics (`he_job_duration_spells.csv` and `he_spells` tab).
- [x] Optimize test suite runtime for heuristic scrapers (mock `Sys.sleep()` in `test-eastern-wyoming-scraper.R`, cutting run time from 64s to <1s).
- [x] Harden interactive Vacancy Spells modules against empty filter states and regularize duration distribution bins.
- [x] Enable 1-click drill-down navigation from Homepage top hiring employers tables to filtered jobs tables.
- [x] Add K-12 and Higher Ed weekly vacancy series downloads and codebook definitions.
- [x] Add spell panels to automated data-quality invariant suite.
- [x] Harmonize attribution across all dashboard views.
- [x] Streamline sidebar navigation into consolidated tabBoxes (10 main tabs).
- [x] Implement Head-to-Head District and College Comparator modules.
- [x] Multi-dimensional map filtering (salary tiers, county cluster, posting volume/urgency) with dynamic count badge and auto-zoom.
- [x] 100% data dictionary column coverage and automated codebook invariant test suite.
- [x] Overhaul K-12 and Higher Ed categorization engine: eliminate misclassifications (Zoology, Pol Sci, Health Sci), audit precedence (clerical before teacher, paraprofessional before teacher, provost/admin before faculty), and expand subject coverage recovering 1,496 previously uncategorized jobs.
- [x] Modernize dashboard UX navigation: clear tab titles (`Districts`, `Colleges & Universities`), flat Current Trends layout without nested tabs, 1-click `🟢 New This Week` filter button, and responsive table container styling.
- [x] Comprehensive 8-dimension data quality audit & historical archive reprocessing across MT & WY:
  * Full reprocessing from raw historical archives back to first scrape date (`rebuild_k12_history_from_archive.R` and higher ed rebuilds) propagating classification fixes across all historical time-series datasets (`allsum.csv`, `k12jobanalysis.csv`, `facultydata.csv`, `job_duration_spells.csv`).
  * Repaired text encoding / HTML entity leakage (`&amp;`, `&quot;`, `&#39;`, `&lt;`, `&gt;`, `&nbsp;`) in job titles.
  * Resolved non-instructional role precedence leaks: bare `Clerk` (Attendance, Records, Library Clerk) routed to `Staff` ahead of `Teacher`; `Library/Media Assistant` to `Paraprofessional`.
  * Expanded discipline coverage: Arapaho/Arapahoe language, Drama/Theatre in Art, Choir/Chorus/Vocal in Music, Trade & Technical, Autism/ASD in SPED, Grade 1-7 primary grades.
  * 100% test pass rate across both WY (1,424 tests) and MT (3,051 tests).
