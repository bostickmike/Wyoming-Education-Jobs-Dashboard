library(shiny)
library(shinydashboard)
library(shinyWidgets)
library(tidyverse)
library(DT)
library(data.table)
library(leaflet)
library(plotly)
library(scales)
library(stringr)
library(readxl)
library(shinycssloaders)

#--------------------------------------------------
# Load K-12 data
#--------------------------------------------------
combineddata <- read.csv("combinedclean.csv", fileEncoding = "UTF-8") %>%
  select(District, title, position, location, date_posted, url) %>%
  mutate(District = str_squish(as.character(District))) %>%
  arrange(District, title) %>%
  mutate(url = paste0('<a href="', url, '" target="_blank">', url, '</a>')) %>%
  rename(Title = title, Position = position, Location = location,
         `Date Posted` = date_posted, Link = url)

mapdata2_k12 <- read.csv("salarymap2.csv", fileEncoding = "UTF-8") %>%
  rename(Name = District)

# Weekly ALL-category posting totals per district/institution (not scoped
# to Teacher/Faculty like k12_history/he_history below) -- powers the
# sparkline trend next to each entity's raw count on the Top Hiring
# tables, matching that same all-category count rather than a
# teacher/faculty-only proxy that wouldn't line up with the number shown.
k12_district_weekly_totals <- read.csv("k12_district_weekly_totals.csv", fileEncoding = "UTF-8") %>%
  mutate(Archive_Date = as.Date(Archive_Date))
he_institution_weekly_totals <- read.csv("he_institution_weekly_totals.csv", fileEncoding = "UTF-8") %>%
  mutate(Archive_Date = as.Date(Archive_Date))

# Tiny inline trend chart (no axes/legend, just the shape of a trend) for
# the Top Hiring tables -- lets "31 openings" read differently depending
# on whether that's a district climbing steadily or one that just posted a
# batch this week, without a separate chart. Plain SVG string templating
# rather than a real ggplot/plotly render, since this needs to be cheap
# enough to generate per table row.
make_sparkline_svg <- function(series, accent = "#2a78d6") {
  series <- series[!is.na(series)]
  if (length(series) < 2) return("")

  w <- 96; h <- 28; pad <- 3
  rng <- range(series)
  span <- diff(rng)
  if (span == 0) span <- 1

  n <- length(series)
  step_x <- (w - pad * 2) / (n - 1)
  xs <- pad + (seq_len(n) - 1) * step_x
  ys <- pad + (1 - (series - rng[1]) / span) * (h - pad * 2)

  line_path <- paste0(ifelse(seq_along(xs) == 1, "M", "L"), round(xs, 1), ",", round(ys, 1), collapse = " ")
  area_path <- paste0(line_path, " L", round(xs[n], 1), ",", h - pad, " L", round(xs[1], 1), ",", h - pad, " Z")

  dot_color <- if (series[n] > series[1]) "#1baf7a" else if (series[n] < series[1]) "#e34948" else "#999999"

  sprintf(
    '<svg width="%d" height="%d" viewBox="0 0 %d %d" style="vertical-align:middle;"><path d="%s" fill="%s22" stroke="none"></path><path d="%s" fill="none" stroke="%s" stroke-width="1.75" stroke-linejoin="round" stroke-linecap="round"></path><circle cx="%s" cy="%s" r="2.5" fill="%s"></circle></svg>',
    w, h, w, h, area_path, accent, line_path, accent, round(xs[n], 1), round(ys[n], 1), dot_color
  )
}

k12sum <- read.csv("allsum.csv", fileEncoding = "UTF-8") %>%
  mutate(District = str_squish(as.character(District)),
         Broad_Category = dplyr::recode(Broad_Category,
                                        "English Language Arts Secondary" = "Engl. LA",
                                        "Secondary Social Studies" = "Soc. St.",
                                        "Special Education - General" = "SpEd - General",
                                        "Special Education - Resource/Life Skills" = "SpEd - Resource/LS",
                                        "CTE - Trades, Ag & Technical" = "CTE - Trades/Ag",
                                        "CTE - Business & Family Sciences" = "CTE - Biz/Family")) %>%
  filter(Broad_Category != "Other")

k12sum$Archive_Date <- as.Date(k12sum$Archive_Date)

# The source aggregation (group_by + summarize) only produces a row for a
# Broad_Category/Archive_Date/District combination that actually had at
# least one posting -- a week with zero postings for a category is simply
# absent, not an explicit 0. geom_line() then draws straight through that
# gap, silently connecting the surrounding weeks and making it look like
# the count never dropped. tidyr::complete() fills every combination that
# doesn't exist with a real 0 so the line actually dips.
k12sum <- k12sum %>%
  tidyr::complete(Broad_Category, Archive_Date, District, fill = list(sum = 0))


k12nowsum <- read.csv("allnow.csv", fileEncoding = "UTF-8") %>%
  mutate(Broad_Category = dplyr::recode(Broad_Category,
                                        "English Language Arts Secondary" = "Engl. LA",
                                        "Secondary Social Studies" = "Soc. St.",
                                        "Special Education - General" = "SpEd - General",
                                        "Special Education - Resource/Life Skills" = "SpEd - Resource/LS",
                                        "CTE - Trades, Ag & Technical" = "CTE - Trades/Ag",
                                        "CTE - Business & Family Sciences" = "CTE - Biz/Family"),
         District = str_squish(iconv(District, from = "", to = "UTF-8"))) %>%
  filter(Broad_Category != "Other")

#--------------------------------------------------
# Load Higher Ed data
#--------------------------------------------------
ccdata <- read_xlsx("hedata.xlsx") %>%
  select(Institution, Title, Location, Posted_Date, Link) %>%
  arrange(Institution, Title) %>%
  rename(`Date Posted` = Posted_Date)
ccdata$Link <- paste0('<a href="', ccdata$Link, '" target="_blank">', ccdata$Link, '</a>')

mapdata2_he <- read.csv("salarymap.csv") %>%
  mutate(Salary_Year = as.character(Salary_Year))

hesum_he <- read.csv("allsum_he.csv") %>%
  filter(Category != "Uncategorized")

hesum_he$Archive_Date <- as.Date(hesum_he$Archive_Date)

# Same gap-filling as k12sum above -- a Category/Institution/Job_Type
# combination with zero postings in a given week is simply missing from
# the source aggregation, not an explicit 0.
hesum_he <- hesum_he %>%
  tidyr::complete(Category, Archive_Date, Institution, Job_Type, fill = list(sum = 0))
he_dates <- sort(unique(hesum_he$Archive_Date))
WINDOW_WEEKS <- 52
hesum_he$Category<- as.factor(hesum_he$Category)

henowsum_he <- read.csv("allnow_he.csv") %>%
  filter(Category != "Uncategorized")

last_refreshed_date <- format(max(k12sum$Archive_Date, hesum_he$Archive_Date, na.rm = TRUE), "%B %d, %Y")

