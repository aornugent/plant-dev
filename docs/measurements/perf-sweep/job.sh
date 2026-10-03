#!/bin/bash
# One job, nice'd, its log and exit status recorded:
#   bash job.sh <tag> <lib> <spread|-> <script> [VAR=value ...]
# Runs Rscript <script> with PLANT_LIB=<lib> (and PLANT_PROBE_SPREAD=<spread>
# unless it is "-"), writing logs/<tag>.log.
SPD=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/sweep_profile
tag=$1; lib=$2; spread=$3; script=$4; shift 4
log=$SPD/logs/$tag.log
cd $SPD
{
  echo "start $(date -u +%FT%TZ) $tag lib=$lib spread=$spread script=$script $*"
  echo "load $(cat /proc/loadavg)"
  if [ "$spread" = "-" ]; then
    env PLANT_LIB=$lib OUT=$SPD/out/$tag.rds "$@" nice -n 10 Rscript $SPD/$script
  else
    env PLANT_LIB=$lib PLANT_PROBE_SPREAD=$spread OUT=$SPD/out/$tag.rds "$@" nice -n 10 Rscript $SPD/$script
  fi
  rc=$?
  echo "load $(cat /proc/loadavg)"
  echo "exit $rc $(date -u +%FT%TZ)"
} > $log 2>&1
