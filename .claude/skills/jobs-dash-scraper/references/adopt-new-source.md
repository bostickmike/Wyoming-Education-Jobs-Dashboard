# Adopting a verified district or institution

You only get here once you've seen real current postings on the live page and know its platform (see `discovery.md`). Adoption touches several files that have to agree with each other. The state reference has the exact list for that repo, and the test suite enforces most of it.

## Steps

1. **Capture a real fixture.** Fetch it the way the scraper will, whether that's an API response, raw HTML, or the chromote innerText for JS-rendered pages. Save it dated in `tests/testthat/fixtures/`. For a zero-code platform add, a fixture is still worth it if the district's board has a quirk; otherwise a live run in the commit message is enough, which matches how earlier registry-only swaps were done.

2. **Scraper.**
   - *Existing platform:* no new parser. For Apptegy / Red Rover / other chromote-driven boards, check whether there's a per-district dispatch table (Montana's `APPTEGY_DISTRICT_SCRAPERS`, the shared-chromote district list in `Mt_ED_Jobs.Rmd`) that needs an entry.
   - *Bespoke:* add a `fetch_<name>_postings()` (I/O only) plus `parse_<name>_postings()` (a pure function of the captured text/HTML, so it's testable on the fixture) pair, in the right tier file (structured API → `direct_api_scrapers.R`, heuristic → `misc_district_scrapers.R` / `misc_college_scrapers.R`). Put a comment above it saying what marker it keys on, and its scope: whether substitutes count, which sections are excluded, and why. Use `perform_with_retry()`. Return `Title, Location, Posted_Date, Link`. Prefer a reusable platform-level parser (Wyoming's `parse_edlio_postings`, `parse_schoolblocks_postings`; Montana's `parse_redrover_postings`) over a one-off whenever the structure is the platform's and not the district's.

3. **Tests.** In the matching `test-*.R`, assert the exact titles read off the fixture, plus at least one negative (a nav link or boilerplate line that must *not* come through). If the scraper resolves through `drift_check.R`'s `resolve_scraper_call()` / `SCRAPER_CALL_SPECS`, make sure the new platform/heuristic name resolves there too. Otherwise drift checks and `repro_scraper.R` can't reach it, and a future break won't be auto-fixable.

4. **Registry + wiring.** Add the registry row (full schema; Montana needs real lat/long and the county), then wire the call into the pipeline `.Rmd` if the platform isn't registry-driven.

5. **Registry-coupled files.** These go in the same commit (see the state reference for the current list), e.g. Montana's Copilot allowlist host, the salary-map "not yet covered" list in `test-salary-scrapers.R`, the documented district count in `README.md` / `CLAUDE.md` / `DATA_COOKBOOK.md`, and the backlog record.

6. **Verify.**
   ```bash
   Rscript scripts/repro_scraper.R "<new registry name>"     # live run returns the real postings
   Rscript -e 'testthat::test_dir("tests/testthat")'        # full suite green
   ```
   `git diff --stat` should show only what you meant to change.

7. **Commit per batch** of 3–6 districts. In the message, name each district: URL, platform, postings found live, and anything declined in the same pass with its reason.

## Sanity checks that have caught real mistakes

- The live count you report in the commit is what the scraper returned, not what you eyeballed.
- Titles look like jobs: no "Apply Now", "Employment Application", "Substitute Application" (unless that source counts subs), or nav text.
- `Location` is the district/town, not the state or a blank.
- `Link` is a per-posting URL when the site has one. If not, it's the board URL, and the posting-identity fallback handles it. Don't invent anchors.
