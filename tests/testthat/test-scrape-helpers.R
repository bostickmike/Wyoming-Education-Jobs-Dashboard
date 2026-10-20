test_that("empty_df returns zero rows with the requested columns", {
  d <- empty_df(c("Title", "Location", "Link"))
  expect_equal(nrow(d), 0)
  expect_equal(names(d), c("Title", "Location", "Link"))
})

test_that("log_scrape_result creates a log with a header, then appends without repeating it", {
  log_path <- withr::local_tempfile(fileext = ".csv")

  log_scrape_result("Test Source", status = "ok", n_rows = 5, log_path = log_path)
  first <- read.csv(log_path)
  expect_equal(nrow(first), 1)
  expect_equal(first$source, "Test Source")
  expect_equal(first$status, "ok")
  expect_equal(first$n_rows, 5)

  log_scrape_result("Test Source", status = "error", n_rows = 0,
                     error_message = "boom", log_path = log_path)
  second <- read.csv(log_path)
  expect_equal(nrow(second), 2)
  expect_equal(second$status, c("ok", "error"))
  expect_equal(second$error_message[2], "boom")
})

test_that("safe_scrape returns the real result and logs 'ok' on success", {
  log_path <- withr::local_tempfile(fileext = ".csv")
  fake_scrape <- function() data.frame(Title = c("A", "B"), Location = c("X", "Y"))

  result <- safe_scrape("Fake College", fake_scrape, c("Title", "Location"), log_path = log_path)

  expect_equal(nrow(result), 2)
  expect_equal(result$Title, c("A", "B"))

  log <- read.csv(log_path)
  expect_equal(log$status, "ok")
  expect_equal(log$n_rows, 2)
})

test_that("safe_scrape degrades to an empty frame and logs 'error' when the scrape throws", {
  log_path <- withr::local_tempfile(fileext = ".csv")
  fake_scrape <- function() stop("selector not found")

  expect_message(
    result <- safe_scrape("Fake College", fake_scrape, c("Title", "Location"), log_path = log_path),
    "Fake College failed"
  )

  expect_equal(nrow(result), 0)
  expect_equal(names(result), c("Title", "Location"))

  log <- read.csv(log_path)
  expect_equal(log$status, "error")
  expect_equal(log$n_rows, 0)
  expect_equal(log$error_message, "selector not found")
})

test_that("safe_scrape logs 'empty' (not 'error') when the scrape succeeds with zero rows", {
  # This is the failure mode that matters most: a silently broken selector
  # returns 0 rows without throwing, and previously looked identical to a
  # genuinely empty week. It must be distinguishable in the log from both
  # a normal success and a hard error.
  log_path <- withr::local_tempfile(fileext = ".csv")
  fake_scrape <- function() data.frame(Title = character(0), Location = character(0))

  result <- safe_scrape("Fake College", fake_scrape, c("Title", "Location"), log_path = log_path)

  expect_equal(nrow(result), 0)
  log <- read.csv(log_path)
  expect_equal(log$status, "empty")
})

test_that("safe_scrape handles a scrape_fn that returns NULL the same as empty", {
  log_path <- withr::local_tempfile(fileext = ".csv")
  fake_scrape <- function() NULL

  result <- safe_scrape("Fake College", fake_scrape, c("Title", "Location"), log_path = log_path)

  expect_equal(nrow(result), 0)
  log <- read.csv(log_path)
  expect_equal(log$status, "empty")
})

# httr2's default req_retry() retries only 429/503. (The retry loop itself
# isn't exercised here: httr2 1.0.0 returns mocked responses before its
# retry loop runs, so a mock can't simulate "520, then 200".)
test_that("is_transient_gateway_error retries rate limits and gateway/Cloudflare 5xx, not real failures", {
  status_is_transient <- function(code) is_transient_gateway_error(httr2::response(status_code = code))
  for (code in c(429, 502, 503, 504, 520, 521, 522, 523, 524)) {
    expect_true(status_is_transient(code), info = code)
  }
  for (code in c(200, 403, 404, 500)) {
    expect_false(status_is_transient(code), info = code)
  }
})

test_that("fetch_json_paginated handles JSON nulls and heterogeneous fields across pages", {
  page1 <- '{"count": 3, "next": "https://api.example.com/p2", "results": [{"id": 1, "val": null}, {"id": 2, "val": "abc"}]}'
  page2 <- '{"count": 3, "next": null, "results": [{"id": 3, "val": "def", "extra": 42}]}'

  httr2::local_mocked_responses(list(
    httr2::response(200, headers = list("Content-Type" = "application/json"), body = charToRaw(page1)),
    httr2::response(200, headers = list("Content-Type" = "application/json"), body = charToRaw(page2))
  ))

  res <- fetch_json_paginated("https://api.example.com/p1")
  expect_equal(nrow(res), 3)
  expect_equal(res$id, c(1, 2, 3))
  expect_true(is.na(res$val[1]))
  expect_equal(res$val[2], "abc")
  expect_true(is.na(res$extra[1]))
  expect_equal(res$extra[3], 42)
})

test_that("fetch_json_paginated handles empty results and respects max_pages", {
  empty_page <- '{"count": 0, "next": null, "results": []}'
  httr2::local_mocked_responses(list(
    httr2::response(200, headers = list("Content-Type" = "application/json"), body = charToRaw(empty_page))
  ))
  res_empty <- fetch_json_paginated("https://api.example.com/empty")
  expect_equal(nrow(res_empty), 0)
  expect_true(is.data.frame(res_empty))

  page1 <- '{"count": 10, "next": "https://api.example.com/p2", "results": [{"id": 1}]}'
  httr2::local_mocked_responses(list(
    httr2::response(200, headers = list("Content-Type" = "application/json"), body = charToRaw(page1))
  ))
  res_limited <- fetch_json_paginated("https://api.example.com/p1", max_pages = 1)
  expect_equal(nrow(res_limited), 1)
})
