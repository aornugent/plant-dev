#!/bin/bash
F=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/front
tag=$1; rel=$2; extra=""; [ -n "$rel" ] && extra="TRAIT_REL=$rel"
for L in F F2 F4; do $F/../placed2/one.sh f_${tag}${L}_constant constant nr harness/run_record.R TIMES=$F/${tag}$L.rds $extra; done
