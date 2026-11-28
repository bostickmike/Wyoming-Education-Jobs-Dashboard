library(shiny)
library(bslib)
library(shinyWidgets)
library(tidyverse)
library(DT)
library(data.table)
library(leaflet)
library(plotly)
library(scales)
library(stringr)
library(readxl)
library(shinycssloaders)
# Shared helpers (pay and date text, sparklines, trends, job search, first-seen fill): bostickmike/edjobs at the
# version in ../EDJOBS_VERSION (package phase 6, 2026-11-16). The deploy manifest records it as a GitHub package.
library(edjobs)
FEEDBACK_REPO_DEFAULT <- "bostickmike/Wyoming-Education-Jobs-Dashboard"

#--------------------------------------------------
# Schema guard -- if a pipeline chunk ever silently drops or renames a
# column app.R references by name, the failure mode used to be a bare
# "object 'Teachers_Total_FTE' not found" crash for the first user who
# opened the dashboard after a bad deploy, with nothing identifying which
# upstream FILE was actually responsible. The real prevention lives in
# schema_check.R + .github/scripts/verify_schema.R at the repo root, which
# blocks a schema-broken commit from ever reaching this deployed app in the
# first place -- but this app folder is deployed standalone (Connect Cloud
# only bundles Wy_Ed_Jobs/, not the repo root), so it can't source that
# file directly. validate_and_pad_schema() is the deployed app's own last
# line of defense: any dataset actually missing an expected column gets
# that column backfilled with NA (so downstream mutate/select references
# don't hard-crash the whole app for every feature) and the problem is
# recorded in DATA_LOAD_ISSUES for a visible Home-tab banner instead of a
# silent blank field or an opaque stack trace.
#--------------------------------------------------
DATA_LOAD_ISSUES <- character(0)
# validate_and_pad_schema() (edjobs) reports a file's missing columns through this.
note_load_issue <- function(msg) DATA_LOAD_ISSUES <<- c(DATA_LOAD_ISSUES, msg)


first_seen_table <- tryCatch(read.csv("posting_first_seen.csv", colClasses = "character", fileEncoding = "UTF-8"),
                             error = function(e) NULL, warning = function(w) NULL)
# Some WY college boards (LCCC, Gillette, Central Wyoming, Casper: 114 of 470
# postings on 2026-11-06) print the posted date relative to the scrape day
# ("Posted 3 weeks ago", "Posted more than 30 days ago"). Shown as written,
# that text goes stale during the week and never ages into "Listed since".
# Dated back from the run instead, as parse_wy_posted_date() in
# posting_spells.R does: "About <date>"; "more than N days ago" gives only an
# upper bound, "Before <date>", or the week we first saw it when earlier.
relative_posted_label <- function(posted, run_date, first_seen = NA) {
  out <- as.character(posted)
  s <- sub("^posted ", "", tolower(trimws(gsub("\\s+", " ", out))))
  exact <- !is.na(s) & grepl("^(today|\\d+ (hour|day|week|month)s? ago)$", s)
  n <- suppressWarnings(as.numeric(sub("^(\\d+).*", "\\1", s)))
  n[s %in% "today"] <- 0
  unit <- ifelse(grepl("week", s), 7, ifelse(grepl("month", s), 30, ifelse(grepl("day", s), 1, 0)))
  out[exact] <- paste("About", format(run_date - n[exact] * unit[exact]))
  more <- !is.na(s) & grepl("^more than \\d+ days? ago$", s)
  if (any(more)) {
    bound <- run_date - as.numeric(sub("^more than (\\d+).*", "\\1", s[more]))
    seen <- suppressWarnings(as.Date(rep_len(first_seen, length(out))[more]))
    bound <- as.Date(ifelse(!is.na(seen) & seen < bound, seen, bound), origin = "1970-01-01")
    out[more] <- paste("Before", format(bound))
  }
  out
}
first_seen_date <- function(district, title, url, segment, lookup = first_seen_table) {
  if (is.null(lookup) || !all(c("Segment", "Key", "First_Seen") %in% names(lookup))) return(rep(NA_character_, length(title)))
  lookup <- lookup[lookup$Segment == segment, , drop = FALSE]
  lookup$First_Seen[match(first_seen_key(district, title, url), lookup$Key)]
}
POSTED_LISTED_NOTE <- paste0(
  "Posted / listed is the date the posting gives. Where the job board gives none, it shows the first week this ",
  "dashboard found the posting (\"First seen\"), or \"On the board since at least\" when the posting was already up ",
  "the first time this dashboard checked that board. \"About <date>\" and \"Before <date>\" are dates worked out from a board ",
  "that says \"Posted 3 weeks ago\" or \"more than 30 days ago\". ")


# Same for higher-ed staff postings: the institution's IPEDS average for the
# posting's staff category ("IPEDS average for full-time management staff,
# Casper College"), or for UW the median in its own salary book ("Median
# FY2026 salary of UW staff titled Business Manager (40 UW staff), UW
# salary book").
format_he_estimate <- function(est_pay, est_unit, category, institution, year, source, has_posted_pay) {
  tooltip <- ifelse(!is.na(source) & source == "UW salary book",
                    paste0("Median ", year, " salary of UW staff titled ", category, ", UW salary book"),
                    paste0("IPEDS average for full-time ", category, " staff, ", institution))
  format_pay_estimate(est_pay, est_unit, tooltip, has_posted_pay)
}


# Map pay bands. Each posting is compared in its own unit -- an hourly wage
# is never turned into an annual one -- so day rates, stipends and per-credit
# pay appear only under "All".
PAY_BANDS <- list(
  hour_lt18  = list(unit = "hour", lo = 0,     hi = 18,    label = "under $18/hr"),
  hour_18_25 = list(unit = "hour", lo = 18,    hi = 25,    label = "$18\u201325/hr"),
  hour_25p   = list(unit = "hour", lo = 25,    hi = Inf,   label = "$25+/hr"),
  year_lt60  = list(unit = "year", lo = 0,     hi = 60000, label = "under $60k/yr"),
  year_60_70 = list(unit = "year", lo = 60000, hi = 70000, label = "$60\u201370k/yr"),
  year_70p   = list(unit = "year", lo = 70000, hi = Inf,   label = "$70k+/yr")
)


#--------------------------------------------------
# Load K-12 data
#--------------------------------------------------
combineddata <- read.csv("combinedclean.csv", fileEncoding = "UTF-8")
# Posted-pay columns are optional (absent from files written before the
# pipeline captured pay) -- padded here rather than in validate_and_pad_schema(),
# which would flag their absence as a schema problem on the Home tab.
# The BLS estimate columns (Est_*) are optional the same way.
for (col in c("Pay_Min", "Pay_Max", "Pay_Unit", "Pay_Text",
              "Est_Pay", "Est_Pay_Unit", "Est_Occupation", "Est_Area", "Est_Year", "Role_Hint")) {
  if (!col %in% names(combineddata)) combineddata[[col]] <- NA
}
oews_year <- na.omit(combineddata$Est_Year)[1]
combineddata <- combineddata %>%
  validate_and_pad_schema(c("District", "title", "position", "location", "date_posted", "url", "Posting_ID"), "combinedclean.csv",
                          on_missing = note_load_issue) %>%
  mutate(`Posted Pay` = format_posted_pay(Pay_Min, Pay_Max, Pay_Unit),
         `Typical pay (BLS est.)` = format_bls_estimate(Est_Pay, Est_Pay_Unit, Est_Occupation, Est_Area, !is.na(Pay_Min)),
         # Home page job-type tables: TRUE unless edjobs classify_work_schedule() marks the posting as a substitute,
         # extra duty, part-time, student or temporary job (the same call as the pipeline's
         # k12_jobtype_weekly_totals.csv, so the counts agree; WY has no role hints, so Role_Hint is NA).
         .Not_Marked = is.na(classify_work_schedule(title, k12_position = position, role_hint = Role_Hint))) %>%
  select(District, title, position, location, `Posted Pay`, `Typical pay (BLS est.)`, date_posted, url,
         Posting_ID, Pay_Min, Pay_Max, Pay_Unit, Est_Pay, Est_Pay_Unit, .Not_Marked) %>%
  mutate(District = str_squish(as.character(District))) %>%
  mutate(date_posted = format_posted_or_listed_date(date_posted)) %>%
  mutate(date_posted = fill_first_seen(date_posted, District, title, url, "K-12", lookup = first_seen_table)) %>%
  arrange(District, title) %>%
  mutate(url = paste0('<a href="', url, '" target="_blank">', url, '</a>')) %>%
  rename(Title = title, Position = position, Location = location,
         `Posted / listed` = date_posted, Link = url)

# BLS QCEW average pay of public school employees by county, all roles (the
# pipeline's qcew_county_school_pay.csv); county context in the map popup.
# Optional: counties BLS withholds, or a missing file, show nothing.
qcew_school_pay <- if (file.exists("qcew_county_school_pay.csv")) {
  read.csv("qcew_county_school_pay.csv", stringsAsFactors = FALSE, colClasses = c(Year = "character"))
} else {
  data.frame(County = character(0), Avg_Annual_Pay = numeric(0), Year = character(0))
}

mapdata2_k12 <- read.csv("salarymap2.csv", fileEncoding = "UTF-8")
# Optional columns (absent before the first run that writes them, 2026-11-09):
# padded here rather than in validate_and_pad_schema(), which would flag their
# absence as a data problem on the Home tab.
# Child_Poverty_Low / _High: Census's approximate 90% range (edjobs 0.27.0, first written by the run after 2026-11-15).
for (col in c("Child_Poverty_Basis", "Free_Reduced_Lunch_Share", "FRL_Year", "Child_Poverty_Low", "Child_Poverty_High",
               "Median_Household_Income_MOE", "Median_Gross_Rent_MOE", "Mining_Employment_Share_MOE")) {
  if (!col %in% names(mapdata2_k12)) mapdata2_k12[[col]] <- NA
}
mapdata2_k12 <- mapdata2_k12 %>%
  validate_and_pad_schema(c("District", "County", "Latitude", "Longitude", "Job_Link",
                             "Teacher_Base_Salary", "Teacher_Base_Salary_Prior_Year", "Salary_Year",
                             "Superintendent_Salary", "Superintendent_Contract_Days", "Salary_Source",
                             "Teachers_Total_FTE", "Data_Coverage", "Enrollment",
                             "Median_Household_Income", "Median_Gross_Rent", "Mining_Employment_Share",
                             "Population_Change_Pct", "ACS_Year", "Child_Poverty_Rate", "SAIPE_Year",
                             "Teacher_Avg_Salary"),
                           "salarymap2.csv", on_missing = note_load_issue) %>%
  rename(Name = District)

