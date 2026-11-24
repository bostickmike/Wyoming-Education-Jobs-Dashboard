# Tier-1 boot smoke -- ported from the Montana dashboard (PR #5), modelled
# on the LASSO project's tests/smoke.R.
#
# test-app-reactives.R drives the server() function with shiny::testServer(),
# which (per Mastering Shiny) "ignores the UI entirely" -- inputs start NULL,
# no JavaScript, no htmlwidgets. This file boots the REAL Wy_Ed_Jobs/app.R
# in a headless browser against the real committed CSVs and checks it renders
# end to end: every tab, no Shiny error banner anywhere, and the leaflet /
# plotly / DT widgets actually came back.
#
# It answers "does the app run on this data shape without falling over", not
# "are the numbers right" (that's test-app-reactives.R + test-weekly-data-
# quality.R). It exists so a refactor of app.R doesn't have to start from a
# blank manual click-through.
#
# Needs shinytest2 (pulls chromote / headless Chrome). ~1 min. Skips
# unless NOT_CRAN=true and a headless Chrome is resolvable.

skip_on_cran()
skip_if_not_installed("shinytest2")
skip_if_not_installed("chromote")
skip_if(is.null(tryCatch(chromote::find_chrome(), error = function(e) NULL)),
        "no headless Chrome available")

`%||%` <- function(a, b) if (is.null(a)) b else a

app_dir <- here::here("Wy_Ed_Jobs")
skip_if_not(dir.exists(app_dir), "Wy_Ed_Jobs/ not found")
skip_if_not(file.exists(file.path(app_dir, "combinedclean.csv")),
            "committed CSVs not found -- run the pipeline first")

# every leaf tab a user can actually land on (k12_root / he_root are
# menuItem containers, not destinations)
LEAF_TABS <- c(
  "intro", "map_tab", "data_tab",
  "k12_table", "k12_summary", "k12_trends", "k12_spells",
  "he_table", "he_summary", "he_trends", "he_spells"
)


# Waiting. Each step waits for the condition it is about to check, not for a
# fixed time: a suite or a pipeline render running beside this file can slow
# the app server and the browser several-fold, and the old fixed waits then
# failed (claude-notes/2026-11-24_boot-smoke/). chromote's own 10 s command
# timeout, which load_timeout doesn't cover, ran out while the browser waited
# for the app's first page ("timed out waiting for response to command
# Page.navigate"); a set_inputs() whose outputs didn't change within 30 s
# only printed a note and the test went on; checks read the map, plot and
# table after a fixed wait_for_idle() (20-25 s) whether or not they had
# rendered ("k12 jobs table rendered no rows", "Shiny did not become stable").
# Every wait below gives up after BOOT_SMOKE_TIMEOUT_S seconds (default 120;
# a quiet run needs 1-5 s per step), and a condition that never came true
# fails its expectation.
BOOT_SMOKE_TIMEOUT_S <- as.numeric(Sys.getenv("BOOT_SMOKE_TIMEOUT_S", "120"))
BOOT_SMOKE_TIMEOUT_MS <- BOOT_SMOKE_TIMEOUT_S * 1000

# The server has the page's inputs and has finished the outputs they changed:
# Shiny idle for 1 s in a row.
wait_for_server <- function(app) {
  app$wait_for_idle(duration = 1000, timeout = BOOT_SMOKE_TIMEOUT_MS)
}

# TRUE once the outer HTML of `selector` matches `pattern` (the same pattern
# the expectation then checks), FALSE if it didn't within the timeout.
wait_for_html <- function(app, selector, pattern) {
  js <- sprintf("(function() { var e = document.querySelector(%s); return e !== null && new RegExp(%s).test(e.outerHTML); })()",
                jsonlite::toJSON(selector, auto_unbox = TRUE), jsonlite::toJSON(pattern, auto_unbox = TRUE))
  tryCatch({ app$wait_for_js(js, timeout = BOOT_SMOKE_TIMEOUT_MS, interval = 250); TRUE },
           error = function(e) FALSE)
}

