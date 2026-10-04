#!/bin/bash
# The events reply's u-scan (prereg_uscan.txt): second differences of ln J in lma
# at r = +-3e-3, +-1e-2, +-3e-2 on the plain replay (rp), the split re-detected
# on each replay (sq) and the split on lma's frozen structure (fq), at 1e-4 and
# its +-5% nudges. Four lanes, each running its share of the jobs in turn.
#   bash uscan.sh            # launch the four lanes
#   bash uscan.sh lane K     # run lane K (0-3) in the foreground
#   bash uscan.sh ext        # the tol extension at 3e-5, after the lanes
E=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/events
source $E/run.sh
OFF="TF24_DOMAIN_TOL=1e9"
SPLIT="LOCAL=1 MEMBER=1 EVENT_ETA=1e-10 DENSE=quintic"
TH="THETA=lma THETA_ALONE=1"
jobs() {
  for r in 3e-3 -3e-3 3e-2 -3e-2; do
    echo "rp_lma_$r TOL=1e-4 PROGRAM=$R/g_1e-4.rds $OFF $TH THETA_REL=$r"
    echo "fq_lma_$r TOL=1e-4 PROGRAM=$R/g_1e-4.rds $OFF $SPLIT $TH THETA_REL=$r STRUCTURE=$R/slq_1e-4.rds"
  done
  for r in 1e-3 -1e-3 3e-3 -3e-3 1e-2 -1e-2 3e-2 -3e-2; do
    echo "sq_lma_$r TOL=1e-4 PROGRAM=$R/g_1e-4.rds $OFF $SPLIT $TH THETA_REL=$r"
  done
  for T in 9.5e-5 1.05e-4; do
    echo "rp_$T TOL=$T PROGRAM=$R/g_$T.rds $OFF"
    for r in 3e-3 -3e-3 1e-2 -1e-2 3e-2 -3e-2; do
      echo "rp_${T}_lma_$r TOL=$T PROGRAM=$R/g_$T.rds $OFF $TH THETA_REL=$r"
      echo "sq_${T}_lma_$r TOL=$T PROGRAM=$R/g_$T.rds $OFF $SPLIT $TH THETA_REL=$r"
    done
  done
}
ext_jobs() {
  # The bases at 1e-4 and 3e-5 again, on the current driver: the recorded
  # spq_1e-4 and spq_3e-5 ran on an earlier one, and rp_1e-4 and rp_3e-5 have
  # no snapshot.
  for T in 1e-4 3e-5; do
    echo "b_rp_$T TOL=$T PROGRAM=$R/g_$T.rds $OFF"
    echo "b_spq_$T TOL=$T PROGRAM=$R/g_$T.rds $OFF $SPLIT"
  done
  for r in 1e-2 -1e-2 3e-2 -3e-2; do
    echo "rp_3e-5_lma_$r TOL=3e-5 PROGRAM=$R/g_3e-5.rds $OFF $TH THETA_REL=$r"
    echo "sq_3e-5_lma_$r TOL=3e-5 PROGRAM=$R/g_3e-5.rds $OFF $SPLIT $TH THETA_REL=$r"
  done
}
if [ "$1" = ext ]; then
  while pgrep -f "uscan.sh lane" > /dev/null; do sleep 20; done
  for k in 0 1 2 3; do
    ext_jobs | awk -v k="$k" 'NR % 4 == k' | while read -r tag args; do
      run $tag $NEW $LIB $args
    done > $R/uscan_ext_$k.out 2>&1 &
  done
  wait
  exit 0
fi
if [ "$1" = lane ]; then
  jobs | awk -v k="$2" 'NR % 4 == k' | while read -r tag args; do
    run $tag $NEW $LIB $args
  done
  exit 0
fi
for k in 0 1 2 3; do
  nohup bash "$0" lane $k > $R/uscan_lane_$k.out 2>&1 &
done
echo "launched: $(jobs | wc -l) jobs in four lanes"
