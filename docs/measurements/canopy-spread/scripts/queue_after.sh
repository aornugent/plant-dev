#!/bin/bash
# bash queue_after.sh AFTER_LOG N JOBS_FILE OUT_LOG: wait until AFTER_LOG has at
# least N lines (another queue has launched its jobs), then run queue.sh on JOBS_FILE.
COMB=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/comb
after="$1"; n="$2"; jobs="$3"; out="$4"
until [ -f "$after" ] && [ "$(wc -l < "$after")" -ge "$n" ]; do sleep 10; done
bash "$COMB/scripts/queue.sh" "$jobs" > "$out" 2>&1
