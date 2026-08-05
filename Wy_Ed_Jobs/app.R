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
# Aggregated rollups -- a 2026-08-04 audit found several badly-oversized,
# artificially-merged categories (K-12 "Special Education" alone was 3,239
# postings; HE "CTE" was 5,834, three times the next-largest real
# category) and split them into coherent sub-groups. That's more accurate,
# but too many categories at once makes the longitudinal line charts an
# unreadable tangle. Both levels stay available -- "Aggregated" collapses
# the splits back into their original combined buckets (what the charts
# looked like before the split), "Detailed" shows the full breakdown --
# via a toggle, rather than picking one and losing the other.
#--------------------------------------------------
k12_collapse_map <- c(
  "SpEd - General" = "Special Education",
  "SpEd - Resource/LS" = "Special Education",
  "Math" = "STEM",
  "Science" = "STEM",
  "CTE - Trades/Ag" = "CTE",
  "CTE - Biz/Family" = "CTE"
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
  "CTE - Trades & Engineering" = "CTE",
  "CTE - Health Sciences" = "CTE",
  "CTE - Business & Computing" = "CTE"
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
# reusing/cycling a slot. Separate palettes for the Aggregated and Detailed
# views since they're different category sets, not just different labels.
#--------------------------------------------------
EXT_HUES <- c("#8B5E34", "#5C7A99", "#7A7A3D", "#767671", "#2E8B87",
              "#C77DA8", "#B8860B", "#6B5B95", "#4A6670", "#D97757")
BASE8 <- c("#2a78d6", "#eb6834", "#1baf7a", "#eda100", "#e87ba4", "#008300", "#4a3aa7", "#e34948")

K12_CATEGORY_COLORS_AGG <- setNames(c(BASE8, EXT_HUES[1:5]), c(
  "Special Education", "Elementary", "STEM", "Music", "CTE",
  "Engl. LA", "Language", "Soc. St.", "Physical Education", "Early Childhood",
  "Art", "Library Media", "Gifted and Talented"
))

K12_CATEGORY_COLORS_DETAIL <- setNames(c(BASE8, EXT_HUES[1:8]), c(
  "Elementary", "SpEd - General", "SpEd - Resource/LS", "Music", "Math",
  "Engl. LA", "Science", "CTE - Trades/Ag", "Language", "CTE - Biz/Family",
  "Soc. St.", "Physical Education", "Early Childhood", "Art", "Library Media",
  "Gifted and Talented"
))

HE_CATEGORY_COLORS_AGG <- setNames(c(BASE8, EXT_HUES[1:8]), c(
  "CTE", "Science", "The Arts", "Humanities", "Social Science",
  "Extension/Outreach", "Math", "History", "Education", "Culinary/Hospitality",
  "Physical Education", "Library", "Language", "Criminal Justice", "Legal",
  "Human Services"
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

map_k12 <- mapdata2_k12 %>%
  left_join(k12_current_counts, by = c("Name" = "District")) %>%
  left_join(k12_sample_titles, by = c("Name" = "District")) %>%
  left_join(k12_weekly_new, by = c("Name" = "District")) %>%
  mutate(
    CurrentCount = coalesce(CurrentCount, 0L),
    WeeklyNew = coalesce(WeeklyNew, 0L),
    SampleTitles = coalesce(SampleTitles, ""),
    Type = "K-12 District",
    Faculty_Avg_Salary = NA_real_, Faculty_Avg_Salary_Professor = NA_real_, Faculty_Count = NA_real_,
    Salary_Note = NA_character_
  ) %>%
  select(Name, Longitude, Latitude, Type, CurrentCount, WeeklyNew, SampleTitles,
         Link = Job_Link, Teacher_Base_Salary, Teacher_Base_Salary_Prior_Year, Salary_Year,
         Superintendent_Salary, Superintendent_Contract_Days,
         Faculty_Avg_Salary, Faculty_Avg_Salary_Professor, Faculty_Count, Salary_Note,
         Salary_Source, Salary_Updated, County)

he_current_counts <- ccdata %>% count(Institution, name = "CurrentCount")
he_sample_titles <- ccdata %>%
  group_by(Institution) %>%
  summarize(SampleTitles = paste(head(Title, 3), collapse = "; "), .groups = "drop")
he_weekly_new <- he_new_this_week %>% count(Institution, name = "WeeklyNew")

map_he <- mapdata2_he %>%
  left_join(he_current_counts, by = c("Name" = "Institution")) %>%
  left_join(he_sample_titles, by = c("Name" = "Institution")) %>%
  left_join(he_weekly_new, by = c("Name" = "Institution")) %>%
  mutate(
    CurrentCount = coalesce(CurrentCount, 0L),
    WeeklyNew = coalesce(WeeklyNew, 0L),
    SampleTitles = coalesce(SampleTitles, ""),
    Type = "Higher Ed Institution",
    Teacher_Base_Salary = NA_real_, Teacher_Base_Salary_Prior_Year = NA_real_,
    Superintendent_Salary = NA_real_, Superintendent_Contract_Days = NA_real_,
    County = NA_character_
  ) %>%
  select(Name, Longitude, Latitude, Type, CurrentCount, WeeklyNew, SampleTitles,
         Link, Teacher_Base_Salary, Teacher_Base_Salary_Prior_Year, Salary_Year,
         Superintendent_Salary, Superintendent_Contract_Days,
         Faculty_Avg_Salary, Faculty_Avg_Salary_Professor, Faculty_Count, Salary_Note,
         Salary_Source, Salary_Updated, County)

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
               menuSubItem("Longitudinal Teacher Trends", tabName = "k12_trends"),
               menuSubItem("Current Teacher Trends", tabName = "k12_current"),
               menuSubItem("New This Week", tabName = "k12_new")
      ),
      menuItem("Higher Ed Careers", tabName = "he_root", icon = icon("university"),
               menuSubItem("Jobs Table", tabName = "he_table"),
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
        div(style = "text-align:center; color:#999; font-size:0.85em; padding:15px;",
            paste0("Refreshed on: ", last_refreshed_date, " · Programmed by Mark Perkins and Mike Bostick"))
      ),

      tabItem(
        tabName = "k12_table",
        uiOutput("k12_filter_status"),
        DTOutput("k12_jobs")
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
                     choices = c("Aggregated" = "agg", "Detailed" = "detail"),
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
                     choices = c("Aggregated" = "agg", "Detailed" = "detail"),
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
        tabName = "he_trends",

        radioButtons("he_detail_level_trends", "Category detail:",
                     choices = c("Aggregated" = "agg", "Detailed" = "detail"),
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
                           choices = c("Aggregated" = "agg", "Detailed" = "detail"),
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
    combineddata %>% count(District, sort = TRUE, name = "Open Postings") %>% head(5)
  })
  output$top_he_institutions <- renderTable({
    ccdata %>% count(Institution, sort = TRUE, name = "Open Postings") %>% head(5)
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
  # picker's own choices (Aggregated and Detailed are different category
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

  plot <- ggplot(df, aes(x = Broad_Category, y = Sum, fill = Broad_Category)) +
    geom_bar(stat = "identity") +
    geom_text(aes(label = Sum), vjust = -0.3) +
    labs(x = "Category", y = "Number of Postings") +
    scale_fill_manual(values = palette) +
    theme_minimal() +
    theme(axis.text.x = element_text(angle = 22.5, hjust = 1, size = 7), 
          legend.position = "bottom", 
          legend.key.size = unit(0.5, "cm"), 
          legend.box.spacing = unit(0.2, "cm"), 
          legend.text = element_text(size = 8), 
          legend.title = element_text(size = 10))
  
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
      ))

    p <- ggplot(df, aes(
      x = Category, y = Sum, fill = Job_Type,
      text = paste0("Category: ", Category, "<br>", "Type: ", Job_Type, "<br>", "Postings: ", Sum)
    )) +
      geom_bar(stat = "identity", position = "stack") +
      geom_text(aes(label = Sum), position = position_stack(vjust = 0.5), size = 3) +
      labs(x = "Category", y = "Number of Postings", fill = "Position Type") +
      scale_fill_manual(values = HE_JOB_TYPE_COLORS) +
      theme_minimal() +
      theme(axis.text.x = element_text(angle = 22.5, hjust = 1, size = 7),
            legend.position = "bottom",
            legend.key.size = unit(0.5, "cm"),
            legend.box.spacing = unit(0.2, "cm"),
            legend.text = element_text(size = 8),
            legend.title = element_text(size = 10))

    ggplotly(p, tooltip = "text")
  })
}

shinyApp(ui, server)
