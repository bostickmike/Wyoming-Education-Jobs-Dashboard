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
#    SchoolBlocks, SmartSites/ParentSquare, WordPress, Google Sites), none
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

empty_misc_result <- function() {
  data.frame(Title = character(0), Location = character(0),
             Posted_Date = character(0), Link = character(0),
             stringsAsFactors = FALSE)
}

# ---------------------------------------------------------------------------
# Edlio (Washakie County SD2, Weston County SD1)
# ---------------------------------------------------------------------------

# Edlio content pages mix two independent block types, and a given page can
# use either or both: a "files" block (an uploaded-document list, each
# posting is literally a PDF/image named after the job -- Weston 1's
# pattern) and a "text" block (prose with the title bolded before a colon,
# in a plain <li> -- Washakie 2's pattern). Neither carries a posted date.
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
fetch_edlio_postings <- function(url) {
  resp <- request(url) %>% req_perform()
  parse_edlio_postings(resp_body_string(resp))
}

parse_edlio_postings <- function(html_text) {
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

  titles <- c(file_titles, prose_titles)
  links <- c(file_links, rep(NA_character_, length(prose_titles)))

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
  resp <- request(url) %>% req_perform()
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
# SmartSites / ParentSquare (Park County SD16, Platte County SD1)
# ---------------------------------------------------------------------------

# Two independent content-block types, either or both may appear on a
# given page: a "document search" list (li.ss-document-item, title in
# data-searchText, posted date embedded in the link's aria-label as
# "...added YYYY-MM-DD") and an "image gallery" block (bare <img alt="...">
# with no date at all -- confirmed this is Platte County SD1's *only*
# visible posting content: the page has no readable title text outside
# these image alt attributes).
fetch_smartsites_postings <- function(url) {
  resp <- request(url) %>% req_perform()
  parse_smartsites_postings(resp_body_string(resp))
}

parse_smartsites_postings <- function(html_text) {
  soup <- rvest::read_html(html_text)

  doc_nodes <- rvest::html_elements(soup, "li.ss-document-item")
  # libxml2/rvest lowercases HTML attribute names on parse, so the source's
  # camelCase "data-searchText" must be queried as "data-searchtext".
  doc_titles_raw <- rvest::html_attr(doc_nodes, "data-searchtext")
  doc_labels_raw <- rvest::html_attr(rvest::html_elements(doc_nodes, "a.ss-document-link"), "aria-label")
  # Same document-search widget lists blank application forms alongside
  # real postings with no distinguishing markup (confirmed on Park County
  # SD16's real page: "classified application"/"certified application"
  # sit in the same list as real job titles) -- same content-based
  # exclusion as the image-gallery variant below.
  is_job <- !grepl("application", doc_titles_raw, ignore.case = TRUE)
  doc_titles <- doc_titles_raw[is_job]
  doc_labels <- doc_labels_raw[is_job]
  doc_dates <- ifelse(
    grepl("added \\d{4}-\\d{2}-\\d{2}", doc_labels),
    sub(".*added (\\d{4}-\\d{2}-\\d{2}).*", "\\1", doc_labels),
    NA_character_
  )

  # The image-gallery widget's own template leaves its <a> self-closed
  # (<a href="..." />), so the <figure>/<img> are its SIBLINGS in the
  # parsed DOM, not descendants -- "a > figure > img" (the semantically
  # "correct" selector) matches nothing on real pages using this template.
  # Both real postings and unrelated application-form links use this exact
  # same widget with no distinguishing heading or class, so the only
  # available signal is content: exclude anything whose alt text names a
  # form rather than a position (confirmed against the real page: titles
  # like "Certified Application"/"Classified Application"/"Coaching
  # Application"/"Substitute Teacher Application" are the district's
  # blank application forms, not open postings).
  img_nodes <- rvest::html_elements(soup, "li.picseries_image img[alt]")
  img_titles <- str_trim(rvest::html_attr(img_nodes, "alt"))
  img_titles <- img_titles[nzchar(img_titles) & !grepl("application", img_titles, ignore.case = TRUE)]

  titles <- c(doc_titles, img_titles)
  dates <- c(doc_dates, rep(NA_character_, length(img_titles)))

  if (length(titles) == 0) return(empty_misc_result())

  data.frame(Title = titles, Location = NA_character_, Posted_Date = dates,
             Link = NA_character_, stringsAsFactors = FALSE)
}

# ---------------------------------------------------------------------------
# WordPress/Elementor (Lincoln County SD2)
# ---------------------------------------------------------------------------

# Postings are plain <p> lines inside an Elementor text-editor widget,
# immediately preceded by a heading widget naming the category. The real
# page has 7 headings total, in document order: "Employment Opportunities"
# (page title), "Application Information" (intro/contact-info block, NOT a
# job category), "Current Open Positions" (the section boundary), then the
# 4 real job categories -- Classified, Certified, Substitutes, Coaching.
# An earlier version of this function whitelisted only "Classified"/
# "Certified" by name and silently dropped Substitutes/Coaching entirely,
# which would have repeated the exact completeness gap already found in
# WSBA (systematically missing substitute/coaching postings). Rather than
# hardcode the 4 real category names (fragile if a 5th category is added
# later) or capture every heading (wrongly pulls in the intro/contact
# text), this scopes to every heading that comes AFTER the "Current Open
# Positions" section heading in document order -- robust to new
# categories, still excludes the non-category intro content.
fetch_wordpress_postings <- function(url) {
  resp <- request(url) %>% req_perform()
  parse_wordpress_postings(resp_body_string(resp))
}

parse_wordpress_postings <- function(html_text) {
  soup <- rvest::read_html(html_text)

  heading_nodes <- rvest::html_elements(soup, ".elementor-widget-heading")
  if (length(heading_nodes) == 0) return(empty_misc_result())

  heading_texts <- str_trim(rvest::html_text2(rvest::html_elements(heading_nodes, ".elementor-heading-title")))
  section_idx <- which(heading_texts == "Current Open Positions")
  if (length(section_idx) == 0) return(empty_misc_result())

  category_nodes <- heading_nodes[(section_idx[1] + 1):length(heading_nodes)]
  if (length(category_nodes) == 0) return(empty_misc_result())

  all_titles <- character(0)
  for (heading_node in category_nodes) {
    next_widget <- rvest::html_element(heading_node, xpath = "following::div[contains(@class,'elementor-widget-text-editor')][1]")
    if (!is.na(next_widget)) {
      lines <- rvest::html_text2(rvest::html_elements(next_widget, "p"))
      all_titles <- c(all_titles, str_trim(lines[nzchar(str_trim(lines))]))
    }
  }

  if (length(all_titles) == 0) return(empty_misc_result())

  data.frame(Title = all_titles, Location = NA_character_, Posted_Date = NA_character_,
             Link = NA_character_, stringsAsFactors = FALSE)
}

# ---------------------------------------------------------------------------
# Google Sites (Uinta County SD6)
# ---------------------------------------------------------------------------

# Same underlying rendering as the WSBA page (server-rendered, text split
# across many small <span> tags), but a completely different content
# pattern: each posting is a numbered, bolded title directly followed by
# prose ("1-Musical Director Uinta County School District #6 is looking
# for..."). No structured date. Matches conservatively -- requires the
# numbered prefix -- to avoid false-matching arbitrary bold text elsewhere
# on the page.
fetch_googlesites_postings <- function(url) {
  resp <- request(url) %>% req_perform()
  parse_googlesites_postings(resp_body_string(resp))
}

parse_googlesites_postings <- function(html_text) {
  soup <- rvest::read_html(html_text)
  text <- rvest::html_text2(soup)

  matches <- regmatches(text, gregexpr("\\d+-([A-Z][A-Za-z/ ]{2,60}?)(?=\\s+[A-Z][a-z]+ County School District|\\s+is (?:looking|seeking|accepting))", text, perl = TRUE))[[1]]
  titles <- str_trim(sub("^\\d+-", "", matches))
  titles <- unique(titles[nzchar(titles)])

  if (length(titles) == 0) return(empty_misc_result())

  data.frame(Title = titles, Location = NA_character_, Posted_Date = NA_character_,
             Link = NA_character_, stringsAsFactors = FALSE)
}

# ---------------------------------------------------------------------------
# Apptegy (Niobrara County SD1, Platte County SD2, Sheridan County SD3,
# Weston County SD7) -- the one platform family that genuinely needs a
# browser
# ---------------------------------------------------------------------------

# Apptegy content pages are a client-side-rendered Nuxt app; the raw HTML
# has no posting text at all (confirmed directly -- a plain fetch returns
# an empty shell). Postings are free prose under a bolded ALL-CAPS category
# heading ("CERTIFIED POSITIONS", "CLASSIFIED POSITIONS", ...), each
# formatted as "Title: description..." -- same shape as Edlio's prose
# variant, just requiring a rendered page as input instead of raw HTML.
# fetch_apptegy_postings() takes a chromote session so callers can reuse
# one browser across all four Apptegy districts instead of paying startup
# cost per district.
fetch_apptegy_postings <- function(chromote_session, url) {
  chromote_session$Page$navigate(url)
  chromote_session$Page$loadEventFired(wait_ = TRUE, timeout_ = 30)
  Sys.sleep(5)
  text <- chromote_session$Runtime$evaluate("document.body.innerText")$result$value
  parse_apptegy_postings(text)
}

parse_apptegy_postings <- function(rendered_text) {
  # document.body.innerText preserves non-breaking spaces (U+00A0) from the
  # page's own styling, which R's \s (PCRE, non-Unicode mode) does not
  # match -- confirmed this silently dropped "Elementary Teacher" (a real
  # posting immediately followed by a non-breaking space after its colon)
  # from every regex below without erroring.
  rendered_text <- gsub("\u00a0", " ", rendered_text)
  lines <- strsplit(rendered_text, "\n")[[1]]

  # Two independent posting formats seen on real pages, both need to be
  # matched:
  #
  # 1. "Title: District Name in City, WY is accepting/seeking
  #    applications..." -- most postings. A naive colon-line match also
  #    catches the page's own "ADDITIONAL INFO" contact block ("Business
  #    Manager: Michelle Neuenschwander" is a person's name, not a job),
  #    which happens to be long enough to pass a bare length check -- real
  #    postings are distinguished by the description actually being about
  #    a posting (mentions the district applying/accepting/seeking), not
  #    just being long.
  colon_lines <- grep("^[A-Za-z][A-Za-z0-9/ '&-]+:\\s", lines, value = TRUE, perl = TRUE)
  colon_lines <- colon_lines[grepl(
    ":\\s+.*(accepting applications|is seeking|is looking for|School District)",
    colon_lines, ignore.case = TRUE
  )]
  colon_titles <- str_trim(sub("^([A-Za-z][A-Za-z0-9/ '&-]+):.*$", "\\1", colon_lines))

  # 2. "ALL-CAPS TITLE- District Wide" (or similar short location) --
  #    confirmed on Niobrara 1's real page for substitute-pool postings
  #    ("BUS DRIVER SUBSTITUTES- District Wide"), which have no
  #    description at all and would be silently missed by the colon
  #    pattern above. Restricted to ALL-CAPS titles specifically so this
  #    doesn't also match ordinary section headings, which never contain
  #    a dash.
  dash_lines <- grep("^[A-Z][A-Z /]+-\\s*.+$", lines, value = TRUE, perl = TRUE)
  dash_titles <- str_trim(sub("^([A-Z][A-Z /]+?)-\\s*.+$", "\\1", dash_lines))

  titles <- unique(c(colon_titles, dash_titles))
  titles <- titles[nzchar(titles)]

  if (length(titles) == 0) return(empty_misc_result())

  data.frame(Title = titles, Location = NA_character_, Posted_Date = NA_character_,
             Link = NA_character_, stringsAsFactors = FALSE)
}
