# Wyoming Education Jobs Dashboard — Data Dictionary & Codebook

Comprehensive variable codebook, schema definitions, and methodological provenance for datasets compiled and published by the **Wyoming Education Jobs Dashboard**.

Each dataset is accessible via the **Data** tab in the interactive web dashboard or by downloading machine-readable CSVs directly from this repository.

---

## 1. Datasets Overview

| Dataset Layer | Primary File | Description | Granularity | Refresh Cadence |
| :--- | :--- | :--- | :--- | :--- |
| **Active K-12 Jobs** | `combinedclean.csv` | Every K-12 posting listed in the latest update: district boards plus WSBA's statewide list. | Posting level | Twice weekly |
| **K-12 Historical Archive** | `k12jobanalysis.csv` | Every teaching posting in every update since August 2024 (teaching jobs only), with standardized categories. | Posting level | Twice weekly |
| **K-12 Job Duration Spells** | `job_duration_spells.csv` | One row per posting: first and last update it was seen, days listed, and job-type flags (STEM, special education, ...). | Posting spell | Twice weekly |
| **District Profiles & Benchmarks** | `salarymap2.csv` | District-level staffing, compensation benchmarks, and Census context. | District level | Twice weekly / Annual |
| **WDE602 District Staffing Matrix** | `wde602_district_staff_salaries.csv` | Staff headcount, FTE, and average base/total compensation across 30+ assignment categories. | District × Role | Annual |
| **Higher Ed Historical Postings** | `facultydata.csv` | Every faculty and adjunct posting in every update since August 2024 (no staff postings). | Posting level | Twice weekly |
| **Higher Ed Job Duration Spells** | `he_job_duration_spells.csv` | One row per college posting: first and last update it was seen, days listed, and discipline flags. | Posting spell | Twice weekly |
| **Higher Ed Institutional Profiles** | `salarymap.csv` | College and university profiles: IPEDS instructional faculty salaries, enrollment, and Pell recipient shares. | Institution level | Twice weekly / Annual |
| **K-12 Weekly Vacancy Time Series** | `k12_district_weekly_totals.csv` | Open posting counts per district in each update. | District × Update | Twice weekly |
| **K-12 Job Type Time Series** | `k12_jobtype_weekly_totals.csv` | Open job postings per update by K-12 position type, all and those not marked part-time, substitute or extra duty. | Job type × Update | Twice weekly |
| **Higher Ed Weekly Vacancy Time Series** | `he_institution_weekly_totals.csv` | Open posting counts per college in each update. | Institution × Update | Twice weekly |
| **Higher Ed Job Type Time Series** | `he_jobtype_weekly_totals.csv` | Open college job postings per update by job type, all and those not marked part-time, student or temporary. | Job type × Update | Twice weekly |
| **K-12 Current Category Counts** | `allnow.csv` | Teaching postings in the latest update by subject group and district, with statewide totals. | District × Category | Twice weekly |
| **K-12 Category Time Series** | `allsum.csv` | Teaching postings by subject group and district in every update, with statewide totals. | District × Category × Update | Twice weekly |
| **Higher Ed Current Category Counts** | `allnow_he.csv` | Faculty and adjunct postings in the latest update by discipline, type and college, with statewide totals. | College × Discipline × Type | Twice weekly |
| **Higher Ed Category Time Series** | `allsum_he.csv` | Faculty and adjunct postings by discipline, type and college in every update, with statewide totals. | College × Discipline × Type × Update | Twice weekly |
| **Active Higher Ed Jobs** | `hedata.xlsx` | Every college posting listed in the latest update, all job types, with posted pay, campus placement and pay estimates. | Posting level | Twice weekly |
| **IPEDS Staff Salaries** | `ipeds_staff_salaries.csv` | Average pay of full-time non-instructional staff by college and occupational category (categories with at least 3 staff). | College × Category | Annual |
| **K-12 Salary History** | `k12_salary_history.csv` | Teacher base salary and superintendent salary by district for each WSBA salary year this project has captured (WSBA keeps no public archive). | District × Year | Annual |
| **BLS Regional Pay by Role** | `oews_role_wages.csv` | Median pay for the occupations K-12 postings are matched to, by Wyoming OEWS area; the source of the K-12 Typical pay (BLS est.) column. | Area × Occupation | Annual |
| **Posting First Seen** | `posting_first_seen.csv` | When the dashboard first found each currently listed posting; shown where the board gives no posted date. | Posting level | Twice weekly |
| **County Public School Pay** | `qcew_county_school_pay.csv` | Average annual pay and employment of public school (local government, NAICS 6111) employees by county, all roles together. | County level | Annual |
| **UW Salary Book** | `uw_salary_book.csv` | University of Wyoming salaried staff by department and title, no names, from UW's departmental salary listing (published each fall); the source of UW staff pay estimates. | Employee level | Annual |
| **Source Retrieval Dates** | `source_retrieved_dates.csv` | When each outside data source was last fetched successfully. | Source level | Twice weekly |
| **Data Dictionary & Codebook** | `data_dictionary.csv` | Machine-readable column definitions, types, and primary source authorities across all files. | Variable level | Static / Maintained |

---

## 2. Universal Identifiers

To support seamless merges with federal, state, and academic datasets, the following universal identifiers are embedded:

- **`NCES_LEAID`**: Official 7-digit federal National Center for Education Statistics Local Education Agency identifier. Enables 1:1 joining with the **Stanford Educational Data Archive (SEDA)**, **Civil Rights Data Collection (CRDC)**, and **Census F-33 School District Finance Survey**.
- **`IPEDS_UNITID`**: Official 6-digit federal Integrated Postsecondary Education Data System identifier.
- **`District_ID`**: 6-digit Wyoming Department of Education state district identification code.

---

## 3. Data Dictionary: Detailed Variable Definitions

### A. Active K-12 Jobs (`combinedclean.csv`)