#--------------------------------------------------
# Simple rollups -- a 2026-08-04 audit found several badly-oversized,
# artificially-merged categories (K-12 "Special Education" alone was 3,239
# postings; HE "CTE" was 5,834, three times the next-largest real
# category) and split them into coherent sub-groups. That's more accurate,
# but too many categories at once makes the longitudinal line charts an
# unreadable tangle -- and a first attempt at an "Aggregated" view that
# just undid those specific splits (13-16 categories) turned out to still
# be nearly as busy as "Detailed" (16-18 categories), not a real second
# option. "Simple" instead collapses every detailed category into ~5 broad
# groups chosen from real posting volume (see git history for the specific
# percentages), matching how school/college staffing is actually organized
# -- e.g. K-12 elementary-generalist vs special-ed vs secondary-subject vs
# CTE vs enrichment, HE by division. Both levels stay available via a
# toggle rather than picking one and losing the other.
#--------------------------------------------------
k12_collapse_map <- c(
  "Elementary" = "Elementary & Early Childhood",
  "Early Childhood" = "Elementary & Early Childhood",
  "SpEd - General" = "Special Education",
  "SpEd - Resource/LS" = "Special Education",
  "Math" = "Core Academic",
  "Science" = "Core Academic",
  "Engl. LA" = "Core Academic",
  "Soc. St." = "Core Academic",
  "Language" = "Core Academic",
  "CTE - Trades/Ag" = "CTE",
  "CTE - Biz/Family" = "CTE",
  "Music" = "Arts & Enrichment",
  "Art" = "Arts & Enrichment",
  "Physical Education" = "Arts & Enrichment",
  "Library Media" = "Arts & Enrichment",
  "Gifted and Talented" = "Arts & Enrichment"
)

k12sum_agg <- k12sum %>%
  mutate(Broad_Category = dplyr::recode(Broad_Category, !!!k12_collapse_map)) %>%
  group_by(Broad_Category, Archive_Date, District) %>%
  summarize(sum = sum(sum), .groups = "drop")

k12nowsum_agg <- k12nowsum %>%
  mutate(Broad_Category = dplyr::recode(Broad_Category, !!!k12_collapse_map)) %>%
  group_by(Broad_Category, District) %>%
  summarize(Sum = sum(Sum), .groups = "drop")

he_collapse_map <- c(
  "CTE - Trades & Engineering" = "CTE / Career-Technical",
  "CTE - Health Sciences" = "CTE / Career-Technical",
  "CTE - Business & Computing" = "CTE / Career-Technical",
  "Culinary/Hospitality" = "CTE / Career-Technical",
  "Science" = "STEM",
  "Math" = "STEM",
  "Humanities" = "Humanities & Social Sciences",
  "Social Science" = "Humanities & Social Sciences",
  "History" = "Humanities & Social Sciences",
  "Language" = "Humanities & Social Sciences",
  "Criminal Justice" = "Humanities & Social Sciences",
  "Legal" = "Humanities & Social Sciences",
  "Human Services" = "Humanities & Social Sciences",
  "Education" = "Humanities & Social Sciences",
  "The Arts" = "Arts & Physical Education",
  "Physical Education" = "Arts & Physical Education",
  "Extension/Outreach" = "Extension/Outreach & Library",
  "Library" = "Extension/Outreach & Library"
)

hesum_he_agg <- hesum_he %>%
  mutate(Category = dplyr::recode(as.character(Category), !!!he_collapse_map)) %>%
  group_by(Category, Archive_Date, Institution, Job_Type) %>%
  summarize(sum = sum(sum), .groups = "drop")

henowsum_he_agg <- henowsum_he %>%
  mutate(Category = dplyr::recode(Category, !!!he_collapse_map)) %>%
  group_by(Category, Institution, Job_Type) %>%
  summarize(Sum = sum(Sum), .groups = "drop")

#--------------------------------------------------
# Category colors -- one fixed hex per category, shared by every chart in
# its section, so a category is never a different color on the current-
# snapshot chart than on the longitudinal chart. First 8 slots (by
# all-time volume) are the validated categorical palette from the dataviz
# skill (fixed order, CVD-checked); slots past 8 extend it with additional
# well-separated hues for the lower-volume categories rather than
# reusing/cycling a slot. Separate palettes for the Simple and Detailed
# views since they're different category sets, not just different labels.
#--------------------------------------------------
EXT_HUES <- c("#8B5E34", "#5C7A99", "#7A7A3D", "#767671", "#2E8B87",
              "#C77DA8", "#B8860B", "#6B5B95", "#4A6670", "#D97757")
BASE8 <- c("#2a78d6", "#eb6834", "#1baf7a", "#eda100", "#e87ba4", "#008300", "#4a3aa7", "#e34948")

# Ordered by real posting volume: Special Education 28%, Core Academic 27%,
# Elementary & Early Childhood 22%, Arts & Enrichment 15%, CTE 9%.
K12_CATEGORY_COLORS_AGG <- setNames(BASE8[1:5], c(
  "Special Education", "Core Academic", "Elementary & Early Childhood",
  "Arts & Enrichment", "CTE"
))

K12_CATEGORY_COLORS_DETAIL <- setNames(c(BASE8, EXT_HUES[1:8]), c(
  "Elementary", "SpEd - General", "SpEd - Resource/LS", "Music", "Math",
  "Engl. LA", "Science", "CTE - Trades/Ag", "Language", "CTE - Biz/Family",
  "Soc. St.", "Physical Education", "Early Childhood", "Art", "Library Media",
  "Gifted and Talented"
))

# Ordered by real posting volume: CTE/Career-Technical 45%, Humanities &
# Social Sciences 21%, STEM 19%, Arts & PE 9%, Extension/Outreach & Library 6%.
HE_CATEGORY_COLORS_AGG <- setNames(BASE8[1:5], c(
  "CTE / Career-Technical", "Humanities & Social Sciences", "STEM",
  "Arts & Physical Education", "Extension/Outreach & Library"
))

HE_CATEGORY_COLORS_DETAIL <- setNames(c(BASE8, EXT_HUES), c(
  "CTE - Trades & Engineering", "Science", "CTE - Health Sciences", "CTE - Business & Computing",
  "The Arts", "Humanities", "Social Science", "Extension/Outreach", "Math",
  "History", "Education", "Culinary/Hospitality", "Physical Education",
  "Library", "Language", "Criminal Justice", "Legal", "Human Services"
))

# Full-time-vs-adjunct split for the "Current Faculty Trends" stacked bar
# only -- Category is already on that chart's x-axis, so color there
# encodes Job_Type instead (coloring by Category too would be redundant
# with position). Top two validated categorical slots for max contrast.
HE_JOB_TYPE_COLORS <- c(
  "Full-Time Faculty" = "#2a78d6",
  "Adjunct/Part-Time"  = "#eb6834"
)

