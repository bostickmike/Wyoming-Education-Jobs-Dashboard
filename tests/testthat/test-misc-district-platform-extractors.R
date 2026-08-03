# All fixtures here are real captured HTML/text from the actual 12
# districts' own pages, not synthetic approximations -- every one of these
# extractors was built against and debugged with real data, and several
# genuine bugs (attribute-name casing, non-breaking spaces, unscoped
# selectors pulling in unrelated forms/salary schedules) were only caught
# by testing against these exact fixtures. See misc_district_scrapers.R's
# header comment for the full platform-to-district mapping.

fixture_path <- function(name) test_path("fixtures", "misc_districts", name)
read_fixture <- function(name) paste(readLines(fixture_path(name), warn = FALSE, encoding = "UTF-8"), collapse = "\n")

# ---------------------------------------------------------------------------
# Edlio (Washakie County SD2, Weston County SD1)
# ---------------------------------------------------------------------------

test_that("parse_edlio_postings extracts prose-with-colon titles (Washakie 2's real page)", {
  html <- read_fixture("edlio_washakie2.html")
  result <- parse_edlio_postings(html)

  expect_equal(nrow(result), 2)
  expect_true("K-12 Music Teacher 2026-27 School Year" %in% result$Title)
  expect_true("High School Girls Basketball Coach" %in% result$Title)
})

test_that("parse_edlio_postings extracts file-list titles scoped to the Open Positions heading only (Weston 1's real page)", {
  # Regression: Weston 1's real page has 3 separate file-list widgets --
  # "Open Positions", an application-forms widget, and a salary-schedule
  # widget. An earlier version pulled titles from all 3, including
  # "WCSD Classified Application" and salary schedule PDFs alongside real
  # postings.
  html <- read_fixture("edlio_weston1.html")
  result <- parse_edlio_postings(html)

  expect_equal(nrow(result), 16)
  expect_true("Business Manager Position" %in% result$Title)
  expect_true("Route Bus Drivers" %in% result$Title)
  expect_false(any(grepl("Application|Salary Schedule|Employee Benefits", result$Title)))
})

test_that("parse_edlio_postings extracts scrollingTabs br-separated titles across all 3 category tabs (Uinta 4's real page)", {
  # Regression: a materially different Edlio page template from the other
  # two districts -- Certified/Classified/Coaching tabs, each a single
  # JSON-embedded HTML string with postings as plain <br>-separated lines
  # and no per-posting markup at all. The first line in each tab carries a
  # leading <p><font ...> prefix (precedes the first <br> rather than
  # following one) that must be stripped per-line, not just once for the
  # whole content string, or "K-12 Special Education Teacher" and "School
  # Bus Route Driver" (both first-in-tab) are silently dropped while every
  # later line in the same tab extracts fine.
  html <- read_fixture("edlio_uinta4_tabs.html")
  result <- parse_edlio_postings(html)

  expect_equal(nrow(result), 6)
  expect_true("K-12 Special Education Teacher" %in% result$Title)  # Certified, first line
  expect_true("SPED Consultant Case Manager (part-time)" %in% result$Title)  # Certified, last line
  expect_true("School Bus Route Driver" %in% result$Title)  # Classified, first line
  # Coaching tab is genuinely empty on the real page -- confirms this
  # isn't silently swallowing a real Coaching posting, not just "0 tabs
  # matched at all".
  expect_false(any(grepl("Coaching", result$Title)))
})

test_that("parse_edlio_postings returns zero rows (not an error) for a page with no matching content", {
  result <- parse_edlio_postings("<html><body><p>nothing here</p></body></html>")
  expect_equal(nrow(result), 0)
  expect_equal(names(result), c("Title", "Location", "Posted_Date", "Link"))
})

# ---------------------------------------------------------------------------
# SchoolBlocks (Sublette County SD1)
# ---------------------------------------------------------------------------

