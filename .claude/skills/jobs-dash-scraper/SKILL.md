---
name: jobs-dash-scraper
description: Find, build, and repair direct job-posting scrapers for the Montana and Wyoming Education Jobs Dashboards (bostickmike/Montana-Education-Jobs-Dashboard, bostickmike/Wyoming-Education-Jobs-Dashboard). Covers three jobs -- (1) fixing a scraper that went quiet or was flagged likely_broken / scraper-autofix by the drift check, (2) discovering K-12 districts or colleges that aren't directly scraped yet (DISTRICT_BACKLOG.md, the OPI/WSBA statewide lists, HE institutions) and adopting them with a registry row, scraper, real fixture and tests, and (3) re-checking previously declined districts to see if their page now has a scrapeable structure. Use this whenever the user is in either jobs-dash repo and mentions a broken/quiet/zero-posting district or college, a scraper-autofix issue, adding districts, "increase coverage", the backlog, OPI/WSBA gaps, identifying what job platform a school site uses, or when running in GitHub Actions on an auto-fix issue -- even if they don't say "scraper".
---

# Jobs-dash scraper work

These two repos scrape every Montana / Wyoming school district and college job board they can, weekly, into a Shiny dashboard. More direct scrapers means better coverage. That only holds if each one returns *real postings*, though. A scraper that silently returns nav links, standing application forms, or another state's district is worse than no scraper, because it pollutes counts that people read as vacancy data.

So everything below serves one rule: **nothing gets written into a parser, a fixture, or the registry until you have seen the live page yourself and know what's on it.** The project's history is full of plausible-but-wrong leads, like subagents misidentifying Apptegy as Finalsite, same-named towns in other states, or "openings" pages that turn out to be evergreen forms. Live verification is what catches them.

## First: orient

1. Work out which repo you're in (`git remote -v`) and read that state's reference file. It covers layout, registry schema, statewide feed, counts, and the files that must change together:
   - Montana → `references/montana.md`
   - Wyoming → `references/wyoming.md`
2. Read the repo's own `CLAUDE.md`. It's maintained and authoritative, and it outranks this skill if they disagree. Tell the user about any disagreement you find.
3. Work out which task you've been given, then read its reference:

| Task | Signal | Read |
|---|---|---|
| **Fix** a broken scraper | a `scraper-autofix` issue, "X went quiet / 0 postings", drift-check flag, scrape_log errors | `references/fix-broken-scraper.md` |
| **Discover** new targets | "find districts we're missing", "work the backlog", "increase coverage", HE gaps | `references/discovery.md`, then adopt |
| **Adopt** a verified target | a specific district/college with a URL to add | `references/adopt-new-source.md` |
| **Recheck** declined targets | "recheck the declined ones", backlog Groups 2/3/7 | `references/discovery.md` § Recheck |

`references/platform-fingerprints.md` maps page signatures to platforms and to the existing scraper for each. You'll need it in every task.

## Identify the platform before writing any code

The cheapest win is a district on a platform that already has a scraper. In that case adoption is just a registry row. Three Forks, Anaconda, and Philipsburg added 42 postings that way, and Butte, Belgrade, and Hamilton were fixed the same way after they migrated off AppliTrack. Always check this before anything bespoke:

```bash
python3 <skill-dir>/scripts/fingerprint_platform.py <url> [<url> ...]
```

It fetches the raw HTML and reports known platform signatures, outbound ATS links (an employment page that just links to `applitrack.com/<slug>` is an AppliTrack district), and whether the page looks JS-rendered (a tiny body with no text means you need chromote, so look at the rendered innerText before concluding anything). It's a lead generator, and it can be wrong. Confirm by looking at the live page, through the rendered text when it's JS-heavy.

## Bespoke heuristic scrapers: when yes, when no

Build one only when the live page has a **structural marker** that separates postings from everything else: a heading the openings sit under, a stable start/stop text marker, a list or table, or a JSON payload. Decline, and record why, when:

- openings are only in free prose (that's the LLM-extract shadow pilot in Montana, not a scraper; see the state reference)
- the page only offers generic "apply here" / application-form links, with no titles
- postings sit behind a login, a Google Drive folder, or a scanned PDF
- the page is stale, contradictory, or belongs to a same-named district in another state

One confirmed case isn't worth a whole new extraction technique (the Box Elder precedent). But when a real page has real postings and the existing approach demonstrably returns 0, build the new technique properly. Apptegy's embedded-JSON decoder came about that way. In local sessions, ask the user if the right investment level isn't clear.

## Non-negotiables (they each come from a real incident)

- **Fixtures are real captured data**, saved verbatim, dated (`<source>_<kind>_YYYY-MM-DD.{html,txt,json}`), and in the form the parser consumes. innerText scrapers get a `.txt` of `document.body.innerText`. Never hand-write or "tidy" a fixture.
- **Keep old fixtures and their tests passing.** Sites flip between layouts, so a fix handles both.
- **Respect the parser's existing scope.** Read the comment above the `parse_*` function and the existing tests. Some sources deliberately exclude standing substitute lists, and some count them. Restore what the parser used to find, and mention anything new instead of quietly widening it.
- **HTTP goes through `perform_with_retry()`** (`scrape_helpers.R`), not bare `req_perform()`. Every scraper returns `Title, Location, Posted_Date, Link` and is wrapped by `safe_scrape()` upstream.
- **Posting identity is a contract** (Montana `DATA_COOKBOOK.md` → "Posting identity"). Use a real per-posting URL as `Link` when one exists. Never use the board/listing URL as if it identified one posting.
- **Don't touch** accumulated data (`Mt_Ed_Jobs/`, `Wy_Ed_Jobs/`), the archives, or `REQUIRED_SCHEMAS`.
- **Run the full suite before you're done:** `Rscript -e 'testthat::test_dir("tests/testthat")'`. Several tests are coupled to the registry, so adding a row breaks them until you update the matching lists. The state reference names them.

## Running in GitHub Actions (unattended)

If you were launched by the `claude-autofix` workflow, you're fixing exactly one issue, with no human to ask. Read `references/ci-automation.md` before anything else. Short version: do the fix procedure, open a PR whose body contains `Fixes #<issue>`, and when the fix belongs to a human (site moved platforms, site is erroring, page is genuinely empty, you can't reproduce what CI saw) **comment on the issue explaining what you found and stop**. Never edit the registry or workflows in CI.

## Finishing a local session

- Commit per batch (one fixed scraper, or a 3–6 district adoption batch), each with a message explaining what was found, what was declined, and why. Don't push unless the user says to. Run `git fetch` first, because the weekly bot pushes data commits to `main`.
- Update the state's backlog / decline record, so nobody re-investigates a district you already resolved.
- Report back in a compact table: district, URL, platform, outcome (added / fixed / declined + reason), postings found live.
