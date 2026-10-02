#!/bin/bash
# Build the probe plant (time-windowed spread) into lib2, a copy of lib_guard.
DEV=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev
COMB=$DEV/comb
log=$COMB/logs/build2.log
{
  echo "start $(date -u +%FT%TZ)"
  rm -f "$COMB"/plant/src/*.o "$COMB"/plant/src/*.so
  if [ ! -d "$COMB/lib2" ]; then cp -a "$DEV/lib_guard" "$COMB/lib2"; fi
  export R_LIBS=$COMB/lib2
  export MAKEFLAGS=-j${JOBS:-2}
  t0=$(date +%s)
  R CMD INSTALL --no-docs --library="$COMB/lib2" "$COMB/plant"
  rc=$?
  echo "exit $rc $(date -u +%FT%TZ) elapsed $(( $(date +%s) - t0 )) s"
} > "$log" 2>&1
