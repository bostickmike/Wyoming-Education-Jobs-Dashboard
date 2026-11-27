# Methods: how the Wyoming dashboard's numbers are made

This page explains what the [Wyoming Education Jobs Dashboard](https://bostickmike-wyoming-education-jobs-dashboard.share.connect.posit.cloud)
counts and how. Every column of every file is defined in [DATA_DICTIONARY.md](DATA_DICTIONARY.md); this page
covers the choices behind them and their limits.

## What is counted

- **Postings, not vacancies.** A posting is one job advertisement listed on a board when the dashboard read it. A
  district can advertise one job twice, or keep an ad up after the job is filled; a vacancy can go unadvertised.
- **K-12:** the job boards of all 48 Wyoming school districts and four of its five charter schools, plus the
  Wyoming School Boards Association's [statewide vacancies list](https://www.wsba-wy.org/vacancies) (WSBA). WSBA
  also brings in the fifth charter school and four other employers (a BOCES, two early-childhood centers and the
  Wyoming Boys School), so every posting has a place on the map.
- **How the boards are read:** most districts use a job-board platform (AppliTrack, SchoolSpring, Red Rover,
  TedK12, Paylocity). Thirteen post on their own websites, which are read directly, together with WSBA; their
  counts are marked "Partial" because a website read can miss postings.
- **Higher education:** the job boards of 9 colleges: the University of Wyoming's own careers site and the community
  colleges' NEOGOV and PeopleAdmin boards.
- **When:** every board is read twice a week, Tuesdays and Fridays (Fridays only before 2026-11-17). Each reading is
  an *update*, and every file records its date (`Archive_Date`).
- **Since:** August 2024.

## One posting, one ID

Each posting gets a `Posting_ID` that stays the same in every update it appears in, so counts, "new this week" and
listing durations follow the posting rather than the row. Where a board gives each posting its own address or job
number (AppliTrack, SchoolSpring, Red Rover, TedK12), the ID is built from that. Where it doesn't (district
websites, WSBA), the ID is built from the district, link, title, location and posted date
(`Posting_Identity_Method` says which). Two postings identical in all of those are kept as two rows, not merged.

## WSBA postings: when they count

Many districts list the same job on their own board and on WSBA's list. The dashboard counts it once, from the
district's board: a WSBA posting doesn't count when the district's board has a posting with the same district,
title and posted date, or when WSBA's link names the board posting's job number. That district posting is marked
`Also_On_Feed`. Every other WSBA posting counts: many jobs, especially at districts without a platform board, are
listed only there. WSBA is an association's list, not a census of vacancies, and a job missing from the dashboard
is not evidence that no vacancy exists.

## Old board ads

