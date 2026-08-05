# Wyoming Higher Ed faculty salary data from IPEDS (the federal Integrated
# Postsecondary Education Data System), via the Urban Institute's Education
# Data Portal -- a real public JSON REST API wrapping IPEDS's own Human
# Resources/Salaries (SAL) survey component, so no PDF/HTML scraping is
# needed here (unlike the WSBA K-12 salary data in salary_scrapers.R).
# https://educationdata.urban.org/documentation/
#
# Endpoint used: college-university/ipeds/salaries-instructional-staff/{year}
# filtered to fips=56 (Wyoming). Per NCES, HR/SAL data is reported "as of
# November 1" of the same calendar year as the survey year -- e.g. year 2024
# means salaries as of Nov 1, 2024, not the "2023-24" academic year.
#
# Each institution reports one row per (academic_rank x contract_length x
# sex) combination; academic_rank/contract_length/sex == 99 means "all
# ranks/lengths/sexes combined" -- that combined row is what's extracted as
# the headline "Faculty_Avg_Salary" figure, plus the academic_rank == 1
# ("Professor") row as a second reference point, mirroring how the WSBA
# scraper surfaces both a base teacher salary and a superintendent salary.
# Negative values (-1, -2, -3) are IPEDS/Urban sentinel codes for
# not-available/not-applicable/suppressed, not real data, and are treated
# as NA.
#
# Wyoming has 9 public HE institutions in this project's salarymap.csv, but
# only 8 distinct IPEDS unitids report salary data for them -- Sheridan
# College and Gillette College are both part of the same accredited entity,
# Northern Wyoming Community College District, so IPEDS has no way to tell
# their faculty salaries apart. Both get the same figures here, flagged via
# Salary_Note rather than silently presented as institution-specific.

suppressMessages({
  library(httr2)
  library(dplyr)
})

IPEDS_SALARY_ENDPOINT <- "https://educationdata.urban.org/api/v1/college-university/ipeds/salaries-instructional-staff"

IPEDS_UNITID_MAP <- tibble::tribble(
  ~unitid, ~Name,
  240505L, "Casper College",
  240514L, "Central Wyoming College",
  240596L, "Eastern Wyoming Community College",
  240620L, "Laramie County Community College",
  240657L, "Northwest College",
  240666L, "Sheridan College",
  240666L, "Gillette College",
  240693L, "Western Wyoming Community College",
  240727L, "University of Wyoming"
)

# Follows the API's `next` pagination link until exhausted, returning every
# result row as one data frame.
fetch_ipeds_paginated <- function(url) {
  rows <- list()
  while (!is.null(url)) {
    resp <- request(url) %>% req_perform() %>% resp_body_json()
    rows <- c(rows, resp$results)
    url <- resp[["next"]]
  }
  if (length(rows) == 0) return(data.frame())
  bind_rows(lapply(rows, function(r) as.data.frame(r, stringsAsFactors = FALSE)))
}

fetch_ipeds_wy_salaries_for_year <- function(year) {
  url <- paste0(IPEDS_SALARY_ENDPOINT, "/", year, "/?fips=56")
  fetch_ipeds_paginated(url)
}

# IPEDS publishes this survey with roughly a 1-2 year lag -- rather than
# hardcode a year that will eventually go stale, walk backward from the
# current year until a non-empty response is found.
find_latest_ipeds_salary_year <- function(start_year = as.integer(format(Sys.Date(), "%Y")),
                                           years_back = 5) {
  for (year in seq(start_year, start_year - years_back)) {
    df <- fetch_ipeds_wy_salaries_for_year(year)
    if (nrow(df) > 0) return(list(year = year, data = df))
  }
  list(year = NA_integer_, data = data.frame())
}

clean_ipeds_value <- function(x) ifelse(is.na(x) | x < 0, NA_real_, x)

# Pure transformation, kept separate from the network fetch above so it can
# be tested against a captured fixture instead of hitting the live API.
parse_ipeds_he_salaries <- function(df, year) {
  if (nrow(df) == 0) {
    return(data.frame(
      Name = character(0), Faculty_Avg_Salary = numeric(0),
      Faculty_Avg_Salary_Professor = numeric(0), Faculty_Count = numeric(0),
      Salary_Year = character(0), Salary_Note = character(0), stringsAsFactors = FALSE
    ))
  }

  overall <- df %>%
    filter(academic_rank == 99, contract_length == 99, sex == 99) %>%
    transmute(unitid,
              Faculty_Avg_Salary = clean_ipeds_value(average_salary),
              Faculty_Count = clean_ipeds_value(instruc_staff_count))

  professor <- df %>%
    filter(academic_rank == 1, contract_length == 99, sex == 99) %>%
    transmute(unitid, Faculty_Avg_Salary_Professor = clean_ipeds_value(average_salary))

  IPEDS_UNITID_MAP %>%
    left_join(overall, by = "unitid") %>%
    left_join(professor, by = "unitid") %>%
    mutate(
      Salary_Year = as.character(year),
      Salary_Note = ifelse(
        unitid == 240666,
        "Reported by Northern Wyoming Community College District, which includes both Sheridan College and Gillette College -- IPEDS does not break this figure out by campus.",
        NA_character_
      )
    ) %>%
    select(Name, Faculty_Avg_Salary, Faculty_Avg_Salary_Professor, Faculty_Count, Salary_Year, Salary_Note)
}

fetch_ipeds_he_salaries <- function() {
  latest <- find_latest_ipeds_salary_year()
  parse_ipeds_he_salaries(latest$data, latest$year)
}