# District salary lookup for the Jobs Table
k12_salary_lookup <- mapdata2_k12 %>%
  select(Name, Teacher_Base_Salary, Teacher_Base_Salary_Prior_Year, Teacher_Avg_Salary) %>%
  mutate(
    `District Starting Base` = ifelse(
      is.na(Teacher_Base_Salary),
      "—",
      scales::dollar(Teacher_Base_Salary, accuracy = 1)
    )
  )

# Role-specific WDE salary lookup for K-12 Jobs Table
# Maps job position/title to its specific assignment-category benchmark in WDE602
wde_staff_file <- "wde602_district_staff_salaries.csv"
if (file.exists(wde_staff_file)) {
  wde_staff <- read.csv(wde_staff_file, fileEncoding = "UTF-8", stringsAsFactors = FALSE)
  canonicalize_wde_dist <- function(name) {
    name <- trimws(name)
    m <- regmatches(name, regexec("^(.+?)\\s*#(\\d+)$", name))
    vapply(m, function(parts) {
      if (length(parts) != 3) return(parts[1])
      county <- parts[2]
      num <- parts[3]
      if (county %in% c("Big Horn", "Natrona")) {
        paste0(county, " School District ", num)
      } else {
        paste0(county, " County School District ", num)
      }
    }, character(1))
  }
  wde_staff$canon_district <- canonicalize_wde_dist(wde_staff$District_Name)
  wde_staff$Salary_Num <- suppressWarnings(as.numeric(wde_staff$Average_Total_Salary))

  map_pos_to_wde_group <- function(pos, title) {
    pos_l <- tolower(pos)
    title_l <- tolower(title)
    case_when(
      pos_l %in% c("teacher", "part-time teacher") ~ "SUBTOTAL Instructional Staff Teachers",
      pos_l == "administration" ~ "School Building Administrators",
      pos_l == "paraprofessional" ~ "Instructional Aides",
      pos_l == "transportation" ~ "School Bus Drivers",
      pos_l == "custodial/maintenance" ~ "Operation and Maintenance",
      pos_l == "food services" ~ "Food Service Staff",
      pos_l == "staff" ~ "School Secretary/Clerical Support",
      pos_l == "support services" & grepl("counselor", title_l) ~ "TOTAL Counselors",
      pos_l == "support services" ~ "Student Support Staff -- Professional",
      # Substitutes (daily rate), coaches (stipends), child care and
      # unclassified postings have no WDE602 counterpart -- leave them blank
      # rather than showing the teacher average.
      TRUE ~ NA_character_
    )
  }

  combineddata <- combineddata %>%
    mutate(WDE_Group = map_pos_to_wde_group(Position, Title)) %>%
    left_join(
      wde_staff %>%
        filter(!is.na(canon_district) & !is.na(Salary_Num) & Salary_Num > 0) %>%
        select(canon_district, Group_Name, Salary_Num),
      by = c("District" = "canon_district", "WDE_Group" = "Group_Name")
    ) %>%
    left_join(k12_salary_lookup, by = c("District" = "Name")) %>%
    mutate(
      Role_Suffix = case_when(
        WDE_Group == "School Building Administrators" ~ " (Admin)",
        WDE_Group == "Instructional Aides" ~ " (Aide)",
        WDE_Group == "School Bus Drivers" ~ " (Bus)",
        WDE_Group == "Operation and Maintenance" ~ " (Maint)",
        WDE_Group == "Food Service Staff" ~ " (Food)",
        WDE_Group == "School Secretary/Clerical Support" ~ " (Clerical)",
        WDE_Group == "TOTAL Counselors" ~ " (Counselor)",
        WDE_Group == "Student Support Staff -- Professional" ~ " (Support)",
        TRUE ~ ""
      ),
      is_teacher_row = Position %in% c("Teacher", "Part-Time Teacher"),
      # Only a teacher row may fall back to the district teacher average; any
      # other role without its own WDE602 figure stays blank.
      Final_Salary = ifelse(is_teacher_row, coalesce(Salary_Num, Teacher_Avg_Salary), Salary_Num),
      `Teacher Starting Base` = ifelse(is_teacher_row, `District Starting Base`, "—"),
      `Role Avg Salary` = ifelse(
        is.na(Final_Salary),
        "—",
        paste0(scales::dollar(round(Final_Salary), accuracy = 1), ifelse(is.na(Salary_Num), "", Role_Suffix))
      ),
      # Figure for the map's pay bands: posted pay, else the WDE602 role
      # figure (the district teacher average on a teaching posting), else
      # the BLS estimate.
      .Pay_Value = posting_pay_value(Pay_Min, Pay_Max, Pay_Unit, coalesce(Final_Salary, Est_Pay),
                                     ifelse(!is.na(Final_Salary), "year", Est_Pay_Unit))$value,
      .Pay_Unit = posting_pay_value(Pay_Min, Pay_Max, Pay_Unit, coalesce(Final_Salary, Est_Pay),
                                    ifelse(!is.na(Final_Salary), "year", Est_Pay_Unit))$unit
    ) %>%
    select(District, Title, Position, Location, `Posted Pay`, `Typical pay (BLS est.)`, `Teacher Starting Base`,
           `Role Avg Salary`, `Posted / listed`, Link, Posting_ID, .Pay_Value, .Pay_Unit, .Not_Marked)
} else {
  combineddata <- combineddata %>%
    left_join(k12_salary_lookup, by = c("District" = "Name")) %>%
    mutate(
      is_teacher_row = Position %in% c("Teacher", "Part-Time Teacher"),
      `Role Avg Salary` = ifelse(
        !is_teacher_row | is.na(Teacher_Avg_Salary),
        "—",
        scales::dollar(Teacher_Avg_Salary, accuracy = 1)
      ),
      `Teacher Starting Base` = ifelse(is_teacher_row, `District Starting Base`, "—"),
      .fallback_value = ifelse(is_teacher_row & !is.na(Teacher_Avg_Salary), Teacher_Avg_Salary, Est_Pay),
      .fallback_unit = ifelse(is_teacher_row & !is.na(Teacher_Avg_Salary), "year", Est_Pay_Unit),
      .Pay_Value = posting_pay_value(Pay_Min, Pay_Max, Pay_Unit, .fallback_value, .fallback_unit)$value,
      .Pay_Unit = posting_pay_value(Pay_Min, Pay_Max, Pay_Unit, .fallback_value, .fallback_unit)$unit
    ) %>%
    select(District, Title, Position, Location, `Posted Pay`, `Typical pay (BLS est.)`, `Teacher Starting Base`,
           `Role Avg Salary`, `Posted / listed`, Link, Posting_ID, .Pay_Value, .Pay_Unit, .Not_Marked)
}

# Weekly ALL-category posting totals per district/institution (not scoped
# to Teacher/Faculty like k12_history/he_history below) -- powers the
# sparkline trend next to each entity's raw count on the Top Hiring
# tables, matching that same all-category count rather than a
# teacher/faculty-only proxy that wouldn't line up with the number shown.
# Twice-weekly runs (2026-11-17): every history file the charts read is rolled up to each ISO week's last run
# (latest_snapshot_per_week()), so a chart has one point a week and "new this week" compares with a week ago.
k12_district_weekly_totals <- read.csv("k12_district_weekly_totals.csv", fileEncoding = "UTF-8") %>%
  validate_and_pad_schema(c("District", "Archive_Date", "n", "n_not_marked"), "k12_district_weekly_totals.csv", on_missing = note_load_issue) %>%
  mutate(Archive_Date = as.Date(Archive_Date)) %>%
  latest_snapshot_per_week()
he_institution_weekly_totals <- read.csv("he_institution_weekly_totals.csv", fileEncoding = "UTF-8") %>%
  validate_and_pad_schema(c("Institution", "Archive_Date", "n", "n_not_marked"), "he_institution_weekly_totals.csv", on_missing = note_load_issue) %>%
  mutate(Archive_Date = as.Date(Archive_Date)) %>%
  latest_snapshot_per_week()
# Per-run totals by job type (edjobs jobtype_run_totals()), for the Home page's job-type sparklines.
read_jobtype_totals <- function(f) {
  read.csv(f, fileEncoding = "UTF-8", stringsAsFactors = FALSE) %>%
    validate_and_pad_schema(c("Job_Type", "Archive_Date", "n", "n_not_marked"), f, on_missing = note_load_issue) %>%
    mutate(Archive_Date = as.Date(Archive_Date)) %>%
    latest_snapshot_per_week()
}
k12_jobtype_weekly_totals <- read_jobtype_totals("k12_jobtype_weekly_totals.csv")
he_jobtype_weekly_totals <- read_jobtype_totals("he_jobtype_weekly_totals.csv")
# Columns the app uses but never shows or exports.
HIDDEN_COLS <- c(".Pay_Value", ".Pay_Unit", ".Map_Name", ".Job_Type", ".Not_Marked")
# The Jobs tables' "Showing:" line when a Home click carried the switch with it.
NOT_MARKED_SHOWING <- "excluding substitutes, coaching and postings marked part-time, student or temporary"
NOT_MARKED_SHOWING_HE <- "excluding adjunct, part-time, student and temporary postings"

data_dictionary <- if (file.exists("data_dictionary.csv")) {
  read.csv("data_dictionary.csv", stringsAsFactors = FALSE)
} else {
  data.frame(Dataset = character(0), File_Name = character(0), Column_Name = character(0),
             Data_Type = character(0), Primary_Authority = character(0), Definition = character(0))
}


job_duration_spells <- if (file.exists("job_duration_spells.csv")) {
  relabel_spell_status(read.csv("job_duration_spells.csv", fileEncoding = "UTF-8", stringsAsFactors = FALSE))
} else {
  data.frame()
}

he_job_duration_spells <- if (file.exists("he_job_duration_spells.csv")) {
  relabel_spell_status(read.csv("he_job_duration_spells.csv", fileEncoding = "UTF-8", stringsAsFactors = FALSE))
} else {
  data.frame()
}


