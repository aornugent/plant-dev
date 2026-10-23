#!/bin/bash
# Native sampling with gperftools (perf is closed: perf_event_paranoid = 4),
# started from inside R around each phase. INV_N as for run.R.
T=/home/a/.claude/jobs/9d586e52/tmp/leaf
S=/home/a/dev/plant-dev/.claude/worktrees/agent-a9f1c333a8d4c65ef/spikes/leaf-table/run.R
cd "$T"
PHASE=invade OUT=$T/prof_run PROF=$T/prof PLANT_LEAF_STATS=$T/stats_prof \
  CPUPROFILE_FREQUENCY=200 Rscript "$S" > prof.log 2>&1
echo DONE
