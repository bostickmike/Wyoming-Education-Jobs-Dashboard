# Loads the real app.R (with the real committed CSVs) into an isolated
# environment and exercises its reactives directly via shiny::testServer,
# rather than mocking data -- this is the same technique used to verify the
# 2026-08-02 fixes by hand; committing it here keeps that verification
# running on every future change instead of being a one-off.

skip_if_not_installed("shiny")

load_app <- function() {
  app_dir <- here::here("Wy_Ed_Jobs")
  skip_if_not(dir.exists(app_dir), "Wy_Ed_Jobs/ not found -- skipping app tests")
  old_wd <- setwd(app_dir)
  on.exit(setwd(old_wd), add = TRUE)

  env <- new.env()
  suppressMessages(sys.source("app.R", envir = env))
  env
}

# Copies the real Wy_Ed_Jobs/ app folder into a scratch tempdir, applies
# corrupt_fn to one file in the copy (not the real committed data), then
# loads app.R from there -- for testing the schema guard's behavior when a
# dataset is actually broken, without touching anything real.
load_app_with_corrupted_file <- function(file_name, corrupt_fn) {
  app_dir <- here::here("Wy_Ed_Jobs")
  skip_if_not(dir.exists(app_dir), "Wy_Ed_Jobs/ not found -- skipping app tests")

  scratch_dir <- withr::local_tempdir()
  file.copy(list.files(app_dir, full.names = TRUE), scratch_dir, recursive = TRUE)
  corrupt_fn(file.path(scratch_dir, file_name))

  old_wd <- setwd(scratch_dir)
  on.exit(setwd(old_wd), add = TRUE)

  env <- new.env()
  suppressMessages(sys.source("app.R", envir = env))
  env
}

test_that("HE longitudinal 'Total' view is not double-counted", {
  # Regression for the HE double-counting bug: filtered_hesum() used to
  # return the entire hesum_he table (Total row + every institution's row)
  # whenever "Total" was selected, and he_longitudinal_plot summed them
  # together -- inflating every category exactly 2x.
  env <- load_app()

  shiny::testServer(env$server, {
    session$setInputs(
      inst_trend = "Total",
      he_category = sort(unique(env$hesum_he$Category)),
      he_scroll = c(min(env$hesum_he$Archive_Date), max(env$hesum_he$Archive_Date)),
      he_chart_type = "all",
      he_detail_level_trends = "detail"
    )

    windowed <- he_windowed()
    expect_true(all(windowed$Institution != "Total"))

    latest_date <- max(windowed$Archive_Date)
    observed <- windowed %>%
      dplyr::filter(Archive_Date == latest_date) %>%
      dplyr::group_by(Category) %>%
      dplyr::summarize(sum = sum(sum), .groups = "drop")

    # hesum_he now carries a Job_Type column (Full Time vs Adjunct/Part-Time);
    # "All Jobs" mode sums across it, so the expected total does too.
    expected <- env$hesum_he %>%
      dplyr::filter(Archive_Date == latest_date, Institution == "Total") %>%
      dplyr::group_by(Category) %>%
      dplyr::summarize(sum = sum(sum), .groups = "drop")

    merged <- dplyr::inner_join(observed, expected, by = "Category", suffix = c("_observed", "_expected"))
    expect_gt(nrow(merged), 0)
    expect_equal(merged$sum_observed, merged$sum_expected)
  })
})

