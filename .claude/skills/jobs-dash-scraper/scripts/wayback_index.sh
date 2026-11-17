#!/usr/bin/env bash
# List every status-200 Wayback capture under a URL (CDX API, paged), resumably.
#   wayback_index.sh <url> <out_dir> [matchType]      matchType: prefix (default), exact, host, domain
# Writes <out_dir>/page_NN.txt, one capture per line: timestamp urlkey original mimetype length digest.
# Rerun to fill pages that failed. Worked example: metnet.mt.gov/TPlacement (OPI's old board), 61 pages,
# 278,672 captures (2026-11-13). See references/web-archive-backfill.md.
set -uo pipefail
url=$1; out=$2; match=${3:-prefix}; mkdir -p "$out"
cdx="https://web.archive.org/cdx/search/cdx?url=${url}&matchType=${match}&filter=statuscode:200"
n=$(curl -s --max-time 120 "${cdx}&showNumPages=true" | tr -dc '0-9')
[ -z "$n" ] && { echo "no page count (the CDX server may be down; retry later)"; exit 1; }
echo "$n index pages for $url"
for p in $(seq 0 $((n - 1))); do
  f="$out/page_$(printf %03d "$p").txt"; [ -s "$f" ] && continue
  for try in 1 2 3 4 5 6; do
    curl -s --max-time 300 "${cdx}&fl=timestamp,urlkey,original,mimetype,length,digest&page=$p" > "$f.tmp"
    if [ -s "$f.tmp" ] && ! grep -q 'Temporarily Offline\|<html' "$f.tmp"; then
      mv "$f.tmp" "$f"; echo "page $p: $(wc -l < "$f" | tr -d ' ') captures"; break; fi
    rm -f "$f.tmp"; echo "page $p try $try failed"; sleep $((30 * try))
  done
  sleep 4
done
