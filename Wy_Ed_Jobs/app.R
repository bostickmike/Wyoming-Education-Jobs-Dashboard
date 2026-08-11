library(shiny)
library(shinydashboard)
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

validate_and_pad_schema <- function(df, required_cols, source_name) {
  missing <- setdiff(required_cols, names(df))
  if (length(missing) > 0) {
    DATA_LOAD_ISSUES <<- c(DATA_LOAD_ISSUES, sprintf(
      "%s is missing expected column(s): %s. That data will show blank until the pipeline is fixed.",
      source_name, paste(missing, collapse = ", ")
    ))
    for (col in missing) df[[col]] <- NA
  }
  df
}

# The repository pipeline classifies these same title patterns in
# k12_he_classification.R. Keep the deployed app self-contained while the
# dashboard distinguishes appointment type without inferring FTE where a
# source does not explicitly provide it.
classify_he_appointment <- function(titles) {
  titles <- as.character(titles)
  dplyr::case_when(
    grepl("Adjunct|Part[- ]?Time", titles, ignore.case = TRUE) ~ "Adjunct/part-time faculty",
    grepl("Instructor|Instructional|Teacher|Faculty|Professor|Lecturer|Post Doc|Subject Matter Expert|Librarian|Educator",
          titles, ignore.case = TRUE) ~ "Faculty/instructor (non-adjunct)",
    TRUE ~ "Other / not faculty"
  )
}

summarize_he_faculty_postings <- function(titles) {
  appointment <- classify_he_appointment(titles)
  list(
    faculty_instructor = sum(appointment == "Faculty/instructor (non-adjunct)", na.rm = TRUE),
    adjunct_part_time = sum(appointment == "Adjunct/part-time faculty", na.rm = TRUE)
  )
}

# Sources that keep evergreen pools active may retain an original posting
# date for years. Make that distinction visible without discarding a still-
# open opportunity or inventing a newer date the source does not provide.
format_posted_or_listed_date <- function(dates, stale_after_days = 180) {
  values <- as.character(dates)
  parsed <- as.Date(lubridate::parse_date_time(
    values,
    orders = c("ymd", "mdy", "dmy", "b d Y h:M p", "B d Y h:M p", "Y-m-d H:M:S"),
    tz = "UTC",
    quiet = TRUE
  ))
  stale <- !is.na(parsed) & parsed < Sys.Date() - stale_after_days
  values[stale] <- paste("Listed since", values[stale])
  values
}

#--------------------------------------------------
# Load K-12 data
#--------------------------------------------------
combineddata <- read.csv("combinedclean.csv", fileEncoding = "UTF-8") %>%
  validate_and_pad_schema(c("District", "title", "position", "location", "date_posted", "url"), "combinedclean.csv") %>%
  select(District, title, position, location, date_posted, url) %>%
  mutate(District = str_squish(as.character(District))) %>%
  mutate(date_posted = format_posted_or_listed_date(date_posted)) %>%
  arrange(District, title) %>%
  mutate(url = paste0('<a href="', url, '" target="_blank">', url, '</a>')) %>%
  rename(Title = title, Position = position, Location = location,
         `Posted / listed` = date_posted, Link = url)

mapdata2_k12 <- read.csv("salarymap2.csv", fileEncoding = "UTF-8") %>%
  validate_and_pad_schema(c("District", "County", "Latitude", "Longitude", "Job_Link",
                             "Teacher_Base_Salary", "Teacher_Base_Salary_Prior_Year", "Salary_Year",
                             "Superintendent_Salary", "Superintendent_Contract_Days", "Salary_Source",
                             "Teachers_Total_FTE", "Data_Coverage", "Enrollment",
                             "Median_Household_Income", "Median_Gross_Rent", "Mining_Employment_Share",
                             "Population_Change_Pct", "ACS_Year", "Child_Poverty_Rate", "SAIPE_Year"),
                           "salarymap2.csv") %>%
  rename(Name = District)

# Weekly ALL-category posting totals per district/institution (not scoped
# to Teacher/Faculty like k12_history/he_history below) -- powers the
# sparkline trend next to each entity's raw count on the Top Hiring
# tables, matching that same all-category count rather than a
# teacher/faculty-only proxy that wouldn't line up with the number shown.
k12_district_weekly_totals <- read.csv("k12_district_weekly_totals.csv", fileEncoding = "UTF-8") %>%
  validate_and_pad_schema(c("District", "Archive_Date", "n"), "k12_district_weekly_totals.csv") %>%
  mutate(Archive_Date = as.Date(Archive_Date))
he_institution_weekly_totals <- read.csv("he_institution_weekly_totals.csv", fileEncoding = "UTF-8") %>%
  validate_and_pad_schema(c("Institution", "Archive_Date", "n"), "he_institution_weekly_totals.csv") %>%
  mutate(Archive_Date = as.Date(Archive_Date))

# Tiny inline trend chart (no axes/legend, just the shape of a trend) for
# the Top Hiring tables -- lets "31 openings" read differently depending
# on whether that's a district climbing steadily or one that just posted a
# batch this week, without a separate chart. Plain SVG string templating
# rather than a real ggplot/plotly render, since this needs to be cheap
# enough to generate per table row.
make_sparkline_svg <- function(series, accent = "#2a78d6") {
  series <- series[!is.na(series)]
  if (length(series) < 2) return("")

  w <- 96; h <- 28; pad <- 3
  rng <- range(series)
  span <- diff(rng)
  if (span == 0) span <- 1

  n <- length(series)
  step_x <- (w - pad * 2) / (n - 1)
  xs <- pad + (seq_len(n) - 1) * step_x
  ys <- pad + (1 - (series - rng[1]) / span) * (h - pad * 2)

  line_path <- paste0(ifelse(seq_along(xs) == 1, "M", "L"), round(xs, 1), ",", round(ys, 1), collapse = " ")
  area_path <- paste0(line_path, " L", round(xs[n], 1), ",", h - pad, " L", round(xs[1], 1), ",", h - pad, " Z")

  dot_color <- if (series[n] > series[1]) "#1baf7a" else if (series[n] < series[1]) "#e34948" else "#999999"

  sprintf(
    '<svg width="%d" height="%d" viewBox="0 0 %d %d" style="vertical-align:middle;"><path d="%s" fill="%s22" stroke="none"></path><path d="%s" fill="none" stroke="%s" stroke-width="1.75" stroke-linejoin="round" stroke-linecap="round"></path><circle cx="%s" cy="%s" r="2.5" fill="%s"></circle></svg>',
    w, h, w, h, area_path, accent, line_path, accent, round(xs[n], 1), round(ys[n], 1), dot_color
  )
}

# Larger, monochrome-white variant for the KPI tiles' icon slot -- replaces
# the plain school/university icon with the same last-12-weeks trend
# shown on the Top Hiring tables, since a colored valueBox background
# doesn't have room for a second color scheme to read clearly.
make_sparkline_svg_light <- function(series) {
  series <- series[!is.na(series)]
  if (length(series) < 2) return("")

  w <- 160; h <- 80; pad <- 6
  rng <- range(series)
  span <- diff(rng)
  if (span == 0) span <- 1

  n <- length(series)
  step_x <- (w - pad * 2) / (n - 1)
  xs <- pad + (seq_len(n) - 1) * step_x
  ys <- pad + (1 - (series - rng[1]) / span) * (h - pad * 2)

  line_path <- paste0(ifelse(seq_along(xs) == 1, "M", "L"), round(xs, 1), ",", round(ys, 1), collapse = " ")
  area_path <- paste0(line_path, " L", round(xs[n], 1), ",", h - pad, " L", round(xs[1], 1), ",", h - pad, " Z")

  sprintf(
    '<svg width="%d" height="%d" viewBox="0 0 %d %d"><path d="%s" fill="rgba(255,255,255,0.18)" stroke="none"></path><path d="%s" fill="none" stroke="rgba(255,255,255,0.85)" stroke-width="2.5" stroke-linejoin="round" stroke-linecap="round"></path><circle cx="%s" cy="%s" r="3.5" fill="#ffffff"></circle></svg>',
    w, h, w, h, area_path, line_path, round(xs[n], 1), round(ys[n], 1)
  )
}

# Current Trends table -- replaces what used to be a horizontal bar chart
# plus a separate sparkline table. Once every bar was already labeled
# with its exact count and a table below repeated those same numbers,
# the bar chart wasn't earning its space (user feedback 2026-08-05).
# One row per category: current count, a 12-week sparkline, and delta
# vs month/quarter/year ago. Week-over-week is deliberately not included
# here -- confirmed against real data it's pure noise at the category
# level (median absolute delta 0), the same finding that shaped
# find_biggest_mover()'s window above. Month is weak but real signal
# (median 1); quarter is strong (median 4) but conflates the actual
# within-year seasonal hiring cycle (e.g. Elementary postings peak in
# spring, trough in late summer) with real change; year isolates
# genuine year-over-year movement by comparing two points at the same
# place in that cycle (confirmed distinct from quarter with real data:
# Elementary was -31 quarter-over-quarter but only -17 year-over-year
# for the same "now").
#
# history: data.frame(Category, Archive_Date, n) already filtered to
# one district/institution and already summed across any other
# dimension (e.g. HE's Job_Type, so this shows category totals, not an
# FT/PT breakdown -- the FT/PT split isn't lost, just no longer show
# here since the bar chart carrying it is gone; Jobs Table / New This
# Week still show individual postings).
build_current_trends_table <- function(history, accent) {
  dates <- sort(unique(history$Archive_Date))
  if (length(dates) == 0) return(NULL)
  latest <- max(dates)

  nearest_on_or_before <- function(target) {
    candidates <- dates[dates <= target]
    if (length(candidates) == 0) return(NA)
    max(candidates)
  }
  month_ago <- nearest_on_or_before(latest - 28)
  quarter_ago <- nearest_on_or_before(latest - 90)
  year_ago <- nearest_on_or_before(latest - 365)

  current <- history %>%
    filter(Archive_Date == latest) %>%
    group_by(Category) %>%
    summarize(`Current Postings` = sum(n), .groups = "drop") %>%
    arrange(desc(`Current Postings`))
  if (nrow(current) == 0) return(NULL)

  value_at <- function(cat, date) {
    if (is.na(date)) return(NA_integer_)
    v <- history$n[history$Category == cat & history$Archive_Date == date]
    if (length(v) == 0) 0L else sum(v)
  }
  fmt_delta <- function(now, then) {
    if (is.na(then)) return("<span style='color:#999;'>—</span>")
    d <- now - then
    color <- if (d > 0) "#1baf7a" else if (d < 0) "#e34948" else "#999999"
    arrow <- if (d >= 0) "▲" else "▼"
    sprintf("<span style='color:%s;'>%s %d</span>", color, arrow, abs(d))
  }

  current$`Last 12 Weeks` <- vapply(current$Category, function(cat) {
    series <- history %>%
      filter(Category == cat) %>%
      group_by(Archive_Date) %>%
      summarize(n = sum(n), .groups = "drop") %>%
      arrange(Archive_Date) %>%
      tail(12) %>%
      pull(n)
    make_sparkline_svg(series, accent = accent)
  }, character(1))

  current$`vs Month Ago` <- mapply(function(cat, now) fmt_delta(now, value_at(cat, month_ago)),
                                    current$Category, current$`Current Postings`)
  current$`vs Quarter Ago` <- mapply(function(cat, now) fmt_delta(now, value_at(cat, quarter_ago)),
                                      current$Category, current$`Current Postings`)
  current$`vs Year Ago` <- mapply(function(cat, now) fmt_delta(now, value_at(cat, year_ago)),
                                   current$Category, current$`Current Postings`)

  current
}

