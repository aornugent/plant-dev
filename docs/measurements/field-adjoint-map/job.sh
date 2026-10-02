#!/bin/bash
# bash job.sh TAG MODE TIMES FINE OUT [ORDER] [OPEN]: one probe_run.R job, run
# from a snapshot of the script, logged to logs/TAG.log.
A=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/adjmap
tag=$1; shift
mkdir -p $A/snap/$tag $A/logs $A/out
cp $A/probe_run.R $A/snap/$tag/probe_run.R
cd $A
Rscript $A/snap/$tag/probe_run.R "$@" > $A/logs/$tag.log 2>&1
echo "exit $?" >> $A/logs/$tag.log
