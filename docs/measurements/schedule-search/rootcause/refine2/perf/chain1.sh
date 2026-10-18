#!/bin/bash
# Part 1 A/B on one case, libS: fresh processes (S, then half pinned to it) against the loop's
# sequence in one process, interleaved, REPS times.   bash chain1.sh CASE REPS [MODEB]
D=/home/user/plant-dev/docs/measurements/schedule-search/rootcause/refine2/perf
O=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/refine2perf
export PLANT_LIB=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/adjmap/libS
C=$1; N=$2; B=${3:-loop}
for r in $(seq 1 $N); do
  Rscript $D/ab.R $C S $O/A_${C}_S_$r.rds >> $O/chain1_$C.log 2>&1
  Rscript $D/ab.R $C half $O/A_${C}_half_$r.rds $O/A_${C}_S_$r.rds.base >> $O/chain1_$C.log 2>&1
  Rscript $D/ab.R $C $B $O/B_${C}_${B}_$r.rds >> $O/chain1_$C.log 2>&1
done
echo done >> $O/chain1_$C.log
