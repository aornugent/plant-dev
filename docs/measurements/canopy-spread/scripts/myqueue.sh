#!/bin/bash
# bash myqueue.sh JOBS_FILE: run each line of JOBS_FILE (arguments to run.sh) in the
# background, keeping at most MAX (2) of this directory's R jobs running, and
# launching only while the 1-minute load average is under LOADMAX (8).
COMB=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/comb
MAX=${MAX:-2}
LOADMAX=${LOADMAX:-8}
mine() {
  local n=0 p
  for p in $(pgrep -f -- '--file=harness/'); do
    [ "$(readlink /proc/$p/cwd 2>/dev/null)" = "$COMB/scripts" ] && n=$((n + 1))
  done
  echo $n
}
busy() { awk -v m="$LOADMAX" '{ exit !($1 >= m) }' /proc/loadavg; }
while IFS= read -r line; do
  [ -z "$line" ] && continue
  case "$line" in \#*) continue ;; esac
  while [ "$(mine)" -ge "$MAX" ] || busy; do sleep 20; done
  echo "$(date -u +%FT%TZ) launch $line"
  # shellcheck disable=SC2086
  bash "$COMB/scripts/run.sh" $line &
  sleep 30
done < "$1"
wait
echo "$(date -u +%FT%TZ) queue done"
