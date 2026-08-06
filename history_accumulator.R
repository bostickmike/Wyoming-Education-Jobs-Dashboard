# Turns the weekly pipeline's derived-dataset writes from "reprocess every
# archived raw snapshot from scratch" into "append this week's newly
# computed rows onto what's already on disk."
#
# Before this, Wy_ED_Jobs.Rmd re-read and re-classified EVERY historical
# archive file (Archivek12_Data/*.csv, Archived_HE_Data/*.xlsx -- 100+ files
# and growing by one every week since August 2024) on every single weekly
# run, just to derive datasets that only ever gain one new week's worth of
# rows. That's O(all history) work on a job with a hard 30-minute CI
# timeout, for a result that's 99%+ identical to last week's. It works fine
# today; it does not fail gracefully as the archive keeps growing -- it
# just eventually blows the timeout with no warning beforehand.
#
# append_weekly_rows() instead takes only this week's freshly classified
# rows and appends them onto the existing accumulated CSV, so the pipeline
# now does O(this week) work regardless of how many weeks of history exist.
# The archived raw snapshots keep being written every week exactly as
# before (that's the durable source of truth / disaster-recovery path,
# untouched by this change) -- they're just no longer read back every run.
# scripts/rebuild_k12_history_from_archive.R and
# scripts/rebuild_he_history_from_archive.R preserve the old from-scratch
# logic for exactly that recovery case, and are what
# tests/testthat/test-history-accumulator.R checks this incremental path
# against on real archived data to prove the two stay equivalent.

suppressMessages(library(dplyr))

# Appends new_rows (expected to be exactly one Archive_Date's worth of
# freshly computed rows) onto whatever's already at existing_path.
#
# Idempotent: if new_rows' date is already present in the existing file
# (a same-day re-run -- workflow_dispatch, a CI retry), that date's old
# rows are replaced rather than duplicated, so running the pipeline twice
# in one day can't double-count that day.
#
# Fails loudly on a column mismatch between the existing file and new_rows
# rather than silently writing a jagged file via bind_rows()'s NA-padding --
# a classifier renaming/adding a column is a real schema change that needs
# a human decision (update the accumulated file's schema, or rebuild from
# archive), not something that should get baked into the growing history
# without anyone noticing.
#
# read_fn is injectable so this is testable against synthetic existing
# data without real files on disk.
append_weekly_rows <- function(existing_path, new_rows, date_col = "Archive_Date",
                                read_fn = utils::read.csv) {
  if (nrow(new_rows) == 0) {
    if (!file.exists(existing_path)) return(new_rows)
    existing <- read_fn(existing_path, stringsAsFactors = FALSE)
    existing[[date_col]] <- as.character(existing[[date_col]])
    return(existing)
  }

  new_rows[[date_col]] <- as.character(new_rows[[date_col]])
  new_dates <- unique(new_rows[[date_col]])
  if (length(new_dates) != 1) {
    stop("append_weekly_rows(): new_rows must contain exactly one ", date_col,
         ", got ", length(new_dates), ": ", paste(new_dates, collapse = ", "))
  }

  if (!file.exists(existing_path)) {
    return(new_rows)
  }

  existing <- read_fn(existing_path, stringsAsFactors = FALSE)
  existing[[date_col]] <- as.character(existing[[date_col]])

  if (!setequal(names(existing), names(new_rows))) {
    stop(
      "append_weekly_rows(): column mismatch between existing ", existing_path,
      " (", paste(sort(names(existing)), collapse = ", "), ") and this week's new rows (",
      paste(sort(names(new_rows)), collapse = ", "), "). A classifier or schema likely ",
      "changed -- fix the mismatch, or rebuild the file from the raw archive (see ",
      "scripts/rebuild_k12_history_from_archive.R / rebuild_he_history_from_archive.R), ",
      "rather than letting bind_rows() silently pad the difference with NA."
    )
  }

  # Same-day re-run guard -- drop this date's rows from the existing file
  # before appending, so a re-run replaces rather than duplicates.
  existing <- existing[existing[[date_col]] != new_dates, , drop = FALSE]

  dplyr::bind_rows(existing, new_rows[names(existing)])
}

# Consistency check for the incremental-append mechanism itself (as opposed
# to the underlying scrape data drifting, which drift_check.R already
# covers separately) -- verifies this week's freshly computed "Total" rows
# actually equal the sum of this week's own per-district/per-institution
# "parts" rows, mirroring the same invariant
# tests/testthat/test-data-integrity.R already checks on the committed
# files, but run proactively here BEFORE anything is written to the
# growing accumulated history, not just caught after the fact. A mismatch
# means a bug in this week's summary computation -- stop() rather than
# silently appending a corrupted week onto years of otherwise-good history.
check_total_matches_parts <- function(total_rows, part_rows, group_cols, value_col = "sum") {
  parts_agg <- part_rows %>%
    dplyr::group_by(dplyr::across(dplyr::all_of(group_cols))) %>%
    dplyr::summarize(parts_sum = sum(.data[[value_col]]), .groups = "drop")

  merged <- total_rows %>%
    dplyr::select(dplyr::all_of(group_cols), total_value = dplyr::all_of(value_col)) %>%
    dplyr::full_join(parts_agg, by = group_cols)

  mismatches <- merged %>%
    dplyr::filter(is.na(total_value) | is.na(parts_sum) | total_value != parts_sum)

  if (nrow(mismatches) > 0) {
    stop(
      "check_total_matches_parts(): this week's Total row(s) don't equal the sum of their ",
      "own parts -- a bug in this week's summary computation, not a data-source problem. ",
      "Refusing to append a corrupted week onto the accumulated history.\n",
      paste(utils::capture.output(print(mismatches)), collapse = "\n")
    )
  }
  invisible(TRUE)
}
