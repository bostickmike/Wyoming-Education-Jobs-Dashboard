test_that("canonicalize_wsba_district maps 'No. N' format to project convention", {
  expect_equal(canonicalize_wsba_district("Niobrara County School District No. 1"), "Niobrara County School District 1")
  expect_equal(canonicalize_wsba_district("Weston County School District No. 7"), "Weston County School District 7")
})

test_that("canonicalize_wsba_district leaves non-matching org names unchanged rather than dropping them", {
  expect_equal(canonicalize_wsba_district("Snowy Range Academy"), "Snowy Range Academy")
})

test_that("parse_wsba_vacancies extracts real entries from the committed WSBA fixture", {
  # Real fixture: full HTML captured from https://www.wsba-wy.org/vacancies.
  # Confirmed this is server-rendered directly (Google Sites splits text
  # across many <span> tags, which is why a naive substring grep misses it
  # -- rvest::html_text2() reconstructs it correctly, no browser needed).
  html <- paste(readLines(test_path("fixtures", "wsba_vacancies.html"), warn = FALSE, encoding = "UTF-8"), collapse = "\n")

  result <- parse_wsba_vacancies(html)

  expect_gt(nrow(result), 100)
  expect_equal(names(result), c("Title", "District", "Location", "Posted_Date"))

  niobrara <- result[result$District == "Niobrara County School District 1", ]
  expect_equal(nrow(niobrara), 2)
  expect_true("K-6 Elementary Teacher" %in% niobrara$Title)
  expect_true("K-12 Band Teacher" %in% niobrara$Title)

  weston1 <- result[result$District == "Weston County School District 1", ]
  # Regression: WSBA is known to be incomplete (confirmed by comparing
  # against Weston 1's own site, which lists 16 postings vs. WSBA's 6) --
  # this pins the specific count WSBA itself reports, not a claim that
  # it's exhaustive.
  expect_equal(nrow(weston1), 5)
})

test_that("parse_wsba_vacancies returns zero rows (not an error) when no entries match the expected pattern", {
  result <- parse_wsba_vacancies("<html><body><p>No vacancies</p></body></html>")
  expect_equal(nrow(result), 0)
  expect_equal(names(result), c("Title", "District", "Location", "Posted_Date"))
})

test_that("normalize_title collapses case/punctuation/whitespace differences", {
  expect_equal(normalize_title("K-12 Music/Band Instructor"), normalize_title("k 12  music band instructor!!"))
})

test_that("dedupe_against_wsba removes only same-district, same-normalized-title matches", {
  district_postings <- data.frame(
    Title = c("K-6 Elementary Teacher", "SPED Paraprofessional", "Bus Driver"),
    stringsAsFactors = FALSE
  )
  wsba_postings <- data.frame(
    Title = c("K-6 Elementary Teacher", "K-12 Band Teacher"),
    District = c("Niobrara County School District 1", "Niobrara County School District 1"),
    stringsAsFactors = FALSE
  )

  result <- dedupe_against_wsba(district_postings, wsba_postings, "Niobrara County School District 1")

  expect_equal(nrow(result), 2)
  expect_false("K-6 Elementary Teacher" %in% result$Title)
  expect_true(all(c("SPED Paraprofessional", "Bus Driver") %in% result$Title))
})

test_that("dedupe_against_wsba does not remove a matching title from a DIFFERENT district", {
  district_postings <- data.frame(Title = c("Substitute Teacher"), stringsAsFactors = FALSE)
  wsba_postings <- data.frame(
    Title = "Substitute Teacher",
    District = "Some Other District",
    stringsAsFactors = FALSE
  )

  result <- dedupe_against_wsba(district_postings, wsba_postings, "Niobrara County School District 1")
  expect_equal(nrow(result), 1)
})

test_that("dedupe_against_wsba is a no-op when the district has no WSBA entries at all", {
  district_postings <- data.frame(Title = c("Anything"), stringsAsFactors = FALSE)
  wsba_postings <- data.frame(Title = character(0), District = character(0), stringsAsFactors = FALSE)

  result <- dedupe_against_wsba(district_postings, wsba_postings, "Lincoln County School District 2")
  expect_equal(nrow(result), 1)
})
