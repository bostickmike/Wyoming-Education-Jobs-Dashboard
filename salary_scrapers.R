# Wyoming K-12 salary data from WSBA's publicly shared PDFs:
# https://sites.google.com/wsba-wy.org/my-wsba/wy-education-salaries
#
# "2025-2026 Teacher Salary Settlements" -- one page, ~48 districts, base
# salary for both the prior and current contract year (a year-over-year
# comparison for free) plus vertical/horizontal increment notes and
# contract days. Only base salary is parsed here -- the increment/days
# cells wrap onto multiple lines with inconsistent formatting (footnotes,
# tiered schedules like "650 (1-5 yrs), 750 (6-10 yrs)...") that isn't
# reliably parseable at the same confidence as the clean single-line
# dollar figures, so they're left out rather than risk silently wrong data.
#
# "2025-2026 Central Office Staff" -- 8 PDF pages (visually labeled "Page
# 1 of 4" -- the export appears to duplicate each visual page as two PDF
# pages; harmless, handled by deduplication below), superintendent salary
# plus 12 other central-office roles per district. Only superintendent
# salary is parsed -- every district has exactly one, making it the one
# figure that's reliably comparable across all districts; the other roles
# are frequently shared/vacant/part-time with free-text notes.
#
# Both PDFs are real structured tables (not scanned images), parsed via
# word-level bounding boxes (pdftools::pdf_data()) rather than plain text
# extraction, since column position is the only reliable way to know
# which cell a number belongs to -- and even then, a cell's content isn't
# always at a single consistent x per column (a wrapped note can start
# closer to a neighboring column than usual), which is why extraction
# uses a tight x-window immediately around each target column's own
# header position rather than a wide bin spanning to the next column.
#
# Fragility: WSBA replaces rather than versions these files on Google
# Drive, so the file IDs below can go stale if they publish a new file at
# a new URL instead of updating the existing one in place -- if a fetch
# here starts returning 0 rows, check the page above for current links.

suppressMessages({
  library(httr2)
  library(pdftools)
  library(dplyr)
})

WSBA_TEACHER_SALARY_PDF_ID <- "1zxHMrGGkHWs_-g7Ao8ja6sugzIgOg1Pr"
WSBA_ADMIN_SALARY_PDF_ID <- "15g-sK33JwzbQsBh6E-7Rr8NWu3VEExWJ"

fetch_google_drive_pdf <- function(file_id, dest = tempfile(fileext = ".pdf")) {
  request(paste0("https://drive.google.com/uc?export=download&id=", file_id)) %>%
    req_perform(path = dest)
  dest
}

# Maps WSBA's abbreviated district names ("Albany #1") to this project's
# canonical district names (matching canonicalize_k12_district()'s output,
# not the raw scraped spelling) -- built explicitly rather than a regex
# transform since two districts (Big Horn, Natrona) don't follow the
# "<Name> County School District <N>" pattern the other 46 do.
canonicalize_wsba_district_name <- function(name) {
  name <- trimws(name)
  pattern <- "^(.+?)\\s*#(\\d+)$"
  matches <- regmatches(name, regexec(pattern, name))
  vapply(matches, function(m) {
    if (length(m) != 3) return(NA_character_)
    county <- m[2]
    num <- m[3]
    if (county %in% c("Big Horn", "Natrona")) {
      paste0(county, " School District ", num)
    } else {
      paste0(county, " County School District ", num)
    }
  }, character(1))
}

# ---------------------------------------------------------------------------
# Teacher base salary
# ---------------------------------------------------------------------------

# The PDF's own title ("2025-2026 TEACHER SALARY SETTLEMENTS") states which
# school year its "current" column actually represents -- deriving this
# from today's date instead would be wrong whenever WSBA hasn't published
# the next year's settlements yet (which is most of the year).
extract_wsba_salary_year <- function(page_data) {
  title_words <- page_data$text[page_data$y < 30]
  year <- title_words[grepl("^[0-9]{4}-[0-9]{4}$", title_words)]
  if (length(year) == 0) NA_character_ else year[1]
}

fetch_wsba_teacher_salary <- function(pdf_path = NULL) {
  path <- if (is.null(pdf_path)) fetch_google_drive_pdf(WSBA_TEACHER_SALARY_PDF_ID) else pdf_path
  page_data <- pdf_data(path)[[1]]
  result <- parse_wsba_teacher_salary(page_data)
  result$Salary_Year <- extract_wsba_salary_year(page_data)
  result
}

