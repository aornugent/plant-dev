#!/bin/bash
# Is the gain general? d ln R' / d ln P for pool invader 2 on the closed stand,
# and for the identity invader on the open (long-drought) stand.
T=/home/a/.claude/jobs/9d586e52/tmp/leaf
S=/home/a/dev/plant-dev/.claude/worktrees/agent-a9f1c333a8d4c65ef/spikes/leaf-table/run.R
cd "$T"
export PHASE=invade
INV_ROWS=2 KEY_INDEX=1 OUT=$T/g_r2_p PLANT_LEAF_PSCALE=1.0001 Rscript "$S" > g_r2_p.log 2>&1 &
INV_ROWS=2 KEY_INDEX=1 OUT=$T/g_r2_m PLANT_LEAF_PSCALE=0.9999 Rscript "$S" > g_r2_m.log 2>&1 &
CASE=open INV_N=1 IDENT_EPS=1e-9 OUT=$T/g_open_p PLANT_LEAF_PSCALE=1.0001 Rscript "$S" > g_open_p.log 2>&1 &
CASE=open INV_N=1 IDENT_EPS=1e-9 OUT=$T/g_open_m PLANT_LEAF_PSCALE=0.9999 Rscript "$S" > g_open_m.log 2>&1 &
wait
INV_ROWS=2 OUT=$T/g_r2_0 Rscript "$S" > g_r2_0.log 2>&1 &
CASE=open INV_N=1 IDENT_EPS=1e-9 OUT=$T/g_open_0 Rscript "$S" > g_open_0.log 2>&1 &
wait
echo ALLDONE
