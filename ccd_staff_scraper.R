# Wyoming K-12 teacher FTE (staff headcount, not job postings) from NCES's
# Common Core of Data (CCD), via the same Urban Institute Education Data
# Portal API used for HE salaries in ipeds_salary_scraper.R -- the district
# directory endpoint already reports teachers_total_fte directly, so no
# separate staff survey/endpoint is needed.
# https://educationdata.urban.org/documentation/
#
# Endpoint: school-districts/ccd/directory/{year} filtered to fips=56
# (Wyoming). agency_type == 1 ("regular local school district") with at
# least one school is what isolates real school districts from the handful
# of other WY-registered LEAs CCD tracks (BOCES-style regional service
# agencies, children's homes, a state health department entry with 0
# schools) -- confirmed live that this filter yields exactly 48 rows, a 1:1
# name match (after canonicalization) against the same 48 districts WSBA's
# salary PDFs cover.
#
# CCD's own district names ("Albany County School District #1") use "#N"
# (inconsistently spaced -- "#1" in most rows, "# 1" in a few) and, unlike
# this project's canonical form, always include "County" -- except Big Horn
# and Natrona don't take "County" in this project's canonical naming (the
# same exception canonicalize_wsba_district_name() in salary_scrapers.R
# handles), so that's done explicitly here too rather than assumed away.
#
# This exists to support a "vacancy rate" figure (current teacher-category
# postings / teachers_total_fte) alongside raw posting counts -- see
# app.R's map popup logic.

suppressMessages({
  library(httr2)
  library(dplyr)
})

CCD_DISTRICT_DIRECTORY_ENDPOINT <- "https://educationdata.urban.org/api/v1/school-districts/ccd/directory"

fetch_ccd_paginated <- function(url) {
  # CCD directory records have real JSON nulls (e.g. a district with no
  # CBSA/CSA assignment) mixed in with populated fields, which breaks a
  # per-record as.data.frame() (unlike the IPEDS salary endpoint, which
  # never has this). simplifyVector = TRUE hands that off to jsonlite,
  # which turns nulls into NA correctly.
  pages <- list()
  while (!is.null(url)) {
    resp <- request(url) %>% req_perform() %>% resp_body_json(simplifyVector = TRUE)
    pages[[length(pages) + 1]] <- resp$results
    url <- resp[["next"]]
  }
  if (length(pages) == 0) return(data.frame())
  bind_rows(pages)
}

fetch_ccd_wy_directory_for_year <- function(year) {
  url <- paste0(CCD_DISTRICT_DIRECTORY_ENDPOINT, "/", year, "/?fips=56")
  fetch_ccd_paginated(url)
}

# CCD lags similarly to IPEDS -- walk backward from the current year until
# a non-empty response is found rather than hardcoding a year that will
# eventually go stale (see find_latest_ipeds_salary_year() for the same
# pattern).
find_latest_ccd_directory_year <- function(start_year = as.integer(format(Sys.Date(), "%Y")),
                                            years_back = 5) {
  for (year in seq(start_year, start_year - years_back)) {
    df <- fetch_ccd_wy_directory_for_year(year)
    if (nrow(df) > 0) return(list(year = year, data = df))
  }
  list(year = NA_integer_, data = data.frame())
}

canonicalize_ccd_district_name <- function(name) {
  name <- trimws(name)
  pattern <- "^(.+?)\\s*#\\s*(\\d+)$"
  matches <- regmatches(name, regexec(pattern, name))
  vapply(matches, function(m) {
    if (length(m) != 3) return(NA_character_)
    prefix <- m[2]
    num <- m[3]
    if (grepl("^Big Horn County", prefix)) {
      paste0("Big Horn School District ", num)
    } else if (grepl("^Natrona County", prefix)) {
      paste0("Natrona School District ", num)
    } else {
      paste0(prefix, " ", num)
    }
  }, character(1))
}

# Pure transformation, kept separate from the network fetch above so it can
# be tested against a captured fixture instead of hitting the live API.
parse_ccd_teacher_fte <- function(df) {
  if (nrow(df) == 0) {
    return(data.frame(District = character(0), Teachers_Total_FTE = numeric(0),
                       Enrollment = numeric(0), stringsAsFactors = FALSE))
  }

  df %>%
    filter(agency_type == 1, !is.na(number_of_schools), number_of_schools >= 1) %>%
    transmute(
      District = canonicalize_ccd_district_name(lea_name),
      Teachers_Total_FTE = ifelse(is.na(teachers_total_fte) | teachers_total_fte < 0, NA_real_, teachers_total_fte),
      Enrollment = ifelse(is.na(enrollment) | enrollment < 0, NA_real_, enrollment)
    ) %>%
    filter(!is.na(District))
}

fetch_ccd_teacher_fte <- function() {
  latest <- find_latest_ccd_directory_year()
  result <- parse_ccd_teacher_fte(latest$data)
  if (nrow(result) > 0) result$CCD_Year <- as.character(latest$year)
  result
}
