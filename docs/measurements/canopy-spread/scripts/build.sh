#!/bin/bash
# Build the probe plant into its own library, a copy of lib_guard.
DEV=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev
COMB=$DEV/comb
log=$COMB/logs/build.log
{
  echo "start $(date -u +%FT%TZ)"
  if [ ! -d "$COMB/lib" ]; then cp -a "$DEV/lib_guard" "$COMB/lib"; fi
  export R_LIBS=$COMB/lib
  export MAKEFLAGS=-j${JOBS:-4}
  t0=$(date +%s)
  R CMD INSTALL --no-docs --library="$COMB/lib" "$COMB/plant"
  rc=$?
  echo "exit $rc $(date -u +%FT%TZ) elapsed $(( $(date +%s) - t0 )) s"
} > "$log" 2>&1
