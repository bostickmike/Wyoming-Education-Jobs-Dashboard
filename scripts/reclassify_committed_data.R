#!/usr/bin/env Rscript
# scripts/reclassify_committed_data.R
#
# Classification safeguards proposal, item 13: after a change to the
# classifier (edjobs' R/k12_he_classification.R since phase 2 of the package
# migration, 2026-11-11, or this repo's k12_he_classification.R, which keeps
# the state's name corrections), brings the committed data in line with it, so the
# change ships with its data (test-weekly-data-quality.R fails until it does:
# every committed bucket must equal what today's classifier gives its title).
#
# How: the committed K-12 and HE datasets are rebuilt from the raw archives
# (scripts/rebuild_*_history_from_archive.R), which reproduce the committed
# files exactly (.github/scripts/check_rebuild_parity.R). Two passes:
#   1. Guard: rebuild with the classifier as pinned (edjobs tag
#      v<EDJOBS_VERSION>, plus this repo's file at git HEAD) and
#      require it to reproduce the committed files. If it doesn't, the rebuild
#      has drifted from the pipeline and writing it would change more than the
#      classification; the script stops.
#   2. Rebuild with the working-tree classifier (the edjobs checkout, --edjobs,
#      default ../edjobs, plus this repo's file) and report what moved: every
#      position / Category / Job_Type change, postings entering or leaving the
#      teacher and faculty histories, and the files that change.
# With --apply it writes the nine files, then refreshes the duration spells
# (scripts/generate_*_job_duration_spells.R, scripts/build_posting_spells.R).
# Raw archives are never modified.
#
# Usage (repo root):
#   Rscript scripts/reclassify_committed_data.R            # dry run: report only
#   Rscript scripts/reclassify_committed_data.R --apply    # write
#   ... --skip-guard   only if the guard's difference is understood and wanted
#   ... --edjobs <dir>  the edjobs checkout holding the changed classifier
# The guard needs the pinned tag installed. When the checkout's R/ differs from
# the tag, steps 2-3 run in a child process with the checkout installed in a
# temporary library (the rebuild runs in edjobs's namespace, so sourcing a file
# reaches only code outside the package), and the spell builders inherit it.

suppressPackageStartupMessages({ library(dplyr); library(readxl) })
args <- commandArgs(trailingOnly = TRUE)
apply_changes <- "--apply" %in% args
skip_guard <- "--skip-guard" %in% args
edjobs_dir <- { i <- match("--edjobs", args); if (is.na(i) || i == length(args)) "../edjobs" else args[i + 1] }
pinned_tag <- paste0("v", trimws(readLines("EDJOBS_VERSION", warn = FALSE)[1]))
app <- "Wy_Ed_Jobs"

library(edjobs)   # bls_oews_scraper.R and the scrape helpers moved there (R package migration)
for (f in c("k12_he_classification.R", "history_accumulator.R",
            "scripts/rebuild_k12_history_from_archive.R", "scripts/rebuild_he_history_from_archive.R")) source(f)

rebuild_all <- function() {
  k12 <- rebuild_k12_history_from_archive()
  he <- rebuild_he_history_from_archive()
  list("combinedclean.csv" = k12$combinedclean, "k12jobanalysis.csv" = k12$k12jobs,
       "allsum.csv" = k12$allsum, "allnow.csv" = k12$allnow,
       "k12_district_weekly_totals.csv" = k12$k12_district_weekly_totals,
       "facultydata.csv" = he$facultydata, "allsum_he.csv" = he$allsum_he, "allnow_he.csv" = he$allnow_he,
       "he_institution_weekly_totals.csv" = he$he_institution_weekly_totals,
              "k12_jobtype_weekly_totals.csv" = k12$k12_jobtype_weekly_totals,
              "he_jobtype_weekly_totals.csv" = he$he_jobtype_weekly_totals)
}
committed <- lapply(setNames(nm = c("combinedclean.csv", "k12jobanalysis.csv", "allsum.csv", "allnow.csv",
                                    "k12_district_weekly_totals.csv", "facultydata.csv", "allsum_he.csv",
                                    "allnow_he.csv", "he_institution_weekly_totals.csv",
                                    "k12_jobtype_weekly_totals.csv", "he_jobtype_weekly_totals.csv")),
                    function(f) read.csv(file.path(app, f), colClasses = "character", check.names = FALSE))
parity <- function(rebuilt) bind_rows(lapply(names(rebuilt), function(f) rebuild_parity_row(f, committed[[f]], rebuilt[[f]])))
differs <- function(p) nzchar(p$Missing_Cols) | nzchar(p$Extra_Cols) | p$Only_Committed > 0 | p$Only_Rebuilt > 0

