#!/bin/bash
# The split's sweep and plain's in one process, alternating (prereg.txt,
# fifteenth extension). LIB holds the build (odelia 1e5a2d7, plant 91098156).
#   DEV=... LIB=lib OUT=run.rds bash inproc_timing.sh
set -u
cd "$(dirname "$0")/../../.."
env PLANT_LIB="$LIB" SPLIT_PROG=$DEV/sc/runs/program_split.rds \
  PLAIN_PROG=$DEV/sc/runs/program_plain.rds OUT="$OUT" \
  taskset -c 3 Rscript docs/measurements/sign-changes/inproc_timing.R
echo "JOB DONE inproc_timing $(date +%T)"
