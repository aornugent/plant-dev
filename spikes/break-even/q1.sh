#!/bin/bash
# Question 1: ln R'(eps) for the identity invader and pool row 2 on the closed
# stand and the identity invader on the open stand; the AD elasticity in the
# same direction on the closed stand.
S=/home/a/dev/plant-dev/.claude/worktrees/agent-a3c3295eb8ad97b06/spikes/break-even
cd /home/a/.claude/jobs/9d586e52/tmp/breakeven
CASE=closed ROW=1 TAG=closed_r1 Rscript "$S/scan.R" > scan_closed_r1.log 2>&1 &
CASE=closed ROW=2 TAG=closed_r2 Rscript "$S/scan.R" > scan_closed_r2.log 2>&1 &
CASE=open ROW=1 TAG=open_r1 Rscript "$S/scan.R" > scan_open_r1.log 2>&1 &
CASE=closed ROWS=1,2 TAG=closed Rscript "$S/ad.R" > ad_closed.log 2>&1 &
wait
echo ALLDONE
