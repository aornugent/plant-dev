#!/bin/bash
# The events spike's runs, one at a time and niced. A job whose log already
# reports J is skipped, so a queue can be re-run after an interruption. Each run
# executes a copy of the driver taken as it starts (runs/snap/TAG.R), from the
# root whose harness/ holds long_drought.R and ark436.R.
#   run TAG HARNESS_ROOT LIB VAR=VALUE ...
E=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/events
R=$E/runs
NEW=$E
ORIG=$E/v0
LIB=$E/lib
V12T=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/lib_v12t
COMMON="NODES=108 METHOD=ck ATOL=1e-4"
mkdir -p $R/snap
done_log() { grep -q " J [0-9]" "$R/$1.log" 2>/dev/null; }
run() {
  local tag=$1 root=$2 lib=$3; shift 3
  if done_log "$tag"; then echo "skip $tag"; return; fi
  local t0=$(date +%s)
  cp "$root/harness/ark_prototype.R" "$R/snap/$tag.R"
  ( cd "$root" && env PLANT_LIB="$lib" $COMMON "$@" nice Rscript "$R/snap/$tag.R" ) > "$R/$tag.log" 2>&1
  echo "done $tag in $(( $(date +%s) - t0 )) s: $(grep -h ' J [0-9]' "$R/$tag.log" | head -1 | cut -c1-110)"
}
