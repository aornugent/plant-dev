#!/bin/bash
# One driver run from pf_soil's harness copy, under nice, after the 1-minute load falls
# below 4. The bounded setting's options come first; later NAME=value arguments override.
#   drv.sh NAME RECORD [VAR=value ...]     (RECORD: long-drought | episodic)
D=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev
P=$D/pf_soil
name=$1; rec=$2; shift 2
cd "$P" || exit 1
while awk '{exit !($1 >= 4)}' /proc/loadavg; do sleep 30; done
echo "start $name $(date +%T) load $(cut -d' ' -f1 /proc/loadavg)" >> "$P/queue.out"
env PLANT_LIB=$D/lib_sw METHOD=ck TOL=3e-5 ATOL=1e-4 TOL_SOIL=10 \
  WEIGHT=$D/window/rule_A/weight_$rec.rds HMAX=15 WEIGHT_MAX=100 \
  TIMES=$D/window/t/t_u108.rds REGIME=$rec OUT=$P/runs/$name.rds "$@" \
  nice -n 10 Rscript harness/ark_prototype.R > "$P/logs/$name.log" 2>&1
status=$?
echo "done $name status $status $(date +%T)" >> "$P/queue.out"
exit $status
