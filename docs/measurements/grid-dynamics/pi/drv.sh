#!/bin/bash
# One driver run: drv.sh NAME [VAR=value ...]; the log goes to $P/logs/NAME.log.
# Runs from the worktree, under nice, with plant from lib_v12t.
W=/home/user/plant-dev/.claude/worktrees/agent-a905e7af8eecaffd3
D=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev
P=$D/pi
name=$1; shift
mkdir -p $P/logs $P/runs
cd $W || exit 1
echo "start $(date +%T) $name $*" >> $P/queue.out
env PLANT_LIB=$D/lib_v12t "$@" nice -n 10 Rscript harness/ark_prototype.R > $P/logs/$name.log 2>&1
status=$?
echo "done $(date +%T) $name status $status" >> $P/queue.out
exit $status