# Statewide week-over-week delta for the KPI tiles -- aggregation smooths
# individual-entity noise into a real signal (confirmed against real data
# 2026-08-05: statewide K-12 totals move ~20-50/week, HE climbed steadily
# 439->487 over 4 weeks, but per-district week-over-week deltas have a
# median absolute value of 0 -- see find_biggest_mover()'s longer window
# below for why that metric uses a different timeframe).
#
# Uses the same min_days_back-eligible-snapshot pattern as
# find_biggest_mover() below rather than the literal last two distinct
# dates -- archive cadence isn't perfectly regular (multiple same-week CI
# test runs exist historically, see Archivek12_Data's 2026-08-03 entries),
# and without this guard an extra same-week run would make "vs last week"
# compare today against a snapshot from hours or a day earlier instead of a
# real week ago, understating or fabricating the KPI tile's headline delta.
compute_wow_delta <- function(weekly_totals, min_days_back = 5) {
  totals <- weekly_totals %>% group_by(Archive_Date) %>% summarize(n = sum(n), .groups = "drop") %>% arrange(Archive_Date)
  if (nrow(totals) < 2) return(NA_integer_)
  latest <- max(totals$Archive_Date)
  candidates <- totals$Archive_Date[totals$Archive_Date <= latest - min_days_back]
  if (length(candidates) == 0) return(NA_integer_)
  prior <- max(candidates)
  totals$n[totals$Archive_Date == latest] - totals$n[totals$Archive_Date == prior]
}

# "Biggest mover" needs a longer window than a week to mean anything --
# individual districts/institutions are mostly flat week-to-week (median
# absolute change 0 in real data), but real movement shows up over ~3+
# weeks (Natrona SD1 +22 postings, University of Wyoming +52, both over
# a 4-week span). Picks the nearest available snapshot at least
# min_days_back before the latest date rather than a fixed index, since
# archive cadence isn't perfectly regular (multiple same-week CI test
# runs exist historically -- see Archivek12_Data's 2026-08-03 entries).
find_biggest_mover <- function(weekly_totals, name_col, min_days_back = 21) {
  dates <- sort(unique(weekly_totals$Archive_Date))
  if (length(dates) < 2) return(NULL)
  latest <- max(dates)
  candidates <- dates[dates <= latest - min_days_back]
  if (length(candidates) == 0) return(NULL)
  prior <- max(candidates)

  wide <- weekly_totals %>%
    filter(Archive_Date %in% c(latest, prior)) %>%
    tidyr::pivot_wider(names_from = Archive_Date, values_from = n, values_fill = 0)
  names(wide)[names(wide) == as.character(prior)] <- "Prior"
  names(wide)[names(wide) == as.character(latest)] <- "Latest"
  wide$Delta <- wide$Latest - wide$Prior

  top <- wide %>% arrange(desc(abs(Delta))) %>% slice(1)
  list(name = top[[name_col]], prior = top$Prior, latest = top$Latest, delta = top$Delta,
       prior_date = prior, latest_date = latest)
}

render_mover_box <- function(mover, label) {
  if (is.null(mover)) return(NULL)
  arrow <- if (mover$delta >= 0) "▲" else "▼"
  delta_color <- if (mover$delta >= 0) "#1baf7a" else "#e34948"
  box(width = 12, status = "info",
      div(
        tags$span(style = "font-weight:bold;", paste0(label, ": ")),
        tags$span(mover$name),
        tags$span(style = paste0("color:", delta_color, "; font-weight:bold; margin-left:8px;"),
                   paste0(arrow, " ", abs(mover$delta))),
        tags$span(style = "color:#999; font-size:0.85em; margin-left:6px;",
                   paste0("(", mover$prior, " → ", mover$latest,
                          " since ", format(mover$prior_date, "%b %d"), ")"))
      )
  )
}

k12sum <- read.csv("allsum.csv", fileEncoding = "UTF-8") %>%
  validate_and_pad_schema(c("Broad_Category", "Archive_Date", "District", "sum"), "allsum.csv") %>%
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
  validate_and_pad_schema(c("Broad_Category", "Sum", "District"), "allnow.csv") %>%
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
ccdata <- read_xlsx("hedata.xlsx") %>%
  validate_and_pad_schema(c("Institution", "Title", "Location", "Posted_Date", "Link"), "hedata.xlsx") %>%
  select(Institution, Title, Location, Posted_Date, Link) %>%
  arrange(Institution, Title) %>%
  mutate(
    Appointment = classify_he_appointment(Title),
    Posted_Date = format_posted_or_listed_date(Posted_Date)
  ) %>%
  rename(`Posted / listed` = Posted_Date)
ccdata$Link <- paste0('<a href="', ccdata$Link, '" target="_blank">', ccdata$Link, '</a>')
he_faculty_counts <- summarize_he_faculty_postings(ccdata$Title)

mapdata2_he <- read.csv("salarymap.csv") %>%
  validate_and_pad_schema(c("Name", "Longitude", "Latitude", "Link", "Faculty_Avg_Salary",
                             "Faculty_Avg_Salary_Professor", "Faculty_Count", "Salary_Year",
                             "Salary_Note", "Salary_Source", "Faculty_Avg_Salary_Y1Ago", "Faculty_Avg_Salary_Y2Ago",
                             "County", "Median_Household_Income", "Median_Gross_Rent",
                             "Mining_Employment_Share", "Population_Change_Pct", "ACS_Year",
                             "Enrollment", "Enrollment_Change_Pct", "Pell_Recipient_Share", "Pell_Year"),
                           "salarymap.csv") %>%
  mutate(Salary_Year = as.character(Salary_Year), Pell_Year = as.character(Pell_Year))

hesum_he <- read.csv("allsum_he.csv") %>%
  validate_and_pad_schema(c("Category", "Archive_Date", "Institution", "Job_Type", "sum"), "allsum_he.csv") %>%
  filter(Category != "Uncategorized")

hesum_he$Archive_Date <- as.Date(hesum_he$Archive_Date)

# Same gap-filling as k12sum above -- a Category/Institution/Job_Type
# combination with zero postings in a given week is simply missing from
# the source aggregation, not an explicit 0.
hesum_he <- hesum_he %>%
  tidyr::complete(Category, Archive_Date, Institution, Job_Type, fill = list(sum = 0))
he_dates <- sort(unique(hesum_he$Archive_Date))
WINDOW_WEEKS <- 52
hesum_he$Category<- as.factor(hesum_he$Category)

henowsum_he <- read.csv("allnow_he.csv") %>%
  validate_and_pad_schema(c("Category", "Job_Type", "Sum", "Institution"), "allnow_he.csv") %>%
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
# "New this week" -- row-level history, diffed against the previous
# archived week by (identity columns), scoped to Teacher/Faculty postings
# same as the rest of the trend tabs (k12jobanalysis.csv/facultydata.csv
# are already filtered that way upstream).
#--------------------------------------------------
k12_history <- read.csv("k12jobanalysis.csv", fileEncoding = "UTF-8") %>%
  validate_and_pad_schema(c("title", "Archive_Date", "location", "District"), "k12jobanalysis.csv") %>%
  mutate(Archive_Date = as.Date(Archive_Date))

k12_new_this_week <- {
  dates <- sort(unique(k12_history$Archive_Date))
  if (length(dates) >= 2) {
    latest <- dates[length(dates)]
    previous <- dates[length(dates) - 1]
    k12_history %>%
      filter(Archive_Date == latest) %>%
      anti_join(k12_history %>% filter(Archive_Date == previous), by = c("title", "location", "District"))
  } else {
    k12_history[0, ]
  }
}

he_history <- read.csv("facultydata.csv", fileEncoding = "UTF-8") %>%
  validate_and_pad_schema(c("Title", "Location", "Institution", "Link", "Archive_Date", "Job_Type", "Category"), "facultydata.csv") %>%
  mutate(Archive_Date = as.Date(Archive_Date)) %>%
  filter(Job_Type %in% c("Instructor/Teacher/Faculty", "Adjunct/Part-Time Faculty")) %>%
  mutate(Appointment = dplyr::recode(
    Job_Type,
    "Instructor/Teacher/Faculty" = "Faculty/instructor (non-adjunct)",
    "Adjunct/Part-Time Faculty" = "Adjunct/part-time faculty"
  ))