A job board can keep an ad listed, and keep taking applications through it, until the district takes it down,
whatever dates the ad shows: AppliTrack's closing date is a note the district types, not a deadline the board
enforces. A district board posting (AppliTrack, SchoolSpring, Red Rover, TedK12 or a
dated district website) whose posted date, or stated closing date, is before the July 1 that began the previous
school year (July 1, 2025 during the 2026-27 school year) doesn't count. Two kinds of ads count whatever their
dates: standing pools (substitutes), and jobs districts advertise all year and fill again and again (bus drivers and
bus aides, paraprofessionals and aides, custodians and maintenance staff, food service, athletic coaches). A WSBA
posting that is the same ad (it links the posting, or has its district, title and posted date) doesn't count
either. The raw postings keep the old ads, each with its reason (`Stale_Reason`); the counts and the Jobs table leave
them out. On the November 20, 2026 postings the rule would have set aside 6 of 688 board postings. A date can't show
which old ads are still real openings: a specialist post a district has struggled to fill (a speech pathologist, an
occupational therapist) may be one. The rule began with the November 27, 2026 update, and on November 26 the whole
history, back to August 2024, was recomputed under it (see "Files and history"): each earlier update's ads are judged
by that update's own date, so every week shown is counted the same way. It set aside 3 to 28 postings a week, and up
to 10 teaching postings (most of them Fremont County School District #38's ads from 2023 and 2024, still listed in 2025).

## Categories

- **K-12 position** (`position`), from the title: Teacher, Substitute, Paraprofessional, Athletics, Support Services,
  Transportation, Custodial/Maintenance, Administration, Food Services, and others.
- **Teaching subject** (`Category`, grouped in `Broad_Category`), for teaching postings, from the title.
- **College job type** (`Job_Type`): Instructor/Teacher/Faculty, Adjunct/Part-Time Faculty, and staff types
  (Professional, Management, Research & Science, Technical, and others); faculty postings also get a discipline.

The rules are written by hand and checked against a hand-labeled set of real titles. The category files
(`allsum.csv`, `k12jobanalysis.csv` and their college counterparts) cover teaching or faculty postings only.

## Pay

- **Posted pay** (`Pay_Min`, `Pay_Max`, `Pay_Unit`, `Pay_Text`): only what the posting itself states, in its own
  unit, never converted. The text it came from is kept. An amount implausible for its unit is left blank.
- **Typical pay (BLS est.)**, K-12, where the posting states no pay: the Bureau of Labor Statistics' median pay for
  the role in the posting's region ([OEWS](https://www.bls.gov/oes/)), across all employers. A regional estimate,
  not this job's offer.
- **College pay estimate**, salaried staff postings: the college's average salary for full-time staff in the
  matching [IPEDS](https://nces.ed.gov/ipeds/) category; for University of Wyoming staff, the median salary of UW
  staff with the matching title in UW's published salary listing. Shown even when the posting states pay. An
  average for the category or title, not this job's offer.
- **Teacher salary** (Districts tab): WSBA's salary documents (starting base salary for a teacher with a bachelor's
  degree, and the superintendent's salary) and the Wyoming Department of Education's
  [WDE602 staff collection](https://edu.wyoming.gov/) (average teacher salary, and staff pay by position). WSBA
  keeps no archive, so `k12_salary_history.csv` holds each year the dashboard has captured.

## Vacancy rate

Current teaching postings divided by the district's full-time-equivalent teachers ([NCES Common Core of
Data](https://nces.ed.gov/ccd/)), or current faculty postings divided by the college's full-time instructional
staff (IPEDS). It is left blank under 10 FTE, where a few postings would give a misleading rate. Sheridan College
and Gillette College report to IPEDS as one institution while they separate, so they share one rate.

## Listing duration

The Listing Duration tab lists each posting with the first and last update that showed it (`job_duration_spells.csv`,
`he_job_duration_spells.csv`). Days listed is the span from the first to the last sighting, plus 7 days; a posting
that disappears for more than 21 days and comes back under the same title starts a new row. It starts at the
first sighting, which is often after the posting went up, and "no longer listed" means only that it stopped
appearing.

Days listed is not time to fill: filled jobs can stay posted, and open jobs get reposted. For that reason the tab
shows the table only, without medians or charts, until a more careful measure has been checked.

That measure is built and published at the repository root (`posting_spells_k12.csv`, `posting_durations_k12.csv`
and their HE counterparts), not yet on the dashboard:

- **Start:** the board's posted date when plausible (on or before the first sighting, at most a year earlier);
  otherwise the first update that found it. A posting already listed the first time the dashboard read its board has
  an unknown start (*left-censored*).
- **End:** a posting counts as ended only when its board was read successfully in the next update and it was gone. If
  the board failed or moved, the end is unknown (*censored*).
- **Left out of the medians, but kept in the files:** standing ads and pools ("Substitute Teachers", always
  hiring), boards that stopped changing (frozen), same-title postings that can't be told apart, and unknown starts.
- Medians use the Kaplan-Meier method, so postings still listed count for as long as they've been up. The mechanics,
  with a worked example, are in the edjobs package's [posting spells vignette](https://github.com/bostickmike/edjobs/blob/main/vignettes/posting-spells.Rmd).

## Context data

District and college context comes from public sources, joined by NCES or IPEDS id:

- [NCES Common Core of Data](https://nces.ed.gov/ccd/): staff, enrollment, free and reduced-price lunch.
- [Census American Community Survey](https://www.census.gov/programs-surveys/acs) (5-year): county income, rent,
  mining and energy jobs, population change, with margins of error.
- [Census SAIPE](https://www.census.gov/programs-surveys/saipe.html): child poverty by district, with its range.
- [IPEDS](https://nces.ed.gov/ipeds/): faculty pay and count, enrollment, staff pay; Federal Student Aid: Pell share.
- BLS [OEWS](https://www.bls.gov/oes/) and [QCEW](https://www.bls.gov/cew/): regional pay by role, county school pay.

CCD, IPEDS and Federal Student Aid figures come through the
[Urban Institute Education Data Portal](https://educationdata.urban.org).

A blank means the source has no figure (suppressed, or not reported), not that the dashboard skipped it. When a
source fails in a update, the previous update's values are kept rather than blanked.

## Files and history

- `combinedclean.csv`, `hedata.xlsx`, `allnow.csv` and `allnow_he.csv` hold the latest update only. The other files
  grow by one update at a time.
- Every update also saves the raw postings (`Archivek12_Data/`, `Archived_HE_Data/`). The history files can be rebuilt
  from them exactly, and every update checks that they are.
- A change to a counting rule applies from the next update on; earlier updates keep the counts they had unless the
  history is recomputed from the raw files.

---

This page replaced `DATA_COOKBOOK.md` on 2026-11-23. The cookbook's engineering notes (dates, platform details,
how each rule was measured) are in that file's git history.
