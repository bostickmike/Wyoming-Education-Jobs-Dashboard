# Direct HTTP/API scrapers replacing RSelenium browser automation.
#
# Every institution/platform previously scraped via RSelemium + Firefox +
# geckodriver turned out to have a plain-HTTP path once actually
# investigated: a public JSON API (UW), an explicitly-published Atom feed
# (Eastern/Sheridan/Northwest, all on the same PeopleAdmin platform), an
# internal AJAX endpoint the site's own JS calls (LCCC/Casper/Central/
# Gillette/Western, all NEOGOV), a separate unprotected API host behind
# the same domain's Incapsula-protected UI (SchoolSpring), and a
# script-injection endpoint whose payload is plain embedded HTML
# (Applitrack). TedK12 already used plain rvest with no browser and needed
# no change. None of the functions below launch a browser.
#
# Each source is split into a fetch_*() function (does the HTTP call, the
# only part that needs live network) and a parse_*() function (pure logic
# on already-fetched text/JSON, testable against a static fixture with no
# network at all).

suppressMessages({
  library(httr2)
  library(jsonlite)
  library(xml2)
  library(rvest)
  library(dplyr)
})

# ---------------------------------------------------------------------------
# University of Wyoming -- Oracle Cloud HCM Recruiting REST API
# ---------------------------------------------------------------------------

# Oracle's API caps at 25 results per page regardless of the requested
# `limit`, so this pages via `offset` until it has everything
# `TotalJobsCount` says exists.
fetch_uw_postings <- function(
    api_base = "https://eeik.fa.us2.oraclecloud.com/hcmRestApi/resources/latest/recruitingCEJobRequisitions",
    ui_base = "https://eeik.fa.us2.oraclecloud.com/hcmUI/CandidateExperience/en/sites/CX_1",
    site_number = "CX_1",
    page_size = 25) {
  all_pages <- list()
  offset <- 0
  total <- NA_integer_

  repeat {
    resp <- request(api_base) %>%
      req_url_query(
        onlyData = "true",
        expand = "requisitionList",
        limit = page_size,
        offset = offset,
        finder = paste0("findReqs;siteNumber=", site_number)
      ) %>%
      req_perform()

    parsed <- resp_body_json(resp, simplifyVector = TRUE)
    item <- parsed$items[1, ]
    total <- item$TotalJobsCount

    reqs <- item$requisitionList[[1]]
    if (is.null(reqs) || nrow(reqs) == 0) break

    all_pages[[length(all_pages) + 1]] <- reqs
    offset <- offset + nrow(reqs)
    if (offset >= total) break
  }

  if (length(all_pages) == 0) {
    return(data.frame(Title = character(0), Location = character(0),
                       Posted_Date = character(0), Link = character(0),
                       stringsAsFactors = FALSE))
  }

  parse_uw_requisitions(bind_rows(all_pages), ui_base)
}

parse_uw_requisitions <- function(reqs_df, ui_base) {
  data.frame(
    Title = reqs_df$Title,
    Location = reqs_df$PrimaryLocation,
    Posted_Date = reqs_df$PostedDate,
    Link = paste0(ui_base, "/job/", reqs_df$Id),
    stringsAsFactors = FALSE
  )
}

# ---------------------------------------------------------------------------
# PeopleAdmin (Eastern Wyoming, Sheridan, Northwest) -- published Atom feed
# ---------------------------------------------------------------------------

fetch_peopleadmin_atom <- function(feed_url, location_fallback) {
  resp <- request(feed_url) %>% req_perform()
  parse_peopleadmin_atom(resp_body_string(resp), location_fallback)
}

parse_peopleadmin_atom <- function(xml_text, location_fallback) {
  doc <- xml2::read_xml(xml_text)
  ns <- c(a = "http://www.w3.org/2005/Atom")
  entries <- xml2::xml_find_all(doc, "//a:entry", ns)

  if (length(entries) == 0) {
    return(data.frame(Title = character(0), Location = character(0),
                       Posted_Date = character(0), Link = character(0),
                       stringsAsFactors = FALSE))
  }

  titles <- xml2::xml_text(xml2::xml_find_first(entries, "a:title", ns))
  links <- xml2::xml_attr(xml2::xml_find_first(entries, "a:link", ns), "href")
  published <- xml2::xml_text(xml2::xml_find_first(entries, "a:published", ns))
  posted_date <- as.Date(substr(published, 1, 10))

  data.frame(
    Title = titles,
    Location = location_fallback,
    Posted_Date = as.character(posted_date),
    Link = links,
    stringsAsFactors = FALSE
  )
}

# ---------------------------------------------------------------------------
# NEOGOV (LCCC, Casper, Central Wyoming, Gillette, Western) -- internal
# AJAX endpoint the page's own JS calls
# ---------------------------------------------------------------------------

