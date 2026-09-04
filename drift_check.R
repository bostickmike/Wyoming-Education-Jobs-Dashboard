# Detects when a source that reliably has real postings suddenly reports
# none -- the same failure signature as the Applitrack encoding bug found
# 2026-08-03 (silent NA -> zero rows, indistinguishable in the scrape log
# from a district with genuinely no openings). That bug was caught by hand;
# this automates the same kind of check.
#
# Two tiers, kept as separate functions so each is independently testable:
#   1. flag_drift() -- cheap, no network calls. Compares this week's
#      per-source counts against each source's own trailing historical
#      baseline. Pure function, easy to unit test with synthetic history.
#   2. score_page_text_for_job_signal() -- the scoring half of the chromote
#      corroboration step (see .github/scripts/chromote_corroborate.R for
#      the live-fetch half, which isn't unit-tested for the same reason
#      fetch_*() functions elsewhere in this repo aren't: it's a thin I/O
#      wrapper around a real network call).

# Only snapshots from this date forward are valid drift-detection baseline
# candidates. Everything before it predates the Applitrack encoding fix
# (and the WSBA/misc-district/direct-HTTP work before that) -- comparing
# against pre-fix data would flag the FIX itself as suspicious drift on
# every affected district.
BASELINE_VALID_FROM <- as.Date("2026-08-03")

# --------------------------------------------------------------------------
# Tier 1: per-source historical drift detection
# --------------------------------------------------------------------------

# archive_files: named character vector of {date string -> file path}, e.g.
# from list.files(archive_dir, pattern=..., full.names=TRUE) with dates
# parsed out of the filenames. Kept as a plain argument (not a directory
# scan) so this is testable against a handful of synthetic in-memory data
# frames instead of real files on disk.
build_historical_counts <- function(archive_snapshots, name_col) {
  # archive_snapshots: named list of data.frames, names are "YYYY-MM-DD"
  # dates, each data.frame has a `name_col` column of source names (one row
  # per posting, same shape as combinedclean.csv/hedata.xlsx).
  valid_dates <- names(archive_snapshots)[as.Date(names(archive_snapshots)) >= BASELINE_VALID_FROM]

  if (length(valid_dates) == 0) {
    return(data.frame(name = character(0), n_weeks = integer(0), mean_count = numeric(0)))
  }

  counts_by_week <- lapply(valid_dates, function(d) {
    df <- archive_snapshots[[d]]
    as.data.frame(table(df[[name_col]]), stringsAsFactors = FALSE)
  })

  all_counts <- do.call(rbind, counts_by_week)
  names(all_counts) <- c("name", "count")
  all_counts$count <- as.numeric(all_counts$count)

  aggregate(count ~ name, data = all_counts, FUN = function(x) c(n = length(x), mean = mean(x))) -> agg
  data.frame(
    name = agg$name,
    n_weeks = agg$count[, "n"],
    mean_count = agg$count[, "mean"],
    stringsAsFactors = FALSE
  )
}

# current_counts: data.frame(name, count) for this week's just-rendered data.
# baseline: output of build_historical_counts().
# min_weeks: a source needs at least this many valid historical weeks before
#   it's eligible to be flagged at all -- with 0 or 1 data points there's no
#   real baseline yet, just noise.
# min_mean_count: a source whose historical average is below this is exempt.
#   A district that averages 1-2 postings and now has 0 is ordinary
#   week-to-week churn, not the silent-parser-failure signature this check
#   exists to catch (that one hides *dozens* of real postings) -- flagging
#   it every week just trains the reader to ignore the alert. The threshold
#   is deliberately low so a source that genuinely sustained even 3/week and
#   broke to 0 is still caught.
# drop_threshold: flag if current count <= mean_count * drop_threshold.
flag_drift <- function(current_counts, baseline, min_weeks = 2, min_mean_count = 3,
                       drop_threshold = 0.2) {
  merged <- merge(baseline, current_counts, by = "name", all.x = TRUE)
  merged$count[is.na(merged$count)] <- 0

  eligible <- merged[merged$n_weeks >= min_weeks & merged$mean_count >= min_mean_count, ]
  flagged <- eligible[eligible$count <= eligible$mean_count * drop_threshold, ]
  flagged[order(-flagged$mean_count), c("name", "mean_count", "n_weeks", "count")]
}

