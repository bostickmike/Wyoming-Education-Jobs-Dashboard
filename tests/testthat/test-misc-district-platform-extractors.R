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
# Edlio: Washakie County SD2 and Weston County SD1 on the edjobs family
# routine (since edjobs 0.24.0), with their registry list rules; Uinta 4 on
# WY's own tab reader below
# ---------------------------------------------------------------------------

misc_rule <- function(district, col) misc_district_registry[[col]][misc_district_registry$District == district]
family_edlio <- function(fixture, district) {
  parse_edlio_postings(read_fixture(fixture), "https://example.org", NA_character_,
                       misc_rule(district, "List_Start"), misc_rule(district, "List_Stop"))
}

test_that("the Edlio family reads Washakie 2's prose-with-colon titles", {
  result <- family_edlio("edlio_washakie2.html", "Washakie County School District 2")
  expect_equal(result$Title, c("K-12 Music Teacher 2026-27 School Year", "High School Girls Basketball Coach"))
})

test_that("the Edlio family reads Weston 1's Open Positions files only, job-description file names as the job", {
  # Weston 1's page has 3 file lists: "Open Positions", application forms and
  # salary schedules; the list rules keep the first. A posting linked as its
  # job description ("Speech Language Pathologist Job Description") keeps the job.
  result <- family_edlio("edlio_weston1.html", "Weston County School District 1")
  expect_equal(nrow(result), 16)
  expect_true(all(c("Business Manager Position", "Route Bus Drivers", "Speech Language Pathologist",
                    "Music Teacher K12", "Assistant Boys Soccer Coach") %in% result$Title))
  expect_false(any(grepl("Application|Salary Schedule|Employee Benefits|Principal", result$Title)))
  expect_true(all(grepl("^https://[0-9]\\.files\\.edl\\.io/", result$Link)))
})

test_that("parse_wy_edlio_postings extracts scrollingTabs br-separated titles across all 3 category tabs (Uinta 4's real page)", {
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
  result <- parse_wy_edlio_postings(html)

  expect_equal(nrow(result), 13)
  expect_true("K-12 Special Education Teacher" %in% result$Title)  # Certified, first line
  expect_true("SPED Consultant Case Manager (part-time)" %in% result$Title)  # Certified, last line
  expect_true("School Bus Route Driver" %in% result$Title)  # Classified, first line
  expect_true("Bus Assistant" %in% result$Title)  # Classified, last line
})

test_that("parse_wy_edlio_postings extracts <li>-based Coaching-tab postings alongside a sibling tab's <br>-based ones", {
  # Regression: found 2026-09-04 re-checking Uinta 4's Partial-tier
  # coverage live -- the Coaching tab on this same fixture has ZERO <br>
  # tags at all (postings are <li> items inside <ul> lists, with
  # "High School"/"Middle School" category sub-headers as separate <p>
  # tags outside any <li>), so the <br>-only extraction above previously
  # treated the whole tab -- headers, postings, trailing prose -- as one
  # un-splittable blob that failed the length filter and silently
  # vanished: 8 real coaching postings, missing with no error and no
  # visible signal (fetch_wy_edlio_postings() still returned a non-empty,
  # plausible-looking result from the other two tabs). The Classified
  # tab's OWN "Classified Job Application"/"Bus Driver Job Application"
  # links are ALSO <li> items in a separate <ul> further down that same
  # tab -- confirms real <br> postings and an unrelated <li> list can
  # coexist in one tab, and that the shared "application" filter (not an
  # either/or choice of which shape to look for) is what correctly keeps
  # the real Classified <br> titles while dropping those two links.
  html <- read_fixture("edlio_uinta4_tabs.html")
  result <- parse_wy_edlio_postings(html)

  expect_true(all(c(
    "HS Varsity Wrestling", "HS Assistant Boys Basketball (Freshman)",
    "Assistant Football", "Assistant Volleyball (pending participation numbers)",
    "Assistant 8th Girls Basketball", "Head 7th Girls Basketball",
    "Head and Assistant 7th Boys Basketball", "Head and Assistant Girls Wrestling"
  ) %in% result$Title))
  expect_false(any(grepl("Application", result$Title, ignore.case = TRUE)))
  # Category sub-headers are <p> tags outside any <li> -- must not leak in
  # as if they were postings themselves.
  expect_false(any(result$Title %in% c("High School", "Middle School")))
})

