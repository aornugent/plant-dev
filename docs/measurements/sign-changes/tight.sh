#!/bin/bash
# The noise's source (prereg.txt, fourth extension). Builds plant against a
# phylloptim whose root-finds and searches stop at adjacent floats, then replays
# the plain program at lma (1 + k 1e-12), k = -3..3, on it, and at k = +-2, +-3
# on the split build, whose k = 0 and +-1 exist (run.sh floor). The split
# build's replays run on the fourth core while the tight build compiles.
#   DEV=... SC=... bash tight.sh
# DEV/tight holds copies of phylloptim (378b083) and plant (abcfcc22) with
# tight_phylloptim.patch and tight_plant.patch applied, and lib/ with odelia as
# lib_sc has it.
set -u
H="$(cd "$(dirname "$0")/../../.." && pwd)/harness"
T=$DEV/tight
PROG=$SC/runs/program_plain.rds
one() {  # library, output directory, LMA_REL
  [ -f "$2/plain_lma_$3.rds" ] && return 0
  env PLANT_LIB="$1" FORWARD=1 ATOL=1e-4 NODES=108 TOL=1e-4 PROGRAM="$PROG" LMA_REL="$3" \
    OUT="$2/plain_lma_$3.rds" Rscript "$H/run_record.R" > "$2/plain_lma_$3.log" 2>&1
}
export -f one; export H PROG
( for r in 2e-12 -2e-12 3e-12 -3e-12; do one "$DEV/lib_sc" "$SC/runs" $r; done ) &
export R_LIBS=$T/lib MAKEFLAGS=-j3
for pkg in phylloptim plant; do
  echo "=== $pkg $(date +%T)"
  R CMD INSTALL --no-docs --library="$T/lib" "$T/$pkg" > "$T/install_$pkg.log" 2>&1 ||
    { echo "BUILD FAILED $pkg"; tail -20 "$T/install_$pkg.log"; wait; exit 1; }
done
echo "=== built $(date +%T)"
mkdir -p "$T/runs"
printf '%s\n' 0 1e-12 -1e-12 2e-12 -2e-12 3e-12 -3e-12 |
  xargs -P 3 -I{} bash -c 'one "$0" "$1" {}' "$T/lib" "$T/runs"
wait
echo "JOB DONE tight $(date +%T)"
