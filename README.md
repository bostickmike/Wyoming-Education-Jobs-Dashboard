# Daily presence check

Written by the daily presence workflow (bostickmike/edjobs, `.github/workflows/presence.yml`); never edit by hand.
Each day, every board on a platform with stable posting IDs is read once (list pages only), with the same call
the weekly run makes, and so is each statewide feed (MT's OPI, WY's WSBA), keyed by a fingerprint.

- `presence_checks.csv`: one row per board per day. `Status`: ok, empty (answered with no postings) or error.
  `N_Keyed`: postings with a key (`Link_Key`).
- `presence_sightings.csv`: one row per unbroken stretch of sightings of a posting on a board. A stretch ends
  when its board answered a check without it; days the board errored or wasn't checked don't break it.
  `Link_Key`: `edjobs::k12_link_posting_id()` of the posting's link, or for a feed `edjobs::opi_posting_key()` /
  `wsba_vacancy_key()` with an occurrence suffix. `District` is the posting's district; `Board` the board or feed.
