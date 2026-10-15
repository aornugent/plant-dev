#!/bin/bash
# S3: the sharp-gate pair with the stop only on steps longer than 0.5 d.
D=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev; S=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest; O=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/JT_out
while ! grep -q "done JT9_a09c_1.05e-4_stop" $S/adjmap/queue.out; do sleep 10; done
for t in 3e-4 2.85e-4; do
  $S/adjmap/one.sh JT10_ins_${t}_h05 dry TIMES=$S/P_out/sched/ins3c_dry.rds WEIGHT=$D/window/rule_A/weight_dry.rds TOL=$t LIB=$S/libJTstop JT_STOP=1 JT_STOP_LOG=1 JT_STOP_HMIN=0.00136986 OUT=$O/JT10_ins_${t}_h05.rds
done
