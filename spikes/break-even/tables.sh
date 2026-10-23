#!/bin/bash
# Writes the result tables in results/ from the runs in the temporary folder.
S=/home/a/dev/plant-dev/.claude/worktrees/agent-a3c3295eb8ad97b06/spikes/break-even
T=/home/a/.claude/jobs/9d586e52/tmp/breakeven
cd /tmp
Rscript "$S/gains.R" > "$S/results/gains.txt" 2>&1
for n in closed_r1 closed_r1_every1 closed_r1_extra16 closed_r2 open_r1; do
  Rscript "$S/cohorts.R" "scan_$n.rds" 1e-6 > "$S/results/cohorts_$n.txt" 2>&1
done
Rscript "$S/traj_summary.R" closed 1 > "$S/results/traj_closed_cohort1.txt" 2>&1
Rscript "$S/traj_summary.R" open 1 > "$S/results/traj_open_cohort1.txt" 2>&1
cp "$T/ad_closed.log" "$S/results/ad_closed.txt"
cp "$T/fdpars_closed.log" "$S/results/fdpars_closed.txt"
Rscript -e 'x <- readRDS("/home/a/.claude/jobs/9d586e52/tmp/breakeven/light_closed.rds")$res_top; print(x[x$time %in% unique(x$time)[c(3,6,9,12,15,18,21,24,30,45,70,100)], ], digits = 4)' > "$S/results/resident_top_closed.txt"
