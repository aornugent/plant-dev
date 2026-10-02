#!/bin/bash
# One run outside the queue, with the queue's own tags and settings, so the
# queue skips it when it gets there (run() skips a log that reports J).
#   exr.sh g T | exr.sh spq T | exr.sh fq T trait r | exr.sh rp T trait r
E=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/events
source $E/run.sh
OFF="TF24_DOMAIN_TOL=1e9"
SPLIT="LOCAL=1 MEMBER=1 EVENT_ETA=1e-10 DENSE=quintic"
case $1 in
  g) run g_$2 $NEW $LIB TOL=$2 OUT=$R/g_$2.rds ;;
  spq) run spq_$2 $NEW $LIB TOL=$2 PROGRAM=$R/g_$2.rds $OFF $SPLIT SPLIT_LOG=$R/slq_$2.rds ;;
  fq) run fq_$2_$3_$4 $NEW $LIB TOL=$2 PROGRAM=$R/g_$2.rds $OFF $SPLIT THETA=$3 THETA_ALONE=1 THETA_REL=$4 STRUCTURE=$R/slq_$2.rds ;;
  rp) run rp_$2_$3_$4 $NEW $LIB TOL=$2 PROGRAM=$R/g_$2.rds $OFF THETA=$3 THETA_ALONE=1 THETA_REL=$4 ;;
esac