# ---- 1. guard: the committed classifier must reproduce the committed data ----
# "Committed" = edjobs at the pinned tag plus this repo's file at HEAD; the
# working tree = the edjobs checkout plus this repo's working file. Each is
# sourced into the global environment, where it masks the attached edjobs for
# the rebuild functions (also sourced there).
git_file <- function(dir, ref, path) {
  f <- tempfile(fileext = ".R")
  if (system2("git", c("-C", dir, "show", paste0(ref, ":", path)), stdout = f) != 0) {
    stop("Couldn't read ", path, " at ", ref, " in ", dir, " (run from the repo root; pass --edjobs <edjobs checkout>).")
  }
  f
}
pinned_classifier <- git_file(edjobs_dir, pinned_tag, "R/k12_he_classification.R")
working_classifier <- file.path(edjobs_dir, "R/k12_he_classification.R")
edjobs_changed <- !identical(readLines(pinned_classifier, warn = FALSE), readLines(working_classifier, warn = FALSE))
state_changed <- system2("git", c("diff", "--quiet", "HEAD", "--", "k12_he_classification.R")) != 0
classifier_changed <- edjobs_changed || state_changed
if (!skip_guard) {
  # The rebuild runs in the installed edjobs's namespace, so "the classifier as committed" means the pinned
  # tag installed (sourcing its classifier file below covers only that one file).
  if (as.character(utils::packageVersion("edjobs")) != sub("^v", "", pinned_tag)) {
    stop("The guard needs the pinned edjobs installed (", pinned_tag, "; installed ", as.character(utils::packageVersion("edjobs")),
         "). Install it (pak::pak(\"bostickmike/edjobs@", pinned_tag, "\")), or pass --skip-guard.")
  }
  if (edjobs_changed) source(pinned_classifier)
  if (state_changed) source(git_file(".", "HEAD", "k12_he_classification.R"))
  cat("Guard: rebuilding with the classifier as committed (edjobs ", pinned_tag, ", this repo at HEAD)...\n", sep = "")
  g <- parity(rebuild_all())
  if (any(differs(g))) {
    print(g[differs(g), c("File", "Committed_Rows", "Rebuilt_Rows", "Missing_Cols", "Extra_Cols", "Only_Committed", "Only_Rebuilt")],
          row.names = FALSE)
    stop("The rebuild with the committed classifier doesn't reproduce the committed data, so writing a rebuild would ",
         "change more than the classification. Find out why first (.github/scripts/check_rebuild_parity.R prints an ",
         "example row per file); --skip-guard overrides.")
  }
  cat("Guard passed: all", nrow(g), "files reproduced.\n\n")
} else {
  cat("--skip-guard: not checking that the committed classifier reproduces the committed data.\n\n")
}
# A change anywhere in edjobs's R/ reaches the rebuild only through the installed package:
# build_k12_combinedclean() and the rest run in edjobs's namespace, where sourcing a file into the global
# environment changes nothing (0.81.0's feed titles, in R/k12_history.R, came out "nothing to write";
# 2026-11-22). So when the checkout's R/ differs from the pinned tag, install the checkout into a temporary
# library and run steps 2-3 there (its spell builders inherit the library). Untracked new files in R/ aren't
# seen by `git diff`; commit them first.
if (!nzchar(Sys.getenv("RECLASSIFY_WITH_CHECKOUT")) &&
    system2("git", c("-C", edjobs_dir, "diff", "--quiet", pinned_tag, "--", "R")) != 0) {
  lib <- tempfile("edjobs-checkout-lib"); dir.create(lib)
  cat("The edjobs checkout's R/ differs from ", pinned_tag, ": installing it into a temporary library and ",
      "rebuilding there.\n\n", sep = "")
  if (system2("R", c("CMD", "INSTALL", "--no-test-load", "-l", shQuote(lib), shQuote(edjobs_dir)), stdout = FALSE, stderr = FALSE) != 0) {
    stop("R CMD INSTALL -l <temp> ", edjobs_dir, " failed")
  }
  libs <- paste(c(lib, Sys.getenv("R_LIBS")[nzchar(Sys.getenv("R_LIBS"))]), collapse = ":")
  status <- system2("Rscript", c("scripts/reclassify_committed_data.R", unique(c(args, "--skip-guard"))),
                    env = c(paste0("R_LIBS=", shQuote(libs)), "RECLASSIFY_WITH_CHECKOUT=1"))
  quit(save = "no", status = status)
}
source(working_classifier)
source("k12_he_classification.R")
if (!classifier_changed) cat("Note: no classifier change (edjobs checkout = ", pinned_tag, ", k12_he_classification.R = HEAD); reclassifying against them.\n\n", sep = "")
if (apply_changes && edjobs_changed) {
  # The spell builders run in their own R process with the installed edjobs.
  inst <- new.env(); sys.source(working_classifier, envir = inst)
  stale <- Filter(function(n) is.function(inst[[n]]) && !identical(deparse(inst[[n]]), deparse(get(n, envir = asNamespace("edjobs")))), ls(inst))
  if (length(stale)) stop("The installed edjobs isn't your edjobs checkout (", paste(head(stale, 3), collapse = ", "),
                          " differ). Install it first: R CMD INSTALL ", edjobs_dir)
}