# A source dropping to (near) zero is ambiguous on count alone: a genuinely
# quiet week looks identical to a scraper that started erroring. But
# safe_scrape() (scrape_helpers.R) already logs which one happened, to
# scrape_log.csv, in the very same pipeline run that produced this week's
# drift-flagged counts -- so check there first, before spending a live
# chromote render on a guess. A source whose most recent logged attempt
# this run was a real "error" (not "empty") is a much stronger and cheaper
# signal: the registered URL itself is broken (a dead ATS tenant, a DNS
# failure, a migrated platform, an HTTP error perform_with_retry() couldn't
# recover from), not just "no visible postings right now". scrape_log's
# `source` strings aren't always an exact match for a flagged `name` (a
# platform-prefixed source name, e.g. "Apptegy/chromote: <District>",
# would still need this even though nothing in this project currently logs
# that way), so match by substring containment rather than requiring
# equality.
attach_scrape_log_errors <- function(flagged, scrape_log) {
  flagged$scrape_error <- rep(NA_character_, nrow(flagged))
  if (nrow(flagged) == 0 || nrow(scrape_log) == 0) return(flagged)

  # Keep only each source's single most recent logged attempt -- a source
  # that errored earlier in the run but succeeded on a later retry/re-run
  # must NOT be reported as currently broken, so status is checked on the
  # latest attempt, not on "was there ever an error this run".
  latest <- scrape_log[order(scrape_log$timestamp), ]
  latest <- latest[!duplicated(latest$source, fromLast = TRUE), ]
  errors <- latest[!is.na(latest$status) & latest$status == "error", ]
  if (nrow(errors) == 0) return(flagged)

  for (i in seq_len(nrow(flagged))) {
    hits <- which(vapply(errors$source, function(s) grepl(flagged$name[i], s, fixed = TRUE), logical(1)))
    if (length(hits) > 0) flagged$scrape_error[i] <- errors$error_message[hits[1]]
  }
  flagged
}

# --------------------------------------------------------------------------
# Tier 0: salary-source structural/coverage checks
# --------------------------------------------------------------------------

# Salary data (WSBA for K-12, IPEDS for Higher Ed -- see salary_scrapers.R
# and ipeds_salary_scraper.R) has a small, essentially fixed universe (48
# WY school districts, 9 WY public HE institutions) and changes far less
# often than job postings (once a year, not weekly), so a trailing
# statistical baseline like flag_drift() doesn't fit. Instead this is a
# hard assertion against that known universe size: a parser silently
# extracting fewer matched records than the known-fixed count is the same
# failure signature as the Applitrack encoding bug -- the scrape "succeeds"
# (safe_scrape logs status "ok", n_rows > 0) while quietly returning much
# less real data than before, because the source changed its page/PDF/API
# layout out from under the parser.
check_salary_coverage <- function(name, actual, expected, min_ok = expected) {
  if (actual >= min_ok) return(NULL)
  data.frame(name = name, expected = expected, actual = actual, stringsAsFactors = FALSE)
}

# --------------------------------------------------------------------------
# Tier 0b: salary VALUE plausibility (as opposed to coverage/row-count)
# --------------------------------------------------------------------------
#
# check_salary_coverage() above (and flag_drift() for job postings) only
# ever check that a source returned enough ROWS -- neither one can catch a
# source whose page/PDF layout shifted just enough to silently misparse
# VALUES while still returning a plausible row count. The WSBA teacher-
# salary PDF is the clearest real risk for exactly this: it's parsed by
# hardcoded pixel-position windows (see salary_scrapers.R), so a column
# nudge in a future WSBA export could swap or shift every district's
# current/prior salary and still produce 48 rows, passing every check
# above without anyone noticing.
#
# Two complementary checks, both pure functions:
#   1. check_salary_value_bounds() -- a hard sanity range. Cheap, catches
#      the most obvious garbage (a location code or a stray digit landing
#      in a dollar column), but a bound wide enough to never false-positive
#      on real salary growth is too wide to catch a subtler misalignment.
#   2. check_salary_yoy_plausibility() -- real historical signal instead of
#      a guessed bound. WSBA's own PDF already reports both the prior and
#      current year's base salary in one scrape (Base_Salary_Prior_Year/
#      Base_Salary_Current_Year), so every run already has 48 real
#      district-level year-over-year changes to compare against EACH
#      OTHER (cross-sectional), without needing this project's own
#      multi-year archive to have accumulated enough history yet (as of
#      2026-08-05 it has exactly one year -- see
#      k12_salary_history.csv). A district moving 47% while every other
#      district moved 2-6% is far more likely a parser misalignment than a
#      genuine outlier settlement.

# actual: named numeric vector (name = district/institution, value = salary).
check_salary_value_bounds <- function(name, actual, min_ok, max_ok) {
  bad <- actual < min_ok | actual > max_ok
  bad[is.na(bad)] <- FALSE
  if (!any(bad)) return(NULL)
  data.frame(
    name = name, entity = names(actual)[bad], value = unname(actual[bad]),
    min_ok = min_ok, max_ok = max_ok, stringsAsFactors = FALSE
  )
}

