# Deterministic tests for the LLM-extraction guardrails. The one
# non-deterministic piece -- llm_extract_call(), the actual model request --
# is NOT exercised here: these feed a hand-written model response (the shape
# llm_extract_call() returns) plus a REAL captured page-text fixture through
# parse_llm_extracted_postings() and the helpers it uses, so the anti-
# hallucination / plausibility / boilerplate logic is fully covered without
# a network call or an API token.
#
# Ported verbatim from the Montana dashboard -- the guardrails are
# state-agnostic, so the fixture is still Montana's.
# Fixture: tests/testthat/fixtures/llm_extract_prose_page.txt is a verbatim
# copy of a real rendered Ennis Schools (Montana) employment page (same capture as
# apptegy_ennis_rendered.txt) -- free-text prose listing Assistant Cook,
# Custodian, and three coaching positions, with "CERTIFIED POSITIONS / NONE
# AT THIS TIME" and two "... Job Application" boilerplate links.

PAGE <- paste(
  readLines(test_path("fixtures", "llm_extract_prose_page.txt"),
            warn = FALSE, encoding = "UTF-8"),
  collapse = "\n"
)
URL <- "https://www.ennisschools.org/page/job-opportunities"

# Helper: build the {title, location, posted_date} list-of-lists shape that
# llm_extract_call() returns.
`%or%` <- function(a, b) if (is.null(a)) b else a
mk <- function(...) lapply(list(...), function(p) {
  list(title = p[["title"]] %or% "",
       location = p[["location"]] %or% "Ennis Schools",
       posted_date = p[["posted_date"]] %or% "")
})


test_that("parse_llm_extracted_postings keeps postings whose titles are really on the page", {
  postings <- mk(
    list(title = "Assistant Cook"),
    list(title = "Custodian"),
    list(title = "High School Wrestling Head Coach"),
    list(title = "Seventh Grade Volleyball")
  )
  res <- parse_llm_extracted_postings(PAGE, postings, URL, location_fallback = "Ennis Schools")

  expect_equal(nrow(res), 4)
  expect_setequal(res$Title,
                  c("Assistant Cook", "Custodian",
                    "High School Wrestling Head Coach", "Seventh Grade Volleyball"))
  expect_equal(names(res), c("Title", "Location", "Posted_Date", "Link"))
  expect_true(all(res$Link == URL))
})

test_that("a hallucinated posting -- title not on the page -- is dropped", {
  postings <- mk(
    list(title = "Assistant Cook"),                 # real
    list(title = "Elementary Music Teacher"),        # not anywhere in the fixture
    list(title = "Director of Curriculum & Instruction")  # not on the page
  )
  res <- parse_llm_extracted_postings(PAGE, postings, URL)

  expect_equal(nrow(res), 1)
  expect_equal(res$Title, "Assistant Cook")
})

test_that("boilerplate 'application' / tax-form titles are dropped even when they appear on the page", {
  # "Certified Job Application" and "Classified Job Application" are literally
  # on the fixture page -- they pass the on-page check but must be filtered
  # as non-jobs, the same way the hand-written parsers filter them.
  postings <- mk(
    list(title = "Certified Job Application"),
    list(title = "Classified Job Application"),
    list(title = "Custodian")
  )
  res <- parse_llm_extracted_postings(PAGE, postings, URL)

  expect_equal(nrow(res), 1)
  expect_equal(res$Title, "Custodian")
})

test_that("a real title that merely mentions a form is NOT treated as boilerplate", {
  # Apptegy-style compound title: the "| Classified Application | ..." suffix
  # must not cause the whole posting to be dropped.
  expect_false(llm_extract_looks_boilerplate(
    "Assistant Cook | Classified Application | 2026-2027 School Year"))
  expect_true(llm_extract_looks_boilerplate("Certified Staff Application"))
  expect_true(llm_extract_looks_boilerplate("W-4 Form"))
  expect_true(llm_extract_looks_boilerplate("Employee Handbook"))
  expect_true(llm_extract_looks_boilerplate("Non-Discrimination Policy"))
  expect_false(llm_extract_looks_boilerplate("Head Volleyball Coach"))
  expect_false(llm_extract_looks_boilerplate("Special Education Paraprofessional"))
})

test_that("an implausible posting count drops the entire result (nav menu / model loop)", {
  many <- do.call(mk, lapply(1:30, function(i) list(title = paste("Assistant Cook", i))))
  res <- parse_llm_extracted_postings(PAGE, many, URL, max_plausible = 25L)
  expect_equal(nrow(res), 0)
  expect_equal(names(res), c("Title", "Location", "Posted_Date", "Link"))
})

test_that("empty / NULL model output yields a 0-row frame, never a fabricated row", {
  expect_equal(nrow(parse_llm_extracted_postings(PAGE, NULL, URL)), 0)
  expect_equal(nrow(parse_llm_extracted_postings(PAGE, list(), URL)), 0)
  # model returned rows but all titles blank
  blank <- list(list(title = "", location = "x", posted_date = ""))
  expect_equal(nrow(parse_llm_extracted_postings(PAGE, blank, URL)), 0)
})

