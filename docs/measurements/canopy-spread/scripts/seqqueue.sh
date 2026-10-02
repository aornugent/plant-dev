#!/bin/bash
# bash seqqueue.sh JOBS_FILE: run each line of JOBS_FILE (arguments to run.sh) one
# at a time, at nice 10, skipping any whose OUT file already exists.
COMB=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/comb
while IFS= read -r line; do
  [ -z "$line" ] && continue
  case "$line" in \#*) continue ;; esac
  out=$(printf '%s\n' $line | sed -n 's/^OUT=//p')
  if [ -n "$out" ] && [ -f "$out" ]; then echo "$(date -u +%FT%TZ) skip (done) $out"; continue; fi
  echo "$(date -u +%FT%TZ) start $line"
  # shellcheck disable=SC2086
  nice -n 10 bash "$COMB/scripts/run.sh" $line < /dev/null
  echo "$(date -u +%FT%TZ) finished, exit $?"
done < "$1"
echo "$(date -u +%FT%TZ) queue done"
