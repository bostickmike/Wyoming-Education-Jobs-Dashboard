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
#    SchoolBlocks, SmartSites/ParentSquare, Google Sites), none
#    of which model job postings as structured data -- postings are free-
#    text prose, bulleted lists, embedded-JSON file listings, or (Platte
#    County SD1 specifically) image alt-text with no visible title text at
#    all. Extraction here is necessarily heuristic per platform family,
#    tested against real captured content, but inherently less reliable
#    than every other source in this pipeline. All but Apptegy turned out
#    to be server-rendered (confirmed by comparing plain httr2 output
#    against a chromote-rendered page) -- only Apptegy's 4 districts
#    (Niobrara 1, Platte 2, Sheridan 3, Weston 7) genuinely need a browser.
#
# Entries found on a district's own page are deduplicated against that
# same district's WSBA entries by normalized title (lowercased, whitespace/
# punctuation collapsed, dates/file names/"Job Description" dropped,
# abbreviations spelled out) before being combined -- see
# dedupe_against_wsba() and dedup_title_key(). This is a heuristic match, not exact: differently-
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
  resp <- request(url) %>% perform_with_retry()
  parse_wsba_vacancies(resp_body_string(resp))
}

# Maps WSBA's "<County> County School District No. <N>" naming to this
# project's canonical "<County> County School District <N>" (no "No.").
# Only covers districts this project actually tracks in the misc bucket;
# an unmapped WSBA district name is left as-is rather than dropped, so a
# genuinely new/renamed district still surfaces (just without
# canonicalization) instead of silently vanishing.
#
# Big Horn and Natrona are this project's one canonical-naming exception:
# every other district keeps "County", but these two drop it (see
# the old CCD name rewrite (CCD now matches by NCES id in edjobs), the old SAIPE
# district-name fix, and
# canonicalize_wsba_district_name() in salary_scrapers.R, which already
# apply the same fix for their own sources). Without this, a WSBA vacancy
# for either district lands under "<...> County School District <N>" -- a
# phantom duplicate combinedclean's own canonicalize_k12_district() never
# catches (it only fixes misspellings, not this naming exception) -- and
# that phantom row would carry no salary/vacancy-rate join at all.
# Then canonicalize_k12_district() for WSBA's own misspellings ("Cabon County
# School District 2", 2026-10-30), so its rows meet the direct rows they
# duplicate in remove_wsba_direct_duplicates().
# str_squish() first: WSBA's 2026-11-18 list ended "Sublette County School District No. 1" with a space and a
# no-break space, which base trimws() keeps, so the "No. N" rule missed and the rows formed a phantom district.
canonicalize_wsba_district <- function(district) {
  district <- str_squish(district)
  district <- str_replace(district, " School District (?:No\\.|#) ?(\\d+)$", " School District \\1")
  canonicalize_k12_district(str_replace(district, "^(Big Horn|Natrona) County School District", "\\1 School District"))
}

