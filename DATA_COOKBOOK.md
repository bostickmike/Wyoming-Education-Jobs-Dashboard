# Data Cookbook

Every dataset the pipeline (`Wy_ED_Jobs.Rmd`) produces and ships to `Wy_Ed_Jobs/`, where `Wy_Ed_Jobs/app.R` reads it. All of these except `combinedclean.csv`, `hedata.xlsx`, `allnow.csv`, and `allnow_he.csv` are **accumulated, growing datasets** — each weekly run appends that week's newly classified rows onto what's already there (see `history_accumulator.R`), rather than rebuilding from scratch. `schema_check.R`'s `REQUIRED_SCHEMAS` is the enforced, tested version of the column lists below — if this document and that list ever disagree, trust the code and open an issue.

---

## K-12

### `combinedclean.csv` — current K-12 postings (this week only)

One row per open K-12 posting, all position types (not just teachers). Powers the K-12 Jobs Table and the map's current-openings counts. Rebuilt fresh every run — **not** an accumulated file.

| Column | Type | Notes |
|---|---|---|
| `title` | text | Job title as posted. Passed through `fix_title_encoding()` at ingestion, so a Windows-1252 byte from a non-Applitrack source won't display as mojibake. |
| `Archive_Date` | date | The date this snapshot was scraped. |
| `date_posted` | text | Original posted-date text, format varies by source platform. |
| `position` | text | Coarse bucket from `classify_k12_position()` (Teacher, Support Services, Administration, etc. — see `k12_he_classification.R` for the full list). |
| `location` | text | School/site name or district office, as scraped — format varies a lot by source platform. |
| `url` | text | The district's job-board URL (one per district, not a per-posting deep link). |
| `District` | text | Canonical district name (`canonicalize_k12_district()` applied). |

### `k12jobanalysis.csv` — full history, Teacher postings only

Row-level history of every Teacher-position posting ever scraped, one row per posting per week it appeared. Powers "New This Week," the teacher-vacancy-rate numerator, and every teacher trend chart. **Accumulated** — grows by one week's rows per run.

| Column | Type | Notes |
|---|---|---|
| `title` | text | |
| `Archive_Date` | date | |
| `position` | text | Always `"Teacher"` in this file (pre-filtered). |
| `location` | text | |
| `url` | text | |
| `District` | text | Canonical district name. |
| `Category` | text | Fine-grained subject from `classify_k12_subject()` (e.g. "Elementary Education", "Special Education - General"). |
| `Broad_Category` | text | Coarser grouping from `classify_k12_broad_category()`; this is what the app's category color palettes and pickers use. |

### `allsum.csv` — longitudinal category counts, by district and statewide

One row per (`Broad_Category`, `Archive_Date`, `District`) combination, **plus** a `District == "Total"` row per (`Broad_Category`, `Archive_Date`) that's the sum of that week's district rows — computed as an explicit sum of the parts, not an independent count, so `Total` can never silently drift out of sync with what it's supposed to add up to (`check_total_matches_parts()` asserts this before every weekly append). Powers the Longitudinal Teacher Trends chart. **Accumulated.**

| Column | Type | Notes |
|---|---|---|
| `Broad_Category` | text | |
| `Archive_Date` | date | |
| `District` | text | A real district name, or `"Total"`. |
| `sum` | integer | Distinct (`title`, `location`) postings that week — deduplicated on the pair, not `title` alone, since two schools can legitimately post the same generic title. |

### `allnow.csv` — current-week category counts

Same shape as `allsum.csv` minus the `Archive_Date` column (it's always just the latest week). Not accumulated — recomputed fresh every run since there's no history to preserve here.

| Column | Type | Notes |
|---|---|---|
| `Broad_Category` | text | |
| `Sum` | integer | Note the capital S — inconsistent with `allsum.csv`'s lowercase `sum`, a pre-existing quirk kept as-is rather than a breaking rename. |
| `District` | text | A real district name, or `"Total"`. |

### `k12_district_weekly_totals.csv` — all-category weekly totals per district

One row per (`District`, `Archive_Date`), counting **every** position type, not just Teacher — this is what powers the sparkline next to each district's raw count on the Home tab's "Top K-12 Hiring Districts" table, so it needs to match that same all-category number. **Accumulated.**

| Column | Type | Notes |
|---|---|---|
| `District` | text | |
| `Archive_Date` | date | |
| `n` | integer | All postings that district had that week, any position type. |

### `salarymap2.csv` — one row per district, static reference + refreshed figures

Not an archive — one current row per of Wyoming's 48 school districts. `District`/`County`/`Latitude`/`Longitude`/`Link`/`Job_Link` are hand-maintained; everything else is refreshed from its live source every run (and left untouched if that run's fetch fails, rather than being blanked out).

