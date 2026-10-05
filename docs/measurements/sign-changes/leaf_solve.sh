#!/bin/bash
# The leaf solve stopped at adjacent floats, as built (prereg.txt, eighth
# extension). Replays the plain program at lma (1 + k 1e-12), k = -3..3, on a
# library holding phylloptim PHYLLOPTIM-17 and plant PLANT-100 (odelia from
# lib_sc), then times plain's replay alone, alternating that library and the
# split build's, two each.
#   DEV=... SC=... NEW=library bash leaf_solve.sh
set -u
H="$(cd "$(dirname "$0")/../../.." && pwd)/harness"
PROG=$SC/runs/program_plain.rds
OUTD=${OUTD:-$DEV/p21/runs}
one() {  # library, output path, LMA_REL
  [ -f "$2.rds" ] && return 0
  env PLANT_LIB="$1" FORWARD=1 ATOL=1e-4 NODES=108 TOL=1e-4 PROGRAM="$PROG" LMA_REL="$3" \
    OUT="$2.rds" Rscript "$H/run_record.R" > "$2.log" 2>&1
}
export -f one; export H PROG
mkdir -p "$OUTD"
printf '%s\n' 0 1e-12 -1e-12 2e-12 -2e-12 3e-12 -3e-12 |
  xargs -P 3 -I{} bash -c 'one "$0" "$1/plain_lma_{}" {}' "$NEW" "$OUTD"
echo "=== replays done $(date +%T)"
for i in 1 2; do
  one "$DEV/lib_sc" "$OUTD/time_split_$i" 0
  one "$NEW" "$OUTD/time_new_$i" 0
done
echo "JOB DONE leaf_solve $(date +%T)"