k12sum <- read.csv("allsum.csv", fileEncoding = "UTF-8") %>%
  validate_and_pad_schema(c("Broad_Category", "Archive_Date", "District", "sum"), "allsum.csv", on_missing = note_load_issue) %>%
  mutate(District = str_squish(as.character(District)),
         Broad_Category = dplyr::recode(Broad_Category,
                                        "English Language Arts Secondary" = "Engl. LA",
                                        "Secondary Social Studies" = "Soc. St.",
                                        "Special Education - General" = "SpEd - General",
                                        "Special Education - Resource/Life Skills" = "SpEd - Resource/LS",
                                        "CTE - Trades, Ag & Technical" = "CTE - Trades/Ag",
                                        "CTE - Business & Family Sciences" = "CTE - Biz/Family")) %>%
  filter(Broad_Category != "Other")

k12sum$Archive_Date <- as.Date(k12sum$Archive_Date)
k12sum <- latest_snapshot_per_week(k12sum)

# The source aggregation (group_by + summarize) only produces a row for a
# Broad_Category/Archive_Date/District combination that actually had at
# least one posting -- a week with zero postings for a category is simply
# absent, not an explicit 0. geom_line() then draws straight through that
# gap, silently connecting the surrounding weeks and making it look like
# the count never dropped. tidyr::complete() fills every combination that
# doesn't exist with a real 0 so the line actually dips.
k12sum <- k12sum %>%
  tidyr::complete(Broad_Category, Archive_Date, District, fill = list(sum = 0))


k12nowsum <- read.csv("allnow.csv", fileEncoding = "UTF-8") %>%
  validate_and_pad_schema(c("Broad_Category", "Sum", "District"), "allnow.csv", on_missing = note_load_issue) %>%
  mutate(Broad_Category = dplyr::recode(Broad_Category,
                                        "English Language Arts Secondary" = "Engl. LA",
                                        "Secondary Social Studies" = "Soc. St.",
                                        "Special Education - General" = "SpEd - General",
                                        "Special Education - Resource/Life Skills" = "SpEd - Resource/LS",
                                        "CTE - Trades, Ag & Technical" = "CTE - Trades/Ag",
                                        "CTE - Business & Family Sciences" = "CTE - Biz/Family"),
         District = str_squish(iconv(District, from = "", to = "UTF-8"))) %>%
  filter(Broad_Category != "Other")

#--------------------------------------------------
# Load Higher Ed data
#--------------------------------------------------
ccdata <- read_xlsx("hedata.xlsx")
# Optional posted-pay columns, padded the same way as combinedclean.csv's.
for (col in c("Pay_Min", "Pay_Max", "Pay_Unit", "Pay_Text",
              "Est_Pay", "Est_Pay_Unit", "Est_Occupation", "Est_Area", "Est_Year", "Est_Source",
              "Campus_Town", "Campus_County", "Campus_Latitude", "Campus_Longitude", "Place_Basis")) {
  if (!col %in% names(ccdata)) ccdata[[col]] <- NA
}
# Typed, so a file written before the placement columns existed still joins.
for (col in c("Campus_Town", "Campus_County", "Place_Basis")) ccdata[[col]] <- as.character(ccdata[[col]])
for (col in c("Campus_Latitude", "Campus_Longitude")) ccdata[[col]] <- as.numeric(ccdata[[col]])
he_run_date <- suppressWarnings(max(as.Date(substr(as.character(ccdata$Archive_Date), 1, 10)), na.rm = TRUE))
if (!is.finite(he_run_date)) he_run_date <- Sys.Date()
ccdata <- ccdata %>%
  validate_and_pad_schema(c("Institution", "Title", "Location", "Posted_Date", "Link"), "hedata.xlsx", on_missing = note_load_issue) %>%
  mutate(`Posted Pay` = format_posted_pay(Pay_Min, Pay_Max, Pay_Unit),
         `Typical pay (est.)` = format_he_estimate(Est_Pay, Est_Pay_Unit, Est_Occupation, Est_Area, Est_Year, Est_Source,
                                                   !is.na(Pay_Min))) %>%
  select(Institution, Title, Location, `Posted Pay`, `Typical pay (est.)`, Posted_Date, Link,
         Pay_Min, Pay_Max, Pay_Unit, Est_Pay, Est_Pay_Unit,
         Campus_Town, Campus_County, Campus_Latitude, Campus_Longitude, Place_Basis) %>%
  arrange(Institution, Title) %>%
  mutate(
    Appointment = classify_he_appointment(Title),
    # Home page job-type tables (as the K-12 .Not_Marked above; he_jobtype_weekly_totals.csv makes the same calls).
    .Job_Type = classify_he_job_type(Title),
    .Not_Marked = is.na(classify_work_schedule(Title, he_job_type = .Job_Type)),
    Posted_Date = format_posted_or_listed_date(Posted_Date),
    Posted_Date = fill_first_seen(Posted_Date, Institution, Title, Link, "HE", lookup = first_seen_table),
    Posted_Date = relative_posted_label(Posted_Date, he_run_date, first_seen_date(Institution, Title, Link, "HE"))
  ) %>%
  rename(`Posted / listed` = Posted_Date)
ccdata$Link <- paste0('<a href="', ccdata$Link, '" target="_blank">', ccdata$Link, '</a>')
he_faculty_counts <- summarize_he_faculty_postings(ccdata$Title)

mapdata2_he <- read.csv("salarymap.csv")
# ACS margins of error (edjobs 0.28.0): optional until the first run writes them.
for (col in c("Median_Household_Income_MOE", "Median_Gross_Rent_MOE", "Mining_Employment_Share_MOE")) if (!col %in% names(mapdata2_he)) mapdata2_he[[col]] <- NA_real_
mapdata2_he <- mapdata2_he %>%
  validate_and_pad_schema(c("Name", "Longitude", "Latitude", "Link", "Faculty_Avg_Salary",
                             "Faculty_Avg_Salary_Professor", "Faculty_Count", "Salary_Year",
                             "Salary_Note", "Salary_Source", "Faculty_Avg_Salary_Y1Ago", "Faculty_Avg_Salary_Y2Ago",
                             "County", "Median_Household_Income", "Median_Gross_Rent",
                             "Mining_Employment_Share", "Population_Change_Pct", "ACS_Year",
                             "Enrollment", "Enrollment_Change_Pct", "Pell_Recipient_Share", "Pell_Year"),
                           "salarymap.csv", on_missing = note_load_issue) %>%
  mutate(Salary_Year = as.character(Salary_Year), Pell_Year = as.character(Pell_Year))

# Institution faculty salary lookup for the Higher Ed Jobs Table
he_salary_lookup <- mapdata2_he %>%
  select(Name, Faculty_Avg_Salary) %>%
  mutate(
    `Avg. Salary, Full-Time Instructional Staff (IPEDS)` = ifelse(
      is.na(Faculty_Avg_Salary),
      "—",
      scales::dollar(Faculty_Avg_Salary, accuracy = 1)
    )
  )

ccdata$.Map_Name <- he_map_name(ccdata$Institution, ccdata$Campus_Town)
he_campus_points <- ccdata %>%
  filter(!is.na(Campus_Town), !is.na(Campus_Latitude), !is.na(Campus_Longitude)) %>%
  distinct(.Map_Name, Institution, Campus_Town, Campus_County, Campus_Latitude, Campus_Longitude)
ccdata$.Map_Name <- ifelse(ccdata$.Map_Name %in% he_campus_points$.Map_Name, ccdata$.Map_Name, ccdata$Institution)
# Postings shown at the main campus because they name no town in the state
# (a department or building, several sites, "United States", another state).
he_unplaced_n <- sum(ccdata$Place_Basis %in% c("no_town", "out_of_state"))
he_place_note <- if (any(!is.na(ccdata$Place_Basis))) paste0(
  "College postings are shown at the town the posting names (a branch campus, outreach center or field office). ",
  format(he_unplaced_n, big.mark = ","), " of ", format(nrow(ccdata), big.mark = ","),
  " current college postings don't name one Wyoming town (the job board gives a department, a building or no place, ",
  "or the job covers several sites or is out of state) and are shown at the institution's main campus.") else ""

ccdata <- ccdata %>%
  left_join(he_salary_lookup, by = c("Institution" = "Name")) %>%
  # Figure for the map's pay bands: posted pay, else the institution's IPEDS
  # faculty average on a full-time faculty posting, else the staff estimate
  # (UW salary book median, or the IPEDS average for the staff category).
  mutate(
    .faculty_avg = Appointment == "Faculty/instructor (non-adjunct)" & !is.na(Faculty_Avg_Salary),
    .fallback_value = ifelse(.faculty_avg, Faculty_Avg_Salary, Est_Pay),
    .fallback_unit = ifelse(.faculty_avg, "year", Est_Pay_Unit),
    .Pay_Value = posting_pay_value(Pay_Min, Pay_Max, Pay_Unit, .fallback_value, .fallback_unit)$value,
    .Pay_Unit = posting_pay_value(Pay_Min, Pay_Max, Pay_Unit, .fallback_value, .fallback_unit)$unit
  ) %>%
  select(Institution, Title, Location, Appointment, `Posted Pay`, `Typical pay (est.)`, `Avg. Salary, Full-Time Instructional Staff (IPEDS)`,
         `Posted / listed`, Link, .Pay_Value, .Pay_Unit, .Map_Name, .Job_Type, .Not_Marked)

hesum_he <- read.csv("allsum_he.csv") %>%
  validate_and_pad_schema(c("Category", "Archive_Date", "Institution", "Job_Type", "sum"), "allsum_he.csv", on_missing = note_load_issue) %>%
  filter(Category != "Uncategorized")

hesum_he$Archive_Date <- as.Date(hesum_he$Archive_Date)
hesum_he <- latest_snapshot_per_week(hesum_he)

# Same gap-filling as k12sum above -- a Category/Institution/Job_Type
# combination with zero postings in a given week is simply missing from
# the source aggregation, not an explicit 0.
hesum_he <- hesum_he %>%
  tidyr::complete(Category, Archive_Date, Institution, Job_Type, fill = list(sum = 0))
he_dates <- sort(unique(hesum_he$Archive_Date))
WINDOW_WEEKS <- 52
hesum_he$Category<- as.factor(hesum_he$Category)

henowsum_he <- read.csv("allnow_he.csv") %>%
  validate_and_pad_schema(c("Category", "Job_Type", "Sum", "Institution"), "allnow_he.csv", on_missing = note_load_issue) %>%
  filter(Category != "Uncategorized")

last_refreshed_date <- format(max(k12sum$Archive_Date, hesum_he$Archive_Date, na.rm = TRUE), "%B %d, %Y")

