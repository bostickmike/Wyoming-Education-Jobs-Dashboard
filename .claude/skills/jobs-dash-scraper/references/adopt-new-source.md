# Adopting a verified district or institution

You only get here once you've seen real current postings on the live page and know its platform (see `discovery.md`). Adoption touches several files that have to agree with each other. The state reference has the exact list for that repo, and the test suite enforces most of it.

## Steps (Automated Workflow)

1. **Probe the live URL**:
   ```bash
   Rscript scripts/probe_district.R "<url>"
   ```
   Confirms live postings exist and flags bot-gate status / platform before downloading.

2. **Capture fixture with automatic secret sanitization**:
   ```bash
   Rscript scripts/capture_fixture.R --url "<url>" --slug "<slug>"
   ```
   Saves to `tests/testthat/fixtures/<slug>_jobs.html` with all `AIza...` Google API tokens automatically redacted.

3. **Scaffold mechanical changes across 6 coupled files**:
   ```bash
   Rscript scripts/scaffold_district.R \
     --district "Full District Name" \
     --city "City" \
     --county "County Name" \
     --lat 48.1234 \
     --lon -114.5678 \
     --url "https://..." \
     --slug "<slug>"
   ```

4. **Implement parser selector & update test assertions**:
   - Write selector logic in `parse_<slug>_postings` inside `misc_district_scrapers.R`.
   - Update `tests/testthat/test-misc-district-scrapers.R` with expected titles from the fixture.

5. **Verify the batch**:
   ```bash
   Rscript scripts/verify_batch.R
   ```
   Runs all allowlist, salary setdiff, schema check, data integrity, deduplication, and unit tests, and guards against committing Claude autofix experiment files.

6. **Verify live scraper execution**:
   ```bash
   Rscript scripts/repro_scraper.R "<new registry name>"
   ```

7. **Commit per batch** of 2–4 districts.

## Apptegy (Montana)

Apptegy sites sit behind a Fastly "Client Challenge" that a plain request can't pass, so they ride the pipeline's shared headless-Chrome session (`fetch_apptegy_k12_postings()`). Since edjobs 0.18.0 every Apptegy district reads through one family routine, `edjobs::fetch_apptegy_postings()`: no per-district code. Registry Platform `Apptegy` reads the rendered text (most districts); `ApptegyPageBuilder` reads the page-builder JSON, for pages whose jobs sit in collapsed accordions, buttons or cards (Conrad, Gardiner, Drummond, Deer Lodge, Savage, Olney-Bissell). Optional per-district rules (where the list starts, where it stops, a section to skip; perl regexes) are rows in `k12_list_rules.csv`. A page the shared filter can't read (Shelby: titles inside a sentence) is `ApptegyBespoke`, with its own scraper in `APPTEGY_DISTRICT_SCRAPERS`.

1. **Capture the rendered page** (headless Chrome, as the pipeline renders it; `AIza...` keys redacted; refuses a page without page-builder data):
   ```bash
   Rscript scripts/capture_fixture.R --apptegy --url "<employment page>" --slug "<slug>"
   ```
   Saves `tests/testthat/fixtures/apptegy_<slug>_rendered_<today>.txt` (innerText) and `apptegy_<slug>_pagedata_<today>.html` (about 1.2 MB). Look at the text: if the postings are in it, the page is text mode (delete the `.html`); if they only show up in the page-builder data (`edjobs::decode_apptegy_pagebuilder_nodes()`), it is page-builder mode (delete the `.txt`).
2. **Scaffold** (`--cms apptegy` is picked automatically when either fixture exists; the text one wins):
   ```bash
   Rscript scripts/scaffold_district.R --district "<exact registry name>" --city "<town>" \
     --county "<County> County" --lat <lat> --lon <lon> --url "<employment page>" \
     --slug "<slug>" --leaid <NCES id> [--node text|pagebuilder] [--start "<regex>"] [--stop "<regex>"] [--skip "<regex>"]
   ```
   It writes the registry row (with its list rules when one is given), the allowlist host, the DLI-unmapped test entry, a `test-apptegy-family.R` block asserting the titles the routine returns on the fixture, and the README/METHODS counts. It prints the titles: **check them against the live page**. Wrong or missing titles: try the other `--node`, or a `--start`/`--stop` rule (rerun after deleting the test block it wrote). Rerunning is safe (each step skips what's there).
3. **Finish by hand:** `DISTRICT_BACKLOG.md`, CLAUDE.md's district count, the DLI map if there is one, the repo's Copilot internet-access setting. Change the shared filter (edjobs `R/apptegy.R`) only for a pattern several districts share, and rerun both states' family tests when you do.
4. Tests (`test-apptegy-family.R`, `test-salary-scrapers.R`, `test-copilot-allowlist.R`), then `scripts/repro_scraper.R "<District>"` for the live run.

## Sanity checks that have caught real mistakes

- The live count you report in the commit is what the scraper returned, not what you eyeballed.
- Titles look like jobs: no "Apply Now", "Employment Application", "Substitute Application" (unless that source counts subs), or nav text.
- `Location` is the district/town, not the state or a blank.
- `Link` is a per-posting URL when the site has one. If not, it's the board URL, and the posting-identity fallback handles it. Don't invent anchors.
