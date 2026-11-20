# Wyoming's state configuration for the edjobs package (state_config(), since
# edjobs 0.7.0, phase 4). What package code needs to know about this state, as
# data. Sourced by the pipeline's setup chunk, tests/testthat/helper-setup.R
# and .github/scripts/check_salary_drift.R; set before anything refreshes or
# checks one of WY's own reference tables.
library(edjobs)

# Where a Wyoming source name comes from, and how each is scraped
# (edjobs::resolve_scraper_call(), for the PR live check,
# scripts/repro_scraper.R and the auto-fix issue). Two registries, the same
# schema as Montana's (one registry schema, 2026-11-16):
#   - k12_district_registry.csv: every K-12 scrape target, one row each
#     (District, NCES_LEAID, City, County, Latitude, Longitude, Platform,
#     Platform_Key, Job_Link, List_Start, List_Stop, List_Skip): the direct
#     boards, the district sites (fetch_misc_district_postings()) and
#     Laramie Montessori's Paylocity board;
#   - he_institution_registry.csv: every college (Institution, County,
#     Latitude, Longitude, Platform, Feed_URL, Job_Link, Location_Pattern,
#     Location_Label).
# WSBA-only orgs (WSBA_ONLY_ORGS) have no scraper of their own and resolve
# to NULL, as does anything else not listed.
# The registries sit at the repository root; tests run from tests/testthat.
wy_registry_path <- function(file) if (file.exists(file)) file else here::here(file)
read_k12_registry <- function() utils::read.csv(wy_registry_path("k12_district_registry.csv"), stringsAsFactors = FALSE,
                                                 colClasses = c(NCES_LEAID = "character", Platform_Key = "character"))
read_he_registry <- function() utils::read.csv(wy_registry_path("he_institution_registry.csv"), stringsAsFactors = FALSE)

# How each platform is scraped: the platforms edjobs scrapes (AppliTrack,
# SchoolSpring, TedK12, Red Rover, Edlio, Apptegy, NEOGOV ...) come from
# edjobs::default_scraper_specs() (edjobs 0.46.0), reading the registry's
# Platform_Key (AppliTrack's tenant path, SchoolSpring's domain, Red Rover's
# org id), Job_Link, City and list rules; the specs below add Wyoming's own
# scrapers and replace PeopleAdmin's.
# The direct district boards: scraped in Wy_ED_Jobs.Rmd's registry loop.
WY_DIRECT_BOARD_PLATFORMS <- c("AppliTrack", "TedK12", "SchoolSpring", "RedRoverK12")
# The direct-board rows only: what the Rmd's registry loop scrapes, and the
# "registered districts" the drift check's WSBA section counts.
read_direct_board_registry <- function() {
  r <- read_k12_registry()
  r[r$Platform %in% WY_DIRECT_BOARD_PLATFORMS, , drop = FALSE]
}
# District sites (fetch_misc_district_postings() dispatches on Platform).
# `session = TRUE`: the fetch_* takes a chromote session first.
# `fixture_prefix`: the fixtures' file-name prefix where it isn't the lower-cased platform.
WY_MISC_SCRAPER_SPECS <- list(
  WordPressBespoke = scraper_spec("fetch_wy_wordpress_postings", "Job_Link", fixture_prefix = "wordpress"),
  SmartSites = scraper_spec("fetch_smartsites_postings", "Job_Link"),
  SchoolBlocks = scraper_spec("fetch_schoolblocks_postings", "Job_Link"),
  EdlioTabs = scraper_spec("fetch_wy_edlio_postings", "Job_Link", fixture_prefix = "edlio"),
  GoogleSitesBespoke = scraper_spec("fetch_wy_googlesites_postings", "Job_Link", session = TRUE,
                                    fixture_prefix = "googlesites"),
  EducationalNetworks = scraper_spec("fetch_educational_networks_postings", "Job_Link",
                                     fixture_prefix = "educational_networks"),
  PrairieViewHeuristic = scraper_spec("fetch_prairieview_postings", "Job_Link", session = TRUE, fixture_prefix = "prairieview")
)
WY_OTHER_K12_SCRAPER_SPECS <- list(
  Paylocity = scraper_spec("fetch_paylocity_jobs", list("Platform_Key", function(row) basename(row$Job_Link)))
)
# Colleges. `Job_Link`: the page a person would visit (the drift check's
# corroboration step), not necessarily the endpoint the scraper reads.
# Western was once listed at schooljobs.com/careers/westernwyoming, a real
# but wrong NEOGOV agency that returned a plausible "0 jobs found" page; it is
# on PeopleAdmin. PeopleAdmin: WY keeps its campus names (Location_Label)
# rather than the feed's authors (location_from_author = FALSE).
WY_HE_SCRAPER_SPECS <- list(
  PeopleAdmin = scraper_spec("fetch_peopleadmin_atom", list("Feed_URL", "Location_Label",
                                                            location_from_author = function(row) FALSE)),
  UWHeuristic = scraper_spec("fetch_uw_postings")
)
# The colleges' pages by name.
he_institution_urls <- local({ he <- read_he_registry(); stats::setNames(he$Job_Link, he$Institution) })
# salarymap.csv's fixed columns from he_institution_registry.csv each run
# (2026-11-16, as MT): County, Latitude, Longitude, and the map's Link = the
# registry's Job_Link (the page postings are read from). Rows and every other
# column are left as they are; a college missing from either file stops the run.
refresh_he_static_columns <- function(salarymap, registry = read_he_registry()) {
  i <- match(salarymap$Name, registry$Institution)
  if (anyNA(i) || length(setdiff(registry$Institution, salarymap$Name)) > 0)
    stop("salarymap.csv and he_institution_registry.csv list different colleges: ",
         paste(c(salarymap$Name[is.na(i)], setdiff(registry$Institution, salarymap$Name)), collapse = ", "))
  salarymap$County <- registry$County[i]
  salarymap$Latitude <- registry$Latitude[i]
  salarymap$Longitude <- registry$Longitude[i]
  salarymap$Link <- registry$Job_Link[i]
  salarymap
}

