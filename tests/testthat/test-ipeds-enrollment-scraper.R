# Real fixture: the actual Wyoming (fips=56) response from the Urban
# Institute's Education Data Portal fall-enrollment/2023 endpoint,
# captured 2026-08-06 -- all 30 rows across 10 unitids' level_of_study
# breakdowns (8 of which are in IPEDS_UNITID_MAP; the other 2 -- 240709,
# 240718 -- are real WY institutions outside this project's 9-institution
# scope and correctly dropped by the left_join), not synthetic.

test_that("parse_ipeds_he_enrollment sums FTE across level_of_study into one Enrollment figure per institution", {
  df <- read.csv(test_path("fixtures", "ipeds_wy_fall_enrollment_2023.csv"))
  result <- parse_ipeds_he_enrollment(df, 2023)

  expect_equal(nrow(result), 9)
  expect_setequal(result$Name, c(
    "Casper College", "Central Wyoming College", "Eastern Wyoming Community College",
    "Laramie County Community College", "Northwest College", "Sheridan College",
    "Gillette College", "Western Wyoming Community College", "University of Wyoming"
  ))
  expect_true(all(result$Enrollment_Year == "2023"))

  # University of Wyoming has real FTE reported across all three levels in
  # the fixture (Undergraduate 7465, Graduate 1503, First professional --
  # est_fte is -1/missing but rep_fte is a real 417) -- summing them is the
  # whole point of this function, and specifically requires coalescing to
  # rep_fte for the level where est_fte is missing, not silently dropping it.
  uw <- result[result$Name == "University of Wyoming", ]
  expect_equal(uw$Enrollment, 7465 + 1503 + 417)

  # Casper College only offers undergraduate (its Graduate/First-
  # professional rows are -2 "not applicable" in the real fixture) --
  # Enrollment should be exactly that one real level's FTE, not NA.
  casper <- result[result$Name == "Casper College", ]
  expect_equal(casper$Enrollment, 2192)
})

test_that("parse_ipeds_he_enrollment gives Sheridan and Gillette the same shared Enrollment figure", {
  df <- read.csv(test_path("fixtures", "ipeds_wy_fall_enrollment_2023.csv"))
  result <- parse_ipeds_he_enrollment(df, 2023)

  sheridan <- result[result$Name == "Sheridan College", ]
  gillette <- result[result$Name == "Gillette College", ]
  expect_equal(sheridan$Enrollment, gillette$Enrollment)
  expect_equal(sheridan$Enrollment, 1852)
})

test_that("parse_ipeds_he_enrollment treats IPEDS negative sentinel codes as NA, not real values", {
  # A level_of_study an institution doesn't offer at all (both est_fte and
  # rep_fte negative) must contribute nothing to the sum, not be coerced
  # into 0 counted as a real reported figure or NA'ing out the whole total.
  df <- data.frame(
    unitid = c(240505L, 240505L, 240505L),
    level_of_study = c(1L, 2L, 3L),
    est_fte = c(2192L, -2L, -1L),
    rep_fte = c(2192L, -2L, -2L)
  )
  result <- parse_ipeds_he_enrollment(df, 2023)
  casper <- result[result$Name == "Casper College", ]
  expect_equal(casper$Enrollment, 2192)
})

test_that("parse_ipeds_he_enrollment returns NA (not 0) for an institution with no real FTE data at all", {
  df <- data.frame(
    unitid = c(240505L, 240505L),
    level_of_study = c(1L, 2L),
    est_fte = c(-1L, -2L),
    rep_fte = c(-1L, -2L)
  )
  result <- parse_ipeds_he_enrollment(df, 2023)
  casper <- result[result$Name == "Casper College", ]
  expect_true(is.na(casper$Enrollment))
})

test_that("parse_ipeds_he_enrollment returns an empty, correctly-shaped frame when given no rows", {
  result <- parse_ipeds_he_enrollment(data.frame(), 2023)
  expect_equal(nrow(result), 0)
  expect_equal(names(result), c("Name", "Enrollment", "Enrollment_Year"))
})