# The server's current value of input `name`. get_value() first checks that
# the app's port answers within 0.5 s (pingr::is_up()) and otherwise stops
# with "Shiny app is no longer running", which a loaded machine can trigger
# on a live app: retry until the timeout, then let the last error through.
server_input <- function(app, name) {
  deadline <- Sys.time() + BOOT_SMOKE_TIMEOUT_S
  repeat {
    v <- tryCatch(list(app$get_value(input = name)), error = function(e) NULL)
    if (!is.null(v)) return(v[[1]])
    if (Sys.time() > deadline) return(app$get_value(input = name))
    Sys.sleep(0.25)
  }
}

# TRUE once the server's input `name` is `value`, FALSE if it wasn't within
# the timeout.
wait_for_input <- function(app, name, value) {
  deadline <- Sys.time() + BOOT_SMOKE_TIMEOUT_S
  repeat {
    if (identical(tryCatch(app$get_value(input = name), error = function(e) NULL), value)) return(TRUE)
    if (Sys.time() > deadline) return(FALSE)
    Sys.sleep(0.25)
  }
}

# Open a tab (or, with `input`, a card's sub-tab), then wait until the server
# has it and has rendered it. TRUE when the server reports the tab.
# (set_inputs()'s own wait is off: it waits for an output to change, and
# revisiting a tab changes none.)
show_tab <- function(app, tab, input = "sidebar_tabs") {
  app$set_inputs(!!input := tab, wait_ = FALSE)
  shown <- wait_for_input(app, input, tab)
  wait_for_server(app)
  shown
}

# One AppDriver for the whole file (booting bslib + leaflet +
# plotly + DT takes ~15s; don't pay it per test).
app <- NULL
withr::defer(if (!is.null(app)) app$stop(), teardown_env())

test_that("app.R boots against the committed data without an error", {
  # AppDriver's first page load runs on chromote's default command timeout
  # (10 s), not load_timeout; its session copies the value when created.
  chromote_obj <- chromote::default_chromote_object()
  old_timeout <- chromote_obj$default_timeout
  chromote_obj$default_timeout <- BOOT_SMOKE_TIMEOUT_S
  withr::defer(chromote_obj$default_timeout <- old_timeout, teardown_env())
  app <<- shinytest2::AppDriver$new(
    app_dir,
    name = "wy-ed-jobs-boot",
    load_timeout = BOOT_SMOKE_TIMEOUT_MS,
    timeout = BOOT_SMOKE_TIMEOUT_MS,
    seed = 1
  )
  wait_for_server(app)

  expect_null(app$get_html(".shiny-output-error"),
              info = "a Shiny output errored on the initial Home tab")

  logs <- app$get_logs()
  js_errors <- logs[!is.na(logs$level) & logs$level %in% c("error", "severe"), ]
  hard <- js_errors[grepl("Uncaught|ReferenceError|TypeError|shiny.*error",
                          js_errors$message, ignore.case = TRUE), ]
  expect_equal(nrow(hard), 0,
               info = paste(utils::capture.output(print(hard[, c("level", "message")])),
                            collapse = "\n"))
})

test_that("every tab renders with no Shiny output error", {
  skip_if(is.null(app), "app failed to boot")

  for (tab in LEAF_TABS) {
    expect_true(show_tab(app, tab), info = sprintf("tab '%s' never became the server's current tab", tab))

    err <- app$get_html(".shiny-output-error")
    expect_null(err, info = sprintf("tab '%s' rendered a Shiny output error:\n%s",
                                    tab, if (is.null(err)) "" else substr(err, 1, 800)))
  }
})

