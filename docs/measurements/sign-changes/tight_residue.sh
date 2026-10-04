#!/bin/bash
# The residue on the tight build (prereg.txt, fifth extension). Replays the
# split's and plain's programs at lma (1 + r), r = +-1e-3, +-3e-3, +-1e-2,
# +-3e-2, and the split's at r = k/32 1e-3, k = 0, 2, ..., 32, on the tight
# build (tight.sh), and plain and the split at +-3e-3 on the split build, whose
# other points exist (run.sh replays).
#   DEV=... SC=... bash tight_residue.sh
set -u
H="$(cd "$(dirname "$0")/../../.." && pwd)/harness"
T=$DEV/tight
one() {  # library, output path, program, split, LMA_REL
  [ -f "$2.rds" ] && return 0
  env PLANT_LIB="$1" FORWARD=1 ATOL=1e-4 NODES=108 TOL=1e-4 PROGRAM="$3" SPLIT="$4" \
    LMA_REL="$5" OUT="$2.rds" Rscript "$H/run_record.R" > "$2.log" 2>&1
}
export -f one; export H
{
  for r in 0 1e-3 -1e-3 3e-3 -3e-3 1e-2 -1e-2 3e-2 -3e-2; do
    echo "$T/lib $T/runs/split_lma_$r $SC/runs/program_split.rds 1 $r"
  done
  for r in 1e-3 -1e-3 3e-3 -3e-3 1e-2 -1e-2 3e-2 -3e-2; do
    echo "$T/lib $T/runs/plain_lma_$r $SC/runs/program_plain.rds 0 $r"
  done
  for k in $(seq 2 2 32); do
    echo "$T/lib $T/runs/fine_split_k$k $SC/runs/program_split.rds 1 $(python3 -c "print(repr($k * 1e-3 / 32))")"
  done
  for r in 3e-3 -3e-3; do
    echo "$DEV/lib_sc $SC/runs/rs_lma_$r $SC/runs/program_split.rds 1 $r"
    echo "$DEV/lib_sc $SC/runs/rp_lma_$r $SC/runs/program_plain.rds 0 $r"
  done
} | xargs -P 4 -L 1 bash -c 'one "$@"' _
echo "JOB DONE tight_residue $(date +%T)"
