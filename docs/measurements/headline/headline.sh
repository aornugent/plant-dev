#!/bin/bash
# The headline (prereg.txt here): each configuration on each record, one run at
# a time with nothing else on the machine.   DEV=... bash headline.sh
set -u
: "${DEV:?}"
O=$DEV/headline
H="$(cd "$(dirname "$0")/../../.." && pwd)"
mkdir -p "$O/runs" "$O/logs"
one() {  # config record lib [seconds allowed]
  local name=$1_$2
  [ -f "$O/runs/$name.rds" ] && return 0
  (cd "$H" && env PLANT_LIB=$DEV/$3 CONFIG=$1 REGIME=$2 OUT="$O/runs/$name.rds" \
    timeout "${4:-3600}" Rscript docs/measurements/headline/headline.R > "$O/logs/$name.log" 2>&1)
  echo "done $name $? $(date +%T)" >> "$O/queue.out"
}
for rec in long-drought episodic; do one develop $rec lib_develop 900; done
for rec in long-drought episodic; do one stack $rec lib_109; done
for rec in long-drought episodic; do one floor $rec lib_109; done
echo "JOB DONE headline $(date +%T)" >> "$O/queue.out"
