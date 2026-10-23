#!/bin/bash
# Four processes, at most 4 cores: resident-only and resident + 4 invaders
# timed with the leaf-solve counters; resident + 2 pool invaders with a sampled
# log of leaf calls; resident + 2 invaders under perf (flat, self time).
T=/home/a/.claude/jobs/9d586e52/tmp/leaf
S=/home/a/dev/plant-dev/.claude/worktrees/agent-a9f1c333a8d4c65ef/spikes/leaf-table/run.R
cd "$T"
PHASE=resident OUT=$T/resident PLANT_LEAF_STATS=$T/stats_resident Rscript "$S" > resident.log 2>&1 &
PHASE=invade INV_N=4 OUT=$T/invade4 PLANT_LEAF_STATS=$T/stats_invade4 Rscript "$S" > invade4.log 2>&1 &
PHASE=invade INV_ROWS=1,2,3 OUT=$T/logged PLANT_LEAF_STATS=$T/stats_logged \
  PLANT_LEAF_LOG=$T/leaflog PLANT_LEAF_LOG_EVERY=${EVERY:-10} Rscript "$S" > logged.log 2>&1 &
PHASE=invade INV_N=2 OUT=$T/perf2 PLANT_LEAF_STATS=$T/stats_perf2 \
  perf record -F 250 -o "$T/perf2.data" -- Rscript "$S" > perf2.log 2>&1 &
wait
echo ALLDONE
