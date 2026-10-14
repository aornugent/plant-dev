#!/bin/bash
# L1: a09's committed run on dry with one class of interval bisected, under GATE (AG or 19).
D=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev; S=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest; X=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/X_out; g=$1
[ "$g" = 19 ] && while pgrep -f "one.sh X_ins3nb_dry" >/dev/null; do sleep 20; done
for k in O C G S I F; do
  if [ "$g" = AG ]; then /home/user/plant-dev/docs/measurements/schedule-search/round4/AG/run.sh AG_a09b${k}_dry dry TIMES=$X/sched/a09b${k}_dry.rds TOL=1e-4
  else $S/adjmap/one.sh X_a09b${k}_dry dry TIMES=$X/sched/a09b${k}_dry.rds WEIGHT=$D/window/rule_A/weight_dry.rds TOL=1e-4 LIB=$S/adjmap/lib19 OUT=$X/runs/X_a09b${k}_dry.rds; fi
done
echo "lane cls $g done"