#--------------------------------------------------
# Simple rollups -- a 2026-08-04 audit found several badly-oversized,
# artificially-merged categories (K-12 "Special Education" alone was 3,239
# postings; HE "CTE" was 5,834, three times the next-largest real
# category) and split them into coherent sub-groups. That's more accurate,
# but too many categories at once makes the longitudinal line charts an
# unreadable tangle -- and a first attempt at an "Aggregated" view that
# just undid those specific splits (13-16 categories) turned out to still
# be nearly as busy as "Detailed" (16-18 categories), not a real second
# option. "Simple" instead collapses every detailed category into ~5 broad
# groups chosen from real posting volume (see git history for the specific
# percentages), matching how school/college staffing is actually organized
# -- e.g. K-12 elementary-generalist vs special-ed vs secondary-subject vs
# CTE vs enrichment, HE by division. Both levels stay available via a
# toggle rather than picking one and losing the other.
#--------------------------------------------------
k12_collapse_map <- c(
  "Elementary" = "Elementary & Early Childhood",
  "Early Childhood" = "Elementary & Early Childhood",
  "SpEd - General" = "Special Education",
  "SpEd - Resource/LS" = "Special Education",
  "Math" = "Core Academic",
  "Science" = "Core Academic",
  "Engl. LA" = "Core Academic",
  "Soc. St." = "Core Academic",
  "Language" = "Core Academic",
  "CTE - Trades/Ag" = "CTE",
  "CTE - Biz/Family" = "CTE",
  "Music" = "Arts & Enrichment",
  "Art" = "Arts & Enrichment",
  "Physical Education" = "Arts & Enrichment",
  "Library Media" = "Arts & Enrichment",
  "Gifted and Talented" = "Arts & Enrichment"
)

k12sum_agg <- k12sum %>%
  mutate(Broad_Category = dplyr::recode(Broad_Category, !!!k12_collapse_map)) %>%
  group_by(Broad_Category, Archive_Date, District) %>%
  summarize(sum = sum(sum), .groups = "drop")

k12nowsum_agg <- k12nowsum %>%
  mutate(Broad_Category = dplyr::recode(Broad_Category, !!!k12_collapse_map)) %>%
  group_by(Broad_Category, District) %>%
  summarize(Sum = sum(Sum), .groups = "drop")

he_collapse_map <- c(
  "CTE - Trades & Engineering" = "CTE / Career-Technical",
  "CTE - Health Sciences" = "CTE / Career-Technical",
  "CTE - Business & Computing" = "CTE / Career-Technical",
  "Culinary/Hospitality" = "CTE / Career-Technical",
  "Science" = "STEM",
  "Math" = "STEM",
  "Humanities" = "Humanities & Social Sciences",
  "Social Science" = "Humanities & Social Sciences",
  "History" = "Humanities & Social Sciences",
  "Language" = "Humanities & Social Sciences",
  "Criminal Justice" = "Humanities & Social Sciences",
  "Legal" = "Humanities & Social Sciences",
  "Human Services" = "Humanities & Social Sciences",
  "Education" = "Humanities & Social Sciences",
  "The Arts" = "Arts & Physical Education",
  "Physical Education" = "Arts & Physical Education",
  "Extension/Outreach" = "Extension/Outreach & Library",
  "Library" = "Extension/Outreach & Library"
)

hesum_he_agg <- hesum_he %>%
  mutate(Category = dplyr::recode(as.character(Category), !!!he_collapse_map)) %>%
  group_by(Category, Archive_Date, Institution, Job_Type) %>%
  summarize(sum = sum(sum), .groups = "drop")

henowsum_he_agg <- henowsum_he %>%
  mutate(Category = dplyr::recode(Category, !!!he_collapse_map)) %>%
  group_by(Category, Institution, Job_Type) %>%
  summarize(Sum = sum(Sum), .groups = "drop")

#--------------------------------------------------
# Category colors -- one fixed hex per category, shared by every chart in
# its section, so a category is never a different color on the current-
# snapshot chart than on the longitudinal chart. First 8 slots (by
# all-time volume) are the validated categorical palette from the dataviz
# skill (fixed order, CVD-checked); slots past 8 extend it with additional
# well-separated hues for the lower-volume categories rather than
# reusing/cycling a slot. Separate palettes for the Simple and Detailed
# views since they're different category sets, not just different labels.
#--------------------------------------------------
EXT_HUES <- c("#8B5E34", "#5C7A99", "#7A7A3D", "#767671", "#2E8B87",
              "#C77DA8", "#B8860B", "#6B5B95", "#4A6670", "#D97757")
BASE8 <- c("#2a78d6", "#eb6834", "#1baf7a", "#eda100", "#e87ba4", "#008300", "#4a3aa7", "#e34948")

# Ordered by real posting volume: Special Education 28%, Core Academic 27%,
# Elementary & Early Childhood 22%, Arts & Enrichment 15%, CTE 9%.
K12_CATEGORY_COLORS_AGG <- setNames(BASE8[1:5], c(
  "Special Education", "Core Academic", "Elementary & Early Childhood",
  "Arts & Enrichment", "CTE"
))

K12_CATEGORY_COLORS_DETAIL <- setNames(c(BASE8, EXT_HUES[1:8]), c(
  "Elementary", "SpEd - General", "SpEd - Resource/LS", "Music", "Math",
  "Engl. LA", "Science", "CTE - Trades/Ag", "Language", "CTE - Biz/Family",
  "Soc. St.", "Physical Education", "Early Childhood", "Art", "Library Media",
  "Gifted and Talented"
))

# Ordered by real posting volume: CTE/Career-Technical 45%, Humanities &
# Social Sciences 21%, STEM 19%, Arts & PE 9%, Extension/Outreach & Library 6%.
HE_CATEGORY_COLORS_AGG <- setNames(BASE8[1:5], c(
  "CTE / Career-Technical", "Humanities & Social Sciences", "STEM",
  "Arts & Physical Education", "Extension/Outreach & Library"
))

HE_CATEGORY_COLORS_DETAIL <- setNames(c(BASE8, EXT_HUES), c(
  "CTE - Trades & Engineering", "Science", "CTE - Health Sciences", "CTE - Business & Computing",
  "The Arts", "Humanities", "Social Science", "Extension/Outreach", "Math",
  "History", "Education", "Culinary/Hospitality", "Physical Education",
  "Library", "Language", "Criminal Justice", "Legal", "Human Services"
))

# Appointment colors retained for any future split view. The current
# faculty-trends table now filters its underlying Job_Type directly.
HE_JOB_TYPE_COLORS <- c(
  "Faculty/instructor (non-adjunct)" = "#2a78d6",
  "Adjunct/Part-Time"  = "#eb6834"
)

#--------------------------------------------------
# Teaching and faculty history (k12jobanalysis.csv/facultydata.csv are
# filtered that way upstream): the trend tabs and the vacancy rate, and
# "new this week" until the every-role files below hold two weeks.
#--------------------------------------------------
k12_history <- read.csv("k12jobanalysis.csv", fileEncoding = "UTF-8") %>%
  validate_and_pad_schema(c("title", "Archive_Date", "location", "District", "Posting_ID"), "k12jobanalysis.csv",
                          on_missing = note_load_issue) %>%
  mutate(Archive_Date = as.Date(Archive_Date)) %>%
  latest_snapshot_per_week()


# New by Posting_ID and by title + location + District (edjobs find_k12_new_postings(); Mike chose rule A, 2026-11-21).
k12_new_this_week <- find_k12_new_postings(k12_history)

he_history <- read.csv("facultydata.csv", fileEncoding = "UTF-8") %>%
  validate_and_pad_schema(c("Title", "Location", "Institution", "Link", "Archive_Date", "Job_Type", "Category"), "facultydata.csv", on_missing = note_load_issue) %>%
  mutate(Archive_Date = as.Date(Archive_Date)) %>%
  latest_snapshot_per_week() %>%
  filter(Job_Type %in% c("Instructor/Teacher/Faculty", "Adjunct/Part-Time Faculty")) %>%
  mutate(Appointment = dplyr::recode(
    Job_Type,
    "Instructor/Teacher/Faculty" = "Faculty/instructor (non-adjunct)",
    "Adjunct/Part-Time Faculty" = "Adjunct/part-time faculty"
  ))

# "New this week" over every role (edjobs 0.107.0; full review 2026-11-27, Mike's call): the pipeline keeps the last
# two weeks' postings of every role in k12_recent_postings.csv / he_recent_postings.csv. The teaching and faculty
# histories above are the fallback until a file holds two weeks. Rules: edjobs find_k12_new_postings() (rule A,
# 2026-11-21) and find_he_new_postings() (title, location, institution).
read_recent_postings <- function(f) {
  d <- tryCatch(read.csv(f, colClasses = "character", fileEncoding = "UTF-8"), error = function(e) NULL)
  if (!is.null(d) && length(unique(d$Archive_Date)) >= 2) d else NULL
}
k12_recent <- read_recent_postings("k12_recent_postings.csv")
if (!is.null(k12_recent)) k12_new_this_week <- find_k12_new_postings(k12_recent)
he_recent <- read_recent_postings("he_recent_postings.csv")
he_new_this_week <- find_he_new_postings(if (is.null(he_recent)) he_history else he_recent)

#--------------------------------------------------
# Combined map dataset -- one row per K-12 district or HE institution,
# merging each entity's existing location/salary reference data with a
# live current-openings count, a couple of sample current titles, and a
# new-this-week count (reusing k12_new_this_week/he_new_this_week above,
# every role, so it's the same definition of "new" as the Jobs tabs' New
# This Week button, not a separate metric).
#--------------------------------------------------
k12_current_counts <- combineddata %>% count(District, name = "CurrentCount")
k12_sample_titles <- combineddata %>%
  group_by(District) %>%
  summarize(SampleTitles = paste(head(Title, 3), collapse = "; "), .groups = "drop")
k12_weekly_new <- k12_new_this_week %>% count(District, name = "WeeklyNew")

# Teacher-only current postings (k12_history is already scoped to
# position == "Teacher", same as the Teacher Trends tabs), for a vacancy
# rate scoped consistently with its denominator (Teachers_Total_FTE from
# CCD, also teacher-only) -- dividing ALL open postings (bus drivers,
# coaches, custodians, etc. included) by teacher FTE would overstate the
# rate by mixing categories that don't correspond to each other.
# Vacancy rate needs a minimum FTE to be a meaningful comparison -- 1
# opening out of 1 teacher is a "100%" rate that isn't really comparable
# to Laramie County's ~5% on a base of 1,067 teachers. Currently a no-op
# against real data (every WY district/institution has 15+ FTE), but
# keeps a future small entity from producing a noisy, misleading rate.
VACANCY_RATE_MIN_FTE <- 10

