#!/bin/bash
# Phase 1b's runs, one at a time and niced. A job whose log already reports J is
# skipped, so a queue can be re-run after an interruption. Each run executes a
# snapshot of its harness directory (snap/TAG/harness), taken as it starts.
#   source run.sh; run TAG HARNESS_DIR LIB VAR=VALUE ...
P=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/phase1b
DEV=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev
R=$P/runs
V12T=$DEV/lib_v12t
PROBE=$DEV/events/lib
COMMON="NODES=108 ATOL=1e-4"
done_log() { grep -q " J [0-9]" "$R/$1.log" 2>/dev/null; }
run() {
  local tag=$1 hdir=$2 lib=$3; shift 3
  if done_log "$tag"; then echo "skip $tag"; return; fi
  local s=$P/snap/$tag
  rm -rf "$s"; mkdir -p "$s/harness"
  cp "$hdir"/*.R "$s/harness/"
  local t0=$(date +%s)
  ( cd "$s" && env PLANT_LIB="$lib" $COMMON "$@" nice -n 10 Rscript harness/ark_prototype.R ) > "$R/$tag.log" 2>&1
  echo "done $tag in $(( $(date +%s) - t0 )) s: $(grep -h ' J [0-9]' "$R/$tag.log" | head -1 | cut -c1-120)"
}
# A script other than the driver, from a snapshot of its directory: script TAG DIR FILE LIB VAR=VALUE ...
script() {
  local tag=$1 dir=$2 file=$3 lib=$4; shift 4
  if [ -s "$R/$tag.done" ]; then echo "skip $tag"; return; fi
  local s=$P/snap/$tag
  rm -rf "$s"; mkdir -p "$s/harness"
  cp "$dir"/*.R "$s/harness/"
  local t0=$(date +%s)
  ( cd "$s" && env PLANT_LIB="$lib" $COMMON "$@" nice -n 10 Rscript "harness/$file" ) > "$R/$tag.log" 2>&1
  echo $? > "$R/$tag.done"
  echo "done $tag in $(( $(date +%s) - t0 )) s (status $(cat $R/$tag.done))"
}
