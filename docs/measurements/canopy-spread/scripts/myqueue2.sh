#!/bin/bash
# bash myqueue2.sh JOBS_FILE: as myqueue.sh, but each job starts in its own session
# (setsid), so it outlives this runner. At most MAX (2) of this directory's R jobs
# run at once, and a job launches only while the 1-minute load average is under
# LOADMAX (8).
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
  setsid bash "$COMB/scripts/run.sh" $line < /dev/null > /dev/null 2>&1 &
  sleep 30
done < "$1"
echo "$(date -u +%FT%TZ) queue done"