# Live links for the Summary tables' source footnotes -- see
# salary_scrapers.R / ipeds_salary_scraper.R's own header comments for why
# these are the canonical pages to check if a fetch ever starts failing.
WSBA_SALARY_SOURCE_URL <- "https://sites.google.com/wsba-wy.org/my-wsba/wy-education-salaries"
IPEDS_SALARY_SOURCE_URL <- "https://educationdata.urban.org"

# The Districts tab's pay and budget columns, their map popup lines, the compare plot's bars and the footnote's
# state paragraphs (edjobs district_spec(), step 7 slice 3 part 3, 2026-11-21).
# WSBA's base salary for the current and prior school year (the prior label is the same range shifted back a year,
# prior_school_year_label()), WDE's average teacher salary and the superintendent's salary.
DISTRICT_SPEC <- district_spec(
  columns = list(
    district_column("Teacher Base Salary (%s)", value = "Teacher_Base_Salary", year_col = "Salary_Year",
                    year_fallback = "current year", card = "Base Starting Salary:"),
    district_column("Teacher Base Salary (%s)", value = "Teacher_Base_Salary_Prior_Year", year_col = "Salary_Year",
                    year_fallback = "prior year", prior_year = TRUE),
    district_column("Teacher Avg Salary (%s WDE)", value = "Teacher_Avg_Salary", year_col = "WDE_Salary_Year",
                    year_fallback = "2025-26", card = "Avg Salary (WDE):"),
    district_column("Superintendent Salary", value = "Superintendent_Salary")
  ),
  popup_lines = list(
    district_popup_line("Teacher base salary", "Teacher_Base_Salary", also = "Teacher_Base_Salary_Prior_Year",
                        also_label = " prior year", year_col = "Salary_Year"),
    district_popup_line("Average teacher salary", "Teacher_Avg_Salary", year_col = "WDE_Salary_Year", suffix = " (WDE)"),
    district_popup_line("Superintendent salary", "Superintendent_Salary")
  ),
  compare_bars = c("Base Starting Salary" = "Teacher_Base_Salary", "Average Salary (WDE)" = "Teacher_Avg_Salary"),
  compare_y_title = "Annual Salary ($)",
  # Salary_Year and Salary_Source are the same for every district (one WSBA document covers all 48 for one school
  # year), so they are a footnote with a live link rather than a column repeating one value.
  source_notes = list(
    district_source_note("Base salary data:", "Salary_Source", year_col = "Salary_Year", url = WSBA_SALARY_SOURCE_URL,
                         url_text = "wsba-wy.org"),
    district_source_note("Average teacher salary data:", "WDE_Salary_Source", year_col = "WDE_Salary_Year",
                         url = "https://edu.wyoming.gov/data/staff-member-collection/", url_text = "edu.wyoming.gov",
                         require_year = FALSE)
  ),
  saipe_scope_note = ". District-level (unlike the county context above).",
  saipe_standin_note = "A charter school or early-childhood center has no Census poverty estimate of its own; it shows its surrounding district's estimate (marked \"Surrounding district\").",
  page_length = 48,
  shared_vacancy_note = "combined Sheridan + Gillette figure -- see note below"
)

k12_teacher_current_counts <- k12_history %>%
  filter(Archive_Date == max(Archive_Date)) %>%
  count(District, name = "TeacherCurrentCount")

map_k12 <- mapdata2_k12 %>%
  left_join(k12_current_counts, by = c("Name" = "District")) %>%
  left_join(k12_sample_titles, by = c("Name" = "District")) %>%
  left_join(k12_weekly_new, by = c("Name" = "District")) %>%
  left_join(k12_teacher_current_counts, by = c("Name" = "District")) %>%
  mutate(
    CurrentCount = coalesce(CurrentCount, 0L),
    WeeklyNew = coalesce(WeeklyNew, 0L),
    SampleTitles = coalesce(SampleTitles, ""),
    Type = "K-12 District",
    FRL_Year = as.character(FRL_Year),  # read back as a number; HE rows carry text NA
    TeacherCurrentCount = coalesce(TeacherCurrentCount, 0L),
    Vacancy_Rate = ifelse(!is.na(Teachers_Total_FTE) & Teachers_Total_FTE >= VACANCY_RATE_MIN_FTE,
                           TeacherCurrentCount / Teachers_Total_FTE, NA_real_),
    Vacancy_Numerator = TeacherCurrentCount, Vacancy_Denominator = Teachers_Total_FTE,
    Vacancy_Rate_Shared = FALSE,
    Faculty_Avg_Salary = NA_real_, Faculty_Avg_Salary_Professor = NA_real_, Faculty_Count = NA_real_,
    Faculty_Avg_Salary_Y1Ago = NA_real_, Faculty_Avg_Salary_Y2Ago = NA_real_,
    Salary_Note = NA_character_,
    # Already fetched from CCD alongside Teachers_Total_FTE (same API call
    # in ccd_staff_scraper.R) but never surfaced anywhere in the app until
    # now -- Students_Per_Teacher is a real class-size-ish proxy a
    # prospective teacher would want, at zero additional scraping cost.
    Students_Per_Teacher = ifelse(!is.na(Teachers_Total_FTE) & Teachers_Total_FTE > 0,
                                   Enrollment / Teachers_Total_FTE, NA_real_),
    # No district-level enrollment-trend equivalent on the K-12 side (CCD's
    # own multi-year history isn't pulled here) -- HE's Enrollment_Change_
    # Pct (institution-level, from ipeds_enrollment_scraper.R) is a
    # different, institution-specific signal from Population_Change_Pct
    # (county-level, already real here via the Census join above), not a
    # duplicate of it.
    Enrollment_Change_Pct = NA_real_,
    # No K-12 equivalent -- Pell Grant recipient share is an HE-specific
    # federal program (FSA), the closest HE analogue to Child_Poverty_Rate
    # below (which itself has no HE equivalent -- see that column's own
    # comment on this K-12 side further down).
    Pell_Recipient_Share = NA_real_, Pell_Year = NA_character_
  ) %>%
  select(Name, Longitude, Latitude, Type, CurrentCount, WeeklyNew, SampleTitles,
         Link = Job_Link, Teacher_Base_Salary, Teacher_Base_Salary_Prior_Year, Salary_Year,
         Teacher_Avg_Salary, Teacher_Avg_Base_Salary, WDE_Salary_Year, WDE_Salary_Source,
         Superintendent_Salary, Superintendent_Contract_Days,
         Faculty_Avg_Salary, Faculty_Avg_Salary_Professor, Faculty_Count,
         Faculty_Avg_Salary_Y1Ago, Faculty_Avg_Salary_Y2Ago, Salary_Note,
         Vacancy_Rate, Vacancy_Numerator, Vacancy_Denominator, Vacancy_Rate_Shared, Salary_Source, County,
         Data_Coverage, Enrollment, Students_Per_Teacher, Enrollment_Change_Pct, Pell_Recipient_Share, Pell_Year,
         Median_Household_Income, Median_Gross_Rent, Mining_Employment_Share, Population_Change_Pct, ACS_Year,
         Median_Household_Income_MOE, Median_Gross_Rent_MOE, Mining_Employment_Share_MOE,
         Child_Poverty_Rate, Child_Poverty_Low, Child_Poverty_High, SAIPE_Year, Child_Poverty_Basis, Free_Reduced_Lunch_Share, FRL_Year)

he_current_counts <- ccdata %>% count(Institution = .Map_Name, name = "CurrentCount")
he_sample_titles <- ccdata %>%
  group_by(Institution = .Map_Name) %>%
  summarize(SampleTitles = paste(head(Title, 3), collapse = "; "), .groups = "drop")
# New-this-week postings counted on the dot their current posting is on.
he_weekly_new <- he_new_this_week %>%
  left_join(ccdata %>% distinct(Institution, Title, Location, .Map_Name) %>%
              distinct(Institution, Title, Location, .keep_all = TRUE),
            by = c("Institution", "Title", "Location")) %>%
  count(Institution = coalesce(.Map_Name, Institution), name = "WeeklyNew")

# Scoped to full-time faculty only, matching Faculty_Count's own scope --
# IPEDS's salaries-instructional-staff survey (the source of Faculty_Count)
# only covers full-time instructional staff, so mixing Adjunct/Part-Time
# postings into this numerator would overstate the rate the same way using
# CurrentCount (all K-12 job categories) would on the K-12 side.
#
# Regression: he_history itself was later widened to include BOTH Job_Types
# (for the FT/PT appointment toggles added to the trend/current/new-this-
# week tabs), but this consumer wasn't updated at the same time -- it
# silently started counting adjunct postings into a full-time-only
# denominator. This filter makes the scope explicit again instead of
# assuming the shared he_history object's scope.
he_faculty_current_counts <- he_history %>%
  filter(Archive_Date == max(Archive_Date), Job_Type == "Instructor/Teacher/Faculty") %>%
  count(Institution, name = "FacultyCurrentCount")

