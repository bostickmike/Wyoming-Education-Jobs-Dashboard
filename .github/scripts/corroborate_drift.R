# Tier 2 of the drift-alert system. Only runs when check_drift.R flagged
# something. For each flagged source, renders its live public page with
# chromote (same technique as the manual 2026-08-03 spot-check that found
# the Applitrack bug) and scores the visible text with
# score_page_text_for_job_signal(). Writes /tmp/drift_report.md -- only
# created if there's something worth a human looking at (likely_broken or
# inconclusive); a report full of nothing but looks_genuinely_empty isn't
# worth alerting on.

source("drift_check.R")
source("misc_district_scrapers.R") # for misc_district_registry
library(chromote)

flagged <- read.csv("/tmp/drift_flagged.csv", stringsAsFactors = FALSE)

if (nrow(flagged) == 0) {
  cat("Nothing flagged, no corroboration to do.\n")
  quit(status = 0)
}

url_lookup <- build_source_url_lookup(misc_registry = misc_district_registry)

b <- ChromoteSession$new()
results <- data.frame(name = character(0), type = character(0), mean_count = numeric(0),
                       count = numeric(0), url = character(0), verdict = character(0),
                       stringsAsFactors = FALSE)

for (i in seq_len(nrow(flagged))) {
  row <- flagged[i, ]
  url <- unname(url_lookup[row$name])
  if (is.na(url)) url <- NULL

  verdict <- if (is.null(url)) {
    "no_url_available"
  } else {
    text <- tryCatch({
      b$Page$navigate(url, wait_ = TRUE)
      b$Page$loadEventFired(wait_ = TRUE)
      Sys.sleep(2.5)
      b$Runtime$evaluate("document.body.innerText")$result$value
    }, error = function(e) NA_character_)
    score_page_text_for_job_signal(text)
  }

  cat(sprintf("%-40s baseline=%.1f current=%d -> %s\n", row$name, row$mean_count, row$count, verdict))
  results <- rbind(results, data.frame(
    name = row$name, type = row$type, mean_count = row$mean_count,
    count = row$count, url = if (is.null(url)) NA_character_ else url,
    verdict = verdict, stringsAsFactors = FALSE
  ))
}

b$close()

actionable <- results[results$verdict %in% c("likely_broken", "inconclusive", "no_url_available"), ]

if (nrow(actionable) == 0) {
  cat("All flagged sources corroborated as genuinely empty -- nothing to report.\n")
  quit(status = 0)
}

lines <- c(
  paste0("Automated drift check flagged ", nrow(actionable), " source(s) as of ", Sys.Date(), "."),
  "",
  "A source is flagged when it has at least 2 weeks of history averaging real postings, and this week's count dropped to 20% or less of that average. This is the same failure signature that hid ~200 real postings across 10 Applitrack districts on 2026-08-03 (a Windows-1252 encoding bug, not real absence of jobs) -- these entries are corroborated against the actual live page but still need a human look.",
  ""
)

for (verdict_group in c("likely_broken", "inconclusive", "no_url_available")) {
  subset_rows <- actionable[actionable$verdict == verdict_group, ]
  if (nrow(subset_rows) == 0) next

  label <- switch(verdict_group,
    likely_broken = "### Likely broken -- live page has real job-posting content, scraper reported little/none",
    inconclusive = "### Inconclusive -- drift detected, live page didn't clearly confirm either way",
    no_url_available = "### No URL on file -- couldn't corroborate automatically"
  )
  lines <- c(lines, label, "")
  for (i in seq_len(nrow(subset_rows))) {
    r <- subset_rows[i, ]
    url_part <- if (is.na(r$url)) "" else sprintf(" -- %s", r$url)
    lines <- c(lines, sprintf("- **%s** (%s): averaged %.1f/week, now %d%s", r$name, r$type, r$mean_count, r$count, url_part))
  }
  lines <- c(lines, "")
}

writeLines(lines, "/tmp/drift_report.md")
cat("Report written to /tmp/drift_report.md\n")
