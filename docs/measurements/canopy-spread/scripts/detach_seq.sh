#!/bin/bash
# bash detach_seq.sh JOBS_FILE LOG: seqqueue.sh on JOBS_FILE in its own session.
COMB=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/comb
setsid bash "$COMB/scripts/seqqueue.sh" "$1" < /dev/null > "$2" 2>&1 &
echo "sequential queue on $1 launched $(date -u +%FT%TZ)"