test_that("the map, a longitudinal plot, and a jobs table actually render their widgets", {
  skip_if(is.null(app), "app failed to boot")

  expect_true(show_tab(app, "map_tab"), info = "the map_tab tab never opened")
  wait_for_html(app, "#combined_map", "leaflet-container|leaflet-tile|leaflet-marker|leaflet-pane")
  map_html <- app$get_html("#combined_map")
  expect_false(is.null(map_html), info = "leaflet map container missing")
  expect_true(grepl("leaflet-container|leaflet-tile|leaflet-marker|leaflet-pane",
                    map_html %||% ""),
              info = "leaflet map rendered no tiles/markers/panes")

  # The plot is on the Trends card's Historical tab (edjobs k12_trends_panel()). Until
  # 11-24 this check never opened it and passed on the empty container, whose
  # class is "plotly"; js-plotly-plot / main-svg appear once the plot draws.
  expect_true(show_tab(app, "k12_trends"), info = "the k12_trends tab never opened")
  expect_true(show_tab(app, "k12_trends_historical", input = "k12_trends_tabs"),
              info = "the k12 Trends card's Historical tab never opened")
  wait_for_html(app, "#k12_longitudinal_plot", "js-plotly-plot|main-svg")
  plot_html <- app$get_html("#k12_longitudinal_plot")
  expect_false(is.null(plot_html), info = "k12 longitudinal plotly container missing")
  expect_true(grepl("js-plotly-plot|main-svg", plot_html %||% ""),
              info = "k12 longitudinal plot rendered no plotly/svg")

  expect_true(show_tab(app, "k12_table"), info = "the k12_table tab never opened")
  wait_for_html(app, "#k12_jobs", "dataTable|dataTables_wrapper|<td")
  dt_html <- app$get_html("#k12_jobs")
  expect_false(is.null(dt_html), info = "k12 jobs DT container missing")
  expect_true(grepl("dataTable|dataTables_wrapper|<td", dt_html %||% ""),
              info = "k12 jobs table rendered no rows")
})

test_that("HE trends and HE jobs table render (the merged-entity / Vacancy_Rate_Shared path)", {
  skip_if(is.null(app), "app failed to boot")

  # The plot is on the Trends card's Historical tab (edjobs he_trends_panel()). Until
  # 11-24 this check never opened it and passed on the empty container, whose
  # class is "plotly"; js-plotly-plot / main-svg appear once the plot draws.
  expect_true(show_tab(app, "he_trends"), info = "the he_trends tab never opened")
  expect_true(show_tab(app, "he_trends_historical", input = "he_trends_tabs"),
              info = "the he Trends card's Historical tab never opened")
  wait_for_html(app, "#he_longitudinal_plot", "js-plotly-plot|main-svg")
  he_plot <- app$get_html("#he_longitudinal_plot")
  expect_false(is.null(he_plot), info = "he longitudinal plotly container missing")
  expect_true(grepl("js-plotly-plot|main-svg", he_plot %||% ""),
              info = "he longitudinal plot rendered no plotly/svg")

  expect_true(show_tab(app, "he_table"), info = "the he_table tab never opened")
  expect_null(app$get_html(".shiny-output-error"),
              info = "HE Jobs Table errored")
})

test_that("clicking 'View all jobs' from a map popup jumps to the filtered K-12 Jobs Table", {
  skip_if(is.null(app), "app failed to boot")

  # simulate the popup link's Shiny.setInputValue('popup_view_jobs', <name>).
  # Use a district that's actually on the map (has lat/long via salarymap2).
  sm <- utils::read.csv(here::here("Wy_Ed_Jobs", "salarymap2.csv"), stringsAsFactors = FALSE)
  a_district <- sm$District[!is.na(sm$Latitude)][1]
  # Start from Home, so the switch is the popup's doing.
  expect_true(show_tab(app, "intro"), info = "the Home tab never opened")
  app$set_inputs(popup_view_jobs = a_district, allow_no_input_binding_ = TRUE, wait_ = FALSE)
  wait_for_input(app, "sidebar_tabs", "k12_table")
  wait_for_server(app)

  expect_equal(server_input(app, "sidebar_tabs"), "k12_table",
               info = "popup_view_jobs did not switch to the K-12 Jobs Table")
  expect_null(app$get_html(".shiny-output-error"),
              info = "the filtered Jobs Table errored after a map-popup jump")
})
