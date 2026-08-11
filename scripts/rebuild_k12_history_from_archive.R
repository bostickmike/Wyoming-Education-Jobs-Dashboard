# Disaster-recovery / verification tool: rebuilds the K-12 accumulated
# datasets (k12jobanalysis.csv, allsum.csv, k12_district_weekly_totals.csv)
# from scratch by reprocessing every raw snapshot in Archivek12_Data/, the
# same way the weekly pipeline used to do on every single run before
# history_accumulator.R's incremental-append path replaced that.
#
# Two real uses:
#   1. Disaster recovery -- if a shipped accumulated CSV is ever lost or
#      believed corrupted, this rebuilds it from the durable raw archive
#      (which the weekly pipeline still writes every run, unchanged).
#   2. Ground truth for tests/testthat/test-history-accumulator.R, which
#      checks that incrementally appending one new week onto an existing
#      accumulated file reproduces exactly what a full from-scratch
#      rebuild through that same week would produce.
#
# Run directly (Rscript scripts/rebuild_k12_history_from_archive.R) to
# actually rebuild and overwrite the files on disk; source() it from
# elsewhere (as the tests do) to get rebuild_k12_history_from_archive()
# without triggering that.

suppressMessages(library(dplyr))

rebuild_k12_history_from_archive <- function(archive_dir = "Archivek12_Data") {
  csv_files <- list.files(archive_dir, pattern = "\\.csv$", full.names = TRUE)
  if (length(csv_files) == 0) {
    stop("rebuild_k12_history_from_archive(): no archive files found in ", archive_dir)
  }

  combined_k12_data <- csv_files %>%
    lapply(function(file) read.csv(file, colClasses = c("Archive_Date" = "character"))) %>%
    bind_rows() %>%
    select(-any_of("X"))

  if (!"posting_id" %in% names(combined_k12_data)) {
    combined_k12_data$posting_id <- NA_character_
  }

  combined_k12_data <- combined_k12_data %>%
    mutate(Archive_Date = case_when(
      grepl("/", Archive_Date) ~ as.Date(Archive_Date, format = "%m/%d/%Y"),
      grepl("-", Archive_Date) ~ as.Date(Archive_Date, format = "%Y-%m-%d"),
      TRUE ~ as.Date(NA)
    ))

  combinedclean <- combined_k12_data %>%
    mutate(
      District = canonicalize_k12_district(District),
      position = classify_k12_position(title),
      posting_id = build_k12_posting_id(
        source_id = posting_id,
        title = title,
        location = location,
        date_posted = date_posted,
        url = url,
        district = District
      )
    ) %>%
    dplyr::select(title, Archive_Date, position, location, url, posting_id, District)

  k12jobs <- combinedclean %>%
    filter(position == "Teacher") %>%
    mutate(Category = classify_k12_subject(title),
           Broad_Category = classify_k12_broad_category(Category)) %>%
    select(title, Archive_Date, position, location, url, posting_id, District, Category, Broad_Category)

  k12_district_weekly_totals <- combinedclean %>%
    count(District, Archive_Date, name = "n")

  k12sumdistrict <- k12jobs %>%
    group_by(Broad_Category, Archive_Date, District) %>%
    summarize(sum = n_distinct(posting_id), .groups = "drop")

  k12sum <- k12sumdistrict %>%
    group_by(Broad_Category, Archive_Date) %>%
    summarize(sum = sum(sum), .groups = "drop") %>%
    mutate(District = "Total") %>%
    select(Broad_Category, Archive_Date, District, sum)

  allsum <- bind_rows(k12sum, k12sumdistrict)

  list(
    combinedclean = combinedclean,
    k12jobs = k12jobs,
    k12_district_weekly_totals = k12_district_weekly_totals,
    allsum = allsum
  )
}

# Only runs when this file is executed directly (Rscript ...), not when
# source()'d -- source() adds a stack frame, so sys.nframe() > 0 while its
# top-level statements evaluate, whereas a directly Rscript'd file's
# top-level statements run at sys.nframe() == 0.
if (sys.nframe() == 0) {
  source("k12_he_classification.R")
  result <- rebuild_k12_history_from_archive()

  write.csv(result$k12jobs, file.path("Wy_Ed_Jobs", "k12jobanalysis.csv"), row.names = FALSE)
  write.csv(result$allsum, file.path("Wy_Ed_Jobs", "allsum.csv"), row.names = FALSE)
  write.csv(result$k12_district_weekly_totals, file.path("Wy_Ed_Jobs", "k12_district_weekly_totals.csv"), row.names = FALSE)

  cat("Rebuilt k12jobanalysis.csv (", nrow(result$k12jobs), " rows), allsum.csv (",
      nrow(result$allsum), " rows), k12_district_weekly_totals.csv (",
      nrow(result$k12_district_weekly_totals), " rows) from ",
      length(list.files("Archivek12_Data", pattern = "\\.csv$")), " archive snapshots.\n", sep = "")
}
