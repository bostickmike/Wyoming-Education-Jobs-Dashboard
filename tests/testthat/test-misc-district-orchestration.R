# misc_district_scrapers.R is sourced directly (not an R package), so
# testthat::local_mocked_bindings() -- which requires pkgload/a dev
# package -- doesn't work here. mock_globals() is a small dependency-free
# stand-in: temporarily reassigns named functions in the global
# environment (where source()'d functions live) and restores the
# originals via testthat's own teardown hook, same lifecycle
# local_mocked_bindings() would give inside a package.
mock_globals <- function(bindings) {
  originals <- mget(names(bindings), envir = globalenv())
  for (name in names(bindings)) assign(name, bindings[[name]], envir = globalenv())
  withr::defer({
    for (name in names(originals)) assign(name, originals[[name]], envir = globalenv())
  }, envir = parent.frame())
}

test_that("misc_district_registry has exactly the 12 confirmed districts, each with a known platform", {
  expect_equal(nrow(misc_district_registry), 12)
  expect_true(all(misc_district_registry$platform %in%
    c("wordpress", "apptegy", "smartsites", "schoolblocks", "edlio", "googlesites")))
  expect_equal(length(unique(misc_district_registry$District)), 12)
})

test_that("fetch_misc_district_postings dispatches to the right platform function", {
  # Fake single-row result so this test doesn't touch the network;
  # confirms routing, not the extractors themselves (already covered in
  # test-misc-district-platform-extractors.R).
  mock_globals(list(
    fetch_wordpress_postings = function(url) data.frame(Title = "wp-hit", Location = NA, Posted_Date = NA, Link = NA)
  ))
  result <- fetch_misc_district_postings("wordpress", "http://example.com")
  expect_equal(result$Title, "wp-hit")
})

test_that("fetch_misc_district_postings errors clearly on an unknown platform", {
  expect_error(fetch_misc_district_postings("not-a-real-platform", "http://example.com"), "unknown platform")
})

test_that("fetch_all_misc_district_postings combines WSBA and district-own postings, deduplicated, with no chromote available", {
  # No chromote_session_factory passed -> apptegy_session stays NULL ->
  # fetch_apptegy_postings(NULL, url) is called for the 4 Apptegy
  # districts and (mocked here) returns a fixed result regardless of the
  # NULL session, standing in for what a real browser fetch would return.
  mock_globals(list(
    fetch_wsba_vacancies = function(url) data.frame(
      Title = c("K-6 Elementary Teacher", "K-12 Band Teacher"),
      District = c("Niobrara County School District 1", "Niobrara County School District 1"),
      Location = c("Lusk", "Lusk"),
      Posted_Date = c("2026-05-18", "2026-05-11"),
      stringsAsFactors = FALSE
    ),
    fetch_wordpress_postings = function(url) data.frame(Title = character(0), Location = character(0), Posted_Date = character(0), Link = character(0)),
    fetch_smartsites_postings = function(url) data.frame(Title = character(0), Location = character(0), Posted_Date = character(0), Link = character(0)),
    fetch_schoolblocks_postings = function(url) data.frame(Title = character(0), Location = character(0), Posted_Date = character(0), Link = character(0)),
    fetch_edlio_postings = function(url) data.frame(Title = character(0), Location = character(0), Posted_Date = character(0), Link = character(0)),
    fetch_googlesites_postings = function(url) data.frame(Title = character(0), Location = character(0), Posted_Date = character(0), Link = character(0)),
    fetch_apptegy_postings = function(session, url) data.frame(
      Title = c("K-6 Elementary Teacher", "SPED Paraprofessional"),  # first is a WSBA duplicate, second is new
      Location = NA_character_, Posted_Date = NA_character_, Link = NA_character_
    )
  ))

  result <- fetch_all_misc_district_postings()

  niobrara <- result[result$District == "Niobrara County School District 1", ]
  # 2 from WSBA + 1 from Apptegy after dedup (the WSBA-duplicate title
  # "K-6 Elementary Teacher" must NOT appear twice).
  expect_equal(nrow(niobrara), 3)
  expect_equal(sum(niobrara$title == "K-6 Elementary Teacher"), 1)
  expect_true("SPED Paraprofessional" %in% niobrara$title)

  expect_equal(names(result), c("title", "date_posted", "position", "location", "url", "District"))
  expect_true(all(is.na(result$position)))
})

test_that("fetch_all_misc_district_postings returns the right empty schema when every source is empty", {
  mock_globals(list(
    fetch_wsba_vacancies = function(url) data.frame(Title = character(0), District = character(0), Location = character(0), Posted_Date = character(0)),
    fetch_wordpress_postings = function(url) data.frame(Title = character(0), Location = character(0), Posted_Date = character(0), Link = character(0)),
    fetch_smartsites_postings = function(url) data.frame(Title = character(0), Location = character(0), Posted_Date = character(0), Link = character(0)),
    fetch_schoolblocks_postings = function(url) data.frame(Title = character(0), Location = character(0), Posted_Date = character(0), Link = character(0)),
    fetch_edlio_postings = function(url) data.frame(Title = character(0), Location = character(0), Posted_Date = character(0), Link = character(0)),
    fetch_googlesites_postings = function(url) data.frame(Title = character(0), Location = character(0), Posted_Date = character(0), Link = character(0)),
    fetch_apptegy_postings = function(session, url) data.frame(Title = character(0), Location = character(0), Posted_Date = character(0), Link = character(0))
  ))

  result <- fetch_all_misc_district_postings()
  expect_equal(nrow(result), 0)
  expect_equal(names(result), c("title", "date_posted", "position", "location", "url", "District"))
})
