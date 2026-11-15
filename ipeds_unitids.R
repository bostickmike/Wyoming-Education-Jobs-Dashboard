# Wyoming's IPEDS unitid map: the dashboard's institution names and their
# IPEDS unit ids, passed to the edjobs federal HE fetchers
# (fetch_ipeds_he_salaries(), fetch_ipeds_he_enrollment(),
# fetch_ipeds_he_enrollment_trend(), fetch_ipeds_he_pell_share(); package
# phase 5, 2026-11-15; the fetch/parse code that lived in
# ipeds_salary_scraper.R, ipeds_enrollment_scraper.R and fsa_pell_scraper.R
# is in edjobs now). Also the Sheridan/Gillette split watch, which is
# Wyoming's alone.
#
# Wyoming has 9 public HE institutions in salarymap.csv but only 8 distinct
# IPEDS unitids: Sheridan College and Gillette College are one accredited
# entity, Northern Wyoming Community College District (240666), so IPEDS
# can't tell their salaries, enrollment or Pell figures apart. Both rows get
# the same figures, and Salary_Note (carried into salarymap.csv by
# edjobs::parse_ipeds_he_salaries()) says so on the dashboard; app.R also
# suppresses Vacancy_Rate for both on that note.

IPEDS_UNITID_MAP <- data.frame(
  unitid = c(240505L, 240514L, 240596L, 240620L, 240657L, 240666L, 240666L, 240693L, 240727L),
  Name = c("Casper College", "Central Wyoming College", "Eastern Wyoming Community College",
           "Laramie County Community College", "Northwest College", "Sheridan College",
           "Gillette College", "Western Wyoming Community College", "University of Wyoming"),
  stringsAsFactors = FALSE
)
IPEDS_UNITID_MAP$Salary_Note <- ifelse(
  IPEDS_UNITID_MAP$unitid == 240666L,
  "Reported by Northern Wyoming Community College District, which includes both Sheridan College and Gillette College -- IPEDS does not break this figure out by campus.",
  NA_character_
)

# ---------------------------------------------------------------------------
# Sheridan/Gillette split watch
# ---------------------------------------------------------------------------
#
# Sheridan and Gillette are in the process of splitting into two colleges,
# so the shared unitid above (and app.R's Vacancy_Rate suppression) will go
# stale once IPEDS reports them separately. Then a NEW unitid shows up in
# the WY institution directory with "Gillette" or "Sheridan" in inst_name
# that isn't 240666; this checks for exactly that (check_salary_drift.R
# reports it), so the split is an assertion to act on rather than something
# to recheck by hand.

# Pure transformation, tested against a captured fixture. Returns the newly
# found unitids, or a 0-row frame (not NULL) while they are still joint.
check_sheridan_gillette_still_joint <- function(directory_df) {
  empty <- data.frame(unitid = integer(0), inst_name = character(0), stringsAsFactors = FALSE)
  if (nrow(directory_df) == 0) return(empty)

  split_candidates <- directory_df[
    grepl("Gillette|Sheridan", directory_df$inst_name, ignore.case = TRUE) &
      directory_df$unitid != 240666,
  ]
  if (nrow(split_candidates) == 0) return(empty)
  split_candidates[, c("unitid", "inst_name")]
}

fetch_sheridan_gillette_split_check <- function() {
  latest <- edjobs::find_latest_ipeds_directory_year()
  check_sheridan_gillette_still_joint(latest$data)
}
