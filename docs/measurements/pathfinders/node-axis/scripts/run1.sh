#!/bin/bash
# One node-axis run under the bounded setting from pf_nodes' harness copy.
#   run1.sh NAME RECORD SCHEDULE SPREAD [VAR=value ...]   (SPREAD 0 lumped, 8 spread)
D=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev
N=$D/pf_nodes
name=$1; rec=$2; sched=$3; spread=$4; shift 4
cd "$N" || exit 1
[ -f runs/$name.rds ] && grep -q "failures" logs/$name.log 2>/dev/null && { echo "skip $name" >> queue.out; exit 0; }
echo "start $name $(date +%T) load $(cut -d' ' -f1 /proc/loadavg)" >> queue.out
env PLANT_LIB=$N/lib REGIME=$rec TOL=3e-5 ATOL=1e-4 WEIGHT_SOIL=10 \
  WEIGHT=$D/window/rule_A/weight_$rec.rds WEIGHT_MAX=100 HMAX=15 \
  TIMES=$N/sched/$sched.rds PLANT_PROBE_SPREAD=$spread PLANT_PROBE_ORDER=2 \
  OUT=$N/runs/$name.rds "$@" nice -n 10 Rscript harness/run_record.R > logs/$name.log 2>&1
echo "done $name status $? $(date +%T)" >> queue.out
