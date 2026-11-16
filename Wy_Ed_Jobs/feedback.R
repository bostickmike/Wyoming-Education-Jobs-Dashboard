# Public feedback form (Mike, 2026-11-16): visitors report a data problem with no GitHub login. The app checks
# the report (spam rules below) and, if it passes, opens one GitHub issue in this state's own repo, labeled
# data-quality + user-report (nothing acts on those labels automatically; auto-fix works only scraper-autofix
# issues the weekly run files itself).
#
# Needs two environment variables on Posit Connect Cloud (set as secrets, never committed):
#   GITHUB_FEEDBACK_TOKEN  fine-grained token: this repo only, permission Issues: read and write, nothing else
#   FEEDBACK_REPO          optional override of the repo app.R passes (owner/name)
# Without the token the Feedback button stays a link to GitHub's issue form (feedback_enabled() is FALSE).
#
# Identical in the Montana and Wyoming apps; app.R passes the state's repo and name.

FEEDBACK_TYPES <- c("Expired / Closed Job (still listed as open)",
                    "Broken Application Link / 404",
                    "Incorrect Subject, Category, or Title",
                    "Missing School District or Institution",
                    "Salary or Staffing Discrepancy",
                    "Other Data Mistake")

FEEDBACK_LIMITS <- list(min_seconds = 4,       # faster than this from opening the form = a bot
                        max_per_session = 3,   # one visitor's browser session
                        max_per_hour = 20,     # whole app process (Connect may run more than one)
                        max_links = 3,
                        district = c(2, 120), job = c(0, 300), details = c(10, 3000))

FEEDBACK_SPAM_WORDS <- "\\b(casino|viagra|cialis|crypto|bitcoin|forex|loan|payday|seo|backlink|porn|escort|betting|replica)\\b"

feedback_enabled <- function() nzchar(Sys.getenv("GITHUB_FEEDBACK_TOKEN"))

# State shared by every session in this app process: recent posting times and report fingerprints.
.feedback_state <- new.env()
.feedback_state$times <- numeric(0)
.feedback_state$hashes <- character(0)

feedback_count_links <- function(...) {
  txt <- paste(c(...), collapse = " ")
  lengths(regmatches(txt, gregexpr("https?://|www\\.", txt, ignore.case = TRUE)))
}

# Decide what to do with one submission. Returns list(action, message):
#   "post"   passed every check
#   "drop"   looks automated or repeated: tell the visitor thanks, post nothing (don't teach bots the rules)
#   "reject" a person can fix it: show the message
feedback_check <- function(type, district, job, details, honeypot, opened_at, now = Sys.time(),
                           session_count = 0, state = .feedback_state, limits = FEEDBACK_LIMITS) {
  trim <- function(x) trimws(if (is.null(x) || length(x) == 0 || is.na(x[1])) "" else as.character(x[1]))
  type <- trim(type); district <- trim(district); job <- trim(job); details <- trim(details)
  if (nzchar(trim(honeypot))) return(list(action = "drop", message = "honeypot"))
  if (is.null(opened_at) || as.numeric(difftime(now, opened_at, units = "secs")) < limits$min_seconds)
    return(list(action = "drop", message = "too fast"))
  if (grepl(FEEDBACK_SPAM_WORDS, paste(district, job, details), ignore.case = TRUE, perl = TRUE))
    return(list(action = "drop", message = "spam words"))
  if (session_count >= limits$max_per_session)
    return(list(action = "reject", message = "Thanks -- that's the limit of reports for one visit. Please come back later for more."))
  recent <- state$times[state$times > as.numeric(now) - 3600]
  if (length(recent) >= limits$max_per_hour)
    return(list(action = "reject", message = "Many reports have come in this hour; please try again a little later."))
  if (!type %in% FEEDBACK_TYPES) return(list(action = "reject", message = "Please choose what kind of problem this is."))
  if (nchar(district) < limits$district[1] || nchar(district) > limits$district[2])
    return(list(action = "reject", message = "Please name the school district or institution."))
  if (nchar(job) > limits$job[2]) return(list(action = "reject", message = "The job title or link is too long."))
  if (nchar(details) < limits$details[1])
    return(list(action = "reject", message = "Please add a few words describing the problem."))
  if (nchar(details) > limits$details[2])
    return(list(action = "reject", message = sprintf("Please keep the description under %d characters.", limits$details[2])))
  if (feedback_count_links(job, details) > limits$max_links)
    return(list(action = "reject", message = sprintf("Please include no more than %d links.", limits$max_links)))
  if (feedback_fingerprint(type, district, job, details) %in% state$hashes)
    return(list(action = "drop", message = "duplicate"))
  list(action = "post", message = "")
}

