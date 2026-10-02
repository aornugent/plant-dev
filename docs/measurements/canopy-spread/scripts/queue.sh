#!/bin/bash
# bash queue.sh JOBS_FILE: run each line of JOBS_FILE (arguments to run.sh) in the
# background, keeping at most MAX harness Rscripts running in total.
COMB=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/comb
MAX=${MAX:-4}
while IFS= read -r line; do
  [ -z "$line" ] && continue
  case "$line" in \#*) continue ;; esac
  while [ "$(pgrep -c -f -- '--file=harness/')" -ge "$MAX" ]; do sleep 10; done
  echo "$(date -u +%FT%TZ) launch $line"
  # shellcheck disable=SC2086
  bash "$COMB/scripts/run.sh" $line &
  sleep 5
done < "$1"
wait
echo "$(date -u +%FT%TZ) queue done"
