# Shared scraping-resilience helpers for Wy_ED_Jobs.Rmd.
#
# Every per-institution/per-district scraper chunk previously called its
# scrape function bare: if a site's HTML changed, a page timed out, or a
# selector stopped matching, that uncaught error halted the ENTIRE weekly
# knit -- including the final munge chunks that write the CSVs the live app
# reads -- so a problem with one source silently prevented that week's data
# update for every other source too. There was also no persisted record of
# what each run actually scraped, so a source quietly returning 0 rows (a
# broken selector, not a genuine empty week) looked identical to a real
# empty week with nothing to distinguish them after the fact -- this is
# exactly how the Eastern Wyoming CC name typo went unnoticed for 17 months.
#
# safe_scrape() wraps a scrape function so a failure degrades to "this one
# source is missing from this week's data" instead of "nothing updated this
# week," and logs every run's outcome (ok/empty/error, row count, message)
# to scrape_log.csv so failures and selector drift are visible without
# having to notice a downstream count looks off.

# Every fetch_*() function across this project's scraper files ends its
# httr2 pipe with this instead of a bare req_perform() -- a single 429/503
# against a shared multi-tenant host (Applitrack, SchoolSpring, ...) or a
# transient blip against any other live source would otherwise drop that
# whole source for the week with no recourse (confirmed real: Lincoln
# County SD1 and Sublette County SD9 both logged a bare "HTTP 500 Internal
# Server Error" on 2026-08-11 with no retry available). httr2's
# req_retry() retries 429/503 and honors a Retry-After header by default; a
# persistent failure (a genuinely broken/migrated tenant, a 404, a real
# 500) still surfaces as an error after the retries, exactly as before --
# safe_scrape() logs it the same as always. Takes and returns the same
# shapes as req_perform() (path included, for fetch_google_drive_pdf()'s
# streamed-to-disk download in salary_scrapers.R), so it drops into any
# existing `request(...) %>% ... %>% req_perform()` pipe as a straight
# substitution for the last step.
perform_with_retry <- function(req, max_tries = 3, path = NULL) {
  req <- httr2::req_retry(req, max_tries = max_tries, backoff = function(i) 2^i)
  httr2::req_perform(req, path = path)
}

# Build a zero-row data frame with the given column names, so a failed or
# empty scrape can still be bind_rows()'d/rbind()'d with everything else
# without special-casing a NULL result at every call site.
empty_df <- function(cols) {
  as.data.frame(
    stats::setNames(rep(list(character(0)), length(cols)), cols),
    stringsAsFactors = FALSE
  )
}

# Append one row to the scrape run log, creating it with a header if it
# doesn't exist yet.
log_scrape_result <- function(source_name, status, n_rows,
                               error_message = NA_character_,
                               log_path = "scrape_log.csv") {
  entry <- data.frame(
    timestamp = as.character(Sys.time()),
    source = source_name,
    status = status,
    n_rows = n_rows,
    error_message = error_message,
    stringsAsFactors = FALSE
  )
  utils::write.table(
    entry,
    file = log_path,
    sep = ",",
    row.names = FALSE,
    col.names = !file.exists(log_path),
    append = file.exists(log_path)
  )
  invisible(entry)
}

# Run scrape_fn() under tryCatch, log the outcome, and always return a data
# frame with `expected_cols` -- the real scraped result on success, or an
# empty frame with the same shape on failure/empty result, so a caller can
# unconditionally rbind()/bind_rows() every source's result without checking
# for NULL or a missing/misnamed column first.
safe_scrape <- function(source_name, scrape_fn, expected_cols, log_path = "scrape_log.csv") {
  outcome <- tryCatch(
    list(df = scrape_fn(), error = NULL),
    error = function(e) list(df = NULL, error = conditionMessage(e))
  )

  if (!is.null(outcome$error)) {
    log_scrape_result(source_name, status = "error", n_rows = 0L,
                       error_message = outcome$error, log_path = log_path)
    message("safe_scrape: ", source_name, " failed: ", outcome$error)
    return(empty_df(expected_cols))
  }

  df <- outcome$df
  if (is.null(df) || nrow(df) == 0) {
    log_scrape_result(source_name, status = "empty", n_rows = 0L, log_path = log_path)
    return(empty_df(expected_cols))
  }

  log_scrape_result(source_name, status = "ok", n_rows = nrow(df), log_path = log_path)
  df
}
