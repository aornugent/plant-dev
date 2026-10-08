#!/bin/bash
# The waterfall (prereg.txt here): each configuration in order, one run at a
# time with nothing else on the machine.   DEV=... bash waterfall.sh
set -u
: "${DEV:?}"
O=$DEV/waterfall
H="$(cd "$(dirname "$0")/../../.." && pwd)"
mkdir -p "$O/runs" "$O/logs"
for c in brute halved cut preset alone window; do
  [ -f "$O/runs/$c.rds" ] && continue
  (cd "$H" && env PLANT_LIB=$DEV/lib_110 CONFIG=$c OUT="$O/runs/$c.rds" \
    timeout 3600 Rscript docs/measurements/waterfall/waterfall.R > "$O/logs/$c.log" 2>&1)
  echo "done $c $? $(date +%T)" >> "$O/queue.out"
done
echo "JOB DONE waterfall $(date +%T)" >> "$O/queue.out"