map_he <- mapdata2_he %>%
  left_join(he_current_counts, by = c("Name" = "Institution")) %>%
  left_join(he_sample_titles, by = c("Name" = "Institution")) %>%
  left_join(he_weekly_new, by = c("Name" = "Institution")) %>%
  left_join(he_faculty_current_counts, by = c("Name" = "Institution")) %>%
  mutate(
    CurrentCount = coalesce(CurrentCount, 0L),
    WeeklyNew = coalesce(WeeklyNew, 0L),
    SampleTitles = coalesce(SampleTitles, ""),
    Type = "Higher Ed Institution",
    FacultyCurrentCount = coalesce(FacultyCurrentCount, 0L),
    # Sheridan College and Gillette College (flagged via Salary_Note) share
    # one IPEDS-reported Faculty_Count -- dividing either institution's own
    # posting count by that joint total isn't a real per-campus rate (it
    # inflated Sheridan to 66% in testing, since its numerator is compared
    # against a denominator that's really Sheridan+Gillette combined).
    # Rather than suppress both to NA, both show the same JOINT rate --
    # their combined current postings over the one shared faculty count --
    # since that's still a real, meaningful "how tight is staffing at this
    # combined institution" figure, just not splittable by campus. Vacancy_
    # Rate_Shared flags this so the UI can label it rather than presenting
    # it as if it were campus-specific. Once IPEDS starts reporting them
    # separately (watched by fetch_sheridan_gillette_split_check() in
    # ipeds_salary_scraper.R), Faculty_Count will stop being identical for
    # both rows and this collapses back to each institution's own rate with
    # no code change needed here.
    Vacancy_Rate_Shared = !is.na(Salary_Note) & nzchar(trimws(Salary_Note)),
    Vacancy_Numerator = ifelse(Vacancy_Rate_Shared,
                                sum(FacultyCurrentCount[!is.na(Salary_Note) & nzchar(trimws(Salary_Note))]),
                                FacultyCurrentCount),
    Vacancy_Rate = ifelse(!is.na(Faculty_Count) & Faculty_Count >= VACANCY_RATE_MIN_FTE,
                           Vacancy_Numerator / Faculty_Count, NA_real_),
    Vacancy_Denominator = Faculty_Count,
    Teacher_Base_Salary = NA_real_, Teacher_Base_Salary_Prior_Year = NA_real_,
    Teacher_Avg_Salary = NA_real_, Teacher_Avg_Base_Salary = NA_real_,
    WDE_Salary_Year = NA_character_, WDE_Salary_Source = NA_character_,
    Superintendent_Salary = NA_real_, Superintendent_Contract_Days = NA_real_,
    # Every HE institution is scraped from a genuine structured job-board
    # platform (NEOGOV/PeopleAdmin/Oracle) -- there's no "misc" tier on the
    # HE side, unlike K-12's Data_Coverage from misc_district_registry.
    Data_Coverage = "Full",
    # Enrollment comes straight from salarymap.csv (mapdata2_he, joined via
    # ipeds_enrollment_scraper.R's fetch_ipeds_he_enrollment() -- added
    # 2026-08-06). Students_Per_Teacher is computed here the same way
    # map_k12 computes it (Enrollment / Teachers_Total_FTE there), just
    # against Faculty_Count instead -- IPEDS's own instructional-staff
    # headcount, already fetched for the vacancy-rate denominator.
    Students_Per_Teacher = ifelse(!is.na(Faculty_Count) & Faculty_Count > 0,
                                   Enrollment / Faculty_Count, NA_real_),
    # Enrollment_Change_Pct also comes straight through from salarymap.csv
    # (ipeds_enrollment_scraper.R's fetch_ipeds_he_enrollment_trend() -- a
    # 5-year institution-level trend, HE's analogue of Population_Change_
    # Pct below but at the institution rather than county level).
    #
    # County/Median_Household_Income/Median_Gross_Rent/Mining_Employment_
    # Share/Population_Change_Pct/ACS_Year come straight from salarymap.csv
    # (mapdata2_he, joined via census_acs_scraper.R's fetch_census_county_
    # context() the same way K-12 gets it -- added 2026-08-06, each HE
    # institution's real home county is now hand-maintained the same way
    # Latitude/Longitude already are) -- no override needed here, unlike
    # the K-12-only fields above.
    #
    # SAIPE child poverty rate has no HE equivalent -- it's a K-12 school-
    # district-specific federal program (child poverty, not overall
    # poverty), and doesn't map onto a mostly-adult college student body.
    # Pell_Recipient_Share/Pell_Year (fsa_pell_scraper.R, added 2026-08-06)
    # come straight through from salarymap.csv instead -- the real HE
    # analogue: share of students who are low-income, from a different
    # federal program (FSA, not SAIPE) since SAIPE itself has no HE
    # equivalent.
    Child_Poverty_Rate = NA_real_, Child_Poverty_Low = NA_real_, Child_Poverty_High = NA_real_, SAIPE_Year = NA_integer_,
    Child_Poverty_Basis = NA_character_, Free_Reduced_Lunch_Share = NA_real_, FRL_Year = NA_character_
  ) %>%
  select(Name, Longitude, Latitude, Type, CurrentCount, WeeklyNew, SampleTitles,
         Link, Teacher_Base_Salary, Teacher_Base_Salary_Prior_Year, Salary_Year,
         Teacher_Avg_Salary, Teacher_Avg_Base_Salary, WDE_Salary_Year, WDE_Salary_Source,
         Superintendent_Salary, Superintendent_Contract_Days,
         Faculty_Avg_Salary, Faculty_Avg_Salary_Professor, Faculty_Count,
         Faculty_Avg_Salary_Y1Ago, Faculty_Avg_Salary_Y2Ago, Salary_Note,
         Vacancy_Rate, Vacancy_Numerator, Vacancy_Denominator, Vacancy_Rate_Shared, Salary_Source, County,
         Data_Coverage, Enrollment, Students_Per_Teacher, Enrollment_Change_Pct, Pell_Recipient_Share, Pell_Year,
         Median_Household_Income, Median_Gross_Rent, Mining_Employment_Share, Population_Change_Pct, ACS_Year,
         Median_Household_Income_MOE, Median_Gross_Rent_MOE, Mining_Employment_Share_MOE,
         Child_Poverty_Rate, Child_Poverty_Low, Child_Poverty_High, SAIPE_Year, Child_Poverty_Basis, Free_Reduced_Lunch_Share, FRL_Year)

# One dot per branch campus or site with current postings: its own count,
# new-this-week and sample titles, its town's county context (the ACS figures
# a district in that county shows), and no institution-wide figures (salary,
# vacancy rate, enrollment), which stay on the main campus dot.
he_county_context <- bind_rows(map_k12, map_he) %>%
  filter(!is.na(County), !is.na(Median_Household_Income)) %>%
  distinct(County, .keep_all = TRUE) %>%
  select(County, Median_Household_Income, Median_Gross_Rent, Mining_Employment_Share, Population_Change_Pct, ACS_Year,
         Median_Household_Income_MOE, Median_Gross_Rent_MOE, Mining_Employment_Share_MOE)
map_he_campus <- he_campus_points %>%
  transmute(Name = .Map_Name, Campus_Of = Institution, Longitude = Campus_Longitude, Latitude = Campus_Latitude,
            County = Campus_County, Link = mapdata2_he$Link[match(Institution, mapdata2_he$Name)]) %>%
  left_join(he_current_counts, by = c("Name" = "Institution")) %>%
  left_join(he_sample_titles, by = c("Name" = "Institution")) %>%
  left_join(he_weekly_new, by = c("Name" = "Institution")) %>%
  left_join(he_county_context, by = "County") %>%
  mutate(CurrentCount = coalesce(CurrentCount, 0L), WeeklyNew = coalesce(WeeklyNew, 0L),
         SampleTitles = coalesce(SampleTitles, ""), Type = "Higher Ed Institution", Data_Coverage = "Full",
         Vacancy_Rate_Shared = FALSE,
         Campus_Note = paste0("A campus or site of ", Campus_Of, ". Its salary, vacancy and enrollment figures are on the ",
                              Campus_Of, " dot."))
he_other_site_counts <- map_he_campus %>% group_by(Campus_Of) %>% summarize(n = sum(CurrentCount), .groups = "drop")
map_he <- map_he %>%
  mutate(Campus_Of = NA_character_,
         Campus_Note = {
           n <- he_other_site_counts$n[match(Name, he_other_site_counts$Campus_Of)]
           ifelse(!is.na(n) & n > 0, paste0("Plus ", n, " opening", ifelse(n == 1, "", "s"),
                                            " at other campuses or sites (their own dots)."), NA_character_)
         }) %>%
  bind_rows(map_he_campus)

combined_map_data <- bind_rows(map_k12, map_he)

map_county_choices <- c("All Counties" = "all", setNames(
  sort(unique(na.omit(combined_map_data$County))),
  sub(", Wyoming$", "", sort(unique(na.omit(combined_map_data$County))))
))

# Map marker size/color -- radius (edjobs map_marker_radius()) scaled by sqrt(CurrentCount), not
# CurrentCount directly, since a circle's perceived size is its area, not
# its radius (linear scaling would visually overstate the gap between a
# 10-opening and a 100-opening district). Color is a single-hue sequential
# ramp on Vacancy_Rate (a bounded 0-100% "severity" dimension that pairs
# naturally with size-as-volume) rather than salary, which would need two
# separate ramps for K-12 vs. HE's different pay scales. Domain is fixed
# from the full unfiltered dataset so the color scale (and legend) don't
# shift as the K-12/HE checkbox filter changes what's on screen.

vacancy_rate_domain <- compute_vacancy_rate_domain(combined_map_data$Vacancy_Rate)
vacancy_rate_palette <- colorNumeric(palette = "YlOrRd", domain = vacancy_rate_domain, na.color = "#9e9e9e")

#--------------------------------------------------
# UI (bslib / Bootstrap 5)
#--------------------------------------------------
# The navbar's id stays "sidebar_tabs" and each page's value is the old
# shinydashboard tabName, so the map's "View N matching jobs" link
# (nav_select) and the boot smoke test's set_inputs(sidebar_tabs = ...) keep
# working unchanged.
app_theme <- bs_theme(
  version = 5,
  preset = "shiny",
  primary = "#2a78d6",
  base_font = font_collection(font_google("Inter", local = FALSE), "system-ui", "-apple-system", "Segoe UI", "Roboto", "sans-serif"),
  "font-size-base" = "0.925rem"
)


# Sources and required notices, shown at the foot of every page. The Census
# Data API terms require their notice "prominently within the application"
# (census.gov/data/developers/about/terms-of-service.html, revised
# 2026-04-14); the BLS API terms require theirs ("Users must clearly state",
# bls.gov/developers/termsOfService.htm, modified 2023-08-30); Urban's
# Education Data Portal data are under ODC-By, cited in its short form for
# visualizations (educationdata.urban.org/documentation/). Audit:
# claude-notes/2026-11-15_citations-audit.md.
# When each outside source was last retrieved (source_retrieved_dates.csv, written by the pipeline only when a fetch
# succeeds and its data is kept; hand-kept files carry the date they were added). BLS asks for the access date
# (Mike, 2026-11-16: give one for every source). Missing file or source: the line shows no date.
source_dates <- tryCatch(read.csv("source_retrieved_dates.csv", stringsAsFactors = FALSE, colClasses = "character"),
                         error = function(e) data.frame(Source = character(0), Retrieved = character(0)))

