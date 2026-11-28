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
| **Geographic Leaflet Map** | Implemented | Implemented | **Full Parity** | Interactive position/subject keyword search ("special ed", "mathematics"), suggestion chips, dynamic radius scaling, layer controls (Positron, OSM, Esri Topo), and cluster pins. |
| **Data Sources & Codebook Tab** | Implemented | Implemented | **Full Parity** | Direct CSV download buttons and interactive schemas. |
| **Federal NCES LEA IDs** | Embedded (48/48) | Embedded (200/200) | **Full Parity** | 7-digit `NCES_LEAID` in registry, `salarymap2.csv`, and `job_duration_spells.csv`. |
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
  * Synchronized [`DATA_DICTIONARY.md`](file:///Users/mikebostick/repos/Jobs_Dash_repos/Wyoming-Education-Jobs-Dashboard/DATA_DICTIONARY.md) markdown codebook with complete markdown tables and universal identifier definitions (`NCES_LEAID`, `IPEDS_UNITID`).
* **Automated Codebook Invariant Test Harness:**
  * Created [`tests/testthat/test-data-dictionary.R`](file:///Users/mikebostick/repos/Jobs_Dash_repos/Wyoming-Education-Jobs-Dashboard/tests/testthat/test-data-dictionary.R) enforcing:
    - 100% column documentation: every column in every public download CSV must exist in `data_dictionary.csv`.
    - Zero phantom columns: every documented column must exist in the target dataset.
    - Non-empty descriptions and valid data types.
    - Synchronized dataset inventories between Shiny UI download handlers and `data_dictionary.csv`.
* **Data Quality Test Suite Registration:**
  * Added `data_dictionary.csv` to `ALL_OUTPUT_CSVS` in `tests/testthat/test-weekly-data-quality.R`.
  * Verified 1,390 passing tests across the entire test suite (0 fails, 0 warnings, 1 skip on CRAN).

### Milestone 8: Categorization Engine Overhaul & Modernized UX Navigation Sync (2026-10-28)
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
- [x] Streamline dashboard navigation architecture across K-12 and Higher Ed:
  * Promoted **Vacancy Spells** to a dedicated top-level sidebar tab for both K-12 (`k12_spells`) and Higher Education (`he_spells`) featuring 4 KPI ValueBoxes, duration distributions, and searchable spell listings.
  * Unified **Current Trends** and **Longitudinal Trends** into a single cohesive **Trends** tab (`k12_trends`, `he_trends`) using a clean top-level `tabBox` with two panels: Current Snapshot (12-week sparklines and discipline breakdown) and Longitudinal Trends (multi-year timeline slider and interactive Plotly time series).
  * Retired redundant standalone "New Postings" sidebar tab, relying on the 1-click `🟢 New This Week` quick-filter toggle in the main postings tables. Preserved reactive server endpoints (`output$k12_new_table`, `output$he_new_table`) for backwards compatibility.
  * Standardized sidebar navigation into exactly 4 symmetrical items per education tier:
    - K-12 CAREERS: `All Postings`, `Districts`, `Trends`, `Vacancy Spells`
    - HIGHER EDUCATION: `All Postings`, `Colleges & Universities`, `Trends`, `Vacancy Spells`
  * 100% test pass rate across both WY (1,424 tests) and MT (3,051 tests).
- [x] Refine public-facing terminology and sidebar proportions:
  * Replaced technical jargon like "scraped" with clean phrasing ("compiled", "weekly updates") across data provenance and Vacancy Spells modules.
  * Single-word navigation clarity: Renamed tabs to concise, intuitive terms (`Jobs` for postings, `Colleges` for institutions, `Time-to-Fill` for duration metrics, `Feedback` for bug reporting).
  * Narrowed sidebar container: Reduced sidebar width from default 230px to 180px (`width = "180px"`, `titleWidth = "180px"`), eliminating empty void space after tab labels and giving 50px more width to data tables and maps. Streamlined category headers to `K-12`, `HIGHER ED`, and `COMMUNITY`.
- [x] Full Wyoming K-12 and Higher Education Statewide Infrastructure & Platform Drift Audit:
  * **Fremont County School District 24** (Shoshoni, WY): Recovered from silent platform drift (AppliTrack throwing `HTTP 500 Internal Server Error`); migrated registry to RedRoverK12 (org `4335`, slug `fremont24`), restoring 2 active vacancies (`Elementary Special Education Paraprofessional`, `Substitute Teacher`) to direct pipeline.
  * **Comprehensive K-12 Structured Registry Audit (38/38 - 100% Active)**:
    - 21 AppliTrack districts: 100% operational, 313 live vacancies (Big Horn, Carbon, Converse, Fremont, Park, Sheridan, Sweetwater, Teton, Uinta, Washakie).
    - 8 SchoolSpring districts: 100% operational, 220 live vacancies (Crook, Laramie 1 & 2, Natrona, Fremont 25, Albany, Campbell, Lincoln 2).
    - 2 TedK12 districts: 100% operational, 18 live vacancies (Fremont 2, Goshen 1).
    - 7 RedRoverK12 districts: 100% operational, 51 live vacancies (Johnson 1, Hot Springs 1, Fremont 38, Lincoln 1, Sublette 9, Platte 2, Fremont 24).
    - Total structured pipeline: 568 live postings extracted across all 38 districts with 0 errors.
  * **Heuristic District & Charter Audit (13/13 - 100% Active, 78 live postings)**:
    - 10 public districts: Niobrara 1 (5), Park 16 (2), Platte 1 (13), Sheridan 3 (0), Sublette 1 (2), Uinta 4 (4), Uinta 6 (5), Washakie 2 (1), Weston 1 (14), Weston 7 (5).
    - 3 charter schools: Cheyenne Classical (1), Wyoming Classical (21), Prairie View (5).
  * **Higher Education Institutions (9/9 - 100% Active, 489 live postings)**:
    - University of Wyoming (231), LCCC (84), Sheridan College (71), Western Wyoming CC (41), Gillette College (27), Central Wyoming College (13), Eastern Wyoming College (10), Casper College (8), Northwest College (4).
  * **Charter Schools & WSBA (100% Active)**:
    - Laramie Montessori Charter School (Paylocity): 2 live postings.
    - WSBA Statewide Vacancy Portal: 110 live postings.
  * Total suite: 1,424 tests PASS (0 failures, 0 warnings, 1 skip on CRAN).
- [x] Interactive Leaflet Map Position & Keyword Search with Suggestion Chips and Multi-Basemap Controls:
  * **Interactive Keyword / Subject Search**: Added instant full-text query matching (`match_job_query`) supporting compound terms, educational abbreviations ("special ed", "sped", "math", "pe", "cte"), and multi-word token matching across both K-12 and Higher Education postings.
  * **Dynamic Employer Filtering & Marker Scaling**: Map marker locations automatically filter to only employers with active matching openings, dynamically scaling circle marker radius proportional to matching vacancy counts.
  * **Rich Contextual Tooltips & Popups**: Hover tooltips and click popups highlight matching position counts, listing sample matching job titles alongside total vacancy counts and median salaries.
  * **Dynamic Feedback Badging**: Added real-time count badge above the map displaying exact matching openings, matching locations, and active query terms (with red guidance badge when 0 matches found).
  * **Instant Suggestion Chips**: Integrated 1-click filter chips for popular subject areas (`Special Ed`, `Mathematics`, `Elementary`, `Science`, `Music / Art`, `Bus Driver`, and `Clear`).
  * **Multi-Basemap Layer Control**: Added interactive tile layer switcher offering CartoDB Positron (clean default), OpenStreetMap, and Esri World Topo Map.
  * Total suite: 1,468 tests PASS (0 failures, 0 warnings, 1 skip on CRAN).
- [x] Post-review fixes (2026-10-29):
  * **Position classifier regressions from the precedence overhaul** (`classify_k12_position()`, identical in MT and WY): bare `Intern` matched inside "Internal Applicants Only" (teacher and bus-driver postings landed in Support Services); `Technician` was checked ahead of Custodial/Transportation/Food Services (cafeteria, maintenance, HVAC, facility technicians); `Director`/`Driver` ahead of Teacher sent "Band/Choir Director" to Administration and "Drivers Education Teacher" to Transportation. Fixed with a word-bounded `\bIntern\b`, a separate late Technician rule, and an early Teacher rule for ensemble directors and Drivers Ed; regression tests added in `test-k12-classification.R`. K-12 history and `job_duration_spells.csv` rebuilt from archive.

- [x] Categorization & research-download data-quality audit (2026-10-30):
  * **One shared classifier for both states.** The Higher Ed job-type and faculty-category functions had drifted between MT and WY (different rule order, Legal checked before Criminal Justice in WY); they are now identical in both repos, with each state's extra rules folded in.
  * **K-12 position:** OPI Jobs for Teachers publishes its subject-area field as the title ("Elementary Curriculum", "Special Education", "Music"), so those teaching postings landed in Other. Titles that name only a subject or grade now classify as Teacher unless they name an assistant/advisor-type role. Also: `\bPara`/`\bSub` word boundaries, nurses and counseling after Teacher/Staff/Admin, and new keywords for guards, noon duty, grounds, superintendents, stipend sports, and kitchen staff. Other fell from 10.9% to 1.8% of archived K-12 rows; uncategorized teacher subjects are 1.5%.
  * **K-12 subject:** bare "CTE" moved to the last-checked CTE bucket so "CTE – Agricultural/Business/FCS" reach their subjects; "Physical Ed", "Health Enhancement", "Reading", "World Languages", "Industrial Technology" and the "Special Educaiton" typo now match.
  * **HE:** "latin" matched inside "Gal**latin** College" (every Gallatin pool landed in Language) and "ems" inside "Syst**ems**" (Information Systems faculty in Health Sciences); bare "Instructional" counted technologists, designers and campus child-center aides as faculty. HE job-type Other fell from 17.2% to 1.6% (MT) and 5.9% to ~0% (WY); WY uncategorized faculty fell from 13.6% to 3.7%.
  * **Placeholder postings dropped** via shared `is_placeholder_posting()` in the pipeline and rebuild scripts: "Sample/Future Certified/Classified Position", account-creation templates, "Student Teaching Opportunities", "No open positions", a scraped "Job Title" header (EWC). Standing applicant pools are kept. Raw archives are unchanged.
  * **Vacancy spells:** a same-title posting absent for more than 21 days now starts a new spell (WY had 244 merged re-postings with a median "duration" of 382 days); `Weeks_Observed` counts calendar weeks rather than scrape dates.
  * **MT `salarymap2.csv`:** the read-back + registry join emitted `NCES_LEAID.x`/`.y` (a third copy would follow next run); collapsed to one `NCES_LEAID` and fixed at the source.
  * **District name variants:** MT OPI location labels normalized ("BILLINGS" / "Billings, MT" → "Billings"); WY "#21" / "No.1" spellings canonicalized.
  * Regression tests added for every fix; histories and spells rebuilt from archive.
- [x] WY weekly run fix (2026-10-30): the weekly salary chunks now keep `IPEDS_UNITID` and no longer duplicate the CCD
  columns (`.x`/`.y`). Both had been introduced by Oct 27 hand-edits to the committed CSVs that the pipeline didn't
  reproduce. Verified with full local rehearsals of both weekly workflows.
- [ ] Posted pay from the job posting itself (in progress):
  * [x] Increment 1: shared `extract_posted_pay()` (amount/range, unit, source snippet; never converted between units).
    AppliTrack postings carry `Pay_Min`/`Pay_Max`/`Pay_Unit`/`Pay_Text` into `combinedclean.csv`, with a "Posted Pay"
    column in the Jobs table. About 91% of sampled live AppliTrack postings state an amount.
  * [x] Increment 2 (2026-10-30): RedRover boards carry Pay_* from the GraphQL `payTypeId`/`minPay`/`maxPay` fields.
  * [x] Increment 3 (2026-10-30): higher ed. The NEOGOV colleges (LCCC, Casper, Central Wyoming, Gillette) carry Pay_*
    from each listing card's pay line, or its description preview when that line is blank, into `hedata.xlsx` and the
    raw HE archive, with a "Posted Pay" column in the Higher Ed Jobs table. Live 2026-10-30: LCCC 57/84 (NEOGOV prints
    "$0.00" for adjuncts with no stated pay, now read as none), Casper 7/8, Central 8/13, Gillette 21/22.
    `facultydata.csv` keeps its schema (no Pay_*). PeopleAdmin colleges and UW: since added (2026-11-01, 55654d0;
    11-06 run: UW 195/229, Sheridan 60/71, Western 34/42, Eastern 10/10, Northwest 1/4).
  * [x] Pay-coverage monitor (2026-10-31): `check_pay_coverage.R` (non-blocking weekly step, in the monitoring
    self-check) flags a source whose postings still arrive but whose share with stated pay fell to <=20% of its own
    average (needs 2+ archived weeks with pay, avg share >=40%, 3+ postings), into the weekly drift issue. Pure logic
    in `drift_check.R` (`flag_pay_coverage_drop()`), tested.
  * [x] Map pay filter rebuilt on posted pay (2026-10-31): "Pay" bands in each posting's own unit (hourly: under $18 /
    $18-25 / $25+; annual: MT under $50k / $50-60k / $60k+, WY under $60k / $60-70k / $70k+), nothing converted. A posting
    counts by its posted pay (range midpoint), else its district/institution role figure, else the estimate below; day
    rates and stipends only under "All". The band narrows each dot to its matching postings, and "View N matching jobs"
    carries it to the Jobs tab.
  * [x] BLS OEWS fallback (2026-10-31): `bls_oews_scraper.R` (shared) pulls May-2025 regional medians for 17 school roles
    via the BLS API (bls.gov downloads refuse scripts), refreshing `oews_role_wages.csv` only when BLS publishes a new
    year. Each K-12 posting gets `Est_*` from its district's county area (statewide where unknown or suppressed); coaches
    get none. Jobs table: "Typical pay (BLS est.)" with role/area on hover, shown only where no pay is posted.
  * [x] IPEDS staff fallback (2026-10-31): `ipeds_staff_salaries.R` (shared) -- each college's average pay for full-time
    non-faculty staff by IPEDS category; HE staff postings get `Est_*` by title -> category. HE Jobs table: "Typical pay
    (IPEDS est.)".
  * [x] QCEW county context (2026-10-31): `qcew_school_pay.R` (shared) -- average pay of public school employees by
    county (all roles), shown in the district map popup.
  * [x] UW salary book (2026-10-31): IPEDS lumps each college's managers into one average, and UW reports only its top
    111 there ($159K), so UW assistant directors and business managers showed $159K. `uw_salary_book.R` (WY only) parses
    UW's published "Salary Information - Departmental Listing" (FY2026: 3,084 salaried staff, department/title/salary,
    no names); UW staff postings get the median salary of UW staff with the same title, else the same role before the
    first comma, with 3+ holders (Business Manager $60,894 from 40; Assistant Director $60,756 from 44). Unmatched UW
    management titles show nothing rather than $159K. BLS OEWS was checked and rejected for this: postsecondary
    administrators' 25th percentile is $81K (MT) / $108K (WY). HE Jobs column renamed "Typical pay (est.)", source on hover.
  * [x] Hourly-pool, work-study, student and intern postings no longer get an annual IPEDS figure (shared
    `is_salaried_staff_posting()`); e.g. UW Student Media hourly jobs had shown $68,490. "Executive Assistant" is office
    support, not management.
  * [ ] Declined: ACS county earnings (less specific than QCEW for the same question).
  * [x] Pay data-quality safeguards (2026-11-01, both states). Posted amounts out of range for their unit
    (`PAY_PLAUSIBLE_RANGE`) are blanked before they reach the dashboard (`drop_implausible_pay()`); the raw archives
    keep them, and the weekly drift issue lists them. Extractor no longer reads application costs, money paid into a
    benefits package, or loan-assistance lists as pay (real misreads from the 10-31 rehearsal). Reference tables behind
    the estimates (OEWS, QCEW, IPEDS staff pay, the UW salary book) refresh through `write_reference_file()`, which keeps
    the old file when a download is partial, mostly blank or out of range, and logs each refresh to `scrape_log.csv`;
    `check_salary_drift.R` reports failed, rejected, missing or stale refreshes. Schema check and the blocking
    data-quality sweep cover the new files and the Pay_*/Est_* columns.
  * [x] Pay extractor fixes (2026-11-01, both states): a unit run into the next label ("$145/dayBENEFITS",
    "$21.69/hrThe District") is read as day/hour, and an earlier amount's bonus wording no longer vetoes a salary
    after it ("Signing bonus $1,000, $42,000 annual salary").
  * [x] `posting_id` (2026-11-01): fallback IDs are joined with " | " instead of a carriage return, which put line
    breaks inside the field; a stored fallback ID passed back in by the archive rebuild is re-derived from the fields,
    so weekly runs and rebuilds give one posting the same ID (rebuilds had been writing spaces). `k12jobanalysis.csv`
    and `combinedclean.csv` rewritten with the new IDs (no other column changed; weekly distinct-ID counts identical).
  * [x] Repeated rows in `k12jobanalysis.csv` (129) and `facultydata.csv` (170) documented in DATA_DICTIONARY.md and
    kept: older snapshots lost the field that told them apart, so they can be separate openings.
  * [x] Classification audit (2026-11-01, both states; shared classifier). Every archived title since Oct 2025 checked
    against its bucket. K-12: new "Activities/Extracurricular" bucket (FFA/FBLA/DECA/HOSA advisors, drama, the musical,
    speech & debate, robotics, color guard, student council; cheer stays Athletics); every substitute posting is
    Substitute (substitute paras were Paraprofessional); coach/kitchen/bus aides go to Athletics/Food Services/
    Transportation instead of Support Services; "Teacher Aide" is Paraprofessional; bare "Aid" no longer matches inside
    "Paid" and "Para" no longer matches "Paradise Valley"; janitors, LPNs, accountants, district IT staff and
    grade-band-only titles ("Junior High 7-8") leave Other; "None at this time" is a placeholder. HE: faculty
    applicant pools are Adjunct/Part-Time; postdocs and research scientists are Research & Science; custodians are
    Maintenance & Service; UW "Hourly Pooled - <job>" is classified by the job (student/intern jobs are Student
    Positions). Spells `is_support_staff` now includes Transportation and Food Services, as documented. Committed
    combinedclean (position, and Est_* on changed rows) and the teacher/faculty histories, aggregates and spells
    reclassified; raw archives unchanged. Tests: test-classification-misroutes.R (identical in both repos).
  * [x] Real posting dates, step 1 (2026-11-03, both states; c75abaf): AppliTrack postings carry the board's own job
    ID (`parse_applitrack_output()` `job_id`, identical to MT); `url` is the posting's own page
    (`applitrack_posting_url()`) and `posting_id` is `applitrack:<tenant>:<job id>` instead of the title fingerprint.
    Parser fix: fields are read per `<li>`; a one-value "Position Type" used to swallow the next field and shift every
    later one (49 of 318 rows on 10-30 had no posted date, e.g. Teton #1, Carbon #1; earlier archives keep the shifted
    values). New `Close_Date` (combinedclean + raw archive): AppliTrack "Closing Date" as written. The 10-30 week was
    moved onto job IDs and corrected from the live boards (263/318; the rest had left the board). WSBA rows linking to
    AppliTrack category pages keep the fingerprint. Fixture `applitrack_output_wy_teton_single_position_type.bin`.
    Full weekly rehearsal passed. Next: WY's spells have the same trust problems as MT's (not audited; since audited
    2026-11-05 and rebuilt at posting level, and re-checked 2026-11-10, see the Listing Duration item).
  * [x] Real posting dates, rest of step 1 (2026-11-04, ported from MT; 8815499): SchoolSpring reads each
    posting's own record (`add_schoolspring_details()`, before `normalize_id_backed_k12_postings()`): `Close_Date`
    (deadline applicants see; "Posted until filled" NA), `Job_Status` (raw archive only) and posted pay from the board's
    pay fields (WY 11-04: 132 of 214 postings; "Substitute" $150/$14.95/$1,132 and "Please see our Salary Schedule"
    left without pay). PeopleAdmin (Western, Eastern, Sheridan, Northwest): the page's open date replaces the feed's
    `<published>` where filled in (39 of 95 differed on 11-04; Sheridan leaves it blank on 32 of 71), and new HE
    `Close_Date` ("Close Date"/"Closing Date"/Sheridan "Initial Review Date", else "Open Until Filled") in
    `hedata.xlsx` and the raw archive, not `facultydata.csv`. Tests shared with MT (`test-peopleadmin-dates.R`,
    SchoolSpring block in `test-direct-api-scrapers.R`, fixtures `schoolspring_job_*.json`). Full weekly rehearsal
    passed.
  * [x] Real posting dates, step 4 (2026-11-04, both states; 7d46347): `refresh_schoolspring_endings()`
    (`direct_api_scrapers.R`) runs after the raw archive is written: every SchoolSpring job ID listed in the past
    year but not today is looked up (`fetch_schoolspring_details()`), and `schoolspring_endings.csv` (repo root,
    committed by the weekly workflow) keeps one row per ended posting: District, Title, board posted date,
    First_Seen/Last_Seen, `Job_Status`, Status_Since, Last_Checked. Filled/canceled are final, review is rechecked
    weekly, and a lookup still saying "posted" (our scrape missed a live posting) records nothing. First lookup:
    WY 504 postings that left Aug-Oct (294 filled, 119 canceled, 91 review; Fremont 25 also mostly canceled), MT 99 (62 / 17 / 20). Districts use the statuses differently (MT Libby leaves all at review; WY Campbell County 1 closes 79 as
    canceled vs 8 filled), so a pooled filled share is not a calibration constant
    (`claude-notes/2026-11-03_posting-dates-plan.md`, "Step 4 findings"). District names go through `canonicalize_k12_district()` (August archives spell "Campbell County Scholl", "Albany Count"). Tests in
    `test-schoolspring-scraper.R`. Full weekly rehearsal passed.
  * [x] Real posting dates, step 2 (2026-11-04, both states; ddb1ccc): coverage calendar. `coverage_calendar.R` writes
    `coverage_calendar.csv` (repo root, committed by the weekly workflow) after the HE archive: one row per run per
    entity (registry districts/institutions, feeds, off-registry districts that log under their own name, anything
    tracked before) with ok / empty / error / not_logged, row count and error, so a posting that stops appearing
    counts as ended only when its source was healthy. Shared-board colleges take the parent board's row; postings
    that come only via a statewide feed take the feed's row; a run with no log leaves the calendar untouched. WY never uploaded its scrape log as an artifact, so its
    calendar starts with the 2026-11-06 run.
    Bug fixed on the way: `log_scrape_result()` backslash-escaped quotes in error messages, which `read.csv` can't
    parse, so rows after such a message were lost (MT 11-03: all 23 HE sources), including in the drift checks; it
    now doubles quotes and `read_scrape_log()` repairs older logs. Tests `test-coverage-calendar.R`. Full weekly
    rehearsal passed (`claude-notes/2026-11-03_posting-dates-plan.md`, "Step 2 findings").
  * [x] Classification safeguards, items 7, 8, 10 (2026-11-04, both states; WY 91ca1ad): blocking checks in
    `test-weekly-data-quality.R`: every committed position / Category / Broad_Category (combinedclean,
    k12jobanalysis) and Job_Type / Category (facultydata) equals what today's classifier gives its title (so a
    classifier change must ship with reclassified data; 0 differences in WY or MT today); k12jobanalysis holds only
    Teacher rows; no placeholder title in combinedclean, k12jobanalysis, facultydata or hedata.xlsx; spell dummies
    (`is_support_staff`, `is_admin`, `is_faculty`, `is_adjunct`) agree with the position they encode.
  * [x] Classification safeguards, items 12 and 13 (2026-11-04, both states; f78d75c): rebuild parity and a
    reclassify script. `build_k12_combinedclean()` / `build_k12_teacher_rows()` (`history_accumulator.R`) are shared
    by `Wy_ED_Jobs.Rmd` and the rebuild, which therefore carries Close_Date and Est_*; the rebuild reproduces all
    nine committed K-12/HE files exactly (row order aside; facultydata's 850 apparent differences were `\r\n` in
    titles, which `read.csv()` reads as `\n`). `.github/scripts/check_rebuild_parity.R` checks it weekly
    (non-blocking). `scripts/reclassify_committed_data.R` (dry run; `--apply`): guard that the HEAD classifier
    reproduces the committed data, report of every move, files written in committed order and formats, spells
    refreshed. Scratch test with a planted rule change: 148 history rows left, diff only those rows and counts.
  * [x] Classification safeguards, items 5, 6 and 3 (2026-11-05, both states; WY a1f3e06): title monitoring and a golden
    labeled set. `.github/scripts/check_title_quality.R` (weekly, non-blocking, into the drift issue; functions in
    `drift_check.R`): (5) title-shape lint of this run's postings per source -- level and rank with no role, schedule
    or detail sentences, field labels, markup, file names, blank or "Other" titles, over 200 characters, and pay
    stated in the title while Posted Pay is blank (`extract_posted_pay()` on the title; hiring incentives ignored);
    (6) a source whose Other share jumped against its last 8 archived weeks (today's classifier on both sides).
    Rules and thresholds measured on every archived week in both states: the lint hits the 2026-11-01 audit's
    misreads and no real title (long real titles reach ~190 characters); the Other-share replay flags 2 MT
    (Florence-Carlton schedule lines) and 2 WY (Albany 2024-09 section headings) source-weeks, all real. First
    run: MT 9 postings at 5 sources (Huntley Project, Livingston, OPI "Other", Turner, Ulm), WY 1 (Fremont #21).
    (3) `tests/testthat/fixtures/classification_golden_set.csv` (identical in both repos): 528 real titles (285
    K-12, 243 HE, both states, sampled across every bucket) with checked buckets, 50 judgment calls left out;
    27 `known_miss` rows the classifier still gets wrong (e.g. Administrative Assistant -> Administration, GEAR UP
    success coaches -> Coaching or Athletics, Laborer -> Support Services). `test-classification-golden-set.R`
    fails on any other disagreement and when a known miss starts agreeing (clear its flag).
  * [x] Time-to-Fill tabs paused and spells trust audit (2026-11-05; 63e7f52): the tabs are now "Listing
    Duration" with MT's paused note, "No longer listed" instead of "Closed / Filled", duration KPIs and charts
    removed (server outputs kept). Audit (`claude-notes/2026-11-05_wy-spells-trust-audit.md`): WY's spells are
    much sounder than MT's -- 3% of closed spells end in a known artifact (MT 68%), 6% left-censored (MT 61%),
    posted dates on 70% of rows, first seen a median 3 days after posting; the K-12 median stays 28 days under every
    cleaning filter, and closed teacher postings ran a median 32 days from posted date to last sighting. Still not
    time-to-fill. Open problems: title identity (133 spells merge same-title postings), frozen boards (17 runs at
    12 districts; Fremont #38 the same postings for 57 weeks, also inflating weekly counts), coverage gaps only
    visible as whole-district absences, HE pools (237 of 719 spells, median 196 days).
  * [x] `Pay_Min`/`Pay_Max`/`Pay_Unit`/`Pay_Text` required in `hedata.xlsx` (`REQUIRED_SCHEMAS_XLSX`, 2026-11-09):
    the weekly runs already write them; `app.R` pads a missing pay column with NA, so before this a dropped column
    would have shown no posted pay without failing the schema step. `Est_Source` too (the HE table's
    "Typical pay (est.)" reads it).

  * [x] Posting-level spells (2026-11-05/06; f5956f0, data be25eab): MT's design (board-host source, per-posting IDs
    keyed by platform and number, posted-date starts, healthy-source endings, Kaplan-Meier with delayed entry), plus
    frozen-board, pool, moved-board and partial-run checks (UW's 208 -> 25 -> 200 rows in 2026-08 had read as 195
    endings). Archives 2024-08 to 2026-10: K-12 median 25.5 days listed (24.5-26.5), teachers 23.5; HE 59.5, 47.5 without
    UW. `scripts/build_posting_spells.R` runs weekly (non-blocking) and its tables are committed. Weekly frozen-board
    check in the drift report (`check_frozen_boards.R`; none frozen now, 8 stretches in the history). Notes:
    `claude-notes/2026-11-05_wy-posting-spells-rebuild.md`.
  * [x] Confirmed closings from each posting's page (2026-11-06; f5956f0): `posting_status.R` (shared with MT) checks
    the pages of postings that dropped off their board (AppliTrack, TalentEd, Red Rover, NEOGOV, Oracle) and records
    `posting_status.csv`; spells use it. Rehearsal 11-06: 46 dropped postings, 42 confirmed closed, 1 still open (a
    scraper miss), 3 unknown.
  * [x] WSBA cleanup (2026-11-05/06; f5956f0): a WSBA row linking a job ID the district's board lists is a duplicate
    (22 of 63 kept rows on 11-05); kept rows whose posting its platform says is closed are dropped (20 of 24 on 11-06,
    15 of them teacher postings; Sweetwater's April postings among them). Notes:
    `claude-notes/2026-11-05_wsba-duplicates-and-stale.md`.
  * [x] Fremont #25 and Sheridan #3 (2026-11-07; f5956f0): Fremont #25 moved to Red Rover (org 4029; 32 postings with
    posted pay instead of 4 via WSBA). Sheridan #3's page lists bare titles after its form links; the Apptegy parser
    reads that shape (format 5, fixture added). Both had been "empty" in the first coverage calendar.
  * [x] TalentEd per-posting links (2026-11-06; f5956f0): rows keep `ViewJob.aspx?JobID=<n>` (as MT's do).
  * [x] Title-shape fixes and Cabon (2026-11-05; f5956f0, data be25eab): Fremont #21's "- Open Until Filled" cut at
    ingestion (shared `split_title_detail()`); "Cabon County School District 2" -> Carbon #2, in the WSBA parser too, and
    the committed rows corrected.
  * [x] Drift-issue WSBA wording, weekly-totals downloads, golden-set fixes (2026-11-06/07; f5956f0, data be25eab):
    as in MT; 2 combinedclean rows Administration -> Staff.
  * [x] Six more golden-set misroutes (2026-11-08; 8436dbc): as in MT (most of the 17 moved titles are WY's, e.g.
    "Office and Records Assistant" -> Staff); committed data unchanged.
  * [x] Classification safeguards 9 and 11 (2026-11-08; f357ca5): as in MT. 1 combinedclean row (Temporary Business
    Office Support Clerk) Support Services -> Staff; posting spells refreshed, which also carry the morning's 17
    moved archive titles (spells Other 85 -> 71, Staff 283 -> 297).
  * [x] WSBA/district-page dedup key (2026-11-08; e2826cb): `dedup_title_key()` drops dates, file names, "Job
    Description", school years and expands JH/HS/MS/Asst/SPED before the exact match. 7 more duplicate pairs in the
    last 30 archives, none distinct merged (subset matching measured and rejected); live: Weston #1 16 -> 15, Park #16
    4 -> 3. Sheridan #3's double count was mostly the 11-07 parser fix; 1 ambiguous row left.

  * [x] Eleven HE golden-set known misses (2026-11-09; 68a86ad): laborers, stationary engineer, lab/husbandry/
    paleontology, "(Student)" titles, counselor/financial assistance, classroom support, night watch, enterprise
    architect. Archive diff: 21 HE titles move, all intended; golden set 548 of 551; HE posting spells refreshed.
    Review tools added 11-08 (archive diff, spells invariant, guard rows; toolkit footgun 16, `sibling_sync.R`).

  * [x] Sheridan #3 both-teams posting; "Coord" -> Administration (2026-11-09; f83f897): a district title naming no
    gender gives way to WSBA's Boys and Girls rows (Mike: two positions); live misc scrape 188 -> 187.

  * [x] "Posted / listed" first-seen fallback (2026-11-09; c57a8a9): 74 of 725 K-12 postings had no date; they now show "First seen <date>" or
    "On the board since at least <date>" (already up when we first scraped that board), from the posting spells
    (`posting_first_seen.csv` in the app folder, committed weekly). Mike: first-seen dates will match posted dates
    more closely the longer the dashboards run. Checked in the rendered app.
  * [x] Reposts (2026-11-09; not built, measured): a listing that ends and reappears next week under a new ID with
    the same title looks like an ending plus a new posting (MT 101 / WY 358 strict pairs). Not linked: of the 23 WY
    SchoolSpring pairs whose old record has a final status, 8 were "filled", i.e. a new vacancy, not the same job.
    Built instead (Mike, option 1): those endings are "outcome unknown" (censored) in the duration estimates
    (7066848): K-12 median 25.5 -> 26.5 days, college 59.5 unchanged. A platform-reported "filled" keeps its ending.

  * [x] Shared role-hint classifier support (2026-11-09; eec6601): same code as MT; WY passes no hint, no WY change.

  * [x] College data integrity (2026-11-09; 2439826): 114 of 470 college postings (LCCC, Gillette, Central Wyoming,
    Casper) had relative posted dates ("Posted 3 weeks ago") shown as written; the app now shows "About <date>" or
    "Before <date>". Also measured, no change needed: standing adjunct and student postings (Western since 2018) are
    open by the can-apply standard, marked "Listed since", excluded from durations; titles that name only past years: 0.
  * [x] Copilot Internet access (repo Settings, Mike, 2026-11-09): uwyo.edu. The setting now matches
    `.github/copilot-allowlist.txt`.
  * [x] Last golden-set known misses (2026-11-09): `classify_k12_position()` reads "_" as a space (an uploaded
    file's name: "Dish_Server_Cashier 26 - Copy", Livingston) and Food Services takes word-bounded "Dish" and
    "Cashier" (not bare "Server", which can be IT). Archive diff over both states (7,825 K-12 titles): only those 2
    titles move, Other -> Food Services; committed data unchanged, MT posting spells refreshed (Food Services 49 -> 50
    postings). Golden set 551 of 551.
  * [x] Fremont County School District 38 child poverty (2026-11-09): SAIPE files Arapahoe as an *elementary*
    district in the Census school-district map, so the unified-only request missed it (the 08-06 note called it
    absent from SAIPE). `fetch_census_saipe_child_poverty()` now also asks for the elementary geography (2024:
    16.8%; a 204 with no body adds no rows). Live: 48 of 48 districts have a rate; the 5 charter rows are next.
  * [x] Free/reduced lunch share and every posting on the map (2026-11-09): `Free_Reduced_Lunch_Share` (+
    `FRL_Year`, `FRL_Schools_Reporting`) from CCD's school directory beside SAIPE child poverty, in the District
    Summary, detail card and popup (each entity's newest reporting year; blank under 80% of students reporting;
    >= 99.5% labeled "likely free meals for all"). Rehearsal: 50 of 57 map rows (the 3 state charters report no
    counts). The 5 charters get staffing from CCD school records and their surrounding district's SAIPE rate
    (`Child_Poverty_Basis`, Census geocoder). New map rows for WSBA's non-district employers: Northeast Wyoming
    BOCES, STRIDE Learning Center, Sweetwater County Child Developmental Center (street-level location), Wyoming
    Boys School; "Laramie Montesorri School" (Paylocity) -> Laramie Montessori Charter School
    (`canonicalize_k12_district()`, committed data rewritten; rebuild parity holds). Snowy Range and Laramie
    Montessori had Laramie County SD 1's NCES id (now blank: schools inside Albany SD 1). Rehearsal
    (`claude-notes/2026-11-09_rehearsal-wy-frl-employers.log`) found 2 failures only next week's data shows (0
    enrollment -> students-per-teacher 0; data dictionary), both fixed and the full suite re-run on that output:
    497 pass.
  * [x] Converse County SD 1 and SD 2 map dots swapped back (2026-11-09): since `fb48a72` each carried the other's
    coordinates (SD 2, Glenrock, sat at Douglas; SD 1 at Glenrock), ~40 km apart; ids and links were right. Found by
    the toolkit's new `tools/reference_audit.R` (map dot vs the district's CCD schools).
  * [x] Review fixes (2026-11-10): a CCD outage now logs an error and keeps last run's lunch values (shared
    `fetch_ccd_frl_share()`); the charters' and centers' surrounding-district rate uses the shared, tested
    `surrounding_district_poverty()` (a split town averaged; a geocoder failure keeps last run's value and is logged);
    the lunch-share and SAIPE joins have `relationship = "many-to-one"`; the District Summary's numeric columns sort as
    numbers (all had sorted as text, server-side); one wording for the free-meals note; golden-set guard row for the
    Cashier rule. Rehearsal (`claude-notes/2026-11-09_rehearsal-wy-review-fixes.log`): all steps passed; app tests and
    boot smoke pass on its output; full suite 499.
  * [x] Two spell artifacts from the 11-10 audit (2026-11-10, d0de23d; MT 6f52b4a): `fix_title_encoding()` decodes every
    numeric HTML entity (`decode_numeric_entities()`; it missed the hex `&#x27;`, so Albany's "Girls&#x27;" broke
    identity and Natrona's "Boy&#x27;s" showed on the dashboard), and `relisted_next_run()` ignores punctuation
    ("Paraeducator- SPED" relisted as "Paraeducator - SPED"). Spells rebuilt: K-12 endings 7,680 -> 7,631 (48 more
    relistings censored), medians unchanged (K-12 26.5, HE 59.5; Part-Time Teacher 17.5 -> 24.5 on 47 endings);
    reclassify: 1 combinedclean title changes. Classifier archive diff (both states): no bucket moves. Rehearsal
    (`claude-notes/2026-11-10_rehearsal-wy-entity-relist.log`): all steps passed, 81 sources ok, post-run suite 2,218.
  * [x] Pay units and advertised windows (2026-11-10, df9bc07; MT 775ff7b; `claude-notes/2026-11-10_data-integrity-sweep.md`):
    `extract_posted_pay()` reads a bare $7.25-$60 beside a pay word as hourly ("starting wage of $16.04", "Step 1:
    $13.37"; all 633 stated-unit amounts in that range were hourly; over every archived pay text exactly 12 change, all
    no unit -> hour). `parse_neogov_card_pay()`: when the pay field's unit is rejected, the card's description is used
    (Gillette's "Adjunct - $900.00 Hourly" is "$900 per credit hour"; fixture `neogov_gillettecollege_p1_2026-11-10.html`).
    Spells: a posting listed more than a week past its stated date gets no advertised window (Sheridan's 3 past
    "Initial Review Date"s, 6 stale K-12 dates, one from 2023). Rehearsal
    (`claude-notes/2026-11-10_rehearsal-wy-pay-windows.log`): all steps passed, 81 sources ok, no posted pay left
    without a unit, post-run suite 2,230.
  * [x] Run expectations and the scheduled-run guard (2026-11-10, eade3b4; MT d1f3879; workflow plan
    `claude-notes/2026-11-10_workflow-review-and-plans.md` items 2.1-2.2, approved by Mike): `run_expectations.csv`
    (20 rows, from the 11-13 watch-list) is checked by the new non-blocking step `check_run_expectations.R`
    (`run_expectations.R`, same file in both repos): summary on the run page, failures in the drift issue. On the
    committed 11-06 data, as of 11-13: 7 pass, 8 fail, 5 error, all of the failures being things the 11-09/10 pushes
    should change. A `guard` job skips a scheduled run when main already has that day's data commit; checked against
    history (skips 11-06, runs 11-13). WY gains the concurrency group. Live run of the step, suite 2,252 (0 failed).
    Review fixes before push (jobs-dashboard reviewer): the committed-file test no longer requires a row's file to
    exist (WY's posting_status.csv rows would have stopped the 11-13 pre-run suite); the guard fetches main's live tip
    (a queued run's checkout is main as of its creation: MT 11-10 started at 6f52b4a, 9 s after c2dec92 landed);
    .xlsx columns are typed like .csv; rows that passed on zero matched rows now count what must be there (21 rows).
    Suite 2,258 (0 failed).

  * [x] Standing substitute lists in the drift check (2026-11-10; same change in MT; MT issue #13, Lone Rock): an
    LLM-read list of substitute pools no longer makes a source likely_broken unless the source's own titles over its
    last 8 archived runs include a substitute posting (49 of 59 direct sources here do). `drop_standing_pool_titles()`,
    `recent_source_titles()` (drift_check.R); `corroborate_drift.R` passes the history. Suite 2,270 (0 failed).
  * [x] apt mirror fallback in CI (2026-11-11; same change in MT and in edjobs' package CI): from ~15:20 UTC 11-11
    hosted runners could not resolve *.ubuntu.com (probe on ubuntu-22.04/24.04/26.04; Microsoft and CRAN hosts
    resolved), so every `apt-get update` hung until the job timed out. New `.github/actions/apt-mirror-fallback`, run
    before R setup in `setup-r-env` (PR checks, Copilot, autofix) and in `weekly-scrape.yml`: apt timeouts always,
    and `mirrors.edge.kernel.org` when azure.archive.ubuntu.com does not resolve (probe: apt-get update 5.6 s).
  * [x] Claude as the auto-fix fallback (2026-11-11; same change in MT): both states assign new auto-fix issues to
    Copilot (`AUTOFIX_ENGINE=copilot`; `COPILOT_TOKEN` is one fine-grained PAT for both repos, expires 2027-02-09).
    An issue still flagged at a later weekly run, at least 5 days old, with no open Copilot PR carrying changes and no
    merged fix, goes to `claude-autofix.yml` once (`autofix_escalation_decision()`, `autofix_linked_prs()` in
    drift_check.R; marker comment records the hand-over). Only when a Claude credential is set
    (`AUTOFIX_CLAUDE_FALLBACK` in weekly-scrape.yml). `claude-autofix.yml` has `allowed_bots: "github-actions"`
    (every earlier run failed "Workflow initiated by non-human actor"). Checked with a fake `gh` (hand-over, no
    credential, already handed over, too new, PR awaiting review, unreadable comments). Suites (NOT_CRAN=true): MT 3,932,
    WY 2,047, 0 failed.
    First real Claude run (WY #7, run 43079089307, 2026-11-11): Claude signed in and finished (11 turns, $0.35), but
    the guard step's `git add -A -- . ':!.autofix'` exits 1 because `.autofix` is gitignored, so no run could ever
    reach its PR/report step. Now `git add -A` then `git reset -- .autofix`.
    Merged 11-11 (PR #12 -> bb94853). Re-test from main (WY run 43086225793): ran end to end, the guard passed and
    Claude posted a "needs a human" report on WY #7. But every Bash call failed ("Sandbox dependencies not available:
    socat not installed"), so the workflow now apt-installs `socat` and `bubblewrap` before Claude runs.
  * [x] Phase 4 close-out review and its fixes (2026-11-13; `claude-notes/2026-11-13_phase4-full-review.md`, outcome
    at its end). `/full-review` of edjobs v0.5.0..v0.11.0 and both states' phase 4: nothing blocking. edjobs 0.12.0
    (PR bostickmike/edjobs#10, branch `phase4-review-fixes`; 1,386 tests, check clean): two latent spells/history bugs,
    ISO-only date parsing, page caps, JSON-LD dates in Mountain time, per-page posting-status log lines, tests for six
    untested exports. Drift baselines (Mike): zero weeks count between a source's first and last weeks with rows;
    trailing zero weeks and calendar-failed weeks (`failed_source_weeks()`) are left out (replayed since 09-01: WY 9
    flags either way, MT 20 -> 19). Run logging in both states: every message/warning to the run log, render
    interrupted at 40 min with R's call stack (`.github/scripts/render_with_stack.R`), partial-outputs artifact on
    failure. EDJOBS_VERSION 0.12.0. Decided by Mike: keep the TedK12 board-URL rule (0 rows affected since 08-11).
    WY: `k12_posting_source_label()` warns and labels instead of stopping; spells source (Mike, measured): rows
    archived as read from WSBA are the WSBA feed (all 47 on 11-13 linked district sites/files, so none had been a feed
    row), direct rows keep host + tenant. Rebuilt spells: endings in durations 7,731 and median 28.5 days unchanged,
    29 spells fixed, ~18 WSBA postings split once at 11-06/11-13 (no bridge, Mike). Suite 1,358 passed; `check_drift.R`
    run live on 11-13's data. Not yet rehearsed on 0.12.0. To land: edjobs #10 merged and tagged, rehearse, PR.
  * [x] Upkeep workflow: keepalive and token expiry (2026-11-13; same change in MT; edjobs 0.12.1, bostickmike/edjobs#11): new
    `.github/workflows/upkeep.yml` (Wednesdays, a day with no weekly run now or on the planned twice-weekly days) calls
    edjobs' reusable `upkeep.yml`. It re-enables every active workflow through the API, so GitHub's 60-day inactivity
    rule can't silently stop the weekly schedule (a disabled schedule sends no failure email), and opens one issue per
    secret 30 days before its date in the new `.github/token-expiry.csv` (`COPILOT_TOKEN` 2027-02-09, read from
    GitHub itself on each run; `CLAUDE_CODE_OAUTH_TOKEN` 2027-11-11, approximate: set 11-11, about a year).
    Self-sustaining checks 1 and 2 of `claude-notes/2026-11-12_twice-weekly-and-daily-presence-scope.md`; check 5
    waits for the daily presence check. Tested from this branch on a temporary push trigger: dry run with a 400-day
    window, then a real run (all workflows still `active`, `dynamic/` Copilot workflows skipped).
  * [x] Daily presence check, phase 0 (2026-11-13; same change in MT; edjobs 0.13.0): new
    `.github/workflows/presence.yml` (daily, 13:17 UTC) calls edjobs' reusable `presence.yml`, which reads each
    AppliTrack, SchoolSpring, TedK12 and Red Rover board once (all 38 districts; list pages only, each district's
    own `resolve_scraper_call()`)
    and commits `presence_checks.csv` (one row per board per day) and `presence_sightings.csv` (one row per unbroken
    stretch of sightings, keyed by `k12_link_posting_id()`) to the `presence` branch, never main.
    `k12_link_posting_id()` moved to edjobs (deleted here). First live run from the Mac (11-13): 30 boards, all
    answered, 528 postings, all keyed, 43 s; 523 of the 530 keys on these boards in that morning's weekly archive
    were seen. Red Rover's 8 boards, added the same day (Mike: "can't you do MT red rover like WY and add them
    both?"; it is a plain API here, not Chrome): all answered, 78 postings, all keyed, about 1 s. OPI/WSBA
    fingerprints measured for a later step (`claude-notes/2026-11-13_presence-redrover-opi-wsba.md`).
    Phase 0 (shadow, 2 weeks): nothing reads the files yet. Measured at the end, in a dated claude-notes audit:
    agreement with the weekly run on its run days, flapping (missing one day, back the next), errors per board,
    runtime and cron lateness. Then phase 1: the spells read the sightings for day-precision endings.
  * [x] Red Rover fetcher moved to edjobs (2026-11-13; edjobs 0.14.0, same change in MT): `fetch_redrover_postings()`,
    `parse_redrover_json()`, `redrover_org_slug()` and the pay helpers deleted here; MT now reads its Red Rover boards
    through the same API. The shared parser drops standing application forms ("Classified/Certified/Volunteer
    Application"), as MT's did; no WY archive has ever carried one, so WY's output is unchanged.
  * [x] WSBA in the daily presence check (2026-11-13; edjobs 0.15.0; Mike: "look a bit harder at OPI and WSBA"):
    `presence_feeds.R` defines WSBA as a statewide feed, keyed by `edjobs::wsba_vacancy_key()` (district, title,
    WSBA's posted date; renamed from the plan's `wsba_posting_key()`, which WY already has), with the weekly run's own
    `fetch_wsba_vacancies()`. Workflow pins v0.15.0 and sources `state_config.R direct_api_scrapers.R
    k12_he_classification.R misc_district_scrapers.R presence_feeds.R`. Tested on GitHub from a throwaway branch (run
    43538209249): 39 boards, all ok; WSBA 95 vacancies, all keyed. Not pipeline code: suite only.
  * [x] Drift check: the LLM reading counts only titles the scraper missed (2026-11-13; edjobs 0.16.0, same change in
    MT; Mike: "I do like the change"). `corroborate_drift.R` passes this run's titles for each flagged source to
    `combine_verdict_with_llm(current_titles =)`. WY's Sublette 1 had been filed as likely_broken on 11-11 and 11-13
    because the LLM read "Substitutes", the one item the scraper returned (WY issue 7, closed 11-13 as genuinely
    quiet). Replayed on all 8 past flags with an LLM reading: the 6 MT ones unchanged (scraper returned 0), the 2
    Sublette ones no longer filed.
  * [x] Auto-fix only from main; Claude when Copilot refuses (2026-11-13; same change in MT; Mike: "limit auto fix to
    main", "if copilot is refused then claude kicks in"). The weekly workflow's auto-fix filing step runs only on
    main (branch test dispatches had been handing issues to Copilot). A new issue Copilot can't be assigned, or
    opens no PR for within 5 minutes, is unassigned and dispatched to `claude-autofix.yml` at once. MT's ruleset no
    longer requests Copilot reviews on every push (15 "insufficient remaining quota" reviews on MT PRs since 11-12).
  * [x] edjobs 0.17.0 (2026-11-14; pin bump only): the package adds the CyberSchool family routine
    (`fetch_cyberschool_postings()`), the first CMS-family routine; MT's Highwood, Power and Vaughn moved to it. No
    WY district runs on CyberSchool, and nothing WY calls changes. Suite on 0.17.0: 1,374 passed, 0 failed
    (`claude-notes/2026-11-14_wy-suite-edjobs-0.17.0.log`). Notes: `claude-notes/2026-11-14_cyberschool-family/README.md`.
  * [x] Listing Duration tabs: the yellow "Time-to-fill estimates are paused" banner replaced by one footnote at
    the bottom of each tab (K-12 and HE), no "we"; the "How days listed is counted" popover reworded the same way
    (2026-11-14, Mike: "either have it or not"; chose: keep the current table, footnote). KPI boxes and charts stay
    out. App tests passed (both states); screenshots checked: MT K-12 tab, WY higher-ed tab.
  * [x] edjobs 0.18.0 (2026-11-14; waits on edjobs PR 17): the package adds MT's Apptegy family routine, whose
    exported `fetch/parse_apptegy_postings()` share names with WY's own Apptegy parser (and its next release,
    `fetch/parse_googlesites_postings()`). WY's are renamed `fetch/parse_wy_apptegy_postings()` and
    `fetch/parse_wy_googlesites_postings()`: no output change, and the auto-fix no longer mistakes them for edjobs
    code. Rehearsal passed every step (`claude-notes/2026-11-14_rehearsal-wy-edjobs-0.18.0.log`; suites 1,374 /
    1,373, 0 failed). Moving WY's three Apptegy districts onto the family routine is a separate decision for Mike
    (measured: identical on Niobrara 1 and Platte 2, Weston 7 gains two postings; `claude-notes/2026-11-14_apptegy-family/README.md`).
  * [x] WY's Apptegy and Edlio districts on the edjobs family routines (2026-11-14; edjobs 0.24.0, waits on the MT
    stack; Mike: "continue working through all of the scraper families"). Niobrara 1, Sheridan 3, Weston 7 ->
    `fetch_apptegy_postings()`; Washakie 2, Weston 1 -> `fetch_edlio_postings()` with registry list rules. WY's
    Apptegy parser (KNOWN INCOMPLETE) deleted. Uinta 4 (tab widgets, platform `edlio_tabs`) and Uinta 6 (titles in
    sentences) keep WY's parsers. Weston 7 gains 2 real postings and its substitute lines; the others match their
    old output (cleaner titles at Weston 1). Suite 1,344 passed, 0 failed; live run of the step ok for every source.
    Notes: `claude-notes/2026-11-14_wy-families/README.md`.
  * [x] Full rehearsal of `wy-families` on edjobs 0.24.0 (2026-11-14): every step passed, rebuild parity 9/9, post-run
    suite 1,367 passed, 0 failed (`claude-notes/2026-11-14_rehearsal-wy-families-0.24.0.log`). It showed Weston 7 at 12
    own-page rows (5 on 11-13): the 2 new postings, plus the page's "Subs Needed" block read as 5 more lines (its
    heading and the same substitute pool again in prose). Fixed: misc registry column `list_skip` (Apptegy's
    `skip_section`), set for Weston 7; the family test now expects the block skipped, and the fixture's posting below
    it still reads. Live run of the three Apptegy districts: Niobrara 1 5, Sheridan 3 2 (both also on WSBA, kept
    once), Weston 7 7. Suite 1,347 passed, 0 failed. Left for Mike: Weston 7's "School Maintenance Technician" says
    applications close 2026-10-29, so a candidate can't apply; the family has no deadline check (the old parser missed
    the posting outright).
  * [x] Package phase 5, slice 1: IPEDS faculty salaries, enrollment, Pell share and ACS county context from edjobs
    0.25.0 (2026-11-15; branch `phase5-ipeds-acs`, 43bc6d9; edjobs branch `phase5-ipeds-acs`, 74b9c6f + c4695a4, not
    tagged). `ipeds_salary_scraper.R`, `ipeds_enrollment_scraper.R`, `fsa_pell_scraper.R`, `census_acs_scraper.R`, their
    tests and fixtures deleted (tests moved to the package); the map is in `ipeds_unitids.R` (with `Salary_Note`; the Sheridan/Gillette split watch stays there, still joint); FIPS from
    `state_config()`. Package output identical to the old functions on every fixture; live fetch identical to the
    committed files. Full rehearsal on 0.25.0: every step passed; federal steps ok (IPEDS salaries 9, trend 27, enrollment 9, trend 9, Pell 9, ACS 23 + 23); `salarymap.csv` (9 rows) and
    `salarymap2.csv` (57 rows) federal columns identical to the committed files; rebuild parity 9/9 (combinedclean
    725); post-run suite 1,296 passed, 0 failed (`claude-notes/2026-11-15_rehearsal-wy-phase5-0.25.0.log`). Notes:
    `claude-notes/2026-11-15_phase5-federal/README.md`.
  * [x] Package phase 5, slice 2: CCD staffing and SAIPE child poverty from edjobs 0.26.0, by NCES id (2026-11-15;
    branch `phase5-ccd-saipe`, 33a9615, on slice 1; edjobs branch `phase5-ccd-saipe`). `ccd_staff_scraper.R`,
    `census_saipe_scraper.R`, their tests and fixtures deleted (the CCD and SAIPE name rewrites go); ids from
    `salarymap2.csv`'s NCES_LEAID; the surrounding-district stand-ins read SAIPE by id with its counts. Rehearsal on
    0.26.0: every step passed; `salarymap2.csv` 57 rows, every column identical except Northeast Wyoming BOCES gaining a
    SAIPE_Year with no rate, fixed in edjobs (d8b258b: no year without a rate; live check after the fix: committed
    values back); parity 9/9 (combinedclean 725); post-run suite 1,238 passed, 0 failed
    (`claude-notes/2026-11-15_rehearsal-wy-phase5-0.26.0.log`).
  * [x] Sources footer and required notices on every page (2026-11-15; branch `phase5-ccd-saipe`, after slice 2).
    Mike 11-15: add the Census API notice and Urban's ODC-By citation, and check every source. Audit of every
    outside source's terms: `claude-notes/2026-11-15_citations-audit.md`. `page_navbar(footer = data_sources_footer)`
    lists the sources and carries the Census Data API notice and the BLS API disclaimer, both verbatim from their
    terms; Urban cited in its short ODC-By form. Esri basemaps now show each service's own credit (the bundled
    leaflet-providers strings were out of date and left out OpenStreetMap contributors).
    Checked live in a headless browser (footer text and all three basemaps' credits read back); app boot smoke and
    app reactives tests pass; `sibling_sync.R` OK.
  * [x] Basemaps with open terms, no Esri (2026-11-15; branch `phase5-ccd-saipe`). Esri's ArcGIS Online FAQ: without
    Esri software "you must purchase an ArcGIS Online subscription"; the free Location Platform key would need
    new endpoints, "Powered by Esri", a visitor terms-of-use page and pay-as-you-go billing past 2M tiles.
    **Mike's choice 11-15:** OpenStreetMap (default; policy URL tile.openstreetmap.org), USGS National Map
    (USGSTopo; public domain, USGS's requested acknowledgment as the credit), Shaded Relief (USGS relief + hydro).
    Options and quotes: `claude-notes/2026-11-15_basemap-options.md`. Checked live in both apps: opens on OSM, all
    three layers draw with their credits; app boot smoke and reactives pass; `sibling_sync.R` OK.
  * [x] Child poverty relabeled (2026-11-15; branch `phase5-ccd-saipe`). Census: "A true poverty \"rate\" for children
    cannot be determined from these figures, because the numerator and denominator refer to slightly different
    universes" (SAIPE school district overview, revised 2026-01-12). **Mike's choice 11-15 (option A):** labels only,
    numbers and the `Child_Poverty_Rate` column unchanged. Table column "School-Age Children in Poverty (Census est.)"
    (+ "Poverty Estimate Basis"), map popup, comparator card, About text; the footnote and the data dictionary (md +
    csv) explain the two counts. Read back live in both apps; app boot smoke, reactives, data dictionary and schema
    tests pass. Notes: `claude-notes/2026-11-15_census-reporting-lit-review/README.md` (Q2).
  * [x] About-tab wording for the county mining share (2026-11-15; branch `phase5-ccd-saipe`): it said "civilian labor
    force" (MT also "agriculture/resource extraction"); ACS S2403's denominator is the civilian employed population
    16 and over and line 4 is mining, quarrying, and oil and gas extraction only (Census API labels, read 2026-11-15).
    Now matches the data dictionary. Text only.
  * [x] SAIPE child poverty: Census's approximate 90% range beside each estimate (2026-11-16; branch `saipe-range`,
    edjobs 0.27.0). **Mike's choice 11-15 (option A):** Census publishes no margin of error for one district, only
    median relative errors by district size ("Quantifying Relative Error in the School District Estimates", revised
    2025-12-17); range = rate x (1 -/+ 1.645 x CV), floored at 0, capped at 1. New columns SAIPE_Population,
    Child_Poverty_Low, Child_Poverty_High (data dictionary; `pending` until the first run writes them;
    run_expectations `saipe_range_*`). Table column "Approx. 90% Range", map popup, comparator card, footnote.
    Rehearsal (`claude-notes/2026-11-15_rehearsal-wy-saipe-range-0.27.0.log`): every step passed; salarymap2 57 rows,
    55 rates, all with a range (7 of them surrounding-district stand-ins); no other value changed; parity 9/9;
    suites pre 1,239 / post 1,239 passed, 0 failed.
  * [x] ACS county figures: Census's 90% margins of error (2026-11-16; branch `acs-moe`, edjobs 0.28.0). **Mike's
    choice 11-16 (option B; `claude-notes/2026-11-16_acs-moe-reliability-decision.md`):** show the MOE, no CV tiers.
    New columns Median_Household_Income_MOE, Median_Gross_Rent_MOE, Mining_Employment_Share_MOE (salarymap2,
    salarymap; data dictionary; `pending` until the first run writes them; run_expectations `acs_moe_salarymap2`). Map popup
    income/rent +/- (mining +/- where shown, >= 5%), comparator rent, HE table, K-12 column "County Figures: 90%
    Margin of Error", footnotes (population trend has no MOE: controlled totals). A share whose MOE is at least the
    share is marked "not distinguishable from 0" (Census's CV > 0.61 line); none in WY.
    Rehearsal (`claude-notes/2026-11-16_rehearsal-wy-acs-moe-0.28.0.log`): every step passed; every county figure has
    its MOE (salarymap2 57 of 57, salarymap 9 of 9); data quality 132 passed; parity 9/9; suites pre 1,239 / post
    1,243 passed, 0 failed. Read back live in the rehearsed app (Laramie County SD 1: income +/-$3,160; rent +/-$39;
    mining +/-0.4 pts).
  * [x] Feedback without a GitHub login (2026-11-16; branch `feedback-form`). Mike: the public shouldn't need a login;
    filter spam in the app and open one issue per real report in this repo (no second repo, no weekly digest).
    `Wy_Ed_Jobs/feedback.R` (same file in both states): form in a modal (problem type, district, job/link, details; no
    email field, reports are public), checks in `feedback_check()` (hidden honeypot field, under 4 s from opening, spam
    words, exact repeats: dropped silently; missing/oversized fields, > 3 links, 3 per visit, 20 per hour: message),
    @mentions and #N neutralized, issue labeled data-quality + user-report (labels created in the repo). Posts with
    `GITHUB_FEEDBACK_TOKEN` (Connect Cloud secret: fine-grained, this repo, Issues read/write only); without it the
    button stays the GitHub issue-form link. manifest.json lists feedback.R; the manifest check now requires curl and
    jsonlite. `test-feedback.R` 28 passed; full suite 1,267 passed, 0 failed; checked in a headless browser (form opens,
    too-fast submit dropped, short text gets a message, a valid report reaches GitHub and a refused post says so).
  * [x] A retrieval date for every outside data source in the footer (2026-11-16; branch `source-dates`, edjobs
    0.29.0). Mike: BLS option A (`claude-notes/2026-11-15_citations-audit.md`, open item 2), and a date for the
    other sources too. The pipeline records a source in `source_retrieved_dates.csv` (app folder; REQUIRED_SCHEMAS
    entry; committed by the weekly run) only when its fetch succeeded and the data was kept (`retrieved_source` on
    safe_scrape() / write_reference_file(); OEWS only when a new year is downloaded). Each footer line shows
    "(retrieved YYYY-MM-DD)", or a range when one line's parts were fetched on different days. uw_salary_book.R
    records the UW book only when a new book is downloaded. Seeded from git: BLS OEWS 2026-10-31 (last download),
    WDE602 2026-10-27 (file added), UW salary book 2026-11-06; the weekly sources get their first dates from the next
    run (scrape_log.csv is not committed, and the local copy's context rows are months old). Rehearsal (`claude-notes/2026-11-16_rehearsal-wy-source-dates-0.29.0.log`):
    every step passed; data quality 132 passed; parity 9/9; suites pre 1,267 / post 1,269 passed, 0 failed; every
    source dated (OEWS kept 2026-10-31: BLS has no newer year).
  * [x] The weekly run keeps its scrape_log.csv (2026-11-16; branch `upload-scrape-log`). The log (per source:
    ok/empty/error, rows) is gitignored on purpose, and WY saved it only inside the failed-run bundle, so a
    successful run's log was lost with the job's workspace. New step "Upload this run's scrape_log.csv" (`if:
    always()`, 90-day artifact `scrape-log-<run id>`), the same step MT has. Workflow only.
  * [x] Feedback form live (2026-11-16): `GITHUB_FEEDBACK_TOKEN` (fine-grained PAT, this repo only, Issues
    read/write, expires 2027-11-16) set as a Connect Cloud secret and the app republished by Mike; his test report
    opened issue #42 with the data-quality and user-report labels (closed). Token added to `.github/token-expiry.csv`
    (the upkeep run opens an issue 30 days before; renewal steps in the file).
  * [x] Package phase 5 close-out (2026-11-16; branch `phase5-closeout`, edjobs 0.30.0). The last pipeline helpers
    both states defined moved to edjobs: `standardize_date()` (same code in both Rmds) and the K-12 salary history,
    `archive_k12_salary_snapshot(salarymap2, history_path, columns)` with this state's
    `WY_K12_SALARY_HISTORY_COLUMNS` (`salary_scrapers.R`; a test checks them against the committed history). The
    archive appends any district/year pair the file lacks (MT's rule; WY's appended only a new year: 0 rows differ on
    WY's committed files); `needs_k12_salary_archive_update()` retired. Rehearsal
    (`claude-notes/2026-11-16_rehearsal-wy-phase5-closeout-0.30.0.log`): every step passed; salary history
    unchanged; parity 9/9; suites pre 1,255 / post 1,258 passed, 0 failed.
  * [x] One registry schema for both states (2026-11-16; branch `registry-schema`, edjobs 0.31.0; Mike 11-16).
    `k12_district_registry.csv` holds every K-12 scrape target in MT's columns (District, NCES_LEAID, City, County,
    Latitude, Longitude, Platform, Platform_Key, Job_Link, List_Start, List_Stop, List_Skip): the direct boards
    (Applitrack -> AppliTrack, Org_ID -> Platform_Key), the 13 district-site rows (were the `misc_district_registry`
    data frame; CamelCase platforms, fixtures keep their names via edjobs `fixture_prefix`) and Laramie Montessori
    (Paylocity). New `he_institution_registry.csv` (the 9 colleges; one loop in the Rmd, file order) and
    `k12_feed_only_entities.csv` (the 5 WSBA-only orgs). Every source resolves to the same call (61 of 61; Laramie
    Montessori gains its page URL); the drift check still counts only the direct boards as registered. **Map columns
    from the registries (Mike: option A):** salarymap2's NCES_LEAID/County/Latitude/Longitude/Job_Link and
    salarymap's County/Latitude/Longitude/Link refreshed each run; values identical except links: 10 K-12 (Fremont
    24/25/38, Laramie 2, Lincoln 1/2, Platte 2, Sublette 9 had old boards or district pages, Mike: registry's for all;
    Platte 1 another page, Uinta 6 a URL suffix) and 8 colleges (Casper had Taleo, LCCC iCIMS). Rehearsal
    (`claude-notes/2026-11-16_rehearsal-wy-registry-schema-0.31.0.log`): every step passed; parity 9/9; suites pre
    1,362 / post 1,365 passed, 0 failed; combinedclean 726 rows, every Posting_Source labeled; all 9 colleges scraped;
    coverage calendar 63 entities (as last run).
  * [x] College postings at branch campuses on the map (2026-11-16; branch `he-campus-places`, edjobs 0.32.0; Mike
    11-16: "we need the locations to be accurate on the map"). A posting whose Location names another Wyoming town
    gets its own dot (edjobs `place_he_postings()`); the HE registry gains `Town`, `places.csv` holds every Census
    place with its county; anything else stays at the main campus, counted in a note under the map;
    facultydata.csv leaves the new columns out (`HE_PLACE_COLUMNS`; the first rehearsal stopped at its append
    guard). Plan and measurement: `claude-notes/2026-11-16_college-campus-locations.md`. Rehearsal
    (`claude-notes/2026-11-16_rehearsal-wy-campus-0.32.0.log`): every step passed except the post-run suite (2 tests
    not yet aware of campus rows; fixed in 8490dfd and passing on that run's output); suites pre 1,373 / post 1,371
    passed; hedata 462 postings: 282 main town, 23 other town (UW 17 in 7 towns, LCCC Laramie 4, CWC Jackson and
    Lander), 157 no town (the four PeopleAdmin colleges' fixed labels, Gillette's buildings, UW "United States";
    campus rules are stage 2, not built).
  * [x] IPEDS faculty salary over 9- to 12-month contracts (2026-11-16; edjobs 0.33.0; Mike 11-16: headline "Avg.
    salary, full-time instructional staff (IPEDS, 9-12-month contracts)"). The contract_length 99 "Total" row counted
    staff on contracts under 9 months, whose salaries IPEDS doesn't collect; the map popup's "blends part-time/adjunct
    pay" note was wrong (IPEDS salaries are full-time only) and is gone. Live fetch on 0.33.0
    (`claude-notes/2026-11-16_ipeds-salary-live.txt`): MT Blackfeet $25,621 -> $54,317, University of Montana
    $93,938 -> $95,013, the other 19 MT and all 9 WY figures and every professor-rank figure unchanged; Faculty_Count
    unchanged. Findings: `claude-notes/2026-11-16_ipeds-faculty-salary.md`.
  * [x] College postings at outreach sites and field offices, campus stage 2 (2026-11-16; branch `he-campus-stage2`,
    edjobs 0.34.0; Mike 11-16: "yes, build it"). WY's four PeopleAdmin colleges give a fixed campus label, not a
    town, so a posting is now also placed from a title marker ("(Rock Springs Campus)") or an explicit sentence on
    its PeopleAdmin page ("This position is located in Wright, WY"; "at the Green River Center"); never a bare town
    name, and a posting naming several towns stays at the main campus. "Main campus" counts only in lowercase (EWC's
    site banner reads "Eastern Wyoming College Main Campus & Douglas Campus"). Measured on 360 live PeopleAdmin
    pages: `claude-notes/2026-11-16_college-campus-locations.md`, "Stage 2 measured". The first rehearsal on 0.34.0
    placed none of WY's 6: the "higher ed scrapes" chunk's per-college select() dropped `Page_Places` (fixed in
    5c011d0, with a dry-run test that fails on the old chunk; log kept as
    `claude-notes/2026-11-16_rehearsal-wy-campus2-0.34.0-run2-dropped-page-places.log`). Rehearsal
    (`claude-notes/2026-11-16_rehearsal-wy-campus2-0.34.0.log`): every step passed; parity 9/9; suites pre 1,388 /
    post 1,391 passed, 0 failed; combinedclean 726 rows; hedata 465 postings: 300 main town, 29 other town (the
    measured 6: Western Green River 3, Sheridan Wright and Kaycee, EWC Douglas; UW 17 in 7 towns, LCCC Laramie 4,
    CWC Jackson and Lander), 136 no town.
  * [x] A link to each district's and college's page at its source (2026-11-16; branch `source-record-links`, edjobs
    0.35.0; Mike 11-16: "each row in each data set could have a url link to its source whenever possible"; option A,
    Mike: "yes"). salarymap2.csv gets `CCD_Link` (NCES CCD district page, from `NCES_LEAID`) and salarymap.csv
    `IPEDS_Link` (College Navigator, from `IPEDS_UNITID`), added by a last Rmd chunk after every chunk that rewrites
    them; wde602_district_staff_salaries.csv gets `Source_Link`, WDE's "District K12 Staff FTE and Average Salary by
    Category" report (reporting.edu.wyo.gov), the same on every row: WDE has no page per district, and its
    edu.wyoming.gov pages are behind a Cloudflare challenge (found via the Wayback copy of 2026-10-15). WSBA, SAIPE
    and ACS have no page per district (measurement: `claude-notes/2026-11-16_source-links-per-row.md`). Both NCES
    pages show NCES's newest year. Rehearsal (`claude-notes/2026-11-16_rehearsal-wy-source-links-0.35.0.log`): every
    step passed; parity 9/9; suites pre 1,388 / post 1,391 passed, 0 failed; links on 52 / 57 districts (no NCES id:
    Snowy Range Academy, Laramie Montessori, STRIDE, Sweetwater CDC, Wyoming Boys School), 9 / 9 colleges, and all
    1,938 WDE602 rows.
  * [x] Data dictionary source labels a reader can look up (2026-11-16; branch `dictionary-source-labels`; Mike 11-16:
    the `Primary_Authority` labels were internal, "Canonical Registry", "Project Pipeline"; option A, Mike: "A is
    fine"). Every row now names an outside source or "This dashboard: ..." with how the value was made: weekly
    snapshot, posting tracking, job title classification, district and college list, coverage summary; Salary_Note "This dashboard: method note"; postings
    are "Job posting (district job board or WSBA vacancy list)" or "Job posting (college job board)"; duplicate source names merged (NCES Common Core
    of Data (CCD), US Census ACS 5-year, US Dept of Education FSA, Wyoming Dept of Education (WDE602)). Names,
    coordinates and careers links say "district and college list", not IPEDS or Census geocoding: the cookbook has
    them hand-maintained. 131 of the CSV's rows and 128 rows of DATA_DICTIONARY.md changed; no other cell changed;
    the two agree on every label. Suite 1,364 passed, 0 failed. Plan: `claude-notes/2026-11-16_dictionary-source-labels.md`.
  * [x] Small leftovers (2026-11-16; branch `small-leftovers`). (1) salarymap2.csv's `Link` column removed: no code read
    it (the app, Rmd, schema check and tests use `Job_Link`), nothing refreshed it since the registry change (05bc330),
    MT's salarymap2 has no such column, and its dictionary text ("home page") was wrong for most rows (48 of 57 filled,
    most a job-board URL). Its row is gone from data_dictionary.csv and DATA_DICTIONARY.md; every other field of the
    CSV is byte-identical. (2) `tests/testthat/testthat-problems.rds` untracked and ignored, as MT. Suite 1,364
    passed, 0 failed; app boot smoke (NOT_CRAN) 24 passed.
  * [x] Package phase 6, slice 1: app helpers from edjobs 0.36.0 (2026-11-16; branch `phase6-slice1`). 22 functions
    both states' app.R defined identically (pay/date/MOE text, sparklines, trends and movers, job search, first-seen
    fill) now come from edjobs; app.R attaches it (`library(edjobs)`) and its copies are gone, with the app's copy of
    `first_seen_key()`. `fill_first_seen()` now takes `lookup = first_seen_table`. Checks: package vs app copies on
    both states' data 64/64 identical; app.R from main vs branch: all 78 data objects identical, every tab's 35
    outputs and the rows shown (7 tables, 122 rows) identical (`claude-notes/2026-11-16_phase6/`). Suite 1,370 passed; the
    only failures are the new committed-manifest test, which passes once manifest.json is rewritten from edjobs
    v0.36.0 installed from GitHub (the PR carries that manifest; the weekly run's manifest check now also requires
    edjobs as a GitHub package at the pinned tag). New test `test-app-no-local-copies.R`: app.R/feedback.R define no
    edjobs export. The unit tests moved to edjobs.
  * [x] Package phase 6, slice 2: app helpers that read an app global, from edjobs 0.37.0 (2026-11-17; branch
    `phase6-slice2`). Six functions (`validate_and_pad_schema`, `in_pay_band`, `relabel_spell_status`,
    `map_marker_radius`, `dictionary_columns_help`, `footer_retrieved`) now come from edjobs, with what they read
    from app globals passed as arguments (37 calls); app.R's copies and three constants are gone, and
    `note_load_issue()` collects the schema-guard banner text. Checks: edjobs `equivalence_slice2.R` 148 checks, 0
    differences; app.R from main vs branch: every data object identical (75; only the 3 constants gone), every tab's
    35 outputs identical (shinytest2, `parity2-wy.log`, `claude-notes/2026-11-16_phase6/`). Suite 1,350
    passed; the one failure is the EDJOBS_VERSION pin test until the pin moves to 0.37.0. WY's CLAUDE.md line on app.R's own copies now says they come from edjobs.
  * [x] Pin edjobs 0.38.0 (the 2026-11-17 full review's fixes) and split posting spells at gaps (2026-11-17; branch
    `pin-0.38.0`). `scripts/build_posting_spells.R` runs `split_posting_gaps()` between `bridge_posting_ids()` and
    `use_earliest_posted_date()` for K-12 and college (Mike's evidence rule, `claude-notes/2026-11-17_spells-gaps/`):
    same posted date on both sides of a gap stays one spell; a later posted date splits it and the earlier piece
    ends; no date splits it and the earlier piece is censored ("censored: back after a gap"); stable IDs never split.
    On the committed archives: K-12 11,938 -> 12,983 postings, 7,731 -> 7,894 endings in durations, median 26.5 days
    (unchanged), 887 pieces censored back after a gap; college 3,651 -> 4,212 postings, 2,684 -> 3,150 endings,
    median 59.5 -> 52.5, 97 censored. `history_accumulator.R`: a zero-row run no longer fails on `Posting_Source`.
    manifest.json: main's, with only the edjobs entry from v0.38.0 installed from GitHub (464c49c). Full rehearsal
    (`claude-notes/2026-11-17_rehearsal-wy-pin-0.38.0.log`): every step passed, suites 1,375 / 1,377 passed, 0
    failed; WSBA 96 rows, UW 232; K-12 rows 729 -> 726, college 460 -> 468.
  * [x] Twice-weekly runs, state side (2026-11-17; branch `twice-weekly`, edjobs 0.39.0 pinned). History checks count
    weeks, not runs or files: `check_pay_coverage.R` reads each ISO week's last run, `check_title_quality.R` the last
    56 days, `check_frozen_boards.R` counts ISO weeks (spells column `Frozen_Runs` -> `Frozen_Weeks`).
    `weekly-scrape.yml` runs in Mountain time (`TZ: America/Denver`; the Mac rehearsals already did), and a new step
    puts the daily presence check's last-commit age on the run summary, with a drift-issue section only when it is
    over 3 days old (Mike 11-17). The app rolls weekly totals up to each ISO week's last run; on the committed data
    only the extra runs of a week drop (05-07, 08-03, 08-04, 08-11). Archive replay
    (`claude-notes/2026-11-17_twice-weekly-replay/`): spells and frozen boards identical; drift flags 11 -> 9 (the
    August re-runs no longer count as weeks; Fremont #25 loses 2 flags, Mike 11-17: accepted). Full rehearsal
    (`claude-notes/2026-11-17_rehearsal-wy-twice-weekly.log`): every step passed, suites 1,375 / 1,377 passed, 0
    failed; WSBA statewide 101 postings; K-12 rows 729 -> 732, college 460 -> 468. The second weekly cron is a
    separate change.
  * [x] Second weekly run (2026-11-17; branch `second-cron`): `weekly-scrape.yml` cron `0 13 * * 2,5`, Tuesdays and
    Fridays (was Fridays); Montana moves to Mondays and Thursdays, so the shared `CENSUS_API_KEY` is never used by
    both on one day (days set by Mike 11-13). CLAUDE.md, README and the scraper skill's run-day line updated.
  * [x] Push retry for the weekly data commit (2026-11-17; branch `push-retry`), ported from MT (its 2026-11-03 fix):
    `weekly-scrape.yml` rebases the data commit onto the run's branch and pushes, up to 3 tries 15 s apart; a rebase
    conflict still fails the step. Same checkout as MT, where the 11-17 test dispatch pushed through it.
  * [x] Pin edjobs 0.40.0, the classifier batch (2026-11-17; branch `pin-0.40.0`): posted pay with a benefit word
    after the amount, part-time FTE, subjects from school/place names, HE job types (police/security -> Support
    Services, chief officers -> Administration, technicians), Apptegy "open until filled". Committed data
    reclassified (`scripts/reclassify_committed_data.R --apply --skip-guard`; the guard needs the old version
    installed, and the 11-17 rehearsal on 0.39.0 reproduced all 9 files): k12jobanalysis 27 subject rows,
    allsum 10,758 -> 10,768, HE spells 29 Positions; spells K-12 median 26.5, HE 52.5 (unchanged). Full rehearsal
    (`claude-notes/2026-11-17_rehearsal-wy-pin-0.40.0.log`): every step passed but the pre-run suite's app boot
    smoke test (1 failure, Chrome timing while the render ran; 24/24 alone after); post-run suite 1,377 passed, 0
    failed; WSBA 101 postings; K-12 rows 729 -> 730.
  * [x] Home: top job types, pin edjobs 0.41.0 (2026-11-18; branch `home-job-types`; plan
    `claude-notes/2026-11-17_home-job-types-plan.md`, flag rules `claude-notes/2026-11-18_not-full-time/`). The
    vacancy-rate plots, the biggest-mover boxes and the vacancy footnote are gone from Home; "Top K-12 / Higher Ed
    Job Types This Week" cards take their place (open postings, share, 12-run sparkline; a click opens that type's
    jobs). The top tables and the KPI cards count postings edjobs `classify_work_schedule()` doesn't mark as
    substitute, extra duty, part-time, student job or temporary: K-12 341 of 729, college 227 of 460. A switch on
    Home (on by default; "Leave out substitutes, coaching, part-time, student and temporary jobs") sets which postings
    the four top tables count, their Share and their sparklines, and the Jobs table a Home link opens follows it (a
    map popup link never does); the KPI cards keep both numbers (plan `claude-notes/2026-11-18_sparkline-basis/PLAN.md`,
    Mike 11-18). For the district and college sparklines, `k12_district_weekly_totals.csv` /
    `he_institution_weekly_totals.csv` gain `n_not_marked` (edjobs `posting_run_totals()`, pipeline and both rebuild
    scripts), backfilled from the archives (K-12 5,895 rows, college 1,083; the rebuilt `n` equals the committed `n` on every
    row; script `claude-notes/2026-11-18_sparkline-basis/backfill_n_not_marked.R`); schema and data dictionary
    cover the column. Switch screenshots `claude-notes/2026-11-18_sparkline-basis/shots/`. Rehearsals
    (`claude-notes/2026-11-18_rehearsal-wy-sparkline-basis{,-run2}.log`): run 1 found the history-accumulator test
    still counting this week's totals the old way (fixed: `posting_run_totals()`) and a WSBA name with a trailing
    no-break space ("Sublette County School District No. 1", 11-18) that `canonicalize_wsba_district()` missed,
    so 2 rows formed a phantom district (fixed: `str_squish()` first, test added). Run 2: rebuild parity 11/11, the
    Sublette rows join "Sublette County School District 1" (3 rows, 2 not marked); data quality failed only on
    Cheyenne Classical Academy's child-poverty range (Census geocoder failed for it this run and the committed
    salarymap2.csv has no `SAIPE_Population` to fall back on; not this change); boot smoke 24/0 alone. Suite on the
    final tree: 1,421 passed, 2 failed (the manifest test, until v0.41.0 is tagged). The pipeline and
    both rebuild scripts write `k12_jobtype_weekly_totals.csv` / `he_jobtype_weekly_totals.csv` (edjobs
    `jobtype_run_totals()`), backfilled from the archives: 1,695 and 2,064 rows, 123 and 121 runs from 2024-08-09
    to 2026-11-13; schema, data dictionary, rebuild parity and reclassify cover them. On a phone the Share column
    is hidden and type names break after "/". Full rehearsal (`claude-notes/2026-11-18_rehearsal-wy-jobtype-0.41.0.log`):
    every pipeline step passed, rebuild parity 11/11; the manifest step and its test fail until v0.41.0 is tagged
    on GitHub (edjobs installed from disk); post-run suite 1,396 passed, those 2 failed; WSBA 101 postings; K-12
    rows 729 -> 730. App tests on the final tree: reactives 315/0, boot smoke 24/0. Screenshots
    `claude-notes/2026-11-18_home-job-types-shots/`.
  * [x] Pin edjobs 0.42.0 (2026-11-18; branch `home-job-types`, replaces the 0.41.0 pin). 0.41.0 is the job-type
    flags the Home switch uses; 0.42.0 adds a day rate for a full/half day written before the amount (one MT posting;
    no WY archived pay text changes) and `write_csv_keep_quoting()`, which `scripts/reclassify_committed_data.R` now
    writes with (the file's own quoting kept). manifest.json's edjobs entry is from a pak install of the `v0.42.0`
    tag (only version, refs, SHA and build dates change). Suite: 1,423 passed, 0 failed (manifest test passes).
  * [x] Pin edjobs 0.44.0 (2026-11-19; branch `pin-0.44.0`, replaces the 0.42.0 pin). 0.43.0: pay units after a
    `;` and wrapped ranges (Browning "Lane 3/Step 0; $21.16" -> hour, Townsend "$13.52 -" / "$13.82/hour" ->
    $13.52-$13.82/hour; replay of 1,044 archived Pay_Text: 1 changes). 0.44.0, the hardening release: 170 exports
    made internal, no state names in package code, `state_config(timezone = )` (set here to America/Denver, the value
    the package used as its default), front matter. `scripts/reclassify_committed_data.R` reads the package namespace
    (`asNamespace`), since some helpers are no longer exported. manifest.json's edjobs entry is from a pak install of
    the `v0.44.0` tag (version, Title, Description, refs, SHA, build dates). Full rehearsal
    (`claude-notes/2026-11-19_rehearsal-wy-pin-0.44.0.log`): every pipeline step passed; post-run suite 1,425 passed, 0 failed. The pre-run suite's app boot smoke test failed once while the render ran (the known Chrome timing flake); alone it passes 24/24.
  * [x] Pin edjobs 0.46.0 (2026-11-19; branch `package-specs`, replaces the 0.44.0 pin).
    The scraper specs for the platforms edjobs scrapes now come from the package (`edjobs::default_scraper_specs()`,
    0.46.0; review step 4): `state_config.R` passes `scraper_specs(...)` with only this state's own scrapers (the district-site families, Paylocity, UW) and its PeopleAdmin spec (campus labels), so a
    district on a known platform is one registry row. These specs drive the PR live check, `scripts/repro_scraper.R`
    and the auto-fix issue, not the weekly pipeline. Dispatch parity (every source's resolved call before vs after,
    `claude-notes/2026-11-19_package-specs/`): 59 of 61 sources identical; Washakie 2 and Weston 1 (Edlio) now also pass `skip_section = NA`, the function's default. Also in the pin: 0.45.0's `state_config(oews_areas = )`
    (`oews_area_definitions()` identical to 0.44.0's for this state, 81 rows) and the toy state in package CI.
    manifest.json's edjobs entry is from a pak install of the `v0.46.0` tag. `k12_district_registry.csv`: `Platform_Key` filled for the 21 AppliTrack rows (tenant path) and 7 SchoolSpring rows (domain), equal to what the Rmd's loop derives from `Job_Link` (only that field changes; new check in `test-drift-check.R`). Live repro of Big Horn School District 1 through the new key: 11 postings. Suite on the tag: 1,425 passed, 0 failed.
  * [x] Scraper skill synced from the toolkit (2026-11-19): the specs for platforms edjobs scrapes come from
    `edjobs::default_scraper_specs()` (0.46.0; montana.md, wyoming.md), and an edjobs helper may be internal since
    0.44.0 (ci-automation.md: list the namespace with `ls(asNamespace("edjobs"))`, call one as `edjobs:::name`).
  * [x] Surrounding-district poverty range survives a geocoder failure (2026-11-19; Mike: "yes"). When the Census
    geocoder fails for a charter/early-childhood school, the Rmd keeps last run's rate, but the committed
    salarymap2.csv had no `SAIPE_Population` yet, so the 90% range came out NA and the blocking data-quality step
    failed (rehearsals 11-18 and 11-19: Cheyenne Classical; then Cheyenne Classical, Wyoming Classical, Sweetwater
    CDC). `carried_surrounding_population()` (state_config.R) now takes the population of the host district named in
    the carried-over `Child_Poverty_Basis` from this run's SAIPE rows, pooled as edjobs pools them. Live run of the
    SAIPE chunk on the committed data with the geocoder failing for all 7 schools: all 7 get a population and a range
    that brackets the rate; data-quality sweep 128 passed, 0 failed. New `test-surrounding-poverty-fallback.R`.
    Notes: `claude-notes/2026-11-19_cheyenne-classical-poverty-fallback.md`. Still open (step 5): store the host
    district ids instead of geocoding each run.
  * [x] Pin edjobs 0.47.0: pipeline stages, slice 1 (2026-11-19; branch `stage-context`, replaces the 0.46.0 pin).
    The Rmd's two Census ACS county-context blocks (salarymap2.csv, salarymap.csv) are now
    `refresh_county_context()` calls, and the source-record-links loop is `refresh_source_record_links()` (edjobs
    0.47.0; review step 5). Wyoming keeps Census's county names ("X County, Wyoming"), so no `county_suffix`.
    manifest.json's edjobs entry is from a pak install of the `v0.47.0` tag. Full rehearsal
    (`claude-notes/2026-11-19_rehearsal-wy-stage-context-0.47.0-run2.log`, after the geocoder fix above): every step
    passed (data quality 132/0). The rehearsed files' ACS columns equal the committed ones. They also gain the
    columns added since WY's last run (ACS MOEs, CCD/IPEDS links, the SAIPE range) and the 11-16 registry links, as
    Friday's run on main would.
  * [x] Scheduled runs moved to 07:17 UTC (2026-11-19; Mike: run very early, so a failure can be fixed and re-run the
    same day and is known by morning). Just after midnight Mountain (00:17 MST, 01:17 MDT): every step's date is
    Mountain (`TZ`), so a start before midnight would date the run the day before. GitHub started the 13:00 UTC cron
    4-8.5 h late (runs since 09-25: 17:08-21:27 UTC), and the daily presence check's 13:17 UTC cron 5.5-9.5 h late,
    so an off-the-hour minute doesn't avoid it. Days unchanged (MT Mon/Thu, WY Tue/Fri; shared Census key).
  * [x] Pin edjobs 0.49.0: pipeline stages, slice 2 (2026-11-19; branch `stage-columns`, replaces the 0.47.0 pin).
    The HE chunk's IPEDS enrollment, 5-year enrollment trend and FSA Pell share blocks are now
    `refresh_file_columns()` calls (edjobs 0.48.0; review step 5; Wyoming has no K-12 blocks of slice 3's shape: its
    SAIPE chunk keeps the charter surrounding-district fallback). `test-pipeline-defensiveness.R` counts
    `refresh_file_columns()` / `refresh_county_context()` as guards (they run their fetch through `safe_scrape()`).
    manifest.json's edjobs entry is from a pak install of the `v0.49.0` tag. Full rehearsal
    (`claude-notes/2026-11-19_rehearsal-wy-stage-columns-0.49.0.log`): every step passed (data quality 132/0); the
    rehearsed Enrollment, Enrollment_Change_Pct and Pell columns equal the committed ones. The other differences are
    those of the 0.47.0 rehearsal (columns and registry links merged since WY's last run, 11-13).
  * [x] Pin edjobs 0.52.0: weekly check scripts in the package (2026-11-19; branch `step6-scripts`, replaces the
    0.49.0 pin; review step 6, `claude-notes/2026-11-19_step6-scripts-measure.md`). Nine `.github/scripts` are now
    short calls into edjobs (0.50.0-0.52.0): sanity, schema, run expectations, render-with-stack, drift
    (`check_drift_step()`), pay coverage, title quality, the pre-flight canary (`canary_step()`) and rebuild parity
    (`report_rebuild_parity()`; the script still sources the state's rebuild files). What differed by state is in
    `state_config.R`: `k12_source_names` (archive district names through `canonicalize_k12_district()`; drift and
    pay coverage still source `k12_he_classification.R` for it), `direct_registry = read_direct_board_registry`
    (the feed section counts the direct boards only) and the feed's canary `signature`. Workflow paths unchanged.
    `test-canary-api-check.R` moved to edjobs. Parity of old and new scripts on the committed data:
    `claude-notes/2026-11-19_step6-parity/`. manifest.json's edjobs entry is from a pak install of the `v0.52.0` tag.
    Full rehearsal (`claude-notes/2026-11-19_rehearsal-wy-step6-0.52.0.log`): every step passed (canary, data quality
    132/0, drift 0 flagged, rebuild parity "all 11 files reproduced from the archives"); suite 1,426/0 before the
    run, 1,428/0 after, none skipped.
  * [x] Pin edjobs 0.53.0: the Census check and the auto-fix live check in the package (2026-11-19; branch
    `step6-census`, replaces the 0.52.0 pin; review step 6, slice 4). `check_census_drift.R` is
    `check_census_step()` and `live_check_autofix.R` is `live_check_autofix_step()` (the script sources the scraper
    files first). The Census check's expected counts now come from `salarymap2.csv` / `salarymap.csv`: the script's
    hard-coded ones had gone stale (48 districts against 57), so a source could lose most of its coverage before it fired. Every county
    should have ACS context and every district a SAIPE rate, except `state_config(saipe_gaps = )`: Northeast Wyoming BOCES and Wyoming Boys School.
    Parity (`claude-notes/2026-11-19_step6-parity/slice4/`): identical output on the committed data (healthy); on a
    copy with two SAIPE rates blanked, the new check flags both by name. Live check run with the state's real
    scrapers through a stubbed `gh` (Laramie County SD 1: 94 postings; Sublette County SD 1 has no single-source call). manifest.json's edjobs entry is from a pak install of the `v0.53.0` tag
    (Suggests gained chromote). Single-step change: each new script run on the committed data, plus the suite 1,426 passed, 0 failed.
  * [x] Salary source named only where that source gave a salary (2026-11-19; branch `salary-source-label`, found
    while measuring the salary drift check; MT has the same fix). The pipeline set `Salary_Source = "WSBA"` on every
    district, so nine WSBA doesn't list (Snowy Range Academy, Laramie Montessori, Cheyenne Classical, Wyoming
    Classical, Prairie View, Northeast Wyoming BOCES, STRIDE, the Sweetwater CDC, Wyoming Boys School) showed "Salary
    source: WSBA" in their map popup under WDE's average (three of them) or under nothing. Now WSBA is named only
    where it gave a base or superintendent salary, and IPEDS only where it gave a faculty salary (all nine colleges
    today); the nine committed cells were blanked (every other column unchanged, and the new expression on the old
    file gives the repaired one exactly). New data-quality test: a named source with no salary fails.
  * [x] Pin edjobs 0.54.0: the auto-fix issue step in the package (2026-11-19; branch `step6-autofix`, replaces the
    0.53.0 pin; review step 6, slice 5). `file_autofix_issues.R` is `file_autofix_issues_step()`; the script keeps its
    own sourcing (`drift_check.R` and the two scraper files). Parity (`claude-notes/2026-11-19_step6-parity/slice5/`): a fake `gh` on PATH logs every call,
    its body file and token; five scenarios (Claude dispatch; Copilot assignment and its PR; an edjobs companion
    issue; escalation to Claude; Copilot refusing; recovery closes with the companion; a confirmed_broken comment; no
    results file; the cap) give identical calls and output from the old script, the package function and the new
    script. manifest.json's edjobs entry is from a pak install of the `v0.54.0` tag. Suite on the tag: 1,428 passed, 0 failed.
  * [x] Pin edjobs 0.55.0: the drift corroboration in the package (2026-11-19; branch `step6-corroborate`, replaces the
    0.54.0 pin; review step 6, slice 6). `corroborate_drift.R` is `corroborate_drift_step()`; the script keeps its
    own sourcing. `state_config.R` gains `canonical_source_name` (the URL lookup's raw registry spellings canonicalized) and `drift_intro` (the report's opening text). Live parity, Gemini off (`claude-notes/2026-11-19_step6-parity/slice6/`): five flagged sources (a
    scrape error, no URL, live boards, a college, and Converse County SD 2, whose registry spelling differs) through the old script and the new one give the same verdicts,
    `drift_results.csv`, report and printed lines (apart from one page's live "current as of" time). manifest.json's edjobs entry is from a pak install of the
    `v0.55.0` tag. Suite on the tag: 1,428 passed, 0 failed.
  * [x] Pin edjobs 0.56.0: a drift corroboration with no LLM reading keeps its verdict (2026-11-19; branch
    `pin-0.56.0`, found during slice 6). With no reading (no key, a failed or quota-limited Gemini call, a rejected
    count) the corroboration had turned "inconclusive" pages into "looks_genuinely_empty" ("an LLM read no postings
    off the live page either"), which the drift report leaves out, so a Gemini outage would hide them. Now they stay
    inconclusive and are reported; a real empty reading still downgrades. A source the statewide feed lists postings
    for, with no reading, now stays inconclusive (a human look) instead of reaching likely_broken (an auto-fix issue)
    through that downgrade. Live run with the key off (`claude-notes/2026-11-19_llm-unavailable/live-0.56.0.log`):
    Laramie County SD 1 and UW now inconclusive, as expected. manifest.json's edjobs entry is from a pak install of the `v0.56.0` tag.
    Suite on the tag: 1,428 passed, 0 failed.
  * [x] Pin edjobs 0.57.0: the salary-source check in the package, coverage against last run's committed file
    (2026-11-20; branch `step6-salary-drift`, replaces the 0.56.0 pin; review step 6, slice 7; Mike chose B over
    per-source gap lists). `check_salary_drift.R` is `salary_drift_step()`; the sources, value bounds and
    year-over-year pairs are `state_config(salary_checks = )`. The WSBA line counted rows (57 >= 48 with 10 districts lacking a base salary); it now counts base salaries, and adds WSBA superintendent pay and CCD teacher FTE. The Sheridan/Gillette split watch is the `extra` hook (`sheridan_gillette_split_lines()`, `ipeds_unitids.R`, now tested). A drop names the districts or colleges that lost a value; it is
    flagged once (after that run's commit it is the baseline). Replayed on every committed version of both states'
    salary maps (75 commits): no false flags. Parity (`claude-notes/2026-11-19_step6-parity/slice7/`): same output on the
    committed data apart from one reworded sentence; with 5 WSBA districts blanked the old script passed and the new one names
    them. Rehearsals have no `.git`: `dryrun.sh` sets `EDJOBS_SALARY_BASELINE`. manifest.json's edjobs entry is from a pak
    install of the `v0.57.0` tag. Suite on the tag: 1,432 passed, 0 failed.
  * [x] Pin edjobs 0.58.0 (2026-11-20; branch `pin-0.58.0`): a salary value range per unit of another column, for MT's
    general fund (no Wyoming config change); salary report amounts are whole dollars. manifest.json's edjobs entry is
    from a pak install of the `v0.58.0` tag. Suite on the tag: 1,432 passed, 0 failed.
  * [x] The weekly run is edjobs's reusable workflow (2026-11-20; branch `weekly-run`, edjobs #58, v0.59.0; review
    step 6, second half). `weekly-scrape.yml` is a short caller: cron, `concurrency`, `permissions`, secrets passed one
    by one, and Wyoming's data as inputs (the app folder, the Rmd, its commit files, `check_frozen_boards.R` as the
    state's own check). The `uses:` tag equals `EDJOBS_VERSION` (`test-weekly-workflow-ref.R`).
    Test dispatch on a branch copy of main after the 11-20 run (run 44766801917, data discarded): success, the same 40
    step outcomes as the 11-20 run 44762141481 apart from two renamed steps, the frozen-boards check running as "The
    state's own checks", and the auto-fix filing (skipped off main); every check summary identical (drift 0 flagged,
    salary and Census healthy, rebuild parity 11/11, run expectations 28/28, K-12 total 735), a commit dated 2026-11-20
    in Mountain time. Pin 0.59.0 (no R change). manifest.json's edjobs entry is from a pak install of the `v0.59.0`
    tag. Suite on the tag: 1,434 passed, 0 failed.
  * [x] Package review step 7, slice 1 (+ 2a): the app's shared server, UI helpers, Feedback form and Listing
    Duration tabs from edjobs 0.60.0 (2026-11-21; branch `app-server-shared`, edjobs #59; Mike's choice A, 11-20).
    `server` calls `dashboard_server_shared()` first (the 101 server blocks both states had identical or differing
    only by the state's name) and keeps this state's own 14 blocks, which read 7 of its reactives; `outputOptions()`
    on the map stays here because it must run after the state's map output exists (the first parity run failed on
    it). The six UI helpers, `feedback.R` and the two Listing Duration panels (`k12_spells_panel()`,
    `he_spells_panel()`) are gone from the app folder; app.R 4,005 -> 2,461 lines. Tests: `test-feedback.R` moved to
    edjobs; `test-app-reactives.R` reaches shared internals as `shared$name()`; the data-dictionary download test
    also reads the package's handlers (same download files as main). Checks vs main: every data object identical
    (83); every tab's outputs identical (shinytest2, 33/33). edjobs 0.60.0 also carries the Carbon
    posted-pay fix. manifest.json: the edjobs entry (with its new Suggests) from a pak install of the `v0.60.0` tag,
    feedback.R out of the file list, stale file checksums refreshed. Suite on the tag: 1,407 passed, 0 failed. Notes and scripts:
    `claude-notes/2026-11-21_step7-slice1/`.
  * [x] Package review step 7, slice 2b, Data tab: its UI from edjobs 0.61.0's `data_tab_panel()` (2026-11-21;
    branch `data-tab-panel`, edjobs #60; Mike 11-21: the package builds each tab, the state passes its text, one tab
    per PR). app.R keeps only Wyoming's own text: 11 `data_tile()`s (fields it leaves out take the shared default
    for that download), the provenance rows (`data_provenance_row()`; county, student need, CCD staffing and IPEDS
    pay rows shared), and the citation and repository. The tile counts are now computed from the downloads at app
    start (`download_rows()`, `rows_phrase()`); the hand-written ones were stale: 76,000+ K-12 and 29,000+ higher ed records for downloads of 13,513 and 18,532 rows; now 13,000+ and 18,000+. Checks vs main
    (`claude-notes/2026-11-21_step7-slice2b-data/`): page HTML identical before the counts commit, only the count
    lines after it (`ui_parity.R`); every tab's outputs identical (shinytest2, 33/33, 122 table rows shown);
    Data tab screenshots looked at. manifest.json edjobs entry from a pak install of the `v0.61.0` tag;
    EDJOBS_VERSION and the weekly workflow ref 0.61.0. Suite on the tag: 1,407 passed, 0 failed (with NOT_CRAN=true, so the app boot test runs).
    Live 11-21 01:05 UTC: new counts shown; Home, Map, Data, K-12 Jobs connected with 0 errors, 3 tries.
  * [x] Data tab wording: two tile counts that didn't match the data (2026-11-21; branch `data-tab-wording`). The
    Higher Ed Archive tile said "Wyoming's 9 public community colleges and UW"; salarymap.csv has 9 institutions,
    UW plus 8 community colleges (the provenance row already said 7 + Gillette + UW), so now "8". The WDE602 tile
    said "51 districts"; the file's 51 are the 48 school districts plus 3 charter schools (Cheyenne Classical
    Academy, Prairie View Community School, Wyoming Classical Academy), so it now says that. Page HTML vs main:
    only those two lines differ (`claude-notes/2026-11-21_step7-slice2b-data/ui_parity.R`).
  * [x] Package review step 7, slice 2b, Map tab: its UI from edjobs 0.62.0's `map_tab_panel()` (2026-11-21;
    branch `map-tab-panel`, edjobs #61, this repo's #81). app.R keeps only Wyoming's own text: the "About this map"
    paragraphs, what the red "Partial" badge means here, and the note under the map; filters and map are the
    package's. Checks vs main (`claude-notes/2026-11-21_step7-slice2b-map/`): page HTML identical (210,165 chars,
    `ui_parity.R`); every tab's outputs identical (shinytest2, 33/33, 122 table rows shown). manifest.json: the edjobs
    entry (leaflet now in its Suggests) for the `v0.62.0` tag, and app.R's checksum; EDJOBS_VERSION and the weekly
    workflow ref 0.62.0. Suite on the tag: 1,407 passed, 0 failed, 0 skipped.
  * [x] Package review step 7, slice 2b, both Jobs tabs: K-12 Jobs and Higher Ed Jobs from edjobs 0.63.0's
    `jobs_tab_panel(level, pay_note)` (2026-11-21; branch `jobs-tab-panel`, edjobs #62, this repo's #82). The two tabs
    differ only in their ids, Higher Ed's Appointment filter and the pay note, so one function and one PR (Mike 11-21).
    app.R keeps only Wyoming's pay notes. Checks vs main (`claude-notes/2026-11-21_step7-slice2b-jobs/`): page HTML
    identical (210,165 chars, `ui_parity.R`); every tab's outputs identical (shinytest2, 33/33, 122 table rows shown).
    edjobs R CMD check OK (0/0/0). manifest.json: the edjobs entry for the `v0.63.0` tag, and app.R's checksum;
    EDJOBS_VERSION and the weekly workflow ref 0.63.0. Suite on the tag: 1,407 passed, 0 failed, 0 skipped.
  * [x] Package review step 7, slice 2b, Higher Ed Trends: its UI from edjobs 0.64.0's `he_trends_panel()`
    (2026-11-21; branch `he-trends-panel`, edjobs #63, this repo's #83). Wyoming uses the default timeline window
    (the last 365 days), so app.R passes only the two summaries. Checks vs main
    (`claude-notes/2026-11-21_step7-slice2b-he-trends/`): page HTML identical (210,165 chars, `ui_parity.R`); every
    tab's outputs identical (shinytest2, 33/33, 122 table rows shown). edjobs R CMD check OK (0/0/0). manifest.json:
    the edjobs entry for the `v0.64.0` tag, and app.R's checksum; EDJOBS_VERSION and the weekly workflow ref 0.64.0.
    Suite on the tag: 1,407 passed, 0 failed, 0 skipped.
  * [x] Package review step 7, slice 2b, Higher Ed Colleges: its UI from edjobs 0.65.0's `he_colleges_panel()`
    (2026-11-21; branch `he-colleges-panel`, edjobs #64, this repo's #84). app.R keeps Wyoming's two directory notes
    (Salaries: three IPEDS years and the professor-rank average; County: income and rent) and opens the comparator on
    UW vs LCCC. Checks vs main (`claude-notes/2026-11-21_step7-slice2b-he-colleges/`): page HTML identical (210,165
    chars, `ui_parity.R`); every tab's outputs identical (shinytest2, 33/33, 122 table rows shown). edjobs R CMD check
    OK (0/0/0). manifest.json: the edjobs entry for the `v0.65.0` tag, and app.R's checksum; EDJOBS_VERSION and the
    weekly workflow ref 0.65.0. Suite on the tag: 1,407 passed, 0 failed, 0 skipped.
  * [x] Package review step 7, slice 2b, K-12 Trends: its UI from edjobs 0.66.0's `k12_trends_panel()` (2026-11-21;
    branch `k12-trends-panel`, edjobs #65, this repo's #85). Wyoming uses the defaults (no slider label, no
    counting note), so app.R passes only the two summaries. Checks vs main
    (`claude-notes/2026-11-21_step7-slice2b-home-districts/`): page HTML identical (210,165 chars, `ui_parity.R`);
    every tab's outputs identical (shinytest2, 33/33, 122 table rows shown). edjobs R CMD check OK (0/0/0).
    manifest.json: the edjobs entry for the `v0.66.0` tag, and app.R's checksum; EDJOBS_VERSION and the weekly
    workflow ref 0.66.0. Suite on the tag: 1,407 passed, 0 failed, 0 skipped.
  * [x] Package review step 7, slice 2b, Home: its UI from edjobs 0.67.0's `home_tab_panel()` (2026-11-21; branch
    `home-tab-panel`, edjobs #66, this repo's #86). app.R passes Wyoming's name, where its K-12 postings come from,
    the refreshed date and the credit line (Mike Bostick and Mark Perkins); the switch label and its two notes
    (HOME_SWITCH_LABEL, NOT_MARKED_NOTE, NOT_MARKED_NOTE_HE) now come from edjobs. Checks vs main
    (`claude-notes/2026-11-21_step7-slice2b-home-districts/`): page HTML identical (210,165 chars, `ui_parity.R`);
    every tab's outputs identical (shinytest2, 33/33, 122 table rows shown). edjobs R CMD check OK (0/0/0).
    manifest.json: the edjobs entry for the `v0.67.0` tag, and app.R's checksum; EDJOBS_VERSION and the weekly
    workflow ref 0.67.0. Suite on the tag: 1,407 passed, 0 failed, 0 skipped.
  * [x] Package review step 7, slice 2b, K-12 Districts (the last tab): its UI from edjobs 0.68.0's
    `k12_districts_panel()` (2026-11-21; branch `k12-districts-panel`, edjobs #67, this repo's #87). app.R keeps
    Wyoming's text (the Openings note, the directory's pay/county paragraphs and source, the comparator blurb, the
    openings source), the comparator's opening pair (Laramie 1 vs Natrona 1) and its salary chart's card (WSBA base
    and WDE average). Checks vs main (`claude-notes/2026-11-21_step7-slice2b-home-districts/`): page HTML identical
    (210,165 chars, `ui_parity.R`); every tab's outputs identical (shinytest2, 33/33, 122 table rows shown). edjobs R
    CMD check OK (0/0/0). manifest.json: the edjobs entry for the `v0.68.0` tag, and app.R's checksum; EDJOBS_VERSION
    and the weekly workflow ref 0.68.0. Suite on the tag: 1,407 passed, 0 failed, 0 skipped. With all 11 tabs from
    edjobs, app.R is 1,911 lines (2,299 before slice 2b).
  * [x] Package review step 7, slice 3, part 1: the server blocks that differed only by a setting come from edjobs
    0.69.0's `dashboard_server_shared()` (2026-11-21; branch `slice3-config`, edjobs #69, this repo's #89): the
    map's basemaps, legend and opening view (`map_view`, -107.5/43, zoom 7) and county zoom, the Institution
    Summary table (page length 9; its Note text for Sheridan & Gillette's shared reporting), the HE slider's opening
    range and the slider labels
    (`bounded_timeline_value()` / `timeline_history_note()` now edjobs's). Dead `k12_new_table` removed (no UI showed
    it). The Feedback form's report time takes `timezone = "America/Denver"` (edjobs had the zone hard-coded since
    0.60.0). Map marker popups stay here for part 3 (their pay lines differ by state). Checks vs main
    (`claude-notes/2026-11-21_step7-slice3a/`): every tab's outputs identical (shinytest2, main on 0.68.0 vs branch on
    0.69.0, 33/33, 122 table rows shown). manifest.json: the edjobs entry for the `v0.69.0` tag, and app.R's
    checksum; EDJOBS_VERSION and the weekly workflow ref 0.69.0. Suite on the tag: 1,405 passed, 0 failed,
    0 skipped. app.R is 1,695 lines (1,911 before).
  * [x] Package review step 7, slice 3, part 2: K-12 "new this week" from edjobs 0.70.0's `find_k12_new_postings()`,
    the K-12 Jobs table from `dashboard_server_shared()` (2026-11-21; branch `slice3-new-this-week`, edjobs #70, this
    repo's #90). Mike chose rule A, then its paired form once measured: a new `Posting_ID`, less ID changes (a new
    ID replacing, one for one, a gone posting with the same title, location and district). Literal A would also have
    dropped a second same-title opening next to one still listed (MT 18, WY 76 over the archives;
    `claude-notes/2026-11-21_step7-slice3a/rule_a_paired.R`). Here: 2,439 new over 119 archived weeks instead of 2,371 by title +
    location + District (title edits no longer count; second same-title openings do); the Jobs filter matches by
    `Posting_ID`, not every posting sharing a new one's title + District (198 extra rows over the archive). app.R
    carries `Posting_ID` (required in combinedclean.csv, k12jobanalysis.csv), so the active K-12 jobs download gains
    that column, as MT's has. Latest week 1 -> 1. Parity vs main (shinytest2, every tab): 33/33 outputs identical, 122
    table rows shown.
    manifest.json: the edjobs entry for the `v0.70.0` tag, and app.R's checksum; EDJOBS_VERSION and the weekly
    workflow ref 0.70.0. Suite on the tag: 1,405 passed, 0 failed, 0 skipped.
  * [x] Package review step 7, slice 3, part 3: the Districts tab and map markers from edjobs 0.71.0's
    `dashboard_server_shared()` (2026-11-21; branch `slice3-districts`, edjobs #72, this repo's #91): the District
    Summary table and footnote, the compare cards and salary plot, and the map marker observer. app.R keeps a
    `DISTRICT_SPEC <- district_spec(...)`: WSBA base salary current and prior year (`prior_school_year_label()`, now edjobs's), WDE average, superintendent salary, their card rows and popup lines, the compare bars (base vs WDE average), the WSBA and WDE source notes and the Sheridan + Gillette vacancy remark. Parity vs main (`claude-notes/2026-11-21_step7-slice3b/`,
    testServer, old app.R on 0.70.0 vs branch): table data and widget, footnote, cards and plot (none / 4 / 2
    districts), and every popup and label (24 + 78) identical. One rule changed: a popup pay line drops " · year" when
    the year is missing (no row here has one). manifest.json: the edjobs entry for the `v0.71.0` tag, and app.R's
    checksum; EDJOBS_VERSION and the weekly workflow ref 0.71.0. Suite on the tag: 1,405 passed, 0 failed, 0 skipped. app.R is 1,263 lines
    (1,665 before).  * [x] edjobs 0.72.0 (2026-11-21; branch `edjobs-0.72.0`). For WY only its pay fix applies: an amount in millions
    or billions is not pay ("$1M ... endowment" was read as pay of $1, found on MT's new UM Interfolio source). No
    archived Pay_Text in either state has such an amount, so no committed value changes. The release's other change
    (the coverage calendar's `extra_sources`) is unused here. manifest.json: the edjobs entry for the `v0.72.0` tag;
    EDJOBS_VERSION and the weekly workflow ref 0.72.0. Suite: 1,385 passed, 0 failed, 0 skipped.
  * [x] HE faculty category fixes, edjobs 0.73.0 (2026-11-21; branch `edjobs-0.73.0`, edjobs #75; Mike chose b), from
    MT's UM Interfolio faculty titles. Clinical ranks, speech-language, forestry and the biological sciences are fixed,
    and UW's Wyoming Institute for Disabilities is Health Sciences (an academic unit of UW's College of Health
    Sciences, uwyo.edu/wind). Replay: 15 WY archived titles move. 14 WIND titles go Education -> Health Sciences;
    "Clinical Assistant Professor - Educational Health Center of Wyoming" (UW College of Education's clinic) goes
    Health Sciences -> Education. Committed data reclassified (`reclassify_committed_data.R --apply`):
    - facultydata.csv: 19 rows (the EHC post's 15 to Education, WIND's Research Professor's 4 to Health Sciences;
      WIND's Clinical Professor, 12 rows, stays Health Sciences);
    - allsum_he.csv: 51 rows -> 52;
    - he_job_duration_spells.csv: those 2 postings.
    The script wrote facultydata.csv with CRLF inside multi-line fields (2,228 CRs; the committed file has none), so
    they were stripped; the parsed table then differs only in those 19 Category values, in the same order.
  * [x] `reclassify_committed_data.R` no longer writes CRs (2026-11-21; branch `reclassify-no-cr`). The raw HE
    archives hold `\r\n` inside some multi-line text fields; `read.csv()` (so the weekly run's append) stores them
    as `\n`, and `rebuild_parity_row()` ignores the difference, so the guard passed and `--apply` wrote them back
    (the 2,228 CRs above). `in_committed_order()` now turns `\r\n` into `\n` in text columns. Check (rebuild at
    the pinned classifier, each file written with the old and the fixed code, compared byte for byte with the
    committed file): facultydata.csv old 2,228 CRs, fixed byte-identical; the other 10 files have no CRs either way.
    Same fix in MT's copy. Follow-up (2026-11-22, same branch): a committed row now keeps its own text wherever the
    rebuild differs only in what the guard ignores (NA vs "", \r\n vs \n), and every column is written as text,
    so the committed quoting holds (the old number coercion wrote combinedclean.csv's quoted Est_Year bare). The
    rebuild scripts' Rscript entry points (`rebuild_*_history_from_archive.R`) wrote with plain `write.csv()`: the
    same 2,228 CRs, plus quoted dates in 9 files; they now write the committed format (row order stays the
    rebuild's). Check: all 11 files byte-identical in both states; replaying b41c8c8 (facultydata.csv before ->
    0.73.0 rebuild) gives the hand-cleaned commit byte for byte; the rebuild entry points give the committed
    content with no CRs or quoting changes (only row order differs). Spell builders: no change.
  * [x] Silent-source check, repo side (2026-11-22; branch `silent-sources-check`; edjobs 0.74.0, bostickmike/edjobs#76;
    test-kit plan item 1). `.github/scripts/check_silent_sources.R` runs `check_silent_sources_step()`: a registry
    district or college with no rows in any of its last 4 weekly runs goes into the drift issue unless
    `silent_sources_acknowledged.csv` (empty) lists it with a reason. On the archives today (11-22) it lists none:
    archives before 11-13 have no `Posting_Source`, so WSBA rows count for a district there, and Sheridan County SD 3
    (own board 0 rows on 11-13 and 11-20, WSBA 3) can be listed from the fourth labeled run. The workflow step runs
    from the pin bump to 0.74.0, held until after the 11-24 WY run.
  * [x] Every posting parser has a captured, non-empty fixture with an exact title (2026-11-22; branch
    `test-kit-parser-fixtures`; test-kit plan item 4). `tests/testthat/test-parser-fixtures.R` (same file in MT): each
    posting parser at the repo root needs a test that reads a captured fixture and asserts a literal title that can
    only pass with rows, or a line in `parser-fixture-allowlist.csv` (empty here). UW's `parse_uw_requisitions()` was
    tested only on a hand-built data frame: new fixture `uw_requisitions_page1_2026-11-22.json` (live page 1, 25 of
    230, unaltered) and a test on it. `eastern_wyoming_scraper.R` (RSelenium, not called by the Rmd since Eastern
    became a PeopleAdmin row in `he_institution_registry.csv`) deleted with its test, its `helper-setup.R` line and its
    entry in `claude-autofix.yml`'s allowed paths. 10 parsers, all covered.
  * [x] edjobs pinned at 0.81.0 (2026-11-22; branch `bump-edjobs-0.81.0`; bostickmike/edjobs#83). 0.74.0-0.80.0 as
    MT (silent sources, title lint, drift report blocks, pay range fix, drift acknowledgements by posting); 0.81.0:
    OPI's generic titles take the description's job (MT only: WY's feed has no descriptions) and "Family Consumer
    Science" / "Family & Consumer Science" are FCS, not Science Education. Reclassified with 0.81.0 installed: 19
    k12jobanalysis rows Science Education -> Family and Consumer Science (2 archived titles), allsum regrouped;
    posting spells unchanged.
  * [x] edjobs pinned at 0.82.0 (2026-11-22; same branch; bostickmike/edjobs#84): silent-source acknowledgements can
    carry an `Empty_Text` pattern the board must still match (WY has no silent sources; no change).
  * [x] edjobs pinned at 0.84.0 (2026-11-23; same branch; bostickmike/edjobs#85-#88): "Last 12 Weeks" sparklines
    plot the latest count in each of the last 12 weeks, and the dashboard text says "update", not "scrape". Dashboard
    code only: `reclassify_committed_data.R` guard passed at v0.84.0, nothing moved; posting spells unchanged.
    Full rehearsal (11-23): every step passed except one post-run test, `test-app-reactives.R`'s "has new" map
    filter, which asked for at least one district with a new teaching posting; 11-20 to 11-23 had none (53 teaching
    postings, all seen before). Since the suite runs before each weekly run, a quiet few days would have blocked the
    next run. The test now checks the filter keeps exactly the places with a new posting (same fix in MT).
  * [x] edjobs pinned at 0.85.0 (2026-11-24; branch `bump-edjobs-0.85.0`; bostickmike/edjobs#90): a Trakstar Hire
    reader (MT's St. Labre board; no WY board on it), `parse_jobposting_jsonld()` retries blocks with raw line breaks
    (WY's NEOGOV blocks parse first time, unchanged), and a pay grade's low-mid-high steps read first to last (none in
    either state's archives). `reclassify_committed_data.R` at v0.85.0: nothing to write. Full rehearsal (11-24) passed every step: suite 1,456 pass, 0 fail
    (`claude-notes/2026-11-24_trakstar/rehearsal_wy.log`); the committed pin files match the rehearsed copy (manifest:
    same edjobs entry, the rest is the Mac's `writeManifest` rewrite).
  * [x] Live dashboard check, edjobs pinned at 0.86.0 (2026-11-24; branch `live-check-0.86.0`; bostickmike/edjobs#91;
    Mike asked 11-23). Connect Cloud redeploys the app on every push to main, and every other check ran before that
    push; nothing checked the app it then served. `.github/workflows/live-check.yml` (edjobs `live_check_step()`) reads
    the live page's "Refreshed on" date until it equals the latest `Archive_Date` in `Wy_Ed_Jobs/allsum.csv` and
    `allsum_he.csv`, reading again for up to 40 minutes while the app wakes or a redeploy finishes. A failure files one
    "Live dashboard check" issue and a pass closes it. Runs after each weekly update (`workflow_run`: the data push
    by the Actions token starts no push workflow), on merges that touch `Wy_Ed_Jobs/`, and daily. Checks the date only: after
    a code-only change a pass shows the page loads with the right data, not that it runs the new code. Suite on 0.86.0: 1,456 passed, 0 failed.
  * [x] Stale board ads flagged, not counted; edjobs pinned at 0.90.0 (2026-11-24; branch `stale-board-rule`;
    bostickmike/edjobs#95; measured in `claude-notes/2026-11-24_stale-ats-ads/README.md`, built in
    `claude-notes/2026-11-24_stale-rule/`). Mike: chose the recommendation (option C, "V1"), for scaling to more states
    and the most complete and accurate data. A board or district-website posting whose posted date, or a stated
    closing date that parses, is before the July 1 that began the previous school year is flagged (`Stale_Reason`)
    and not counted, except standing pools and ongoing roles (bus, para/aide, custodial/maintenance, food service,
    athletic coaches). `flag_stale_k12_rows()` (`misc_district_scrapers.R`, edjobs `flag_stale_board_postings()`)
    runs before `remove_wsba_direct_duplicates()`; a WSBA row that is the same ad as a flagged posting is split off
    with `STALE_FEED_LINK_REASON` (archived, not counted, not page-checked). `combinedclean` and the rebuild use
    `drop_stale_rows()`; spells keep flagged board rows and leave out the WSBA copies. Forward-only (METHODS.md "Old
    board ads"). Replay: 6 of 688 board rows flagged on 11-20 (6 of 674 on 11-24); 1 of them (Carbon #2 OT) is on
    WSBA too. Full rehearsal (11-24, v0.90.0 from
    GitHub): every step passed; the run flagged 6 of 706 board postings and split off 1 WSBA row as the same ad
    (Carbon #2 OT: WSBA dates it 2026-05-11 and links the 2023 AppliTrack job 546); `combinedclean.csv` 718 -> 712
    rows; 0 counted board rows the rule would flag; rebuild parity passed; suites 1,451 passed, 0 failed (pre and post).
  * [x] edjobs pinned at 0.91.0 (2026-11-24; branch `pin-edjobs-0.91.0`; bostickmike/edjobs#96, #97). K-12 Trends tab:
    the counting note is a footnote at the bottom of the tab instead of a box under the multi-year plot, whose date
    axis and legend it covered (both Trends plots are drawn 500px tall; their containers were 400px, now 500px). The
    Current and Multi-Year help popovers say the counts are full teaching positions only. Checked by screenshot of
    both sub-tabs (`claude-notes/2026-11-24_pin-0.91.0/trends-*.png`). Suite on 0.91.0: 1,470 passed, 0 failed.
  * [x] edjobs pinned at 0.93.0 (2026-11-24; branch `pin-edjobs-0.93.0`; bostickmike/edjobs#98, #99). 0.93.0: the
    Trends tabs' multi-year legend sits under the date axis with the title "Category" (the title was clipped to
    "oad_Category" and the last item to "Library"); checked by screenshot (`claude-notes/2026-11-24_trends-legend/`).
    0.92.0's `scrape_registry_platforms()` is in the package but not used here yet (Montana's slice A; Wyoming's is
    A2 in `claude-notes/2026-11-24_step5-measure/README.md`). Suite on 0.93.0: 1,470 passed, 0 failed.
  * [x] Higher-ed boards read by edjobs `scrape_registry_platforms()`; edjobs pinned at 0.95.0 (2026-11-24; branch
    `he-registry-stage`; bostickmike/edjobs#100 = 0.94.0, #101 = 0.95.0; review step 5 slice B2). The higher-ed chunk's
    registry loop becomes one call, one group per registry row in file order (`platforms = NULL`).
    `test-drift-check.R` checks resolved calls instead of reading the Rmd's text. Stub replay
    (`claude-notes/2026-11-24_step5-measure/replay/`): 9 of 9 frames identical, same log order. Full rehearsal on the
    tagged 0.95.0: rebuild parity 11 of 11 files, 0 sources flagged by the drift check; K-12 rows 718 -> 716; higher-ed
    rows 460 -> 459 against the committed file, by college: University of Wyoming 229 -> 227, Casper College 3 -> 4,
    the other seven unchanged. One failure, the pre-run boot smoke (2 plots not drawn): the Mac's display went off
    mid-test (next entry). Post-run suite 1,477 passed, 0 failed.
  * [x] Boot smoke keeps its page visible (2026-11-24; same branch;
    `claude-notes/2026-11-24_legend-load/README.md`). When the Mac's display goes off, Chrome marks the test page hidden
    and stops drawing it, so Shiny never learns that a newly opened tab is visible and renders nothing on it. That is why the
    pre-run suites of two rehearsals failed on a plot (`caffeinate -u` wakes the display, which goes off about 15 s
    later); edjobs 0.93.0's legend is not involved (0.92.0 fails the same way on a quiet Mac). The test now sets
    Chrome's focus emulation and checks on every tab that the page is visible (the "every tab renders" check passed on
    tabs that had rendered nothing). With the display going off mid-run: 41 passed, 2 failed before (0.92.0 and 0.93.0);
    54 passed, 0 failed twice after. Suite with the fix: 1,488 passed, 0 failed.
  * [x] District sites read by edjobs `scrape_registry_platforms()` (2026-11-24; branch `k12-misc-stage`; edjobs 0.95.0,
    no release needed; review step 5 slice A2). `fetch_all_misc_district_postings()` reads the 13 sites in one call,
    each row by its `scraper_spec()`, and then dedupes against WSBA per district as before, so row order is unchanged.
    The hand `switch()` in `fetch_misc_district_postings()`, a second copy of the specs, is gone; each of the 5
    browser-read sites gets its own Chrome session (one shared before, so one crash could stop the rest). Stub replay
    (`claude-notes/2026-11-24_step5-measure/replay/wy_misc_stub_replay.R`): 28 of 28 rows identical, same 14 log rows in
    order, 13 calls (11 identical; the 2 Edlio ones add the skip rule, blank for both). Live run of the step with old and
    new code: 174 of 174 rows identical (99 WSBA). Suite: 1,475 passed, 0 failed.
  * [x] K-12 history files written by edjobs `write_k12_history()`; edjobs pinned at 0.96.0 (2026-11-25 UTC; branch
    `k12-history-tail`; bostickmike/edjobs#102; review step 5 slice C1). The Rmd's hand-written steps after
    `combinedclean` (teacher rows, district and job-type weekly totals, `allsum`, `allnow`) and the same steps in
    `scripts/rebuild_k12_history_from_archive.R` become `write_k12_history()` / `build_k12_history()`.
    `list.csv`, written each run and read by nothing, is gone.
    Replay of the old steps against the new call on the committed files
    (`claude-notes/2026-11-24_step5-measure/replay/k12_history_replay.R`): 5 of 5 files byte-identical, for a same-day
    re-run and for a new run date. Rebuild parity on the branch build: 11 of 11 files. Suite on 0.96.0: 1,475 passed,
    0 failed. No full rehearsal (one step, replayed on real files).
  * [x] Daily presence check reads Wyoming's 21 AppliTrack boards again (2026-11-25 UTC; branch `presence-applitrack`).
    The 11-16 registry change (05bc330) renamed the platform "Applitrack" to "AppliTrack"; `presence.yml` kept the old name, so
    from 11-16 to 11-24 the check read 18 boards a day, not 39, with no error. Nothing on the dashboard reads the check yet.
    Dry run on a copy of the presence files: 39 boards ok, 701 postings; 239 AppliTrack stretches resume and 26 postings left
    sometime in the gap (an AppliTrack ending in those days is known only as a range, for the phase 1 spells). New
    `test-presence-workflow.R` (both states): every platform the workflow names is in the registry; it fails on the old name.
  * [x] Higher-ed stage after the scrapes in edjobs; edjobs pinned at 0.97.0 (2026-11-25 UTC; branch `he-stage`;
    bostickmike/edjobs#103; review step 5 slice D). `combine_he_frames()`, `finish_he_rows()` (placeholders, implausible pay,
    IPEDS staff estimates) and `write_he_history()` replace the hand-written steps; the rebuild script uses the same
    `build_he_history()`. UW's salary book and the map placing stay in the Rmd; the local-only root copy of
    `facultydata.csv` (gitignored) is no longer written.
    Replay on the newest committed archive (`claude-notes/2026-11-24_step5-measure/replay/he_history_replay.R`): combined and
    finished tables identical, 5 of 5 history files byte-identical, for the same date and a new one. Live higher-ed scrape
    (branch build), old and new code on the same frames: combined and finished tables identical (459 rows). Rebuild
    parity (branch build) 11 of 11 files. Suite on 0.97.0: 1,474 passed, 0 failed. Full rehearsal of slices A2, C1 and D
    together on v0.97.0 (11-25 UTC, `replay/rehearsal_wy_d.log`): all steps passed, rebuild parity 11 of 11, suites 1,474 (pre-run) and 1,474 (post-run) passed,
    0 failed. K-12 rows 718 and 718 against the 11-24 run, each source within 1; higher
    ed 459 to 460 (University of Wyoming 229 to 226, Casper 3 to 4, LCCC 66 to 67).
  * [x] Reference and salary stages in edjobs; edjobs pinned at 0.98.0 (2026-11-25 UTC; branch `salary-stage`;
    bostickmike/edjobs#104; review step 5 slice E). `refresh_pay_benchmarks()` (OEWS, QCEW), `refresh_ipeds_staff_pay()`,
    `refresh_ipeds_he_salaries()`, `refresh_ccd_teacher_fte()` and `refresh_data_coverage()` replace the blocks both states wrote
    out; the Rmd goes from 953 to 861 lines. WSBA's salary documents, UW's salary book, the charter staffing and the SAIPE stand-ins stay in the Rmd.
    `salarymap.csv`'s columns change order once (new columns go last); every value is the same.
    Replays with one live fetch fed to old and new code (`claude-notes/2026-11-24_step5-measure/replay/salary_stage_replay.R`,
    `benchmark_stage_replay.R`): every value identical in `salarymap.csv` and `salarymap2.csv`; the three reference files, retrieval
    dates and log rows identical. The edited Rmd chunks run live in a scratch copy (`run_e_chunks.R`): every fetch ok,
    no value changed in either file (one lunch share differs in its 15th digit). Suite on 0.98.0: 1,474 passed, 0 failed. No full rehearsal (each step replayed).
  * [x] Package review step 5 closed (2026-11-25): the pipeline stages are edjobs calls (slices 1-3, A, A2, B, B2, C1, D, E; C2 in
    E). C3, a shared skeleton for reconciling the statewide feed, is not built (Mike, 2026-11-25): MT matches OPI posting by posting, WY drops
    WSBA duplicates and opens the linked pages; revisit with a third state's feed. `claude-notes/2026-11-24_step5-measure/README.md`.
  * [x] Park 16 and Platte 1 on edjobs's SmartSites reader, edjobs pinned at 0.88.0 (2026-11-24; branch
    `smartsites-family`; bostickmike/edjobs#92, #93; `claude-notes/2026-11-24_smartsites-family/` measured it,
    `claude-notes/2026-11-24_smartsites-build/` built it). edjobs `fetch_smartsites_postings(url, location)` reads the
    three SmartSites (ParentSquare) widgets (document list, image gallery, posts) with no per-district rules and keeps
    posted dates; MT's Ekalaka moved onto it the same day. WY's `fetch/parse_smartsites_postings`, its `SmartSites`
    spec line (edjobs's default is used) and 5 tests are deleted; the fixtures are in edjobs. The dispatch arm in
    `fetch_misc_district_postings()` now calls edjobs's reader (no location, as the Edlio arm); the `switch` stops on
    an unknown platform, so the arm stays. Parity: on both fixtures the new reader gives the old parser's rows
    exactly after the orchestrator fills blank links (Park 16 3, Platte 1 12), and on the 11-23 pages (1, 12). Live
    run of the step (11-23 22:44 MST, `fetch_all_misc_district_postings()` cut to the two rows): old and new code give
    the same rows as the 11-20 archive (Park 16 1, Platte 1 12). This pin also brings 0.87.0 (the CSS-board reader;
    no WY source uses it). Full rehearsal (11-23): every step passed except the pre-run suite's boot smoke, which ran
    alongside an MT suite (1,442 passed, 1 failed; that file alone in the same copy: 24 passed, 0 failed); post-run
    suite 1,443 passed, 0 failed; Park 16 1 row, Platte 1 12 (`claude-notes/2026-11-24_smartsites-build/rehearsal_wy.log`).
    The committed pin files match the rehearsed copy (manifest: same edjobs entry, the rest is the Mac's `writeManifest`
    rewrite).
  * [x] App boot smoke test waits for what it checks (2026-11-24; branch `boot-smoke-wait`;
    `claude-notes/2026-11-24_boot-smoke/README.md`; same change in MT). `test-app-boot-smoke.R` failed when a suite or a
    render ran beside it and passed alone. Causes: `AppDriver$new()` loads the first page on chromote's 10 s command
    timeout, which `load_timeout` doesn't cover (a starved app server fails the boot at exactly 10 s, "timed out waiting
    for response to command Page.navigate"); `set_inputs()` gives up silently after 30 s without an output change; each
    widget was read after a fixed `wait_for_idle()`. Now every wait is for its condition, bounded by
    `BOOT_SMOKE_TIMEOUT_S` (default 120): the server's `sidebar_tabs` equals the tab, Shiny idle 1 s, the widget's HTML
    matches before it is read; chromote's timeout is raised for the boot. The longitudinal-plot check had passed on
    the empty container since the plot moved to the Trends card's Historical tab (11-21): the test now opens that tab
    and requires `js-plotly-plot|main-svg`. The popup test starts from Home. Proof: with the app server paused 15 s
    after it starts listening, then 2.5 s of every 4 s, the old file failed 4 of 4 runs per state at boot; the new one
    passed 5 of 5 per state (43 expectations each). Alone it takes about 30 s instead of 57 s. Suite on 0.89.0:
    1,462 passed, 0 failed.

  * [x] Documentation review (2026-11-23; branches `docs-facts`, `docs-methods`; `claude-notes/2026-11-23_docs-review/`;
    Mike's call: split roles). README: real tabs, UW's careers site and WDE602 among the sources, what blocks vs only
    reports. Data dictionary: Data tab name; teaching / faculty-only files; days listed is not time to fill; runs,
    not weeks; now every shipped file (71 rows, 12 files; college estimates are IPEDS staff averages or the UW
    salary book, `Est_Source`), and `test-data-dictionary.R` fails on any undocumented file in `Wy_Ed_Jobs/`.
    `DATA_COOKBOOK.md` (headed "SUPERSEDED", untested) becomes `METHODS.md`, for a data user, sources linked; its
    engineering notes stay in git history. Same in MT.

  * [x] Dashboard text corrected (2026-11-23; branch `app-text-facts`; `claude-notes/2026-11-23_docs-review/app-text/`).
    Partial badge: "WSBA reliably captures only ~25-40% of real openings" had no source (cut); it now says a Partial
    district's postings come from its own site and WSBA, or WSBA only, and either can miss openings. Downloads: the
    K-12 history is teaching postings only; the HE archive is faculty and adjuncts, no staff; weekly totals are
    postings, not vacancies. Provenance: twice weekly; the real platform list; WSBA salaries "across all 48
    districts" -> computed (47 with a starting base). METHODS.md: the Listing Duration tab shows first-to-last
    sightings; the posting spells are built but not on the dashboard yet.
  * [x] README read against the running app and the registry (2026-11-23; branch `docs-readme`): Home lists what it
    shows (no "biggest movers" or vacancy-rate leaderboards); app.R's one Wyoming-only server block named (WDE staff
    download); archives are one snapshot per update (weekly before 11-17); the UW repair script in plain words;
    "update", not "run" or "week".
  * [x] `scripts/reclassify_committed_data.R` sees every edjobs change (2026-11-22; branch
    `reclassify-sees-all-edjobs`; both states). Its rebuild runs in the installed edjobs's namespace, so sourcing the
    checkout's classifier file reached nothing inside the package, and 0.81.0's feed titles (`R/k12_history.R`) came
    out "nothing to write". Now the guard requires the pinned tag installed (it stops and says so otherwise), and when
    the checkout's `R/` differs from the tag, steps 2-3 rerun in a child process with the checkout installed in a
    temporary library (the spell builders inherit it). Tested on MT (same script) at the 0.80.0 commit with 0.80.0 installed:
    guard passes, then the same moves as the manual restatement, and `--apply` writes the five files byte for byte
    as committed in `bump-edjobs-0.81.0`; with 0.81.0 installed the guard stops. WY: no-change path, nothing to write.
  * [x] edjobs pinned at 0.89.0 (2026-11-24; branch `pin-edjobs-0.89.0`; bostickmike/edjobs#94). A platform's
    `scraper_spec()` can name its parser (`parse_fn`); the auto-fix evidence finds a source's fixtures from the tests of
    the fetch function and that parser. Before, the parser was guessed as the fetch function's `parse_*` twin, which for
    CSS boards (`fetch_css_board_postings()` -> `parse_css_board()`) named no function. Named in edjobs for CSS boards,
    AppliTrack, SchoolSpring, Red Rover, NEOGOV and Trakstar. Also syncs the vendored `jobs-dash-scraper` skill (CSS-board
    rules; SmartSites is an edjobs family). Suite on 0.89.0: 1,443 passed, 0 failed.
  * [x] edjobs pinned at 0.99.0 (2026-11-25; branch `pin-edjobs-0.99.0`; bostickmike/edjobs#105; package review step 8). Text
    boards (a job page read by rules on its lines of text) and two CSS-board columns, used by MT; nothing in WY uses them
    yet: WY's own-page readers are distinct widgets and rendered pages (`claude-notes/2026-11-25_step8-tail/README.md`).
    "$16.97 per hour to $20.04 per hour" is read as a range from the next run. Suite on 0.99.0: 1,476 passed, 0 failed.
  * [x] Pay the districts' own pages state is kept (2026-11-25; branch `own-page-pay`;
    `claude-notes/2026-11-25_step8-tail/README.md`). `fetch_all_misc_district_postings()` rebuilt each own-page row without
    the pay columns, so none of the 75 in the 11-24 archive had pay. Now carried through, and read from each posting's
    own line (Google Sites, Uinta 6) or cell (Educational Networks, Cheyenne Classical). Full rehearsal: 4 own-page rows
    with pay (Uinta 6 three, Cheyenne Classical one), the same own-page rows per source as the 11-24 archive; every step
    passed but `manifest`, which failed only because the rehearsal used a locally installed edjobs 0.99.0
    (`rehearsal_wy.log`). Weston 7's tiered substitute day rates are not read.
  * [x] `WordPressBespoke` retired (2026-11-25; branch `retire-wordpress-bespoke`; listed as dead code on 11-21). No
    registry row uses it (Lincoln County SD2 moved to SchoolSpring 10-20) and no archive row has its label: the two
    functions, the spec, the label, 2 test blocks and the fixture are gone.
  * [x] Places for postings that had none; WSBA's misnamed towns corrected; edjobs pinned at 0.100.0 (2026-11-26; branch
    `wy-locations`; bostickmike/edjobs#106; Mike chose all four steps; `claude-notes/2026-11-26_wy-location/README.md`).
    125 of 718 rows (11-24) had no place. WSBA's town was checked: 81 of 86 of today's WSBA rows give a town where the
    district has a school (CCD 2023), and 17 of 17 that link a school's board posting give that school's town; it was
    wrong for Laramie County SD 1 ("Laramie"; its schools are in Cheyenne) and Carbon 2 ("CCSD#2"). Now: WSBA's town is
    kept for the own-page districts' WSBA rows (17 rows were blank); a WSBA town that is none of the district's becomes its
    office town (3 rows); a row with no place takes the district's town when all its schools are in one town (84 rows, from
    `Wy_Ed_Jobs/district_towns.csv`, CCD 2024, refreshed each run). 24 rows in districts with schools in several towns stay
    blank. Full rehearsal: 85 filled, 3 corrected, 24 blank (the several-town districts); every step passed except the
    pre-run and post-run suites (a test calling an unexported edjobs helper, and the new file missing from the data
    dictionary: both fixed, then the suite passed 1,487/0 on the branch and 1,488/0 on the rehearsal's output) and
    `manifest` (a locally installed edjobs). The place is part of the "new this week" key, so the next update shows 12
    teacher postings as new that only gained a place (a normal week shows 0-4). A pairing rule for that (a gone row with
    the same title and district and no place) was measured, not built: it would also have paired 2 past WY and 7 MT
    postings. Mike 11-26: skip it (a one-time effect of the fill). Listing durations bridge by title.

**Open work (moved here from claude-notes handoff, 2026-11-03; this list is the source of truth):**
- [x] Run expectation `wsba_schoolspring_counted_once` (2026-12-01 to 12-15): no WSBA row whose SchoolSpring job number
  is a SchoolSpring board posting (the six pairs counted twice in the 11-27 data). Measured with
  `measure_expectation()`: 6 on main's 11-27 `combinedclean.csv`, 0 on the 11-28 rehearsal's; validates (34 rows).
- [x] Registry reads through edjobs (Utah phase 0, gap 4; branch `registry-reader`; edjobs 0.113.0): WY's own
  `read_k12_registry()` / `read_he_registry()` deleted from `state_config.R` (same names as the edjobs exports, so they
  would mask them), and the Rmd's two plain `read.csv()` registry reads go through the package. Pin 0.113.0 (from
  0.111.0; 0.112.0 CCD id padding / NEOGOV links). Before/after replay of every registry consumer (installed 0.110.0
  on main vs 0.113.0 on the branch, separate processes): `k12_static_columns()`, `refresh_he_static_columns()`,
  `he_institution_urls`, the id map and every source's `resolve_scraper_call()` identical; the registry tables,
  `read_direct_board_registry()` and `misc_district_rows()` differ only in all-blank `City` / `Location_Pattern`
  (logical NA -> ""), equal as text. Rehearsed 2026-11-28 (`claude-notes/logs/2026-11-28_rehearsal-wy-registry-reader-0.113.0.log`):
  every step ok, rebuild parity 11 of 11, pre- and post-run suites 1502 passed, 0 failed; recent-postings files hold
  2026-11-20 and 2026-11-28 (K-12 735 + 714, college 463 + 460). Sources as on 11-27 except WSBA 50 -> 44: the six
  SchoolSpring pairs `data_audit.R` listed (0.109.0's link-ID fix) now count once. Still twice: Laramie Montessori's
  school counselor (Paylocity + WSBA), because the WSBA dedupe compares only the direct-board platforms; separate fix.
- [x] Built with edjobs (branch `pin-edjobs-0.111.0`; edjobs 0.111.0). The data-sources footer, on every tab, ends
  with `built_with_edjobs()` ("Built with edjobs, an open-source R package for tracking education job postings",
  linking to the package on GitHub), and the Data tab invites anyone wanting a dashboard for another state to start
  from the package. Text only, no rehearsal: the app booted on 0.111.0 and both lines were checked in it. Pinned
  edjobs 0.111.0 (`EDJOBS_VERSION`, weekly workflow ref, manifest edjobs entry and app.R checksum by hand). Tests on
  0.111.0: 1448 passed, 0 failed.
- [x] New This Week covers every role (full review 2026-11-27, finding 1.6; Mike's call; branch
  `new-this-week-all-roles`; edjobs 0.107.0). It compared the teaching/faculty histories, so the Jobs tabs' button on an
  all-roles table dropped every new support, para, coach and staff posting, and the map's and summary tables' "New
  This Week" counted teachers and faculty only. The pipeline now keeps `k12_recent_postings.csv` /
  `he_recent_postings.csv` (every role, last two weeks; edjobs `write_k12_history()` / `write_he_history()`); app.R
  reads them (rule A unchanged; college rule now edjobs `find_he_new_postings()`), with the old histories as the
  fallback. Seeded from git history (`claude-notes/2026-11-27_full-review/seed_recent_postings.R`). This week: K-12
  14 -> 106 new (106 of 720 in the Jobs table), college 0 -> 17 (of 460), checked in the running app.
  Data dictionary updated. App/dictionary/data tests on 0.107.0: 671 passed, 0 failed. Pinned edjobs 0.110.0
  (`Pin edjobs 0.110.0`); rehearsed 2026-11-27 (`claude-notes/logs/2026-11-27_rehearsal-wy-pin-0.110.0.log`): every
  step ok, rebuild parity 11 of 11 files, post-run suite 1502 passed, 0 failed; the recent-postings files hold
  2026-11-20 and 2026-11-27 (K-12 735 + 714 rows, college 463 + 460).
- [x] Listing Duration: days listed end halfway to the next update, not +7 (full review 2026-11-27, finding 2.4;
  Mike's call; branch `durations-midpoint`). The flat 7 days assumed weekly updates (twice a week since 11-17); now a
  gone posting's listing runs to the midpoint between its last sighting and the next update, as the posting spells
  end one, and a still-listed posting gets nothing added. `job_duration_spells.csv` / `he_job_duration_spells.csv`
  regenerated (only `Estimated_Days_Open` changes): ended-listing median K-12 28 -> 25, college 77 -> 74 days. METHODS.md and
  the dictionary updated; the tab text changes with edjobs 0.110.0. Tests: 285 passed, 0 failed.
- [x] `test-data-dictionary.R`'s `pending` list emptied (full review 2026-11-27, finding 3.3; branch
  `review-dictionary-pending`): every listed column (SAIPE range, ACS MOEs, CCD/IPEDS links) is in the committed files,
  so dropping one now fails the test. Tests: 171 passed, 0 failed.
- [x] Docs for the 11-26 changes (branch `docs-place-and-wsba`): METHODS.md gains "Where a K-12 posting is placed"
  (the CCD-town fill and the WSBA-town correction, from the 11-27 update; on the 11-24 postings 84 filled, 3 corrected,
  24 left blank; a filled posting counts once as new); DATA_DICTIONARY.md and `data_dictionary.csv` describe the fill
  on both `location` columns; CLAUDE.md names `fill_k12_locations()` and `wsba_feed_rows()`.
- [x] WSBA rows picked out by their source label in the weekly run (Mike, 2026-11-26, option A; branch
  `is-wsba-by-label`; `claude-notes/2026-11-26_is-wsba/`). The Rmd's `is_wsba` keyed on the district having a direct
  board, so WSBA rows at districts with none (Platte #1, Niobrara #1, Park #16, Weston #1 and #7, STRIDE, the
  Sweetwater CDC, ...) were treated as board rows: judged by the stale-ad date rule, though the comments and the
  rebuild (`wy_archive_stale_flags()`, by `Posting_Source`) don't. Now `wsba_feed_rows()` (`misc_district_scrapers.R`)
  uses the same rule as the rebuild: the WSBA label or the vacancies-page link. No output changes: on the archives 31,
  35 and 32 rows moved (11-13/11-20/11-24), oldest posted 2026-03-12, none before the 2025-07-01 cutoff, none with a
  page the closed-posting check reads. Live run of the WSBA + district-page step (11-26): 174 rows, 99 WSBA, 32 move;
  stale flags 0 under both rules, 1 WSBA copy split off under both, 137 rows out of the step under both; a second run (three district pages timed
  out, same 99 WSBA rows) matched again, and 37 direct postings are "also on WSBA" under both. Without it the
  live run and the rebuild would disagree from July 2027 on, when these rows can first be old. Suite 1,493 passed, 0 failed (with the boot smoke).
- [x] Stale board ads: history restated under the rule (Mike, 2026-11-26; branch `stale-restate`; edjobs 0.104.0,
  bostickmike/edjobs#110; `claude-notes/2026-11-26_stale-restate/`). Was forward-only: the weeks before the rule still
  counted the old ads, so the totals would have stepped down once when it began. Now `wy_archive_stale_flags()`
  (`history_accumulator.R`, edjobs `stale_flags_for_archive()`) gives an archive written before the rule its flags,
  judged with that run's own date (WSBA rows not judged; none of the flagged rows in any archive is a WSBA row); the
  rebuild and `test-history-accumulator.R` read through it, and the history files were rebuilt once from all 126
  archives: every week 3 to 28 postings lower, Teacher 0 to 10 lower (264 of the 291 teaching row-weeks out are Fremont
  County SD 38's 2023-24 ads), the current 11-24 snapshot 718 -> 712; `job_duration_spells.csv` regenerated (1,909 ->
  1,905). METHODS.md "Old board ads", DATA_DICTIONARY.md, the K-12 Trends note and CLAUDE.md updated; run expectation
  `stale_history_restated` for 11-27. Suite 1,487 passed, 0 failed; rebuild parity 11 of 11. Found while building: the
  live `is_wsba` (direct-board district, or the WSBA page link) leaves WSBA rows at districts with no direct board
  (Platte, Niobrara, Park 16) to be judged by their dates like board rows, though the comments say WSBA rows aren't;
  none of the 98 such rows on 11-13/11-20/11-24 (31, 35, 32; the 148 first written here was every WSBA row) would be
  flagged, so nothing changes yet (fixed 11-26, entry above). Full rehearsal (11-26, edjobs 0.104.0):
  every step passed, suites 1,487 / 1,488 passed, 0 failed; the render flagged 6 of 711 board postings and 1 WSBA copy;
  rebuild parity held after the live run; every run expectation passed on its output with RUN_DATE 2026-11-27.
- [ ] **Later (Mike 11-16, parked): a way for someone sending feedback to get a reply.** An email can't go in the
  report: it becomes a public issue (edit history keeps it). Options: (A) a "want a reply? email ..." line with a
  separate address, recommended; (B) an optional field whose address the app emails to Mike privately via a mail
  service (new account and secret; the form then needs a note on how the address is used); (C) the address
  encrypted in the issue (ruled out: clumsy).
- [ ] **Citations audit follow-ups (2026-11-15; `claude-notes/2026-11-15_citations-audit.md`), decisions for Mike:**
  BLS asks for the access date (apps don't know it yet); WSBA/WDE pages say "All rights reserved" with no reuse
  terms. (Esri basemaps: done, replaced 11-15.)
- [ ] **R package migration (current focus, Mike 2026-11-10):** shared code moves to `bostickmike/edjobs`, pinned in
  `EDJOBS_VERSION` (plan and status: `claude-notes/2026-11-10_r-package-migration-plan.md`). Phase 0 merged 11-11
  (run expectations; edjobs 0.0.1). Phase 1 merged 11-11 (edjobs v0.2.0: scrape helpers, posting status, coverage
  calendar, BLS OEWS, BLS QCEW, LLM extraction; MT PR #16, WY PR #8; full rehearsal in both states, WY test dispatch
  on the branch passed). Phase 2 on branch `edjobs-phase2` (11-11, edjobs v0.4.0): the classifier and posted pay, IPEDS staff salaries,
  41 shared drift/data-quality/auto-fix definitions, `check_file_schema()`, `check_total_matches_parts()`,
  `rebuild_parity_row()`; this repo keeps its name corrections, posting identity, dispatch, baselines and schemas.
  Suites on 0.4.0: WY 1,600 passed, 0 failed; full rehearsal passed every step, rebuild parity 9/9
  (`claude-notes/2026-11-11_rehearsal-wy-edjobs-phase2.log`). Phase 2 merged 11-11 (WY PR #14 -> 51de3e1).
  Phase 3 on branch `edjobs-phase3` (11-11, edjobs v0.5.0): the shared platform scrapers (AppliTrack fetch/parse,
  SchoolSpring details and ending reasons, PeopleAdmin page pay and dates, NEOGOV card pay). Auto-fix for a scraper
  that lives in edjobs: Copilot first on a companion edjobs issue, then the Claude fallback, which checks edjobs out
  in `.edjobs/` and opens its PR there. Suite on 0.5.0: WY 1,504 passed, 0 failed; full rehearsal passed every
  step, rebuild parity 9/9 (`claude-notes/2026-11-11_rehearsal-wy-edjobs-phase3.log`). Design rule from 11-11: build
  for N states and one stackable schema (plan section 2a).
  Phase 4, first slice, on branch `edjobs-phase4-spells` (11-11, edjobs v0.6.0): the posting-spells engine
  (bridging, endings, starts, flags, durations, first-seen lookup) moved to edjobs; this repo keeps its panels
  and its rules (`WY_SPELL_RULES` in `posting_spells.R`, a `spell_rules()` object). Rebuilt from the archives, every
  pre-existing column of the committed spells is unchanged (11,834 K-12 + 3,621 HE postings); the files gain the shared
  36-column schema (`POSTING_SPELL_COLUMNS`). Suite on 0.6.0: WY 1,435 passed, 0 failed.
  Phase 4 slice 1 merged 11-11 (WY PR #16 -> 0c67509). Slice 2 on branch `edjobs-phase4-state-config` (edjobs
  v0.7.0): `state_config.R` sets `edjobs::state_config()` (name, FIPS, app folder, this state's own reference
  tables, which left the package's `REFERENCE_TABLE_RULES`); OEWS areas are a FIPS-keyed CSV in the package.
  Suite on 0.7.0: WY 1,439 passed, 0 failed; full rehearsal passed every step, rebuild parity 9/9
  (`claude-notes/2026-11-11_rehearsal-wy-edjobs-phase4.log`).
  Slice 2 merged 11-11 (WY PR #17 -> a59accd). Slice 3 (edjobs v0.8.0): the drift-check functions MT and WY held
  differently, except dispatch and the auto-fix issue body, come from the package (`flag_drift`,
  `build_historical_counts`, the drift report, the live-check summary); `state_config.R` gains the WSBA feed's
  labels and the drift baseline date. `check_drift.R` output on committed data is identical. Suite on 0.8.0:
  WY 1,425 passed, 0 failed (1,423 after the rehearsal's run); full rehearsal passed every step, rebuild parity 9/9
  (`claude-notes/2026-11-12_rehearsal-wy-edjobs-0.8.0.log`).
  Slice 3 merged 11-12. Slice 4 (edjobs v0.9.0): scraper dispatch and the auto-fix issue body come from the
  package (`resolve_scraper_call(name)`, `run_scraper_call()`, `gather_autofix_evidence()`,
  `build_autofix_issue_body()`, `build_source_url_lookup()`); this state's sources and how each is scraped are
  data in `state_config.R` (`scraper_sources`, `autofix`). On all 67 source names the resolved call, its description and
  the evidence are identical to the local code's; the issue body changes only in wording. The URL lookup gains the WSBA feed's page.
  Suite on 0.9.0: WY 1,415 passed, 0 failed (1,413 after the rehearsal's run); full rehearsal passed every step,
  rebuild parity 9/9 (`claude-notes/2026-11-12_rehearsal-wy-edjobs-0.9.0.log`). Not exercised by a rehearsal:
  `file_autofix_issues.R` and `live_check_autofix.R` (GitHub-only steps); `scripts/repro_scraper.R` was run live.
  Slice 4 merged 11-12. Slice 5 (edjobs v0.10.0): the accumulated K-12 history comes from the package
  (`build_k12_combinedclean()`, `build_k12_teacher_rows()`, `append_weekly_rows()`,
  `summarize_k12_posting_counts()`), with one output schema for every state (`edjobs::K12_POSTING_COLUMNS`).
  `combinedclean.csv` and `k12jobanalysis.csv` were rewritten from the archives in the shared columns, same row order, every existing cell unchanged (725 and 13,406 rows): `posting_id` is now `Posting_ID`, `Posting_Identity_Method` is derived from the id, and `Posting_Source`, `Feed_District`, `Also_On_Feed`, `Role_Hint` are NA until Wyoming records them (open: define WY's `Posting_Source`). Outside readers of the downloads must use `Posting_ID`.
  Raw rows and the weekly archives keep their column names; posting id values are untouched. Suite on 0.10.0:
  WY 1,403 passed, 0 failed (1,401 after the rehearsal's run); full rehearsal passed every step, rebuild parity 9/9
  (`claude-notes/2026-11-12_rehearsal-wy-edjobs-0.10.0.log`). Design and open items:
  `claude-notes/2026-11-12_phase4-k12-output-schema.md`.
  Slice 5 merged 11-12 (PR #20 -> 9659bf0). Then the source columns (Mike 11-12: backfill what is feasible, NA
  for the rest, record it going forward): every K-12 row is tagged with `Posting_Source` at scrape time and
  archived with it; `Also_On_Feed` flags a direct posting WSBA also lists (`direct_also_on_wsba()`);
  `Feed_District` is the organization WSBA names. History is backfilled where the archived row settles the source
  (`backfill_k12_posting_source()`: the source id, WSBA's own link, and the link's host for every run before
  2026-08-02, when WSBA was first read): `k12jobanalysis.csv` 12,705 of 13,406 rows, `combinedclean.csv` 532 of
  725; every other cell unchanged. `Role_Hint` stays NA: WSBA titles carry the role and WSBA has no description
  (checked 11-12). Suite 1,430 passed, 0 failed (1,428 after the rehearsal's run); full rehearsal passed every
  step, rebuild parity 9/9; the rehearsed run tagged all 699 rows, 39 of them also on WSBA
  (`claude-notes/2026-11-12_rehearsal-wy-posting-source.log`).
  Slice 6 (edjobs 0.11.0, PR #9 there; WY PR #22, branch `edjobs-platform-fetchers`, 11-12): the platform fetchers
  come from the package (`fetch_neogov_postings()`, `fetch_peopleadmin_atom()`, `fetch_schoolspring_postings()`,
  `fetch_tedk12_postings()`, `schoolspring_domain()`); local copies, tests and fixtures deleted (three NEOGOV
  card-pay tests moved). NEOGOV is one platform keyed by the agency slug (Mike's decision after the 11-12
  measurement: every posting only an Attract site listed had expired; `claude-notes/2026-11-12_neogov-decision-research.md`),
  and each posting's page gives its exact posted date and closing date: the four NEOGOV colleges' `Posted_Date`
  is a date, not "Posted 2 weeks ago", and `Close_Date` reaches `hedata.xlsx` (Casper states closing dates; the
  others are continuous). PeopleAdmin keeps the campus name as Location (`location_from_author = FALSE`; all
  four feeds carry departments as authors, a one-argument switch if wanted). Suite on 0.11.0: 1,351 passed,
  4 failed (one test whose needle dropped argument names; fixed, reran green); full rehearsal passed every step,
  rebuild parity 9/9 (`claude-notes/2026-11-12_rehearsal-wy-edjobs-0.11.0.log`): 97 NEOGOV rows, 97 exact posted
  dates, 0 relative, 5 closing dates, posted pay on 74. Three `run_expectations.csv` rows for the 11-13 run.
  Review fixes before release (edjobs 579d632, `claude-notes/2026-11-12_review-edjobs-0.11.0.md`): NEOGOV cards'
  Location and date read per card, a warning when a board returns no Locations, and a JSON-LD reader that takes
  schema.org's text forms and catches errors per page. Re-rehearsed: every step passed, parity 9/9, suite
  1,379/0 (`claude-notes/2026-11-12_rehearsal-wy-edjobs-0.11.0-fixes.log`); NEOGOV rows Casper 6, CWC 12,
  Gillette 20, LCCC 59. PR checks pass once edjobs v0.11.0 is tagged.
- [ ] Weston County SD 7 (decision needed): 36 students per teacher on the dashboard. CCD's enrollment grew from
  222 (2020) to 859 (2024), almost all at Upton Elementary (96 -> 574 with 7 teachers), no school flagged virtual:
  likely an online or home-based program counted under Upton's schools (found by `tools/reference_audit.R`, 11-09).
  Options: a footnote on its row/popup, hide its students-per-teacher figure, or leave it.
- [x] After the 2026-11-13 run writes them: remove `pending`'s salarymap2.csv entries in
  `tests/testthat/test-data-dictionary.R` (Child_Poverty_Basis, Free_Reduced_Lunch_Share, FRL_Schools_Reporting,
  FRL_Year). They were documented before any run wrote them, and the blocking pre-run suite would have stopped that
  run (found by the MT rehearsal, 2026-11-09). Done 2026-11-13: run 43462550744 (a4801fa) wrote all four;
  `pending` is now empty; test file passes (56).
- [x] `posting_status_checked` run expectation widened 15-60 -> 20-120 (2026-11-13). The 11-13 run checked 75 pages
  (64 postings dropped since 11-06 + 11 WSBA rows; 71 closed, 4 unknown: Gillette 3, LCCC 1, NEOGOV pages with no
  closing date). Not a bug: same NEOGOV link format in both archives, and only 2 of the 64 have a same-titled listing
  still up (both pages closed: relistings). The 15-60 guess predates K-12 archives carrying AppliTrack per-posting
  links (from 10-30: checkable K-12 links ~45 -> ~370); dropped checkable postings per week were 16-48 before, 48 and
  75 since. Evaluated on the 11-13 file: passes.
- [x] HE salarymap.csv keeps its enrollment-trend and Pell columns when their fetches fail (2026-11-13). The IPEDS
  salary chunk rewrote salarymap.csv with only its static columns, and the later chunks add theirs back only on a
  successful fetch: in the first 0.12.0 rehearsal both got HTTP 524 from Urban Institute, so Enrollment_Change_Pct,
  Pell_Recipient_Share and Pell_Year were lost and the schema check stopped the run. Now the chunk keeps every
  column and replaces only its own (as MT). Simulated on the committed file (salary fetch ok, the rest failing):
  25 columns, values identical. Re-rehearsal on 0.12.0: all steps passed
  (`claude-notes/2026-11-13_rehearsal-wy-edjobs-0.12.0.log`; the failed one is `...-run1.log`).
- [ ] Real posting dates, what's left (`claude-notes/2026-11-03_posting-dates-plan.md`): daily presence check for
  day-precision ends (spells, coverage calendar and page-confirmed closings are done; plan
  `claude-notes/2026-11-09_daily-presence-check-plan.md`). Phase 0 built 2026-11-13 (all 38 districts plus
  WSBA's statewide list, edjobs 0.15.0; runs daily once the PR merges): the audit after two weeks, then phase 1 (the
  spells read the sightings).
- [ ] What the paused Listing Duration tabs show (both states; spells and durations now rebuilt weekly).
  Update (Mike, 2026-11-14): no "paused" banner: the tabs show the current table with one footnote at the
  bottom; the duration KPI boxes and charts stay out until the checks below. For when this resumes (Mike): a way to
  filter out standing postings that are nearly always listed (adjunct pools and the like).
  Decision (Mike, 2026-11-09): the tabs stay paused until we are sure the data is accurate. Proposed checks
  (not yet agreed): (a) about 4 weekly runs after the 11-09/10 pushes (relistings censored, first-seen fallback,
  page-confirmed closings) with no processing change that moves the medians by more than a few days (the OPI
  dedup alone moved MT K-12 from 63 to 28 days; censoring relistings moved MT HE from 21.5 to 31.5); (b) the spells
  trust audit (`claude-notes/2026-11-02_spells-trust-audit.md`) re-run on that data, with few endings left that a
  known data artifact explains (68% on 11-02); (c) the OPI matcher check against fresh OPI data done.
  WY (b) done 2026-11-10 on the 11-06 run's spells (`claude-notes/2026-11-10_wy-posting-spells-audit.md`): likely
  artifacts K-12 241 of 7,680 endings in durations (3.1%; median 26.5 -> 27.5 days with them censored), HE 7 of 2,661
  (0.3%; 59.5 unchanged); widest reading, re-advertised postings included, K-12 750 (9.8%, 31.5 days). Found: a
  re-titled ad (same board + posted date) reads as an ending (209); `relisted_next_run()` keys on the exact title,
  so punctuation edits escape it (41; MT same); `fix_title_encoding()` misses hex entities (`&#x27;`, both states).
  Status 2026-11-26 (`claude-notes/2026-11-26_duration-checks/README.md`): (a) clean since 11-17, the last processing change
  ("split posting spells at gaps", which took WY HE 59.5 -> 52.5 and MT K-12 25.5 -> 29); today's code on older archives
  reproduces the medians committed then, so later moves are data (MT HE 32.5 -> 36.5 on 11-23); ~4 weeks puts (a) at
  ~12-15. (b) preview on the pipeline's panels: endings with any artifact sign MT K-12 8.0%, MT HE 3.2%, WY K-12 6.7%,
  WY HE 0.7% (ceilings; 68% on 11-02); rerun at (a)'s date. (c) done 11-10.
- [ ] Classification safeguards (`claude-notes/2026-11-01_classification-safeguards-proposal.md`): 3, 5, 6, 7, 8,
  9, 10, 11, 12, 13 done; 2 measured, no effect, not built; 1 has a small ceiling (Other is 1.6% MT, 0.1% WY), suggest
  parking (`claude-notes/2026-11-08_classifier-items-1-2-measured.md`). Golden set 551 of 551, no known misses (2026-11-09:
  the 2 file-name titles fixed; "COMMUNICATIONS COORD." was already relabeled in 3389731). Left: 4. ("Activities/Extracurricular" confirmed in the 2026-11-06 data: 7.)
- [ ] WSBA vs district-page near-duplicates left (exact key match only, on purpose): Weston #1 "Head Middle School
  Girls Soccer Coach" / "MS Head Girls Soccer Coach" (word order; a word-order-blind key would merge "Assistant
  Teacher" with "Teacher Assistant"); Park #16 "K-12 School Guidance Counselor" / "School Guidance Counselor" (subset).
  Not duplicates: Platte #1's WSBA substitute rows (Glendo and Wheatland).
- [ ] Using the twice-weekly runs and the daily presence check on the dashboard (Mike, 2026-11-18). Every run is
  stored (`Archive_Date`; two a week, Tue + Fri, first Fri 2026-11-20); the app rolls the history up to each ISO week's last
  run (`latest_snapshot_per_week()`), so the history charts stay weekly while the current counts read the newest run.
  The presence check writes `presence_sightings.csv` (one row per posting: `First_Day`, `Last_Day`, `Days_Seen`) on
  the `presence` branch; nothing on the dashboard reads it yet.
  **Check ~2026-01-15 (about 8 weeks of twice-weekly runs):** do the two runs in a week differ by more than noise (new
  postings, endings, totals, by day of week)? If not, the history charts could plot every run on a date axis (back to
  the first twice-weekly run; nothing is lost by waiting). If there is a day-of-week pattern, keep one point a week.
  Either way, re-measure the drift thresholds (tuned on weekly counts) before any run-level chart.
  Ideas, not decided (each measured on the archives before building):
  Twice-weekly runs: (1) listing durations to within 3-4 days instead of 7 (the spells already end per run);
  (2) short-lived postings: postings seen in one run only, which weekly scrapes missed, by job type (fast fills or
  quick withdrawals); (3) when districts post: new postings by day of week and by month (a hiring calendar);
  (4) the weekly roll-up takes the week's most complete run instead of its last, so one failed run doesn't cost the
  week; (5) a broken board noticed in 3-4 days instead of 7.
  Daily presence (after the phase-0 audit ~11-27 and phase 1): (6) day-precision listing durations (planned: the
  spells read the sightings); (7) a "Last seen on its board" date in the Jobs table, and postings gone between scrapes
  hidden, so "open" means a candidate can still apply today; (8) closed early: postings that left the board before
  their stated closing date, by job type; (9) days open so far for current postings, and the longest-open ones by job
  type and district (a hard-to-fill signal; relistings censored, not linked); (10) board health: a board the daily
  check can't read flagged within a day.

- [x] WSBA parser reads en and em dashes (2026-11-14; 9b63a53). `parse_wsba_vacancies()` matched only a hyphen
  between title, district and town; in Mar-Jun 2024 WSBA typed many listings with en dashes, and those were skipped
  silently (71 of 245 on the 2024-03-01 Internet Archive copy; found while parsing WSBA's archived pages,
  `claude-notes/2026-11-14_wy-history/README.md`). Live page 2026-11-14: 95 rows before and after, identical. Archived
  2024-26 copies: 5,059 -> 5,605 rows (2024-03-01 141 -> 245). New test from real 2024 lines; suite 1,355 passed,
  0 failed (edjobs 0.17.0).
