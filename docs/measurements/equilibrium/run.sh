#!/bin/bash
# The stand at its demographic equilibrium (prereg.txt). LIB holds the build.
#   LIB=lib OUTD=dir bash run.sh
set -u
H="$(cd "$(dirname "$0")/../../.." && pwd)/harness"
mkdir -p "$OUTD"
env PLANT_LIB="$LIB" SPLIT=1 TOL=1e-4 ATOL=1e-4 NODES=108 FIXED_MAX=8 BATCH_SWEEP=1 \
  OUT="$OUTD/eq.rds" Rscript "$H/equilibrium.R" > "$OUTD/eq.log" 2>&1
echo "JOB DONE equilibrium $(date +%T)"
