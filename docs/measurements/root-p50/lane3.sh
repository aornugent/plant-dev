#!/bin/bash
S=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest
for g in "$@"; do for s in 0.02 -0.02; do $S/placed2/one.sh rp_${g}_${s}_dry dry nr harness/run_record.R TIMES=$S/rp50/${g}_dry.rds FORWARD=1 TRAIT_REL=root_P50=$s; done; done