parse_wsba_teacher_salary <- function(page_data) {
  d <- page_data[page_data$y > 110, ]
  is_dollar <- grepl("^[0-9]{1,3}(,[0-9]{3})+$", d$text)

  ys <- sort(unique(d$y))
  line_id <- cumsum(c(1, diff(ys) > 4))
  y_to_line <- setNames(line_id, ys)
  d$line <- y_to_line[as.character(d$y)]

  district_lines <- d %>%
    filter(x >= 45, x < 100) %>%
    group_by(line) %>%
    summarize(District = paste(text[order(x)], collapse = " "), y = min(y), .groups = "drop")

  if (nrow(district_lines) == 0) {
    return(data.frame(District = character(0), Base_Salary_Prior_Year = numeric(0),
                       Base_Salary_Current_Year = numeric(0), stringsAsFactors = FALSE))
  }

  anchor_y <- sort(district_lines$y)
  nearest_anchor <- function(y) anchor_y[which.min(abs(anchor_y - y))]

  extract_base <- function(xmin, xmax) {
    d %>%
      filter(is_dollar, x >= xmin, x <= xmax) %>%
      mutate(record_y = vapply(y, nearest_anchor, numeric(1))) %>%
      group_by(record_y) %>%
      summarize(value = as.numeric(gsub(",", "", first(text))), .groups = "drop")
  }

  base_prior <- extract_base(95, 135) %>% rename(Base_Salary_Prior_Year = value)
  base_current <- extract_base(298, 338) %>% rename(Base_Salary_Current_Year = value)

  district_lines %>%
    rename(record_y = y) %>%
    left_join(base_prior, by = "record_y") %>%
    left_join(base_current, by = "record_y") %>%
    mutate(District = canonicalize_wsba_district_name(District)) %>%
    filter(!is.na(District)) %>%
    select(District, Base_Salary_Prior_Year, Base_Salary_Current_Year)
}

# ---------------------------------------------------------------------------
# Superintendent salary
# ---------------------------------------------------------------------------

fetch_wsba_superintendent_salary <- function(pdf_path = NULL) {
  path <- if (is.null(pdf_path)) fetch_google_drive_pdf(WSBA_ADMIN_SALARY_PDF_ID) else pdf_path
  pages <- pdf_data(path)
  raw <- bind_rows(lapply(pages, parse_wsba_superintendent_salary_page))
  raw <- raw[!is.na(raw$District) & nzchar(raw$District), ]
  # The PDF export duplicates each visual page as two PDF pages -- one
  # full copy, one with the same district names but no salary data at
  # the x-positions this looks at. Keep whichever copy actually matched.
  deduped <- raw %>%
    group_by(District) %>%
    summarize(Superintendent_Salary_Days = dplyr::first(stats::na.omit(Superintendent_Salary_Days)), .groups = "drop")

  split <- strsplit(deduped$Superintendent_Salary_Days, "/")
  deduped %>%
    mutate(
      Superintendent_Salary = vapply(split, function(s) if (length(s) == 2) as.numeric(s[1]) else NA_real_, numeric(1)),
      Superintendent_Contract_Days = vapply(split, function(s) if (length(s) == 2) as.numeric(s[2]) else NA_real_, numeric(1))
    ) %>%
    select(District, Superintendent_Salary, Superintendent_Contract_Days)
}

parse_wsba_superintendent_salary_page <- function(page_data) {
  d <- page_data[page_data$y > 100, ]
  is_salary_days <- grepl("^[0-9]{4,7}/[0-9]{2,3}$", d$text)

  ys <- sort(unique(d$y))
  if (length(ys) == 0) {
    return(data.frame(District = character(0), Superintendent_Salary_Days = character(0),
                       stringsAsFactors = FALSE))
  }
  line_id <- cumsum(c(1, diff(ys) > 4))
  y_to_line <- setNames(line_id, ys)
  d$line <- y_to_line[as.character(d$y)]

  district_lines <- d %>%
    filter(x >= 15, x < 90) %>%
    group_by(line) %>%
    summarize(District = paste(text[order(x)], collapse = " "), y = min(y), .groups = "drop")

  if (nrow(district_lines) == 0) {
    return(data.frame(District = character(0), Superintendent_Salary_Days = character(0),
                       stringsAsFactors = FALSE))
  }

  anchor_y <- sort(district_lines$y)
  nearest_anchor <- function(y) anchor_y[which.min(abs(anchor_y - y))]

  supt <- d %>%
    filter(is_salary_days, x >= 195, x <= 260) %>%
    mutate(record_y = vapply(y, nearest_anchor, numeric(1))) %>%
    group_by(record_y) %>%
    summarize(Superintendent_Salary_Days = dplyr::first(text), .groups = "drop")

  district_lines %>%
    rename(record_y = y) %>%
    left_join(supt, by = "record_y") %>%
    mutate(District = canonicalize_wsba_district_name(District)) %>%
    select(District, Superintendent_Salary_Days)
}
