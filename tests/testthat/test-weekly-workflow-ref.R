# The weekly run is edjobs's reusable workflow (package review step 6, 2026-11-20). Its `uses:` tag must be the
# pinned EDJOBS_VERSION: a branch ref left over from a test dispatch would run unreviewed workflow code on main, and a
# stale tag would run old steps against the new package.
test_that("weekly-scrape.yml calls edjobs's weekly-run workflow at the pinned tag", {
  wf <- readLines(here::here(".github/workflows/weekly-scrape.yml"))
  uses <- trimws(sub(".*uses:", "", grep("uses: bostickmike/edjobs/.github/workflows/weekly-run.yml@", wf, value = TRUE)))
  expect_length(uses, 1)
  pinned <- trimws(readLines(here::here("EDJOBS_VERSION")))
  expect_identical(uses, paste0("bostickmike/edjobs/.github/workflows/weekly-run.yml@v", pinned))
})
