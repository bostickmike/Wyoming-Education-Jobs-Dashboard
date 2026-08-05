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
  mutate(District = str_squish(as.character(District)))

mapdata2_k12 <- read.csv("salarymap2.csv", fileEncoding = "UTF-8") %>%
  mutate(Start_Salary = as.numeric(gsub("[^0-9.]", "", Start_Salary)),
         Top_Salary   = as.numeric(gsub("[^0-9.]", "", Top_Salary)))

k12sum <- read.csv("allsum.csv", fileEncoding = "UTF-8") %>%
  mutate(District = str_squish(as.character(District)),
         Broad_Category = dplyr::recode(Broad_Category,
                                        "English Language Arts Secondary" = "Engl. LA",
                                        "Secondary Social Studies" = "Soc. St.")) %>%
  filter(Broad_Category != "Other")

k12sum$Archive_Date <- as.Date(k12sum$Archive_Date)


k12nowsum <- read.csv("allnow.csv", fileEncoding = "UTF-8") %>%
  mutate(Broad_Category = dplyr::recode(Broad_Category,
                                        "English Language Arts Secondary" = "Engl. LA",
                                        "Secondary Social Studies" = "Soc. St."),
         District = str_squish(iconv(District, from = "", to = "UTF-8"))) %>%
  filter(Broad_Category != "Other")

#--------------------------------------------------
# Load Higher Ed data
#--------------------------------------------------
ccdata <- read_xlsx("hedata.xlsx") %>%
  select(Institution, Title, Location, Posted_Date, Link) %>%
  arrange(Institution, Title)
ccdata$Link <- paste0('<a href="', ccdata$Link, '" target="_blank">', ccdata$Link, '</a>')

mapdata2_he <- read.csv("salarymap.csv")

hesum_he <- read.csv("allsum_he.csv") %>%
  filter(Category != "Uncategorized")

hesum_he$Archive_Date <- as.Date(hesum_he$Archive_Date)
he_dates <- sort(unique(hesum_he$Archive_Date))
WINDOW_WEEKS <- 52
hesum_he$Category<- as.factor(hesum_he$Category)

henowsum_he <- read.csv("allnow_he.csv") %>%
  filter(Category != "Uncategorized")

last_refreshed_date <- format(max(k12sum$Archive_Date, hesum_he$Archive_Date, na.rm = TRUE), "%B %d, %Y")

#--------------------------------------------------
# Category colors -- one fixed hex per category, shared by every chart in
# its section, so a category is never a different color on the current-
# snapshot chart than on the longitudinal chart. First 8 slots (by
# all-time volume) are the validated categorical palette from the dataviz
# skill (fixed order, CVD-checked); slots past 8 extend it with additional
# well-separated hues for the lower-volume categories rather than
# reusing/cycling a slot.
#--------------------------------------------------
K12_CATEGORY_COLORS <- c(
  "Special Education" = "#2a78d6",
  "Elementary"         = "#eb6834",
  "STEM"               = "#1baf7a",
  "Music"              = "#eda100",
  "CTE"                = "#e87ba4",
  "Engl. LA"           = "#008300",
  "Language"           = "#4a3aa7",
  "Soc. St."           = "#e34948",
  "Physical Education" = "#8B5E34",
  "Early Childhood"    = "#5C7A99",
  "Art"                = "#7A7A3D"
)

