#!/bin/bash
# The soil-alone spikes (prereg.txt): the driver's multirate step (mrw) with sa_harness.diff,
# three runs at a time, each skipped once its record exists.
#   DEV=... bash run.sh
# $DEV/soil_alone/harness is the mrw copy of harness/ark_prototype.R (the workspace harness,
# pathfinders/soil-control/harness.diff, q3/mr_harness.diff, q3/mrw_harness.diff) with
# sa_harness.diff.
set -u
: "${DEV:?}"
S=$DEV/soil_alone
one() {  # name, record, tolerance, then settings
  local name=$1 rec=$2 tol=$3; shift 3
  [ -f "$S/runs/$name.rds" ] && return 0
  local times=$DEV/window/t/t_u108.rds
  [ "$rec" = constant ] && times=$DEV/window/t/t_const_Gbf16.rds
  (cd "$S" && env PLANT_LIB=$DEV/lib_sw METHOD=ck TOL=$tol ATOL=1e-4 TOL_SOIL=10 \
    WEIGHT=$DEV/window/rule_A/weight_$rec.rds HMAX=15 WEIGHT_MAX=100 TIMES=$times \
    REGIME=$rec OUT=$S/runs/$name.rds "$@" nice -n 10 Rscript harness/ark_prototype.R \
    > $S/logs/$name.log 2>&1)
  echo "done $name status $? $(date +%T)" >> $S/queue.out
}
export -f one; export S DEV
MRW="MR_SHARE=0.1 MR_COUPLE=member"
{
  for rec in long-drought episodic; do
    echo "s1_$rec $rec 3e-5 $MRW MR_SLOPE=0"
    echo "s2_$rec $rec 3e-5 $MRW MR_U1=stage"
    echo "s12_$rec $rec 3e-5 $MRW MR_SLOPE=0 MR_U1=stage"
  done
  echo "s12_long-drought_1e-4 long-drought 1e-4 $MRW MR_SLOPE=0 MR_U1=stage"
  echo "s12_long-drought_1e-5 long-drought 1e-5 $MRW MR_SLOPE=0 MR_U1=stage"
  echo "bnd_constant constant 3e-5"
  echo "mrw_constant constant 3e-5 $MRW"
  echo "s12_constant constant 3e-5 $MRW MR_SLOPE=0 MR_U1=stage"
  echo "arkc_constant constant 3e-5 METHOD=ark SOIL_EST=chain"
} | xargs -P 3 -L 1 bash -c 'one "$@"' _
echo "JOB DONE soil_alone $(date +%T)" >> $S/queue.out
