#!/bin/bash
# The cut's native timings, both builds, two repetitions each.
SPD=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/sweep_profile
DEV=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev
bash $SPD/job.sh cut5_guard $DEV/lib_guard - sp_time.R T=5 REPS=2
bash $SPD/job.sh cut5_spread $DEV/comb/lib3 8 sp_time.R T=5 REPS=2
echo "QCUT DONE $(date -u +%FT%TZ)" > $SPD/logs/q_cut.done
