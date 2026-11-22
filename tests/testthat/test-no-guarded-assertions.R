# A test whose assertions sit inside `if (nrow(result) > 0) { ... }` passes when the parser finds nothing, so it
# cannot fail on a broken or wrong page. Six MT parser tests were written that way (scripts/scaffold_district.R's
# template, 2026-10-27/28): five passed on empty boards for weeks, and Ulm's passed on a Title I notice it took for
# a job (2026-11-21, claude-notes/2026-11-21_step8/). This test fails on any `if` whose condition is a count above
# zero (nrow, NROW, length, sum) and whose body asserts something. A guard that is right (the assertion only applies
# when there is something to compare) carries `# guard-ok: <reason>` on the `if` line.
# The same file is in the MT and WY repos and in edjobs (keep the three identical).

guarded_assertions <- function(path) {
  lines <- readLines(path, warn = FALSE)
  exprs <- tryCatch(parse(path, keep.source = TRUE), error = function(e) NULL)
  if (is.null(exprs)) return(character(0))
  data <- utils::getParseData(exprs)
  hits <- character(0)
  is_count_test <- function(cond) {
    txt <- paste(deparse(cond), collapse = " ")
    grepl("\\b(nrow|NROW|length|sum)\\s*\\(", txt) && grepl("(>\\s*0|>=\\s*1|!=\\s*0|>\\s*0L|>=\\s*1L)\\b", txt)
  }
  asserts <- function(body) any(grepl("\\bexpect_", paste(deparse(body), collapse = " ")))
  # Each `if` call, with its line, from the parse data.
  if_rows <- data[data$token == "IF", ]
  for (i in seq_len(nrow(if_rows))) {
    ln <- if_rows$line1[i]
    parent <- data[data$id == if_rows$parent[i], ]
    txt <- paste(utils::getParseText(data, parent$id), collapse = "\n")
    e <- tryCatch(parse(text = txt)[[1]], error = function(err) NULL)
    if (is.null(e) || !identical(e[[1]], as.name("if"))) next
    if (is_count_test(e[[2]]) && asserts(e[[3]]) && !grepl("#\\s*guard-ok:", lines[ln])) {
      hits <- c(hits, sprintf("%s:%d  if (%s)", basename(path), ln, paste(deparse(e[[2]]), collapse = " ")))
    }
  }
  unique(hits)
}

test_that("no test hides its assertions behind a non-empty guard", {
  files <- list.files(test_path(), pattern = "^test.*\\.R$", full.names = TRUE)
  hits <- as.character(unlist(lapply(files, guarded_assertions)))
  expect_equal(hits, character(0),
               info = "assert the exact expected rows (an empty board: expect 0 rows and the list container), or mark a needed guard `# guard-ok: <reason>`")
})

test_that("the guard check finds the pattern it is for", {
  f <- withr::local_tempfile(fileext = ".R")
  writeLines(c('test_that("x", {', '  result <- parse_x(fixture)', '  if (nrow(result) > 0) {',
               '    expect_true(all(result$Location == "Ulm"))', '  }',
               '  if (length(result$Title) >= 1) expect_true(TRUE)  # guard-ok: example',
               '  if (nrow(result) > 0) print(result)', '})'), f)
  hits <- guarded_assertions(f)
  expect_length(hits, 1)
  expect_match(hits, ":3  if \\(nrow\\(result\\) > 0\\)")
})
