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
| **Federal NCES LEA IDs** | Embedded (48/48) | Embedded (188/188) | **Full Parity** | 7-digit `NCES_LEAID` in registry, `salarymap2.csv`, and `job_duration_spells.csv`. |
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