data_sources_footer <- tags$footer(
  class = "data-sources-footer",
  tags$p(tags$strong("Data sources."), "Job postings: each employer's own job board (every posting links to it) and the Wyoming School Boards Association vacancies list."),
  tags$p(
    paste0("U.S. Census Bureau: American Community Survey 5-Year Estimates", footer_retrieved("Census ACS", source_dates),
           "; Small Area Income and Poverty Estimates", footer_retrieved("Census SAIPE", source_dates),
           "; Census Geocoder", footer_retrieved("Census Geocoder", source_dates), "."),
    paste0("U.S. Bureau of Labor Statistics, Occupational Employment and Wage Statistics", footer_retrieved("BLS OEWS", source_dates),
           " and Quarterly Census of Employment and Wages", footer_retrieved("BLS QCEW", source_dates), "."),
    HTML(paste0("NCES Common Core of Data", footer_retrieved("Urban CCD", source_dates), ", IPEDS", footer_retrieved("Urban IPEDS", source_dates),
                " and Federal Student Aid Title IV data", footer_retrieved("Urban FSA", source_dates), ", via Education Data Portal, Urban Institute, ",
                "under <a href=\"https://opendatacommons.org/licenses/by/1-0/\" target=\"_blank\" rel=\"noopener\">ODC Attribution License</a>."))
  ),
  tags$p(paste0("Wyoming School Boards Association, salary settlements", footer_retrieved("WSBA salaries", source_dates),
                "; Wyoming Department of Education, Staff Member Collection, WDE602", footer_retrieved("WDE602", source_dates),
                "; University of Wyoming salary book", footer_retrieved("UW salary book", source_dates), ".")),
  tags$p(
    "This product uses the Census Bureau Data API but is not endorsed or certified by the Census Bureau.",
    "BLS.gov cannot vouch for the data or analyses derived from these data after the data have been retrieved from BLS.gov."
  ),
  built_with_edjobs()
)