he_new_this_week <- {
  dates <- sort(unique(he_history$Archive_Date))
  if (length(dates) >= 2) {
    latest <- dates[length(dates)]
    previous <- dates[length(dates) - 1]
    he_history %>%
      filter(Archive_Date == latest) %>%
      anti_join(he_history %>% filter(Archive_Date == previous), by = c("Title", "Location", "Institution"))
  } else {
    he_history[0, ]
  }
}

#--------------------------------------------------
# Combined map dataset -- one row per K-12 district or HE institution,
# merging each entity's existing location/salary reference data with a
# live current-openings count, a couple of sample current titles, and a
# new-this-week count (reusing k12_new_this_week/he_new_this_week above,
# so it's the same Teacher/Faculty-scoped definition of "new" as the New
# This Week tabs, not a separate metric).
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

# WSBA's Salary_Year is a "2025-2026"-style school-year range -- the prior
# year is that same range shifted back by one, not a separate value we
# fetch. Used to put the actual year in the K-12 summary table's column
# headers instead of a generic "Prior Year" label.
prior_school_year_label <- function(year_label) {
  parts <- regmatches(year_label, gregexpr("[0-9]{4}", year_label))[[1]]
  if (length(parts) != 2) return(NA_character_)
  paste0(as.integer(parts[1]) - 1, "-", as.integer(parts[2]) - 1)
}

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
         Superintendent_Salary, Superintendent_Contract_Days,
         Faculty_Avg_Salary, Faculty_Avg_Salary_Professor, Faculty_Count,
         Faculty_Avg_Salary_Y1Ago, Faculty_Avg_Salary_Y2Ago, Salary_Note,
         Vacancy_Rate, Vacancy_Numerator, Vacancy_Denominator, Vacancy_Rate_Shared, Salary_Source, County,
         Data_Coverage, Enrollment, Students_Per_Teacher, Enrollment_Change_Pct, Pell_Recipient_Share, Pell_Year,
         Median_Household_Income, Median_Gross_Rent, Mining_Employment_Share, Population_Change_Pct, ACS_Year,
         Child_Poverty_Rate, SAIPE_Year)

he_current_counts <- ccdata %>% count(Institution, name = "CurrentCount")
he_sample_titles <- ccdata %>%
  group_by(Institution) %>%
  summarize(SampleTitles = paste(head(Title, 3), collapse = "; "), .groups = "drop")
he_weekly_new <- he_new_this_week %>% count(Institution, name = "WeeklyNew")

# he_history is already scoped to Job_Type == "Instructor/Teacher/Faculty"
# (full-time only, excluding the standing adjunct pool) -- matches
# Faculty_Count's own scope, since IPEDS's salaries-instructional-staff
# survey only covers full-time instructional staff. Mixing in
# Adjunct/Part-Time postings here would overstate the rate the same way
# using CurrentCount (all K-12 job categories) would on the K-12 side.
he_faculty_current_counts <- he_history %>%
  filter(Archive_Date == max(Archive_Date)) %>%
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
    Vacancy_Rate_Shared = !is.na(Salary_Note),
    Vacancy_Numerator = ifelse(Vacancy_Rate_Shared,
                                sum(FacultyCurrentCount[!is.na(Salary_Note)]),
                                FacultyCurrentCount),
    Vacancy_Rate = ifelse(!is.na(Faculty_Count) & Faculty_Count >= VACANCY_RATE_MIN_FTE,
                           Vacancy_Numerator / Faculty_Count, NA_real_),
    Vacancy_Denominator = Faculty_Count,
    Teacher_Base_Salary = NA_real_, Teacher_Base_Salary_Prior_Year = NA_real_,
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
    Child_Poverty_Rate = NA_real_, SAIPE_Year = NA_integer_
  ) %>%
  select(Name, Longitude, Latitude, Type, CurrentCount, WeeklyNew, SampleTitles,
         Link, Teacher_Base_Salary, Teacher_Base_Salary_Prior_Year, Salary_Year,
         Superintendent_Salary, Superintendent_Contract_Days,
         Faculty_Avg_Salary, Faculty_Avg_Salary_Professor, Faculty_Count,
         Faculty_Avg_Salary_Y1Ago, Faculty_Avg_Salary_Y2Ago, Salary_Note,
         Vacancy_Rate, Vacancy_Numerator, Vacancy_Denominator, Vacancy_Rate_Shared, Salary_Source, County,
         Data_Coverage, Enrollment, Students_Per_Teacher, Enrollment_Change_Pct, Pell_Recipient_Share, Pell_Year,
         Median_Household_Income, Median_Gross_Rent, Mining_Employment_Share, Population_Change_Pct, ACS_Year,
         Child_Poverty_Rate, SAIPE_Year)

combined_map_data <- bind_rows(map_k12, map_he)

# Map marker size/color -- radius scaled by sqrt(CurrentCount), not
# CurrentCount directly, since a circle's perceived size is its area, not
# its radius (linear scaling would visually overstate the gap between a
# 10-opening and a 100-opening district). Color is a single-hue sequential
# ramp on Vacancy_Rate (a bounded 0-100% "severity" dimension that pairs
# naturally with size-as-volume) rather than salary, which would need two
# separate ramps for K-12 vs. HE's different pay scales. Domain is fixed
# from the full unfiltered dataset so the color scale (and legend) don't
# shift as the K-12/HE checkbox filter changes what's on screen.
MAP_MARKER_MIN_RADIUS <- 6
MAP_MARKER_MAX_RADIUS <- 24
map_marker_radius <- function(current_count) {
  pmin(MAP_MARKER_MAX_RADIUS, MAP_MARKER_MIN_RADIUS + 1.2 * sqrt(current_count))
}
# If every Vacancy_Rate is NA (both the CCD and IPEDS staffing fetches
# failing the same week, or a fresh checkout before either has ever
# succeeded once), range(..., na.rm = TRUE) on an all-NA vector returns
# c(Inf, -Inf) with a warning -- colorNumeric() then gets an invalid
# domain and the map's color legend breaks for every user, not just the
# vacancy-rate feature. Falls back to a placeholder 0-1 domain (never
# actually used to color a marker, since every Vacancy_Rate would be NA
# too, rendering na.color everywhere) so the legend itself stays valid.
# Kept as its own function (rather than inlined) so the all-NA branch is
# unit-testable without constructing a full combined_map_data.
compute_vacancy_rate_domain <- function(vacancy_rate) {
  if (all(is.na(vacancy_rate))) c(0, 1) else range(vacancy_rate, na.rm = TRUE)
}
vacancy_rate_domain <- compute_vacancy_rate_domain(combined_map_data$Vacancy_Rate)
vacancy_rate_palette <- colorNumeric(palette = "YlOrRd", domain = vacancy_rate_domain, na.color = "#9e9e9e")