# A school's SAIPE population when the Census geocoder failed and last run's file has none (2026-11-19). The
# carried-over Child_Poverty_Basis ("Surrounding district: A / B") names the host district(s); their population comes
# from this run's SAIPE rows (`saipe`: LEAID, Child_Poverty_Rate, SAIPE_Population), pooled the way
# edjobs::surrounding_district_poverty() pools them, so add_saipe_range() can still give the 90% range. NA when the
# basis is missing or names no district in `saipe`. `district_names`: LEAID -> display name.
carried_surrounding_population <- function(basis, saipe, district_names) {
  if (is.na(basis) || !grepl("^Surrounding district: ", basis)) return(NA_real_)
  hosts <- strsplit(sub("^Surrounding district: ", "", basis), " / ", fixed = TRUE)[[1]]
  ids <- unique(c(names(district_names)[district_names %in% hosts], hosts[hosts %in% as.character(saipe$LEAID)]))
  pool_saipe_population(saipe[as.character(saipe$LEAID) %in% ids, , drop = FALSE])
}

set_state_config(state_config(
  state = "Wyoming", fips = "56", app_dir = "Wy_Ed_Jobs",
  feed = list(short_name = "WSBA", label = "WSBA statewide vacancies", url = "https://www.wsba-wy.org/vacancies",
              discrepancy_file = "wy_discrepancy_report.csv",
              signature = c("wsba", "wyoming")),   # words the page must show (pre-flight canary, edjobs 0.52.0)
  # How the weekly checks name a K-12 row's source (edjobs 0.51.0): archive district names canonicalized, as
  # combinedclean.csv already is (k12_he_classification.R); the feed section counts the direct boards only.
  k12_source_names = function(df) canonicalize_k12_district(df$District),
  direct_registry = read_direct_board_registry,
  # Districts SAIPE has no child poverty rate for (a BOCES; the state's school at the Boys School), so the Census
  # check (edjobs 0.53.0) expects one for every other district in salarymap2.csv.
  saipe_gaps = c("Northeast Wyoming BOCES", "Wyoming Boys School"),
  # The drift corroboration's URL lookup (edjobs 0.55.0): registry links are keyed by the raw spelling ("Converse County
  # School Distrcit 2") while the drift check flags the corrected one, so the keys are canonicalized the same way.
  canonical_source_name = function(x) canonicalize_k12_district(x),
  drift_intro = paste("A source is flagged when it has at least 2 weeks of history averaging real postings, and this week's count dropped to 20% or less of that average.",
                      "This is the same failure signature that hid ~200 real postings across 10 Applitrack districts on 2026-08-03 (a Windows-1252 encoding bug, not real absence of jobs) -- these entries are corroborated against the actual live page but still need a human look."),
  # The first archive that counts toward the drift check's per-source
  # baselines: earlier runs predate fixes that changed the counts.
  drift_baseline_from = "2026-08-03",
  # The boards' own time zone: the day a presence check counts for, a JSON-LD date's local day (edjobs 0.44.0).
  timezone = "America/Denver",
  scraper_sources = list(
    # The registry sits at the repository root; tests run from tests/testthat.
    scraper_registry(read_k12_registry, "District", "k12_district_registry.csv",
                     specs = scraper_specs(c(WY_MISC_SCRAPER_SPECS, WY_OTHER_K12_SCRAPER_SPECS))),
    scraper_registry(read_he_registry, "Institution", "he_institution_registry.csv",
                     specs = scraper_specs(WY_HE_SCRAPER_SPECS))
  ),
  # The auto-fix issue: scraper files read as text; fixtures are named
  # <platform>_<district>..., and several districts share one parser.
  autofix = list(scraper_files = c("direct_api_scrapers.R", "misc_district_scrapers.R"), fixtures_by = "name",
                 fixture_example = "tests/testthat/fixtures/misc_districts/{platform}_<district>_rendered_{date}.txt"),
  # WY's own reference tables (the shared ones are edjobs::REFERENCE_TABLE_RULES).
  reference_tables = list(
    uw_salary_book = list(name = "UW salary book", required = "Salary",
                          bounds = list(Salary = c(1000, 5000000)),
                          year_col = "Fiscal_Year", max_age = 2)
  )
))