test_that("K-12 longitudinal 'Total' view is still not double-counted", {
  # Same shape of bug is structurally possible here too (filtered_k12sum()
  # also returns everything unfiltered for "Total") -- df_windowed() already
  # guards against it; this pins that guard in place.
  env <- load_app()

  shiny::testServer(env$server, {
    session$setInputs(
      district_trend = "Total",
      broad_category = sort(unique(env$k12sum$Broad_Category)),
      k12_scroll = c(min(env$k12sum$Archive_Date), max(env$k12sum$Archive_Date)),
      k12_detail_level_trends = "detail"
    )

    windowed <- df_windowed()
    expect_true(all(windowed$Broad_Category %in% unique(env$k12sum$Broad_Category)))

    latest_date <- max(windowed$Archive_Date)
    observed <- windowed %>%
      dplyr::filter(Archive_Date == latest_date) %>%
      dplyr::group_by(Broad_Category) %>%
      dplyr::summarize(sum = sum(sum), .groups = "drop")

    expected <- env$k12sum %>%
      dplyr::filter(Archive_Date == latest_date, District == "Total") %>%
      dplyr::select(Broad_Category, sum)

    merged <- dplyr::inner_join(observed, expected, by = "Broad_Category", suffix = c("_observed", "_expected"))
    expect_gt(nrow(merged), 0)
    expect_equal(merged$sum_observed, merged$sum_expected)
  })
})

test_that("HE and K-12 reactives don't error across every institution/district", {
  env <- load_app()

  shiny::testServer(env$server, {
    for (inst in sort(unique(env$hesum_he$Institution))) {
      session$setInputs(inst_trend = inst, he_category = sort(unique(env$hesum_he$Category)),
                         he_scroll = c(min(env$hesum_he$Archive_Date), max(env$hesum_he$Archive_Date)),
                         he_chart_type = "all", he_detail_level_trends = "detail")
      expect_no_error(he_windowed())
      expect_no_error(output$he_longitudinal_plot)
    }
    for (inst in sort(unique(env$henowsum_he$Institution))) {
      session$setInputs(inst_current = inst, he_detail_level_current = "detail")
      expect_no_error(output$he_current_trends_table)
    }

    for (d in sort(unique(env$k12sum$District))) {
      session$setInputs(district_trend = d, broad_category = sort(unique(env$k12sum$Broad_Category)),
                         k12_scroll = c(min(env$k12sum$Archive_Date), max(env$k12sum$Archive_Date)),
                         k12_detail_level_trends = "detail")
      expect_no_error(df_windowed())
      expect_no_error(output$k12_longitudinal_plot)
    }
    for (d in sort(unique(env$k12nowsum$District))) {
      session$setInputs(district_current = d, k12_detail_level_current = "detail")
      expect_no_error(output$k12_current_trends_table)
    }
  })
})

test_that("make_sparkline_svg draws a rising trend with a green endpoint and a falling trend with a red one", {
  env <- load_app()

  rising <- env$make_sparkline_svg(c(10, 15, 20))
  expect_match(rising, "^<svg")
  expect_match(rising, "#1baf7a", fixed = TRUE)

  falling <- env$make_sparkline_svg(c(20, 15, 10))
  expect_match(falling, "#e34948", fixed = TRUE)

  flat <- env$make_sparkline_svg(c(10, 10, 10))
  expect_match(flat, "#999999", fixed = TRUE)
})

test_that("make_sparkline_svg handles too little data without erroring", {
  env <- load_app()

  expect_equal(env$make_sparkline_svg(numeric(0)), "")
  expect_equal(env$make_sparkline_svg(c(5)), "")
  expect_equal(env$make_sparkline_svg(c(NA, NA)), "")
  # One real value plus NAs still isn't enough to draw a line between two points.
  expect_equal(env$make_sparkline_svg(c(5, NA, NA)), "")
})

test_that("compute_wow_delta skips an extra same-week snapshot instead of comparing against it", {
  env <- load_app()

  # A real week-old snapshot, plus an extra same-week re-run 1 day before
  # "latest" (the exact failure mode min_days_back guards against -- see
  # Archivek12_Data's 2026-08-03 entries for a real historical example).
  weekly <- data.frame(
    Archive_Date = as.Date(c("2026-07-30", "2026-08-05", "2026-08-06")),
    n = c(100, 108, 111)
  )
  # Without the gap guard this would return 111 - 108 = 3 (comparing
  # against yesterday's extra run); with it, it should skip the too-recent
  # 2026-08-05 snapshot and compare against the real week-old one.
  expect_equal(env$compute_wow_delta(weekly), 111 - 100)
})