#--------------------------------------------------
# "New this week" -- row-level history, diffed against the previous
# archived week by (identity columns), scoped to Teacher/Faculty postings
# same as the rest of the trend tabs (k12jobanalysis.csv/facultydata.csv
# are already filtered that way upstream).
#--------------------------------------------------
k12_history <- read.csv("k12jobanalysis.csv", fileEncoding = "UTF-8") %>%
  mutate(Archive_Date = as.Date(Archive_Date))

k12_new_this_week <- {
  dates <- sort(unique(k12_history$Archive_Date))
  if (length(dates) >= 2) {
    latest <- dates[length(dates)]
    previous <- dates[length(dates) - 1]
    k12_history %>%
      filter(Archive_Date == latest) %>%
      anti_join(k12_history %>% filter(Archive_Date == previous), by = c("title", "location", "District"))
  } else {
    k12_history[0, ]
  }
}

he_history <- read.csv("facultydata.csv", fileEncoding = "UTF-8") %>%
  mutate(Archive_Date = as.Date(Archive_Date)) %>%
  filter(Job_Type == "Instructor/Teacher/Faculty")

he_new_this_week <- {
  dates <- sort(unique(he_history$Archive_Date))
  if (length(dates) >= 2) {
    latest <- dates[length(dates)]
    previous <- dates[length(dates) - 1]
    he_history %>%
      filter(Archive_Date == latest) %>%
      anti_join(he_history %>% filter(Archive_Date == previous), by = c("Title", "Location", "Institution"))
  } else {
    he_history[0, ]
  }
}

#--------------------------------------------------
# Combined map dataset -- one row per K-12 district or HE institution,
# merging each entity's existing location/salary reference data with a
# live current-openings count, a couple of sample current titles, and a
# new-this-week count (reusing k12_new_this_week/he_new_this_week above,
# so it's the same Teacher/Faculty-scoped definition of "new" as the New
# This Week tabs, not a separate metric).
#--------------------------------------------------
k12_current_counts <- combineddata %>% count(District, name = "CurrentCount")
k12_sample_titles <- combineddata %>%
  group_by(District) %>%
  summarize(SampleTitles = paste(head(Title, 3), collapse = "; "), .groups = "drop")
k12_weekly_new <- k12_new_this_week %>% count(District, name = "WeeklyNew")

# Teacher-only current postings (k12_history is already scoped to
# position == "Teacher", same as the Teacher Trends tabs), for a vacancy
# rate scoped consistently with its denominator (Teachers_Total_FTE from
# CCD, also teacher-only) -- dividing ALL open postings (bus drivers,
# coaches, custodians, etc. included) by teacher FTE would overstate the
# rate by mixing categories that don't correspond to each other.
# Vacancy rate needs a minimum FTE to be a meaningful comparison -- 1
# opening out of 1 teacher is a "100%" rate that isn't really comparable
# to Laramie County's ~5% on a base of 1,067 teachers. Currently a no-op
# against real data (every WY district/institution has 15+ FTE), but
# keeps a future small entity from producing a noisy, misleading rate.
VACANCY_RATE_MIN_FTE <- 10

k12_teacher_current_counts <- k12_history %>%
  filter(Archive_Date == max(Archive_Date)) %>%
  count(District, name = "TeacherCurrentCount")

map_k12 <- mapdata2_k12 %>%
  left_join(k12_current_counts, by = c("Name" = "District")) %>%
  left_join(k12_sample_titles, by = c("Name" = "District")) %>%
  left_join(k12_weekly_new, by = c("Name" = "District")) %>%
  left_join(k12_teacher_current_counts, by = c("Name" = "District")) %>%
  mutate(
    CurrentCount = coalesce(CurrentCount, 0L),
    WeeklyNew = coalesce(WeeklyNew, 0L),
    SampleTitles = coalesce(SampleTitles, ""),
    Type = "K-12 District",
    TeacherCurrentCount = coalesce(TeacherCurrentCount, 0L),
    Vacancy_Rate = ifelse(!is.na(Teachers_Total_FTE) & Teachers_Total_FTE >= VACANCY_RATE_MIN_FTE,
                           TeacherCurrentCount / Teachers_Total_FTE, NA_real_),
    Vacancy_Numerator = TeacherCurrentCount, Vacancy_Denominator = Teachers_Total_FTE,
    Faculty_Avg_Salary = NA_real_, Faculty_Avg_Salary_Professor = NA_real_, Faculty_Count = NA_real_,
    Salary_Note = NA_character_
  ) %>%
  select(Name, Longitude, Latitude, Type, CurrentCount, WeeklyNew, SampleTitles,
         Link = Job_Link, Teacher_Base_Salary, Teacher_Base_Salary_Prior_Year, Salary_Year,
         Superintendent_Salary, Superintendent_Contract_Days,
         Faculty_Avg_Salary, Faculty_Avg_Salary_Professor, Faculty_Count, Salary_Note,
         Vacancy_Rate, Vacancy_Numerator, Vacancy_Denominator, Salary_Source, Salary_Updated, County)

he_current_counts <- ccdata %>% count(Institution, name = "CurrentCount")
he_sample_titles <- ccdata %>%
  group_by(Institution) %>%
  summarize(SampleTitles = paste(head(Title, 3), collapse = "; "), .groups = "drop")
he_weekly_new <- he_new_this_week %>% count(Institution, name = "WeeklyNew")

# he_history is already scoped to Job_Type == "Instructor/Teacher/Faculty"
# (full-time only, excluding the standing adjunct pool) -- matches
# Faculty_Count's own scope, since IPEDS's salaries-instructional-staff
# survey only covers full-time instructional staff. Mixing in
# Adjunct/Part-Time postings here would overstate the rate the same way
# using CurrentCount (all K-12 job categories) would on the K-12 side.
he_faculty_current_counts <- he_history %>%
  filter(Archive_Date == max(Archive_Date)) %>%
  count(Institution, name = "FacultyCurrentCount")

map_he <- mapdata2_he %>%
  left_join(he_current_counts, by = c("Name" = "Institution")) %>%
  left_join(he_sample_titles, by = c("Name" = "Institution")) %>%
  left_join(he_weekly_new, by = c("Name" = "Institution")) %>%
  left_join(he_faculty_current_counts, by = c("Name" = "Institution")) %>%
  mutate(
    CurrentCount = coalesce(CurrentCount, 0L),
    WeeklyNew = coalesce(WeeklyNew, 0L),
    SampleTitles = coalesce(SampleTitles, ""),
    Type = "Higher Ed Institution",
    FacultyCurrentCount = coalesce(FacultyCurrentCount, 0L),
    # Sheridan College and Gillette College (flagged via Salary_Note) share
    # one IPEDS-reported Faculty_Count -- dividing either institution's own
    # posting count by that joint total isn't a real per-campus rate (it
    # inflated Sheridan to 66% in testing, since its numerator is compared
    # against a denominator that's really Sheridan+Gillette combined), so
    # both are suppressed here rather than shown as if they were exact.
    Vacancy_Rate = ifelse(!is.na(Faculty_Count) & Faculty_Count >= VACANCY_RATE_MIN_FTE & is.na(Salary_Note),
                           FacultyCurrentCount / Faculty_Count, NA_real_),
    Vacancy_Numerator = FacultyCurrentCount, Vacancy_Denominator = Faculty_Count,
    Teacher_Base_Salary = NA_real_, Teacher_Base_Salary_Prior_Year = NA_real_,
    Superintendent_Salary = NA_real_, Superintendent_Contract_Days = NA_real_,
    County = NA_character_
  ) %>%
  select(Name, Longitude, Latitude, Type, CurrentCount, WeeklyNew, SampleTitles,
         Link, Teacher_Base_Salary, Teacher_Base_Salary_Prior_Year, Salary_Year,
         Superintendent_Salary, Superintendent_Contract_Days,
         Faculty_Avg_Salary, Faculty_Avg_Salary_Professor, Faculty_Count, Salary_Note,
         Vacancy_Rate, Vacancy_Numerator, Vacancy_Denominator, Salary_Source, Salary_Updated, County)

