test_that("classify_he_job_type separates Adjunct from full-time faculty", {
  # Regression: this is the main bug from the 2026-08-02 audit -- Adjunct
  # titles used to fall into the same "Instructor/Teacher/Faculty" bucket as
  # tenure-track/full-time postings.
  expect_equal(classify_he_job_type("Adjunct Instructor, Biology"), "Adjunct/Part-Time Faculty")
  expect_equal(classify_he_job_type("Adjunct- Spanish- Jackson"), "Adjunct/Part-Time Faculty")
  expect_equal(classify_he_job_type("Assistant Professor of Biology"), "Instructor/Teacher/Faculty")
  expect_equal(classify_he_job_type("Professor of History"), "Instructor/Teacher/Faculty")
})

test_that("classify_he_job_type covers the remaining coarse buckets", {
  expect_equal(classify_he_job_type("Student Worker - Library"), "Student Positions")
  expect_equal(classify_he_job_type("Registered Nurse"), "Healthcare")
  expect_equal(classify_he_job_type("Temporary Pooled Position"), "Temporary Position")
  expect_equal(classify_he_job_type("Administrative Assistant"), "Staff")
  expect_equal(classify_he_job_type("Academic Advisor"), "Advising and Student Services")
  expect_equal(classify_he_job_type("Registrar"), "Professional")
  expect_equal(classify_he_job_type("Dean of Students"), "Administration")
  expect_equal(classify_he_job_type("Head Basketball Coach"), "Coaching or Athletics")
  expect_equal(classify_he_job_type("Staff Accountant"), "Accounting/Finance")
  expect_equal(classify_he_job_type("Research Associate"), "Research & Science")
  expect_equal(classify_he_job_type("Network Specialist"), "Technical")
  expect_equal(classify_he_job_type("HVAC Technician"), "Maintenance & Service")
  expect_equal(classify_he_job_type("Custodian"), "Support Services")
  expect_equal(classify_he_job_type("Executive Chef"), "Culinary")
  expect_equal(classify_he_job_type("Director of Marketing"), "Management")
  expect_equal(classify_he_job_type("Totally Unmatched Title Zyx"), "Other")
})

test_that("classify_he_faculty_category covers representative subject areas", {
  expect_equal(classify_he_faculty_category("Assistant Professor of Mathematics"), "Math")
  expect_equal(classify_he_faculty_category("Professor of English"), "Humanities")
  expect_equal(classify_he_faculty_category("Biology Instructor"), "Science")
  expect_equal(classify_he_faculty_category("History Instructor"), "History")
  expect_equal(classify_he_faculty_category("Welding Instructor"), "CTE - Trades & Engineering")
  expect_equal(classify_he_faculty_category("Spanish Instructor"), "Language")
  expect_equal(classify_he_faculty_category("Nursing Instructor"), "CTE - Health Sciences")
  expect_equal(classify_he_faculty_category("Art Instructor"), "The Arts")
  expect_equal(classify_he_faculty_category("Psychology Instructor"), "Social Science")
  expect_equal(classify_he_faculty_category("Librarian"), "Library")
  expect_equal(classify_he_faculty_category("Totally Unmatched Faculty Title"), "Uncategorized")
})

test_that("canonicalize_he_institution fixes the Eastern Wyoming typo and passes through everything else", {
  # Regression: "Commmunity" (triple-m) was corrected mid-history in the
  # scraper but old archives still carried it, silently splitting the
  # college's trend line in two on a full rebuild.
  expect_equal(canonicalize_he_institution("Eastern Wyoming Commmunity College"), "Eastern Wyoming Community College")
  expect_equal(canonicalize_he_institution("Casper College"), "Casper College")
})