test_that("compute_wow_delta returns NA when no snapshot is old enough to count as 'last week'", {
  env <- load_app()

  weekly <- data.frame(
    Archive_Date = as.Date(c("2026-08-05", "2026-08-06")),
    n = c(50, 55)
  )
  expect_true(is.na(env$compute_wow_delta(weekly)))
})

test_that("compute_vacancy_rate_domain falls back to a placeholder range instead of Inf/-Inf when every rate is NA", {
  env <- load_app()

  expect_equal(env$compute_vacancy_rate_domain(c(NA_real_, NA_real_, NA_real_)), c(0, 1))
  expect_equal(env$compute_vacancy_rate_domain(c(0.05, NA_real_, 0.20)), c(0.05, 0.20))
})

test_that("Sheridan/Gillette get a shared joint vacancy rate instead of NA", {
  # Regression for switching from "suppress both to NA" to "both show the
  # same combined rate" -- see map_he's Vacancy_Rate_Shared comment.
  env <- load_app()
  sg <- env$combined_map_data[env$combined_map_data$Name %in% c("Sheridan College", "Gillette College"), ]
  skip_if(nrow(sg) < 2, "Sheridan/Gillette rows not both present in committed data -- skipping")

  expect_true(all(sg$Vacancy_Rate_Shared))
  expect_false(any(is.na(sg$Vacancy_Rate)))
  # Same joint numerator/denominator/rate for both rows, not each one's own
  # independent count -- that's the whole point of "shared."
  expect_equal(sg$Vacancy_Numerator[1], sg$Vacancy_Numerator[2])
  expect_equal(sg$Vacancy_Denominator[1], sg$Vacancy_Denominator[2])
  expect_equal(sg$Vacancy_Rate[1], sg$Vacancy_Rate[2])
  # Internally consistent: the displayed rate really is numerator/denominator.
  expect_equal(sg$Vacancy_Rate, sg$Vacancy_Numerator / sg$Vacancy_Denominator)
})

test_that("an institution not flagged via Salary_Note gets its own independent vacancy rate", {
  env <- load_app()
  uw <- env$combined_map_data[env$combined_map_data$Name == "University of Wyoming", ]
  skip_if(nrow(uw) == 0, "University of Wyoming row not present in committed data -- skipping")

  expect_false(uw$Vacancy_Rate_Shared)
})

test_that("Data_Coverage is carried through to combined_map_data for both K-12 and HE", {
  # Regression for the disclosure fix: misc-district data completeness used
  # to live only in code comments, invisible to anyone using the dashboard.
  # Every HE institution is "Full" (no misc tier on that side); K-12 has a
  # real mix since misc_district_registry's 12 districts get a "Partial"
  # tier via salarymap2.csv's Data_Coverage column.
  env <- load_app()
  expect_true("Data_Coverage" %in% names(env$combined_map_data))
  expect_false(any(is.na(env$combined_map_data$Data_Coverage)))

  he <- env$combined_map_data[env$combined_map_data$Type == "Higher Ed Institution", ]
  skip_if(nrow(he) == 0, "no HE rows in committed data -- skipping")
  expect_true(all(he$Data_Coverage == "Full"))

  k12_partial <- env$combined_map_data[env$combined_map_data$Type == "K-12 District" &
                                          env$combined_map_data$Data_Coverage != "Full", ]
  skip_if(nrow(k12_partial) == 0, "no partial-coverage K-12 rows in committed data -- skipping")
  # Both partial tiers are legitimate here: misc_district_registry's 12
  # districts ("WSBA + own page"), plus WSBA_ONLY_ORGS entries like Snowy
  # Range Academy ("WSBA only", no own-page scraper at all).
  expect_true(all(k12_partial$Data_Coverage %in% c("Partial (WSBA + own page)", "Partial (WSBA only)")))
})

test_that("clean committed data produces no schema-guard issues", {
  env <- load_app()
  expect_equal(env$DATA_LOAD_ISSUES, character(0))
})

