#!/bin/bash
# combo.sh RECORD TAG [TRAIT_REL]: forward base, edge ladder L0..L2.
M=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/matrix
P2=$M/../placed2; rec=$1; tag=$2; rel=$3
extra=""; [ -n "$rel" ] && extra="TRAIT_REL=$rel"
$P2/one.sh m_${tag}_f_$rec $rec nr harness/run_record.R NODES=54 FORWARD=1 $extra
cd $M && Rscript ../edges/mk2.R $P2/runs/m_${tag}_f_$rec.rds u54 ${tag}_$rec >> $M/mk.log 2>&1
for L in "" 2 4; do $P2/one.sh m_${tag}${L}_$rec $rec nr harness/run_record.R TIMES=$M/${tag}_$rec$L.rds $extra; done
