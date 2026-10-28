# Wyoming Education Jobs Dashboard — Data Dictionary & Codebook

Comprehensive variable codebook, schema definitions, and methodological provenance for datasets compiled and published by the **Wyoming Education Jobs Dashboard**.

Each dataset is accessible via the **Data Sources & Open Research Downloads** tab in the interactive web dashboard or by downloading machine-readable CSVs directly from this repository.

---

## 1. Datasets Overview

| Dataset Layer | Primary File | Description | Granularity | Refresh Cadence |
| :--- | :--- | :--- | :--- | :--- |
| **Active K-12 Jobs** | `combinedclean.csv` | All active public school job vacancies currently open across Wyoming school districts. | Posting level | Weekly |
| **K-12 Job Duration Spells** | `job_duration_spells.csv` | Longitudinal panel tracking vacancy duration (time-to-fill) and shortage dummy flags. | Posting spell | Weekly |
| **District Profiles & Benchmarks** | `salarymap2.csv` | District-level staffing, compensation benchmarks (WSBA base & WDE602 average), and Census context. | District level | Weekly / Annual |
| **WDE602 District Staffing Matrix** | `wde602_district_staff_salaries.csv` | Staff headcount, FTE, and average base/total compensation across 30+ assignment categories. | District × Role | Annual |
| **Higher Ed Institutional Profiles** | `salarymap.csv` | College and university profiles: IPEDS instructional faculty salaries, enrollment, and Pell recipient shares. | Institution level | Weekly / Annual |
| **Higher Ed Historical Postings** | `facultydata.csv` | Multi-year longitudinal postings for instructional faculty, adjuncts, and staff. | Posting level | Weekly |
| **Higher Ed Job Duration Spells** | `he_job_duration_spells.csv` | Longitudinal spell panel tracking collegiate faculty search duration (time-to-fill) and discipline flags. | Posting spell | Weekly |
| **Data Dictionary & Codebook** | `data_dictionary.csv` | Machine-readable column definitions, types, and primary source authorities across all files. | Variable level | Static / Maintained |

---

## 2. Universal Identifiers

To support seamless merges with federal, state, and academic datasets, the following universal identifiers are embedded:

- **`NCES_LEAID`**: Official 7-digit federal National Center for Education Statistics Local Education Agency identifier (e.g., `5600730` for Albany #1, `5601980` for Laramie #1). Enables 1:1 joining with the **Stanford Educational Data Archive (SEDA)**, **Civil Rights Data Collection (CRDC)**, and **Census F-33 School District Finance Survey**.
- **`IPEDS_UNITID`**: Official 6-digit federal Integrated Postsecondary Education Data System identifier (e.g., `240727` for University of Wyoming, `240505` for Casper College).
- **`District_ID`**: 6-digit Wyoming Department of Education state district identification code.

---

## 3. Data Dictionary: Detailed Variable Definitions

### A. Active K-12 Job Vacancies (`combinedclean.csv`)
*Current active openings, updated weekly.*

| Column Name | Data Type | Source Authority | Description |
| :--- | :--- | :--- | :--- |
| `title` | String | District Job Board | Job vacancy title as published by the school district or charter school. |
| `date_posted` | String / Date | District Job Board | Original posted date string as published on the district applicant tracking board. |
| `position` | Categorical | Classifier | Broad occupational classification (Teacher, Administration, Support Services, etc.). |
| `location` | String | District Job Board | Specific school building, school campus, facility, or central administrative office. |
| `url` | URL | District Job Board | Direct URL link to the official job vacancy listing or online application portal. |
| `posting_id` | String | Project Key | Durable posting fingerprint used to track unique openings longitudinally across weekly scrapers. |
| `District` | String | Canonical Registry | Canonical public school district or charter school Local Education Agency (LEA) name. |
| `Category` | String | Classifier | Fine-grained subject specialization or departmental role assignment. |
| `Broad_Category` | Categorical | Classifier | High-level clustered role grouping (Elementary, STEM, Special Education, Humanities, etc.). |
| `Role_Avg_Salary` | Currency ($) | WDE602 Staff Matrix | District benchmark average total compensation for this specific job classification. |
| `Role_Avg_Salary_Note` | String | WDE602 Staff Matrix | Tag indicating which staff assignment group benchmark applies (e.g., Admin, Aide, Bus, Maint, Food). |

---

### B. K-12 Job Duration & Shortage Spells Panel (`job_duration_spells.csv`)
*Longitudinal spell panel tracking vacancy duration and subject-area shortages. Essential for labor economists and empirical policy analysts.*

| Column Name | Data Type | Source Authority | Description |
| :--- | :--- | :--- | :--- |
| `District` | String | Canonical Registry | Canonical public school district or charter school name. |
| `NCES_LEAID` | String (7-digit) | NCES CCD | Federal NCES 7-digit Local Education Agency identifier. |
| `Title` | String | District Job Board | Standardized job vacancy title. |
| `Position` | Categorical | Classifier | Broad staff position group (Teacher, Administrator, Support Services). |
| `Category` | String | Classifier | Fine-grained subject area or functional assignment. |
| `Broad_Category` | Categorical | Classifier | High-level clustered subject or role category. |
| `First_Seen_Date` | Date (YYYY-MM-DD) | Project Scraper | Earliest weekly scraper run in which this job posting was observed active. |
| `Last_Seen_Date` | Date (YYYY-MM-DD) | Project Scraper | Latest weekly scraper run in which this job posting was observed active. |
| `Weeks_Observed` | Integer | Project Scraper | Total count of weekly snapshots where this posting was present. |
| `Estimated_Days_Open` | Integer | Derived Metric | Estimated calendar duration of the vacancy (proxy for labor shortage / time-to-fill). |
| `Status` | Categorical | Derived Metric | State of posting: `Closed / Filled` or `Still Active` as of the latest pipeline run. |
| `is_stem` | Binary (0/1) | Taxonomy Indicator | Dummy indicator: 1 if position is Science, Technology, Engineering, or Math; 0 otherwise. |
| `is_sped` | Binary (0/1) | Taxonomy Indicator | Dummy indicator: 1 if position is Special Education; 0 otherwise. |
| `is_elementary` | Binary (0/1) | Taxonomy Indicator | Dummy indicator: 1 if position is Elementary Education; 0 otherwise. |
| `is_secondary` | Binary (0/1) | Taxonomy Indicator | Dummy indicator: 1 if position is Middle or High School; 0 otherwise. |
| `is_admin` | Binary (0/1) | Taxonomy Indicator | Dummy indicator: 1 if position is Administration, Principal, or Superintendent; 0 otherwise. |
| `is_support_staff` | Binary (0/1) | Taxonomy Indicator | Dummy indicator: 1 if position is Paraprofessional, Aide, Custodial, Bus, or Food Service; 0 otherwise. |

---

### C. District Profiles & Socioeconomic Context (`salarymap2.csv`)
*District-level profiles combining compensation surveys, federal CCD staffing, and Census economic indicators.*

| Column Name | Data Type | Source Authority | Description |
| :--- | :--- | :--- | :--- |
| `District` | String | Canonical Registry | Canonical public school district or charter school name. |
| `NCES_LEAID` | String (7-digit) | NCES CCD | Federal NCES 7-digit Local Education Agency identifier. |
| `County` | String | US Census Bureau | Primary county in which the district central administrative office is located. |
| `Latitude` / `Longitude` | Decimal Degrees | US Census / Geocoding | Geographic coordinates of district central headquarters. |
| `Job_Link` | URL | District Registry | Official employment or applicant tracking portal link for the district. |
| `Teacher_Base_Salary` | Currency ($) | WSBA Survey | Published starting base salary for a certified teacher with a BA and Step 1 experience. |
| `Teacher_Base_Salary_Prior_Year` | Currency ($) | WSBA Survey | Published starting base salary for BA Step 1 in the preceding academic year. |
| `Salary_Year` | String | WSBA Survey | Academic school year corresponding to the published WSBA base salary survey. |
| `Teacher_Avg_Salary` | Currency ($) | WDE602 Collection | Actual average total compensation across all certified classroom teachers in the district. |
| `Teacher_Avg_Base_Salary` | Currency ($) | WDE602 Collection | Actual average base contract salary across all certified classroom teachers in the district. |
| `WDE_Salary_Year` | String | WDE602 Collection | Academic school year corresponding to the WDE602 certified staff collection. |
| `Superintendent_Salary` | Currency ($) | WSBA Survey | Contracted annual salary of the district superintendent. |
| `Superintendent_Contract_Days` | Integer | WSBA Survey | Annual contracted working days for the district superintendent. |
| `Teachers_Total_FTE` | Numeric | NCES CCD via Urban Inst | Total full-time-equivalent certified classroom teachers employed by the district. |
| `Enrollment` | Integer | NCES CCD via Urban Inst | Total pre-K through grade 12 student enrollment count. |
| `CCD_Year` | Integer | NCES CCD | Data collection school year for federal CCD staffing and enrollment counts. |
| `Median_Household_Income` | Currency ($) | US Census ACS 5-Year | County median annual household income in inflation-adjusted dollars. |
| `Median_Gross_Rent` | Currency ($) | US Census ACS 5-Year | County median monthly gross rent including estimated utilities. |
| `Population` | Integer | US Census ACS 5-Year | Total estimated resident population of the county. |
| `Mining_Employment_Share` | Proportion (0-1) | US Census ACS 5-Year | Share of county civilian employed labor force in agriculture, forestry, mining, and energy extraction. |
| `Population_Change_Pct` | Proportion | US Census ACS 5-Year | County 5-year percentage change in total resident population. |
| `Child_Poverty_Rate` | Proportion (0-1) | US Census SAIPE | Estimated share of school-age children (ages 5-17) living in families below the federal poverty line. |
| `SAIPE_Year` | Integer | US Census SAIPE | Release year of federal Small Area Income and Poverty Estimates data. |
| `Data_Coverage` | Categorical | Project Methodology | Scraper coverage fidelity: `Full` (direct ATS integration) vs `Partial` (heuristic site scrape). |

---

### D. WDE602 District Staffing Matrix (`wde602_district_staff_salaries.csv`)
*Wyoming Department of Education certified and classified staff compensation matrix.*

| Column Name | Data Type | Source Authority | Description |
| :--- | :--- | :--- | :--- |
| `School_Year` | String | Wyoming Dept of Ed | State reporting academic year for the WDE602 staff member collection. |
| `District_ID` | Integer | Wyoming Dept of Ed | Official 6-digit WDE state district identification number. |
| `District_Name` | String | Wyoming Dept of Ed | District name as reported in official WDE collections (e.g., 'Albany #1'). |
| `District` | String | Project Canonical | Project canonical district name matching `salarymap2.csv` and job tables. |
| `NCES_LEAID` | String (7-digit) | NCES CCD | Federal NCES 7-digit Local Education Agency identifier. |
| `Group_Name` | String | Wyoming Dept of Ed | Staff assignment code group (Teachers, Principals, Aides, Bus Drivers, Custodians, Food Service). |
| `Total_FTE` | Numeric | Wyoming Dept of Ed | Total full-time-equivalent employees employed in that specific assignment group. |
| `Average_Base_Salary` | Currency ($) | Wyoming Dept of Ed | Average contracted base salary for staff in that assignment group. |
| `Average_Total_Salary` | Currency ($) | Wyoming Dept of Ed | Average total compensation including stipends and benefits adjustments for staff in that assignment group. |

---

### E. Higher Education Institutional Profiles (`salarymap.csv`)
*Profiles for Wyoming's public community colleges and the University of Wyoming.*

| Column Name | Data Type | Source Authority | Description |
| :--- | :--- | :--- | :--- |
| `Name` | String | IPEDS Directory | Official legal institution name of the public college or university. |
| `IPEDS_UNITID` | String / Integer | NCES IPEDS | Official 6-digit federal NCES Integrated Postsecondary Education Data System Unit ID. |
| `County` | String | US Census Bureau | County in which the collegiate campus is located. |
| `Latitude` / `Longitude` | Decimal Degrees | IPEDS Directory | Geographic coordinates of campus centroid. |
| `Faculty_Avg_Salary` | Currency ($) | NCES IPEDS via Urban Inst | Average full-time instructional faculty salary across all academic ranks combined. |
| `Faculty_Avg_Salary_Professor` | Currency ($) | NCES IPEDS via Urban Inst | Average full-time instructional faculty salary for the Full Professor rank. |
| `Faculty_Count` | Integer | NCES IPEDS via Urban Inst | Total count of full-time instructional faculty employed by the institution. |
| `Salary_Year` | String / Integer | NCES IPEDS | Academic reporting year for IPEDS faculty compensation data. |
| `Enrollment` | Integer | NCES IPEDS | Total unduplicated fall student enrollment count. |
| `Pell_Recipient_Share` | Proportion (0-1) | US Dept of Ed FSA | Share of undergraduate degree-seeking students awarded federal need-based Pell Grants. |

---

### F. Higher Education Historical Postings (`facultydata.csv`)
*Longitudinal academic and administrative vacancies across higher education institutions.*

| Column Name | Data Type | Source Authority | Description |
| :--- | :--- | :--- | :--- |
| `Title` | String | Institutional Board | Published higher education job vacancy title. |
| `Institution` | String | IPEDS Directory | Collegiate institution name. |
| `Location` | String | Institutional Board | Campus location or city. |
| `Appointment` | Categorical | Classifier | Position appointment category (Faculty/Instructor non-adjunct, Adjunct/Part-Time, Other/Staff). |
| `Category` | String | Classifier | Academic discipline or administrative functional area. |
| `Archive_Date` | Date (YYYY-MM-DD) | Project Scraper | Snapshot observation date when the posting was captured open. |
| `Link` | URL | Institutional Board | Direct web URL to the employment vacancy listing. |

---

### G. Higher Education Job Duration Spells Panel (`he_job_duration_spells.csv`)
*Longitudinal spell panel tracking vacancy duration, search persistence, and academic disciplines across colleges and universities.*

| Column Name | Data Type | Source Authority | Description |
| :--- | :--- | :--- | :--- |
| `Institution` | String | IPEDS Directory | Collegiate institution name. |
| `IPEDS_UNITID` | String (6-digit) | NCES IPEDS | Official 6-digit federal NCES Integrated Postsecondary Education Data System Unit ID. |
| `Title` | String | Institutional Board | Standardized collegiate job vacancy title. |
| `Category` | String | Classifier | Academic discipline or functional assignment area. |
| `Job_Type` | Categorical | Classifier | Collegiate appointment type (Instructor/Teacher/Faculty or Adjunct/Part-Time Faculty). |
| `First_Seen_Date` | Date (YYYY-MM-DD) | Project Scraper | Earliest weekly scraper run in which this job posting was observed active. |
| `Last_Seen_Date` | Date (YYYY-MM-DD) | Project Scraper | Latest weekly scraper run in which this job posting was observed active. |
| `Weeks_Observed` | Integer | Project Scraper | Total count of weekly snapshots where this posting was present. |
| `Estimated_Days_Open` | Integer | Derived Metric | Estimated calendar duration of the vacancy (proxy for search length and time-to-fill). |
| `Status` | Categorical | Derived Metric | State of posting: `Closed / Filled` or `Still Active` as of the latest pipeline run. |
| `is_stem` | Binary (0/1) | Taxonomy Indicator | Dummy indicator: 1 if position is Science, Technology, Engineering, or Math; 0 otherwise. |
| `is_health` | Binary (0/1) | Taxonomy Indicator | Dummy indicator: 1 if position is Health Sciences, Nursing, or Medical; 0 otherwise. |
| `is_cte` | Binary (0/1) | Taxonomy Indicator | Dummy indicator: 1 if position is Career & Technical Education; 0 otherwise. |
| `is_adjunct` | Binary (0/1) | Taxonomy Indicator | Dummy indicator: 1 if appointment is Adjunct or Part-Time Faculty; 0 otherwise. |
| `is_faculty` | Binary (0/1) | Taxonomy Indicator | Dummy indicator: 1 if appointment is Full-Time or Regular Instructional Faculty; 0 otherwise. |

---

## 4. Citation Guidance

If you utilize these datasets in academic papers, policy briefs, or journalistic reporting, please use the following citation:

```bibtex
@misc{bostick_perkins_2026_wyoming,
  author = {Bostick, Michael and Perkins, Mark},
  title = {Wyoming Education Jobs Dashboard: Longitudinal Staffing Demand, Compensation, and Socioeconomic Context},
  year = {2026},
  publisher = {GitHub},
  howpublished = {\url{https://github.com/bostickmike/Wyoming-Education-Jobs-Dashboard}}
}
```