| Column Name | Data Type | Source Authority | Description |
| :--- | :--- | :--- | :--- |
| `title` | String | Job posting (district job board or WSBA vacancy list) | Official job vacancy title as published by the school district or charter school. |
| `Archive_Date` | Date (YYYY-MM-DD) | This dashboard: snapshot at each update | Date of the update that saw the posting listed (the dashboard updates twice a week since 2026-11-17, weekly before). |
| `date_posted` | String / Date | Job posting (district job board or WSBA vacancy list) | Original posted date string as published on the district applicant tracking board. |
| `position` | Categorical | This dashboard: job title classification | Broad staff position group (Teacher, Administrator, Support Services, etc.). |
| `location` | String | Job posting (district job board or WSBA vacancy list) | Specific school building, school campus, facility, or district administrative office. |
| `url` | URL | Job posting (district job board or WSBA vacancy list) | Direct link to the job posting or district applicant tracking portal. |
| `Posting_ID` | String | This dashboard: posting tracking | Durable unique posting identifier the same for a posting in every update it appears in. |
| `Posting_Source` | String | This dashboard: posting tracking | The board a posting was read from: '<platform> (direct district board)' for a district's AppliTrack, SchoolSpring, TedK12 or Red Rover board, '<platform> district site (direct board)' for a district's own page, 'WSBA statewide vacancies' for a WSBA listing. Recorded at scrape time from 2026-11-12. Earlier updates are filled where the archived row settles it: from the posting's source id, from WSBA's own link, and for every update before 2026-08-02 (when WSBA was first read) from the link's host, with 'District site (direct board)' for a district's own site. NA where it cannot be told (some rows from 2026-08-03 to 2026-11-06). |
| `Posting_Identity_Method` | String | This dashboard: posting tracking | How Posting_ID was made: 'Source posting ID' (the board's own id for the posting) or 'Source fallback: district + link + title + location + posted date (no source posting ID)' (a fingerprint of those fields). |
| `Feed_District` | String | This dashboard: posting tracking | For a WSBA row, the organization WSBA names. NA for direct-board rows and where Posting_Source is NA. |
| `Also_On_Feed` | Logical | This dashboard: posting tracking | TRUE for a direct-board posting that WSBA also lists (same district, title and posted date, or a WSBA link naming the posting's job ID). It is counted once, from the district's board. Recorded from 2026-11-12; NA for earlier updates. |
| `Role_Hint` | Categorical | This dashboard: job title classification | The role a statewide-feed posting's description names, used to refine its position bucket. Always NA for Wyoming: WSBA gives no description to read one from. Kept so the file has the same columns in every state (edjobs::K12_POSTING_COLUMNS). |
| `District` | String | This dashboard: district and college list | Canonical public school district or charter school name. |
| `Close_Date` | String | Job posting (district job board or WSBA vacancy list) | The posting's closing date as its board states it, unparsed (a date, or "When Filled", "Open Until Filled" and similar). AppliTrack rows (from 2026-11-03) as written, and SchoolSpring (from 2026-11-04: the deadline applicants see, as YYYY-MM-DD; "Posted until filled" is NA); NA where the board gives none and for other sources. |
| `Pay_Min` | Numeric | Job posting (district job board or WSBA vacancy list) | Lowest pay amount stated in the posting itself, in `Pay_Unit` (NA when no dollar figure is stated). Never converted between units. |
| `Pay_Max` | Numeric | Job posting (district job board or WSBA vacancy list) | Highest stated amount (equals `Pay_Min` for a single figure). |
| `Pay_Unit` | String | Job posting (district job board or WSBA vacancy list) | `hour`, `day`, `month`, `year`, `credit hour`, or `stipend` (season/activity amount); NA when undeterminable. |
| `Pay_Text` | String | Job posting (district job board or WSBA vacancy list) | The posting text the pay was read from, for verification (for RedRover, the board's own pay line, e.g. "$13.50 - $14.65 per hour"; "per unit" there means a stipend). |
| `Est_Pay` | Numeric | BLS OEWS | Where the posting states no pay of its own: the Bureau of Labor Statistics' median pay for the posting's role in its region (see `Est_Occupation`, `Est_Area`), in `Est_Pay_Unit`. A regional estimate across all employers of that occupation, not this job's offer. NA for roles with no fair match (coaches, unclassified postings). |
| `Est_Pay_Unit` | String | BLS OEWS | `hour` for roles usually paid hourly where BLS publishes an hourly median; otherwise `year`. |
| `Est_Occupation` | String | BLS OEWS | The OEWS occupation the posting was matched to from its position and title (e.g. "Teaching assistants", "School bus drivers"). |
| `Est_Area` | String | BLS OEWS | The OEWS area the figure is for: the metro or nonmetro area holding the district's county, or the state where the county is unknown or BLS suppresses the local figure. |
| `Est_Year` | String | BLS OEWS | OEWS reference year (May of that year). |

---

### B. K-12 Historical Archive (`k12jobanalysis.csv`)

| Column Name | Data Type | Source Authority | Description |
| :--- | :--- | :--- | :--- |
| `title` | String | Job posting (district job board or WSBA vacancy list) | Standardized job vacancy title as published by the school district or charter school. |
| `Archive_Date` | Date (YYYY-MM-DD) | This dashboard: snapshot at each update | Date of the update that saw the posting listed (the dashboard updates twice a week since 2026-11-17, weekly before). |
| `position` | Categorical | This dashboard: job title classification | Broad staff position group (Teacher, Administrator, Support Services, etc.). |
| `location` | String | Job posting (district job board or WSBA vacancy list) | Specific school building, facility, or district administrative office location. |
| `url` | URL | Job posting (district job board or WSBA vacancy list) | Direct URL link to the official job vacancy listing or district portal. |
| `Posting_ID` | String | This dashboard: posting tracking | Durable unique posting identifier the same for a posting in every update it appears in. The source's own posting ID where it has one (e.g. `schoolspring:laramie1.schoolspring.com:5857967`, `applitrack:tcsd:836` from 2026-11-03); otherwise a fallback fingerprint, `fallback \| <district> \| <url> \| <title> \| <location> \| <posted date>`, lower-cased. |
| `Posting_Source` | String | This dashboard: posting tracking | The board a posting was read from: '<platform> (direct district board)' for a district's AppliTrack, SchoolSpring, TedK12 or Red Rover board, '<platform> district site (direct board)' for a district's own page, 'WSBA statewide vacancies' for a WSBA listing. Recorded at scrape time from 2026-11-12. Earlier updates are filled where the archived row settles it: from the posting's source id, from WSBA's own link, and for every update before 2026-08-02 (when WSBA was first read) from the link's host, with 'District site (direct board)' for a district's own site. NA where it cannot be told (some rows from 2026-08-03 to 2026-11-06). |
| `Posting_Identity_Method` | String | This dashboard: posting tracking | How Posting_ID was made: 'Source posting ID' (the board's own id for the posting) or 'Source fallback: district + link + title + location + posted date (no source posting ID)' (a fingerprint of those fields). |
| `Role_Hint` | Categorical | This dashboard: job title classification | The role a statewide-feed posting's description names, used to refine its position bucket. Always NA for Wyoming: WSBA gives no description to read one from. Kept so the file has the same columns in every state (edjobs::K12_POSTING_COLUMNS). |
| `District` | String | This dashboard: district and college list | Canonical public school district or charter school Local Education Agency (LEA) name. |
| `Category` | String | This dashboard: job title classification | Fine-grained subject specialization or departmental role assignment. |
| `Broad_Category` | Categorical | This dashboard: job title classification | Clustered high-level category grouping (Elementary, STEM, Special Education, Humanities, etc.). |

**Repeated rows.** 129 rows are exact repeats of another row in the same week (78 of them in the first week, 2024-08-09; the other 51 February-July 2026, all SchoolSpring postings in Albany, Campbell and Laramie County School Districts 1). Older snapshots dropped the building that told these postings apart (e.g. one coach per elementary school), so they can be separate openings and are kept. Counts use distinct `posting_id` within a week, so each set counts once; for those SchoolSpring sets that is an under-count. Weeks since August 2026 have none (`test-weekly-data-quality.R` checks the newest week).

**ID format change.** Before November 2026 the fallback fingerprint's parts were joined with a carriage return, which showed up as line breaks inside the field, and weeks rebuilt from the raw archive used spaces instead. Every week was regenerated in the current form, so a posting's ID is consistent across the whole file.

---

### C. K-12 Job Duration Spells (`job_duration_spells.csv`)

| Column Name | Data Type | Source Authority | Description |
| :--- | :--- | :--- | :--- |
| `District` | String | This dashboard: district and college list | Canonical public school district or charter school name. |
| `NCES_LEAID` | String (7-digit) | NCES Common Core of Data (CCD) | Official federal National Center for Education Statistics Local Education Agency 7-digit identifier. |
| `Title` | String | Job posting (district job board or WSBA vacancy list) | Standardized job vacancy title. |
| `Category` | String | This dashboard: job title classification | Fine-grained subject area or departmental functional assignment. |
| `Broad_Category` | Categorical | This dashboard: job title classification | High-level clustered role grouping (Elementary, STEM, Special Education, etc.). |
| `Position` | Categorical | This dashboard: job title classification | Broad staff position group (Teacher, Administrator, Support Services). |
| `First_Seen_Date` | Date (YYYY-MM-DD) | This dashboard: posting tracking | Earliest update in which this job vacancy was observed active. |
| `Last_Seen_Date` | Date (YYYY-MM-DD) | This dashboard: posting tracking | Latest update in which this job vacancy was observed active. |
| `Weeks_Observed` | Integer | This dashboard: posting tracking | Number of distinct calendar weeks (ISO weeks) in which this posting was observed during the spell. A posting absent for more than 21 days that reappears under the same title starts a new spell. |
| `Estimated_Days_Open` | Integer | This dashboard: posting tracking | Estimated days the posting was listed, from its first to its last sighting. How long a listing stays up, not time to fill: filled jobs can stay posted and open jobs get reposted. |
| `Status` | Categorical | This dashboard: posting tracking | Still Active (listed in the latest update) or Closed / Filled (no longer listed; whether it was filled isn't known). |
| `is_stem` | Binary (0/1) | This dashboard: job title classification | Binary indicator: 1 if position is Science, Technology, Engineering, or Mathematics; 0 otherwise. |
| `is_sped` | Binary (0/1) | This dashboard: job title classification | Binary indicator: 1 if position is Special Education; 0 otherwise. |
| `is_elementary` | Binary (0/1) | This dashboard: job title classification | Binary indicator: 1 if position is Elementary Education; 0 otherwise. |
| `is_secondary` | Binary (0/1) | This dashboard: job title classification | Binary indicator: 1 if position is Middle School or High School; 0 otherwise. |
| `is_admin` | Binary (0/1) | This dashboard: job title classification | Binary indicator: 1 if position is Administration, Principal, or Superintendent; 0 otherwise. |
| `is_support_staff` | Binary (0/1) | This dashboard: job title classification | Binary indicator: 1 if position is Paraprofessional, Aide, Custodial, Bus, or Food Service; 0 otherwise. |

---

### D. District Profiles & Context (`salarymap2.csv`)

| Column Name | Data Type | Source Authority | Description |
| :--- | :--- | :--- | :--- |
| `District` | String | This dashboard: district and college list | Canonical public school district or charter school name. |
| `NCES_LEAID` | String (7-digit) | NCES Common Core of Data (CCD) | Official federal NCES Local Education Agency 7-digit identifier. |
| `CCD_Link` | URL | NCES Common Core of Data (CCD) | Link to this district's page in the NCES Common Core of Data district search, built from NCES_LEAID (edjobs nces_district_url()). The page shows NCES's newest school year, which can be newer than CCD_Year. Blank when the district has no NCES id. |
| `County` | String | US Census Bureau | County in which the district central administrative headquarters is located. |
| `Latitude` | Decimal Degrees | This dashboard: district and college list | Geographic latitude coordinate of district central headquarters. |
| `Longitude` | Decimal Degrees | This dashboard: district and college list | Geographic longitude coordinate of district central headquarters. |
| `Job_Link` | URL | This dashboard: district and college list | Official employment, careers, or applicant tracking portal link for the district. |
| `Teacher_Base_Salary` | Currency ($) | WSBA Salary Survey | Published starting base salary for a certified teacher with a Bachelors degree and Step 1 experience. |
| `Teacher_Base_Salary_Prior_Year` | Currency ($) | WSBA Salary Survey | Published starting base salary for BA Step 1 in the preceding academic school year. |
| `Salary_Year` | String | WSBA Salary Survey | Academic school year corresponding to the published WSBA base salary survey. |
| `Superintendent_Salary` | Currency ($) | WSBA Salary Survey | Contracted annual salary of the district superintendent. |
| `Superintendent_Contract_Days` | Integer | WSBA Salary Survey | Contracted annual working days for the district superintendent. |
| `Salary_Source` | String | WSBA Salary Survey | Publishing authority and survey title for district teacher base salaries. |
| `Data_Coverage` | Categorical | This dashboard: coverage summary | Scraper coverage fidelity tier: Full (direct ATS integration) vs Partial (heuristic site or state feed scrape). |
| `Teachers_Total_FTE` | Numeric | NCES Common Core of Data (CCD) | Total full-time-equivalent certified classroom teachers employed by the district. |
| `Enrollment` | Integer | NCES Common Core of Data (CCD) | Total pre-K through grade 12 student fall enrollment headcount. |
| `CCD_Year` | Integer | NCES Common Core of Data (CCD) | Reporting school year for federal Common Core of Data staffing and enrollment counts. |
| `CCD_Source` | String | NCES Common Core of Data (CCD) | Federal source citation for NCES CCD public school district universe data. |
| `Median_Household_Income` | Currency ($) | US Census ACS 5-year | County median annual household income in inflation-adjusted dollars. |
| `Median_Household_Income_MOE` | Currency ($) | US Census ACS 5-year | Census's 90% margin of error for Median_Household_Income (B19013_001M). Shown as ± on the dashboard. |
| `Median_Gross_Rent` | Currency ($) | US Census ACS 5-year | County median monthly gross rent including estimated utilities. |
| `Median_Gross_Rent_MOE` | Currency ($) | US Census ACS 5-year | Census's 90% margin of error for Median_Gross_Rent (B25064_001M). |
| `Population` | Integer | US Census ACS 5-year | Total estimated resident population of the county. |
| `ACS_Year` | Integer | US Census ACS 5-year | Data release year for US Census American Community Survey 5-year estimates. |
| `Mining_Employment_Share` | Proportion (0-1) | US Census ACS 5-year | Share of the county's employed civilians (16 and over) who work in mining, quarrying, and oil and gas extraction (ACS table S2403). |
| `Mining_Employment_Share_MOE` | Proportion (0-1) | US Census ACS 5-year (derived) | 90% margin of error for Mining_Employment_Share, from Census's formula for a derived proportion (ACS handbook 2020, ch. 8, formula 6) using the S2403 MOEs. When it is at least the share itself, the share is not distinguishable from zero (Census's CV > 0.61 line) and the dashboard says so. Census's CV-based reliability rules are unstable for shares under 5% (National Research Council 2007, p. 67), so no reliability tier is given. |
| `Population_Change_Pct` | Proportion | US Census ACS 5-year | County 5-year percentage change in total resident population. |
| `Child_Poverty_Rate` | Proportion (0-1) | US Census SAIPE | Estimated proportion of school-age children (ages 5-17) living in families below the federal poverty line. Not a true poverty rate (Census): the first count includes only children related to the householder, in families in poverty; the second, all children 5-17 (foster children, other unrelated children and children in group quarters are in the second only). The dashboards label it "School-age children in poverty (Census est.)". |
| `SAIPE_Population` | Number | US Census SAIPE | Total population of the SAIPE district behind the child poverty estimate (SAEPOVALL_PT); for a charter or early-childhood center, its surrounding district's. It sets the estimate's error band. |
| `Child_Poverty_Low` | Proportion (0-1) | US Census SAIPE (derived) | Low end of Census's approximate 90% range for Child_Poverty_Rate: rate x (1 - 1.645 x CV), floored at 0. CV is Census's median relative error for districts of that size (0.67 under 2,500 people down to 0.15 at 65,000+; "Quantifying Relative Error in the School District Estimates", revised 2025-12-17), which Census calls an approximate upper bound. Census publishes no margin of error for one district. |
| `Child_Poverty_High` | Proportion (0-1) | US Census SAIPE (derived) | High end of the same range: rate x (1 + 1.645 x CV), capped at 1. See Child_Poverty_Low. |
| `SAIPE_Year` | Integer | US Census SAIPE | Release year of federal Small Area Income and Poverty Estimates (SAIPE) data. |
| `Teacher_Avg_Salary` | Currency ($) | Wyoming Dept of Education (WDE602) | Actual average total compensation paid across all employed certified classroom teachers in the district. |
| `Teacher_Avg_Base_Salary` | Currency ($) | Wyoming Dept of Education (WDE602) | Actual average base contract salary paid across all employed certified classroom teachers in the district. |
| `WDE_Salary_Year` | String | Wyoming Dept of Education (WDE602) | Academic school year corresponding to the WDE602 certified staff collection. |
| `WDE_Salary_Source` | String | Wyoming Dept of Education (WDE602) | Publishing state agency authority for Wyoming Department of Education staff collections. |

---

### E. WDE602 Staff Salary Collection (`wde602_district_staff_salaries.csv`)

| Column Name | Data Type | Source Authority | Description |
| :--- | :--- | :--- | :--- |
| `School_Year` | String | Wyoming Dept of Education (WDE602) | Official state reporting academic school year for the certified and classified staff collection. |
| `Data_Scope` | String | Wyoming Dept of Education (WDE602) | Scope classification of staff reporting (District-level collection). |
| `District_ID` | Integer | Wyoming Dept of Education (WDE602) | Official 6-digit Wyoming Department of Education state district identification number. |
| `District_Name` | String | Wyoming Dept of Education (WDE602) | Official district name as recorded in WDE state reporting collections. |
| `District` | String | This dashboard: district and college list | Standardized canonical district name harmonized with project job boards and benchmarks. |
| `NCES_LEAID` | String (7-digit) | NCES Common Core of Data (CCD) | Official federal NCES Local Education Agency 7-digit identifier. |
| `Group_Scope` | String | Wyoming Dept of Education (WDE602) | Staff assignment classification scope (All Staff, Certified, Classified). |
| `Group_Name` | String | Wyoming Dept of Education (WDE602) | Specific staff assignment code group (Teachers, Principals, Aides, Bus Drivers, Custodians, Food Service). |
| `Male_FTE` | Numeric | Wyoming Dept of Education (WDE602) | Total full-time-equivalent male employees in this staff assignment group. |
| `Female_FTE` | Numeric | Wyoming Dept of Education (WDE602) | Total full-time-equivalent female employees in this staff assignment group. |
| `Total_FTE` | Numeric | Wyoming Dept of Education (WDE602) | Total full-time-equivalent staff employed in that specific assignment group. |
| `Average_Base_Salary` | Currency ($) | Wyoming Dept of Education (WDE602) | Average contracted base salary for staff in that assignment group. |
| `Average_Total_Salary` | Currency ($) | Wyoming Dept of Education (WDE602) | Average total compensation including stipends and benefits for staff in that assignment group. |
| `Source_Link` | URL | Wyoming Dept of Education (WDE602) | WDE's report "District K12 Staff FTE and Average Salary by Category" (reporting.edu.wyo.gov), where these figures are published. WDE has no page per district: the report covers every district; choose the school year in its form. |

---

### F. Higher Ed Historical Archive (`facultydata.csv`)

| Column Name | Data Type | Source Authority | Description |
| :--- | :--- | :--- | :--- |
| `Title` | String | Job posting (college job board) | Published collegiate job vacancy title as advertised on the college or university careers portal. |
| `Location` | String | Job posting (college job board) | Campus location, city, or remote work designation. |
| `Posted_Date` | String / Date | Job posting (college job board) | Original date of vacancy posting as published by the college or university. |
| `Institution` | String | This dashboard: district and college list | Canonical name of the public college or university. |
| `Link` | URL | Job posting (college job board) | Direct URL link to the official higher education employment vacancy announcement. |
| `Archive_Date` | Date (YYYY-MM-DD) | This dashboard: snapshot at each update | Date of the update that saw the posting listed (the dashboard updates twice a week since 2026-11-17, weekly before). |
| `Job_Type` | Categorical | This dashboard: job title classification | Instructor/Teacher/Faculty or Adjunct/Part-Time Faculty (this file holds faculty postings only). |
| `Category` | String | This dashboard: job title classification | Academic discipline, instructional field, or administrative functional area. |

**Repeated rows.** 170 rows are exact repeats of another row in the same week (August 2024 to January 2026, 1-5 per week, mostly Sheridan College's "Part-time Faculty Pool" listings and University of Wyoming faculty titles). Those snapshots link to the listing page rather than the posting, so two identical rows can be two real openings with the same title; they are kept, and counted as separate postings. Weeks since January 2026 have none.

---

### G. Higher Ed Job Duration Spells (`he_job_duration_spells.csv`)

| Column Name | Data Type | Source Authority | Description |
| :--- | :--- | :--- | :--- |
| `Institution` | String | This dashboard: district and college list | Canonical name of the public college or university. |
| `IPEDS_UNITID` | String (6-digit) | NCES IPEDS | Official 6-digit federal NCES Integrated Postsecondary Education Data System Unit ID. |
| `Title` | String | Job posting (college job board) | Standardized collegiate job vacancy title. |
| `Category` | String | This dashboard: job title classification | Academic discipline or collegiate functional assignment area. |
| `Job_Type` | Categorical | This dashboard: job title classification | Collegiate appointment classification: Instructor/Teacher/Faculty or Adjunct/Part-Time Faculty. |
| `First_Seen_Date` | Date (YYYY-MM-DD) | This dashboard: posting tracking | Earliest update in which this collegiate job posting was observed active. |
| `Last_Seen_Date` | Date (YYYY-MM-DD) | This dashboard: posting tracking | Latest update in which this collegiate job posting was observed active. |
| `Weeks_Observed` | Integer | This dashboard: posting tracking | Number of distinct calendar weeks (ISO weeks) in which this posting was observed during the spell. A posting absent for more than 21 days that reappears under the same title starts a new spell. |
| `Estimated_Days_Open` | Integer | This dashboard: posting tracking | Estimated days the posting was listed, from its first to its last sighting. How long a listing stays up, not time to fill: filled jobs can stay posted and open jobs get reposted. |
| `Status` | Categorical | This dashboard: posting tracking | Still Active (listed in the latest update) or Closed / Filled (no longer listed; whether it was filled isn't known). |
| `is_stem` | Binary (0/1) | This dashboard: job title classification | Binary indicator: 1 if position is Science, Technology, Engineering, or Mathematics; 0 otherwise. |
| `is_health` | Binary (0/1) | This dashboard: job title classification | Binary indicator: 1 if position is Nursing, Health Sciences, or Medical; 0 otherwise. |
| `is_cte` | Binary (0/1) | This dashboard: job title classification | Binary indicator: 1 if position is Career & Technical Education or Trades; 0 otherwise. |
| `is_adjunct` | Binary (0/1) | This dashboard: job title classification | Binary indicator: 1 if position is Part-Time or Adjunct Faculty; 0 otherwise. |
| `is_faculty` | Binary (0/1) | This dashboard: job title classification | Binary indicator: 1 if position is Full-Time Instructional Faculty; 0 otherwise. |

---

### H. Higher Ed Institutional Profiles (`salarymap.csv`)

| Column Name | Data Type | Source Authority | Description |
| :--- | :--- | :--- | :--- |
| `Name` | String | This dashboard: district and college list | College or university name. |
| `IPEDS_UNITID` | String (6-digit) | NCES IPEDS | Official 6-digit federal NCES Integrated Postsecondary Education Data System Unit ID. |
| `IPEDS_Link` | URL | NCES IPEDS | Link to this institution's page in NCES College Navigator, built from IPEDS_UNITID (edjobs college_navigator_url()). The page shows NCES's newest year, which can be newer than this file's year columns. Blank when the institution has no IPEDS id. |
| `Longitude` | Decimal Degrees | This dashboard: district and college list | Geographic longitude coordinate of main campus centroid. |
| `Latitude` | Decimal Degrees | This dashboard: district and college list | Geographic latitude coordinate of main campus centroid. |
| `Link` | URL | This dashboard: district and college list | Official careers or employment opportunities portal URL for the institution. |
| `County` | String | US Census Bureau | County in which the collegiate campus is located. |
| `Faculty_Avg_Salary` | Currency ($) | NCES IPEDS | Average salary of full-time instructional staff on 9- to 12-month contracts (IPEDS collects none for part-time staff or for contracts under 9 months) across all academic ranks combined. |
| `Faculty_Avg_Salary_Professor` | Currency ($) | NCES IPEDS | Average salary of full-time instructional staff on 9- to 12-month contracts (IPEDS collects none for part-time staff or for contracts under 9 months) for the Full Professor academic rank. |
| `Faculty_Count` | Integer | NCES IPEDS | Total count of full-time instructional staff employed by the institution. |
| `Salary_Year` | Integer | NCES IPEDS | Academic reporting year corresponding to the IPEDS faculty compensation survey. |
| `Salary_Note` | String | This dashboard: method note | Methodological reporting note (e.g., joint IPEDS reporting for multi-campus community college districts). |
| `Salary_Source` | String | NCES IPEDS | Data provenance and primary survey source citation for instructional faculty pay. |
| `Faculty_Avg_Salary_Y1Ago` | Currency ($) | NCES IPEDS | Average salary of full-time instructional staff on 9- to 12-month contracts (IPEDS collects none for part-time staff or for contracts under 9 months) in the prior academic year (t-1). |
| `Faculty_Avg_Salary_Y2Ago` | Currency ($) | NCES IPEDS | Average salary of full-time instructional staff on 9- to 12-month contracts (IPEDS collects none for part-time staff or for contracts under 9 months) two academic years prior (t-2). |
| `Enrollment` | Integer | NCES IPEDS | Total unduplicated fall student headcount enrollment. |
| `Enrollment_Year` | Integer | NCES IPEDS | Academic reporting year for IPEDS fall enrollment figures. |
| `Enrollment_Change_Pct` | Proportion | NCES IPEDS | 5-year percentage change in total fall student enrollment. |
| `Pell_Recipient_Share` | Proportion (0-1) | US Dept of Education FSA | Share of undergraduate degree-seeking students awarded federal need-based Pell Grants. |
| `Pell_Year` | Integer | US Dept of Education FSA | Award year for Federal Student Aid (FSA) Pell Grant recipient figures. |
| `Median_Household_Income` | Currency ($) | US Census ACS 5-year | County median annual household income in inflation-adjusted dollars. |
| `Median_Household_Income_MOE` | Currency ($) | US Census ACS 5-year | Census's 90% margin of error for Median_Household_Income (B19013_001M). Shown as ± on the dashboard. |
| `Median_Gross_Rent` | Currency ($) | US Census ACS 5-year | County median monthly gross rent including estimated utilities. |
| `Median_Gross_Rent_MOE` | Currency ($) | US Census ACS 5-year | Census's 90% margin of error for Median_Gross_Rent (B25064_001M). |
| `Population` | Integer | US Census ACS 5-year | Total estimated resident population of the county in which the campus is located. |
| `ACS_Year` | Integer | US Census ACS 5-year | Data release year for US Census American Community Survey 5-year estimates. |
| `Mining_Employment_Share` | Proportion (0-1) | US Census ACS 5-year | Share of the county's employed civilians (16 and over) who work in mining, quarrying, and oil and gas extraction (ACS table S2403). |
| `Mining_Employment_Share_MOE` | Proportion (0-1) | US Census ACS 5-year (derived) | 90% margin of error for Mining_Employment_Share, from Census's formula for a derived proportion (ACS handbook 2020, ch. 8, formula 6) using the S2403 MOEs. When it is at least the share itself, the share is not distinguishable from zero (Census's CV > 0.61 line) and the dashboard says so. Census's CV-based reliability rules are unstable for shares under 5% (National Research Council 2007, p. 67), so no reliability tier is given. |
| `Population_Change_Pct` | Proportion | US Census ACS 5-year | County 5-year percentage change in total resident population. |
| `n_not_marked` | Integer | This dashboard: job classification | Of those, postings classify_work_schedule() (edjobs) does not mark as a substitute, extra-duty (coaching, activities, stipend), part-time, student or temporary/seasonal job. Sources never confirm full-time, so this is "not marked", not "full-time". The Home page's top districts table and its sparklines count these when its switch is on (the default). |

---

### I. K-12 Weekly Vacancy Time Series (`k12_district_weekly_totals.csv`)

| Column Name | Data Type | Source Authority | Description |
| :--- | :--- | :--- | :--- |
| `District` | String | This dashboard: district and college list | Canonical public school district or charter school name. |
| `Archive_Date` | Date (YYYY-MM-DD) | This dashboard: snapshot at each update | Date of the update. |
| `n` | Integer | This dashboard: snapshot at each update | Total count of active job postings observed open for that district in that update. |
| `n_not_marked` | Integer | This dashboard: job classification | Of those, postings classify_work_schedule() (edjobs) does not mark as a substitute, extra-duty (coaching, activities, stipend), part-time, student or temporary/seasonal job. Sources never confirm full-time, so this is "not marked", not "full-time". The Home page's top colleges table and its sparklines count these when its switch is on (the default). |

---

### H2. K-12 Job Type Time Series (`k12_jobtype_weekly_totals.csv`)

| Column Name | Data Type | Source Authority | Description |
| :--- | :--- | :--- | :--- |
| `Job_Type` | String | This dashboard: job classification | K-12 position bucket (position in combinedclean.csv). |
| `Archive_Date` | Date (YYYY-MM-DD) | This dashboard: snapshot at each update | Date of the update. |
| `n` | Integer | This dashboard: snapshot at each update | Count of active job postings of that type observed open on that update. |
| `n_not_marked` | Integer | This dashboard: job classification | Of those, postings classify_work_schedule() (edjobs) does not mark as a substitute, extra-duty (coaching, activities, stipend), part-time, student or temporary/seasonal job. Sources never confirm full-time, so this is "not marked", not "full-time". The Home page's job-type tables count these. |

---

### J. Higher Ed Weekly Vacancy Time Series (`he_institution_weekly_totals.csv`)

| Column Name | Data Type | Source Authority | Description |
| :--- | :--- | :--- | :--- |
| `Institution` | String | This dashboard: district and college list | College or university name. |
| `Archive_Date` | Date (YYYY-MM-DD) | This dashboard: snapshot at each update | Date of the update. |
| `n` | Integer | This dashboard: snapshot at each update | Total count of active job postings observed open for that higher education institution in that update. |

---

### I2. Higher Ed Job Type Time Series (`he_jobtype_weekly_totals.csv`)

| Column Name | Data Type | Source Authority | Description |
| :--- | :--- | :--- | :--- |
| `Job_Type` | String | This dashboard: job classification | College job type (classify_he_job_type(), every posting, not only faculty). |
| `Archive_Date` | Date (YYYY-MM-DD) | This dashboard: snapshot at each update | Date of the update. |
| `n` | Integer | This dashboard: snapshot at each update | Count of active college job postings of that type observed open on that update. |
| `n_not_marked` | Integer | This dashboard: job classification | Of those, postings classify_work_schedule() (edjobs) does not mark as a substitute, extra-duty (coaching, activities, stipend), part-time, student or temporary/seasonal job. Sources never confirm full-time, so this is "not marked", not "full-time". The Home page's job-type tables count these. |

---

## 4. More Datasets

Summary counts, current college postings, and the reference tables behind the pay estimates and dates.

### K. K-12 Current Category Counts (`allnow.csv`)

Teaching postings in the latest update by subject group and district, with statewide totals.

| Column Name | Data Type | Source Authority | Description |
| :--- | :--- | :--- | :--- |
| `Broad_Category` | Categorical | This dashboard: teaching postings | Teaching subject group (Elementary, STEM, Special Education, Humanities, ...). Teaching postings only. |
| `Sum` | Integer | This dashboard: teaching postings | Teaching postings in that subject group at that district in the latest update. |
| `District` | String | This dashboard: teaching postings | District name, or "Total" for the statewide sum of the district rows. |

### L. K-12 Category Time Series (`allsum.csv`)

Teaching postings by subject group and district in every update, with statewide totals.

| Column Name | Data Type | Source Authority | Description |
| :--- | :--- | :--- | :--- |
| `Broad_Category` | Categorical | This dashboard: teaching postings | Teaching subject group (Elementary, STEM, Special Education, Humanities, ...). Teaching postings only. |
| `Archive_Date` | Date (YYYY-MM-DD) | This dashboard: teaching postings | Date of the update. |
| `District` | String | This dashboard: teaching postings | District name, or "Total" for the statewide sum of that update's district rows. |
| `sum` | Integer | This dashboard: teaching postings | Teaching postings in that subject group at that district in that update (distinct postings). |

### M. Higher Ed Current Category Counts (`allnow_he.csv`)

Faculty and adjunct postings in the latest update by discipline, type and college, with statewide totals.

| Column Name | Data Type | Source Authority | Description |
| :--- | :--- | :--- | :--- |
| `Category` | String | This dashboard: faculty postings | Faculty discipline (Science, Humanities, Health, ...). |
| `Job_Type` | Categorical | This dashboard: faculty postings | Instructor/Teacher/Faculty or Adjunct/Part-Time Faculty (faculty postings only). |
| `Sum` | Integer | This dashboard: faculty postings | Faculty postings of that discipline and type at that college in the latest update. |
| `Institution` | String | This dashboard: faculty postings | College name, or "Total" for the statewide sum of the college rows. |

### N. Higher Ed Category Time Series (`allsum_he.csv`)

Faculty and adjunct postings by discipline, type and college in every update, with statewide totals.

| Column Name | Data Type | Source Authority | Description |
| :--- | :--- | :--- | :--- |
| `Category` | String | This dashboard: faculty postings | Faculty discipline (Science, Humanities, Health, ...). |
| `Archive_Date` | Date (YYYY-MM-DD) | This dashboard: faculty postings | Date of the update. |
| `Institution` | String | This dashboard: faculty postings | College name, or "Total" for the statewide sum of that update's college rows. |
| `Job_Type` | Categorical | This dashboard: faculty postings | Instructor/Teacher/Faculty or Adjunct/Part-Time Faculty (faculty postings only). |
| `sum` | Integer | This dashboard: faculty postings | Faculty postings of that discipline and type at that college in that update. |

### O. Active Higher Ed Jobs (`hedata.xlsx`)

Every college posting listed in the latest update, all job types, with posted pay, campus placement and pay estimates.

| Column Name | Data Type | Source Authority | Description |
| :--- | :--- | :--- | :--- |
| `Title` | String | Job posting (college job board) | Job title as the college's board gives it. |
| `Location` | String | Job posting (college job board) | Location as the board gives it: a town on some platforms, a department on others. |
| `Posted_Date` | String | Job posting (college job board) | Posted date as the board gives it; blank where the board shows none. |
| `Institution` | String | Job posting (college job board) | College name. |
| `Link` | String | Job posting (college job board) | Link to the posting. |
| `Close_Date` | String | Job posting (college job board) | Closing date the posting page states (YYYY-MM-DD), where it gives one; PeopleAdmin boards only. |
| `Pay_Min` | Numeric | Job posting (college job board) | Lowest pay amount stated in the posting itself, in Pay_Unit (blank when the posting states no dollar figure). Never converted between units. |
| `Pay_Max` | Numeric | Job posting (college job board) | Highest pay amount stated in the posting (equals Pay_Min for a single figure). |
| `Pay_Unit` | String | Job posting (college job board) | Unit of Pay_Min and Pay_Max: hour, day, month, year, credit hour or stipend. Blank when no pay is stated, or when the stated unit is implausible for the amount. |
| `Pay_Text` | String | Job posting (college job board) | The posting text the pay was read from, kept so every figure can be checked against its source. |
| `Archive_Date` | Date (YYYY-MM-DD) | Job posting (college job board) | Date of the update that saw the posting listed (the dashboard updates twice a week since 2026-11-17, weekly before). |
| `Campus_Town` | String | Job posting (college job board) | The town the posting is mapped to when it is at a campus or site other than the college's main campus (Place_Basis other_town); blank otherwise. |
| `Campus_County` | String | Job posting (college job board) | County of Campus_Town. |
| `Campus_Latitude` | Numeric | Job posting (college job board) | Latitude of Campus_Town (Census place internal point). |
| `Campus_Longitude` | Numeric | Job posting (college job board) | Longitude of Campus_Town (Census place internal point). |
| `Place_Basis` | Categorical | Job posting (college job board) | Why the posting is mapped where it is: main (the main campus town), other_town (one other town in the state, named in its location, title or page), out_of_state, or no_town (nothing placeable, or several towns at once; shown at the main campus). |
| `Est_Pay` | Numeric | IPEDS via Urban Institute Education Data Portal | For a salaried staff posting: the college's average salary for full-time staff in the posting's IPEDS occupational category (Est_Occupation), per year. A college-wide average for the category, not this job's offer; given whether or not the posting states pay. University of Wyoming staff postings use the median salary of UW staff with the matching title in UW's salary book instead (Est_Source). |
| `Est_Pay_Unit` | String | IPEDS via Urban Institute Education Data Portal | year. |
| `Est_Occupation` | String | IPEDS via Urban Institute Education Data Portal | The IPEDS staff category the posting was matched to from its title, or, for a UW salary-book figure, the matched title and how many UW staff hold it. |
| `Est_Area` | String | IPEDS via Urban Institute Education Data Portal | The college whose figure is used. |
| `Est_Year` | String | IPEDS via Urban Institute Education Data Portal | IPEDS year, or the UW salary book's fiscal year. |
| `Est_Source` | String | IPEDS via Urban Institute Education Data Portal | IPEDS or UW salary book: where Est_Pay comes from; blank when there's no estimate. |

### P. IPEDS Staff Salaries (`ipeds_staff_salaries.csv`)

Average pay of full-time non-instructional staff by college and occupational category (categories with at least 3 staff).

| Column Name | Data Type | Source Authority | Description |
| :--- | :--- | :--- | :--- |
| `IPEDS_UNITID` | Integer | IPEDS via Urban Institute Education Data Portal | IPEDS institution id; joins to salarymap.csv. |
| `Staff_Category` | Integer | IPEDS via Urban Institute Education Data Portal | IPEDS occupational category code for full-time non-instructional staff (2 research ... 14 production and transportation). |
| `Category_Label` | String | IPEDS via Urban Institute Education Data Portal | Short name of the category. |
| `Staff_Count` | Numeric | IPEDS via Urban Institute Education Data Portal | Full-time non-instructional staff in the category. |
| `Avg_Salary` | Numeric | IPEDS via Urban Institute Education Data Portal | Average salary: total salary outlays divided by staff count, rounded. |
| `Year` | String | IPEDS via Urban Institute Education Data Portal | IPEDS year. |

### Q. K-12 Salary History (`k12_salary_history.csv`)

Teacher base salary and superintendent salary by district for each WSBA salary year this project has captured (WSBA keeps no public archive).

| Column Name | Data Type | Source Authority | Description |
| :--- | :--- | :--- | :--- |
| `District` | String | Wyoming School Boards Association (WSBA) | District name. |
| `Salary_Year` | String | Wyoming School Boards Association (WSBA) | School year of the WSBA salary document. |
| `Teacher_Base_Salary` | Currency ($) | Wyoming School Boards Association (WSBA) | Starting base salary for a teacher with a bachelor's degree and no experience (BA, step 1), from WSBA's salary settlement document. |
| `Superintendent_Salary` | Currency ($) | Wyoming School Boards Association (WSBA) | Superintendent's contracted annual salary, from WSBA's superintendent salary document. |

### R. BLS Regional Pay by Role (`oews_role_wages.csv`)

Median pay for the occupations K-12 postings are matched to, by Wyoming OEWS area; the source of the K-12 Typical pay (BLS est.) column.

| Column Name | Data Type | Source Authority | Description |
| :--- | :--- | :--- | :--- |
| `Area_Code` | String | BLS Occupational Employment and Wage Statistics (OEWS) | OEWS area code (keep as text: metro codes have leading zeros, e.g. `0013740`). |
| `Area_Name` | String | BLS Occupational Employment and Wage Statistics (OEWS) | OEWS area name: the state, a metro area, or a nonmetropolitan area. |
| `SOC` | String | BLS Occupational Employment and Wage Statistics (OEWS) | 2018 SOC code without the dash, e.g. `259045`. |
| `Occupation` | String | BLS Occupational Employment and Wage Statistics (OEWS) | OEWS occupation title. |
| `Annual_Median` | Numeric | BLS Occupational Employment and Wage Statistics (OEWS) | Annual median wage. `NA` where BLS suppresses the figure for that area. |
| `Hourly_Median` | Numeric | BLS Occupational Employment and Wage Statistics (OEWS) | Hourly median, fetched only for roles usually paid hourly; `NA` where BLS publishes none (school-year roles such as teaching assistants). |
| `Year` | String | BLS Occupational Employment and Wage Statistics (OEWS) | Reference year (May). |

### S. Posting First Seen (`posting_first_seen.csv`)

When the dashboard first found each currently listed posting; shown where the board gives no posted date.

| Column Name | Data Type | Source Authority | Description |
| :--- | :--- | :--- | :--- |
| `Segment` | Categorical | This dashboard: posting tracking | K-12 or HE. |
| `Key` | String | This dashboard: posting tracking | District or college, title and link, lowercased and joined with " / ": the key the dashboard uses to look up a posting it shows. |
| `First_Seen` | Date (YYYY-MM-DD) | This dashboard: posting tracking | First update that found the posting. The dashboard shows it where the board gives no posted date. |
| `Left_Censored` | Logical | This dashboard: posting tracking | TRUE when the posting was already listed the first time this project read that board, so it may have been up longer (shown as "on the board since at least"). |

### T. County Public School Pay (`qcew_county_school_pay.csv`)

Average annual pay and employment of public school (local government, NAICS 6111) employees by county, all roles together.

| Column Name | Data Type | Source Authority | Description |
| :--- | :--- | :--- | :--- |
| `County` | String | BLS Quarterly Census of Employment and Wages (QCEW) | "Yellowstone County" (joined to `salarymap2.csv`'s `County` with any ", State" suffix dropped). |
| `County_FIPS` | String | BLS Quarterly Census of Employment and Wages (QCEW) | Five-digit county FIPS. |
| `School_Employment` | Numeric | BLS Quarterly Census of Employment and Wages (QCEW) | Annual average employment. |
| `Avg_Annual_Pay` | Numeric | BLS Quarterly Census of Employment and Wages (QCEW) | Annual average pay per employee. |
| `Year` | String | BLS Quarterly Census of Employment and Wages (QCEW) | QCEW reference year. |

### U. UW Salary Book (`uw_salary_book.csv`)

University of Wyoming salaried staff by department and title, no names, from UW's departmental salary listing (published each fall); the source of UW staff pay estimates.

| Column Name | Data Type | Source Authority | Description |
| :--- | :--- | :--- | :--- |
| `Department` | String | University of Wyoming salary listing | Department as printed in UW's departmental salary listing. |
| `Title` | String | University of Wyoming salary listing | Job title as printed, abbreviations included ("Asst Dir", "Mgr"). No names are kept. |
| `Salary` | Numeric | University of Wyoming salary listing | Scheduled salary as of September 1: annual base plus pay for added duties. |
| `Fiscal_Year` | String | University of Wyoming salary listing | UW fiscal year of the listing, e.g. FY2026. |
| `Source_URL` | String | University of Wyoming salary listing | The PDF the rows were read from. |

### V. Source Retrieval Dates (`source_retrieved_dates.csv`)

When each outside data source was last fetched successfully.

| Column Name | Data Type | Source Authority | Description |
| :--- | :--- | :--- | :--- |
| `Source` | String | This dashboard: update log | An outside data source the dashboard uses (BLS OEWS, Census ACS, Urban IPEDS, ...). |
| `Retrieved` | Date (YYYY-MM-DD) | This dashboard: update log | Last date that source was fetched successfully; shown on the Data tab. |
