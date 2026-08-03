# Scrapers for the "miscellaneous" K-12 districts that don't sit on any of
# the major platforms covered by direct_api_scrapers.R (previously hand-
# maintained in otherjobs.xlsx, which no code in this repo ever wrote).
#
# Two complementary sources, deliberately kept separate rather than forced
# into one:
#
# 1. WSBA (Wyoming School Boards Association) publishes a statewide
#    vacancies page (wsba-wy.org/vacancies) with clean, reliably-parseable
#    structured entries (title/district/location/posted-date). It's
#    actively current, but a direct comparison against several districts'
#    own sites (Niobrara County SD1, Weston County SD1) found it
#    systematically omits classified/support/substitute/assistant-coach
#    postings -- only ~25-40% of a district's real open positions
#    typically appear there. It is NOT a complete source on its own.
#
# 2. Each district's own site, to catch what WSBA misses. These sit on six
#    different small-business/school-CMS platforms (Apptegy, Edlio,
#    SchoolBlocks, an unnamed Finalsite-style "search documents" platform,
#    WordPress, Google Sites), none of which model job postings as
#    structured data -- postings are free-text prose, bulleted lists, or
#    (Platte County SD1 specifically) image alt-text with no visible title
#    text at all. Extraction here is necessarily heuristic per platform
#    family, tested against real captured content, but inherently less
#    reliable than every other source in this pipeline.
#
# Entries found on a district's own page are deduplicated against that
# same district's WSBA entries by normalized title (lowercased, whitespace/
# punctuation collapsed) before being combined -- see
# dedupe_against_wsba(). This is a heuristic match, not exact: differently-
# worded titles for the same real posting (e.g. WSBA's "K-12 Music/Band
# Instructor" vs. a district's own "Job Description - Music Teacher K12")
# will not be recognized as duplicates and may appear twice. Prefer a
# missed duplicate over a silently dropped real posting.

suppressMessages({
  library(httr2)
  library(rvest)
  library(dplyr)
  library(stringr)
})

# ---------------------------------------------------------------------------
# WSBA statewide vacancies page
# ---------------------------------------------------------------------------

# The page is a Google Sites embed of a Google Doc; despite that, the full
# vacancy list is server-rendered directly in the raw HTML (confirmed: a
# plain HTTP fetch + rvest::html_text2() reproduces byte-identical content
# to a chromote-rendered version), so no browser is needed here either.
fetch_wsba_vacancies <- function(url = "https://www.wsba-wy.org/vacancies") {
  resp <- request(url) %>% req_perform()
  parse_wsba_vacancies(resp_body_string(resp))
}

# Maps WSBA's "<County> County School District No. <N>" naming to this
# project's canonical "<County> County School District <N>" (no "No.").
# Only covers districts this project actually tracks in the misc bucket;
# an unmapped WSBA district name is left as-is rather than dropped, so a
# genuinely new/renamed district still surfaces (just without
# canonicalization) instead of silently vanishing.
canonicalize_wsba_district <- function(district) {
  str_replace(district, " School District No\\. (\\d+)$", " School District \\1")
}

parse_wsba_vacancies <- function(html_text) {
  soup <- rvest::read_html(html_text)
  text <- rvest::html_text2(soup)
  lines <- strsplit(text, "\n")[[1]]

  # Entry lines look like "TITLE - DISTRICT NAME - LOCATION, Wyoming".
  # DISTRICT NAME is either a "<...> School District No. <N>" or a
  # standalone org name (e.g. "Snowy Range Academy"); LOCATION is
  # everything after the last " - " before ", Wyoming".
  entry_pattern <- "^(.+?) - (.+? School District(?: No\\. \\d+)?|[^-]+?) - ([^,]+), Wyoming$"
  entry_idx <- grep(entry_pattern, lines, perl = TRUE)

  if (length(entry_idx) == 0) {
    return(data.frame(Title = character(0), District = character(0),
                       Location = character(0), Posted_Date = character(0),
                       stringsAsFactors = FALSE))
  }

  date_pattern <- "^Posted (\\d{1,2}/\\d{1,2}/\\d{4})$"

  rows <- lapply(entry_idx, function(i) {
    m <- regmatches(lines[i], regexec(entry_pattern, lines[i], perl = TRUE))[[1]]
    title <- m[2]
    district <- canonicalize_wsba_district(m[3])
    location <- m[4]

    # The posted date is the next non-blank line, when present -- a small
    # minority of real WSBA entries have no date line at all (confirmed
    # against the live site, not a parsing gap).
    j <- i + 1
    while (j <= length(lines) && !nzchar(trimws(lines[j]))) j <- j + 1
    posted_date <- if (j <= length(lines) && grepl(date_pattern, lines[j])) {
      d <- sub(date_pattern, "\\1", lines[j])
      as.character(as.Date(d, format = "%m/%d/%Y"))
    } else {
      NA_character_
    }

    data.frame(Title = title, District = district, Location = location,
               Posted_Date = posted_date, stringsAsFactors = FALSE)
  })

  do.call(rbind, rows)
}

# ---------------------------------------------------------------------------
# Deduplication: district's own postings vs. that district's WSBA entries
# ---------------------------------------------------------------------------

normalize_title <- function(title) {
  title <- tolower(title)
  title <- str_replace_all(title, "[^a-z0-9]+", " ")
  str_trim(str_squish(title))
}

# Returns district_postings with any row whose normalized title matches a
# normalized WSBA title for the SAME district removed. Matching is exact
# on the normalized string, not fuzzy, so differently-worded duplicates
# will both survive -- see the module-level note on why that's the safer
# failure mode here.
dedupe_against_wsba <- function(district_postings, wsba_postings, district_name) {
  if (nrow(district_postings) == 0) return(district_postings)

  wsba_titles_here <- wsba_postings$Title[wsba_postings$District == district_name]
  if (length(wsba_titles_here) == 0) return(district_postings)

  wsba_norm <- normalize_title(wsba_titles_here)
  district_postings[!normalize_title(district_postings$Title) %in% wsba_norm, , drop = FALSE]
}