feedback_fingerprint <- function(type, district, job, details) {
  norm <- function(x) gsub("\\s+", " ", tolower(trimws(paste(x, collapse = " "))))
  paste(norm(type), norm(district), norm(job), norm(details), sep = "|")
}

# Text a visitor typed, made safe to show in a public issue: no @mentions (would notify people), no #123 links
# (would cross-reference other issues), no HTML. GitHub sanitizes the rest of the Markdown itself.
feedback_sanitize <- function(x) {
  x <- gsub("[\r\n]+", "\n", x)
  x <- gsub("<[^>]*>", "", x)
  x <- gsub("@", "@​", x, fixed = TRUE)
  gsub("#(\\d)", "#​\\1", x, perl = TRUE)
}

feedback_issue <- function(type, district, job, details, state_name, now = Sys.time()) {
  s <- function(x) feedback_sanitize(trimws(as.character(x)))
  title <- substr(paste0("[Data Issue]: ", type, " -- ", s(district)), 1, 200)
  quote <- function(x) paste0("> ", gsub("\n", "\n> ", s(x)))
  body <- paste0(
    "Reported through the ", state_name, " dashboard's Feedback form (no GitHub account; ",
    format(now, "%Y-%m-%d %H:%M %Z", tz = "America/Denver"), ").\n\n",
    "**Issue Type:** ", type, "\n\n",
    "**School District or Institution:** ", s(district), "\n\n",
    "**Job Title or Listing URL:** ", if (nzchar(trimws(job))) s(job) else "_not given_", "\n\n",
    "**Description & Details:**\n\n", quote(details), "\n")
  list(title = title, body = body, labels = list("data-quality", "user-report"))
}

# POST the issue. Returns list(ok, number, url, error); never stops the app.
feedback_post <- function(issue, repo, token = Sys.getenv("GITHUB_FEEDBACK_TOKEN")) {
  tryCatch({
    h <- curl::new_handle()
    curl::handle_setheaders(h, Authorization = paste("Bearer", token), Accept = "application/vnd.github+json",
                            `X-GitHub-Api-Version` = "2022-11-28", `User-Agent` = "education-jobs-dashboard-feedback",
                            `Content-Type` = "application/json")
    curl::handle_setopt(h, customrequest = "POST", timeout = 20,
                        postfields = as.character(jsonlite::toJSON(issue, auto_unbox = TRUE)))
    r <- curl::curl_fetch_memory(paste0("https://api.github.com/repos/", repo, "/issues"), handle = h)
    out <- jsonlite::fromJSON(rawToChar(r$content))
    if (r$status_code == 201) list(ok = TRUE, number = out$number, url = out$html_url, error = NA_character_)
    else list(ok = FALSE, number = NA, url = NA, error = paste(r$status_code, out$message))
  }, error = function(e) list(ok = FALSE, number = NA, url = NA, error = conditionMessage(e)))
}

feedback_record <- function(type, district, job, details, now = Sys.time(), state = .feedback_state) {
  state$times <- c(state$times[state$times > as.numeric(now) - 3600], as.numeric(now))
  state$hashes <- tail(c(state$hashes, feedback_fingerprint(type, district, job, details)), 500)
}

