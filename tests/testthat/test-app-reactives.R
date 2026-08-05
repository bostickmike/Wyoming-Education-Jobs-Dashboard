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
      expect_no_error(output$he_current_plot)
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
      expect_no_error(output$k12_current_plot)
    }
  })
})
