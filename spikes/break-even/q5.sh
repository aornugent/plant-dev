#!/bin/bash
# Is the identity gain the schedule's? The resident and the identity invader
# on every introduction, with 8 and 16 more introductions packed into the
# first interval (0, 0.37).
S=/home/a/dev/plant-dev/.claude/worktrees/agent-a3c3295eb8ad97b06/spikes/break-even
cd /home/a/.claude/jobs/9d586e52/tmp/breakeven
ID="0,1e-6,-1e-6,1e-5,-1e-5"
EXTRA=8 EVERY=1 CASE=closed ROW=1 EPS=$ID TAG=closed_r1_extra8 Rscript "$S/scan.R" > scan_closed_r1_extra8.log 2>&1 &
EXTRA=16 EVERY=1 CASE=closed ROW=1 EPS=$ID TAG=closed_r1_extra16 Rscript "$S/scan.R" > scan_closed_r1_extra16.log 2>&1 &
EXTRA=16 EVERY=1 CASE=closed ROWS=2,29,31 EPS=0,1e-5,-1e-5 TAG=closed_pool_extra16 Rscript "$S/scan.R" > scan_closed_pool_extra16.log 2>&1 &
EXTRA=16 EVERY=1 CASE=open ROW=1 EPS=$ID TAG=open_r1_extra16 Rscript "$S/scan.R" > scan_open_r1_extra16.log 2>&1 &
wait
echo ALLDONE
