#!/bin/bash
# One run at a time, niced. Usage: run.sh NAME script [VAR=value ...]
#   script is "split" (split_stepper.R) or "mono" (harness/ark_prototype.R).
# The script is copied first, so editing it while a run reads it is harmless.
S=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/split
W=/home/user/plant-dev/.claude/worktrees/agent-a4e5afe75b72479f0
name=$1; kind=$2; shift 2
mkdir -p $S/runs
case $kind in
  split) cp $S/split_stepper.R $S/runs/$name.R; file=$S/runs/$name.R ;;
  mono) file=$W/harness/ark_prototype.R ;;
esac
cd $W
echo "=== $name start $(date -u +%T) load $(cut -d' ' -f1 /proc/loadavg)" >> $S/logs/runs.log
env PLANT_LIB=$S/lib NODES=108 ATOL=1e-4 OUT=$S/out/$name.rds "$@" nice -n 10 Rscript $file > $S/logs/$name.log 2>&1
echo "=== $name end $(date -u +%T) status $?" >> $S/logs/runs.log
