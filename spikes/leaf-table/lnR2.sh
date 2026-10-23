#!/bin/bash
# ln R' with the table in place of the solved P, for pool invader 2 on the
# closed stand (three grids) and the identity invader on the open stand (two
# grids). The live baselines are g_r2_0 and g_open_0 from scale2.sh.
T=/home/a/.claude/jobs/9d586e52/tmp/leaf
S=/home/a/dev/plant-dev/.claude/worktrees/agent-a9f1c333a8d4c65ef/spikes/leaf-table/run.R
H=/home/a/dev/plant-dev/.claude/worktrees/agent-a9f1c333a8d4c65ef/spikes/leaf-table
cd "$T"
export PHASE=invade
LMA_SHIFT=0 TRAIT_ROW=1 GRIDS=2,3 Rscript "$H/table.R" > tab_open.out 2>&1 &
for n in 13824 96000 524288; do
  INV_ROWS=2 KEY_INDEX=1 OUT=$T/t_r2_$n PLANT_LEAF_TABLE=$T/table_${n}_1_r2.bin \
    Rscript "$S" > t_r2_$n.log 2>&1 &
done
wait
for n in 96000 524288; do
  CASE=open INV_N=1 IDENT_EPS=1e-9 OUT=$T/t_open_$n \
    PLANT_LEAF_TABLE=$T/table_${n}_1_open_r1.bin Rscript "$S" > t_open_$n.log 2>&1 &
done
wait
echo ALLDONE
