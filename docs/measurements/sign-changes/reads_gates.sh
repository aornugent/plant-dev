#!/bin/bash
# A part reads the rest of the patch at five fractions of the step (prereg.txt,
# thirteenth extension). LIB holds the build, PREV the build it changes (odelia
# ODELIA-54 373f5b9, plant PLANT-103 4f45b702).
#   DEV=... LIB=lib PREV=lib OUTD=dir bash reads_gates.sh
set -u
H="$(cd "$(dirname "$0")/../../.." && pwd)/harness"
SPLIT_PROG=$DEV/sc/runs/program_split.rds
PLAIN_PROG=$DEV/sc/runs/program_plain.rds
one() {  # library, output path, program, SPLIT, LMA_REL, FORWARD, [TOL]
  [ -f "$2.rds" ] && return 0
  env PLANT_LIB="$1" PROGRAM="$3" SPLIT="$4" LMA_REL="$5" FORWARD="$6" \
    STAND_ONLY=1 ATOL=1e-4 NODES=108 TOL="${7:-1e-4}" OUT="$2.rds" \
    Rscript "$H/run_record.R" > "$2.log" 2>&1
}
export -f one; export H
mkdir -p "$OUTD"
# Alone, alternating: the forward against the previous build's and plain's, two
# each; then the sweep against plain's, three each.
for i in 1 2; do
  one "$LIB" "$OUTD/fwd_t$i" "$SPLIT_PROG" 1 0 1
  one "$PREV" "$OUTD/fwdprev_t$i" "$SPLIT_PROG" 1 0 1
  one "$LIB" "$OUTD/fwdplain_t$i" "$PLAIN_PROG" 0 0 1
done
for i in 1 2 3; do
  one "$LIB" "$OUTD/grad_t$i" "$SPLIT_PROG" 1 0 0
  one "$LIB" "$OUTD/plain_t$i" "$PLAIN_PROG" 0 0 0
done
echo "=== timed $(date +%T)"
{
  echo "$LIB $OUTD/grad_r3 $SPLIT_PROG 1 0.001 0"
  for r in 1e-6 -1e-6 0.001001 0.000999; do
    echo "$LIB $OUTD/cd_$r $SPLIT_PROG 1 $r 1"
  done
  for t in 1e-3 3e-4; do
    echo "$LIB $OUTD/adapt_$t '' 1 0 1 $t"
    echo "$PREV $OUTD/adaptprev_$t '' 1 0 1 $t"
  done
} | xargs -P 3 -L 1 bash -c 'one "$@"' _
echo "JOB DONE reads_gates $(date +%T)"
