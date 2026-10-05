#!/bin/bash
# The sweep through split steps (prereg.txt, twelfth extension). LIB holds the
# sweep build, BASE the build without the sweep's record (PLANT-102), PROBE the
# sweep build with sweep_frozen.patch, whose PROBE_FROZEN=1 holds each cut.
#   DEV=... LIB=lib BASE=lib PROBE=lib OUTD=dir bash sweep_gates.sh
set -u
H="$(cd "$(dirname "$0")/../../.." && pwd)/harness"
SPLIT_PROG=$DEV/sc/runs/program_split.rds
PLAIN_PROG=$DEV/sc/runs/program_plain.rds
one() {  # library, output path, program, SPLIT, LMA_REL, FORWARD, PROBE_FROZEN
  [ -f "$2.rds" ] && return 0
  env PLANT_LIB="$1" PROGRAM="$3" SPLIT="$4" LMA_REL="$5" FORWARD="$6" PROBE_FROZEN="$7" \
    STAND_ONLY=1 ATOL=1e-4 NODES=108 TOL=1e-4 OUT="$2.rds" \
    Rscript "$H/run_record.R" > "$2.log" 2>&1
}
export -f one; export H
mkdir -p "$OUTD"
# Alone, alternating: the forward against PLANT-102's, then the sweep against
# plain's, two each.
for i in 1 2; do
  one "$LIB" "$OUTD/fwd_t$i" "$SPLIT_PROG" 1 0 1 0
  one "$BASE" "$OUTD/fwd102_t$i" "$SPLIT_PROG" 1 0 1 0
done
for i in 1 2; do
  one "$LIB" "$OUTD/grad_t$i" "$SPLIT_PROG" 1 0 0 0
  one "$LIB" "$OUTD/plain_t$i" "$PLAIN_PROG" 0 0 0 0
done
echo "=== timed $(date +%T)"
{
  echo "$LIB $OUTD/grad_r3 $SPLIT_PROG 1 0.001 0 0"
  echo "$PROBE $OUTD/frozen $SPLIT_PROG 1 0 0 1"
  for r in 1e-6 -1e-6 0.001001 0.000999; do
    echo "$LIB $OUTD/cd_$r $SPLIT_PROG 1 $r 1 0"
  done
} | xargs -P 3 -L 1 bash -c 'one "$@"' _
echo "JOB DONE sweep_gates $(date +%T)"
