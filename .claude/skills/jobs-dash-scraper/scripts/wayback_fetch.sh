#!/usr/bin/env bash
# Fetch archived pages listed in a TSV (id, timestamp, original URL; from wayback_pick.sh), politely and resumably.
#   [STOP_AT=07:00] [MAX_FAILS=5] [PAUSE=5] caffeinate -imsu wayback_fetch.sh <list.tsv> <raw_dir>
# - Raw copies (`id_`): the page as served, without the Archive's toolbar or rewritten links.
# - Follows the Archive's redirects (it 302s to the nearest capture when a timestamp isn't exact); without -L
#   those come back empty and look like failures.
# - PAUSE seconds between pages; each failure retries 4 times, waiting 1, 2, 3, 4 minutes.
# - Stops at STOP_AT (local time, next occurrence) or after MAX_FAILS pages in a row fail (throttled).
# - Saved pages are skipped, so a rerun continues where the last one stopped. Log: <raw_dir>.log.
# Start it by hand (never as a launchd/cron job on Mike's Mac). Mac plugged in, lid open. Not -d on caffeinate
# (that keeps the screen on all night).
set -uo pipefail
list=$1; raw=$2; mkdir -p "$raw"; log="${raw%/}.log"
pause=${PAUSE:-5}; max_fails=${MAX_FAILS:-5}; stop_at=${STOP_AT:-}
stop_epoch=""
if [ -n "$stop_at" ]; then
  stop_epoch=$(date -j -f "%Y-%m-%d %H:%M" "$(date +%Y-%m-%d) $stop_at" +%s)
  [ "$stop_epoch" -le "$(date +%s)" ] && stop_epoch=$((stop_epoch + 86400))
fi
saved() { ls "$raw" | grep -vc '\.tmp$'; }
echo "== $(date '+%F %T') start $list (stop ${stop_at:-none}, max fails $max_fails)" >> "$log"
fails=0
while IFS=$'\t' read -r id ts orig; do
  [ -n "$stop_epoch" ] && [ "$(date +%s)" -ge "$stop_epoch" ] && { echo "== $(date '+%F %T') stop time; $(saved) saved" >> "$log"; exit 0; }
  f="$raw/${id}_${ts}.html"; [ -s "$f" ] && continue
  ok=0
  for try in 1 2 3 4; do
    curl -sL --max-redirs 3 --proto-redir =https --max-time 60 -o "$f.tmp" "https://web.archive.org/web/${ts}id_/${orig}"
    if [ -s "$f.tmp" ] && ! grep -q 'Temporarily Offline' "$f.tmp"; then mv "$f.tmp" "$f"; ok=1; break; fi
    rm -f "$f.tmp"; sleep $((60 * try))
  done
  if [ $ok = 0 ]; then
    echo "$(date '+%F %T') failed $id $ts" >> "$log"; fails=$((fails + 1))
    [ $fails -ge "$max_fails" ] && { echo "== $(date '+%F %T') $fails failures in a row, stopping; $(saved) saved" >> "$log"; exit 0; }
  else fails=0; fi
  sleep "$pause"
done < "$list"
echo "== $(date '+%F %T') list done; $(saved) saved" >> "$log"
