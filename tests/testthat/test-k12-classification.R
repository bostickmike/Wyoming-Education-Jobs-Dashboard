test_that("classify_k12_position buckets substitutes before teachers", {
  expect_equal(classify_k12_position("Substitute Teacher"), "Substitute")
  expect_equal(classify_k12_position("Sub Nurse"), "Substitute")
  expect_equal(
    classify_k12_position("Long Term Sub Kindergarten Dual Immersion Teacher-Spanish Instruction"),
    "Substitute"
  )
})

test_that("classify_k12_position separates part-time teaching from full-FTE Teacher", {
  # Regression: part-time/reduced-FTE teacher titles used to be counted
  # identically to full-time teacher postings in the FTE trend charts.
  expect_equal(
    classify_k12_position("Part-Time (1/7th) Agriculture Education Teacher Remainder of 25-26 School Year"),
    "Part-Time Teacher"
  )
  expect_equal(classify_k12_position("Head Start Part-Time Assistant Teacher"), "Part-Time Teacher")
  expect_equal(classify_k12_position("Elementary Teacher 1st Grade"), "Teacher")

  # "Part-Time" alone, with no teacher keyword, must NOT be swept into
  # Part-Time Teacher -- it should still classify by its own role.
  expect_equal(classify_k12_position("Part-Time Bus Driver (29 Hours/Week)"), "Transportation")
})

test_that("classify_k12_position covers the remaining coarse buckets", {
  expect_equal(classify_k12_position("Paraprofessional - Elementary"), "Paraprofessional")
  expect_equal(classify_k12_position("School Counselor"), "Support Services")
  expect_equal(classify_k12_position("Head Football Coach"), "Athletics")
  expect_equal(classify_k12_position("Custodian"), "Custodial/Maintenance")
  expect_equal(classify_k12_position("Bus Driver"), "Transportation")
  expect_equal(classify_k12_position("Principal"), "Administration")
  expect_equal(classify_k12_position("Secretary"), "Staff")
  expect_equal(classify_k12_position("Cafeteria Cook"), "Food Services")
  expect_equal(classify_k12_position("Daycare Provider"), "Child Care")
  expect_equal(classify_k12_position("Random Title With Nothing Matching"), "Other")
})

test_that("classify_k12_subject checks Special Education ahead of subject keywords", {
  expect_equal(classify_k12_subject("Special Education Math Teacher"), "Special Education - General")
})

test_that("classify_k12_subject covers representative subject areas", {
  expect_equal(classify_k12_subject("Welding Teacher"), "Technical Education")
  expect_equal(classify_k12_subject("Agriculture Teacher"), "Agriculture Education")
  expect_equal(classify_k12_subject("5th Grade Teacher"), "Elementary Education")
  expect_equal(classify_k12_subject("High School English Teacher"), "English Language Arts Education")
  expect_equal(classify_k12_subject("Spanish Teacher"), "Language Education")
  expect_equal(classify_k12_subject("Mathematics Teacher"), "Mathematics Education")
  expect_equal(classify_k12_subject("Band Director"), "Music Education")
  expect_equal(classify_k12_subject("Physical Education Teacher"), "Physical Education")
  expect_equal(classify_k12_subject("History Teacher"), "Social Studies Education")
  expect_equal(classify_k12_subject("Random Teacher Title"), "Uncategorized")
})

test_that("classify_k12_broad_category maps Language correctly (regression for 'Lanugage' typo)", {
  expect_equal(classify_k12_broad_category("Language Education"), "Language")
  expect_false(identical(classify_k12_broad_category("Language Education"), "Lanugage"))
})

test_that("classify_k12_broad_category covers other mappings and the catchall", {
  expect_equal(classify_k12_broad_category("Special Education - General"), "Special Education - General")
  expect_equal(classify_k12_broad_category("Special Education - Resource/Life Skills"), "Special Education - Resource/Life Skills")
  expect_equal(classify_k12_broad_category("Elementary Education"), "Elementary")
  expect_equal(classify_k12_broad_category("Uncategorized"), "Other")
  expect_equal(classify_k12_broad_category("Nonsense Category"), "Other")
})

test_that("canonicalize_k12_district fixes known typos and passes through everything else", {
  expect_equal(canonicalize_k12_district("Hot Springs School District 1"), "Hot Springs County School District 1")
  expect_equal(canonicalize_k12_district("Crook County school District 1"), "Crook County School District 1")
  expect_equal(canonicalize_k12_district("Albany Count School District 1"), "Albany County School District 1")
  expect_equal(canonicalize_k12_district("Campbell County Scholl District 1"), "Campbell County School District 1")
  expect_equal(canonicalize_k12_district("Converse County School Distrcit 2"), "Converse County School District 2")
  expect_equal(canonicalize_k12_district("Sheridan County School District 1"), "Sheridan County School District 1")
})

test_that("fix_title_encoding repairs a Windows-1252 byte without warning, and classification still works", {
  # Reconstruct the exact byte sequence that produced the original
  # 'unable to translate ... to a wide string' warning: a raw 0x96
  # (Windows-1252 en dash) inside an otherwise-plain title.
  bad_bytes <- as.raw(c(
    0x31, 0x20, 0x50, 0x61, 0x72, 0x74, 0x20, 0x54, 0x69, 0x6d, 0x65,
    0x20, 0x28, 0x31, 0x30, 0x3a, 0x30, 0x30, 0x20, 0x61, 0x6d, 0x20,
    0x96, 0x20, 0x32, 0x3a, 0x30, 0x30, 0x20, 0x70, 0x6d, 0x29, 0x20,
    0x41, 0x73, 0x73, 0x69, 0x73, 0x74, 0x61, 0x6e, 0x74, 0x20, 0x43,
    0x6f, 0x6f, 0x6b
  ))
  bad_title <- rawToChar(bad_bytes)
  Encoding(bad_title) <- "unknown"

  expect_no_warning(result <- classify_k12_position(bad_title))
  expect_equal(result, "Food Services")
  expect_no_warning(classify_k12_subject(bad_title))
})