# current/prior: named numeric vectors (name = district/institution),
# compared pairwise by name. Flags an entity whose |% change| both (a)
# exceeds hard_ceiling outright (a settlement essentially never moves this
# much in one real year) and (b) is a real statistical outlier against
# every OTHER entity's change this same run (median absolute deviation,
# robust to one or two entities genuinely having an unusual year) --
# requiring both avoids flagging a single district with a real large
# settlement while every other district also moved a lot (a real
# statewide event, not a parser bug), and avoids flagging a small
# percentage move that's just normal variation.
check_salary_yoy_plausibility <- function(current, prior, hard_ceiling = 0.25, mad_multiplier = 5) {
  common <- intersect(names(current), names(prior))
  cur <- current[common]
  pri <- prior[common]
  valid <- !is.na(cur) & !is.na(pri) & pri != 0
  if (sum(valid) < 3) return(NULL)  # too few points for a cross-sectional outlier check to mean anything

  pct_change <- (cur[valid] - pri[valid]) / pri[valid]
  center <- stats::median(pct_change)
  spread <- stats::mad(pct_change)

  is_outlier <- if (spread > 0) {
    abs(pct_change - center) > mad_multiplier * spread & abs(pct_change) > hard_ceiling
  } else {
    # A zero spread means every peer moved by (near) the exact same amount
    # -- a MAD-based threshold would then be 0, and "greater than 0" would
    # flag ordinary tiny floating-point variation between otherwise-equal
    # changes. Fall back to the hard ceiling alone: still lets a genuine
    # uniform statewide move of, say, 15% through untouched (below the
    # ceiling), while still catching one district at 47% against five
    # peers that didn't move at all (this function's whole reason to
    # exist), which a spread-based threshold of 0 could never do since
    # nothing can exceed a threshold of Inf.
    abs(pct_change) > hard_ceiling
  }
  if (!any(is_outlier)) return(NULL)

  data.frame(
    name = names(pct_change)[is_outlier],
    prior = unname(pri[valid][is_outlier]),
    current = unname(cur[valid][is_outlier]),
    pct_change = unname(pct_change[is_outlier]),
    stringsAsFactors = FALSE
  )
}

# --------------------------------------------------------------------------
# Source name -> public URL lookup, for the chromote corroboration step
# --------------------------------------------------------------------------

# Human-facing pages, not necessarily the API endpoint the real scraper
# hits -- the point of this lookup is "what would a person visiting the
# site actually see," as independent corroboration.
he_institution_urls <- c(
  "Laramie County Community College"  = "https://www.governmentjobs.com/careers/lcccwy",
  "Casper College"                    = "https://www.schooljobs.com/careers/caspercollege",
  # Was schooljobs.com/careers/westernwyoming (a real but wrong NEOGOV
  # agency, found returning a plausible "0 jobs found" page instead of an
  # error) -- Western is actually on PeopleAdmin like Eastern/Sheridan/
  # Northwest; see Wy_ED_Jobs.Rmd's "western wyoming" chunk for the story.
  "Western Wyoming Community College" = "https://wwcwy.peopleadmin.com/postings/all_jobs",
  "Central Wyoming College"           = "https://www.schooljobs.com/careers/cwc",
  "Gillette College"                  = "https://www.schooljobs.com/careers/gillettecollege",
  "Eastern Wyoming Community College" = "https://ewc.peopleadmin.com/postings/all_jobs",
  "Sheridan College"                  = "https://jobs.sheridan.edu/postings/all_jobs",
  "Northwest College"                 = "https://northwestcollege.simplehire.com/postings/all_jobs",
  "University of Wyoming"             = "https://eeik.fa.us2.oraclecloud.com/hcmUI/CandidateExperience/en/sites/CX_1"
)

build_source_url_lookup <- function(
    k12_registry_csv = "k12_district_registry.csv",
    misc_registry = NULL) {
  k12_registry <- read.csv(k12_registry_csv, stringsAsFactors = FALSE)

  lookup <- c(
    setNames(k12_registry$Job_Link, k12_registry$District),
    he_institution_urls
  )

  if (!is.null(misc_registry)) {
    lookup <- c(lookup, setNames(misc_registry$url, misc_registry$District))
  }

  # Later sources win on name collisions (e.g. a district deliberately
  # dual-listed across two platforms) -- arbitrary but deterministic, and
  # any one live URL for a district is enough for a corroboration check.
  lookup[!duplicated(names(lookup), fromLast = TRUE)]
}

# --------------------------------------------------------------------------
# Tier 2: chromote corroboration scoring (pure function half)
# --------------------------------------------------------------------------

# page_text: visible rendered text of a live page (document.body.innerText
# via chromote, same technique used for the 2026-08-03 manual spot-check).
# Returns one of "likely_broken", "looks_genuinely_empty", or
# "inconclusive" -- deliberately three-valued rather than a boolean, since
# a page that's neither clearly job-signal-positive nor clearly says "no
# openings" (e.g. a fetch error, a redirect to an unrelated page) shouldn't
# be silently folded into either bucket.
score_page_text_for_job_signal <- function(page_text) {
  if (is.na(page_text) || nchar(trimws(page_text)) == 0) {
    return("inconclusive")
  }

  negative_signal <- grepl(
    "no (open |current )?(job|position|vacan)|no openings|not currently (hiring|accepting)|there are (currently )?no",
    page_text, ignore.case = TRUE
  )

  positive_hits <- lengths(regmatches(
    page_text,
    gregexpr("apply now|view details|job title|posted:|closing date|date posted|JobID", page_text, ignore.case = TRUE)
  ))

  if (negative_signal && positive_hits < 3) {
    "looks_genuinely_empty"
  } else if (positive_hits >= 3) {
    "likely_broken"
  } else {
    "inconclusive"
  }
}
