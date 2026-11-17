#!/usr/bin/env bash
# From a wayback_index.sh folder, one capture per distinct page whose URL key matches a regex: the earliest
# text/html capture. Output TSV (stdout): id, timestamp, original URL; id is the URL key's last path segment
# (lowercased by the CDX), made filename-safe. URLs with a query string are left out (KEEP_QUERY=1 keeps them):
# they are usually the same page reached another way (OPI: 5,008 "?Clear=0&...&TargetURL=" variants).
#   wayback_pick.sh <index_dir> '<urlkey regex>' > list.tsv
#   e.g. wayback_pick.sh tplacement_cdx 'tplacement/i0[0-9a-f]+$'   (OPI's posting pages: 10,210)
set -euo pipefail
cat "$1"/page_*.txt | awk -v re="$2" -v kq="${KEEP_QUERY:-0}" '$4 == "text/html" && $2 ~ re && (kq == 1 || index($2, "?") == 0)' | sort -k2,2 -k1,1 |
  awk '$2 != last { last = $2; n = split($2, s, "/"); id = s[n]; gsub(/[^A-Za-z0-9._-]/, "_", id);
                    print id "\t" $1 "\t" $3 }'