test_that("a posting with a parseable old posted_date is dropped as page rot", {
  postings <- list(
    list(title = "Assistant Cook", location = "Ennis Schools", posted_date = "2023-03-20"),
    list(title = "Custodian", location = "Ennis Schools", posted_date = ""),          # undated -> kept
    list(title = "High School Wrestling Head Coach", location = "Ennis Schools",
         posted_date = format(Sys.Date() - 30))                                       # recent -> kept
  )
  res <- parse_llm_extracted_postings(PAGE, postings, URL, stale_after_days = 550L)
  expect_setequal(res$Title, c("Custodian", "High School Wrestling Head Coach"))
})

test_that("posted_date normalises '' to NA and a real date passes through", {
  postings <- list(
    list(title = "Assistant Cook", location = "Ennis Schools", posted_date = ""),
    list(title = "Custodian", location = "Ennis Schools", posted_date = "2026-08-15")
  )
  res <- parse_llm_extracted_postings(PAGE, postings, URL)
  expect_true(is.na(res$Posted_Date[res$Title == "Assistant Cook"]))
  expect_equal(res$Posted_Date[res$Title == "Custodian"], "2026-08-15")
})

test_that("blank location falls back to the district name", {
  postings <- list(list(title = "Custodian", location = "", posted_date = ""))
  res <- parse_llm_extracted_postings(PAGE, postings, URL, location_fallback = "Ennis Schools")
  expect_equal(res$Location, "Ennis Schools")
})

test_that("llm_extract_title_on_page matches a leading chunk, not the whole string", {
  expect_true(llm_extract_title_on_page("Assistant Cook", PAGE))
  expect_true(llm_extract_title_on_page("High School Wrestling Head Coach", PAGE))  # first 20 chars on page
  expect_false(llm_extract_title_on_page("Assistant Groundskeeper", PAGE))
  expect_equal(
    llm_extract_title_on_page(c("Custodian", "Nonexistent Role"), PAGE),
    c(TRUE, FALSE)
  )
})

test_that("llm_extract_call returns NULL (no throw) when the token is missing", {
  expect_null(llm_extract_call("some page text", token = ""))
  expect_null(llm_extract_call("", token = "fake-key"))
})

test_that("provider config is env-overridable, defaults to Gemini", {
  withr::with_envvar(c(LLM_EXTRACT_ENDPOINT = "", LLM_EXTRACT_MODEL = "",
                       LLM_EXTRACT_KEY_ENV = ""), {
    expect_match(llm_extract_endpoint(), "generativelanguage\\.googleapis\\.com")
    expect_equal(llm_extract_model(), "gemini-3.1-flash-lite")
    expect_equal(llm_extract_key_env(), "GEMINI_API_KEY")
  })
  withr::with_envvar(c(LLM_EXTRACT_KEY_ENV = "OPENAI_API_KEY",
                       OPENAI_API_KEY = "sk-test"), {
    expect_equal(llm_extract_key_env(), "OPENAI_API_KEY")
    expect_equal(llm_extract_token(), "sk-test")
  })
})


# --- shadow-pilot orchestration -------------------------------------------

test_that("read_llm_extract_targets tolerates a missing or header-only file", {
  expect_equal(nrow(read_llm_extract_targets(tempfile(fileext = ".csv"))), 0)

  p <- withr::local_tempfile(fileext = ".csv")
  writeLines("District,Job_Link,County,Notes", p)
  expect_equal(nrow(read_llm_extract_targets(p)), 0)

  writeLines(c("District,Job_Link,County,Notes",
               "Grass Range School,https://example.org/jobs,Fergus,pilot",
               ",,,skip me"), p)
  got <- read_llm_extract_targets(p)
  expect_equal(nrow(got), 1)
  expect_equal(got$District, "Grass Range School")
})

test_that("fetch_all_llm_extracted_postings is a no-op without a chromote factory, targets, or token", {
  cols <- c("Title", "Location", "Posted_Date", "Link", "District")
  targets <- data.frame(District = "Grass Range School",
                        Job_Link = "https://example.org/jobs",
                        County = "Fergus", Notes = "", stringsAsFactors = FALSE)

  # no factory
  r1 <- fetch_all_llm_extracted_postings(NULL, targets = targets, token = "fake-key")
  expect_equal(nrow(r1), 0); expect_equal(names(r1), cols)

  # no targets
  r2 <- fetch_all_llm_extracted_postings(function() stop("should not be called"),
                                         targets = data.frame(), token = "fake-key")
  expect_equal(nrow(r2), 0)

  # no token -> skipped, logged as skipped_no_key, session never created
  log_path <- withr::local_tempfile(fileext = ".csv")
  r3 <- fetch_all_llm_extracted_postings(function() stop("should not be called"),
                                         targets = targets, token = "",
                                         log_path = log_path)
  expect_equal(nrow(r3), 0)
  logged <- read.csv(log_path, stringsAsFactors = FALSE)
  expect_true("skipped_no_key" %in% logged$status)
})
