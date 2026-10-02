#!/bin/bash
# bash run.sh SCRIPT.R LOG KEY=VALUE ...
# Exports each KEY=VALUE, then runs the frozen copy of SCRIPT.R from the frozen
# harness directory (so its source("harness/...") resolves there), logging to LOG.
COMB=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/comb
script="$1"; log="$2"; shift 2
for kv in "$@"; do export "$kv"; done
export R_LIBS="${PLANT_LIB}"
cd "$COMB/scripts" || exit 1
{
  echo "start $(date -u +%FT%TZ) $script $*"
  t0=$(date +%s)
  Rscript "harness/$script" 2>&1
  rc=$?
  echo "exit $rc $(date -u +%FT%TZ) elapsed $(( $(date +%s) - t0 )) s"
} > "$log" 2>&1