combined_map_data <- bind_rows(map_k12, map_he)

#--------------------------------------------------
# UI
#--------------------------------------------------
ui <- dashboardPage(
  skin = 'black',
  dashboardHeader(title = "Wyoming Education Careers"),
  dashboardSidebar(
    sidebarMenu(
      id = "sidebar_tabs",
      menuItem("Map", tabName = "intro", icon = icon("home")),
      menuItem("K-12 Careers", tabName = "k12_root", icon = icon("school"),
               menuSubItem("Jobs Table", tabName = "k12_table"),
               menuSubItem("District Summary", tabName = "k12_summary"),
               menuSubItem("Longitudinal Teacher Trends", tabName = "k12_trends"),
               menuSubItem("Current Teacher Trends", tabName = "k12_current"),
               menuSubItem("New This Week", tabName = "k12_new")
      ),
      menuItem("Higher Ed Careers", tabName = "he_root", icon = icon("university"),
               menuSubItem("Jobs Table", tabName = "he_table"),
               menuSubItem("Institution Summary", tabName = "he_summary"),
               menuSubItem("Longitudinal Faculty Trends", tabName = "he_trends"),
               menuSubItem("Current Faculty Trends", tabName = "he_current"),
               menuSubItem("New This Week", tabName = "he_new")
      )
    )
  ),
  dashboardBody(
    tags$head(
      tags$style(HTML("
    .leaflet-tooltip {
      max-width: 800px !important;  /* make tooltip wide */
      min-width: 400px !important;  /* optional: ensures minimum width */
      white-space: normal !important;  /* text can wrap if needed */
      background-color: rgba(255,255,255,0.95);
      padding: 6px 10px;
      border-radius: 6px;
      border: 1px solid gray;
      font-size: 14px;
      display: inline-block;
    }
  ")),
      tags$script(HTML("
    // On mobile, AdminLTE's sidebar opens as a full-width overlay (body
    // gets a 'sidebar-open' class) and, unlike the desktop mini-sidebar
    // behavior, never closes itself after a link is clicked -- it stays
    // open over the content until manually toggled. Only real navigation
    // links carry data-toggle='tab' (a treeview parent like 'K-12 Careers'
    // that just expands/collapses its submenu doesn't), so this closes the
    // sidebar specifically when the user has actually navigated somewhere,
    // not when they're just opening a category.
    $(document).on('click', '.sidebar-menu a[data-toggle=\"tab\"]', function() {
      if ($(window).width() < 768) {
        $('body').removeClass('sidebar-open');
      }
    });
  "))
    )
    ,
    tabItems(
      # ------------------ Global Introduction ------------------
      tabItem(
        tabName = "intro",
        h1("Education Jobs in Wyoming"),
        fluidRow(
          valueBoxOutput("kpi_k12_total", width = 4),
          valueBoxOutput("kpi_he_total", width = 4),
          valueBoxOutput("kpi_last_refreshed", width = 4)
        ),
        box(width = 12, title = "Where the openings are", status = "primary",
            checkboxGroupInput(
              "map_types", "Show:",
              choices = c("K-12 Districts" = "K-12 District", "Higher Ed Institutions" = "Higher Ed Institution"),
              selected = c("K-12 District", "Higher Ed Institution"),
              inline = TRUE
            ),
            withSpinner(leafletOutput("combined_map", height = 600)),
            helpText("Only locations with current openings are shown. Click a marker to jump to its filtered Jobs Table.")
        ),
        fluidRow(
          box(title = "Top K-12 Hiring Districts This Week", width = 6, status = "primary",
              tableOutput("top_k12_districts")),
          box(title = "Top Higher Ed Hiring Institutions This Week", width = 6, status = "primary",
              tableOutput("top_he_institutions"))
        ),
        fluidRow(
          box(title = "Highest Teacher Vacancy Rate", width = 6, status = "primary",
              withSpinner(plotlyOutput("k12_vacancy_leaderboard", height = 320)),
              helpText("Districts with at least", VACANCY_RATE_MIN_FTE, "teacher FTE.")),
          box(title = "Highest Faculty Vacancy Rate", width = 6, status = "primary",
              withSpinner(plotlyOutput("he_vacancy_leaderboard", height = 320)),
              helpText("Institutions with at least", VACANCY_RATE_MIN_FTE, "full-time faculty."))
        ),
        div(style = "text-align:center; color:#999; font-size:0.85em; padding:15px;",
            paste0("Refreshed on: ", last_refreshed_date, " · Programmed by Mark Perkins and Mike Bostick"))
      ),

      tabItem(
        tabName = "k12_table",
        uiOutput("k12_filter_status"),
        DTOutput("k12_jobs")
      ),
      tabItem(
        tabName = "k12_summary",
        h4("One row per district -- current openings, teacher vacancy rate, and salary data"),
        DTOutput("k12_summary_table")
      ),
      tabItem(
        tabName = "k12_new",
        h4("New teacher postings since the previous weekly snapshot"),
        DTOutput("k12_new_table")
      ),

      # ------------------ K-12 ------------------
      tabItem(
        tabName = "k12_trends",

        radioButtons("k12_detail_level_trends", "Category detail:",
                     choices = c("Simple" = "agg", "Detailed" = "detail"),
                     selected = "agg", inline = TRUE),

        # Row for category + district
        fluidRow(
          column(
            width = 6,  # half the row
            pickerInput(
              "broad_category",
              "Choose Teacher Category:",
              choices  = sort(unique(k12sum_agg$Broad_Category)),
              selected = sort(unique(k12sum_agg$Broad_Category)),
              multiple = TRUE,
              width = "100%",
              options = pickerOptions(actionsBox = TRUE, liveSearch = TRUE, selectedTextFormat = "count > 3")
            )
          ),
          column(
            width = 6,  # other half
            selectInput(
              "district_trend",
              "Choose District:",
              choices = sort(unique(k12sum$District)),
              selected = "Total",
              width = "100%"
            )
          )
        ),
        
        # Timeline slider (full width)
        sliderInput(
          "k12_scroll",
          "Scroll timeline:",
          min = min(k12sum$Archive_Date),
          max = max(k12sum$Archive_Date),
          value = c(max(k12sum$Archive_Date) - 365,
                    max(k12sum$Archive_Date)),
          timeFormat = "%Y-%m-%d",
          width = "100%"
        ),
        
        # Plot output
        withSpinner(plotlyOutput("k12_longitudinal_plot"))
      ),
      
      tabItem(
        tabName = "k12_current",

        radioButtons("k12_detail_level_current", "Category detail:",
                     choices = c("Simple" = "agg", "Detailed" = "detail"),
                     selected = "agg", inline = TRUE),

        selectInput(
          "district_current",
          "Choose District:",
          choices = sort(unique(k12nowsum$District)),
          selected = "Total"
        ),

        withSpinner(plotlyOutput("k12_current_plot"))
      ),
      
      # ------------------ Higher Ed ------------------
      tabItem(
        tabName = "he_table",
        uiOutput("he_filter_status"),
        DTOutput("he_jobs")
      ),
      tabItem(
        tabName = "he_summary",
        h4("One row per institution -- current openings, faculty vacancy rate, and salary data"),
        DTOutput("he_summary_table")
      ),
      tabItem(
        tabName = "he_trends",

        radioButtons("he_detail_level_trends", "Category detail:",
                     choices = c("Simple" = "agg", "Detailed" = "detail"),
                     selected = "agg", inline = TRUE),

        # Row for Category + Institution
        fluidRow(
          column(
            width = 6,
            pickerInput(
              "he_category",
              "Choose Category:",
              choices  = sort(unique(hesum_he_agg$Category)),
              selected = sort(unique(hesum_he_agg$Category)),
              multiple = TRUE,
              width = "100%",
              options = pickerOptions(actionsBox = TRUE, liveSearch = TRUE, selectedTextFormat = "count > 3")
            )
          ),
          column(
            width = 6,
            selectInput(
              "inst_trend",
              "Select Institution:",
              choices = sort(unique(hesum_he$Institution)),
              selected = "Total",
              width = "100%"
            )
          )
        ),
        
        # Timeline slider (full width)
        textOutput("he_slider_label"),  # optional label
        sliderInput(
          "he_scroll",
          "Scroll timeline:",
          min = min(hesum_he$Archive_Date),
          max = max(hesum_he$Archive_Date),
          value = c(
            max(hesum_he$Archive_Date) - 365,
            max(hesum_he$Archive_Date)
          ),
          timeFormat = "%Y-%m-%d",
          width = "100%"
        ),
        
        radioButtons("he_chart_type", NULL, choices = c(
          "All Jobs" = "all",
          "Full Time" = "Instructor/Teacher/Faculty",
          "Part Time" = "Adjunct/Part-Time Faculty"
        ), selected = "all", inline = TRUE),

        # Plot output
        withSpinner(plotlyOutput("he_longitudinal_plot"))),
      
      tabItem(tabName = "he_current",
              radioButtons("he_detail_level_current", "Category detail:",
                           choices = c("Simple" = "agg", "Detailed" = "detail"),
                           selected = "agg", inline = TRUE),
              selectInput("inst_current", "Select Institution:",
                          choices = sort(unique(henowsum_he$Institution)), selected = "Total"),
              withSpinner(plotlyOutput("he_current_plot"))),

      tabItem(
        tabName = "he_new",
        h4("New faculty postings since the previous weekly snapshot"),
        DTOutput("he_new_table")
      )
    )
  )
)


#--------------------------------------------------
# Server
#--------------------------------------------------
server <- function(input, output, session) {

  # Set by clicking a marker on the combined map; cleared by the "Show
  # All" button on each Jobs Table tab.
  selected_district <- reactiveVal(NULL)
  selected_institution <- reactiveVal(NULL)

  # -------- Intro KPIs --------
  output$kpi_k12_total <- renderValueBox({
    valueBox(format(nrow(combineddata), big.mark = ","), "Open K-12 Postings",
             icon = icon("school"), color = "blue")
  })
  output$kpi_he_total <- renderValueBox({
    valueBox(format(nrow(ccdata), big.mark = ","), "Open Higher Ed Postings",
             icon = icon("university"), color = "purple")
  })
  output$kpi_last_refreshed <- renderValueBox({
    valueBox(last_refreshed_date, "Last Refreshed", icon = icon("calendar"), color = "green")
  })

  output$top_k12_districts <- renderTable({
    top <- combineddata %>% count(District, sort = TRUE, name = "Open Postings") %>% head(5)
    top$`Last 12 Weeks` <- vapply(top$District, function(d) {
      series <- k12_district_weekly_totals %>%
        filter(District == d) %>%
        arrange(Archive_Date) %>%
        tail(12) %>%
        pull(n)
      make_sparkline_svg(series, accent = "#2a78d6")
    }, character(1))
    top
  }, sanitize.text.function = function(x) x)

  output$top_he_institutions <- renderTable({
    top <- ccdata %>% count(Institution, sort = TRUE, name = "Open Postings") %>% head(5)
    top$`Last 12 Weeks` <- vapply(top$Institution, function(inst) {
      series <- he_institution_weekly_totals %>%
        filter(Institution == inst) %>%
        arrange(Archive_Date) %>%
        tail(12) %>%
        pull(n)
      make_sparkline_svg(series, accent = "#4a3aa7")
    }, character(1))
    top
  }, sanitize.text.function = function(x) x)

  # Vacancy-rate leaderboards -- a different question from the raw-count
  # tables above ("who's short-staffed relative to their size" rather than
  # "who's hiring the most"), so they sit alongside rather than replacing
  # them. Same horizontal-bar, ranked-descending pattern as the Current
  # Trends charts. combined_map_data's Vacancy_Rate is already NA below
  # VACANCY_RATE_MIN_FTE, so no separate floor check is needed here.
  output$k12_vacancy_leaderboard <- renderPlotly({
    df <- combined_map_data %>%
      filter(Type == "K-12 District", !is.na(Vacancy_Rate)) %>%
      arrange(desc(Vacancy_Rate)) %>%
      head(8)
    req(nrow(df) > 0)

    plot <- ggplot(df, aes(x = reorder(Name, Vacancy_Rate), y = Vacancy_Rate,
                            text = paste0(Name, ": ", Vacancy_Numerator, " / ", Vacancy_Denominator,
                                          " = ", scales::percent(Vacancy_Rate, accuracy = 0.1)))) +
      geom_bar(stat = "identity", fill = "#2a78d6") +
      geom_text(aes(label = scales::percent(Vacancy_Rate, accuracy = 0.1)), hjust = -0.15, size = 3) +
      labs(x = NULL, y = "Teacher vacancy rate") +
      scale_y_continuous(labels = scales::percent, expand = expansion(mult = c(0, 0.2))) +
      coord_flip() +
      theme_minimal()

    ggplotly(plot, tooltip = "text")
  })

  output$he_vacancy_leaderboard <- renderPlotly({
    df <- combined_map_data %>%
      filter(Type == "Higher Ed Institution", !is.na(Vacancy_Rate)) %>%
      arrange(desc(Vacancy_Rate)) %>%
      head(8)
    req(nrow(df) > 0)

    plot <- ggplot(df, aes(x = reorder(Name, Vacancy_Rate), y = Vacancy_Rate,
                            text = paste0(Name, ": ", Vacancy_Numerator, " / ", Vacancy_Denominator,
                                          " = ", scales::percent(Vacancy_Rate, accuracy = 0.1)))) +
      geom_bar(stat = "identity", fill = "#4a3aa7") +
      geom_text(aes(label = scales::percent(Vacancy_Rate, accuracy = 0.1)), hjust = -0.15, size = 3) +
      labs(x = NULL, y = "Faculty vacancy rate") +
      scale_y_continuous(labels = scales::percent, expand = expansion(mult = c(0, 0.2))) +
      coord_flip() +
      theme_minimal()

    ggplotly(plot, tooltip = "text")
  })

  # -------- New This Week --------
  output$k12_new_table <- renderDT({
    datatable(
      k12_new_this_week %>% select(title, District, location, Broad_Category, url),
      options = list(scrollX = TRUE)
    )
  })
  output$he_new_table <- renderDT({
    datatable(
      he_new_this_week %>% select(Title, Institution, Location, Category, Link),
      options = list(scrollX = TRUE)
    )
  })

  # -------- K-12 --------
  output$k12_jobs <- renderDT({
    df <- combineddata
    if (!is.null(selected_district())) df <- df %>% filter(District == selected_district())
    datatable(df, filter = "top", escape = FALSE, extensions = "Buttons",
              options = list(scrollX = TRUE, dom = "Bfrtip", buttons = c("copy", "csv", "print")))
  })

  output$k12_filter_status <- renderUI({
    if (is.null(selected_district())) return(NULL)
    div(style = "margin-bottom: 10px;",
        strong(paste("Showing:", selected_district())),
        actionButton("clear_k12_filter", "Show All Districts", class = "btn-xs", style = "margin-left: 10px;")
    )
  })
  observeEvent(input$clear_k12_filter, { selected_district(NULL) })

  # District Summary -- everything the map popups show (vacancy rate,
  # salary figures, source/date), but as a real exportable table instead
  # of something only visible one marker at a time.
  output$k12_summary_table <- renderDT({
    df <- combined_map_data %>%
      filter(Type == "K-12 District") %>%
      arrange(desc(CurrentCount)) %>%
      transmute(
        District = Name,
        County,
        `Current Openings` = CurrentCount,
        `New This Week` = WeeklyNew,
        `Teacher Vacancy Rate` = ifelse(is.na(Vacancy_Rate), NA_character_, scales::percent(Vacancy_Rate, accuracy = 0.1)),
        `Teacher Base Salary` = ifelse(is.na(Teacher_Base_Salary), NA_character_, scales::dollar(Teacher_Base_Salary)),
        `Prior Year` = ifelse(is.na(Teacher_Base_Salary_Prior_Year), NA_character_, scales::dollar(Teacher_Base_Salary_Prior_Year)),
        `Salary Year` = Salary_Year,
        `Superintendent Salary` = ifelse(is.na(Superintendent_Salary), NA_character_, scales::dollar(Superintendent_Salary)),
        `Salary Source` = Salary_Source,
        `Salary Updated` = Salary_Updated
      )
    datatable(df, filter = "top", extensions = "Buttons",
              options = list(scrollX = TRUE, dom = "Bfrtip", buttons = c("copy", "csv", "print"), pageLength = 48))
  })

  # -------- Combined map (Introduction tab) --------
  output$combined_map <- renderLeaflet({
    leaflet() %>%
      addTiles() %>%
      setView(lng = -107.5, lat = 43, zoom = 7)
  })

  map_filtered <- reactive({
    df <- combined_map_data %>% filter(Type %in% input$map_types, CurrentCount > 0)
    df
  })

  observe({
    df <- map_filtered()

    # A marker click always just opens its popup (leaflet's default) --
    # navigating away from the map has to be a second, deliberate action,
    # so the "View all jobs" link below fires a Shiny input from inside
    # the popup itself rather than reacting to the marker click event,
    # which used to fire at the same instant as the popup opened and
    # immediately navigated away before it could be read.
    popups <- with(df, paste0(
      "<div><strong>", Name, "</strong><br/>", Type, "</div>",
      "<div>Current openings: <strong>", CurrentCount, "</strong></div>",
      "<div>New this week: ", WeeklyNew, "</div>",
      ifelse(!is.na(Vacancy_Rate),
             paste0("<div>", ifelse(Type == "K-12 District", "Teacher", "Faculty"),
                    " vacancy rate: ", scales::percent(Vacancy_Rate, accuracy = 0.1), "</div>"),
             ""),
      ifelse(nzchar(SampleTitles), paste0("<div>Recent postings: ", SampleTitles, "</div>"), ""),
      ifelse(!is.na(Teacher_Base_Salary),
             paste0("<div>Teacher base salary: ", scales::dollar(Teacher_Base_Salary),
                    ifelse(!is.na(Teacher_Base_Salary_Prior_Year),
                           paste0(" (", scales::dollar(Teacher_Base_Salary_Prior_Year), " prior year)"),
                           ""),
                    " &middot; ", Salary_Year, "</div>"),
             ""),
      ifelse(!is.na(Superintendent_Salary),
             paste0("<div>Superintendent salary: ", scales::dollar(Superintendent_Salary), "</div>"),
             ""),
      ifelse(!is.na(Faculty_Avg_Salary),
             paste0("<div>Avg. faculty salary: ", scales::dollar(Faculty_Avg_Salary),
                    ifelse(!is.na(Faculty_Avg_Salary_Professor),
                           paste0(" (Professor rank: ", scales::dollar(Faculty_Avg_Salary_Professor), ")"),
                           ""),
                    " &middot; ", Salary_Year, "</div>"),
             ""),
      ifelse(!is.na(Salary_Note),
             paste0("<div style='font-size:0.85em;color:#666;'>", Salary_Note, "</div>"),
             ""),
      ifelse(!is.na(Salary_Source),
             paste0("<div style='font-size:0.85em;color:#666;'>Salary source: ", Salary_Source,
                    " (updated ", Salary_Updated, ")</div>"),
             ""),
      "<div style='margin-top:6px;'>",
      "<a href='", Link, "' target='_blank'>Careers page</a>",
      " &nbsp;|&nbsp; ",
      "<a href='#' onclick=\"Shiny.setInputValue('popup_view_jobs', '",
      gsub("'", "&#39;", Name, fixed = TRUE),
      "', {priority: 'event'}); return false;\">View all jobs &rarr;</a>",
      "</div>"
    ))

    leafletProxy("combined_map", data = df) %>%
      clearMarkers() %>%
      addCircleMarkers(
        lng = ~Longitude, lat = ~Latitude,
        fillOpacity = 0.8,
        layerId = ~Name,
        popup = popups
      )
  })

  observeEvent(input$popup_view_jobs, {
    entity <- input$popup_view_jobs
    row <- combined_map_data %>% filter(Name == entity)
    req(nrow(row) > 0)

    if (row$Type[1] == "K-12 District") {
      selected_district(entity)
      updateTabItems(session, "sidebar_tabs", "k12_table")
    } else {
      selected_institution(entity)
      updateTabItems(session, "sidebar_tabs", "he_table")
    }
  })


  # ---- DATA SCOPE: District + Broad Category ----------------------------
  
  #------------Filter for longitudinal plot--------
  
  # Toggling detail level swaps both the underlying dataset and the
  # picker's own choices (Simple and Detailed are different category
  # name sets, not just different labels on the same data).
  observeEvent(input$k12_detail_level_trends, {
    cats <- if (identical(input$k12_detail_level_trends, "detail")) {
      sort(unique(k12sum$Broad_Category))
    } else {
      sort(unique(k12sum_agg$Broad_Category))
    }
    updatePickerInput(session, "broad_category", choices = cats, selected = cats)
  }, ignoreInit = TRUE)

  filtered_k12sum <- reactive({
    req(input$district_trend, input$broad_category, input$k12_detail_level_trends)

    base <- if (identical(input$k12_detail_level_trends, "detail")) k12sum else k12sum_agg

    base %>%
      dplyr::filter(
        # District filter
        input$district_trend == "Total" |
          District == input$district_trend,
        
        # Broad category filter (MULTI-SELECT SAFE)
        Broad_Category %in% input$broad_category
      )
  })
  
 
  # K-12 longitudinal plot
  df_windowed <- reactive({
    df <- filtered_k12sum()
    req(nrow(df) > 0, input$k12_scroll)
    
    df <- df %>%
      filter(
        Archive_Date >= input$k12_scroll[1],
        Archive_Date <= input$k12_scroll[2]
      )
    
    # Aggregate to ensure one row per Broad_Category x Archive_Date
    df <- df %>%
      filter(District != "Total") %>%  # remove total row to prevent double-counting
      group_by(Broad_Category, Archive_Date) %>%
      summarise(sum = sum(sum), .groups = "drop") %>%
      arrange(Broad_Category, Archive_Date)
    
    df
  })
  

  # ---- OUTPUT: LONGITUDINAL PLOT ----------------------------------------
  
  
  output$k12_longitudinal_plot <- renderPlotly({
    df <- df_windowed()
    
    validate(
      need(nrow(df) > 0, "No data for selected districts.")
    )
    
    # Get the exact dates in the filtered data
    all_dates <- sort(unique(df$Archive_Date))

    p <- ggplot(df, aes(
      x = Archive_Date,
      y = sum,
      color = Broad_Category,
      group = Broad_Category,
      text = paste0(
        "Date: ", Archive_Date, "<br>",
        "Category: ", Broad_Category, "<br>",
        "Postings: ", sum
      )
    )) +
      geom_line() +
      geom_point(size = 1) +
      scale_color_manual(values = if (identical(input$k12_detail_level_trends, "detail")) K12_CATEGORY_COLORS_DETAIL else K12_CATEGORY_COLORS_AGG) +
      labs(x = "Archive Date", y = "Number of Postings") +
      scale_x_date(
        breaks = all_dates,      # show every date exactly
        labels = scales::date_format("%b %d")
      ) +
      theme_minimal() +
      theme(
        axis.text.x = element_text(angle = 45, hjust = 1, size = 8),
        legend.position = "bottom",
        legend.key.size = unit(0.5, "cm"),
        legend.box.spacing = unit(0.2, "cm"),
        legend.text = element_text(size = 8),
        legend.title = element_text(size = 10)
      )

    ggplotly(p, height = 500, tooltip = "text")
  })
  

  
  output$k12_current_plot <- renderPlotly({
    req(input$k12_detail_level_current)
    src <- if (identical(input$k12_detail_level_current, "detail")) k12nowsum else k12nowsum_agg
    df <- src %>% filter(District == input$district_current)
    palette <- if (identical(input$k12_detail_level_current, "detail")) K12_CATEGORY_COLORS_DETAIL else K12_CATEGORY_COLORS_AGG

  # Horizontal bars, sorted so the largest category reads at the top like
  # a ranked list -- with up to 18 categories at the Detailed level, long
  # labels rotated on a vertical x-axis were overlapping the axis title
  # and legend (confirmed visually 2026-08-05). reorder(..., Sum) is exact
  # here since Sum is already one row per category, no grouping needed.
  # No legend, no "Category" axis title -- fill is 1:1 with the category,
  # which is already the label on every bar, so either one would just
  # repeat the same names a second time. The axis title also has a real
  # ggplotly() bug: its theme margin isn't respected through conversion,
  # so at the Detailed level it renders vertically centered on top of the
  # tick-label column instead of clear to the left (confirmed visually
  # 2026-08-05) -- dropping it sidesteps that rather than fighting it.
  plot <- ggplot(df, aes(x = reorder(Broad_Category, Sum), y = Sum, fill = Broad_Category)) +
    geom_bar(stat = "identity") +
    geom_text(aes(label = Sum), hjust = -0.2, size = 3) +
    labs(x = NULL, y = "Number of Postings") +
    scale_fill_manual(values = palette) +
    coord_flip() +
    theme_minimal() +
    theme(legend.position = "none")

  ggplotly(plot)
})
  # -------- Higher Ed --------
  output$he_jobs <- renderDT({
    df <- ccdata
    if (!is.null(selected_institution())) df <- df %>% filter(Institution == selected_institution())
    datatable(df, filter = "top", escape = FALSE, extensions = "Buttons",
              options = list(scrollX = TRUE, dom = "Bfrtip", buttons = c("copy", "csv", "print")))
  })

  output$he_filter_status <- renderUI({
    if (is.null(selected_institution())) return(NULL)
    div(style = "margin-bottom: 10px;",
        strong(paste("Showing:", selected_institution())),
        actionButton("clear_he_filter", "Show All Institutions", class = "btn-xs", style = "margin-left: 10px;")
    )
  })
  observeEvent(input$clear_he_filter, { selected_institution(NULL) })

  # Institution Summary -- same purpose as k12_summary_table above: the
  # map popups' data as a real exportable table, not one marker at a time.
  output$he_summary_table <- renderDT({
    df <- combined_map_data %>%
      filter(Type == "Higher Ed Institution") %>%
      arrange(desc(CurrentCount)) %>%
      transmute(
        Institution = Name,
        `Current Openings` = CurrentCount,
        `New This Week` = WeeklyNew,
        `Faculty Vacancy Rate` = ifelse(is.na(Vacancy_Rate), NA_character_, scales::percent(Vacancy_Rate, accuracy = 0.1)),
        `Avg Faculty Salary` = ifelse(is.na(Faculty_Avg_Salary), NA_character_, scales::dollar(Faculty_Avg_Salary)),
        `Professor Avg Salary` = ifelse(is.na(Faculty_Avg_Salary_Professor), NA_character_, scales::dollar(Faculty_Avg_Salary_Professor)),
        `Faculty Count` = Faculty_Count,
        `Salary Year` = Salary_Year,
        # Short plain-text label, not the full Salary_Note sentence --
        # that blew out Sheridan/Gillette's row height next to every other
        # institution's single-line rows (confirmed visually 2026-08-05).
        # Kept plain text rather than an HTML tooltip so the CSV/copy
        # export buttons still produce clean text, not raw markup.
        Note = ifelse(is.na(Salary_Note), "", "Shared reporting w/ Sheridan & Gillette"),
        `Salary Source` = Salary_Source,
        `Salary Updated` = Salary_Updated
      )
    datatable(df, filter = "top", extensions = "Buttons",
              options = list(scrollX = TRUE, dom = "Bfrtip", buttons = c("copy", "csv", "print"), pageLength = 9))
  })

  observeEvent(input$he_detail_level_trends, {
    cats <- if (identical(input$he_detail_level_trends, "detail")) {
      sort(unique(hesum_he$Category))
    } else {
      sort(unique(hesum_he_agg$Category))
    }
    updatePickerInput(session, "he_category", choices = cats, selected = cats)
  }, ignoreInit = TRUE)

  # ---- Reactive filtered dataset by institution + Category ----
  filtered_hesum <- reactive({
    req(input$inst_trend, input$he_category, input$he_chart_type, input$he_detail_level_trends)

    base <- if (identical(input$he_detail_level_trends, "detail")) hesum_he else hesum_he_agg

    # Filter by institution
    df <- if (input$inst_trend == "Total") {
      base
    } else {
      base %>% filter(Institution == input$inst_trend)
    }

    # Filter by Category (vector match)
    df <- df %>% filter(Category %in% input$he_category)

    # Filter by Job_Type -- "all" sums Full Time + Part Time together
    # (the group_by/summarize below combines whatever rows are present),
    # otherwise scope down to just the selected Job_Type.
    if (!identical(input$he_chart_type, "all")) {
      df <- df %>% filter(Job_Type == input$he_chart_type)
    }

    df
  })
  
  # ---- Update slider based on filtered data ----
  observe({
    df <- filtered_hesum()
    req(nrow(df) > 0)
    
    df$Archive_Date <- as.Date(df$Archive_Date)
    he_dates <- sort(unique(df$Archive_Date))
    
    # Set slider min/max as actual dates
    updateSliderInput(
      session,
      "he_scroll",
      min = min(he_dates),
      max = max(he_dates),
      value = c(max(he_dates) - WINDOW_WEEKS*7, max(he_dates)),
      timeFormat = "%Y-%m-%d"
    )
    
    # Store for reactive filtering
    session$userData$he_dates <- he_dates
  })
  
  # ---- Reactive dataset filtered by date window ----
  he_windowed <- reactive({
    df <- filtered_hesum()
    req(input$he_scroll)

    df %>%
      filter(
        Archive_Date >= as.Date(input$he_scroll[1]),
        Archive_Date <= as.Date(input$he_scroll[2]),
        Institution != "Total"  # remove pre-aggregated total row to prevent double-counting
      ) %>%
      arrange(Archive_Date)
  })
  
  # ---- Optional: show slider range ----
  output$he_slider_label <- renderText({
    req(input$he_scroll)
    paste0("Showing: ", input$he_scroll[1], " to ", input$he_scroll[2])
  })
  
  # ---- Render plot ----
  output$he_longitudinal_plot <- renderPlotly({
    df <- he_windowed()
    validate(need(nrow(df) > 0, "No data for selected institution/category/date range."))
    
    # Ensure one row per Category × Archive_Date and sort properly
    df <- df %>%
      group_by(Category, Archive_Date) %>%
      summarize(sum = sum(sum), .groups = "drop") %>%
      arrange(Category, Archive_Date) %>%
      mutate(Category = factor(Category))
    
    # Plot
    p <- ggplot(df, aes(
      x = Archive_Date,
      y = sum,
      color = Category,
      group = Category,
      text = paste0(
        "Date: ", Archive_Date, "<br>",
        "Category: ", Category, "<br>",
        "Postings: ", sum
      )
    )) +
      geom_line() +
      geom_point(size = 1) +
      scale_color_manual(values = if (identical(input$he_detail_level_trends, "detail")) HE_CATEGORY_COLORS_DETAIL else HE_CATEGORY_COLORS_AGG) +
      labs(x = "Archive Date", y = "Number of Postings") +
      theme_minimal() +
      theme(
        axis.text.x = element_text(angle = 45, hjust = 1, size = 8),
        legend.position = "bottom",
        legend.key.size = unit(0.5, "cm"),
        legend.box.spacing = unit(0.2, "cm"),
        legend.text = element_text(size = 8),
        legend.title = element_text(size = 10)
      )

    ggplotly(p, height = 500, tooltip = "text")
  })




  output$he_current_plot <- renderPlotly({
    req(input$he_detail_level_current)
    src <- if (identical(input$he_detail_level_current, "detail")) henowsum_he else henowsum_he_agg
    df <- src %>%
      filter(Institution == input$inst_current) %>%
      mutate(Job_Type = dplyr::recode(Job_Type,
        "Instructor/Teacher/Faculty" = "Full-Time Faculty",
        "Adjunct/Part-Time Faculty" = "Adjunct/Part-Time"
      )) %>%
      group_by(Category) %>%
      mutate(Category_Total = sum(Sum)) %>%
      ungroup()

    # Horizontal bars, sorted so the largest category reads at the top --
    # same fix as k12_current_plot. Category_Total (not Sum) drives the
    # sort since each category has two stacked rows (FT/PT); reorder()'s
    # default mean-of-Sum would rank a mostly-FT category differently than
    # its true total some of the time. No "Category" axis title -- same
    # ggplotly() margin bug as k12_current_plot (renders on top of the
    # tick-label column instead of clear to the left); the legend stays
    # since it encodes Job_Type, a separate dimension from the labels.
    p <- ggplot(df, aes(
      x = reorder(Category, Category_Total), y = Sum, fill = Job_Type,
      text = paste0("Category: ", Category, "<br>", "Type: ", Job_Type, "<br>", "Postings: ", Sum)
    )) +
      geom_bar(stat = "identity", position = "stack") +
      geom_text(aes(label = Sum), position = position_stack(vjust = 0.5), size = 3) +
      labs(x = NULL, y = "Number of Postings", fill = NULL) +
      scale_fill_manual(values = HE_JOB_TYPE_COLORS) +
      coord_flip() +
      theme_minimal() +
      theme(legend.position = "bottom",
            legend.key.size = unit(0.5, "cm"),
            legend.box.spacing = unit(0.2, "cm"),
            legend.text = element_text(size = 8),
            legend.title = element_text(size = 10))

    ggplotly(p, tooltip = "text")
  })
}

shinyApp(ui, server)