# base_domain is e.g. "https://www.schooljobs.com" or
# "https://www.governmentjobs.com"; agency_slug is the short agency code
# from the site's own career-page URL (e.g. "cwc", "caspercollege").
# The X-Requested-With header is what makes the server return the AJAX
# job-list fragment instead of the full page shell around an empty
# container -- found by tracing the page's real network traffic with
# chromote, not by guessing.
fetch_neogov_postings <- function(base_domain, agency_slug) {
  resp <- request(paste0(base_domain, "/careers/home/index")) %>%
    req_url_query(agency = agency_slug, sort = "PositionTitle", isDescendingSort = "false") %>%
    req_headers(`X-Requested-With` = "XMLHttpRequest") %>%
    req_perform()
  parse_neogov_html(resp_body_string(resp), base_domain)
}

parse_neogov_html <- function(html_text, base_domain) {
  soup <- rvest::read_html(html_text)

  # The fragment renders each job TWICE -- once in a card/list <ul> (with
  # location/date metadata) and again in a plain desktop <table> (title
  # only, no metadata) -- both populated regardless of viewport, not
  # switched by CSS. Scoping to just the card container avoids double-
  # counting every posting and matching the table version's rows, which
  # have no location/date to extract at all.
  container <- rvest::html_elements(soup, "ul.job-listing-container")
  nodes <- rvest::html_elements(container, ".item-details-link")

  if (length(nodes) == 0) {
    return(data.frame(Title = character(0), Location = character(0),
                       Posted_Date = character(0), Link = character(0),
                       stringsAsFactors = FALSE))
  }

  titles <- rvest::html_text2(nodes)
  links <- paste0(base_domain, rvest::html_attr(nodes, "href"))

  # Location/date nodes are matched positionally within the same
  # container; pad with NA if a page's markup omits one for some rows
  # rather than erroring on a length mismatch.
  pad_to <- function(x, n) if (length(x) == n) x else rep(NA_character_, n)
  n <- length(titles)
  locations <- pad_to(rvest::html_text2(rvest::html_elements(container, ".list-meta li:nth-child(1)")), n)
  posted_dates <- pad_to(rvest::html_text2(rvest::html_elements(container, ".list-entry-starts span")), n)

  data.frame(Title = titles, Location = locations, Posted_Date = posted_dates,
             Link = links, stringsAsFactors = FALSE)
}

# ---------------------------------------------------------------------------
# SchoolSpring (K-12 districts) -- unprotected API host behind the
# Incapsula-protected UI domain
# ---------------------------------------------------------------------------

# domain_name is the district's own SchoolSpring hostname, e.g.
# "crook1.schoolspring.com" (from springer_job_links.csv's Job Link column,
# stripped of scheme/trailing slash). The interactive crook1.schoolspring.com
# site itself is Incapsula-protected, but api.schoolspring.com -- the same
# host its own React app calls -- is not.
fetch_schoolspring_postings <- function(domain_name, page_size = 50) {
  all_pages <- list()
  page <- 1
  repeat {
    resp <- request("https://api.schoolspring.com/api/Jobs/GetPagedJobsWithSearch") %>%
      req_url_query(
        domainName = domain_name, keyword = "", location = "", category = "",
        gradelevel = "", jobtype = "", organization = "",
        page = page, size = page_size, sortDateAscending = "false"
      ) %>%
      req_perform()

    page_df <- parse_schoolspring_json(resp_body_string(resp), domain_name)
    if (nrow(page_df) == 0) break

    all_pages[[length(all_pages) + 1]] <- page_df
    if (nrow(page_df) < page_size) break  # last page was partial -> no more pages
    page <- page + 1
  }

  if (length(all_pages) == 0) {
    return(data.frame(Title = character(0), Location = character(0),
                       Posted_Date = character(0), Link = character(0),
                       stringsAsFactors = FALSE))
  }
  dplyr::bind_rows(all_pages)
}

parse_schoolspring_json <- function(json_text, domain_name) {
  parsed <- jsonlite::fromJSON(json_text, simplifyVector = TRUE)
  jobs <- parsed$value$jobsList

  if (is.null(jobs) || length(jobs) == 0 || nrow(jobs) == 0) {
    return(data.frame(Title = character(0), Location = character(0),
                       Posted_Date = character(0), Link = character(0),
                       stringsAsFactors = FALSE))
  }

  data.frame(
    Title = jobs$title,
    Location = jobs$location,
    Posted_Date = substr(jobs$displayDate, 1, 10),
    Link = paste0("https://", domain_name, "/jobs/", jobs$jobId),
    stringsAsFactors = FALSE
  )
}

# ---------------------------------------------------------------------------
# RedRoverK12 (Johnson County School District 1) -- unauthenticated GraphQL
# endpoint the site's own Next.js app calls
# ---------------------------------------------------------------------------

# org_id is the numeric organization ID RedRoverK12 assigns per district
# (found by tracing the real GraphQL request body with chromote --
# Johnson County SD1's is "3146" for org slug "jcsd1"). Not derivable from
# the org slug alone; a new district on this platform would need its own
# ID looked up the same way.
fetch_redrover_postings <- function(org_id, org_slug) {
  query <- 'query GetJobPostings($search: JobPostingSearchInput!) {
  jobSeekerSiteUnauthenticated {
    jobPostingSearch(search: $search) {
      results {
        id
        name
        organizationName
        location { name }
        activePublicOnDateUtc
      }
    }
  }
}'
  resp <- request("https://api.redroverk12.com/graphql") %>%
    req_headers(`Content-Type` = "application/json") %>%
    req_body_json(list(
      operationName = "GetJobPostings",
      variables = list(search = list(orgId = org_id, searchTerm = "", locationIds = list(), jobPostingCategoryIds = list())),
      query = query
    )) %>%
    req_perform()
  parse_redrover_json(resp_body_string(resp), org_slug)
}

