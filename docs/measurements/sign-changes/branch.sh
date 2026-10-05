#!/bin/bash
# One branch per side (prereg.txt, eleventh extension). SMOOTH holds the final
# build, BRANCH the probe (branch_odelia.patch, branch_plant.patch over it).
#   DEV=... SMOOTH=lib BRANCH=lib OUTD=dir bash branch.sh
set -u
H="$(cd "$(dirname "$0")/../../.." && pwd)/harness"
PROG=$DEV/sc/runs/program_split.rds
one() {  # library, output path, LMA_REL
  [ -f "$2.rds" ] && return 0
  env PLANT_LIB="$1" FORWARD=1 ATOL=1e-4 NODES=108 TOL=1e-4 PROGRAM="$PROG" SPLIT=1 \
    LMA_REL="$3" OUT="$2.rds" Rscript "$H/run_record.R" > "$2.log" 2>&1
}
export -f one; export H PROG
mkdir -p "$OUTD"
# Alone, alternating: each arm's replay at r = 0, two each.
for i in 1 2; do
  one "$SMOOTH" "$OUTD/smooth_t$i" 0
  one "$BRANCH" "$OUTD/branch_t$i" 0
done
echo "=== timed $(date +%T)"
{
  for arm in smooth branch; do
    lib=$SMOOTH; [ $arm = branch ] && lib=$BRANCH
    for r in 1e-3 -1e-3 1e-2 -1e-2; do echo "$lib $OUTD/${arm}_$r $r"; done
    for k in $(seq 2 2 32); do
      echo "$lib $OUTD/${arm}_k$k $(python3 -c "print(repr($k * 1e-3 / 32))")"
    done
  done
} | xargs -P 3 -L 1 bash -c 'one "$@"' _
echo "JOB DONE branch $(date +%T)"
