#!/bin/bash
# The split's costs timed again on one core (prereg.txt, fourteenth extension).
# LIB holds the build (odelia 1e5a2d7, plant 91098156), PREV PLANT-103's before
# it (odelia 373f5b9, plant 4f45b702).
#   DEV=... LIB=lib PREV=lib OUTD=dir bash reads_timing.sh
set -u
H="$(cd "$(dirname "$0")/../../.." && pwd)/harness"
SPLIT_PROG=$DEV/sc/runs/program_split.rds
PLAIN_PROG=$DEV/sc/runs/program_plain.rds
one() {  # library, output path, program, SPLIT, FORWARD
  [ -f "$2.rds" ] && return 0
  env PLANT_LIB="$1" PROGRAM="$3" SPLIT="$4" LMA_REL=0 FORWARD="$5" \
    STAND_ONLY=1 ATOL=1e-4 NODES=108 TOL=1e-4 OUT="$2.rds" \
    taskset -c 3 Rscript "$H/run_record.R" > "$2.log" 2>&1
}
mkdir -p "$OUTD"
# Alone, alternating, each on the same core: the forward against PREV's and
# plain's, two each; then the sweep against plain's, six each.
for i in 1 2; do
  one "$LIB" "$OUTD/fwd_f$i" "$SPLIT_PROG" 1 1
  one "$PREV" "$OUTD/fwdprev_f$i" "$SPLIT_PROG" 1 1
  one "$LIB" "$OUTD/fwdplain_f$i" "$PLAIN_PROG" 0 1
done
for i in 1 2 3 4 5 6; do
  one "$LIB" "$OUTD/grad_s$i" "$SPLIT_PROG" 1 0
  one "$LIB" "$OUTD/plain_s$i" "$PLAIN_PROG" 0 0
done
echo "JOB DONE reads_timing $(date +%T)"
