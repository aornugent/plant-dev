#!/bin/bash
# The coordinator's pool question, ahead of the rest of q3b: once the CK
# quartic's d_I nudges are done, pause q3b, run CK and DP at 1e-4 through the
# driver with ATTEMPT_LOG and STAGE_LOG (each must reproduce its earlier run bit
# for bit), then resume q3b, which skips the runs it finished.
source /tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/phase1b/run.sh
H=$P/harness
until grep -q "fq_ck4_1.015e-4_d_I_-1e-3" $R/q3b.out 2>/dev/null; do sleep 10; done
pid=$(pgrep -f "phase1b/q3b.sh" | head -1)
if [ -n "$pid" ]; then
  pg=$(ps -o pgid= -p $pid | tr -d ' ')
  kill -- -$pg
  echo "paused q3b (process group $pg)"
fi
sleep 3
run sl_ck_1e-4 $H $V12T METHOD=ck TOL=1e-4 REF=$DEV/events/runs/v0_1e-4.rds ATTEMPT_LOG=$R/att_ck_1e-4.rds STAGE_LOG=$R/stg_ck_1e-4.rds
run sl_dp_1e-4 $H $V12T METHOD=dp TOL=1e-4 REF=$R/dp_1e-4.rds ATTEMPT_LOG=$R/att_dp_1e-4.rds STAGE_LOG=$R/stg_dp_1e-4.rds
cp $R/q3b.out $R/q3b_part1.out
bash $P/launch.sh q3b.sh
echo "q7 finished"
