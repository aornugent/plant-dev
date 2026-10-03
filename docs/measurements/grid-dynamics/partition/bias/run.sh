#!/bin/bash
# One run at a time, niced. Usage: run.sh NAME SCRIPT [VAR=value ...]
#   SCRIPT is a stepper file under this directory (copied first, so editing it
#   while a run reads it is harmless), or "mono" for the driver at 2ad8059.
# Refuses to overwrite an existing log or OUT.
B=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/partition_bias
S=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/split
W=/home/user/plant-dev/.claude/worktrees/agent-a4e5afe75b72479f0
name=$1; kind=$2; shift 2
if [ -e "$B/logs/$name.log" ] || [ -e "$B/out/$name.rds" ]; then echo "exists: $name" >&2; exit 1; fi
mkdir -p "$B/runs"
case $kind in
  mono) file=$W/harness/ark_prototype.R ;;
  *) cp "$B/$kind" "$B/runs/$name.R"; file=$B/runs/$name.R ;;
esac
echo "=== $name start $(date -u +%T) load $(cut -d' ' -f1 /proc/loadavg) :: $kind $*" >> "$B/logs/runs.log"
env PLANT_LIB=$S/lib NODES=108 ATOL=1e-4 OUT=$B/out/$name.rds "$@" nice -n 10 Rscript "$file" > "$B/logs/$name.log" 2>&1
st=$?
echo "=== $name end $(date -u +%T) status $st" >> "$B/logs/runs.log"
