# extract_posted_pay(): the pay a posting itself states. Unit tests use
# wording copied from real AppliTrack postings (Great Falls, Billings, MCPS,
# Helena, Sweetwater); the parser test uses a real captured Output.asp page.

test_that("extract_posted_pay reads amounts, ranges and units as written", {
  p <- extract_posted_pay(c(
    "LOCATION: Great Falls High School SALARY: $15.14 per hour (25/26 Salary Schedule)",
    "EMPLOYMENT: 2026/2027 SALARY: $48,300-$73,957 (2026/2027 salary schedule)",
    "7.5 hrs/day$21.46 to $22.81 per hour, depending on experience",
    "Starts: August 2026Stipend: $3,548.00Required Coaches Certificates",
    "Long Term Substitutes are paid at $250.00 per day and issued a contract.",
    "Salary: $160.00/Whole Day, $80.00/Half Day",
    "6:00am - 2:30pm $20.60* - $21.95*/hr depending on experience",
    "Part Time, at most 29 hours per weekSalary: P-V, $25.69",
    "BEA Salary Schedule; Full Benefits",
    NA
  ))
  expect_equal(p$Pay_Min, c(15.14, 48300, 21.46, 3548, 250, 160, 20.60, 25.69, NA, NA))
  expect_equal(p$Pay_Max, c(15.14, 73957, 22.81, 3548, 250, 160, 21.95, 25.69, NA, NA))
  expect_equal(p$Pay_Unit, c("hour", "year", "hour", "stipend", "day", "day", "hour", "hour", NA, NA))
  expect_true(all(is.na(p$Pay_Text) == is.na(p$Pay_Min)))
})

test_that("extract_posted_pay ignores bonuses, fees and differentials", {
  p <- extract_posted_pay(c(
    "*We offer a one-time $1,000 signing bonus. Starting salary will be a minimum of $46,225 to max of $86,400 DOE",
    "*Includes a $0.50 per hour differential. Pay: $20.60 per hour",
    "Application fee of $25 required."
  ))
  expect_equal(p$Pay_Min, c(46225, 20.60, NA))
  expect_equal(p$Pay_Max, c(86400, 20.60, NA))
})

test_that("parse_applitrack_output carries each posting's stated pay", {
  path <- test_path("fixtures", "applitrack_output_park1_pay.bin")
  js <- iconv(readChar(path, file.size(path), useBytes = TRUE), "WINDOWS-1252", "UTF-8")
  out <- parse_applitrack_output(js)
  expect_true(all(c("Pay_Min", "Pay_Max", "Pay_Unit", "Pay_Text") %in% names(out)))
  expect_gt(nrow(out), 0)
  expect_gte(mean(!is.na(out$Pay_Min)), 0.9)
  ok <- !is.na(out$Pay_Min)
  expect_true(all(out$Pay_Min[ok] <= out$Pay_Max[ok]))
  expect_true(all(out$Pay_Unit[ok] %in% c("hour", "day", "month", "year", "credit hour", "stipend", NA)))
  expect_true(all(mapply(function(txt, v) grepl(format(v, big.mark = ",", nsmall = 0, scientific = FALSE), gsub("\\.00\\b", "", txt), fixed = TRUE) || grepl(sprintf("%.2f", v), txt, fixed = TRUE),
                         out$Pay_Text[ok], out$Pay_Min[ok])))
  expect_equal(ncol(parse_applitrack_output("")), ncol(out))
})
