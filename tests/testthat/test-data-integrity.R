# These tests read the actual committed summary CSVs (not fixtures), so they
# double as a data-contract check on whatever was last regenerated. They're
# expected to keep passing as real postings come and go -- what they guard
# against is a structural regression in *how* the summaries are built.

read_summary <- function(name) {
  path <- here::here("Wy_Ed_Jobs", name)
  skip_if_not(file.exists(path), paste(name, "not found -- skipping"))
  df <- read.csv(path)
  # Drop write.csv()'s row-index column -- it's unique per row, so leaving
  # it in would make every "group" a single row and defeat the whole point
  # of grouping by the real category/date columns below.
  df[, setdiff(names(df), "X"), drop = FALSE]
}

expect_total_matches_sum_of_parts <- function(df, group_col, value_col = "sum") {
  # Regression for the HE longitudinal double-counting bug: the pre-
  # aggregated "Total" row for each (category, date) must equal the sum of
  # that same (category, date)'s individual institution/district rows, not
  # some other value. This alone doesn't catch a consumer (like app.R)
  # summing Total together with the individual rows -- that's covered by
  # test-app-reactives.R -- but it does catch the aggregation step itself
  # ever producing a Total row that's out of sync with its parts.
  by_cols <- setdiff(names(df), c(group_col, value_col))
  mismatches <- df %>%
    dplyr::group_by(dplyr::across(dplyr::all_of(by_cols))) %>%
    dplyr::summarize(
      total_row = sum(.data[[value_col]][.data[[group_col]] == "Total"]),
      parts_sum = sum(.data[[value_col]][.data[[group_col]] != "Total"]),
      .groups = "drop"
    ) %>%
    dplyr::filter(total_row != parts_sum)
  expect_equal(nrow(mismatches), 0)
}

test_that("allsum_he.csv: Total row equals sum of individual institutions", {
  d <- read_summary("allsum_he.csv")
  expect_total_matches_sum_of_parts(d, "Institution")
})

test_that("allnow_he.csv: Total row equals sum of individual institutions", {
  d <- read_summary("allnow_he.csv")
  expect_total_matches_sum_of_parts(d, "Institution", value_col = "Sum")
})

test_that("allsum.csv: Total row equals sum of individual districts", {
  d <- read_summary("allsum.csv")
  expect_total_matches_sum_of_parts(d, "District")
})

test_that("allnow.csv: Total row equals sum of individual districts", {
  d <- read_summary("allnow.csv")
  expect_total_matches_sum_of_parts(d, "District", value_col = "Sum")
})

test_that("no known name typos survive into the committed summary data", {
  he <- read_summary("allsum_he.csv")
  expect_false(any(grepl("Commmunity", he$Institution)))

  k12 <- read_summary("allsum.csv")
  expect_false("Lanugage" %in% k12$Broad_Category)
  expect_false(any(grepl("Count School District|Scholl District|Distrcit", k12$District)))
})
