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
**Open work (moved here from claude-notes handoff, 2026-11-03; this list is the source of truth):**
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