#--------------------------------------------------
# UI
#--------------------------------------------------
ui <- dashboardPage(
  skin = 'black',
  dashboardHeader(title = "Wyo Edu Jobs"),
  dashboardSidebar(
    sidebarMenu(
      id = "sidebar_tabs",
      menuItem("Home", tabName = "intro", icon = icon("house")),
      menuItem("Map", tabName = "map_tab", icon = icon("map-location-dot")),
      menuItem("K-12 Careers", tabName = "k12_root", icon = icon("school"),
               menuSubItem("Jobs Table", tabName = "k12_table"),
               menuSubItem("District Summary", tabName = "k12_summary"),
               menuSubItem("Longitudinal Teacher Trends", tabName = "k12_trends"),
               menuSubItem("Current Teacher Trends", tabName = "k12_current"),
               menuSubItem("New This Week", tabName = "k12_new")
      ),
      menuItem("Higher Ed Careers", tabName = "he_root", icon = icon("university"),
               menuSubItem("Jobs Table", tabName = "he_table"),
               menuSubItem("Institution Summary", tabName = "he_summary"),
               menuSubItem("Longitudinal Faculty Trends", tabName = "he_trends"),
               menuSubItem("Current Faculty Trends", tabName = "he_current"),
               menuSubItem("New This Week", tabName = "he_new")
      )
    )
  ),
  dashboardBody(
    tags$head(
      tags$style(HTML("
    /* AdminLTE's header logo box clips long titles by default (was
       already truncating the shorter old title too) -- shrinking the
       font is safer than widening the box, which is fixed-width and
       tightly coupled to the sidebar-toggle button's position. */
    .main-header .logo {
      font-size: 19px;
    }
    .leaflet-tooltip {
      max-width: 800px !important;  /* make tooltip wide */
      min-width: 400px !important;  /* optional: ensures minimum width */
      white-space: normal !important;  /* text can wrap if needed */
      background-color: rgba(255,255,255,0.95);
      padding: 6px 10px;
      border-radius: 6px;
      border: 1px solid gray;
      font-size: 14px;
      display: inline-block;
    }
  ")),
      tags$script(HTML("
    // On mobile, AdminLTE's sidebar opens as a full-width overlay (body
    // gets a 'sidebar-open' class) and, unlike the desktop mini-sidebar
    // behavior, never closes itself after a link is clicked -- it stays
    // open over the content until manually toggled. Only real navigation
    // links carry data-toggle='tab' (a treeview parent like 'K-12 Careers'
    // that just expands/collapses its submenu doesn't), so this closes the
    // sidebar specifically when the user has actually navigated somewhere,
    // not when they're just opening a category.
    $(document).on('click', '.sidebar-menu a[data-toggle=\"tab\"]', function() {
      if ($(window).width() < 768) {
        $('body').removeClass('sidebar-open');
      }
    });
  "))
    )
    ,
    tabItems(
      # ------------------ Global Introduction ------------------
      tabItem(
        tabName = "intro",
        h1("Education Jobs in Wyoming"),
        uiOutput("data_load_issues_banner"),
        fluidRow(
          valueBoxOutput("kpi_k12_total", width = 4),
          valueBoxOutput("kpi_he_total", width = 4),
          valueBoxOutput("kpi_last_refreshed", width = 4)
        ),
        fluidRow(
          column(width = 6, uiOutput("k12_biggest_mover")),
          column(width = 6, uiOutput("he_biggest_mover"))
        ),
        fluidRow(
          box(title = "Top K-12 Hiring Districts This Week", width = 6, status = "primary",
              div(style = "overflow-x: auto;", tableOutput("top_k12_districts"))),
          box(title = "Top Higher Ed Hiring Institutions This Week", width = 6, status = "primary",
              div(style = "overflow-x: auto;", tableOutput("top_he_institutions")))
        ),
        fluidRow(
          box(title = "Highest Teacher Vacancy Rate", width = 6, status = "primary",
              withSpinner(plotlyOutput("k12_vacancy_leaderboard", height = 320)),
              helpText("Districts with at least", VACANCY_RATE_MIN_FTE, "teacher FTE.")),
          box(title = "Highest Faculty Vacancy Rate", width = 6, status = "primary",
              withSpinner(plotlyOutput("he_vacancy_leaderboard", height = 320)),
              helpText("Institutions with at least", VACANCY_RATE_MIN_FTE, "full-time faculty.",
                        "* Sheridan College and Gillette College are reported jointly by IPEDS and share one combined rate."))
        ),
        div(style = "color:#999; font-size:0.8em; padding: 0 5px 5px;",
            "K-12 vacancy rate is current teacher postings ÷ CCD teacher FTE; Higher Ed vacancy rate is current instructor/faculty postings ÷ IPEDS full-time instructional staff. ",
            "The two use different staffing sources and reporting years — compare rates within a type (district vs. district, institution vs. institution), not across K-12 and Higher Ed."),
        div(style = "text-align:center; color:#999; font-size:0.85em; padding:15px;",
            paste0("Refreshed on: ", last_refreshed_date, " · Programmed by Mark Perkins and Mike Bostick"))
      ),

      tabItem(
        tabName = "map_tab",
        h1("Where the Openings Are"),
        box(width = 12, title = "Wyoming Education Job Openings Map", status = "primary",
            checkboxGroupInput(
              "map_types", "Show:",
              choices = c("K-12 Districts" = "K-12 District", "Higher Ed Institutions" = "Higher Ed Institution"),
              selected = c("K-12 District", "Higher Ed Institution"),
              inline = TRUE
            ),
            withSpinner(leafletOutput("combined_map", height = 650)),
            helpText("Only locations with current openings are shown. Circle size reflects current openings; color reflects teacher/faculty vacancy rate where available. Click a marker to jump to its filtered Jobs Table. K-12 and Higher Ed vacancy rates use different staffing sources (CCD vs. IPEDS) and years -- the shared color scale is for a rough at-a-glance read, not a precise cross-type comparison. A red 'Partial' badge means that district's postings come from Wyoming School Boards Association's statewide feed (which reliably captures only ~25-40% of real openings) instead of the district's own job board -- its current-openings count is a floor, not a complete count.")
        )
      ),

      tabItem(
        tabName = "k12_table",
        uiOutput("k12_filter_status"),
        DTOutput("k12_jobs")
      ),
      tabItem(
        tabName = "k12_summary",
        h4("One row per district -- current openings, teacher vacancy rate, and salary data"),
        DTOutput("k12_summary_table"),
        uiOutput("k12_summary_footnote")
      ),
      tabItem(
        tabName = "k12_new",
        h4("New teacher postings since the previous weekly snapshot"),
        DTOutput("k12_new_table")
      ),

      # ------------------ K-12 ------------------
      tabItem(
        tabName = "k12_trends",

        radioButtons("k12_detail_level_trends", "Category detail:",
                     choices = c("Simple" = "agg", "Detailed" = "detail"),
                     selected = "agg", inline = TRUE),

        # Row for category + district
        fluidRow(
          column(
            width = 6,  # half the row
            pickerInput(
              "broad_category",
              "Choose Teacher Category:",
              choices  = sort(unique(k12sum_agg$Broad_Category)),
              selected = sort(unique(k12sum_agg$Broad_Category)),
              multiple = TRUE,
              width = "100%",
              options = pickerOptions(actionsBox = TRUE, liveSearch = TRUE, selectedTextFormat = "count > 3")
            )
          ),
          column(
            width = 6,  # other half
            selectInput(
              "district_trend",
              "Choose District:",
              choices = sort(unique(k12sum$District)),
              selected = "Total",
              width = "100%"
            )
          )
        ),
        
        # Timeline slider (full width)
        sliderInput(
          "k12_scroll",
          "Scroll timeline:",
          min = min(k12sum$Archive_Date),
          max = max(k12sum$Archive_Date),
          value = c(max(k12sum$Archive_Date) - 365,
                    max(k12sum$Archive_Date)),
          timeFormat = "%Y-%m-%d",
          width = "100%"
        ),
        
        # Plot output
        withSpinner(plotlyOutput("k12_longitudinal_plot"))
      ),
      
      tabItem(
        tabName = "k12_current",

        radioButtons("k12_detail_level_current", "Category detail:",
                     choices = c("Simple" = "agg", "Detailed" = "detail"),
                     selected = "agg", inline = TRUE),

        selectInput(
          "district_current",
          "Choose District:",
          choices = sort(unique(k12nowsum$District)),
          selected = "Total"
        ),

        div(style = "overflow-x: auto;", withSpinner(tableOutput("k12_current_trends_table")))
      ),

      # ------------------ Higher Ed ------------------
      tabItem(
        tabName = "he_table",
        uiOutput("he_filter_status"),
        radioButtons(
          "he_table_appointment", "Appointment:",
          choices = c(
            "All roles" = "all",
            "Faculty/instructor (non-adjunct)" = "Faculty/instructor (non-adjunct)",
            "Adjunct/part-time faculty" = "Adjunct/part-time faculty",
            "Other / not faculty" = "Other / not faculty"
          ),
          selected = "all", inline = TRUE
        ),
        DTOutput("he_jobs")
      ),
      tabItem(
        tabName = "he_summary",
        h4("One row per institution -- current openings, faculty vacancy rate, and salary data"),
        DTOutput("he_summary_table"),
        uiOutput("he_summary_footnote")
      ),
      tabItem(
        tabName = "he_trends",

        radioButtons("he_detail_level_trends", "Category detail:",
                     choices = c("Simple" = "agg", "Detailed" = "detail"),
                     selected = "agg", inline = TRUE),

        # Row for Category + Institution
        fluidRow(
          column(
            width = 6,
            pickerInput(
              "he_category",
              "Choose Category:",
              choices  = sort(unique(hesum_he_agg$Category)),
              selected = sort(unique(hesum_he_agg$Category)),
              multiple = TRUE,
              width = "100%",
              options = pickerOptions(actionsBox = TRUE, liveSearch = TRUE, selectedTextFormat = "count > 3")
            )
          ),
          column(
            width = 6,
            selectInput(
              "inst_trend",
              "Select Institution:",
              choices = sort(unique(hesum_he$Institution)),
              selected = "Total",
              width = "100%"
            )
          )
        ),
        
        # Timeline slider (full width)
        textOutput("he_slider_label"),  # optional label
        sliderInput(
          "he_scroll",
          "Scroll timeline:",
          min = min(hesum_he$Archive_Date),
          max = max(hesum_he$Archive_Date),
          value = c(
            max(hesum_he$Archive_Date) - 365,
            max(hesum_he$Archive_Date)
          ),
          timeFormat = "%Y-%m-%d",
          width = "100%"
        ),
        
        radioButtons("he_chart_type", NULL, choices = c(
          "All Jobs" = "all",
          "Faculty/instructor (non-adjunct)" = "Instructor/Teacher/Faculty",
          "Adjunct/part-time faculty" = "Adjunct/Part-Time Faculty"
        ), selected = "all", inline = TRUE),

        # Plot output
        withSpinner(plotlyOutput("he_longitudinal_plot"))),
      
      tabItem(tabName = "he_current",
              radioButtons("he_detail_level_current", "Category detail:",
                           choices = c("Simple" = "agg", "Detailed" = "detail"),
                           selected = "agg", inline = TRUE),
              radioButtons("he_current_appointment", "Appointment:",
                           choices = c(
                             "All faculty postings" = "all",
                             "Faculty/instructor (non-adjunct)" = "Instructor/Teacher/Faculty",
                             "Adjunct/part-time faculty" = "Adjunct/Part-Time Faculty"
                           ),
                           selected = "all", inline = TRUE),
              selectInput("inst_current", "Select Institution:",
                          choices = sort(unique(henowsum_he$Institution)), selected = "Total"),
              div(style = "overflow-x: auto;", withSpinner(tableOutput("he_current_trends_table")))),

      tabItem(
        tabName = "he_new",
        h4("New faculty postings since the previous weekly snapshot"),
        radioButtons(
          "he_new_appointment", "Appointment:",
          choices = c(
            "All faculty postings" = "all",
            "Faculty/instructor (non-adjunct)" = "Faculty/instructor (non-adjunct)",
            "Adjunct/part-time faculty" = "Adjunct/part-time faculty"
          ),
          selected = "all", inline = TRUE
        ),
        DTOutput("he_new_table")
      )
    )
  )
)


#--------------------------------------------------
# Server
#--------------------------------------------------
server <- function(input, output, session) {

  # Set by clicking a marker on the combined map; cleared by the "Show
  # All" button on each Jobs Table tab.
  selected_district <- reactiveVal(NULL)
  selected_institution <- reactiveVal(NULL)

  # DATA_LOAD_ISSUES is populated once at app startup (see
  # validate_and_pad_schema() above) -- not reactive, but wrapped in
  # renderUI/uiOutput anyway rather than inlined in the UI definition, so
  # the exact same "which source is broken" list a maintainer would see in
  # the R console is also visible to anyone using the deployed dashboard,
  # instead of a blank field or a crash being the only symptom.
  output$data_load_issues_banner <- renderUI({
    req(length(DATA_LOAD_ISSUES) > 0)
    box(width = 12, status = "danger", title = "Data issue detected",
        tags$ul(lapply(DATA_LOAD_ISSUES, tags$li)),
        helpText("This is a schema problem in the underlying data pipeline, not something wrong with your view of the dashboard -- the missing field(s) above need a pipeline fix."))
  })

  # -------- Intro KPIs --------
  # Week-over-week delta as a subtitle line -- compute_wow_delta() works at
  # the statewide-total level specifically because that's where the signal
  # is real (see its definition above for why individual-entity deltas
  # aren't used here).
  wow_delta_ui <- function(delta) {
    if (is.na(delta)) return(NULL)
    arrow <- if (delta >= 0) "▲" else "▼"
    tags$div(style = "font-size: 0.85em; margin-top: 2px;", paste0(arrow, " ", abs(delta), " vs last week"))
  }

  # Statewide last-12-week trend, for the KPI tiles' icon slot -- replaces
  # the plain school/university icon (previously a static hero-photo
  # stand-in) with the same information the sparkline redesign already
  # added everywhere else, since that space was otherwise just decorative.
  statewide_weekly_series <- function(weekly_totals) {
    weekly_totals %>%
      group_by(Archive_Date) %>%
      summarize(n = sum(n), .groups = "drop") %>%
      arrange(Archive_Date) %>%
      tail(12) %>%
      pull(n)
  }

  output$kpi_k12_total <- renderValueBox({
    valueBox(format(nrow(combineddata), big.mark = ","),
             tagList("Open K-12 Postings", wow_delta_ui(compute_wow_delta(k12_district_weekly_totals))),
             icon = tags$i(HTML(make_sparkline_svg_light(statewide_weekly_series(k12_district_weekly_totals)))),
             color = "blue")
  })
  output$kpi_he_total <- renderValueBox({
    valueBox(format(nrow(ccdata), big.mark = ","),
             tagList(
               "Open Higher Ed Postings",
               tags$small(
                 style = "display: block; font-size: 11px; opacity: 0.85;",
                 sprintf(
                   "%s faculty/instructor (non-adjunct) | %s adjunct/part-time faculty",
                   format(he_faculty_counts$faculty_instructor, big.mark = ","),
                   format(he_faculty_counts$adjunct_part_time, big.mark = ",")
                 )
               ),
               wow_delta_ui(compute_wow_delta(he_institution_weekly_totals))
             ),
             icon = tags$i(HTML(make_sparkline_svg_light(statewide_weekly_series(he_institution_weekly_totals)))),
             color = "purple")
  })
  output$kpi_last_refreshed <- renderValueBox({
    valueBox(last_refreshed_date, "Last Refreshed", icon = icon("calendar"), color = "green")
  })

  output$k12_biggest_mover <- renderUI({
    render_mover_box(find_biggest_mover(k12_district_weekly_totals, "District"), "Biggest K-12 mover")
  })
  output$he_biggest_mover <- renderUI({
    render_mover_box(find_biggest_mover(he_institution_weekly_totals, "Institution"), "Biggest Higher Ed mover")
  })

  output$top_k12_districts <- renderTable({
    top <- combineddata %>% count(District, sort = TRUE, name = "Open Postings") %>% head(5)
    top$`Last 12 Weeks` <- vapply(top$District, function(d) {
      series <- k12_district_weekly_totals %>%
        filter(District == d) %>%
        arrange(Archive_Date) %>%
        tail(12) %>%
        pull(n)
      make_sparkline_svg(series, accent = "#2a78d6")
    }, character(1))
    top
  }, sanitize.text.function = function(x) x)

  output$top_he_institutions <- renderTable({
    top <- ccdata %>% count(Institution, sort = TRUE, name = "Open Postings") %>% head(5)
    top$`Last 12 Weeks` <- vapply(top$Institution, function(inst) {
      series <- he_institution_weekly_totals %>%
        filter(Institution == inst) %>%
        arrange(Archive_Date) %>%
        tail(12) %>%
        pull(n)
      make_sparkline_svg(series, accent = "#4a3aa7")
    }, character(1))
    top
  }, sanitize.text.function = function(x) x)

  # Vacancy-rate leaderboards -- a different question from the raw-count
  # tables above ("who's short-staffed relative to their size" rather than
  # "who's hiring the most"), so they sit alongside rather than replacing
  # them. Same horizontal-bar, ranked-descending pattern as the Current
  # Trends charts. combined_map_data's Vacancy_Rate is already NA below
  # VACANCY_RATE_MIN_FTE, so no separate floor check is needed here.
  #
  # validate(need()), not a bare req() -- req() would leave the box showing
  # only its spinner forever if nothing qualifies (e.g. every staffing
  # source failed this week), with no indication that's a real state and
  # not just slow loading. Matches the friendly-message pattern the
  # longitudinal charts already use below.
  output$k12_vacancy_leaderboard <- renderPlotly({
    df <- combined_map_data %>%
      filter(Type == "K-12 District", !is.na(Vacancy_Rate)) %>%
      arrange(desc(Vacancy_Rate)) %>%
      head(8)
    validate(need(nrow(df) > 0, "No districts currently meet the minimum-FTE threshold for a vacancy rate."))

    plot <- ggplot(df, aes(x = reorder(Name, Vacancy_Rate), y = Vacancy_Rate,
                            text = paste0(Name, ": ", Vacancy_Numerator, " / ", Vacancy_Denominator,
                                          " = ", scales::percent(Vacancy_Rate, accuracy = 0.1)))) +
      geom_bar(stat = "identity", fill = "#2a78d6") +
      geom_text(aes(label = scales::percent(Vacancy_Rate, accuracy = 0.1)), hjust = -0.15, size = 3) +
      labs(x = NULL, y = "Teacher vacancy rate") +
      scale_y_continuous(labels = scales::percent, expand = expansion(mult = c(0, 0.2))) +
      coord_flip() +
      theme_minimal()

    ggplotly(plot, tooltip = "text")
  })

  output$he_vacancy_leaderboard <- renderPlotly({
    df <- combined_map_data %>%
      filter(Type == "Higher Ed Institution", !is.na(Vacancy_Rate)) %>%
      arrange(desc(Vacancy_Rate)) %>%
      head(8) %>%
      # Sheridan/Gillette carry a marked *-suffixed label rather than their
      # plain name, since this is the one place their joint rate sits next
      # to genuinely campus-specific rates with nothing else distinguishing
      # them -- see Vacancy_Rate_Shared's definition in map_he above.
      mutate(Name = ifelse(Vacancy_Rate_Shared, paste0(Name, " *"), Name))
    validate(need(nrow(df) > 0, "No institutions currently meet the minimum-FTE threshold for a vacancy rate."))

    plot <- ggplot(df, aes(x = reorder(Name, Vacancy_Rate), y = Vacancy_Rate,
                            text = paste0(Name, ": ", Vacancy_Numerator, " / ", Vacancy_Denominator,
                                          " = ", scales::percent(Vacancy_Rate, accuracy = 0.1)))) +
      geom_bar(stat = "identity", fill = "#4a3aa7") +
      geom_text(aes(label = scales::percent(Vacancy_Rate, accuracy = 0.1)), hjust = -0.15, size = 3) +
      labs(x = NULL, y = "Faculty vacancy rate") +
      scale_y_continuous(labels = scales::percent, expand = expansion(mult = c(0, 0.2))) +
      coord_flip() +
      theme_minimal()

    ggplotly(plot, tooltip = "text")
  })

  # -------- New This Week --------
  output$k12_new_table <- renderDT({
    datatable(
      k12_new_this_week %>% select(title, District, location, Broad_Category, url),
      options = list(scrollX = TRUE)
    )
  })
  output$he_new_table <- renderDT({
    df <- he_new_this_week
    if (!identical(input$he_new_appointment, "all")) {
      df <- df %>% filter(Appointment == input$he_new_appointment)
    }
    datatable(
      df %>% select(Title, Institution, Location, Appointment, Category, Link),
      options = list(scrollX = TRUE)
    )
  })

  # -------- K-12 --------
  output$k12_jobs <- renderDT({
    df <- combineddata
    if (!is.null(selected_district())) df <- df %>% filter(District == selected_district())
    datatable(df, filter = "top", escape = FALSE, extensions = "Buttons",
              options = list(scrollX = TRUE, dom = "Bfrtip", buttons = c("copy", "csv", "print")))
  })

  output$k12_filter_status <- renderUI({
    if (is.null(selected_district())) return(NULL)
    div(style = "margin-bottom: 10px;",
        strong(paste("Showing:", selected_district())),
        actionButton("clear_k12_filter", "Show All Districts", class = "btn-xs", style = "margin-left: 10px;")
    )
  })
  observeEvent(input$clear_k12_filter, { selected_district(NULL) })

  # District Summary -- everything the map popups show (vacancy rate,
  # salary figures, source/date), but as a real exportable table instead
  # of something only visible one marker at a time.
  output$k12_summary_table <- renderDT({
    k12_rows <- combined_map_data %>% filter(Type == "K-12 District")
    year <- unique(na.omit(k12_rows$Salary_Year))
    current_label <- if (length(year) > 0) year[1] else "current year"
    prior_label <- if (length(year) > 0) prior_school_year_label(year[1]) else "prior year"

    df <- k12_rows %>%
      arrange(desc(CurrentCount)) %>%
      transmute(
        District = Name,
        County,
        `Current Openings` = CurrentCount,
        # Real, sortable/filterable column -- not just a map badge or a
        # buried code comment -- so "why does this district look quiet"
        # is answerable directly from the exportable table, not just the
        # map. "Full" is the overwhelming majority (every district on a
        # real job-board platform); see the Map tab's helpText for what
        # the partial tiers mean.
        `Posting Data` = Data_Coverage,
        `New This Week` = WeeklyNew,
        `Teacher Vacancy Rate` = ifelse(is.na(Vacancy_Rate), NA_character_, scales::percent(Vacancy_Rate, accuracy = 0.1)),
        Enrollment,
        `Students per Teacher` = ifelse(is.na(Students_Per_Teacher), NA_character_, sprintf("%.1f", Students_Per_Teacher)),
        TeacherBaseSalary = ifelse(is.na(Teacher_Base_Salary), NA_character_, scales::dollar(Teacher_Base_Salary)),
        TeacherBaseSalaryPrior = ifelse(is.na(Teacher_Base_Salary_Prior_Year), NA_character_, scales::dollar(Teacher_Base_Salary_Prior_Year)),
        `Superintendent Salary` = ifelse(is.na(Superintendent_Salary), NA_character_, scales::dollar(Superintendent_Salary)),
        # County-level context (Census ACS 5-Year) -- constant across
        # sibling districts in the same county, same as any other county-
        # level figure, and deliberately alongside the salary columns
        # rather than off in a separate tab: "$46k pay in a county where
        # median rent is $650/mo" is the actual comparison a prospective
        # teacher is making, not two numbers looked up separately.
        `County Median Income` = ifelse(is.na(Median_Household_Income), NA_character_, scales::dollar(Median_Household_Income)),
        `County Median Rent` = ifelse(is.na(Median_Gross_Rent), NA_character_, paste0(scales::dollar(Median_Gross_Rent), "/mo")),
        # Share of the county's civilian workforce in mining/oil & gas --
        # Wyoming's energy-producing counties pay teachers measurably more
        # specifically to compete with these wages for the same local
        # labor pool, so this is the one column here that helps explain
        # WHY salaries vary across WY districts, not just what things cost.
        `County Mining/Energy Jobs` = ifelse(is.na(Mining_Employment_Share), NA_character_, scales::percent(Mining_Employment_Share, accuracy = 0.1)),
        `County Population Trend (5yr)` = ifelse(is.na(Population_Change_Pct), NA_character_,
                                                   paste0(ifelse(Population_Change_Pct >= 0, "+", ""), scales::percent(Population_Change_Pct, accuracy = 0.1))),
        # District-level, not county-level, unlike the four columns above --
        # the closest free proxy to free/reduced-lunch eligibility at the
        # actual district a posting is in (Census SAIPE doesn't publish
        # free/reduced-lunch counts directly). A prospective teacher sizing
        # up a district's student population, not just its town.
        `District Child Poverty Rate` = ifelse(is.na(Child_Poverty_Rate), NA_character_, scales::percent(Child_Poverty_Rate, accuracy = 0.1))
      )
    # Real year in the header instead of a generic "Prior Year" label --
    # cleaner than a separate Salary Year column repeating the same value
    # in every row.
    names(df)[names(df) == "TeacherBaseSalary"] <- paste0("Teacher Base Salary (", current_label, ")")
    names(df)[names(df) == "TeacherBaseSalaryPrior"] <- paste0("Teacher Base Salary (", prior_label, ")")

    datatable(df, filter = "top", extensions = "Buttons",
              options = list(scrollX = TRUE, dom = "Bfrtip", buttons = c("copy", "csv", "print"), pageLength = 48))
  })

  # Salary_Year and Salary_Source are the same for every district (one
  # WSBA document covers all 48 for one school year) -- a column repeating
  # an identical value 48 times isn't information, so it's a single
  # footnote with a live link instead.
  output$k12_summary_footnote <- renderUI({
    year <- unique(na.omit(combined_map_data$Salary_Year[combined_map_data$Type == "K-12 District"]))
    source <- unique(na.omit(combined_map_data$Salary_Source[combined_map_data$Type == "K-12 District"]))
    acs_year <- unique(na.omit(combined_map_data$ACS_Year[combined_map_data$Type == "K-12 District"]))
    saipe_year <- unique(na.omit(combined_map_data$SAIPE_Year[combined_map_data$Type == "K-12 District"]))
    req(length(year) > 0, length(source) > 0)
    tagList(
      helpText(
        "Salary data:", source[1], paste0("(", year[1], " school year)"), "—",
        tags$a(href = WSBA_SALARY_SOURCE_URL, target = "_blank", "wsba-wy.org")
      ),
      if (length(acs_year) > 0) {
        helpText(
          "County context (income, rent, mining/energy employment share, population trend): US Census Bureau, American Community Survey 5-Year Estimates",
          paste0("(", acs_year[1], ")"), "—",
          tags$a(href = "https://www.census.gov/data/developers/data-sets/acs-5year.html", target = "_blank", "census.gov"),
          ". County-level, not district-level -- sibling districts in the same county share the same figures."
        )
      },
      if (length(saipe_year) > 0) {
        helpText(
          "District child poverty rate: US Census Bureau, Small Area Income and Poverty Estimates (SAIPE)",
          paste0("(", saipe_year[1], ")"), "—",
          tags$a(href = "https://www.census.gov/programs-surveys/saipe/data/datasets.html", target = "_blank", "census.gov/saipe"),
          ". District-level (unlike the county context above)."
        )
      }
    )
  })

  # -------- Combined map (Introduction tab) --------
  output$combined_map <- renderLeaflet({
    leaflet() %>%
      addTiles() %>%
      setView(lng = -107.5, lat = 43, zoom = 7) %>%
      addLegend(position = "bottomright", pal = vacancy_rate_palette, values = vacancy_rate_domain,
                title = "Vacancy rate", labFormat = labelFormat(suffix = "%", transform = function(x) 100 * x),
                na.label = "N/A")
  })
  # The map now lives on its own "Map" tab, not the default active one --
  # without this, the marker-update observe() below fires (and calls
  # leafletProxy()) before the browser has ever rendered/registered the
  # widget, since shinydashboard doesn't render hidden tabs' outputs by
  # default. Confirmed live 2026-08-05: markers silently never appeared,
  # "Couldn't find map with id combined_map" in the browser console.
  outputOptions(output, "combined_map", suspendWhenHidden = FALSE)

  map_filtered <- reactive({
    df <- combined_map_data %>% filter(Type %in% input$map_types, CurrentCount > 0)
    df
  })

  observe({
    df <- map_filtered()

    # A marker click always just opens its popup (leaflet's default) --
    # navigating away from the map has to be a second, deliberate action,
    # so the "View all jobs" link below fires a Shiny input from inside
    # the popup itself rather than reacting to the marker click event,
    # which used to fire at the same instant as the popup opened and
    # immediately navigated away before it could be read.
    popups <- with(df, paste0(
      "<div><strong>", Name, "</strong><br/>", Type, "</div>",
      # Visible badge, not just a footnote or a code comment -- Data_Coverage
      # is "Full" for every district on a real structured job-board platform;
      # the ~25-40% (own page) / ~25-40% only (WSBA-only) partial tiers come
      # from misc_district_coverage_tiers() in misc_district_scrapers.R.
      ifelse(Data_Coverage != "Full",
             paste0("<div style='margin:2px 0;'><span style='background:#fdecea;color:#a92f1e;",
                    "font-size:0.78em;font-weight:bold;padding:1px 6px;border-radius:8px;'>",
                    Data_Coverage, "</span></div>"),
             ""),
      "<div>Current openings: <strong>", CurrentCount, "</strong></div>",
      "<div>New this week: ", WeeklyNew, "</div>",
      ifelse(!is.na(Vacancy_Rate),
             paste0("<div>", ifelse(Type == "K-12 District", "Teacher", "Faculty"),
                    " vacancy rate: ", scales::percent(Vacancy_Rate, accuracy = 0.1),
                    ifelse(Vacancy_Rate_Shared,
                           " <span style='color:#666;'>(combined Sheridan + Gillette figure -- see note below)</span>",
                           ""),
                    "</div>"),
             ""),
      ifelse(nzchar(SampleTitles), paste0("<div>Recent postings: ", SampleTitles, "</div>"), ""),
      ifelse(!is.na(Students_Per_Teacher),
             paste0("<div>Students per ", ifelse(Type == "K-12 District", "teacher", "faculty member"), ": ",
                    sprintf("%.1f", Students_Per_Teacher),
                    " (", format(Enrollment, big.mark = ","), " students)</div>"),
             ""),
      # Institution-level, HE only -- K-12's equivalent trend is county-
      # level (Population_Change_Pct, shown further down alongside income/
      # rent/mining share) since no district-level enrollment trend is
      # pulled here.
      ifelse(!is.na(Enrollment_Change_Pct),
             paste0("<div>Enrollment trend (5yr): ", ifelse(Enrollment_Change_Pct >= 0, "+", ""),
                    scales::percent(Enrollment_Change_Pct, accuracy = 0.1), "</div>"),
             ""),
      # HE only -- see Pell_Recipient_Share's map_he comment for why
      # there's no K-12 equivalent.
      ifelse(!is.na(Pell_Recipient_Share),
             paste0("<div>Pell Grant recipients: ", scales::percent(Pell_Recipient_Share, accuracy = 0.1),
                    " of students (", Pell_Year, ")</div>"),
             ""),
      ifelse(!is.na(Teacher_Base_Salary),
             paste0("<div>Teacher base salary: ", scales::dollar(Teacher_Base_Salary),
                    ifelse(!is.na(Teacher_Base_Salary_Prior_Year),
                           paste0(" (", scales::dollar(Teacher_Base_Salary_Prior_Year), " prior year)"),
                           ""),
                    " &middot; ", Salary_Year, "</div>"),
             ""),
      ifelse(!is.na(Superintendent_Salary),
             paste0("<div>Superintendent salary: ", scales::dollar(Superintendent_Salary), "</div>"),
             ""),
      ifelse(!is.na(Faculty_Avg_Salary),
             paste0("<div>Avg. faculty salary: ", scales::dollar(Faculty_Avg_Salary),
                    ifelse(!is.na(Faculty_Avg_Salary_Professor),
                           paste0(" (Professor rank: ", scales::dollar(Faculty_Avg_Salary_Professor), ")"),
                           ""),
                    " &middot; ", Salary_Year, "</div>"),
             ""),
      ifelse(!is.na(Salary_Note),
             paste0("<div style='font-size:0.85em;color:#666;'>", Salary_Note, "</div>"),
             ""),
      ifelse(!is.na(Salary_Source),
             paste0("<div style='font-size:0.85em;color:#666;'>Salary source: ", Salary_Source, "</div>"),
             ""),
      ifelse(!is.na(Median_Household_Income),
             paste0("<div style='font-size:0.85em;color:#666;margin-top:4px;'>County: median income ",
                    scales::dollar(Median_Household_Income), ", median rent ", scales::dollar(Median_Gross_Rent), "/mo",
                    ifelse(!is.na(Mining_Employment_Share) & Mining_Employment_Share >= 0.05,
                           paste0(", ", scales::percent(Mining_Employment_Share, accuracy = 1), " of jobs in mining/energy"),
                           ""),
                    "</div>"),
             ""),
      ifelse(!is.na(Child_Poverty_Rate),
             paste0("<div style='font-size:0.85em;color:#666;'>District: ",
                    scales::percent(Child_Poverty_Rate, accuracy = 0.1), " child poverty rate</div>"),
             ""),
      "<div style='margin-top:6px;'>",
      "<a href='", Link, "' target='_blank'>Careers page</a>",
      " &nbsp;|&nbsp; ",
      "<a href='#' onclick=\"Shiny.setInputValue('popup_view_jobs', '",
      gsub("'", "&#39;", Name, fixed = TRUE),
      "', {priority: 'event'}); return false;\">View all jobs &rarr;</a>",
      "</div>"
    ))

    leafletProxy("combined_map", data = df) %>%
      clearMarkers() %>%
      addCircleMarkers(
        lng = ~Longitude, lat = ~Latitude,
        radius = ~map_marker_radius(CurrentCount),
        fillColor = ~vacancy_rate_palette(Vacancy_Rate),
        color = "#333333", weight = 1,
        fillOpacity = 0.85,
        layerId = ~Name,
        popup = popups
      )
  })

  observeEvent(input$popup_view_jobs, {
    entity <- input$popup_view_jobs
    row <- combined_map_data %>% filter(Name == entity)
    req(nrow(row) > 0)

    if (row$Type[1] == "K-12 District") {
      selected_district(entity)
      updateTabItems(session, "sidebar_tabs", "k12_table")
    } else {
      selected_institution(entity)
      updateTabItems(session, "sidebar_tabs", "he_table")
    }
  })


  # ---- DATA SCOPE: District + Broad Category ----------------------------
  
  #------------Filter for longitudinal plot--------
  
  # Toggling detail level swaps both the underlying dataset and the
  # picker's own choices (Simple and Detailed are different category
  # name sets, not just different labels on the same data).
  observeEvent(input$k12_detail_level_trends, {
    cats <- if (identical(input$k12_detail_level_trends, "detail")) {
      sort(unique(k12sum$Broad_Category))
    } else {
      sort(unique(k12sum_agg$Broad_Category))
    }
    updatePickerInput(session, "broad_category", choices = cats, selected = cats)
  }, ignoreInit = TRUE)

  filtered_k12sum <- reactive({
    req(input$district_trend, input$broad_category, input$k12_detail_level_trends)

    base <- if (identical(input$k12_detail_level_trends, "detail")) k12sum else k12sum_agg

    base %>%
      dplyr::filter(
        # District filter
        input$district_trend == "Total" |
          District == input$district_trend,
        
        # Broad category filter (MULTI-SELECT SAFE)
        Broad_Category %in% input$broad_category
      )
  })
  
 
  # K-12 longitudinal plot
  df_windowed <- reactive({
    df <- filtered_k12sum()
    req(nrow(df) > 0, input$k12_scroll)
    
    df <- df %>%
      filter(
        Archive_Date >= input$k12_scroll[1],
        Archive_Date <= input$k12_scroll[2]
      )
    
    # Aggregate to ensure one row per Broad_Category x Archive_Date
    df <- df %>%
      filter(District != "Total") %>%  # remove total row to prevent double-counting
      group_by(Broad_Category, Archive_Date) %>%
      summarise(sum = sum(sum), .groups = "drop") %>%
      arrange(Broad_Category, Archive_Date)
    
    df
  })
  

  # ---- OUTPUT: LONGITUDINAL PLOT ----------------------------------------
  
  
  output$k12_longitudinal_plot <- renderPlotly({
    df <- df_windowed()
    
    validate(
      need(nrow(df) > 0, "No data for selected districts.")
    )
    
    # Get the exact dates in the filtered data
    all_dates <- sort(unique(df$Archive_Date))

    p <- ggplot(df, aes(
      x = Archive_Date,
      y = sum,
      color = Broad_Category,
      group = Broad_Category,
      text = paste0(
        "Date: ", Archive_Date, "<br>",
        "Category: ", Broad_Category, "<br>",
        "Postings: ", sum
      )
    )) +
      geom_line() +
      geom_point(size = 1) +
      scale_color_manual(values = if (identical(input$k12_detail_level_trends, "detail")) K12_CATEGORY_COLORS_DETAIL else K12_CATEGORY_COLORS_AGG) +
      labs(x = "Archive Date", y = "Number of Postings") +
      scale_x_date(
        breaks = all_dates,      # show every date exactly
        labels = scales::date_format("%b %d")
      ) +
      theme_minimal() +
      theme(
        axis.text.x = element_text(angle = 45, hjust = 1, size = 8),
        legend.position = "bottom",
        legend.key.size = unit(0.5, "cm"),
        legend.box.spacing = unit(0.2, "cm"),
        legend.text = element_text(size = 8),
        legend.title = element_text(size = 10)
      )

    ggplotly(p, height = 500, tooltip = "text")
  })
  

  
  output$k12_current_trends_table <- renderTable({
    req(input$k12_detail_level_current)
    hist_src <- if (identical(input$k12_detail_level_current, "detail")) k12sum else k12sum_agg
    history <- hist_src %>%
      filter(District == input$district_current) %>%
      transmute(Category = Broad_Category, Archive_Date, n = sum)

    result <- build_current_trends_table(history, accent = "#2a78d6")
    req(!is.null(result))
    result
  }, sanitize.text.function = function(x) x)

  # -------- Higher Ed --------
  output$he_jobs <- renderDT({
    df <- ccdata
    if (!is.null(selected_institution())) df <- df %>% filter(Institution == selected_institution())
    if (!identical(input$he_table_appointment, "all")) {
      df <- df %>% filter(Appointment == input$he_table_appointment)
    }
    datatable(df, filter = "top", escape = FALSE, extensions = "Buttons",
              options = list(scrollX = TRUE, dom = "Bfrtip", buttons = c("copy", "csv", "print")))
  })

  output$he_filter_status <- renderUI({
    if (is.null(selected_institution())) return(NULL)
    div(style = "margin-bottom: 10px;",
        strong(paste("Showing:", selected_institution())),
        actionButton("clear_he_filter", "Show All Institutions", class = "btn-xs", style = "margin-left: 10px;")
    )
  })
  observeEvent(input$clear_he_filter, { selected_institution(NULL) })

  # Institution Summary -- same purpose as k12_summary_table above: the
  # map popups' data as a real exportable table, not one marker at a time.
  output$he_summary_table <- renderDT({
    he_rows <- combined_map_data %>% filter(Type == "Higher Ed Institution")
    appointment_counts <- ccdata %>%
      count(Institution, Appointment, name = "Openings") %>%
      tidyr::complete(
        Institution,
        Appointment = c("Faculty/instructor (non-adjunct)", "Adjunct/part-time faculty"),
        fill = list(Openings = 0L)
      ) %>%
      tidyr::pivot_wider(names_from = Appointment, values_from = Openings, values_fill = 0)
    year <- unique(na.omit(he_rows$Salary_Year))
    year_label <- if (length(year) > 0) year[1] else "current"
    year_int <- suppressWarnings(as.integer(year_label))
    y1_label <- if (!is.na(year_int)) as.character(year_int - 1) else "1 year ago"
    y2_label <- if (!is.na(year_int)) as.character(year_int - 2) else "2 years ago"

    df <- he_rows %>%
      left_join(appointment_counts, by = c("Name" = "Institution")) %>%
      arrange(desc(CurrentCount)) %>%
      transmute(
        Institution = Name,
        County,
        `Current Openings` = CurrentCount,
        `Faculty/instructor (non-adjunct)` = coalesce(`Faculty/instructor (non-adjunct)`, 0L),
        `Adjunct/part-time faculty` = coalesce(`Adjunct/part-time faculty`, 0L),
        `New This Week` = WeeklyNew,
        `Faculty Vacancy Rate` = ifelse(is.na(Vacancy_Rate), NA_character_, scales::percent(Vacancy_Rate, accuracy = 0.1)),
        AvgFacultySalary = ifelse(is.na(Faculty_Avg_Salary), NA_character_, scales::dollar(Faculty_Avg_Salary)),
        AvgFacultySalaryY1 = ifelse(is.na(Faculty_Avg_Salary_Y1Ago), NA_character_, scales::dollar(Faculty_Avg_Salary_Y1Ago)),
        AvgFacultySalaryY2 = ifelse(is.na(Faculty_Avg_Salary_Y2Ago), NA_character_, scales::dollar(Faculty_Avg_Salary_Y2Ago)),
        ProfessorAvgSalary = ifelse(is.na(Faculty_Avg_Salary_Professor), NA_character_, scales::dollar(Faculty_Avg_Salary_Professor)),
        `Faculty Count` = Faculty_Count,
        # IPEDS fall enrollment (FTE) -- HE's analogue of the K-12 District
        # Summary table's Enrollment/Students per Teacher columns, added
        # 2026-08-06 via ipeds_enrollment_scraper.R.
        Enrollment,
        `Students per Faculty` = ifelse(is.na(Students_Per_Teacher), NA_character_, sprintf("%.1f", Students_Per_Teacher)),
        # 5-year enrollment trend, institution-level (IPEDS) -- the HE
        # analogue of the K-12 District Summary table's county-level
        # "County Population Trend (5yr)" column, but arguably a more
        # direct signal here since it's the actual institution, not just
        # its county.
        `Enrollment Trend (5yr)` = ifelse(is.na(Enrollment_Change_Pct), NA_character_,
                                           paste0(ifelse(Enrollment_Change_Pct >= 0, "+", ""), scales::percent(Enrollment_Change_Pct, accuracy = 0.1))),
        # Share of students receiving a Pell Grant (FSA) -- the HE
        # analogue of the K-12 District Summary table's "District Child
        # Poverty Rate" column, a different federal program since SAIPE
        # has no HE equivalent. Pell_Year usually trails Salary_Year/
        # Enrollment's year (FSA's own data lags IPEDS's), so it's called
        # out by name here rather than assumed to match.
        `Pell Grant Recipient Share` = ifelse(is.na(Pell_Recipient_Share), NA_character_,
                                               paste0(scales::percent(Pell_Recipient_Share, accuracy = 0.1), " (", Pell_Year, ")")),
        # County-level context (Census ACS 5-Year) -- same reasoning and
        # same source as the K-12 District Summary table's equivalent
        # columns, added 2026-08-06 once salarymap.csv gained a County
        # column to join through. No child-poverty-rate column here (see
        # map_he's Child_Poverty_Rate comment for why SAIPE has no HE
        # equivalent).
        `County Median Income` = ifelse(is.na(Median_Household_Income), NA_character_, scales::dollar(Median_Household_Income)),
        `County Median Rent` = ifelse(is.na(Median_Gross_Rent), NA_character_, paste0(scales::dollar(Median_Gross_Rent), "/mo")),
        `County Mining/Energy Jobs` = ifelse(is.na(Mining_Employment_Share), NA_character_, scales::percent(Mining_Employment_Share, accuracy = 0.1)),
        `County Population Trend (5yr)` = ifelse(is.na(Population_Change_Pct), NA_character_,
                                                   paste0(ifelse(Population_Change_Pct >= 0, "+", ""), scales::percent(Population_Change_Pct, accuracy = 0.1))),
        # Short plain-text label, not the full Salary_Note sentence --
        # that blew out Sheridan/Gillette's row height next to every other
        # institution's single-line rows (confirmed visually 2026-08-05).
        # Kept plain text rather than an HTML tooltip so the CSV/copy
        # export buttons still produce clean text, not raw markup. Now
        # mentions the vacancy rate too, since that's a combined figure
        # here as well (see Vacancy_Rate_Shared), not just salary.
        Note = ifelse(is.na(Salary_Note), "", "Shared salary & vacancy-rate reporting w/ Sheridan & Gillette")
      )
    names(df)[names(df) == "AvgFacultySalary"] <- paste0("Avg Faculty Salary (", year_label, ")")
    names(df)[names(df) == "AvgFacultySalaryY1"] <- paste0("Avg Faculty Salary (", y1_label, ")")
    names(df)[names(df) == "AvgFacultySalaryY2"] <- paste0("Avg Faculty Salary (", y2_label, ")")
    names(df)[names(df) == "ProfessorAvgSalary"] <- paste0("Professor Avg Salary (", year_label, ")")

    datatable(df, filter = "top", extensions = "Buttons",
              options = list(scrollX = TRUE, dom = "Bfrtip", buttons = c("copy", "csv", "print"), pageLength = 9))
  })

  # Salary_Year and Salary_Source are the same for every institution (one
  # IPEDS survey year covers all 9) -- same reasoning as
  # k12_summary_footnote above.
  output$he_summary_footnote <- renderUI({
    year <- unique(na.omit(combined_map_data$Salary_Year[combined_map_data$Type == "Higher Ed Institution"]))
    source <- unique(na.omit(combined_map_data$Salary_Source[combined_map_data$Type == "Higher Ed Institution"]))
    acs_year <- unique(na.omit(combined_map_data$ACS_Year[combined_map_data$Type == "Higher Ed Institution"]))
    pell_year <- unique(na.omit(combined_map_data$Pell_Year[combined_map_data$Type == "Higher Ed Institution"]))
    req(length(year) > 0, length(source) > 0)
    tagList(
      helpText(
        "Salary data:", source[1], paste0("(", year[1], " data)"), "—",
        tags$a(href = IPEDS_SALARY_SOURCE_URL, target = "_blank", "educationdata.urban.org")
      ),
      if (length(acs_year) > 0) {
        helpText(
          "County context (income, rent, mining/energy employment share, population trend): US Census Bureau, American Community Survey 5-Year Estimates",
          paste0("(", acs_year[1], ")"), "—",
          tags$a(href = "https://www.census.gov/data/developers/data-sets/acs-5year.html", target = "_blank", "census.gov")
        )
      },
      if (length(pell_year) > 0) {
        helpText(
          "Pell Grant recipient share: US Dept. of Education, Federal Student Aid, via Urban Institute Education Data Portal",
          paste0("(", pell_year[1], " data — usually a year or more older than the salary/enrollment figures above, since FSA's own data lags IPEDS's)"), "—",
          tags$a(href = "https://educationdata.urban.org/documentation/colleges.html", target = "_blank", "educationdata.urban.org"),
          ". Recipients ÷ that same year's IPEDS FTE enrollment — a headcount-over-FTE ratio, not two directly comparable counts."
        )
      }
    )
  })

  observeEvent(input$he_detail_level_trends, {
    cats <- if (identical(input$he_detail_level_trends, "detail")) {
      sort(unique(hesum_he$Category))
    } else {
      sort(unique(hesum_he_agg$Category))
    }
    updatePickerInput(session, "he_category", choices = cats, selected = cats)
  }, ignoreInit = TRUE)

  # ---- Reactive filtered dataset by institution + Category ----
  filtered_hesum <- reactive({
    req(input$inst_trend, input$he_category, input$he_chart_type, input$he_detail_level_trends)

    base <- if (identical(input$he_detail_level_trends, "detail")) hesum_he else hesum_he_agg

    # Filter by institution
    df <- if (input$inst_trend == "Total") {
      base
    } else {
      base %>% filter(Institution == input$inst_trend)
    }

    # Filter by Category (vector match)
    df <- df %>% filter(Category %in% input$he_category)

    # Filter by Job_Type -- "all" sums Full Time + Part Time together
    # (the group_by/summarize below combines whatever rows are present),
    # otherwise scope down to just the selected Job_Type.
    if (!identical(input$he_chart_type, "all")) {
      df <- df %>% filter(Job_Type == input$he_chart_type)
    }

    df
  })
  
  # ---- Update slider based on filtered data ----
  observe({
    df <- filtered_hesum()
    req(nrow(df) > 0)
    
    df$Archive_Date <- as.Date(df$Archive_Date)
    he_dates <- sort(unique(df$Archive_Date))
    
    # Set slider min/max as actual dates
    updateSliderInput(
      session,
      "he_scroll",
      min = min(he_dates),
      max = max(he_dates),
      value = c(max(he_dates) - WINDOW_WEEKS*7, max(he_dates)),
      timeFormat = "%Y-%m-%d"
    )
    
    # Store for reactive filtering
    session$userData$he_dates <- he_dates
  })
  
  # ---- Reactive dataset filtered by date window ----
  he_windowed <- reactive({
    df <- filtered_hesum()
    req(input$he_scroll)

    df %>%
      filter(
        Archive_Date >= as.Date(input$he_scroll[1]),
        Archive_Date <= as.Date(input$he_scroll[2]),
        Institution != "Total"  # remove pre-aggregated total row to prevent double-counting
      ) %>%
      arrange(Archive_Date)
  })
  
  # ---- Optional: show slider range ----
  output$he_slider_label <- renderText({
    req(input$he_scroll)
    paste0("Showing: ", input$he_scroll[1], " to ", input$he_scroll[2])
  })
  
  # ---- Render plot ----
  output$he_longitudinal_plot <- renderPlotly({
    df <- he_windowed()
    validate(need(nrow(df) > 0, "No data for selected institution/category/date range."))
    
    # Ensure one row per Category × Archive_Date and sort properly
    df <- df %>%
      group_by(Category, Archive_Date) %>%
      summarize(sum = sum(sum), .groups = "drop") %>%
      arrange(Category, Archive_Date) %>%
      mutate(Category = factor(Category))
    
    # Plot
    p <- ggplot(df, aes(
      x = Archive_Date,
      y = sum,
      color = Category,
      group = Category,
      text = paste0(
        "Date: ", Archive_Date, "<br>",
        "Category: ", Category, "<br>",
        "Postings: ", sum
      )
    )) +
      geom_line() +
      geom_point(size = 1) +
      scale_color_manual(values = if (identical(input$he_detail_level_trends, "detail")) HE_CATEGORY_COLORS_DETAIL else HE_CATEGORY_COLORS_AGG) +
      labs(x = "Archive Date", y = "Number of Postings") +
      theme_minimal() +
      theme(
        axis.text.x = element_text(angle = 45, hjust = 1, size = 8),
        legend.position = "bottom",
        legend.key.size = unit(0.5, "cm"),
        legend.box.spacing = unit(0.2, "cm"),
        legend.text = element_text(size = 8),
        legend.title = element_text(size = 10)
      )

    ggplotly(p, height = 500, tooltip = "text")
  })




  # Sums across Job_Type (FT + PT) per category -- this table shows "how
  # has this category moved," not a FT/PT breakdown (which lived in the
  # now-removed stacked bar chart; the Appointment control below applies
  # the selected Job_Type before the category comparisons are calculated).
  output$he_current_trends_table <- renderTable({
    req(input$he_detail_level_current, input$he_current_appointment)
    hist_src <- if (identical(input$he_detail_level_current, "detail")) hesum_he else hesum_he_agg
    history <- hist_src %>%
      filter(
        Institution == input$inst_current,
        identical(input$he_current_appointment, "all") | Job_Type == input$he_current_appointment
      ) %>%
      transmute(Category, Archive_Date, n = sum)

    result <- build_current_trends_table(history, accent = "#4a3aa7")
    req(!is.null(result))
    result
  }, sanitize.text.function = function(x) x)
}

shinyApp(ui, server)
