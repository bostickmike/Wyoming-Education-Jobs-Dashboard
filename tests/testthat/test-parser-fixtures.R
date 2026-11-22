# Every posting parser this repo defines needs a test that reads a captured page from tests/testthat/fixtures/ and
# asserts at least one exact title it returns (`expect_true("X" %in% result$Title)`, `expect_equal(result$Title, ...)`,
# `expect_equal(result$Title[1], "X")`). A test like that can only pass when the parser finds that row on a real page.
# Ten MT parsers were tested only on empty boards or short hand-written HTML (2026-10-27 to 11-21), so their tests
# could not fail on a broken or wrong page (claude-notes/2026-11-21_step8-review/ section E, test-kit item 4).
# A parser with no such test yet is listed in parser-fixture-allowlist.csv with the reason and the date; an entry
# that is no longer needed (the parser now has the test, or is gone) fails too, so the list only shrinks.
# "Posting parser" = a function named parse_*_postings / _positions / _page / _vacancies / _requisitions / _jobs
# (not a salary-table parser), defined in a .R file at the repo root.
# The same file is in the MT and WY repos (keep them identical; each has its own allowlist).

# TRUE if a test block asserts a literal title positively, in a form that fails on an empty result:
# expect_true("X" %in% r$Title), expect_true(all(c("X", "Y") %in% r$Title)), or expect_equal/identical/setequal/
# contains(<something with $Title>, "X" or c("X", ...)) (either order). Not expect_false(...), not
# expect_true(all(r$Title %in% ...)) or all(grepl(...)): those pass when there are no rows.
asserts_literal_title <- function(block) {
  has_title <- function(e) any(grepl("$Title", deparse(e, width.cutoff = 500L), fixed = TRUE))
  is_lit <- function(e) (is.character(e) && length(e) >= 1 && all(nchar(e) >= 3)) ||
    (is.call(e) && identical(e[[1]], as.name("c")) && length(e) > 1 && all(vapply(as.list(e)[-1], is_lit, TRUE)))
  in_title <- function(e) is.call(e) && identical(e[[1]], as.name("%in%")) && is_lit(e[[2]]) && has_title(e[[3]])
  found <- FALSE
  walk <- function(e) {
    if (found || !is.call(e)) return(invisible())
    f <- if (is.name(e[[1]])) as.character(e[[1]]) else ""
    args <- as.list(e)[-1]
    if (f == "expect_true" && length(args)) {
      a <- args[[1]]
      if (in_title(a) || (is.call(a) && identical(a[[1]], as.name("all")) && length(a) == 2 && in_title(a[[2]]))) found <<- TRUE
    }
    if (f %in% c("expect_equal", "expect_identical", "expect_setequal", "expect_contains") && length(args) >= 2) {
      if ((has_title(args[[1]]) && is_lit(args[[2]])) || (is_lit(args[[1]]) && has_title(args[[2]]))) found <<- TRUE
    }
    for (i in seq_along(args)) if (!identical(args[[i]], quote(expr = ))) walk(args[[i]])
  }
  walk(block)
  found
}

