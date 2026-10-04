#!/bin/bash
# The positive part's width at 1e-5 (prereg.txt, seventh extension): plant on
# the tight build with storage_prod_eps 1e-5 for 1e-4 (eps01_plant.patch), and
# one replay of the split's program at lma, as split_lma_0 at 1e-4 and 1e-3.
#   DEV=... SC=... bash eps01.sh
set -u
H="$(cd "$(dirname "$0")/../../.." && pwd)/harness"
T=$DEV/tight
R_LIBS=$T/lib_eps5 MAKEFLAGS=-j3 R CMD INSTALL --no-docs --library="$T/lib_eps5" "$T/plant_eps5" \
  > "$T/install_plant_eps5.log" 2>&1 || { echo "BUILD FAILED"; tail -20 "$T/install_plant_eps5.log"; exit 1; }
env PLANT_LIB="$T/lib_eps5" FORWARD=1 ATOL=1e-4 NODES=108 TOL=1e-4 PROGRAM="$SC/runs/program_split.rds" \
  SPLIT=1 LMA_REL=0 OUT="$T/runs_eps5/split_lma_0.rds" Rscript "$H/run_record.R" > "$T/runs_eps5/split_lma_0.log" 2>&1
echo "JOB DONE eps01 $(date +%T)"