test_that("parse_wy_edlio_postings returns zero rows (not an error) for a page with no matching content", {
  result <- parse_wy_edlio_postings("<html><body><p>nothing here</p></body></html>")
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
# Google Sites (Uinta County SD6)
# ---------------------------------------------------------------------------

test_that("parse_wy_googlesites_postings extracts both numbered-title patterns from a real rendered page", {
  # Plain rendered text (document.body.innerText), not raw HTML -- the page
  # itself only ever contains real posting text once JS-rendered (confirmed
  # live 2026-09-04: a plain fetch of this same page has none of the
  # posting text below at all), so parse_wy_googlesites_postings() takes
  # already-rendered text the same way the Apptegy routine and
  # parse_prairieview_postings() do, not HTML it parses itself.
  rendered <- read_fixture("googlesites_uinta6_rendered.txt")
  result <- parse_wy_googlesites_postings(rendered)

  expect_equal(nrow(result), 5)
  expect_setequal(result$Title, c(
    "High School Boys Assistant Swim Coach",  # title-before-district pattern
    "HS Musical Assistant Director",          # title-after-district pattern
    "maintenance position",
    "substitute school bus drivers",
    "substitute school bus aides"
  ))
  # The pay each numbered line states (2026-11-25).
  pay <- setNames(result$Pay_Min, result$Title)
  expect_equal(unname(pay[c("substitute school bus drivers", "substitute school bus aides")]), c(20.59, 16.97))
  expect_equal(sum(is.na(result$Pay_Min)), 3)
})

test_that("parse_wy_googlesites_postings returns zero rows (not an error) when no numbered posting pattern is present", {
  result <- parse_wy_googlesites_postings("Contact us for openings.")
  expect_equal(nrow(result), 0)
  expect_equal(names(result), c("Title", "Location", "Posted_Date", "Link"))
})

# ---------------------------------------------------------------------------
# Apptegy: Niobrara County SD1, Sheridan County SD3, Weston County SD7 on the
# edjobs family routine (since edjobs 0.24.0); Platte 2's fixture is kept as
# another real Apptegy page (Platte 2 is not in the registry)
# ---------------------------------------------------------------------------

family_apptegy <- function(fixture, district = NA) {
  rule <- function(col) if (is.na(district)) NA else misc_rule(district, col)
  parse_apptegy_postings(read_fixture(fixture), "https://example.org", NA_character_, "text",
                         rule("List_Start"), rule("List_Stop"), rule("List_Skip"))$Title
}

test_that("the Apptegy family reads Niobrara 1: colon and dash formats, contacts left out", {
  # WY's old parser's regressions, still covered: a non-breaking space after
  # "Elementary Teacher:", the "Business Manager: <name>" contact line, and
  # dash titles with no description ("BUS DRIVER SUBSTITUTES- District Wide").
  expect_equal(family_apptegy("apptegy_niobrara_rendered.txt"), c(
    "Elementary Teacher", "Music/Band Teacher", "Central Office Administrative Assistant", "Technology Support Staff",
    "SPED Paraprofessional", "Library/Media Support Staff", "BUS DRIVER SUBSTITUTES", "CUSTODIAL SUBSTITUTE"))
})

test_that("the Apptegy family reads Platte 2's 'Title $NNN/day' lines", {
  expect_equal(family_apptegy("apptegy_platte2_rendered.txt"), c("Substitute Certified Teachers", "Substitute Paraeducator"))
})

test_that("the Apptegy family reads Weston 7's flat lists, skipping the repeated 'Subs Needed' block", {
  # The substitute list is kept (Mike's 11-13 rule). The "Subs Needed" block
  # below it is the same substitute pool again in prose, plus its own heading:
  # read, it counted the pool twice (5 extra rows in the 11-14 rehearsal). The
  # registry's List_Skip drops that block; the posting below it still reads.
  expect_equal(family_apptegy("apptegy_weston7_rendered.txt", "Weston County School District 7"), c(
    "Substitute Teacher", "Substitute Paraprofessional", "Substitute Custodian",
    "Substitute Bus Driver (CDL preferred but willing to train)", "Substitute Lunchroom Cook",
    "Paraprofessional - Technology Aide"))
  # Without the rule the block's lines come through (what List_Skip guards).
  expect_true("Subs Needed" %in% family_apptegy("apptegy_weston7_rendered.txt"))
})

test_that("the Apptegy family reads Sheridan 3's bare titles after its form links", {
  expect_equal(family_apptegy("apptegy_sheridan3_rendered.txt"),
               c("JH Assistant Basketball Coaches", "Substitute Custodial Positions"))
})

# ---------------------------------------------------------------------------
# Educational Networks / "EN CMS" (Cheyenne Classical Academy, Wyoming
# Classical Academy)
# ---------------------------------------------------------------------------

test_that("parse_educational_networks_postings extracts real titles and excludes filled/empty cells (Cheyenne Classical's real page)", {
  # Regression x3, all against this one real fixture:
  # 1. A trailing " NEW" tag on the title's own line ("Paraeducator NEW")
  #    must be stripped, not kept as part of the title.
  # 2. "(All Positions Filled)" appears both on the title's own line
  #    ("6th Grade Teacher (All Positions Filled)") and on its own
  #    separate line two rows later ("K-7 Latin Teacher" / next line
  #    "(All Positions Filled)") -- both must be excluded regardless of
  #    which line the marker lands on.
  # 3. A stray cell containing nothing but an "Apply Now" button (no
  #    descriptive text at all) must not surface as a fake posting titled
  #    "Apply Now" -- the real bug caught by this fixture during
  #    development, via nzchar(NA_character_) being TRUE in R.
  html <- read_fixture("educational_networks_cheyenne_classical.html")
  result <- parse_educational_networks_postings(html)

  expect_equal(nrow(result), 3)
  expect_equal(sort(result$Title), sort(c("Paraeducator", "IT Support Technician", "Substitute Teacher Positions")))
  expect_false(any(grepl("Filled", result$Title)))
  expect_false("Apply Now" %in% result$Title)
  expect_false(any(c("Instructional Coach", "Art Teacher", "K–7 Latin Teacher", "6th Grade Teacher",
                      "Long-Term Substitute Teacher") %in% result$Title))
  # The pay each posting's own cell states (2026-11-25); filled positions' amounts go with them.
  expect_equal(result$Pay_Min, c(18.9, 18, NA))
  expect_equal(result$Pay_Max, c(18.9, 22, NA))
  expect_equal(result$Pay_Unit, c("hour", "hour", NA))
})

test_that("parse_educational_networks_postings extracts real titles from a differently-formatted table on the same platform (Wyoming Classical's real page)", {
  # Same CMS platform as Cheyenne Classical, but its cells are formatted
  # completely differently (no bold title span, title and the "VIEW JOB
  # POSTING" link text sometimes concatenated with no separator at all --
  # e.g. "Grades K-2 Classroom TeacherVIEW JOB POSTING") -- confirms the
  # extraction isn't accidentally over-fit to one school's specific markup.
  html <- read_fixture("educational_networks_wyoming_classical.html")
  result <- parse_educational_networks_postings(html)

  expect_equal(nrow(result), 19)
  expect_true("Grades K-2 Classroom Teacher" %in% result$Title)
  expect_true("Custodian" %in% result$Title)
  expect_false(any(grepl("VIEW JOB POSTING", result$Title, ignore.case = TRUE)))
})

test_that("parse_educational_networks_postings returns zero rows (not an error) for a page with no matching table", {
  result <- parse_educational_networks_postings("<html><body><p>Not this platform</p></body></html>")
  expect_equal(nrow(result), 0)
  expect_equal(names(result), c("Title", "Location", "Posted_Date", "Link"))
})

# ---------------------------------------------------------------------------
# Prairie View Community School
# ---------------------------------------------------------------------------

test_that("parse_prairieview_postings scopes to headings strictly between Open Positions and Application Process (real captured headings)", {
  # Regression: the page's OWN marketing headings ("Why Work With Us",
  # "Mission-Driven Work", "Small, Collaborative Team", "Professional
  # Growth", "Work-Life Balance", all before "Open Positions") and its
  # application-process sub-steps ("Review the Job Description", "Submit
  # Your Application", "Interview & Background Check", all after
  # "Application Process") must NOT be mistaken for job titles -- this
  # fixture is the real heading list captured live from the rendered page
  # on 2026-08-06, in real page order.
  headings_json <- read_fixture("prairieview_headings.json")
  result <- parse_prairieview_postings(headings_json)

  expect_equal(nrow(result), 4)
  expect_equal(result$Title, c("Custodian / Maintenance", "Paraprofessional", "Substitute Teacher", "Bus Driver"))
  expect_false(any(grepl("Why Work|Mission-Driven|Review the Job|Application Process", result$Title)))
})

test_that("parse_prairieview_postings returns zero rows (not an error) when neither section heading is present", {
  result <- parse_prairieview_postings('["Home","About","Contact"]')
  expect_equal(nrow(result), 0)
  expect_equal(names(result), c("Title", "Location", "Posted_Date", "Link"))
})

test_that("parse_prairieview_postings returns zero rows when Open Positions has no headings before Application Process", {
  result <- parse_prairieview_postings('["Employment","Open Positions","Application Process","Contact"]')
  expect_equal(nrow(result), 0)
})