# Every archived title whose bucket the change moves (not only the titles in
# the committed history): read each line, every move should be intended.
if (classifier_changed) {
  cat("Titles in the raw archives whose bucket changes (scripts/classifier_archive_diff.R):\n")
  system2("Rscript", c("scripts/classifier_archive_diff.R", "--edjobs", edjobs_dir))
  cat("\n")
}

# ---- 2. rebuild with the working-tree classifier, and say what moved ----
cat("Rebuilding with the working-tree classifier...\n")
rebuilt <- rebuild_all()
p <- parity(rebuilt)

moves <- function(label, old, new, key_cols, cols) {
  m <- merge(old[, c(key_cols, cols)], as.data.frame(lapply(as.data.frame(new)[, c(key_cols, cols)], as.character)),
             by = key_cols, suffixes = c(".old", ".new"))
  for (col in cols) {
    a <- m[[paste0(col, ".old")]]; b <- m[[paste0(col, ".new")]]
    ch <- (is.na(a) != is.na(b)) | (!is.na(a) & !is.na(b) & a != b)
    if (!any(ch)) next
    x <- as.data.frame(count(data.frame(from = a[ch], to = b[ch]), from, to, sort = TRUE))
    cat(sprintf("  %s %s: %d rows changed\n", label, col, sum(ch)))
    for (i in seq_len(min(nrow(x), 15))) cat(sprintf("    %4d  %s -> %s\n", x$n[i], x$from[i], x$to[i]))
  }
}
cat("\nWhat moved:\n")
moves("combinedclean.csv", committed[["combinedclean.csv"]], rebuilt[["combinedclean.csv"]], c("Posting_ID", "Archive_Date"), "position")
moves("k12jobanalysis.csv", committed[["k12jobanalysis.csv"]], rebuilt[["k12jobanalysis.csv"]], c("Posting_ID", "Archive_Date"),
      c("Category", "Broad_Category"))
moves("facultydata.csv", committed[["facultydata.csv"]], rebuilt[["facultydata.csv"]], c("Link", "Title", "Archive_Date", "Institution"),
      c("Job_Type", "Category"))
key <- function(d, cols) do.call(paste, c(lapply(as.data.frame(d)[cols], as.character), sep = "\u001f"))
for (f in c("k12jobanalysis.csv", "facultydata.csv")) {
  cols <- if (f == "k12jobanalysis.csv") c("Posting_ID", "Archive_Date") else c("Link", "Title", "Archive_Date", "Institution")
  a <- key(committed[[f]], cols); b <- key(rebuilt[[f]], cols)
  cat(sprintf("  %s: %d rows leave, %d rows enter (%d -> %d)\n", f, sum(!a %in% b), sum(!b %in% a), length(a), length(b)))
}
cat("\nFiles that change:\n")
print(p[differs(p), c("File", "Committed_Rows", "Rebuilt_Rows", "Only_Committed", "Only_Rebuilt")], row.names = FALSE)
if (!any(differs(p))) {
  cat("Nothing to write: the committed data already matches the classifier.\n")
  # The posting spells are built from every raw archive, not from these nine
  # files, so a classifier change that only touches older archived titles
  # still moves them (2026-11-08: MT's "Little Raiders Daycare" posting).
  if (apply_changes) {
    cat("Refreshing the posting spells, which come from the raw archives...\n")
    if (file.exists("scripts/build_posting_spells.R") && system2("Rscript", "scripts/build_posting_spells.R") != 0) {
      warning("scripts/build_posting_spells.R failed; rerun it by hand.")
    }
  } else {
    cat("The posting spells come from the raw archives and can still change: rerun with --apply to refresh them.\n")
  }
  quit(save = "no", status = 0)
}

