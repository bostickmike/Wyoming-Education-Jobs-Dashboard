# The daily presence check reads the boards on the platforms its workflow names. A platform no registry row has is
# skipped without an error: on 2026-11-16 the registry's "Applitrack" became "AppliTrack" and Wyoming's 21 AppliTrack
# boards went unchecked until 11-24. So every name in the workflow must be a registry platform.
test_that("every platform presence.yml checks is in the K-12 registry", {
  wf <- readLines(here::here(".github/workflows/presence.yml"))
  line <- grep("^ +platforms:", wf, value = TRUE)
  expect_length(line, 1)
  asked <- trimws(strsplit(sub("^ +platforms:", "", line), ",")[[1]])
  registry <- read.csv(here::here("k12_district_registry.csv"), stringsAsFactors = FALSE)
  expect_identical(setdiff(asked, registry$Platform), character(0))
})
