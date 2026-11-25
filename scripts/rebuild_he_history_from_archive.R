# Disaster-recovery / verification tool: rebuilds the Higher Ed accumulated
# datasets (facultydata.csv, allsum_he.csv, he_institution_weekly_totals.csv, he_jobtype_weekly_totals.csv)
# from scratch by reprocessing every raw snapshot in Archived_HE_Data/, the
# same way the weekly pipeline used to do on every single run before
# history_accumulator.R's incremental-append path replaced that.
#
# See rebuild_k12_history_from_archive.R's header for the two real uses
# (disaster recovery, and ground truth for
# tests/testthat/test-history-accumulator.R) -- same reasoning applies here
# on the HE side.

suppressMessages(library(dplyr))

rebuild_he_history_from_archive <- function(archive_dir = "Archived_HE_Data") {
  xlsx_files <- list.files(archive_dir, pattern = "\\.xlsx$", full.names = TRUE)
  if (length(xlsx_files) == 0) {
    stop("rebuild_he_history_from_archive(): no archive files found in ", archive_dir)
  }

  # build_he_history() keeps HE_FACULTY_COLUMNS, so archives that also carry Pay_*, Close_Date or the map places (from
  # 2026-10-30 on) give the weekly path's facultydata.csv.
  combined_HE_data <- xlsx_files %>%
    lapply(readxl::read_xlsx) %>%
    bind_rows()

  combined_HE_data$Archive_Date <- as.Date(combined_HE_data$Archive_Date)
  combined_HE_data <- combined_HE_data %>%
    mutate(Institution = canonicalize_he_institution(Institution)) %>%
    filter(!is_placeholder_posting(Title))

  build_he_history(combined_HE_data)
}

# Only runs when this file is executed directly -- see
# rebuild_k12_history_from_archive.R's matching comment for why.
if (sys.nframe() == 0) {
  source("k12_he_classification.R")
  result <- rebuild_he_history_from_archive()

  # Written as the committed file is (the weekly run's format): dates bare,
  # each column quoted as the committed file quotes it, and \r\n inside a
  # text field as \n (read.csv() and so the weekly append store it that way;
  # written as is, the HE rebuild put 2,228 CRs into WY's facultydata.csv,
  # 2026-11-22). Row order is the rebuild's own.
  write_rebuilt <- function(df, path) {
    df <- as.data.frame(df, stringsAsFactors = FALSE)
    df[] <- lapply(df, function(x) gsub("\r\n", "\n", if (inherits(x, "Date")) format(x) else as.character(x), fixed = TRUE))
    if (file.exists(path)) write_csv_keep_quoting(df, path) else utils::write.csv(df, path, row.names = FALSE)
  }

  write_rebuilt(result$facultydata, file.path("Wy_Ed_Jobs", "facultydata.csv"))
  write_rebuilt(result$allsum_he, file.path("Wy_Ed_Jobs", "allsum_he.csv"))
  write_rebuilt(result$allnow_he, file.path("Wy_Ed_Jobs", "allnow_he.csv"))
  write_rebuilt(result$he_institution_weekly_totals, file.path("Wy_Ed_Jobs", "he_institution_weekly_totals.csv"))
  write_rebuilt(result$he_jobtype_weekly_totals, file.path("Wy_Ed_Jobs", "he_jobtype_weekly_totals.csv"))

  cat("Rebuilt facultydata.csv (", nrow(result$facultydata), " rows), allsum_he.csv/allnow_he.csv (",
      nrow(result$allsum_he), "/", nrow(result$allnow_he), " rows), he_institution_weekly_totals.csv (",
      nrow(result$he_institution_weekly_totals), " rows) from ",
      length(list.files("Archived_HE_Data", pattern = "\\.xlsx$")), " archive snapshots.\n", sep = "")
}