test_that("parse_schoolblocks_postings un-escapes the double-escaped embedded JSON and extracts real items", {
  # Regression: the "Current Job Announcements" widget's JSON is embedded
  # as a STRING within the page's own JS state, so the source contains
  # literal backslash-quote (\") sequences that must be un-escaped once
  # before any title/date extraction works at all.
  html <- read_fixture("schoolblocks_sublette1.html")
  result <- parse_schoolblocks_postings(html)

  expect_equal(nrow(result), 8)
  expect_true("Substitute Bus Driver" %in% result$Title)
  expect_true("2026-07-14" %in% result$Posted_Date)
})

test_that("parse_schoolblocks_postings returns zero rows (not an error) when the named widget isn't present", {
  result <- parse_schoolblocks_postings("<html>no matching widget here</html>")
  expect_equal(nrow(result), 0)
  expect_equal(names(result), c("Title", "Location", "Posted_Date", "Link"))
})

# ---------------------------------------------------------------------------
# SmartSites/ParentSquare (Park County SD16, Platte County SD1)
# ---------------------------------------------------------------------------

test_that("parse_smartsites_postings extracts document-list titles/dates and excludes application forms (Park 16's real page)", {
  # Regression: data-searchText (camelCase in the source) is lowercased by
  # the HTML parser to data-searchtext; querying the camelCase name
  # silently returns all-NA titles instead of erroring. Also regression:
  # the same document-list widget mixes blank application forms in with
  # real postings ("classified application"/"certified application"),
  # indistinguishable by markup, only by content.
  html <- read_fixture("smartsites_park16.html")
  result <- parse_smartsites_postings(html)

  expect_equal(nrow(result), 3)
  expect_true("HS Head Track Coach" %in% result$Title)
  expect_true("2026-04-28" %in% result$Posted_Date)
  expect_false(any(grepl("application", result$Title, ignore.case = TRUE)))
})

test_that("parse_smartsites_postings extracts image-alt titles when that's the only content (Platte 1's real page)", {
  # Regression: this template leaves its <a> self-closed (<a href=... />),
  # so <figure>/<img> are SIBLINGS of <a> in the parsed DOM, not
  # descendants -- the semantically "correct" `a > figure > img` selector
  # matches nothing on this real page. Also regression: application-form
  # links use the identical widget with no distinguishing heading, same
  # content-based exclusion as the document-list variant.
  html <- read_fixture("smartsites_platte1.html")
  result <- parse_smartsites_postings(html)

  expect_equal(nrow(result), 12)
  expect_true("Bus Driver" %in% result$Title)
  expect_true("WHS SPED Para" %in% result$Title)
  expect_false(any(grepl("application", result$Title, ignore.case = TRUE)))
})

test_that("parse_smartsites_postings returns zero rows (not an error) for a page with neither widget type", {
  result <- parse_smartsites_postings("<html><body>nothing</body></html>")
  expect_equal(nrow(result), 0)
  expect_equal(names(result), c("Title", "Location", "Posted_Date", "Link"))
})

# ---------------------------------------------------------------------------
# WordPress/Elementor (Lincoln County SD2)
# ---------------------------------------------------------------------------

test_that("parse_wordpress_postings captures every category after the Open Positions section, not just Classified/Certified", {
  # Regression: an earlier version whitelisted only "Classified"/
  # "Certified" by name and silently dropped the "Substitutes" and
  # "Coaching" categories entirely -- the exact same completeness gap
  # already found in WSBA (systematically missing substitute/coaching
  # postings). Also regression: naively capturing every heading on the
  # page (instead of scoping to after "Current Open Positions") pulls in
  # the page's own intro/contact-info text as if it were job titles.
  html <- read_fixture("wordpress_lincoln2.html")
  result <- parse_wordpress_postings(html)

  expect_equal(nrow(result), 17)
  expect_true("Activity Bus Driver- Star Valley" %in% result$Title)   # Classified
  expect_true("Educational Sign Language Interpreter- District Wide" %in% result$Title)  # Certified
  expect_true("Substitute Bus Aides- Star Valley" %in% result$Title)  # Substitutes
  expect_true("Volunteer Coach/Advisor" %in% result$Title)            # Coaching
  expect_false(any(grepl("close at 5:00 p.m.|non-discrimination|equal employment", result$Title, ignore.case = TRUE)))
})