HE_CATEGORY_COLORS <- c(
  "CTE"                  = "#2a78d6",
  "The Arts"             = "#eb6834",
  "Science"              = "#1baf7a",
  "Humanities"           = "#eda100",
  "Math"                 = "#e87ba4",
  "Social Science"       = "#008300",
  "Culinary/Hospitality" = "#4a3aa7",
  "History"              = "#e34948",
  "Library"              = "#8B5E34",
  "Education"            = "#5C7A99",
  "Legal"                = "#7A7A3D",
  "Physical Education"   = "#767671"
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
  mutate(Archive_Date = as.Date(Archive_Date))

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
# UI
#--------------------------------------------------
ui <- dashboardPage(
  skin = 'black',
  dashboardHeader(title = "Wyoming Education Careers"),
  dashboardSidebar(
    sidebarMenu(
      menuItem("Introduction", tabName = "intro", icon = icon("home")),
      menuItem("K-12 Careers", tabName = "k12_root", icon = icon("school"),
               menuSubItem("Jobs Table", tabName = "k12_table"),
               menuSubItem("District Locations", tabName = "k12_collmap"),
               menuSubItem("Longitudinal Teacher Trends", tabName = "k12_trends"),
               menuSubItem("Current Teacher Trends", tabName = "k12_current"),
               menuSubItem("New This Week", tabName = "k12_new")
      ),
      menuItem("Higher Ed Careers", tabName = "he_root", icon = icon("university"),
               menuSubItem("Jobs Table", tabName = "he_table"),
               menuSubItem("Institution Locations", tabName = "he_collmap"),
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
  "))
    )
    ,
    tabItems(
      # ------------------ Global Introduction ------------------
      tabItem(
        tabName = "intro",
        fluidPage(
          tags$style(HTML("
            .intro-background {
              background-image: url('tree.jpg'); 
              background-size: cover; 
              background-position: center; 
              height: 100vh;
              position: relative;
              color: white;
              padding: 0;
              margin: 0;
            }
            .coed-logo {
              position: absolute;
              top: 50px;  
              right: 20px;
              width: auto;
              height: 85px;
              z-index: 10;
            }
            .refresh-info {
              position: absolute; 
              top: 20px; 
              left: 20px;
              background-color: rgba(255, 255, 255, 0.8); 
              color: red; 
              padding: 5px 10px; 
              border: 1px solid red; 
              border-radius: 5px;
              z-index: 10;
              font-weight: bold;
            }
            .intro-text {
              position: absolute;
              bottom: 15%;
              width: 100%;
              text-align: center;
              font-size: 2.5em;
              color: white;
              z-index: 5;
            }
          ")),
          div(class = "intro-background",
              div(class = "refresh-info", paste("Refreshed on:", last_refreshed_date)),
              img(src = "mark.png", class = "coed-logo"),
              div(class = "intro-text",
                  h1("Education Jobs in Wyoming")
              )
          ),
          fluidRow(
            valueBoxOutput("kpi_k12_total", width = 4),
            valueBoxOutput("kpi_he_total", width = 4),
            valueBoxOutput("kpi_last_refreshed", width = 4)
          ),
          fluidRow(
            box(title = "Top K-12 Hiring Districts This Week", width = 6, status = "primary",
                tableOutput("top_k12_districts")),
            box(title = "Top Higher Ed Hiring Institutions This Week", width = 6, status = "primary",
                tableOutput("top_he_institutions"))
          )
        )
      ),

      tabItem(
        tabName = "k12_table",
        DTOutput("k12_jobs")
      ),
      tabItem(
        tabName = "k12_new",
        h4("New teacher postings since the previous weekly snapshot"),
        DTOutput("k12_new_table")
      ),
      tabItem(
        tabName = "k12_collmap",
        withSpinner(leafletOutput("k12_map", height = 800))
      ),
      
      
      
      # ------------------ K-12 ------------------
      tabItem(
        tabName = "k12_trends",
        
        # Row for category + district
        fluidRow(
          column(
            width = 6,  # half the row
            pickerInput(
              "broad_category",
              "Choose Teacher Category:",
              choices  = sort(unique(k12sum$Broad_Category)),
              selected = sort(unique(k12sum$Broad_Category)),
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
        
        radioButtons("k12_chart_type", NULL, choices = c("Line" = "line", "Stacked Area" = "area"),
                     selected = "line", inline = TRUE),

        # Plot output
        withSpinner(plotlyOutput("k12_longitudinal_plot"))
      ),
      
      tabItem(
        tabName = "k12_current",
        
        selectInput(
          "district_current",
          "Choose District:",
          choices = sort(unique(k12nowsum$District)),
          selected = "Total"
        ),
        
        withSpinner(plotlyOutput("k12_current_plot"))
      ),
      
      # ------------------ Higher Ed ------------------
      tabItem(tabName = "he_table", DTOutput("he_jobs")),
      tabItem(tabName = "he_collmap", withSpinner(leafletOutput("he_map", height = 800))),
      tabItem(
        tabName = "he_trends",
        
        # Row for Category + Institution
        fluidRow(
          column(
            width = 6,
            pickerInput(
              "he_category",
              "Choose Category:",
              choices  = sort(unique(hesum_he$Category)),
              selected = sort(unique(hesum_he$Category)),
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
        
        radioButtons("he_chart_type", NULL, choices = c("Line" = "line", "Stacked Area" = "area"),
                     selected = "line", inline = TRUE),

        # Plot output
        withSpinner(plotlyOutput("he_longitudinal_plot"))),
      
      tabItem(tabName = "he_current",
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
    datatable(combineddata, filter = "top", extensions = "Buttons",
              options = list(scrollX = TRUE, dom = "Bfrtip", buttons = c("copy", "csv", "print")))
  })
  
  output$k12_map <- renderLeaflet({
    leaflet(data = mapdata2_k12) %>%
      addTiles() %>%
      addCircleMarkers(
        group = "name", 
        fillOpacity = 0.8, 
        lng = ~Longitude, 
        lat = ~Latitude,
        popup = ~lapply(paste0(
          "<div><strong>Name:</strong> ", Name, "</div>",
          "<div><strong>Start Salary:</strong> ", scales::dollar(Start_Salary), "</div>",
          "<div><strong>Top Salary:</strong> ", scales::dollar(Top_Salary), "</div>",
          "<div><strong>Year:</strong> ", Salary_Year, "</div>",
          "<div><strong>County:</strong> ", County, "</div>",
          "<div><strong>Job_Link:</strong> <a href='", Job_Link, "' target='_blank'>", Job_Link, "</a></div>"
        ), htmltools::HTML)
      )
  })
  
  # ---- DATA SCOPE: District + Broad Category ----------------------------
  
  #------------Filter for longitudinal plot--------
  
  filtered_k12sum <- reactive({
    req(input$district_trend, input$broad_category)
    
    k12sum %>%
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

    base <- ggplot(df, aes(
      x = Archive_Date,
      y = sum,
      group = Broad_Category,
      text = paste0(
        "Date: ", Archive_Date, "<br>",
        "Category: ", Broad_Category, "<br>",
        "Postings: ", sum
      )
    ))

    p <- if (identical(input$k12_chart_type, "area")) {
      base + aes(fill = Broad_Category) +
        geom_area(position = "stack") +
        scale_fill_manual(values = K12_CATEGORY_COLORS)
    } else {
      base + aes(color = Broad_Category) +
        geom_line() +
        geom_point(size = 1) +
        scale_color_manual(values = K12_CATEGORY_COLORS)
    }

    p <- p +
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
    df <- k12nowsum %>% filter(District == input$district_current)
    
  plot <- ggplot(df, aes(x = Broad_Category, y = Sum, fill = Broad_Category)) +
    geom_bar(stat = "identity") +
    geom_text(aes(label = Sum), vjust = -0.3) +
    labs(x = "Category", y = "Number of Postings") +
    scale_fill_manual(values = K12_CATEGORY_COLORS) +
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
    datatable(ccdata, escape = FALSE, extensions = "Buttons",
              options = list(scrollX = TRUE, dom = "Bfrtip", buttons = c("copy", "csv", "print")))
  })
  
  
  output$he_map <- renderLeaflet({
    leaflet(mapdata2_he) %>%
      addTiles() %>%
      addCircleMarkers(
        lng = ~Longitude,
        lat = ~Latitude,
        fillOpacity = 0.8,
        popup = ~lapply(paste0(
          "<strong>Name:</strong> ", Name, "<br/>",
          "<strong>Job Links:</strong> <a href='", Link, "' target='_blank'>", Link, "</a>"
        ), htmltools::HTML)
      )
  })
  
  
  # ---- Reactive filtered dataset by institution + Category ----
  filtered_hesum <- reactive({
    req(input$inst_trend, input$he_category)
    
    # Filter by institution
    df <- if (input$inst_trend == "Total") {
      hesum_he
    } else {
      hesum_he %>% filter(Institution == input$inst_trend)
    }
    
    # Filter by Category (vector match)
    df %>% filter(Category %in% input$he_category)
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
    base <- ggplot(df, aes(
      x = Archive_Date,
      y = sum,
      group = Category,
      text = paste0(
        "Date: ", Archive_Date, "<br>",
        "Category: ", Category, "<br>",
        "Postings: ", sum
      )
    ))

    p <- if (identical(input$he_chart_type, "area")) {
      base + aes(fill = Category) +
        geom_area(position = "stack") +
        scale_fill_manual(values = HE_CATEGORY_COLORS)
    } else {
      base + aes(color = Category) +
        geom_line() +
        geom_point(size = 1) +
        scale_color_manual(values = HE_CATEGORY_COLORS)
    }

    p <- p +
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
    df <- henowsum_he %>% filter(Institution == input$inst_current)
   
    p <- ggplot(df, aes(x = Category, y = Sum, fill = Category)) +
      geom_bar(stat = "identity") +
      geom_text(aes(label = Sum), nudge_y = 0.05 * max(df$Sum)) +
      labs(x = "Category", y = "Number of Postings") +
      scale_fill_manual(values = HE_CATEGORY_COLORS) +
      theme_minimal() +
      theme(axis.text.x = element_text(angle = 22.5, hjust = 1, size = 7),
            legend.position = "bottom",
            legend.key.size = unit(0.5, "cm"),
            legend.box.spacing = unit(0.2, "cm"),
            legend.text = element_text(size = 8),
            legend.title = element_text(size = 10))
    
    ggplotly(p)
  })
}

shinyApp(ui, server)
