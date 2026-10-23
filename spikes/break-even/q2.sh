#!/bin/bash
# Question 2: cohort trajectories for the identity invader at P x (1, 1 +- 1e-4)
# and pool row 2, on the closed and the open stand.
S=/home/a/dev/plant-dev/.claude/worktrees/agent-a3c3295eb8ad97b06/spikes/break-even
cd /home/a/.claude/jobs/9d586e52/tmp/breakeven
CASE=closed TAG=closed Rscript "$S/traj.R" > traj_closed.log 2>&1 &
CASE=open TAG=open Rscript "$S/traj.R" > traj_open.log 2>&1 &
wait
echo ALLDONE
