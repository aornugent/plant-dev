#!/bin/bash
# lane.sh RECORD SETTING NAME...: run each named schedule in turn (placed2's one.sh).
E=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/edges
rec=$1; set=$2; shift 2
for k in "$@"; do $E/../placed2/one.sh e_${k}_$rec $rec $set harness/run_record.R TIMES=$E/$k.rds; done
