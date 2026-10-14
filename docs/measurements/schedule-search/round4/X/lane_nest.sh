#!/bin/bash
# N1-N6 on dry: nested checks under both gates, one run at a time.
D=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev; X=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/X_out; AG=/home/user/plant-dev/docs/measurements/schedule-search/round4/AG/run.sh
W="WEIGHT=$D/window/rule_A/weight_dry.rds"
$AG AG_a09nb_dry dry TIMES=$X/sched/a09nb_dry.rds TOL=1e-4
$D/schedtest/adjmap/one.sh X_ins3nb_dry dry TIMES=$X/sched/insnb_dry.rds $W TOL=3e-4 LIB=$D/schedtest/adjmap/lib19 OUT=$X/runs/X_ins3nb_dry.rds
$AG AG_insnb_dry dry TIMES=$X/sched/insnb_dry.rds TOL=1e-4
$D/schedtest/adjmap/one.sh X_insnb_dry dry TIMES=$X/sched/insnb_dry.rds $W TOL=1e-4 LIB=$D/schedtest/adjmap/lib19 OUT=$X/runs/X_insnb_dry.rds
$D/schedtest/adjmap/one.sh X_a09nb3_dry dry TIMES=$X/sched/a09nb_dry.rds $W TOL=3e-4 LIB=$D/schedtest/adjmap/lib19 OUT=$X/runs/X_a09nb3_dry.rds
$D/schedtest/adjmap/one.sh X_a09nb_dry dry TIMES=$X/sched/a09nb_dry.rds $W TOL=1e-4 LIB=$D/schedtest/adjmap/lib19 OUT=$X/runs/X_a09nb_dry.rds
echo "lane nest done"
