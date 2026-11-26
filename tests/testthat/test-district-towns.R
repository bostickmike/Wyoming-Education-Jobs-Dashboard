# The districts' CCD towns (Wy_Ed_Jobs/district_towns.csv, edjobs refresh_district_towns(), 2026-11-26): every
# registry district with an NCES id has its row, so fill_k12_locations() can place its postings.

test_that("every registry district with an NCES id has a district-towns row", {
  towns <- read_district_towns(here::here("Wy_Ed_Jobs", "district_towns.csv"))
  reg <- read_k12_registry()
  ids <- sprintf("%07d", suppressWarnings(as.integer(reg$NCES_LEAID)))
  ids <- ids[!grepl("NA", ids)]
  expect_length(setdiff(ids, towns$NCES_LEAID), 0)
  expect_equal(names(towns), c("NCES_LEAID", "Office_Town", "School_Towns", "CCD_Year"))
  expect_false(anyNA(towns$Office_Town))
})

test_that("the towns that put a WSBA town right: Laramie County SD 1 is in Cheyenne, Lincoln 1's schools in Kemmerer", {
  towns <- read_district_towns(here::here("Wy_Ed_Jobs", "district_towns.csv"))
  reg <- read_k12_registry()
  ids <- setNames(reg$NCES_LEAID, reg$District)
  df <- data.frame(District = c("Laramie County School District 1", "Lincoln County School District 1",
                                "Weston County School District 1", "Platte County School District 1"),
                   location = c("Laramie", NA, NA, NA), stringsAsFactors = FALSE)
  out <- fill_k12_locations(df, towns, ids, feed_rows = c(TRUE, FALSE, FALSE, FALSE))
  expect_equal(out$location, c("Cheyenne", "Kemmerer", "Newcastle", NA))
})
