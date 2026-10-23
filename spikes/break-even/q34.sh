#!/bin/bash
# Questions 3 and 4. Batch A: the gain for ten pool rows on each stand (near
# and far from ln R' = 0 on the closed stand), and the identity invader's gain
# with the gate narrowed and with the tolerance halved. Batch B: the gate
# widened, the tolerance doubled, storage_prod_eps x10, and the light profile.
S=/home/a/dev/plant-dev/.claude/worktrees/agent-a3c3295eb8ad97b06/spikes/break-even
cd /home/a/.claude/jobs/9d586e52/tmp/breakeven
POOL=11,43,29,38,31,5,9,13,24,14
ID="0,1e-6,-1e-6,1e-5,-1e-5"
if [ "$1" = A ]; then
CASE=closed ROWS=$POOL EPS=0,1e-5,-1e-5 TAG=closed_pool Rscript "$S/scan.R" > scan_closed_pool.log 2>&1 &
CASE=open ROWS=$POOL EPS=0,1e-5,-1e-5 TAG=open_pool Rscript "$S/scan.R" > scan_open_pool.log 2>&1 &
PLANT_GATE_WIDTH=0.05 CASE=closed ROW=1 EPS=$ID TAG=closed_r1_gate005 Rscript "$S/scan.R" > scan_closed_r1_gate005.log 2>&1 &
TOL=5e-5 CASE=closed ROW=1 EPS=$ID TAG=closed_r1_tol5e-5 Rscript "$S/scan.R" > scan_closed_r1_tol5e-5.log 2>&1 &
fi
if [ "$1" = B ]; then
PLANT_GATE_WIDTH=0.2 CASE=closed ROW=1 EPS=$ID TAG=closed_r1_gate02 Rscript "$S/scan.R" > scan_closed_r1_gate02.log 2>&1 &
TOL=2e-4 CASE=closed ROW=1 EPS=$ID TAG=closed_r1_tol2e-4 Rscript "$S/scan.R" > scan_closed_r1_tol2e-4.log 2>&1 &
PLANT_STORAGE_EPS=1e-3 CASE=closed ROW=1 EPS=$ID TAG=closed_r1_seps1e-3 Rscript "$S/scan.R" > scan_closed_r1_seps1e-3.log 2>&1 &
CASE=closed TAG=closed Rscript "$S/light.R" > light_closed.log 2>&1 &
fi
wait
echo ALLDONE
