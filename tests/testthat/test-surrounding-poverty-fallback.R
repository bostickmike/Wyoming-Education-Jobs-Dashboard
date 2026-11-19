# carried_surrounding_population() (state_config.R, 2026-11-19): when the Census geocoder fails for a charter or
# early-childhood school and last run's salarymap2.csv has no SAIPE_Population, the host district named in the
# carried-over Child_Poverty_Basis gives it, so edjobs::add_saipe_range() still gives the 90% range. Rows from the
# 2026-11-19 rehearsal where the geocoder failed for these three schools (host values from that run's SAIPE pull).

saipe_hosts <- data.frame(LEAID = c("5601980", "5604510", "5605302", "5605690"),
                          Child_Poverty_Rate = c(0.085, 0.100, 0.091, 0.2),
                          SAIPE_Population = c(95622, 80410, 28791, 7000))
host_names <- c("5601980" = "Laramie County School District 1", "5604510" = "Natrona School District 1",
                "5605302" = "Sweetwater County School District 1")

test_that("the host district named in the basis gives the population", {
  expect_equal(carried_surrounding_population("Surrounding district: Laramie County School District 1",
                                              saipe_hosts, host_names), 95622)
  expect_equal(carried_surrounding_population("Surrounding district: Natrona School District 1",
                                              saipe_hosts, host_names), 80410)
})

test_that("a split town's districts pool as surrounding_district_poverty() pools them; an unnamed id still counts", {
  basis <- "Surrounding district: Sweetwater County School District 1 / 5605690"
  expect_equal(carried_surrounding_population(basis, saipe_hosts, host_names),
               pool_saipe_population(saipe_hosts[saipe_hosts$LEAID %in% c("5605302", "5605690"), ]))
})

test_that("no basis, another basis, or an unknown district gives NA", {
  expect_true(is.na(carried_surrounding_population(NA_character_, saipe_hosts, host_names)))
  expect_true(is.na(carried_surrounding_population("SAIPE district", saipe_hosts, host_names)))
  expect_true(is.na(carried_surrounding_population("Surrounding district: Nowhere SD 9", saipe_hosts, host_names)))
})

test_that("with the population filled, the three rehearsal rows get a range that brackets the rate", {
  rows <- data.frame(District = c("Cheyenne Classical Academy", "Wyoming Classical Academy",
                                  "Sweetwater County Child Developmental Center"),
                     Child_Poverty_Rate = c(0.085, 0.100, 0.091),
                     Child_Poverty_Basis = paste("Surrounding district:", host_names))
  rows$SAIPE_Population <- vapply(rows$Child_Poverty_Basis, carried_surrounding_population, numeric(1),
                                  saipe = saipe_hosts, district_names = host_names, USE.NAMES = FALSE)
  out <- add_saipe_range(rows)
  expect_false(anyNA(out$Child_Poverty_Low))
  expect_true(all(out$Child_Poverty_Low <= out$Child_Poverty_Rate & out$Child_Poverty_Rate <= out$Child_Poverty_High))
})

test_that("the Rmd fills it only on a geocoder failure, from this run's SAIPE rows", {
  rmd <- paste(readLines(here::here("Wy_ED_Jobs.Rmd"), warn = FALSE), collapse = "\n")
  expect_true(grepl("carried_surrounding_population(salarymap2$Child_Poverty_Basis[i],", rmd, fixed = TRUE))
  expect_true(grepl("district_rates, district_names)", rmd, fixed = TRUE))
})