parse_redrover_json <- function(json_text, org_slug) {
  parsed <- jsonlite::fromJSON(json_text, simplifyVector = TRUE)
  results <- parsed$data$jobSeekerSiteUnauthenticated$jobPostingSearch$results

  if (is.null(results) || length(results) == 0 || nrow(results) == 0) {
    return(data.frame(Title = character(0), Location = character(0),
                       Posted_Date = character(0), Link = character(0),
                       stringsAsFactors = FALSE))
  }

  data.frame(
    Title = results$name,
    Location = results$location$name,
    Posted_Date = substr(results$activePublicOnDateUtc, 1, 10),
    Link = paste0("https://jobs.redroverk12.com/org/", org_slug, "/opening/", results$id),
    stringsAsFactors = FALSE
  )
}

# ---------------------------------------------------------------------------
# Applitrack (K-12 districts) -- script-injection endpoint whose payload is
# plain embedded HTML, not real JS execution
# ---------------------------------------------------------------------------

# tenant_path is everything between applitrack.com/ and /onlineapp/ in the
# district's own URL, e.g. "bighorn" for
# https://www.applitrack.com/bighorn/onlineapp/default.aspx. The listing
# markup itself (ul.postingsList, table.title td#wrapword, li span.label/
# span.normal) is unchanged from the original scraper's selectors -- what's
# different is fetching it directly from Output.asp (the endpoint
# default.aspx's own inline script injects via document.write()) instead of
# rendering default.aspx in a browser and waiting for that injection to
# happen.
fetch_applitrack_postings <- function(tenant_path) {
  resp <- request(paste0("https://www.applitrack.com/", tenant_path, "/onlineapp/jobpostings/Output.asp")) %>%
    req_url_query(all = "1") %>%
    req_perform()
  parse_applitrack_output(resp_body_string(resp))
}

parse_applitrack_output <- function(js_text) {
  # Response body is a series of document.write('<html fragment>') calls
  # with single quotes escaped as \' for JS string-literal safety; joining
  # every literal's un-escaped content reconstructs the full HTML the
  # browser would otherwise inject into the page.
  writes <- regmatches(js_text, gregexpr("document\\.write\\('(.*?)'\\);", js_text))[[1]]
  literals <- sub("^document\\.write\\('(.*)'\\);$", "\\1", writes)
  html <- paste(gsub("\\\\'", "'", literals), collapse = "")

  if (!nzchar(html)) {
    return(data.frame(title = character(0), position = character(0), position2 = character(0),
                       date_posted = character(0), location = character(0), closing_date = character(0),
                       stringsAsFactors = FALSE))
  }

  soup <- rvest::read_html(html)
  postings <- rvest::html_elements(soup, "ul.postingsList")

  if (length(postings) == 0) {
    return(data.frame(title = character(0), position = character(0), position2 = character(0),
                       date_posted = character(0), location = character(0), closing_date = character(0),
                       stringsAsFactors = FALSE))
  }

  rows <- lapply(postings, function(p) {
    title <- rvest::html_text2(rvest::html_element(p, "table.title td#wrapword"))
    labels <- rvest::html_text2(rvest::html_elements(p, "li span.label"))
    values <- rvest::html_text2(rvest::html_elements(p, "li span.normal"))

    # Mirrors the original Applitrack K-12 loop's label/value matching
    # exactly (same markup, same labels): "Position Type:" can consume TWO
    # consecutive values (category + subcategory, e.g. "Support Staff/" and
    # "Para-Educator Special Services") when the next value isn't itself
    # another label's value (heuristic: doesn't contain ":"). Getting this
    # wrong shifts every subsequent field by one position, corrupting
    # date_posted/location/closing_date even though position2 itself is
    # discarded downstream (combinedclean only keeps title/date_posted/
    # position/location/url/District).
    field <- setNames(as.list(rep(NA_character_, 5)), c("position", "position2", "date_posted", "location", "closing_date"))
    j <- 1
    for (label in labels) {
      if (label == "Position Type:") {
        field$position <- values[j]
        if (j + 1 <= length(values) && !grepl(":", values[j + 1])) {
          field$position2 <- values[j + 1]
          j <- j + 1
        }
      } else if (label == "Date Posted:") {
        field$date_posted <- values[j]
      } else if (label == "Location:") {
        field$location <- values[j]
      } else if (label == "Closing Date:") {
        field$closing_date <- values[j]
      }
      j <- j + 1
    }

    data.frame(title = title, position = field$position, position2 = field$position2,
               date_posted = field$date_posted, location = field$location,
               closing_date = field$closing_date, stringsAsFactors = FALSE)
  })

  do.call(rbind, rows)
}
