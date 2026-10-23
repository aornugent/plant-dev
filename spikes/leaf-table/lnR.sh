#!/bin/bash
# ln R' of the identity invader (the resident's traits, vcmax_25 moved by 1e-9)
# with its P from the live leaf, from each table, and scaled by 1 + 1e-3.
T=/home/a/.claude/jobs/9d586e52/tmp/leaf
S=/home/a/dev/plant-dev/.claude/worktrees/agent-a9f1c333a8d4c65ef/spikes/leaf-table/run.R
cd "$T"
export PHASE=invade INV_N=1 IDENT_EPS=1e-9
OUT=$T/lnr_live Rscript "$S" > lnr_live.log 2>&1 &
OUT=$T/lnr_t13824 PLANT_LEAF_TABLE=$T/table_13824_1_r1.bin Rscript "$S" > lnr_t13824.log 2>&1 &
OUT=$T/lnr_t96000 PLANT_LEAF_TABLE=$T/table_96000_1_r1.bin Rscript "$S" > lnr_t96000.log 2>&1 &
OUT=$T/lnr_t524288 PLANT_LEAF_TABLE=$T/table_524288_1_r1.bin Rscript "$S" > lnr_t524288.log 2>&1 &
wait
OUT=$T/lnr_scale PLANT_LEAF_PSCALE=1.001 Rscript "$S" > lnr_scale.log 2>&1 &
OUT=$T/lnr_scale_m PLANT_LEAF_PSCALE=0.999 Rscript "$S" > lnr_scale_m.log 2>&1 &
wait
echo ALLDONE