# ---- UI and server pieces app.R uses -----------------------------------------------------------------------------

# The navbar item: a button that opens the form when the token is set, else the GitHub issue form link.
feedback_nav_item <- function(repo) {
  if (feedback_enabled()) {
    bslib::nav_item(shiny::actionLink("open_feedback", label = " Feedback", icon = shiny::icon("flag"), class = "nav-link"))
  } else {
    bslib::nav_item(shiny::tags$a(class = "nav-link", href = paste0("https://github.com/", repo, "/issues/new?template=data_issue.yml"),
                                  target = "_blank", rel = "noopener", shiny::icon("flag"), " Feedback"))
  }
}

feedback_modal <- function(repo) {
  shiny::modalDialog(
    title = "Report a data problem",
    shiny::p("Spotted an expired job, a broken link, a wrong subject or a missing district? Report it here; no account needed."),
    shiny::p(style = "font-size: 0.85em; color: #666;",
             "Reports are posted publicly on the project's ",
             shiny::tags$a(href = paste0("https://github.com/", repo, "/issues"), target = "_blank", "GitHub issue page"),
             ". Please don't include names, email addresses or other personal details."),
    shiny::selectInput("fb_type", "What kind of problem?", choices = c("Choose one" = "", FEEDBACK_TYPES), width = "100%"),
    shiny::textInput("fb_district", "School district or institution", width = "100%"),
    shiny::textInput("fb_job", "Job title or listing link (optional)", width = "100%"),
    shiny::textAreaInput("fb_details", "What's wrong? Include the correct link or information if you have it.",
                         width = "100%", rows = 5),
    # Honeypot: hidden from people (off screen, not focusable), filled in by form-filling bots.
    shiny::div(style = "position: absolute; left: -10000px; top: auto; width: 1px; height: 1px; overflow: hidden;",
               `aria-hidden` = "true",
               shiny::tags$label(`for` = "fb_website", "Leave this empty"),
               shiny::tags$input(id = "fb_website", type = "text", class = "form-control shiny-bound-input",
                                 tabindex = "-1", autocomplete = "off", value = "")),
    shiny::uiOutput("fb_error"),
    footer = shiny::tagList(shiny::modalButton("Cancel"), shiny::actionButton("fb_submit", "Send report", class = "btn-primary")),
    easyClose = TRUE)
}

feedback_server <- function(input, output, session, repo, state_name) {
  opened_at <- NULL
  sent <- 0
  shiny::observeEvent(input$open_feedback, {
    opened_at <<- Sys.time()
    output$fb_error <- shiny::renderUI(NULL)
    shiny::showModal(feedback_modal(repo))
  })
  shiny::observeEvent(input$fb_submit, {
    chk <- feedback_check(input$fb_type, input$fb_district, input$fb_job, input$fb_details, input$fb_website,
                          opened_at, session_count = sent)
    if (chk$action == "reject") {
      output$fb_error <- shiny::renderUI(shiny::div(class = "text-danger", style = "margin-top: 8px;", chk$message))
      return()
    }
    if (chk$action == "post") {
      res <- feedback_post(feedback_issue(input$fb_type, input$fb_district, input$fb_job, input$fb_details, state_name),
                           Sys.getenv("FEEDBACK_REPO", repo))
      if (!isTRUE(res$ok)) {
        message("feedback post failed: ", res$error)
        output$fb_error <- shiny::renderUI(shiny::div(class = "text-danger", style = "margin-top: 8px;",
          "Sorry, the report couldn't be sent just now. Please try again in a few minutes."))
        return()
      }
      feedback_record(input$fb_type, input$fb_district, input$fb_job, input$fb_details)
      sent <<- sent + 1
    }
    shiny::removeModal()
    shiny::showNotification("Thank you -- your report was sent.", type = "message", duration = 6)
  })
}
