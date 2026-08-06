# Salary-source coverage check, run after the Rmd render against the
# just-regenerated salarymap2.csv (K-12/WSBA) and salarymap.csv (HE/IPEDS).
# Unlike check_drift.R (job postings, trailing statistical baseline), this
# checks against a known-fixed universe size -- see drift_check.R's
# check_salary_coverage() for why that's the right shape of check here.
# Diagnostic-only: never blocks the pipeline (see weekly-scrape.yml's
# continue-on-error on this step).

source("drift_check.R")
source("ipeds_salary_scraper.R")

k12 <- read.csv(file.path("Wy_Ed_Jobs", "salarymap2.csv"), stringsAsFactors = FALSE)
he <- read.csv(file.path("Wy_Ed_Jobs", "salarymap.csv"), stringsAsFactors = FALSE)

# Wyoming has 48 school districts -- WSBA's teacher salary PDF and
# superintendent salary spreadsheet each report one row per district
# regardless of whether an individual cell is blank (see
# tests/testthat/test-salary-scrapers.R), so nrow() itself is the right
# structural signal: a parser that silently extracts fewer district rows
# than that means the PDF layout changed, not that a district's salary
# happens to be unreported this year.
#
# IPEDS's 9 WY institutions are hardcoded in ipeds_salary_scraper.R's
# IPEDS_UNITID_MAP, so salarymap.csv always has 9 rows regardless of
# whether the API actually matched real salary data -- the meaningful
# signal there is coverage of the headline Faculty_Avg_Salary field, which
# has historically been 9/9 (unlike Professor-rank salary, which is
# legitimately sparse at two-year colleges and isn't checked here).
flags <- rbind(
  check_salary_coverage("K-12 teacher base salary (WSBA)", nrow(k12), expected = 48L),
  check_salary_coverage("HE avg faculty salary (IPEDS)", sum(!is.na(he$Faculty_Avg_Salary)), expected = 9L, min_ok = 8L)
)

if (!is.null(flags) && nrow(flags) > 0) print(flags)

coverage_lines <- if (is.null(flags) || nrow(flags) == 0) {
  character(0)
} else {
  lines <- c(
    paste0("Automated salary-source coverage check flagged ", nrow(flags), " source(s) as of ", Sys.Date(), "."),
    "",
    "Unlike the job-posting drift check above, these are hard assertions against a known, essentially-fixed universe (48 WY school districts, 9 WY public HE institutions) rather than a trailing statistical baseline -- salary data updates far less often (once a year, not weekly), so a genuine week-to-week dip isn't expected. A source landing below its expected count usually means the source changed its page/PDF/API layout and the parser is silently extracting less real data, not that Wyoming lost school districts or colleges.",
    ""
  )
  for (i in seq_len(nrow(flags))) {
    r <- flags[i, ]
    lines <- c(lines, sprintf("- **%s**: expected >= %d, got %d", r$name, r$expected, r$actual))
  }
  c(lines, "")
}

# Sheridan College and Gillette College are in the process of splitting
# from their shared parent entity -- app.R shows both a shared JOINT
# Vacancy_Rate (combined postings / the one shared IPEDS faculty count,
# flagged via Vacancy_Rate_Shared) until IPEDS starts reporting them
# separately (see ipeds_salary_scraper.R's "Sheridan/Gillette split watch"
# section). This is a real live network check (unlike the coverage check
# above, which only reads the already-rendered CSVs), so a transient API
# failure here should surface as "couldn't check" rather than silently
# doing nothing.
split_result <- tryCatch(
  fetch_sheridan_gillette_split_check(),
  error = function(e) NULL
)

split_lines <- if (is.null(split_result)) {
  c(
    "Could not check whether IPEDS has started reporting Sheridan College and Gillette College separately -- the directory API call failed. Not necessarily a problem (could be a transient network issue), but worth a manual check if it keeps happening.",
    ""
  )
} else if (nrow(split_result) > 0) {
  c(
    paste0("IPEDS now reports a NEW unitid for Sheridan/Gillette as of ", Sys.Date(), " -- they may have finished splitting into two separate colleges:"),
    "",
    paste0("- unitid ", split_result$unitid, ": ", split_result$inst_name),
    "",
    "If this is real, update IPEDS_UNITID_MAP in ipeds_salary_scraper.R to the new unitid(s). That's the only change needed: parse_ipeds_he_salaries()'s Salary_Note only fires for unitid == 240666, so it (and everything downstream keyed off it -- Wy_Ed_Jobs/app.R's Vacancy_Rate_Shared in map_he) will automatically go back to each institution having its own real, independent Faculty_Count and vacancy rate once neither institution maps to 240666 anymore.",
    ""
  )
} else {
  character(0)
}

if (length(coverage_lines) == 0 && length(split_lines) == 0) {
  cat("Salary source coverage looks healthy, and Sheridan/Gillette are still reported jointly as expected.\n")
  quit(status = 0, save = "no")
}

report_lines <- c(coverage_lines, split_lines)

# Append to the same report the job-posting drift check may have already
# started, so both land in one GitHub Issue/comment instead of two separate
# threads.
if (file.exists("/tmp/drift_report.md")) {
  write(c("", "---", "", report_lines), file = "/tmp/drift_report.md", append = TRUE)
} else {
  writeLines(report_lines, "/tmp/drift_report.md")
}
cat("Flagged items written to /tmp/drift_report.md\n")