test_that("a dataset missing an expected column degrades instead of crashing app.R, and names the source", {
  # Regression for the "if something breaks, the dashboard should alert you
  # which data source is broken" fix -- before validate_and_pad_schema(),
  # this exact scenario (Teachers_Total_FTE silently dropped from
  # salarymap2.csv) crashed app.R at load time with a bare "object
  # 'Teachers_Total_FTE' not found", naming nothing.
  env <- load_app_with_corrupted_file("salarymap2.csv", function(path) {
    df <- read.csv(path)
    df$Teachers_Total_FTE <- NULL
    write.csv(df, path, row.names = FALSE)
  })

  expect_length(env$DATA_LOAD_ISSUES, 1)
  expect_match(env$DATA_LOAD_ISSUES, "salarymap2\\.csv is missing expected column\\(s\\): Teachers_Total_FTE")
  # The rest of the app still built successfully -- the missing column was
  # padded with NA rather than left absent, so downstream code that
  # references it by name (Vacancy_Rate's calculation) didn't hard-error.
  expect_true(is.data.frame(env$combined_map_data))
  expect_true(nrow(env$combined_map_data) > 0)
})

test_that("the Home-tab data-issue banner renders when there are load issues, and stays hidden when there aren't", {
  env <- load_app()
  shiny::testServer(env$server, {
    # req(FALSE) inside renderUI surfaces as a shiny.silent.error when the
    # output is accessed directly in testServer (rather than just quietly
    # returning NULL, as it would when rendered normally in a browser) --
    # that's the correct "nothing to show" signal here.
    expect_error(output$data_load_issues_banner, class = "shiny.silent.error")
  })

  broken_env <- load_app_with_corrupted_file("salarymap2.csv", function(path) {
    df <- read.csv(path)
    df$Teachers_Total_FTE <- NULL
    write.csv(df, path, row.names = FALSE)
  })
  shiny::testServer(broken_env$server, {
    expect_no_error(output$data_load_issues_banner)
    expect_false(is.null(output$data_load_issues_banner))
  })
})

test_that("Students_Per_Teacher is computed for both K-12 districts (vs. Teachers_Total_FTE) and HE institutions (vs. Faculty_Count)", {
  # Regression for the enrichment-data addition: Enrollment was already
  # fetched from CCD alongside Teachers_Total_FTE but never surfaced
  # anywhere -- Students_Per_Teacher is Enrollment / Teachers_Total_FTE,
  # zero additional scraping. HE gained its own real IPEDS fall-enrollment
  # pull 2026-08-06 (ipeds_enrollment_scraper.R), so both sides should now
  # have real, non-NA values (not just present-but-NA columns).
  env <- load_app()
  expect_true(all(c("Enrollment", "Students_Per_Teacher") %in% names(env$combined_map_data)))

  he <- env$combined_map_data[env$combined_map_data$Type == "Higher Ed Institution", ]
  skip_if(nrow(he) == 0, "no HE rows in committed data -- skipping")
  expect_true(any(!is.na(he$Students_Per_Teacher)))
  he_values <- he$Students_Per_Teacher[!is.na(he$Students_Per_Teacher)]
  # Same loose sanity range as the K-12 check below, not a tight real-
  # world one -- just catching a units/sign error, not asserting what a
  # plausible ratio looks like.
  expect_true(all(he_values > 0 & he_values < 100))

  k12_with_fte <- env$combined_map_data[env$combined_map_data$Type == "K-12 District" &
                                           !is.na(env$combined_map_data$Vacancy_Denominator) &
                                           env$combined_map_data$Vacancy_Denominator > 0, ]
  skip_if(nrow(k12_with_fte) == 0, "no K-12 rows with teacher FTE in committed data -- skipping")
  expect_true(any(!is.na(k12_with_fte$Students_Per_Teacher)))
  # Loose sanity range, not a tight real-world one -- most WY districts sit
  # roughly 10-16 students per teacher, but small/rural districts can be
  # real outliers on either side (confirmed: Weston County SD7 genuinely
  # reports ~36 in CCD's own data, 859 students against a reported 24
  # teacher FTE). This bound exists to catch a units/column mixup (e.g. a
  # negative value or one in the thousands), not to assert what a
  # plausible ratio looks like.
  real_values <- k12_with_fte$Students_Per_Teacher[!is.na(k12_with_fte$Students_Per_Teacher)]
  expect_true(all(real_values > 0 & real_values < 100))
})

