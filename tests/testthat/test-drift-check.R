test_that("build_historical_counts excludes pre-fix snapshots and computes correct means", {
  snapshots <- list(
    "2026-08-03" = data.frame(District = c("A", "A", "A", "B")),
    "2026-08-10" = data.frame(District = c("A", "A", "B", "B")),
    "2026-08-17" = data.frame(District = c("A", "A", "A")),
    # Predates the Applitrack encoding fix -- must be excluded, or the fix
    # itself would register as suspicious drift on every affected district.
    "2026-02-27" = data.frame(District = c("A", "A", "A", "A", "A", "A", "A", "A", "A", "A"))
  )

  baseline <- build_historical_counts(snapshots, "District")

  expect_equal(baseline$n_weeks[baseline$name == "A"], 3)
  expect_equal(baseline$mean_count[baseline$name == "A"], (3 + 2 + 3) / 3)
  expect_equal(baseline$n_weeks[baseline$name == "B"], 2)
})

test_that("build_historical_counts returns an empty frame when no snapshots are post-fix", {
  snapshots <- list("2026-02-27" = data.frame(District = c("A", "A")))
  baseline <- build_historical_counts(snapshots, "District")
  expect_equal(nrow(baseline), 0)
})

test_that("flag_drift flags a real drop and leaves a stable source alone", {
  baseline <- data.frame(
    name = c("BigDistrict", "StableDistrict"),
    n_weeks = c(5, 5),
    mean_count = c(50, 10)
  )
  current <- data.frame(name = c("BigDistrict", "StableDistrict"), count = c(0, 9))

  flagged <- flag_drift(current, baseline)

  expect_equal(flagged$name, "BigDistrict")
})

test_that("flag_drift requires a minimum number of historical weeks before flagging", {
  baseline <- data.frame(name = "BrandNewDistrict", n_weeks = 1, mean_count = 10)
  current <- data.frame(name = "BrandNewDistrict", count = 0)

  flagged <- flag_drift(current, baseline, min_weeks = 2)

  expect_equal(nrow(flagged), 0)
})

test_that("flag_drift treats a source missing from current data as a count of zero", {
  baseline <- data.frame(name = "VanishedDistrict", n_weeks = 3, mean_count = 20)
  current <- data.frame(name = character(0), count = numeric(0))

  flagged <- flag_drift(current, baseline)

  expect_equal(flagged$name, "VanishedDistrict")
  expect_equal(flagged$count, 0)
})

test_that("check_salary_coverage flags a source that fell below its expected count", {
  flagged <- check_salary_coverage("K-12 teacher base salary (WSBA)", actual = 12, expected = 48)
  expect_equal(flagged$name, "K-12 teacher base salary (WSBA)")
  expect_equal(flagged$expected, 48)
  expect_equal(flagged$actual, 12)
})

test_that("check_salary_coverage returns NULL when a source meets its expected count", {
  expect_null(check_salary_coverage("K-12 teacher base salary (WSBA)", actual = 48, expected = 48))
})

test_that("check_salary_coverage supports a tolerance below the ideal expected count", {
  # IPEDS Professor-rank coverage is legitimately sparse (some two-year
  # colleges report no "Professor" rank at all) -- min_ok lets a check use
  # a looser floor than the full expected universe without that being
  # confused with actual drift.
  expect_null(check_salary_coverage("HE avg faculty salary (IPEDS)", actual = 8, expected = 9, min_ok = 8))
  flagged <- check_salary_coverage("HE avg faculty salary (IPEDS)", actual = 5, expected = 9, min_ok = 8)
  expect_equal(flagged$actual, 5)
})

test_that("score_page_text_for_job_signal identifies real hidden postings as likely_broken", {
  # Real fixture: this is the actual Sweetwater County SD1 page text that
  # exposed the Applitrack encoding bug -- 69 real postings, scraper said 0.
  text <- paste(readLines(test_path("fixtures", "drift_check", "real_postings_sweetwater.txt"), warn = FALSE), collapse = "\n")
  expect_equal(score_page_text_for_job_signal(text), "likely_broken")
})

test_that("score_page_text_for_job_signal identifies a genuinely empty page", {
  # Real fixture: Western Wyoming CC's actual "No jobs at this time." page.
  text <- paste(readLines(test_path("fixtures", "drift_check", "genuinely_empty_western.txt"), warn = FALSE), collapse = "\n")
  expect_equal(score_page_text_for_job_signal(text), "looks_genuinely_empty")
})

test_that("score_page_text_for_job_signal is honestly inconclusive on ambiguous real content", {
  # Real fixture: Sheridan County SD3's Apptegy page -- real postings exist
  # ("Bus Drivers", a coaching opening) but in a bare-line format with none
  # of the structured keywords (JobID, "posted:", etc.) this heuristic looks
  # for, and no explicit "no openings" phrase either. Getting this wrong in
  # either direction would be worse than admitting the heuristic can't tell.
  text <- paste(readLines(test_path("fixtures", "drift_check", "ambiguous_bare_lines_sheridan3.txt"), warn = FALSE), collapse = "\n")
  expect_equal(score_page_text_for_job_signal(text), "inconclusive")
})

test_that("score_page_text_for_job_signal returns inconclusive for NA or empty input", {
  expect_equal(score_page_text_for_job_signal(NA_character_), "inconclusive")
  expect_equal(score_page_text_for_job_signal(""), "inconclusive")
  expect_equal(score_page_text_for_job_signal("   "), "inconclusive")
})

test_that("build_source_url_lookup combines all registries and later sources win on collision", {
  frontline <- withr::local_tempfile(fileext = ".csv")
  write.csv(data.frame(`School District` = "Test District", JobSite = "https://frontline.example",
                        check.names = FALSE), frontline, row.names = FALSE)

  tedk12 <- withr::local_tempfile(fileext = ".csv")
  write.csv(data.frame(District = "Other District", `Job Link` = "https://ted.example",
                        check.names = FALSE), tedk12, row.names = FALSE)

  springer <- withr::local_tempfile(fileext = ".csv")
  write.csv(data.frame(District = "Other District", `Job Link` = "https://springer.example",
                        check.names = FALSE), springer, row.names = FALSE)

  misc_registry <- data.frame(District = "Misc District", url = "https://misc.example", stringsAsFactors = FALSE)

  lookup <- build_source_url_lookup(frontline, tedk12, springer, misc_registry)

  expect_equal(unname(lookup["Test District"]), "https://frontline.example")
  # "Other District" appears in both tedk12 and springer -- springer (added
  # later in the combination order) should win, matching duplicated(fromLast=TRUE).
  expect_equal(unname(lookup["Other District"]), "https://springer.example")
  expect_equal(unname(lookup["Misc District"]), "https://misc.example")
  expect_true("University of Wyoming" %in% names(lookup))
})
