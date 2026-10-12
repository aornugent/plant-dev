#!/bin/bash
# Stand and invader (resident traits) with gradients on each hybrid schedule H and its
# central coarsening C, through run_record.R at the references' setting.
S=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest
for job in "$@"; do IFS=: read tag rec g <<< "$job"; set="nr"; extra=""
  [ $rec = long-drought ] && set="pf"; [ $tag = dylma ] && extra="TRAIT_REL=lma=0.25"
  $S/placed2/one.sh inv_${g}_${tag}_${rec} $rec $set harness/run_record.R TIMES=$S/hier/hybl_${tag}_${rec}_p0_$g.rds $extra
done
