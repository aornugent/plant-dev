#!/bin/bash
# bash detach.sh SCRIPT.R LOG KEY=VALUE ...: run.sh in its own session, returning at once.
COMB=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/comb
setsid bash "$COMB/scripts/run.sh" "$@" < /dev/null > /dev/null 2>&1 &
echo "launched $1 $(date -u +%FT%TZ)"
