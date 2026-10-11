#!/bin/bash
# tl.sh NAME [TRAIT_REL]: one forward constant-rain run on the scan schedule.
T=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/traits
name=$1; rel=$2
[ -n "$rel" ] && extra="TRAIT_REL=$rel" || extra=""
$T/../placed2/one.sh t_$name constant nr harness/run_record.R TIMES=$T/scan.rds FORWARD=1 $extra
