#!/bin/bash
# regnans's own root-finders on the stand (prereg.txt, extension). LIB holds the
# build and nleqslv, BB and quadprog; REGNANS a regnans checkout at 56ad241.
#   LIB=lib REGNANS=dir B_STAR=b OUTD=dir bash run_solvers.sh
# then the stand at b* replayed on its own program, and the invader at its traits.
set -u
H="$(cd "$(dirname "$0")/../../.." && pwd)/harness"
mkdir -p "$OUTD"
for s in nleqslv dfsane; do
  env PLANT_LIB="$LIB" REGNANS_DIR="$REGNANS" SOLVER=$s SPLIT=1 TOL=1e-4 ATOL=1e-4 \
    NODES=108 MAX_RUNS=25 OUT="$OUTD/$s.rds" Rscript "$H/regnans_solvers.R" > "$OUTD/$s.log" 2>&1
done
env PLANT_LIB="$LIB" B_STAR="$B_STAR" SPLIT=1 TOL=1e-4 ATOL=1e-4 NODES=108 \
  OUT="$OUTD/replay.rds" Rscript "$H/equilibrium_replay.R" > "$OUTD/replay.log" 2>&1
env PLANT_LIB="$LIB" B="$B_STAR" TOL=1e-4 ATOL=1e-4 NODES=108 \
  OUT="$OUTD/walk.rds" Rscript "$H/walk_identity.R" > "$OUTD/walk.log" 2>&1
echo "JOB DONE solvers $(date +%T)"
