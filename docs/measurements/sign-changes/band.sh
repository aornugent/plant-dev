#!/bin/bash
# The splits reply's two cheap checks (prereg.txt, sixth extension). First the
# tightened leaf solve's cost, timed alone: plain's replay at lma, alternating
# the split build and the tight build, two each. Then the smoothing band:
# plant on the tight build with the positive part's width 1e-3 for 1e-4
# (eps10_plant.patch), and the split's program replayed at r = 0, +-1e-3,
# +-1e-2 and on the fine grid, r = k/32 1e-3, k = 2, 4, ..., 32.
#   DEV=... SC=... bash band.sh
set -u
H="$(cd "$(dirname "$0")/../../.." && pwd)/harness"
T=$DEV/tight
one() {  # library, output path, program, split, LMA_REL
  [ -f "$2.rds" ] && return 0
  env PLANT_LIB="$1" FORWARD=1 ATOL=1e-4 NODES=108 TOL=1e-4 PROGRAM="$3" SPLIT="$4" \
    LMA_REL="$5" OUT="$2.rds" Rscript "$H/run_record.R" > "$2.log" 2>&1
}
export -f one; export H
mkdir -p "$T/timing" "$T/runs_eps"
for i in 1 2; do
  one "$DEV/lib_sc" "$T/timing/default_$i" "$SC/runs/program_plain.rds" 0 0
  one "$T/lib" "$T/timing/tight_$i" "$SC/runs/program_plain.rds" 0 0
done
echo "=== timed $(date +%T)"
R_LIBS=$T/lib_eps MAKEFLAGS=-j3 R CMD INSTALL --no-docs --library="$T/lib_eps" "$T/plant_eps" \
  > "$T/install_plant_eps.log" 2>&1 || { echo "BUILD FAILED"; tail -20 "$T/install_plant_eps.log"; exit 1; }
echo "=== built $(date +%T)"
{
  for r in 0 1e-3 -1e-3 1e-2 -1e-2; do
    echo "$T/lib_eps $T/runs_eps/split_lma_$r $SC/runs/program_split.rds 1 $r"
  done
  for k in $(seq 2 2 32); do
    echo "$T/lib_eps $T/runs_eps/fine_split_k$k $SC/runs/program_split.rds 1 $(python3 -c "print(repr($k * 1e-3 / 32))")"
  done
} | xargs -P 4 -L 1 bash -c 'one "$@"' _
echo "JOB DONE band $(date +%T)"
