#!/bin/bash
# The seventeenth extension's runs (prereg.txt), alone and alternating. NEW
# holds the rebuilt split (odelia ODELIA-54, plant PLANT-103).
#   DEV=... NEW=lib OUTD=dir bash rebuild.sh
set -u
H="$(cd "$(dirname "$0")/../../.." && pwd)/harness"
M="$(cd "$(dirname "$0")" && pwd)"
SPLIT_PROG=$DEV/sc/runs/program_split.rds
PLAIN_PROG=$DEV/sc/runs/program_plain.rds
one() {  # output path, program, SPLIT, what run_record.R runs
  [ -f "$1.rds" ] && return 0
  case "$4" in
    forward) what="FORWARD=1" ;;
    stand) what="STAND_ONLY=1" ;;
    walk) what="STAND_GRADIENT=0" ;;
  esac
  env PLANT_LIB="$NEW" PROGRAM="$2" SPLIT="$3" LMA_REL=0 "$what" ATOL=1e-4 \
    NODES=108 TOL=1e-4 OUT="$1.rds" Rscript "$H/run_record.R" > "$1.log" 2>&1
}
mkdir -p "$OUTD"
for i in 1 2 3; do
  one "$OUTD/grad_t$i" "$SPLIT_PROG" 1 stand
  one "$OUTD/plain_t$i" "$PLAIN_PROG" 0 stand
done
for i in 1 2; do
  one "$OUTD/fwd_t$i" "$SPLIT_PROG" 1 forward
  one "$OUTD/fwdplain_t$i" "$PLAIN_PROG" 0 forward
done
one "$OUTD/walk_split" "$SPLIT_PROG" 1 walk
one "$OUTD/walk_plain" "$PLAIN_PROG" 0 walk
[ -f "$OUTD/walk_three.rds" ] ||
  env PLANT_LIB="$NEW" PROGRAM="$SPLIT_PROG" OUT="$OUTD/walk_three.rds" \
    Rscript "$M/walk_three.R" > "$OUTD/walk_three.log" 2>&1
echo "JOB DONE rebuild $(date +%T)"
