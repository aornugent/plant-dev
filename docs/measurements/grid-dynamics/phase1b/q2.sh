#!/bin/bash
# Stage 2 on the probe build (events/lib), after stage 1: at 1e-4 then 3e-5,
# DP's plain forward (against stage 1's run, bit for bit), the dense outputs'
# field error on every crossing step of the DP and CK grids (P1), DP's plain
# replay, the split replays on DP's contd5 and CK's quartic (J, structure,
# cost), and at 1e-4 DP's adaptive forward with the split (P3). The CK grids,
# replays, cubic and quintic splits are the spike's (dev/events/runs).
source /tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/phase1b/run.sh
E=$P/events
OFF="TF24_DOMAIN_TOL=1e9"
SPLIT="LOCAL=1 MEMBER=1 EVENT_ETA=1e-10"
CKG=$DEV/events/runs
until grep -q "q1 finished" $R/q1.out 2>/dev/null; do sleep 20; done
for T in 1e-4 3e-5; do
  run g_dp_$T $E $PROBE METHOD=dp TOL=$T OUT=$R/g_dp_$T.rds REF=$R/dp_$T.rds
  script dc_dp_$T $E dense_check2.R $PROBE METHOD=dp TOL=$T GRID=$R/g_dp_$T.rds OUT=$R/dc_dp_$T.rds
  script dc_ck_$T $E dense_check2.R $PROBE METHOD=ck TOL=$T GRID=$CKG/g_$T.rds OUT=$R/dc_ck_$T.rds
  run rp_dp_$T $E $PROBE METHOD=dp TOL=$T PROGRAM=$R/g_dp_$T.rds $OFF
  run sp_dp4_$T $E $PROBE METHOD=dp TOL=$T PROGRAM=$R/g_dp_$T.rds $OFF $SPLIT DENSE=dp4 SPLIT_LOG=$R/sl_dp4_$T.rds
  run sp_ck4_$T $E $PROBE METHOD=ck TOL=$T PROGRAM=$CKG/g_$T.rds $OFF $SPLIT DENSE=ck4 SPLIT_LOG=$R/sl_ck4_$T.rds
  if [ "$T" = 1e-4 ]; then
    run ga_dp4_$T $E $PROBE METHOD=dp TOL=$T $SPLIT DENSE=dp4 OUT=$R/ga_dp4_$T.rds
  fi
done
echo "q2 finished"
