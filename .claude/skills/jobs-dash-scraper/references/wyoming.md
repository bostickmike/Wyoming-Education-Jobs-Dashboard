# Wyoming (`bostickmike/Wyoming-Education-Jobs-Dashboard`)

Pipeline `Wy_ED_Jobs.Rmd` → dashboard `Wy_Ed_Jobs/app.R`. CI runs twice a week, Tuesdays and Fridays (since 2026-11-17). Wyoming has a small, fixed universe: **48 public school districts**, plus a few charters and **9 public HE institutions** (UW + the community colleges).

## Registries (the same schema as Montana's since 2026-11-16)
- `k12_district_registry.csv`: `District, NCES_LEAID, City, County, Latitude, Longitude, Platform, Platform_Key, Job_Link, List_Start, List_Stop, List_Skip`, one row per K-12 scrape target:
  - direct boards `AppliTrack`, `SchoolSpring`, `RedRoverK12` (`Platform_Key` = the numeric org id), `TedK12`, scraped in the Rmd's registry loop (`read_direct_board_registry()`, `state_config.R`);
  - districts and charters scraped from their own sites, on a **platform-level** parser: `Apptegy`, `Edlio` (both the edjobs family routines, with the row's list rules), `EdlioTabs`, `GoogleSitesBespoke`, `WordPressBespoke`, `SmartSites`, `SchoolBlocks`, `EducationalNetworks`, `PrairieViewHeuristic`. `misc_district_registry` (in `misc_district_scrapers.R`) is these rows, and `fetch_misc_district_postings(Platform, Job_Link, session, ...)` dispatches. Wyoming prefers reusable per-CMS parsers over per-district heuristics. Follow that: a new district on Edlio is a one-row registry addition;
  - Laramie Montessori (`Paylocity`, `Platform_Key` = the company id).
  `City` is blank in WY for now. Fixture names keep their old lowercase prefixes (`educational_networks_...`, `googlesites_...`); the spec's `fixture_prefix` maps them.
- `he_institution_registry.csv`: `Institution, County, Latitude, Longitude, Platform, Feed_URL, Job_Link, Location_Pattern, Location_Label` (`Neogov` with the agency slug in `Feed_URL`, `PeopleAdmin` with the Atom feed and WY's campus name in `Location_Label`, `UWHeuristic`). The Rmd loops over it in file order.

`edjobs::resolve_scraper_call(name)`, reading `state_config.R`'s `scraper_sources`, resolves a source name across both registries. `scripts/repro_scraper.R "<name>"` uses it.

## Statewide feed
**WSBA vacancies** (`wsba-wy.org/vacancies`, `fetch_wsba_vacancies()` in `misc_district_scrapers.R`) covers districts without their own structured board, and is de-duplicated against direct postings (`dedupe_against_wsba`, `remove_wsba_direct_duplicates`). Districts that appear on WSBA but have no direct scraper are the natural discovery list.

## Discovery list
There's no backlog file. Build one from the 48-district universe (WDE directory, WSBA's district names via `canonicalize_wsba_district()`) minus the K-12 registry. Coverage is already high, so the remaining wins are mostly districts that only post through WSBA, and charter schools. If you start tracking declines, propose a `DISTRICT_BACKLOG.md` in the same format as Montana's, rather than leaving them in chat.

## Files that change together when adopting
1. A `k12_district_registry.csv` row.
2. A parser only when the CMS is new to Wyoming. Add it as a platform-level `fetch_<cms>_postings` / `parse_<cms>_postings` pair, plus a branch in `fetch_misc_district_postings()`, a name in `MISC_DISTRICT_PLATFORMS`, a spec in `state_config.R`'s `WY_MISC_SCRAPER_SPECS` (a platform edjobs already scrapes needs no spec: `edjobs::default_scraper_specs()`; its registry row needs `Platform_Key` where the spec reads it, e.g. AppliTrack's tenant path, SchoolSpring's domain) and a label in `K12_PLATFORM_SOURCE_LABELS`.
3. Fixture + tests (`test-misc-district-platform-extractors.R` for platform parsers, `test-misc-district-orchestration.R` for registry/dispatch).
4. `.github/copilot-allowlist.txt` + `test-copilot-allowlist.R` (same contract as Montana).
5. `misc_district_coverage_tiers()` / Data_Coverage disclosure, if the district's coverage tier changes.
6. Counts in `README.md` / `CLAUDE.md` / `METHODS.md`.

## Quirks
Sheridan/Gillette had a district split that has its own test (`test-sheridan-gillette-split.R`). UW's paginated feed has had duplicate-row bugs (`repair_uw_pagination_duplicates.R`). Repairs follow `--dry-run` then `--apply`.