test_that("county-level Census context is present for both K-12 and HE, and K-12 sibling districts share values", {
  # Regression for the Census ACS county-context enrichment: real per-
  # county figures on both K-12 and HE rows (HE joined via salarymap.csv's
  # County column, added 2026-08-06), and two K-12 districts in the same
  # county (e.g. Weston County SD1 and SD7) must show the EXACT same
  # county-level figures, not two different ones -- this is a county-level
  # join, not a district-level one. No equivalent sibling check for HE:
  # Wyoming's 9 public HE institutions each sit in a different county, so
  # there's no case of two HE rows legitimately sharing one county's figures.
  env <- load_app()
  census_cols <- c("Median_Household_Income", "Median_Gross_Rent", "Mining_Employment_Share", "Population_Change_Pct")
  expect_true(all(census_cols %in% names(env$combined_map_data)))

  he <- env$combined_map_data[env$combined_map_data$Type == "Higher Ed Institution", ]
  skip_if(nrow(he) == 0, "no HE rows in committed data -- skipping")
  expect_true(any(!is.na(he$Median_Household_Income)))
  # No two HE institutions share a county, so no two HE rows should share
  # an identical (County, Median_Household_Income) figure by coincidence.
  he_with_income <- he[!is.na(he$Median_Household_Income), ]
  expect_equal(length(unique(he_with_income$County)), nrow(he_with_income))

  k12 <- env$combined_map_data[env$combined_map_data$Type == "K-12 District", ]
  skip_if(nrow(k12) == 0, "no K-12 rows in committed data -- skipping")
  expect_true(any(!is.na(k12$Median_Household_Income)))

  siblings <- k12[k12$County == k12$County[which(!is.na(k12$Median_Household_Income))[1]] &
                    !is.na(k12$Median_Household_Income), ]
  skip_if(nrow(siblings) < 2, "no county with 2+ mapped K-12 districts in committed data -- skipping")
  expect_equal(length(unique(siblings$Median_Household_Income)), 1)
  expect_equal(length(unique(siblings$Mining_Employment_Share)), 1)
})

test_that("Child_Poverty_Rate is district-level (unlike the county-level Census columns), so sibling districts can genuinely differ", {
  # Regression for the SAIPE addition: unlike Median_Household_Income etc.
  # (real county-level joins, correctly identical for sibling districts),
  # Child_Poverty_Rate is a real DISTRICT-level figure and two districts in
  # the same county are NOT expected to share it -- confirmed with real
  # data (Fremont County SD2 and SD21 are both Fremont County but have very
  # different real child poverty rates). Also present (NA) on HE rows.
  env <- load_app()
  expect_true("Child_Poverty_Rate" %in% names(env$combined_map_data))

  he <- env$combined_map_data[env$combined_map_data$Type == "Higher Ed Institution", ]
  skip_if(nrow(he) == 0, "no HE rows in committed data -- skipping")
  expect_true(all(is.na(he$Child_Poverty_Rate)))

  k12 <- env$combined_map_data[env$combined_map_data$Type == "K-12 District", ]
  k12_with_rate <- k12[!is.na(k12$Child_Poverty_Rate), ]
  skip_if(nrow(k12_with_rate) == 0, "no K-12 rows with a child poverty rate in committed data -- skipping")
  expect_true(all(k12_with_rate$Child_Poverty_Rate >= 0 & k12_with_rate$Child_Poverty_Rate <= 1))

  fremont <- k12_with_rate[k12_with_rate$County == "Fremont County, Wyoming", ]
  skip_if(nrow(fremont) < 2, "fewer than 2 mapped Fremont County districts with a rate in committed data -- skipping")
  expect_true(length(unique(fremont$Child_Poverty_Rate)) > 1)
})