# Written in the committed file's own row order and formats (dates as text,
# as the pipeline writes them), so the commit's diff shows only what moved:
# a row keeps its committed position when its identity matches; a new row goes
# after the last committed row of its week.
ROW_IDENTITY <- list(
  "combinedclean.csv" = c("Posting_ID", "Archive_Date"), "k12jobanalysis.csv" = c("Posting_ID", "Archive_Date"),
  "allsum.csv" = c("Broad_Category", "Archive_Date", "District"), "allnow.csv" = c("Broad_Category", "District"),
  "k12_district_weekly_totals.csv" = c("District", "Archive_Date"),
  "facultydata.csv" = c("Title", "Link", "Archive_Date", "Institution"),
  "allsum_he.csv" = c("Category", "Archive_Date", "Institution", "Job_Type"),
  "allnow_he.csv" = c("Category", "Job_Type", "Institution"),
  "he_institution_weekly_totals.csv" = c("Institution", "Archive_Date"),
  "k12_jobtype_weekly_totals.csv" = c("Job_Type", "Archive_Date"),
  "he_jobtype_weekly_totals.csv" = c("Job_Type", "Archive_Date"))
in_committed_order <- function(new, old, id_cols) {
  new <- as.data.frame(new, stringsAsFactors = FALSE)
  new[] <- lapply(new, function(x) if (inherits(x, "Date")) format(x) else x)
  # Every column as text, so write_csv_keep_quoting() quotes it as the
  # committed file does (by column) and nothing else does: a number converted
  # back to a number lost the quotes the pipeline writes around Est_Year in
  # combinedclean.csv (2026-11-22).
  new[] <- lapply(new, as.character)
  # Line breaks as the committed file stores them: the raw archives hold
  # \r\n inside some multi-line text fields, read.csv() (and so the weekly
  # run's append) turns a quoted \r\n into \n, and the guard's parity check
  # ignores the difference; written as is, they came back as 2,228 stray
  # CRs in WY's facultydata.csv (2026-11-21).
  new[] <- lapply(new, function(x) gsub("\r\n", "\n", x, fixed = TRUE))
  k <- function(d) {
    base <- do.call(paste, c(lapply(d[id_cols], as.character), sep = "\u001f"))
    paste(base, stats::ave(seq_along(base), base, FUN = seq_along))   # repeated identities stay distinct
  }
  pos <- match(k(new), k(old))
  # A committed row keeps its own text wherever the rebuild differs from it
  # only in what the guard ignores (rebuild_parity_row(): NA vs "", \r\n vs
  # \n), so the diff shows only what the classifier moved (MT facultydata.csv
  # came back with a "" Location as NA, 2026-11-22).
  same <- function(a, b) {
    norm <- function(x) { x <- gsub("\r\n", "\n", x, fixed = TRUE); x[is.na(x) | x == ""] <- "<NA>"; x }
    norm(a) == norm(b)
  }
  hit <- which(!is.na(pos))
  for (col in intersect(names(new), names(old))) {
    keep <- hit[same(new[[col]][hit], old[[col]][pos[hit]])]
    new[[col]][keep] <- old[[col]][pos[keep]]
  }
  if ("Archive_Date" %in% id_cols) {
    last_of_week <- tapply(seq_len(nrow(old)), old$Archive_Date, max)
    pos[is.na(pos)] <- unname(last_of_week[new$Archive_Date[is.na(pos)]]) + 0.5
  }
  pos[is.na(pos)] <- Inf
  # Committed columns in their order, then any column the pipeline now adds
  # (e.g. Role_Hint, 2026-11-09) at the end, as the next weekly run writes it.
  new[order(pos, seq_along(pos)), c(names(old)[names(old) %in% names(new)], setdiff(names(new), names(old))), drop = FALSE]
}

if (!apply_changes) {
  cat("\nDry run: nothing written. Rerun with --apply to write these files.\n")
} else {
  for (f in p$File[differs(p)]) {
    write_csv_keep_quoting(in_committed_order(rebuilt[[f]], committed[[f]], ROW_IDENTITY[[f]]), file.path(app, f))
  }
  cat("\nWritten:", paste(p$File[differs(p)], collapse = ", "), "\nRefreshing duration spells...\n")
  for (s in c("scripts/generate_job_duration_spells.R", "scripts/generate_he_job_duration_spells.R", "scripts/build_posting_spells.R")) {
    if (file.exists(s) && system2("Rscript", s) != 0) warning(s, " failed; rerun it by hand.")
  }
  cat("Done. Run testthat::test_file('tests/testthat/test-weekly-data-quality.R') and commit the classifier with its data.\n")
}