test_that("parse_wordpress_postings returns zero rows (not an error) when there's no Current Open Positions section", {
  result <- parse_wordpress_postings("<html><body><h3 class='elementor-heading-title'>Something Else</h3></body></html>")
  expect_equal(nrow(result), 0)
  expect_equal(names(result), c("Title", "Location", "Posted_Date", "Link"))
})

# ---------------------------------------------------------------------------
# Google Sites (Uinta County SD6)
# ---------------------------------------------------------------------------

test_that("parse_googlesites_postings extracts the numbered-bold-title pattern from a real page", {
  html <- read_fixture("googlesites_uinta6.html")
  result <- parse_googlesites_postings(html)

  expect_equal(nrow(result), 1)
  expect_equal(result$Title, "Musical Director")
})

test_that("parse_googlesites_postings returns zero rows (not an error) when no numbered posting pattern is present", {
  result <- parse_googlesites_postings("<html><body><p>Contact us for openings.</p></body></html>")
  expect_equal(nrow(result), 0)
  expect_equal(names(result), c("Title", "Location", "Posted_Date", "Link"))
})

# ---------------------------------------------------------------------------
# Apptegy (Niobrara County SD1, Platte County SD2, Sheridan County SD3,
# Weston County SD7)
# ---------------------------------------------------------------------------

test_that("parse_apptegy_postings extracts both posting formats and excludes contact info (Niobrara 1's real rendered page)", {
  # Regression x3, all against this one real fixture:
  # 1. A non-breaking space (U+00A0) immediately after "Elementary
  #    Teacher:" is not matched by PCRE's non-Unicode \s, silently
  #    dropping that entire real posting from every downstream regex with
  #    no error.
  # 2. "Business Manager: Michelle Neuenschwander" (a contact-info line in
  #    the page's own "Additional Info" section) satisfies a naive
  #    colon-plus-long-text check and gets misidentified as a posting.
  # 3. "BUS DRIVER SUBSTITUTES- District Wide" and "CUSTODIAL SUBSTITUTE-
  #    District Wide" use a dash, not a colon, and have no description at
  #    all -- silently missed by the colon-only pattern, which would have
  #    repeated the classified/substitute-postings gap already found in
  #    WSBA.
  text <- read_fixture("apptegy_niobrara_rendered.txt")
  result <- parse_apptegy_postings(text)

  expect_equal(nrow(result), 8)
  expect_true("Elementary Teacher" %in% result$Title)
  expect_true("BUS DRIVER SUBSTITUTES" %in% result$Title)
  expect_true("CUSTODIAL SUBSTITUTE" %in% result$Title)
  expect_false(any(grepl("Business Manager", result$Title)))
})

test_that("parse_apptegy_postings extracts the dollar-rate posting format (Platte 2's real rendered page)", {
  # Regression: a third real Apptegy posting format found by checking all
  # 4 Apptegy districts' actual current pages (not just Niobrara 1) --
  # "Title $NNN/day" with neither a colon nor a dash, which the first two
  # patterns silently miss entirely.
  text <- read_fixture("apptegy_platte2_rendered.txt")
  result <- parse_apptegy_postings(text)

  expect_equal(nrow(result), 2)
  expect_true("Substitute Certified Teachers" %in% result$Title)
  expect_true("Substitute Paraeducator" %in% result$Title)
})

test_that("parse_apptegy_postings returns zero rows (not an error) for rendered text with no matching pattern", {
  result <- parse_apptegy_postings("Just some regular page text with no postings.")
  expect_equal(nrow(result), 0)
  expect_equal(names(result), c("Title", "Location", "Posted_Date", "Link"))
})