ui <- page_navbar(
  id = "sidebar_tabs",
  title = tags$span(icon("graduation-cap"), " Wyoming Education Jobs"),
  window_title = "Wyoming Education Jobs",
  theme = app_theme,
  fillable = FALSE,
  footer = data_sources_footer,
  navbar_options = navbar_options(theme = "dark", bg = "#1e293b"),
  header = tags$head(
    tags$style(HTML("
    .bslib-page-navbar > .navbar .navbar-brand { font-weight: 600; font-size: 1.1rem; }
    .navbar .dropdown-header { font-size: 11px; letter-spacing: 0.08em; text-transform: uppercase; }
    h1.page-title { font-size: 1.6rem; font-weight: 600; margin: 4px 0 14px; }
    h3.page-title { font-size: 1.3rem; font-weight: 600; margin: 4px 0 8px; }
    .card { margin-bottom: 1rem; }
    .data-sources-footer { border-top: 1px solid var(--bs-border-color); margin: 24px 0 0; padding: 12px 16px 16px; font-size: 0.78rem; color: var(--bs-secondary-color); }
    .data-sources-footer p { margin: 0 0 4px; }
    .bslib-value-box .value-box-title { font-size: 0.85rem; }
    .bslib-value-box .value-box-showcase svg { max-width: 100%; height: auto; }
    .download-tile { border: 1px solid var(--bs-border-color); border-radius: 8px; padding: 14px;
                     height: 100%; display: flex; flex-direction: column; background: var(--bs-tertiary-bg); }
    .download-tile h4 { font-size: 15px; font-weight: 600; margin-top: 0; }
    .download-tile p { font-size: 12px; color: var(--bs-secondary-color); flex-grow: 1; }
    .leaflet-tooltip {
      max-width: min(800px, 92vw) !important;
      min-width: min(320px, 85vw) !important;
      white-space: normal !important;
      background-color: rgba(255,255,255,0.95);
      padding: 6px 10px;
      border-radius: 6px;
      border: 1px solid gray;
      font-size: 14px;
      display: inline-block;
      box-sizing: border-box;
    }
    @media (max-width: 767px) {
      .leaflet-container { height: 480px !important; }
    }
    /* Table toolbar styling */
    .table-toolbar {
      display: flex;
      align-items: center;
      justify-content: space-between;
      flex-wrap: wrap;
      gap: 10px;
      margin-bottom: 12px;
      background: #f8fafc;
      padding: 10px 14px;
      border-radius: 6px;
      border: 1px solid #e2e8f0;
    }
    .table-toolbar .form-group { margin-bottom: 0; }
    /* Clean table styling so tables do not overfill space */
    .trends-table-container {
      width: 100%;
      overflow-x: auto;
      margin-top: 10px;
    }
    .trends-table-container table {
      width: 100% !important;
      max-width: 980px !important;
      margin: 0 auto;
      border-collapse: separate;
      border-spacing: 0;
      border-radius: 6px;
      overflow: hidden;
      border: 1px solid #e2e8f0;
      background: #ffffff;
      font-size: 13.5px;
    }
    .trends-table-container th {
      background-color: #f8fafc !important;
      color: #334155;
      font-weight: 600;
      font-size: 12px;
      text-transform: uppercase;
      letter-spacing: 0.04em;
      padding: 10px 14px !important;
      border-bottom: 2px solid #e2e8f0 !important;
    }
    .trends-table-container td {
      padding: 8px 14px !important;
      border-bottom: 1px solid #f1f5f9;
      color: #1e293b;
      vertical-align: middle !important;
    }
    .trends-table-container tr:last-child td { border-bottom: none; }
    .trends-table-container tr:hover td { background-color: #f8fafc; }
    /* Light DT export buttons instead of BS5 btn-secondary blocks */
    .dt-buttons .btn {
      background: transparent !important; color: var(--bs-body-color) !important;
      border: 1px solid var(--bs-border-color) !important;
      padding: 0.2rem 0.75rem !important; font-size: 0.8rem !important;
    }
    .dt-buttons .btn:hover { background: var(--bs-tertiary-bg) !important; }
    #map_filter_count .badge { white-space: normal; text-align: left; line-height: 1.4; }
    .info-pop { font-size: 0.85rem; font-weight: 500; text-decoration: none; white-space: nowrap; }
    .info-popover { --bs-popover-max-width: 420px; font-size: 0.85rem; }
    .help-popover .popover-body { max-height: 60vh; overflow-y: auto; }
    .help-pop { color: var(--bs-secondary-color); font-size: 0.95rem; text-decoration: none; }
    .help-pop:hover, .help-pop:focus { color: var(--bs-primary); }
    .help-columns dt { font-weight: 600; margin-top: 4px; }
    .help-columns dd { margin: 0 0 2px; }
    .map-chips { margin-top: -8px; font-size: 12px; color: #64748b; line-height: 1.9; }
    .map-chips a { margin-right: 8px; font-weight: 500; }
    .bslib-sidebar-layout > .sidebar .form-group { margin-bottom: 0.75rem; }
    .page-sidebar { border: none; --_sidebar-bg: transparent; }
    /* On a phone the collapsed sidebar is just a chevron; name it. */
    @media (max-width: 575.98px) {
      .bslib-sidebar-layout.sidebar-collapsed > .collapse-toggle { width: auto; padding: 4px 10px; border: 1px solid var(--bs-border-color); border-radius: 6px; }
      .bslib-sidebar-layout.sidebar-collapsed > .collapse-toggle::after { content: 'Filters'; margin-left: 6px; font-size: 0.9rem; }
      /* Home job-type tables: drop Share on a phone so the 12-week sparkline fits without scrolling. */
      #top_k12_job_types th:nth-child(3), #top_k12_job_types td:nth-child(3),
      #top_he_job_types th:nth-child(3), #top_he_job_types td:nth-child(3) { display: none; }
    }
  ")),
    # A DT table rendered while its page or tab was hidden measures its columns
    # at zero width; re-measure whenever a page or tab is shown.
    tags$script(HTML("
    $(document).on('shown.bs.tab', function() {
      if ($.fn.dataTable) $.fn.dataTable.tables({ visible: true, api: true }).columns.adjust();
      // On a phone, close the collapsed navbar menu once a page is picked.
      var menu = document.querySelector('.navbar-collapse.show');
      if (menu && window.bootstrap) bootstrap.Collapse.getOrCreateInstance(menu).hide();
    });
  "))
  ),

  # ------------------ Global Introduction ------------------
  # Home tab: edjobs's home_tab_panel() (step 7 slice 2b).
  home_tab_panel("Wyoming", "each district's own job board, read twice a week, or the Wyoming School Boards Association vacancies list for districts without one.",
    last_refreshed_date, "Developed by Mike Bostick and Mark Perkins"),

  # Map tab: the layout, filters and shared text are edjobs's map_tab_panel(); this is Wyoming's own text.
  map_tab_panel(
    "Wyoming",
    about = list(
      p("Only locations with current openings are shown. Circle size reflects current openings; color reflects teacher/faculty vacancy rate where available. Click a marker to jump to its filtered Jobs Table.")
    ),
    partial_note = "A red 'Partial' badge marks a district without a job-board platform: its postings come from its own website and the Wyoming School Boards Association's statewide list, or from that list only. Either can miss openings, so its current-openings count is a floor, not a complete count.",
    map_note = "Only locations with current openings are shown. Circle size = current openings; color = vacancy rate. A red \"Partial\" badge marks a count that is a floor. ",
    county_choices = map_county_choices, pay_bands = PAY_BANDS, he_place_note = he_place_note
  ),

  # ------------------ K-12 ------------------
  nav_menu(
    "K-12", icon = icon("school"),
    # K-12 Jobs tab: the layout and filters are edjobs's jobs_tab_panel(); this is Wyoming's pay note.
    jobs_tab_panel("k12", pay_note = list(POSTED_LISTED_NOTE, paste0("Posted Pay is the pay the job posting itself states (hourly, daily, annual, or a season stipend, as written); blank where the posting gives no figure. ",
        "Typical pay (BLS est.) fills in where the posting states none: the Bureau of Labor Statistics' ",
        if (!is.na(oews_year)) paste0("May ", oews_year, " ") else "",
        "median pay for that role in the posting's region (hover for the role and area; OEWS, all employers, not just schools), so treat it as a regional estimate, not this job's offer. "),
        "Teacher Starting Base is the district's published starting base salary for teachers (BA Step 1, Source: WSBA), shown on teaching postings only. Role Avg Salary is the average total compensation the Wyoming Department of Education reports (Source: WDE602) for that job category in that district (e.g. Teacher, Admin, Aide, Bus Driver, Custodial). It is blank where WDE602 has no matching category, such as substitutes and coaches.")),
    # K-12 Districts tab: edjobs's k12_districts_panel() (step 7 slice 2b); this state's text and salary card.
    k12_districts_panel(sort(unique(mapdata2_k12$Name)), c("Laramie County School District 1", "Natrona School District 1"),
      openings_note = "postings in this week's scrape (all job types) and those new since last week. Posting Data says whether the count is complete (the district's own board) or a floor (only the WSBA statewide list).",
      directory_notes = tagList(
        p(tags$strong("Salaries: "), "starting base for a bachelor's-degree teacher at step 1 and the superintendent's salary (WSBA salary settlements); average teacher pay (WDE602)."),
        p(tags$strong("County and poverty: "), "county median household income, median rent, mining/energy share of jobs and 5-year population change (Census American Community Survey 5-year estimates, with 90% margins of error); school-age children in poverty for the district (Census SAIPE), with its approximate 90% range.")),
      directory_source = "see each group above; full definitions in the District Benchmarks download's (?) on the Data tab.",
      compare_blurb = "Select up to four school districts to evaluate staffing demand, compensation benchmarks, and community demographics side-by-side.",
      salary_card = dash_card("Starting Base & Average Salary",
          withSpinner(plotlyOutput("k12_compare_salary_plot", height = "360px")),
          info = help_popover("Teacher salaries",
            p(tags$strong("Base Starting Salary: "), "the district's published starting salary for a teacher with a bachelor's degree, step 1."),
            p(tags$strong("Average Salary (WDE): "), "the average total pay of the district's teachers."),
            source = "Wyoming School Boards Association salary settlements (starting base); Wyoming Department of Education, Staff Member Collection, WDE602 (average).")),
      openings_source = "each district's own job board, or the Wyoming School Boards Association vacancies list."),
    # K-12 Trends tab: edjobs's k12_trends_panel() (step 7 slice 2b); the note on old board ads (edjobs
    # flag_stale_board_postings(), 2026-11-24; history restated 2026-11-26; METHODS.md "Old board ads").
    k12_trends_panel(k12nowsum, k12sum, counting_note = tagList(
      tags$strong("How postings are counted: "),
      "a job listed on both a district's own board and WSBA's statewide list counts once, from the district's board. ",
      "Board ads posted (or closing) before the July 1 that began the previous school year aren't counted, in any week shown ",
      "(each week by its own date), except substitute pools and jobs districts advertise all year (bus drivers, paraprofessionals, ",
      "custodians, food service, coaches).")),
    k12_spells_panel()
  ),

  # ------------------ Higher Ed ------------------
  nav_menu(
    "Higher Ed", icon = icon("building-columns"),
    # Higher Ed Jobs tab: the layout and filters are edjobs's jobs_tab_panel(); this is Wyoming's pay note.
    jobs_tab_panel("he", pay_note = list(POSTED_LISTED_NOTE, "Posted Pay is the pay the job posting itself states (hourly, annual, or per credit hour, as written); blank where the posting gives no figure. Typical pay (est.) fills in for salaried staff postings that state none, not this job's offer: for the University of Wyoming, the median salary of UW staff with the same title in UW's published salary book; for the other colleges, the college's average pay for its full-time staff in that job category (IPEDS). Hover for the source. Hourly and student jobs get no estimate. Avg. Salary, Full-Time Instructional Staff is the college's IPEDS average for full-time instructional staff on 9- to 12-month contracts, all ranks (via the Urban Institute), not this job's offer.")),
    # Higher Ed Colleges tab: edjobs's he_colleges_panel() (step 7 slice 2b); Wyoming's Salaries and County notes.
    he_colleges_panel(sort(unique(mapdata2_he$Name)), c("University of Wyoming", "Laramie County Community College"),
      salaries_note = "IPEDS average salary of full-time instructional staff on 9- to 12-month contracts, all ranks, for the latest three years, and the professor-rank average.",
      county_note = "the college's county's median income and rent (Census American Community Survey 5-year estimates)."),
    # Higher Ed Trends tab: edjobs's he_trends_panel() (step 7 slice 2b).
    he_trends_panel(henowsum_he, hesum_he),
    he_spells_panel()
  ),

  # ------------------ Data & community ------------------
  # Data tab: the layout and the text both states share are edjobs's data_tab_panel(); this is Wyoming's own text.
  data_tab_panel(
    tiles = list(
      data_tile("download_active_k12",
                "All current public school job openings in Wyoming with standardized titles, positions, locations, links, and district/role salary benchmarks.",
                sources = "each district's own job board, or the Wyoming School Boards Association vacancies list; Typical pay: BLS Occupational Employment and Wage Statistics; Teacher Starting Base: WSBA salary settlements; Role Avg Salary: WDE602."),
      data_tile("download_history_k12",
                paste0("Every teaching posting in every update since August 2024", rows_phrase(download_rows("k12jobanalysis.csv")),
                       ", with subject categories. Teaching jobs only.")),
      data_tile("download_spells",
                "Each posting's first and last week on the boards this dashboard tracks, with NCES LEAID, days listed, and subject flags (STEM, SPED, etc.). Not a time-to-fill measure: see the note on the Listing Duration tab."),
      data_tile("download_district_benchmarks",
                "District profiles: NCES LEAID, WSBA base salaries, WDE avg salaries, NCES teacher FTE & enrollment, student-to-teacher ratios, and Census poverty/rent.",
                heading = "District Benchmarks",
                sources = "WSBA salary settlements; WDE602; NCES Common Core of Data (via the Urban Institute); Census American Community Survey 5-year estimates and SAIPE."),
      data_tile("download_wde_staff",
                "Wyoming Dept of Education staffing matrix: average total & base salaries and FTE counts for the 48 school districts and 3 charter schools across 30+ assignment categories.",
                icon = "users", heading = "WDE602 Staff Matrix", label = "WDE602 Matrix (CSV)",
                sources = "Wyoming Department of Education, Staff Member Collection (WDE602).",
                dictionary_file = "wde602_district_staff_salaries.csv"),
      data_tile("download_history_he",
                paste0("Every faculty and adjunct posting in every update since August 2024 (no staff postings), across Wyoming's 8 community colleges and the University of Wyoming",
                       rows_phrase(download_rows("facultydata.csv")), ".")),
      data_tile("download_he_spells"),
      data_tile("download_he_benchmarks"),
      data_tile("download_weekly_totals",
                "Open posting counts per district at each update (twice a week), all job types. Postings, not vacancies.",
                label = "K-12 Weekly Totals (CSV)"),
      data_tile("download_he_weekly_totals",
                "Open posting counts per college at each update (twice a week), all job types. Postings, not vacancies."),
      data_tile("download_dictionary")
    ),
    dictionary = data_dictionary,
    provenance_title = "Data Provenance & Methodology",
    provenance_intro = "This project integrates 7 primary public data layers, updated twice a week (job postings) or when each federal or state source publishes (yearly for most):",
    provenance_headers = c("Data Layer", "Source Organization", "Update Cadence", "Scope & Description"),
    provenance_table_class = "table table-striped table-hover", provenance_table_style = "font-size: 13px;",
    provenance_rows = list(
      data_provenance_row(layer = "Job Openings", source = "District Hiring Portals & Statewide Feeds",
                          cadence = "Twice weekly", badge = "success",
                          description = "Read from each district's job board (AppliTrack, SchoolSpring, Red Rover, TedK12, Paylocity, or its own website), WSBA's statewide vacancies list, and each college's board (NEOGOV, PeopleAdmin, UW's Oracle site). A job listed on both a district board and WSBA counts once; board ads from before the previous school year are left out (except substitute pools and jobs advertised all year); postings are sorted into role categories."),
      data_provenance_row(layer = "Starting Base Salaries", source = "Wyoming School Boards Association (WSBA)", cadence = "Annual",
                          description = paste0("Starting base salary for a teacher with a bachelor's degree (step 1) and the superintendent's salary, from WSBA's salary documents; ",
                                               sum(!is.na(mapdata2_k12$Teacher_Base_Salary)), " districts on the map have a starting base.")),
      data_provenance_row(layer = "Average Salaries by Role", source = "Wyoming Department of Education (WDE602)", cadence = "Annual",
                          description = "Official state collection reporting actual average total compensation and FTE for teachers, administrators, counselors, aides, and support staff across all districts."),
      data_provenance_row("ccd_staffing", layer = "Staffing Headcounts & FTE"),
      data_provenance_row("ipeds_pay",
                          description = "Average salaries of full-time instructional staff on 9- to 12-month contracts (all ranks and full professor rank) for Wyoming's 7 community colleges, Gillette College, and the University of Wyoming."),
      data_provenance_row("county"),
      data_provenance_row("student_need")
    ),
    citation = "Bostick, M., & Perkins, M. (2026). Wyoming Education Jobs Dashboard: Longitudinal Staffing Demand, Compensation, and Socioeconomic Context. ",
    repo_url = "https://github.com/bostickmike/Wyoming-Education-Jobs-Dashboard"
  ),

  nav_spacer(),
  feedback_nav_item(FEEDBACK_REPO_DEFAULT)
)


#--------------------------------------------------
# Server
#--------------------------------------------------
server <- function(input, output, session) {
  # Outputs and observers both states share (edjobs dashboard_server_shared(), step 7 slice 1, 2026-11-21). This
  # state's own blocks follow and read the reactives it returns.
  shared <- dashboard_server_shared(input, output, session,
                                    data = mget(dashboard_server_data_names(), inherits = TRUE),
                                    state_name = "Wyoming", feedback_repo = FEEDBACK_REPO_DEFAULT,
                                    timezone = "America/Denver",
                                    map_view = list(lng = -107.5, lat = 43, zoom = 7), he_page_length = 9,
                                    he_shared_salary_note = "Shared salary & vacancy-rate reporting w/ Sheridan & Gillette",
                                    district_spec = DISTRICT_SPEC)
  k12_not_marked_only <- shared$k12_not_marked_only
  selected_district <- shared$selected_district
  selected_k12_query <- shared$selected_k12_query
  selected_k12_type <- shared$selected_k12_type
  selected_pay_band <- shared$selected_pay_band
  map_filtered <- shared$map_filtered
  filtered_hesum <- shared$filtered_hesum


  output$download_wde_staff <- downloadHandler(
    filename = function() { paste0("wyoming_wde602_staff_salaries_", Sys.Date(), ".csv") },
    content = function(file) {
      file.copy("wde602_district_staff_salaries.csv", file)
    }
  )

}

shinyApp(ui, server)
