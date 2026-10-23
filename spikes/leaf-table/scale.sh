#!/bin/bash
# d ln R' / d ln P for the identity invader: its solved P scaled by 1 +- 1e-4
# and 1 +- 1e-5, to check the response is linear at the table's error size.
T=/home/a/.claude/jobs/9d586e52/tmp/leaf
S=/home/a/dev/plant-dev/.claude/worktrees/agent-a9f1c333a8d4c65ef/spikes/leaf-table/run.R
cd "$T"
export PHASE=invade INV_N=1 IDENT_EPS=1e-9
for s in 1.0001 0.9999 1.00001 0.99999; do
  OUT=$T/lnr_scale_$s PLANT_LEAF_PSCALE=$s Rscript "$S" > lnr_scale_$s.log 2>&1 &
done
wait
echo ALLDONE