| Column | Type | Source | Notes |
|---|---|---|---|
| `District` | text | hand-maintained | Canonical name; the join key everything else in the app keys off. |
| `County` | text | hand-maintained | |
| `Latitude` / `Longitude` | numeric | hand-maintained | Used for the map marker. |
| `Link` | text | hand-maintained | District's general website (not currently surfaced in the app). |
| `Job_Link` | text | hand-maintained | District's job-board URL, shown in the map popup as "Careers page." |
| `Teacher_Base_Salary` / `Teacher_Base_Salary_Prior_Year` | numeric | WSBA (weekly refresh) | Current + prior year base salary from the same PDF scrape. |
| `Salary_Year` | text | WSBA | e.g. `"2025-2026"` — the real freshness signal (there's no separate "last updated" timestamp, since the dollar figures only change once a year regardless of scrape cadence). |
| `Superintendent_Salary` / `Superintendent_Contract_Days` | numeric | WSBA | |
| `Salary_Source` | text | WSBA | Literal string `"WSBA (wsba-wy.org)"`, for the summary table's footnote link. |
| `Teachers_Total_FTE` / `Enrollment` | numeric | NCES CCD via Urban Institute (weekly refresh) | Vacancy-rate denominator. |
| `CCD_Year` / `CCD_Source` | text | NCES CCD | |
| `Data_Coverage` | text | `misc_district_coverage_tiers()` (weekly refresh) | `"Full"` for districts on a real job-board platform; `"Partial (WSBA + own page)"` for the 12 `misc_district_registry` districts, whose postings come from WSBA's statewide feed (confirmed ~25-40% complete on its own) plus a heuristically-scraped district page. Shown as a badge on the map and a column on the K-12 Summary table — see `misc_district_scrapers.R`'s header for the full reasoning. |

### `k12_salary_history.csv` — multi-year K-12 salary archive

WSBA publishes no historical archive of its own (checked directly, confirmed no public archive exists) — this is this project's own accumulating record, one snapshot appended per new `Salary_Year` WSBA publishes (not one row per weekly run; `needs_k12_salary_archive_update()` guards against duplicate-year appends). Not currently read by `app.R` — it exists to grow into a real multi-year trend as more `Salary_Year`s accumulate, the same way `salarymap.csv`'s `Faculty_Avg_Salary_Y1Ago`/`Y2Ago` already work on the HE side via IPEDS's deeper history.

| Column | Type | Notes |
|---|---|---|
| `District` | text | |
| `Salary_Year` | text | |
| `Teacher_Base_Salary` | numeric | |
| `Superintendent_Salary` | numeric | |

---

## Higher Ed

### `hedata.xlsx` — current HE postings (this week only)

One row per open posting across all 9 public HE institutions, every job type (not just faculty). Rebuilt fresh every run — **not** accumulated (the accumulated raw history lives in `Archived_HE_Data/*.xlsx`, one file per week, which `facultydata.csv` etc. are derived from incrementally).

| Column | Type | Notes |
|---|---|---|
| `Title` | text | |
| `Location` | text | |
| `Posted_Date` | text | Original posted-date text, format varies by source platform. |
| `Institution` | text | Canonical institution name (`canonicalize_he_institution()` applied). |
| `Link` | text | Direct link to the posting. |
| `Archive_Date` | date | |

### `facultydata.csv` — full history, faculty + adjunct postings only

Row-level history of every `"Instructor/Teacher/Faculty"` and `"Adjunct/Part-Time Faculty"` posting ever scraped. Powers "New This Week," the faculty-vacancy-rate numerator, and every faculty trend chart, including the full-time/adjunct split on Current Faculty Trends. **Accumulated.**

| Column | Type | Notes |
|---|---|---|
| `Title` | text | |
| `Location` | text | |
| `Posted_Date` | text | |
| `Institution` | text | Canonical institution name. |
| `Link` | text | |
| `Archive_Date` | date | |
| `Job_Type` | text | `"Instructor/Teacher/Faculty"` or `"Adjunct/Part-Time Faculty"` from `classify_he_job_type()` — kept separate so a standing adjunct pool posting isn't counted the same as full-time faculty hiring. |
| `Category` | text | Subject area from `classify_he_faculty_category()`. |

### `allsum_he.csv` — longitudinal category counts, by institution and statewide

Same shape/logic as K-12's `allsum.csv`, plus a `Job_Type` dimension. One row per (`Category`, `Archive_Date`, `Institution`, `Job_Type`), plus `Institution == "Total"` rows summing across institutions for that (`Category`, `Archive_Date`, `Job_Type`). **Accumulated.**

| Column | Type | Notes |
|---|---|---|
| `Category` | text | |
| `Archive_Date` | date | |
| `Institution` | text | A real institution name, or `"Total"`. |
| `Job_Type` | text | |
| `sum` | integer | Posting count for that combination. |

### `allnow_he.csv` — current-week category counts

Same shape as `allsum_he.csv` minus `Archive_Date`. Not accumulated.

| Column | Type | Notes |
|---|---|---|
| `Category` | text | |
| `Job_Type` | text | |
| `Sum` | integer | Capital S, same pre-existing inconsistency as K-12's `allnow.csv`. |
| `Institution` | text | A real institution name, or `"Total"`. |

### `he_institution_weekly_totals.csv` — all-category weekly totals per institution

One row per (`Institution`, `Archive_Date`), all job types. Same purpose as K-12's `k12_district_weekly_totals.csv`. **Accumulated.**

| Column | Type | Notes |
|---|---|---|
| `Institution` | text | |
| `Archive_Date` | date | |
| `n` | integer | |

### `salarymap.csv` — one row per institution, static reference + refreshed figures

One current row per Wyoming's 9 public HE institutions. `Name`/`Longitude`/`Latitude`/`Link` are hand-maintained; the salary/staffing figures refresh from IPEDS every run (walking backward from the current year until a non-empty response is found, since IPEDS publishes with a 1-2 year lag).

| Column | Type | Source | Notes |
|---|---|---|---|
| `Name` | text | hand-maintained | Canonical name; the join key. |
| `Longitude` / `Latitude` | numeric | hand-maintained | |
| `Link` | text | hand-maintained | Careers page, shown in the map popup. |
| `Faculty_Avg_Salary` / `Faculty_Avg_Salary_Professor` | numeric | IPEDS via Urban Institute | "All ranks combined" and Professor-rank average salary. |
| `Faculty_Count` | numeric | IPEDS | Vacancy-rate denominator (full-time instructional staff only, matching `Job_Type == "Instructor/Teacher/Faculty"`'s scope). |
| `Salary_Year` | text | IPEDS | The calendar year IPEDS surveyed as of (Nov 1 of that year), not an academic year. |
| `Salary_Note` | text | IPEDS | Non-`NA` only for Sheridan/Gillette, explaining they're still one IPEDS-reported entity — see `Data_Coverage`'s HE analogue below. |
| `Salary_Source` | text | IPEDS | |
| `Faculty_Avg_Salary_Y1Ago` / `Y2Ago` | numeric | IPEDS | Real multi-year trend (unlike K-12's WSBA data, IPEDS is queryable by year indefinitely). |

**Sheridan College / Gillette College**: both institutions currently share one IPEDS-reported `Faculty_Count` and `Faculty_Avg_Salary` (they're legally one entity, Northern Wyoming Community College District, mid-split into two separate colleges). `app.R` gives both a shared *joint* vacancy rate (combined postings ÷ the one shared `Faculty_Count`) rather than showing neither — flagged via a `Vacancy_Rate_Shared` column computed in `app.R`, not stored in this file. `check_salary_drift.R` watches IPEDS's institution directory every run for a new, separate unitid; when the split becomes official there, updating `IPEDS_UNITID_MAP` in `ipeds_salary_scraper.R` is the only change needed to restore independent per-campus figures.

---

## Notes on the data model

- **Accumulation, not rebuilding.** Every "full history" file above (`k12jobanalysis.csv`, `allsum.csv`, `k12_district_weekly_totals.csv`, `facultydata.csv`, `allsum_he.csv`, `he_institution_weekly_totals.csv`) is appended to weekly, not regenerated from the raw archive from scratch — see `history_accumulator.R`. The raw weekly snapshots (`Archivek12_Data/*.csv`, `Archived_HE_Data/*.xlsx`) are still written every run as the durable source of truth; `scripts/rebuild_*_history_from_archive.R` rebuild any of the accumulated files from that raw archive from scratch, for disaster recovery or to verify the incremental path hasn't drifted.
- **Missingness is real, not a data quality bug.** `NA` in a salary/staffing column means that source's fetch failed or the row wasn't yet matched — not that the underlying district/institution has no data. Both K-12 and HE staffing/salary fetches leave the relevant file untouched on a failed run rather than blanking out last week's good values.
- **Classification lives in one place.** `classify_k12_position()`, `classify_k12_subject()`, `classify_k12_broad_category()`, `classify_he_job_type()`, `classify_he_faculty_category()`, and the `canonicalize_*` functions all live in `k12_he_classification.R`, sourced everywhere they're needed — the current-week and accumulated-history code paths can't silently classify the same title two different ways.
- **Schema is enforced, not just documented.** `schema_check.R`'s `REQUIRED_SCHEMAS` is checked against every shipped file before each weekly commit (`.github/scripts/verify_schema.R`) and again at `app.R`'s own startup (`validate_and_pad_schema()`, which also shows a Home-tab banner naming the exact file/column if something's ever missing).