parse_wsba_vacancies <- function(html_text) {
  soup <- rvest::read_html(html_text)
  # Hyphen, en dash or em dash between title, district and town: in Mar-Jun
  # 2024 WSBA typed many listings with en dashes ("Special Education Director
  # – Hot Springs County School District No. 1 – Thermopolis, Wyoming"), and a
  # hyphen-only pattern skipped them without an error (71 of 245 listings on
  # the 2024-03-01 Internet Archive copy). The live page used hyphens only on
  # 2026-10-26, but its editor can switch back at any time.
  dash <- "[-\u2013\u2014]"
  delim <- paste0("(?:\\s+", dash, "\\s*|\\s*", dash, "\\s+)")
  entry_pattern <- paste0("^(.+?)", delim, "(.+? School District(?: (?:No\\.|#) \\d+)?|[^-\u2013\u2014]+?)", delim,
                          "([^,]+),\\s*Wyoming$")
  date_pattern <- "^Posted (\\d{1,2}/\\d{1,2}/\\d{4})$"

  ps <- rvest::html_elements(soup, "p")
  p_texts <- rvest::html_text(ps, trim = TRUE)
  entry_idx <- which(grepl(entry_pattern, p_texts, perl = TRUE))

  if (length(entry_idx) > 0) {
    rows <- lapply(entry_idx, function(i) {
      m <- regmatches(p_texts[i], regexec(entry_pattern, p_texts[i], perl = TRUE))[[1]]
      title <- trimws(m[2])
      district <- canonicalize_wsba_district(trimws(m[3]))
      location <- trimws(m[4])

      a_elem <- rvest::html_element(ps[i], "a")
      href <- if (!is.na(a_elem)) rvest::html_attr(a_elem, "href") else NA_character_
      url <- if (!is.na(href) && nzchar(trimws(href))) trimws(href) else WSBA_VACANCIES_URL

      j <- i + 1
      while (j <= length(p_texts) && !nzchar(p_texts[j])) j <- j + 1
      posted_date <- if (j <= length(p_texts) && grepl(date_pattern, p_texts[j])) {
        d <- sub(date_pattern, "\\1", p_texts[j])
        as.character(as.Date(d, format = "%m/%d/%Y"))
      } else {
        NA_character_
      }

      data.frame(Title = title, District = district, Location = location,
                 Posted_Date = posted_date, Url = url, stringsAsFactors = FALSE)
    })
    return(do.call(rbind, rows))
  }

  # Fallback to plain lines if no <p> tags matched
  text <- rvest::html_text2(soup)
  lines <- strsplit(text, "\n")[[1]]
  line_idx <- grep(entry_pattern, lines, perl = TRUE)

  if (length(line_idx) == 0) {
    return(data.frame(Title = character(0), District = character(0),
                       Location = character(0), Posted_Date = character(0),
                       Url = character(0), stringsAsFactors = FALSE))
  }

  rows <- lapply(line_idx, function(i) {
    m <- regmatches(lines[i], regexec(entry_pattern, lines[i], perl = TRUE))[[1]]
    title <- trimws(m[2])
    district <- canonicalize_wsba_district(trimws(m[3]))
    location <- trimws(m[4])

    j <- i + 1
    while (j <= length(lines) && !nzchar(trimws(lines[j]))) j <- j + 1
    posted_date <- if (j <= length(lines) && grepl(date_pattern, lines[j])) {
      d <- sub(date_pattern, "\\1", lines[j])
      as.character(as.Date(d, format = "%m/%d/%Y"))
    } else {
      NA_character_
    }

    data.frame(Title = title, District = district, Location = location,
               Posted_Date = posted_date, Url = WSBA_VACANCIES_URL, stringsAsFactors = FALSE)
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

# The key dedupe_against_wsba() matches on: normalize_title() after dropping
# what district pages wrap around a title and WSBA doesn't -- file
# extensions ("...Coach 8/7/2026.docx"), dates ("Paraprofessional
# 7/14/2026", "Closes 8/26"), school years ("2026-27 School Year"), "Job
# Description" -- with the common abbreviations (JH, HS, MS, Asst, SPED)
# spelled out and plurals dropped. Still an exact match on what's left: a
# subset rule was measured and rejected (it paired "Speech-Language
# Pathologist" with "...Pathologist Assistant"). 2026-11-08, last 30 WY
# archives: 7 more duplicate pairs (Sublette #1, Washakie #2, Weston #1,
# Park #16), nothing distinct merged.
dedup_title_key <- function(title) {
  t <- tolower(as.character(title))
  t <- gsub("\\.(docx?|pdf)\\b", " ", t)
  t <- gsub("\\b(closes?|closing|posted|deadline)\\b[^a-z]*\\d{1,2}/\\d{1,2}(/\\d{2,4})?", " ", t)
  t <- gsub("\\b\\d{1,2}/\\d{1,2}/\\d{2,4}\\b", " ", t)
  t <- gsub("\\b(20)?\\d{2}\\s*[-/\u2013]\\s*(20)?\\d{2}\\b(\\s+school\\s+year)?", " ", t)
  t <- gsub("\\b(job\\s+)?description\\b", " ", t)
  t <- gsub("[^a-z0-9]+", " ", t)
  abbrev <- c(jh = "junior high", hs = "high school", ms = "middle school", asst = "assistant",
              sped = "special education")
  vapply(strsplit(trimws(t), " +"), function(w) {
    w <- ifelse(w %in% names(abbrev), abbrev[w], w)
    w <- unlist(strsplit(w, " "))
    w <- sub("(?<=[a-z]{3})(es|s)$", "", w, perl = TRUE)
    paste(w[nzchar(w)], collapse = " ")
  }, character(1))
}

# Returns district_postings with any row whose dedup_title_key() matches a
# WSBA title's for the SAME district removed. Matching is exact on that
# key, not fuzzy, so differently-worded duplicates will both survive -- see
# the module-level note on why that's the safer failure mode here.
dedupe_against_wsba <- function(district_postings, wsba_postings, district_name) {
  if (nrow(district_postings) == 0) return(district_postings)

  wsba_titles_here <- wsba_postings$Title[wsba_postings$District == district_name]
  if (length(wsba_titles_here) == 0) return(district_postings)

  wsba_norm <- dedup_title_key(wsba_titles_here)
  own <- dedup_title_key(district_postings$Title)
  # One district posting for both teams ("JH Assistant Basketball Coaches",
  # Sheridan #3) that WSBA lists as a Boys and a Girls row: WSBA's rows carry
  # the two positions, so the district's combined row is the duplicate
  # (decided 2026-11-09). Only a title that names no gender is matched this
  # way, so a district's "Boys ... Coach" is never dropped for WSBA's
  # "Girls ... Coach". No other case in the last 30 WY archives.
  gender <- "\\b(boy|girl|men|women)\\b"
  no_gender <- function(k) trimws(gsub("\\s+", " ", gsub(gender, " ", k)))
  both_teams <- !grepl(gender, own) & own %in% no_gender(wsba_norm[grepl(gender, wsba_norm)])
  district_postings[!(own %in% wsba_norm | both_teams), , drop = FALSE]
}

empty_misc_result <- function() {
  data.frame(Title = character(0), Location = character(0),
             Posted_Date = character(0), Link = character(0),
             stringsAsFactors = FALSE)
}

# ---------------------------------------------------------------------------
# Edlio (Washakie County SD2, Weston County SD1, Uinta County SD4)
# ---------------------------------------------------------------------------

# Edlio content pages mix up to three independent block types, and a given
# page can use any combination: a "files" block (an uploaded-document
# list, each posting is literally a PDF/image named after the job --
# Weston 1's pattern), a "text" block (prose with the title bolded before
# a colon, in a plain <li> -- Washakie 2's pattern), and a "scrollingTabs"
# widget (Certified/Classified/Coaching tabs, each tab's content a single
# JSON-embedded HTML string with postings as plain <br>-separated lines,
# no title markup at all -- Uinta 4's pattern, a materially different
# Edlio page template from the other two). None of the three carry a
# posted date.
#
# A page can ALSO have "files" blocks that have nothing to do with job
# postings at all: salary schedules, application forms, or (confirmed on
# Washakie 2's real page) individual attachments referenced inline within
# unrelated prose, with no heading of their own. Only a files block whose
# nearest preceding bold heading contains "Open Position" is treated as a
# real posting list -- everything else is silently excluded, verified
# against both districts' real pages (Weston 1 has 3 separate files
# blocks: "Open Positions", an application-forms block, and a salary-
# schedule block; only the first is real postings).
fetch_wy_edlio_postings <- function(url) {
  resp <- request(url) %>% perform_with_retry()
  parse_wy_edlio_postings(resp_body_string(resp))
}

parse_wy_edlio_postings <- function(html_text) {
  soup <- rvest::read_html(html_text)

  file_blocks <- rvest::html_elements(soup, ".page-block-files")
  file_titles <- character(0)
  file_links <- character(0)
  for (block in file_blocks) {
    heading <- rvest::html_element(block, xpath = "preceding::strong[1]")
    heading_text <- if (!is.na(heading)) rvest::html_text2(heading) else ""
    if (grepl("open position", heading_text, ignore.case = TRUE)) {
      links_in_block <- rvest::html_elements(block, "a")
      file_titles <- c(file_titles, rvest::html_text2(links_in_block))
      file_links <- c(file_links, rvest::html_attr(links_in_block, "href"))
    }
  }

  prose_nodes <- rvest::html_elements(soup, ".page-block-text li strong")
  prose_titles <- str_trim(str_remove(rvest::html_text2(prose_nodes), ":\\s*$"))

  # scrollingTabs widget: each real job-category tab is
  # "title":"Certified/Classified/Coaching(...)","content":"<html
  # string>","active". Content is itself HTML, JSON-string-escaped (\n,
  # \") -- postings are plain text separated by literal <br> tags, with no
  # per-posting markup to key off at all, so this can only be scoped by
  # tab title (Certified/Classified/Coaching), not by any structural
  # marker. A trailing licensing/application-instructions paragraph
  # follows the postings in the same tab; excluded by requiring each
  # candidate line be short and not itself prose (no period, not
  # containing "must"/"submit"/"application").
  tab_matches <- gregexpr(
    '"title":"(Certified[^"]*|Classified[^"]*|Coaching[^"]*)","content":"(.*?)","active"',
    html_text, perl = TRUE
  )
  tab_groups <- regmatches(html_text, tab_matches)[[1]]
  tab_titles <- character(0)
  for (tab in tab_groups) {
    m <- regmatches(tab, regexec('"title":"([^"]*)","content":"(.*?)","active"', tab, perl = TRUE))[[1]]
    content <- gsub("\\\\n", " ", m[3])
    content <- gsub("&nbsp;", " ", content)

    # Two independent tab-content shapes seen on real pages -- BOTH can
    # appear in the SAME tab, not just one or the other: plain text
    # separated by literal <br> tags (Uinta 4's Certified/Classified tabs
    # use this for the real postings themselves), and postings as <li>
    # items inside one or more <ul> lists, with category sub-headers
    # ("High School"/"Middle School") as separate <p> tags OUTSIDE any
    # <li> (Uinta 4's own Coaching tab -- has zero <br> tags at all, so
    # the <br>-only extraction previously treated the ENTIRE tab, headers
    # and all, as one un-splittable blob that failed the length filter
    # below and silently vanished -- 8 real coaching postings, not caught
    # by any test because the existing fixtures only covered the <br>
    # shape). The Classified tab's OWN trailing "Classified Job
    # Application"/"Bus Driver Job Application" links are also <li> items
    # (a real, separate <ul> further down the same tab, after the <br>
    # postings) -- an either/or choice keyed on "does this tab contain any
    # <li> at all" would silently drop that tab's real <br> postings the
    # moment it also has an unrelated <li> list; extracting candidates
    # from BOTH shapes unconditionally and relying on the shared filter
    # below to drop non-postings (the application links contain the word
    # "application") is what actually handles a tab having either, both,
    # or neither shape correctly.
    br_lines <- gsub("<[^>]+>", "", strsplit(content, "<br>")[[1]])
    li_items <- regmatches(content, gregexpr("<li>.*?</li>", content, perl = TRUE))[[1]]
    li_lines <- gsub("<[^>]+>", "", li_items)
    # The first line in particular carries a leading <p><font ...> prefix
    # (confirmed on Uinta 4's real page: "K-12 Special Education Teacher"
    # arrives as "...<font size=\"5\">K-12 Special Education Teacher"),
    # since that markup precedes the first <br> rather than following one
    # -- stripping tags first (above) rather than before splitting on
    # <br> would have destroyed the <br> delimiters themselves.
    lines <- str_trim(c(br_lines, li_lines))
    lines <- lines[nzchar(lines) & nchar(lines) < 80 & !grepl("must|submit|application|\\.$", lines, ignore.case = TRUE)]
    tab_titles <- c(tab_titles, lines)
  }

  titles <- c(file_titles, prose_titles, tab_titles)
  links <- c(file_links, rep(NA_character_, length(prose_titles) + length(tab_titles)))

  if (length(titles) == 0) return(empty_misc_result())

  data.frame(Title = titles, Location = NA_character_, Posted_Date = NA_character_,
             Link = links, stringsAsFactors = FALSE)
}

# ---------------------------------------------------------------------------
# SchoolBlocks (Sublette County SD1)
# ---------------------------------------------------------------------------

# The page embeds a Google-Drive-folder-backed widget (titled "Current Job
# Announcements" on this specific district's page) as a DOUBLE-escaped JSON
# string within the page's own JS state -- i.e. the substring contains
# literal backslash-quote (\") sequences, not real JSON syntax, until
# un-escaped once. Each item is then extracted by splitting on its own
# {"viewLink":" boundary rather than full JSON-parsing the whole blob,
# since the surrounding page has other unrelated "title" fields that a
# naive whole-page regex would also match.
fetch_schoolblocks_postings <- function(url, widget_title = "Current Job Announcements") {
  resp <- request(url) %>% perform_with_retry()
  parse_schoolblocks_postings(resp_body_string(resp), widget_title)
}

parse_schoolblocks_postings <- function(html_text, widget_title = "Current Job Announcements") {
  marker <- paste0("account_title\\\":\\\"", widget_title)
  idx <- regexpr(marker, html_text, fixed = TRUE)
  if (idx == -1) return(empty_misc_result())

  window <- substr(html_text, idx, min(idx + 10000, nchar(html_text)))
  unescaped <- gsub('\\\\"', '"', window)

  items_idx <- regexpr('"items":\\[', unescaped)
  if (items_idx == -1) return(empty_misc_result())
  items_region <- substr(unescaped, items_idx, min(items_idx + 6000, nchar(unescaped)))

  chunks <- strsplit(items_region, '\\{"viewLink":"')[[1]][-1]
  if (length(chunks) == 0) return(empty_misc_result())

  rows <- lapply(chunks, function(chunk) {
    title_m <- regmatches(chunk, regexpr('"title":"[^"]+"', chunk))
    date_m <- regmatches(chunk, regexpr('"modifiedTimestamp":"[^"]+"', chunk))
    if (length(title_m) == 0) return(NULL)
    title <- sub('"title":"([^"]+)"', "\\1", title_m)
    posted_date <- if (length(date_m) > 0) {
      substr(sub('"modifiedTimestamp":"([^"]+)"', "\\1", date_m), 1, 10)
    } else {
      NA_character_
    }
    data.frame(Title = title, Location = NA_character_, Posted_Date = posted_date,
               Link = NA_character_, stringsAsFactors = FALSE)
  })
  rows <- rows[!vapply(rows, is.null, logical(1))]
  if (length(rows) == 0) return(empty_misc_result())
  do.call(rbind, rows)
}

# ---------------------------------------------------------------------------
# Google Sites (Uinta County SD6) -- the third platform family that
# genuinely needs a browser
# ---------------------------------------------------------------------------

# Previously assumed server-rendered, "same underlying rendering as the WSBA
# page" -- wrong, confirmed directly 2026-09-04: a plain httr2 fetch of the
# real live page contains none of its actual posting text at all (checked
# for "accepting applications", not present), while a chromote render of the
# identical URL shows it in full. This had been silently returning 0 rows
# for real, live postings the whole time it was plain-HTTP -- not a
# genuinely quiet district. Two independent title patterns confirmed on the
# real rendered page, both numbered ("N-"), but in opposite title/district
# order:
#
# 1. "N-  TITLE District Name County School District #N is
#    looking/seeking/accepting..." -- title comes BEFORE the district name
#    (e.g. "1-   High School Boys Assistant Swim Coach Uinta County School
#    District #6 is taking applications..."). Whitespace after the "N-" is
#    NOT reliably zero, unlike this pattern's original single confirmed
#    example ("1-Musical Director...") -- the real page uses anywhere from
#    0 to 3 spaces, so this must tolerate `\s*`, not assume none.
# 2. "N- District Name County School District #N is accepting/taking
#    applications for [a/an] TITLE." -- the inverse order, title comes
#    AFTER the district name and a fixed "applications for" phrase, ending
#    at the next period (e.g. "1- Uinta County School District #6 is
#    accepting applications for a HS Musical Assistant Director."). Not
#    caught by pattern 1's lookahead at all, since here the district name
#    comes immediately after the number, not the title -- confirmed this
#    silently dropped 4 of the page's 5 real postings (only the swim coach
#    posting used pattern 1's order).
fetch_wy_googlesites_postings <- function(chromote_session, url) {
  chromote_session$Page$navigate(url)
  chromote_session$Page$loadEventFired(wait_ = TRUE, timeout_ = 30)
  Sys.sleep(5)
  text <- chromote_session$Runtime$evaluate("document.body.innerText")$result$value
  parse_wy_googlesites_postings(text)
}

parse_wy_googlesites_postings <- function(rendered_text) {
  # document.body.innerText preserves non-breaking spaces (U+00A0) from the
  # page's own styling, which R's \s (PCRE, non-Unicode mode) does not
  # match -- the same gotcha WY's old Apptegy parser had, confirmed here too: the swim-coach posting's "1-" is followed
  # by two U+00A0 characters, not regular spaces, silently failing every
  # `\s*`/`\s+` in both patterns below without erroring.
  rendered_text <- gsub("\u00a0", " ", rendered_text)

  title_before_district <- regmatches(rendered_text, gregexpr(
    "\\d+-\\s*([A-Z][A-Za-z/ ]{2,60}?)(?=\\s+[A-Z][a-z]+ County School District|\\s+is (?:looking|seeking|accepting))",
    rendered_text, perl = TRUE
  ))[[1]]
  titles_1 <- str_trim(sub("^\\d+-\\s*", "", title_before_district))

  title_after_district <- regmatches(rendered_text, gregexpr(
    "\\d+-\\s*[A-Z][a-z]+ County School District #?\\d+ is (?:accepting|taking) applications for (?:a |an )?([A-Za-z][A-Za-z0-9/ '-]{2,60}?)\\.",
    rendered_text, perl = TRUE
  ))[[1]]
  titles_2 <- str_trim(sub(
    "^\\d+-\\s*[A-Z][a-z]+ County School District #?\\d+ is (?:accepting|taking) applications for (?:a |an )?([A-Za-z][A-Za-z0-9/ '-]+)\\.$",
    "\\1", title_after_district
  ))

  titles <- unique(c(titles_1, titles_2))
  titles <- titles[nzchar(titles)]

  if (length(titles) == 0) return(empty_misc_result())

  # Each posting is one numbered line; the pay it states ("Pay starts at $20.59 per hour") is in it (2026-11-25).
  items <- grep("^\\s*\\d+-", strsplit(rendered_text, "\n", fixed = TRUE)[[1]], value = TRUE)
  own_line <- vapply(titles, function(t) {
    hit <- items[grepl(t, items, fixed = TRUE)]
    if (length(hit)) hit[1] else NA_character_
  }, "", USE.NAMES = FALSE)
  cbind(data.frame(Title = titles, Location = NA_character_, Posted_Date = NA_character_,
                   Link = NA_character_, stringsAsFactors = FALSE),
        extract_posted_pay(own_line))
}

# ---------------------------------------------------------------------------
# Educational Networks / "EN CMS" (Cheyenne Classical Academy, Wyoming
# Classical Academy) -- found 2026-08-06 while investigating charter schools
# not yet in this pipeline
# ---------------------------------------------------------------------------

# Server-rendered (a plain httr2 fetch with a real browser User-Agent
# reproduces the full page -- confirmed by comparing against a chromote
# render), but structurally the most free-form source in this file: each
# posting is one hand-edited <td> in an "en-editable-table" CMS widget, with
# no consistent internal markup between cells (even within the same
# school's own table -- confirmed directly: some titles are wrapped in a
# bold <span>, others aren't; the "NEW" tag sometimes shares the title's
# own line, sometimes gets its own; "(All Positions Filled)" appears
# inline after the title on some rows and on its own line on others).
# Requires a real browser User-Agent for the same reason TedK12 does (see
# fetch_tedk12_postings() in direct_api_scrapers.R) -- unrelated platforms,
# same underlying cause (bot-detection-driven content negotiation).
fetch_educational_networks_postings <- function(url) {
  resp <- request(url) %>%
    req_user_agent("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36") %>%
    perform_with_retry()
  parse_educational_networks_postings(resp_body_string(resp))
}

# Rather than parse each cell's specific nested-span layout (too
# inconsistent, per the header comment above), works off html_text2()'s
# flattened text: strips the fixed, known action-link labels ("View Job
# Posting"/"View Job Description"/"Apply Now" -- CMS-template button text,
# never part of a real title) from wherever they appear in the cell, then
# takes the first line of what's left as the title. A "(All Positions
# Filled)" marker anywhere in the cell's full text excludes that posting
# entirely -- it's a real posting that's no longer open, not a live one.
# An empty title after stripping (a cell containing nothing but an "Apply
# Now" button and no descriptive text at all -- confirmed a real case,
# a stray/orphaned cell on Cheyenne Classical's page) is excluded too;
# nzchar(NA_character_) is TRUE in R, so that check is written as an
# explicit is.na() first, not folded into a single nzchar() condition.
parse_educational_networks_postings <- function(html_text) {
  page <- rvest::read_html(html_text)
  cells <- rvest::html_elements(page, "table.en-editable-table td")
  if (length(cells) == 0) return(empty_misc_result())

  titles <- vapply(cells, function(cell) {
    full_text <- trimws(rvest::html_text2(cell))
    if (!nzchar(full_text)) return(NA_character_)
    if (grepl("(?i)all positions filled", full_text, perl = TRUE)) return(NA_character_)

    title <- sub("(?i)\\s*(view job posting|view job description|apply now).*$", "", full_text, perl = TRUE)
    title <- trimws(strsplit(title, "\n")[[1]][1])
    title <- trimws(sub("(?i)\\s*new\\s*$", "", title))
    if (is.na(title) || !nzchar(title)) return(NA_character_)
    title
  }, character(1))

  # A posting's own cell states its pay (Cheyenne Classical's "$150 per day", 2026-11-25).
  cell_text <- vapply(cells, function(cell) trimws(rvest::html_text2(cell)), character(1))[!is.na(titles)]
  titles <- titles[!is.na(titles)]
  if (length(titles) == 0) return(empty_misc_result())

  cbind(data.frame(Title = titles, Location = NA_character_, Posted_Date = NA_character_,
                   Link = NA_character_, stringsAsFactors = FALSE),
        extract_posted_pay(cell_text))
}

# ---------------------------------------------------------------------------
# Apptegy (Niobrara County SD1, Sheridan County SD3, Weston County SD7)
# ---------------------------------------------------------------------------

# Since edjobs 0.24.0 these districts use the package's Apptegy family routine,
# edjobs::fetch_apptegy_postings() (text mode, a shared chromote session), the
# same one 44 MT districts use; WY's own parser (marked KNOWN INCOMPLETE: it
# missed Weston 7's paraprofessional and maintenance postings and its
# substitute lines) was deleted. Comparison:
# claude-notes/2026-11-14_wy-families/README.md.

# ---------------------------------------------------------------------------
# Prairie View Community School -- the second platform family that
# genuinely needs a browser (found 2026-08-06)
# ---------------------------------------------------------------------------

# A modern client-side-rendered app (built with "Manus", per its own
# window.__MANUS_HOST_DEV__ global -- confirmed via a plain fetch: raw HTML
# has no posting text, only a JS bundle with no embedded job data baked in
# at build time, unlike e.g. fetch_paylocity_jobs()'s window.pageData).
# Real job titles are genuine <h1>-<h5> headings, unlike Apptegy's free
# prose -- confirmed via a live DOM query, not just innerText, since
# innerText's flattened line order didn't reliably put each title
# immediately before its own description. Scoped to the headings strictly
# between the page's own "Open Positions" and "Application Process"
# section headings, so this doesn't also pick up the page's marketing
# headings ("Why Work With Us", "Mission-Driven Work", etc.). Needs a
# browser: this page never puts that text in server-rendered HTML at all.
fetch_prairieview_postings <- function(chromote_session, url) {
  chromote_session$Page$navigate(url)
  chromote_session$Page$loadEventFired(wait_ = TRUE, timeout_ = 30)
  Sys.sleep(5)
  headings_json <- chromote_session$Runtime$evaluate(
    "JSON.stringify(Array.from(document.querySelectorAll('h1,h2,h3,h4,h5')).map(h => h.innerText.trim()).filter(t => t.length > 0))"
  )$result$value
  parse_prairieview_postings(headings_json)
}

parse_prairieview_postings <- function(headings_json) {
  headings <- jsonlite::fromJSON(headings_json)
  if (length(headings) == 0) return(empty_misc_result())

  start_idx <- which(headings == "Open Positions")
  end_idx <- which(headings == "Application Process")
  if (length(start_idx) == 0 || length(end_idx) == 0 || end_idx[1] <= start_idx[1] + 1) {
    return(empty_misc_result())
  }

  titles <- headings[(start_idx[1] + 1):(end_idx[1] - 1)]
  titles <- titles[nzchar(titles)]
  if (length(titles) == 0) return(empty_misc_result())

  data.frame(Title = titles, Location = NA_character_, Posted_Date = NA_character_,
             Link = NA_character_, stringsAsFactors = FALSE)
}

# ---------------------------------------------------------------------------
# Registry + orchestration
# ---------------------------------------------------------------------------

# One row per district or standalone charter school (the same broadening
# WSBA_ONLY_ORGS already established for Snowy Range Academy -- these two
# aren't LEAs either, just orgs with their own real, scrapable job page),
# read from k12_district_registry.csv (one registry schema, 2026-11-16; before
# that a data frame here): the rows whose Platform is a district-site reader
# below. Columns used: District, Platform, Job_Link (the page) and the family
# routines' per-district rules List_Start / List_Stop (where the posting list
# starts and stops) and List_Skip (Apptegy only: a section skipped up to the
# next header; Weston 7's "Subs Needed" block repeats its substitute list in
# prose, so it's skipped and a posting below it still reads).
MISC_DISTRICT_PLATFORMS <- c("SmartSites", "SchoolBlocks", "Edlio", "EdlioTabs",
                             "GoogleSitesBespoke", "EducationalNetworks", "Apptegy", "PrairieViewHeuristic")
# Their whole registry rows, for scrape_registry_platforms().
misc_district_rows <- function(registry = read_k12_registry()) {
  registry[registry$Platform %in% MISC_DISTRICT_PLATFORMS, , drop = FALSE]
}
misc_district_registry <- local({
  path <- if (file.exists("k12_district_registry.csv")) "k12_district_registry.csv" else here::here("k12_district_registry.csv")
  r <- utils::read.csv(path, stringsAsFactors = FALSE, na.strings = "", colClasses = "character")
  r <- r[r$Platform %in% MISC_DISTRICT_PLATFORMS, c("District", "Platform", "Job_Link", "List_Start", "List_Stop", "List_Skip")]
  rownames(r) <- NULL
  r
})

# Standalone orgs WSBA covers as their own "District" entry (see
# parse_wsba_vacancies()'s comment on WSBA's "<...> - <org> - <location>,
# Wyoming" line format) that aren't school districts and have no own-page
# scraper of any kind -- WSBA is the only source for these, not a
# supplement to one. Snowy Range Academy is the one confirmed case
# (Laramie Montessori Charter School, the other real charter school found,
# has its own clean Paylocity source instead -- see
# direct_api_scrapers.R::fetch_paylocity_jobs() and Wy_ED_Jobs.Rmd's
# charter-school block). Previously this project's own comments claimed
# Snowy Range "already surfaces via WSBA with no extra code needed," which
# turned out to be wrong: fetch_all_misc_district_postings() below only
# ever pulled WSBA rows for districts actually IN misc_district_registry,
# so Snowy Range's postings were silently dropped entirely -- confirmed
# absent from every committed combinedclean.csv to date. This constant and
# the loop below are the actual fix.
# The orgs are the rows of k12_feed_only_entities.csv (since 2026-11-16; a
# vector here before), which also holds their map position and page: they
# aren't scrape targets, so they aren't in k12_district_registry.csv.
read_feed_only_entities <- function() {
  path <- if (file.exists("k12_feed_only_entities.csv")) "k12_feed_only_entities.csv" else here::here("k12_feed_only_entities.csv")
  utils::read.csv(path, stringsAsFactors = FALSE)
}
WSBA_ONLY_ORGS <- read_feed_only_entities()$District

# The map's fixed columns for every K-12 entity in salarymap2.csv: from
# k12_district_registry.csv for the scrape targets (one registry schema,
# 2026-11-16; MT's salarymap2 has always taken them from its registry) and
# from k12_feed_only_entities.csv for the WSBA-only orgs. Until 2026-11-16
# they were typed into salarymap2.csv, and 10 districts' Job_Link had fallen
# behind the board they're scraped from.
K12_STATIC_COLUMNS <- c("NCES_LEAID", "County", "Latitude", "Longitude", "Job_Link")
k12_static_columns <- function(registry = read_k12_registry(), feed_only = read_feed_only_entities()) {
  cols <- c("District", K12_STATIC_COLUMNS)
  out <- rbind(registry[, cols], feed_only[, cols])
  stopifnot(!anyDuplicated(out$District))
  # A 7-digit NCES id, numeric as salarymap2.csv has always stored it (blank = NA).
  out$NCES_LEAID <- suppressWarnings(as.integer(out$NCES_LEAID))
  out
}
# Overwrites salarymap2's fixed columns from `static`, keeping its rows' order
# and every other column; an entity in `static` with no salarymap2 row yet is
# added (its data columns NA until their steps fill them), and a salarymap2
# row with no entity is dropped (as MT's right join does).
refresh_k12_static_columns <- function(salarymap2, static = k12_static_columns()) {
  salarymap2 <- salarymap2[salarymap2$District %in% static$District, , drop = FALSE]
  new <- setdiff(static$District, salarymap2$District)
  if (length(new) > 0) salarymap2 <- dplyr::bind_rows(salarymap2, data.frame(District = new, stringsAsFactors = FALSE))
  i <- match(salarymap2$District, static$District)
  for (col in K12_STATIC_COLUMNS) salarymap2[[col]] <- static[[col]][i]
  rownames(salarymap2) <- NULL
  salarymap2
}

# District-level data-completeness classification -- used by app.R to show
# a real, visible badge on any district whose current-openings count is
# measurably less complete than a platform-scraped district's, rather than
# leaving that fact sitting only in this file's comments where an end user
# viewing the dashboard has no way to see it.
#
# "Partial (WSBA + own page)": misc_district_registry's 10 districts --
# WSBA (confirmed ~25-40% of real postings on its own) plus a heuristic
# own-page scrape, deduplicated. Still meaningfully less complete than a
# real structured job-board platform.
# "Partial (WSBA only)": WSBA_ONLY_ORGS -- no own-page scraper exists at
# all, so this is WSBA's ~25-40% coverage with nothing to supplement it.
# Every other district (not returned here) is scraped from a genuine
# structured platform and is implicitly "Full" -- callers coalesce a
# missing match to that, rather than this function needing to enumerate
# every fully-covered district too.
misc_district_coverage_tiers <- function() {
  data.frame(
    District = c(misc_district_registry$District, WSBA_ONLY_ORGS),
    Data_Coverage = c(
      rep("Partial (WSBA + own page)", nrow(misc_district_registry)),
      rep("Partial (WSBA only)", length(WSBA_ONLY_ORGS))
    ),
    stringsAsFactors = FALSE
  )
}

# Full pipeline: every WSBA statewide row (one fetch) + each miscellaneous
# district's own page (deduplicated against that district's WSBA entries by
# normalized title), combined into one data frame matching the schema the
# rest of the K-12 pipeline expects (title/date_posted/position/location/
# url/District). The final K-12 merge removes exact WSBA/direct-platform
# overlaps, after direct feeds' dates have been standardized.
# `position` is intentionally NA throughout -- combinedclean's
# classify_k12_position() recomputes it from `title` for every source
# regardless, same as every other K-12 loader.
#
# safe_scrape (from scrape_helpers.R) logs each source individually: WSBA
# once, then each of the 12 districts' own-page fetch, so one district's
# selector breaking is visible in scrape_log.csv without blocking the
# other 11 or the WSBA fetch itself.
#
# chromote_session_factory: a zero-arg function returning a fresh
# chromote session (e.g. \() chromote::ChromoteSession$new()); the stage
# opens one per browser-read district and closes it. Injected, so the
# function stays testable without a browser (NULL: no session).
WSBA_VACANCIES_URL <- "https://www.wsba-wy.org/vacancies"

fetch_all_misc_district_postings <- function(chromote_session_factory = NULL) {
  wsba <- safe_scrape(
    "WSBA statewide vacancies",
    scrape_fn = fetch_wsba_vacancies,
    expected_cols = c("Title", "District", "Location", "Posted_Date", "Url")
  )

  # Each site's own postings, one frame per district in registry order, read by its scraper_spec()
  # (state_config.R; edjobs's defaults for the family platforms), the call the live check and
  # scripts/repro_scraper.R make.
  own_by_district <- scrape_registry_platforms(
    misc_district_rows(), NULL, source = "k12_district_registry.csv", shape = "raw",
    session_factory = if (is.null(chromote_session_factory)) function() NULL else chromote_session_factory)

  all_rows <- list()

  for (i in seq_len(nrow(misc_district_registry))) {
    district <- misc_district_registry$District[i]
    platform <- misc_district_registry$Platform[i]
    url <- misc_district_registry$Job_Link[i]

    own_postings <- dedupe_against_wsba(own_by_district[[district]], wsba, district)

    wsba_here <- wsba[wsba$District == district, , drop = FALSE]

    wsba_urls <- if ("Url" %in% names(wsba_here) && nrow(wsba_here) > 0) {
      ifelse(!is.na(wsba_here$Url) & nzchar(wsba_here$Url), wsba_here$Url, WSBA_VACANCIES_URL)
    } else {
      rep(WSBA_VACANCIES_URL, nrow(wsba_here))
    }

    own_urls <- if ("Link" %in% names(own_postings) && nrow(own_postings) > 0) {
      ifelse(!is.na(own_postings$Link) & nzchar(own_postings$Link), own_postings$Link, url)
    } else {
      rep(url, nrow(own_postings))
    }

    combined <- dplyr::bind_rows(
      if (nrow(wsba_here) > 0) data.frame(title = wsba_here$Title, date_posted = wsba_here$Posted_Date, url = wsba_urls,
                                          Posting_Source = WSBA_POSTING_SOURCE, stringsAsFactors = FALSE),
      # The pay the page states for a posting, when its reader returns any (2026-11-25; dropped here until then).
      if (nrow(own_postings) > 0) data.frame(title = own_postings$Title, date_posted = own_postings$Posted_Date, url = own_urls,
                                             Posting_Source = k12_posting_source_label(platform),
                                             ensure_posted_pay_columns(own_postings)[c("Pay_Min", "Pay_Max", "Pay_Unit", "Pay_Text")],
                                             stringsAsFactors = FALSE)
    )

    if (nrow(combined) > 0) {
      combined$position <- NA_character_
      combined$location <- NA_character_
      combined$District <- district
      all_rows[[length(all_rows) + 1]] <- combined
    }
  }

  # WSBA-only orgs (see WSBA_ONLY_ORGS's comment) -- no own-page scrape or
  # dedup needed, just WSBA's rows for that org name passed straight
  # through, same shape as every other district's combined rows above.
  for (org in WSBA_ONLY_ORGS) {
    wsba_here <- wsba[wsba$District == org, , drop = FALSE]
    if (nrow(wsba_here) > 0) {
      org_urls <- if ("Url" %in% names(wsba_here)) {
        ifelse(!is.na(wsba_here$Url) & nzchar(wsba_here$Url), wsba_here$Url, WSBA_VACANCIES_URL)
      } else {
        rep(WSBA_VACANCIES_URL, nrow(wsba_here))
      }
      all_rows[[length(all_rows) + 1]] <- data.frame(
        title = wsba_here$Title, date_posted = wsba_here$Posted_Date,
        position = NA_character_, location = wsba_here$Location,
        url = org_urls, District = org, Posting_Source = WSBA_POSTING_SOURCE,
        stringsAsFactors = FALSE
      )
    }
  }

  # The direct-platform districts were previously excluded here even though
  # WSBA had already provided their rows. Keep those statewide listings;
  # exact overlaps are removed against the direct feeds in Wy_ED_Jobs.Rmd.
  represented_orgs <- c(misc_district_registry$District, WSBA_ONLY_ORGS)
  wsba_remaining <- wsba[!wsba$District %in% represented_orgs, , drop = FALSE]
  if (nrow(wsba_remaining) > 0) {
    rem_urls <- if ("Url" %in% names(wsba_remaining)) {
      ifelse(!is.na(wsba_remaining$Url) & nzchar(wsba_remaining$Url), wsba_remaining$Url, WSBA_VACANCIES_URL)
    } else {
      rep(WSBA_VACANCIES_URL, nrow(wsba_remaining))
    }
    all_rows[[length(all_rows) + 1]] <- data.frame(
      title = wsba_remaining$Title,
      date_posted = wsba_remaining$Posted_Date,
      position = NA_character_,
      location = wsba_remaining$Location,
      url = rem_urls,
      District = wsba_remaining$District,
      Posting_Source = WSBA_POSTING_SOURCE,
      stringsAsFactors = FALSE
    )
  }

  if (length(all_rows) == 0) {
    return(ensure_posted_pay_columns(data.frame(
      title = character(0), date_posted = character(0), position = character(0),
      location = character(0), url = character(0), District = character(0),
      Posting_Source = character(0), stringsAsFactors = FALSE)))
  }

  result <- dplyr::bind_rows(all_rows)
  ensure_posted_pay_columns(result)[, c("title", "date_posted", "position", "location", "url", "District", "Posting_Source",
                                        "Pay_Min", "Pay_Max", "Pay_Unit", "Pay_Text")]
}

# WSBA identifies a posting by district, title, and usually a posted date.
# Remove a WSBA row only when all three fields exactly match a direct-board
# row. Missing dates deliberately prevent a match: retaining an uncertain
# duplicate is safer than dropping a real vacancy.
wsba_posting_key <- function(postings) {
  title <- normalize_title(postings$title)
  district <- normalize_title(canonicalize_wsba_district(postings$District))
  posted_date <- trimws(as.character(postings$date_posted))
  valid <- !is.na(title) & nzchar(title) &
    !is.na(district) & nzchar(district) &
    !is.na(postings$date_posted) & nzchar(posted_date)
  key <- rep(NA_character_, nrow(postings))
  key[valid] <- paste(district[valid], title[valid], posted_date[valid], sep = "\r")
  key
}

generate_wsba_discrepancy_report <- function(wsba_postings, direct_postings) {
  empty <- data.frame(
    District = character(0),
    Source = character(0),
    Title = character(0),
    Date_Posted = character(0),
    Location = character(0),
    URL = character(0),
    Discrepancy_Type = character(0),
    Detected_Date = character(0),
    stringsAsFactors = FALSE
  )
  if (nrow(wsba_postings) == 0) return(empty)

  required <- c("title", "date_posted", "District")
  missing_wsba <- setdiff(required, names(wsba_postings))
  missing_direct <- setdiff(required, names(direct_postings))
  if (length(missing_wsba) > 0 || length(missing_direct) > 0) {
    stop(
      "Cannot generate discrepancy report; missing columns: ",
      paste(c(missing_wsba, missing_direct), collapse = ", "),
      call. = FALSE
    )
  }

  direct_keys <- wsba_posting_key(direct_postings)
  direct_keys <- direct_keys[!is.na(direct_keys)]

  wsba_keys <- wsba_posting_key(wsba_postings)
  is_dup <- wsba_duplicates_direct(wsba_postings, direct_postings, wsba_keys, direct_keys)
  survived_wsba <- wsba_postings[!is_dup, , drop = FALSE]
  if (nrow(survived_wsba) == 0) return(empty)

  # Check which survived rows belong to districts that have an active direct scraper
  direct_districts <- unique(canonicalize_wsba_district(direct_postings$District))
  survived_canon <- canonicalize_wsba_district(survived_wsba$District)
  is_discrepancy <- survived_canon %in% direct_districts
  discrepancies <- survived_wsba[is_discrepancy, , drop = FALSE]
  if (nrow(discrepancies) == 0) return(empty)

  parse_discrepancy_date <- function(dp) {
    if (inherits(dp, "Date")) return(dp)
    if (is.na(dp) || !nzchar(trimws(as.character(dp)))) return(as.Date(NA))
    d <- tryCatch(as.Date(as.character(dp)), error = function(e) NA)
    if (!is.na(d)) return(d)
    tryCatch(as.Date(as.character(dp), format = "%m/%d/%Y"), error = function(e) NA)
  }

  # Categorize discrepancy
  reasons <- vapply(seq_len(nrow(discrepancies)), function(i) {
    dp <- discrepancies$date_posted[i]
    parsed_date <- parse_discrepancy_date(dp)
    if (is.na(parsed_date)) {
      return("Unmatched on direct scraper (no date)")
    }
    if (parsed_date < (Sys.Date() - 60)) {
      return(paste0("Potential ghost posting on WSBA (stale date: ", dp, ")"))
    }
    "Unmatched on direct scraper (investigate ATS drift or unlisted posting)"
  }, character(1))

  loc <- if ("location" %in% names(discrepancies)) discrepancies$location else rep(NA_character_, nrow(discrepancies))
  u <- if ("url" %in% names(discrepancies)) discrepancies$url else rep(NA_character_, nrow(discrepancies))

  data.frame(
    District = canonicalize_wsba_district(discrepancies$District),
    Source = "WSBA",
    Title = as.character(discrepancies$title),
    Date_Posted = as.character(discrepancies$date_posted),
    Location = as.character(loc),
    URL = as.character(u),
    Discrepancy_Type = reasons,
    Detected_Date = as.character(Sys.Date()),
    stringsAsFactors = FALSE
  )
}

# The other side of wsba_duplicates_direct(): TRUE for each direct posting
# that a WSBA row duplicates (same district, title and posted date, or a WSBA
# link naming the posting's own job ID). The WSBA row is dropped and the
# posting counts once, from the district's board; this flag keeps the fact
# that WSBA lists it too (Also_On_Feed).
direct_also_on_wsba <- function(direct_postings, wsba_postings) {
  if (nrow(direct_postings) == 0) return(logical(0))
  if (nrow(wsba_postings) == 0) return(rep(FALSE, nrow(direct_postings)))
  wsba_keys <- stats::na.omit(wsba_posting_key(wsba_postings))
  direct_keys <- wsba_posting_key(direct_postings)
  by_key <- !is.na(direct_keys) & direct_keys %in% wsba_keys
  wsba_ids <- if ("url" %in% names(wsba_postings)) stats::na.omit(unique(k12_link_posting_id(wsba_postings$url))) else character(0)
  link_id <- k12_link_posting_id(direct_postings$url)
  source_id <- if ("posting_id" %in% names(direct_postings)) k12_source_posting_id(direct_postings$posting_id) else rep(NA_character_, nrow(direct_postings))
  by_id <- (!is.na(link_id) & link_id %in% wsba_ids) | (!is.na(source_id) & source_id %in% wsba_ids)
  by_key | by_id
}

remove_wsba_direct_duplicates <- function(wsba_postings, direct_postings, report_path = NULL) {
  required <- c("title", "date_posted", "District")
  missing_wsba <- setdiff(required, names(wsba_postings))
  missing_direct <- setdiff(required, names(direct_postings))
  if (length(missing_wsba) > 0 || length(missing_direct) > 0) {
    stop(
      "Cannot deduplicate WSBA postings; missing columns: ",
      paste(c(missing_wsba, missing_direct), collapse = ", "),
      call. = FALSE
    )
  }

  if (!is.null(report_path)) {
    rep <- generate_wsba_discrepancy_report(wsba_postings, direct_postings)
    write.csv(rep, report_path, row.names = FALSE)
  }

  direct_keys <- wsba_posting_key(direct_postings)
  direct_keys <- direct_keys[!is.na(direct_keys)]
  if (nrow(wsba_postings) == 0 || length(direct_keys) == 0) return(wsba_postings)

  wsba_keys <- wsba_posting_key(wsba_postings)
  wsba_postings[!wsba_duplicates_direct(wsba_postings, direct_postings, wsba_keys, direct_keys), , drop = FALSE]
}

# Stale board ads (edjobs flag_stale_board_postings(); Mike, 2026-11-24). One
# run's direct board rows and the "other" rows (district websites and WSBA,
# is_wsba marking WSBA's): board rows dated before the July 1 that began the
# previous school year get a Stale_Reason (pools and ongoing roles excepted);
# WSBA rows are the feed, not judged by dates, but a WSBA row that is the same
# ad as a flagged board posting (wsba_duplicates_direct(): its link names the
# posting's job, or the same district, title and posted date) is split off as
# wsba_stale with STALE_FEED_LINK_REASON, so it neither counts nor is checked
# against its page (which would find the old ad still listed). Returns
# list(direct, other, wsba_keep, wsba_stale): wsba_keep goes on to
# remove_wsba_direct_duplicates() against the unflagged direct rows.
flag_stale_k12_rows <- function(direct, other, is_wsba, run_date) {
  direct <- flag_stale_board_postings(direct, run_date)
  other <- flag_stale_board_postings(other, run_date, board = !is_wsba)
  stale_direct <- direct[is_stale_flagged(direct$Stale_Reason), , drop = FALSE]
  wsba <- other[is_wsba, , drop = FALSE]
  same <- if (nrow(stale_direct) > 0 && nrow(wsba) > 0) wsba_duplicates_direct(wsba, stale_direct) else rep(FALSE, nrow(wsba))
  list(direct = direct, other = other, wsba_keep = wsba[!same, , drop = FALSE],
       wsba_stale = mark_stale_feed_rows(wsba[same, , drop = FALSE], TRUE))
}

# A WSBA row duplicates a direct posting when its district, title and posted
# date match one (wsba_posting_key()), or when its link names a job ID the
# district's own board lists this run, whatever the wording or date: WSBA
# lists Park #6's AppliTrack job 1026 as "Middle School ASD Special Education
# Teacher" (posted 2026-03-27) while the board calls it "ASD Special
# Education Teacher"; 22 of the 63 WSBA rows kept on 2026-11-05 were such
# duplicates, each counted twice.
wsba_duplicates_direct <- function(wsba_postings, direct_postings,
                                   wsba_keys = wsba_posting_key(wsba_postings),
                                   direct_keys = stats::na.omit(wsba_posting_key(direct_postings))) {
  by_key <- !is.na(wsba_keys) & wsba_keys %in% direct_keys
  direct_ids <- stats::na.omit(unique(c(
    k12_link_posting_id(direct_postings$url),
    if ("posting_id" %in% names(direct_postings)) k12_source_posting_id(direct_postings$posting_id))))
  wsba_ids <- if ("url" %in% names(wsba_postings)) k12_link_posting_id(wsba_postings$url) else rep(NA_character_, nrow(wsba_postings))
  by_id <- !is.na(wsba_ids) & wsba_ids %in% direct_ids
  by_key | by_id
}