parser_fixture_coverage <- function(src_files, test_files) {
  defs <- unlist(lapply(src_files, function(f) {
    l <- readLines(f, warn = FALSE)
    fns <- sub("\\s*<-.*", "", grep("^parse_[A-Za-z0-9_.]+_(postings|positions|page|vacancies|requisitions|jobs)\\s*<-\\s*function", l, value = TRUE))
    fns[!grepl("salary", fns)]
  }))
  exprs <- unlist(lapply(test_files, function(f) as.list(tryCatch(parse(f, keep.source = FALSE), error = function(e) NULL))),
                  recursive = FALSE)
  text_of <- function(e) paste(deparse(e, width.cutoff = 500L), collapse = "\n")
  # Test-file helpers that read a captured fixture unchanged (read_fixture(), interfolio_fixture(), ...) count as
  # reading one; a helper that edits the page (sub/gsub, like zurich_fixture_with()) does not.
  fixture_re <- "test_path\\(\"fixtures\"|\"fixtures/"
  defs_in_tests <- Filter(function(e) is.call(e) && identical(e[[1]], as.name("<-")) && is.name(e[[2]]) &&
                            is.call(e[[3]]) && identical(e[[3]][[1]], as.name("function")), exprs)
  readers <- character(0)
  for (pass in 1:2) for (e in defs_in_tests) {
    body <- text_of(e[[3]])
    reads <- grepl(fixture_re, body) || (length(readers) && grepl(paste0("\\b(", paste(readers, collapse = "|"), ")\\("), body))
    if (reads && !grepl("\\b(g?sub|regmatches)\\(", body)) readers <- union(readers, as.character(e[[2]]))
  }
  test_exprs <- Filter(function(e) is.call(e) && identical(e[[1]], as.name("test_that")), exprs)
  blocks <- vapply(test_exprs, text_of, "")
  reader_re <- if (length(readers)) paste0("\\b(", paste(readers, collapse = "|"), ")\\(") else "$^"
  reads_fixture <- grepl(fixture_re, blocks) | grepl(reader_re, blocks)
  asserts_title <- vapply(test_exprs, asserts_literal_title, TRUE)
  good <- blocks[reads_fixture & asserts_title]
  covered <- vapply(defs, function(fn) any(grepl(paste0("\\b", fn, "\\("), good)), TRUE)
  data.frame(fn = defs, covered = unname(covered), stringsAsFactors = FALSE)
}

test_that("every posting parser has a captured, non-empty fixture with an exact title asserted", {
  root <- test_path("..", "..")
  cov <- parser_fixture_coverage(list.files(root, pattern = "\\.R$", full.names = TRUE),
                                 list.files(test_path(), pattern = "^test.*\\.R$", full.names = TRUE))
  allow <- utils::read.csv(test_path("parser-fixture-allowlist.csv"), colClasses = "character")
  expect_true(all(nzchar(allow$reason) & grepl("^\\d{4}-\\d{2}-\\d{2}$", allow$added)),
              info = "each allowlist entry needs a reason and an added date (YYYY-MM-DD)")
  no_test <- setdiff(cov$fn[!cov$covered], allow$fn)
  expect(length(no_test) == 0, paste0("add a test on a captured page that asserts an exact title, or list the parser in parser-fixture-allowlist.csv with a reason: ", paste(no_test, collapse = ", ")))
  now_covered <- intersect(allow$fn, cov$fn[cov$covered])
  expect(length(now_covered) == 0, paste0("these parsers now have the test: take them off parser-fixture-allowlist.csv: ", paste(now_covered, collapse = ", ")))
  gone <- setdiff(allow$fn, cov$fn)
  expect(length(gone) == 0, paste0("these allowlisted parsers are no longer defined: take them off parser-fixture-allowlist.csv: ", paste(gone, collapse = ", ")))
})

test_that("the coverage check tells a real fixture test from an empty or hand-written one", {
  src <- withr::local_tempfile(fileext = ".R")
  writeLines(c("parse_a_postings <- function(html) NULL", "parse_b_postings <- function(html) NULL",
               "parse_c_postings <- function(html) NULL", "parse_d_postings <- function(html) NULL",
               "parse_e_job_details <- function(html) NULL"), src)
  tst <- withr::local_tempfile(fileext = ".R")
  writeLines(c(
    'test_that("a", { r <- parse_a_postings(readLines(test_path("fixtures", "a.html"))); expect_true("Bus Driver" %in% r$Title) })',
    'test_that("b", { r <- parse_b_postings(readLines(test_path("fixtures", "b.html"))); expect_equal(nrow(r), 0) })',
    'test_that("c", { r <- parse_c_postings("<li>Cook</li>"); expect_equal(r$Title, "Cook") })',
    'test_that("d", { r <- parse_d_postings(readLines(test_path("fixtures", "d.html"))); expect_false("Notice" %in% r$Title) })'), tst)
  cov <- parser_fixture_coverage(src, tst)
  expect_equal(cov$fn, c("parse_a_postings", "parse_b_postings", "parse_c_postings", "parse_d_postings"))
  expect_equal(cov$covered, c(TRUE, FALSE, FALSE, FALSE))
})
