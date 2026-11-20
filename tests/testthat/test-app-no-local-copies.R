# Package phase 6 (2026-11-16): app.R and feedback.R attach edjobs. A top-level definition with the name of an edjobs
# export would mask the package's version (a moved helper left behind, or a new one written over it).
test_that("app.R defines nothing edjobs exports", {
  exported <- getNamespaceExports("edjobs")
  for (f in "app.R") {   # feedback.R moved into edjobs (step 7 slice 1, 2026-11-21)
    ex <- parse(here::here("Wy_Ed_Jobs", f), keep.source = FALSE)
    defined <- unlist(lapply(ex, function(x)
      if (is.call(x) && as.character(x[[1]]) %in% c("<-", "=") && is.name(x[[2]])) as.character(x[[2]])))
    expect_equal(intersect(defined, exported), character(0), label = paste(f, "names also exported by edjobs"))
  }
})

test_that("app.R attaches edjobs", {
  ex <- parse(here::here("Wy_Ed_Jobs", "app.R"), keep.source = FALSE)
  expect_true(any(vapply(ex, function(x) identical(x, quote(library(edjobs))), logical(1))))
})

test_that("the committed deploy manifest installs edjobs from GitHub at the pinned version", {
  # Connect Cloud deploys from main with this manifest; without edjobs (or with a local install's record, which has
  # no Remote fields) the deploy can't install it and the app fails to start.
  m <- jsonlite::fromJSON(here::here("Wy_Ed_Jobs", "manifest.json"), simplifyVector = FALSE)
  ej <- m$packages$edjobs$description
  pinned <- trimws(readLines(here::here("EDJOBS_VERSION")))
  expect_false(is.null(ej))
  expect_identical(ej$RemoteType, "github")
  expect_identical(ej$RemotePkgRef, paste0("bostickmike/edjobs@v", pinned))
  expect_identical(ej$Version, pinned)
})
