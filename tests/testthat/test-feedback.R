# Public Feedback form (app folder's feedback.R, 2026-11-16): the spam and validation rules, the issue text, and
# that nothing is posted without a token. No network: feedback_post() is never called here.
app_dir <- Filter(dir.exists, here::here(c("Mt_Ed_Jobs", "Wy_Ed_Jobs")))[1]
fb <- new.env()
sys.source(file.path(app_dir, "feedback.R"), envir = fb)

good <- list(type = fb$FEEDBACK_TYPES[1], district = "Bozeman Public Schools", job = "HS Science Teacher",
             details = "This job closed last week but still shows as open.", honeypot = "")
t0 <- as.POSIXct("2026-11-16 10:00:00", tz = "UTC")
check <- function(..., state = { s <- new.env(); s$times <- numeric(0); s$hashes <- character(0); s }, opened = t0 - 30,
                  now = t0, session_count = 0) {
  a <- modifyList(good, list(...))
  fb$feedback_check(a$type, a$district, a$job, a$details, a$honeypot, opened, now = now,
                    session_count = session_count, state = state)
}

test_that("a normal report passes", {
  expect_equal(check()$action, "post")
})

test_that("bot signs are dropped silently (visitor sees thanks, nothing posted)", {
  expect_equal(check(honeypot = "http://spam.example")$action, "drop")
  expect_equal(check(opened = t0 - 1)$action, "drop")                     # submitted 1 s after opening
  expect_equal(check(opened = NULL)$action, "drop")                       # never opened the form
  expect_equal(check(details = "Cheap viagra and casino bonus here")$action, "drop")
})

test_that("fixable problems are rejected with a message", {
  expect_equal(check(type = "")$action, "reject")
  expect_equal(check(district = "")$action, "reject")
  expect_equal(check(details = "bad")$action, "reject")
  expect_equal(check(details = strrep("x", 3001))$action, "reject")
  expect_equal(check(job = strrep("x", 301))$action, "reject")
  links <- paste(rep("https://example.org/a", 4), collapse = " ")
  expect_equal(check(details = paste("See", links))$action, "reject")
  expect_equal(check(details = paste("See https://a.org/1 and https://a.org/2"))$action, "post")
})

test_that("per-visit and per-hour limits, and exact repeats", {
  expect_equal(check(session_count = 3)$action, "reject")
  s <- new.env(); s$times <- rep(as.numeric(t0) - 60, 20); s$hashes <- character(0)
  expect_equal(check(state = s)$action, "reject")
  s$times <- rep(as.numeric(t0) - 4000, 20)                               # older than an hour: not counted
  expect_equal(check(state = s)$action, "post")
  fb$feedback_record(good$type, good$district, good$job, good$details, now = t0, state = s)
  expect_equal(check(state = s)$action, "drop")
  expect_equal(check(state = s, details = paste(good$details, "Also the link is broken."))$action, "post")
})

test_that("the issue text can't ping people or cross-link issues, and carries the labels", {
  iss <- fb$feedback_issue(good$type, "Hamilton <b>SD</b>", "", "Ask @someone about #12 please", "Montana", now = t0)
  expect_match(iss$title, "^\\[Data Issue\\]: Expired / Closed Job")
  expect_false(grepl("<b>", iss$title, fixed = TRUE))
  expect_false(grepl("@someone", iss$body, fixed = TRUE))
  expect_false(grepl("#12", iss$body, fixed = TRUE))
  expect_match(iss$body, "_not given_", fixed = TRUE)
  expect_match(iss$body, "> Ask", fixed = TRUE)
  expect_equal(unlist(iss$labels), c("data-quality", "user-report"))
  expect_lte(nchar(fb$feedback_issue(good$type, strrep("D", 500), "", good$details, "Montana")$title), 200)
})

test_that("without a token the Feedback button stays the GitHub link", {
  withr::local_envvar(GITHUB_FEEDBACK_TOKEN = "")
  expect_false(fb$feedback_enabled())
  html <- as.character(fb$feedback_nav_item("bostickmike/Example"))
  expect_match(html, "issues/new?template=data_issue.yml", fixed = TRUE)
  withr::local_envvar(GITHUB_FEEDBACK_TOKEN = "x")
  expect_match(as.character(fb$feedback_nav_item("bostickmike/Example")), "open_feedback", fixed = TRUE)
})
