# Backfilling history from web archives (Wayback Machine and others)

Use this when a state's statewide board, or a district or college board, existed before we started scraping it, and
the question is what it listed then. Built on WY's WSBA list and OPI's boards (2026-11-13/14; notes and code in the
workspace's `claude-notes/2026-11-13_wayback-backfill-idea.md` and `claude-notes/2026-11-13_wayback/`). Mike's aim:
a historical record and a publication, extending Mark Perkins's Data 2025 paper and AERA 2026 poster.

## Ground rules
- **Archive rows are never weekly-run rows.** Keep them in their own files with `Data_Origin = "Internet Archive
  snapshot"` and the capture timestamp, and never mix them into the weekly series, spells or durations without a
  label. Mike, 11-13: "we would need some sort of distinction between the two".
- **Measure trust on the overlap first:** where archive captures and our own runs cover the same weeks, compare them
  before using the earlier years.
- **Be slow and cache everything:** one request every ~5 s, back off on 429/5xx, save every page, and never fetch
  the same page twice. The Archive is free and rate-limited.
- **Long fetches are started by hand,** with the Mac plugged in and `caffeinate -imsu` (not `-d`). Never as a
  launchd/cron job on Mike's Mac. A chunked GitHub Actions run is the alternative. Not Tempest: the dashboards are a
  personal project, separate from MSU work.
- **Also ask the owner.** A state agency's board is often its own database (OPI's Jobs for Teachers), and an export
  request may beat any archive. Ask early, because answers take weeks.

## Step 1: find what was captured (the CDX index)
`scripts/wayback_index.sh <url> <out_dir> [prefix|exact|host|domain]` lists every status-200 capture, page by page,
and can be rerun to fill gaps. Each line is: timestamp, urlkey, original, mimetype, length, digest.
- **Try every URL variant and the real host.** The board's address may have moved (`vacancies.asp` -> `.aspx` ->
  `/vacancies`), and the public "front door" may not be where the listings lived: OPI's `jobsforteachers.mt.gov`
  (2006-2016) linked to `www.metnet.mt.gov/TPlacement/`. Open a capture of the front door and follow its links.
- **What each kind of capture gives you:**
  - A **listing page** is a snapshot of what was open that day. Captures are irregular (WSBA: median gap 25 days),
    so a listing gives levels and seasonality, not durations.
  - A **per-posting page** states its own dates: OPI's old pages give posted time, closing date, salary and the
    description. Dates then come from the page, not the capture, so one capture per posting is enough. When both
    kinds exist, the per-posting pages are the better source.
  - **ASP.NET postback pages** (pagination, "details" buttons) are not crawled, so only the first page survives
    (OPI's current board: the newest ~50).
- **Revisits** (the crawler saw unchanged bytes) share a `digest`. Fetch one copy per digest for a listing page.

## Step 2: pick one capture per page
`scripts/wayback_pick.sh <index_dir> '<urlkey regex>' > list.tsv` picks the earliest text/html capture per distinct
page and writes `id, timestamp, original` rows. URLs with a query string are dropped by default (`KEEP_QUERY=1` keeps
them): they are usually the same page reached another way (OPI had 5,008 such variants). Split a big list into
chunks with `split -l 1000`, so each night has a clear end point.

## Step 3: fetch
`[STOP_AT=07:00] [MAX_FAILS=5] [PAUSE=5] caffeinate -imsu scripts/wayback_fetch.sh list.tsv raw_dir/`
- It fetches **raw copies** (`<timestamp>id_/<url>`), the page as served without the Archive's toolbar or
  rewritten links, so our own parsers read them unchanged.
- It **follows redirects.** The Archive 302s to the nearest capture when a timestamp isn't exact. Without `-L`, those
  pages come back empty: on 11-14, 17 such "failures" each spent ~10 min in retries and looked like throttling.
- It stops at `STOP_AT`, or after `MAX_FAILS` pages in a row fail all retries (real throttling). A rerun skips saved
  pages. The log is `raw_dir.log`.
- Speed: ~1,000 pages in about 1.5 h at the default pause.
- A 200 body reading "Temporarily Offline" is the Archive being down, not a page: the script retries it.

## Step 4: parse per era, label, compare
- **Layouts change across the years** (WSBA 2024-26 parses with the current `parse_wsba_vacancies()`; 2018-23 needs
  its own parser; 2012-17 only partly matches). Score each era's parser against hand-checked captures before trusting
  its rows, as for any new scraper.
- **Run the rows through the same classifier** (edjobs), so roles line up with the weekly data.
- Output: one row per posting (or per posting per snapshot for listings), with `Data_Origin`, `Capture_Timestamp`,
  the archive URL, and the fields the page itself states.

## Other archives
- **Common Crawl** (`index.commoncrawl.org`): query `url=<page>&matchType=prefix` per crawl. A wildcard
  `url=host/path*` gave HTTP 400, and the index 504s under load, so go slowly and resumably.
- **Memento Time Travel** (one query across archive.today, the Library of Congress, the UK Web Archive, Arquivo.pt and
  others): the timemap JSON call returned nothing usable on 11-13; recheck the endpoint format before relying on it.
- Perma.cc, ArchiveBox, Ghost Archive and MirrorWeb save pages from now on; they hold no past copies of our boards.

## What we found (for comparison when adding a state)
| Source | Archive holdings | Use |
|---|---|---|
| WSBA vacancies (WY statewide) | 125 days with a good copy, 2012-07 to 2026-10 | listing snapshots; per-era parsers |
| OPI current board (MT) | 107 listing days 2016-12 to 2026-10, first page only | newest ~50 per day |
| OPI old board `metnet.mt.gov/TPlacement` (MT, also some WY districts) | 10,210 posting pages 2006-2016; 267 front-page days with open counts | per-posting dates, salary, closing date |
| MSU PeopleAdmin postings | 1,618 captures 2015-2026 | per-posting dates (not yet tried) |
