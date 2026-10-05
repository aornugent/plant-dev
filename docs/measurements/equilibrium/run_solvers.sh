#!/bin/bash
# regnans's own root-finders on the stand (prereg.txt, extension). LIB holds the
# build and nleqslv, BB and quadprog; REGNANS a regnans checkout at 56ad241.
#   LIB=lib REGNANS=dir OUTD=dir bash run_solvers.sh
set -u
H="$(cd "$(dirname "$0")/../../.." && pwd)/harness"
mkdir -p "$OUTD"
for s in nleqslv dfsane; do
  env PLANT_LIB="$LIB" REGNANS_DIR="$REGNANS" SOLVER=$s SPLIT=1 TOL=1e-4 ATOL=1e-4 \
    NODES=108 MAX_RUNS=25 OUT="$OUTD/$s.rds" Rscript "$H/regnans_solvers.R" > "$OUTD/$s.log" 2>&1
done
echo "JOB DONE solvers $(date +%T)"
