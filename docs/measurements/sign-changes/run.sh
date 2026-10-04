#!/bin/bash
# Step 2's gates (prereg.txt). PLANT_LIB is the sign-changes build; R holds the
# runs. Lanes run three at a time; the cost pair runs alone.
#   PLANT_LIB=... R=... [ARM=split|diff] bash run.sh ladder|cost|cost-loose|replays|diff|scan|fix|fix-base|
#     floor|floor-diff|fine
set -u
H="$(cd "$(dirname "$0")/../../.." && pwd)/harness"
: "${PLANT_LIB:?}" "${R:?}"
mkdir -p "$R"
one() {  # tag, then environment assignments
  local tag=$1; shift
  [ -f "$R/$tag.rds" ] && return 0
  env PLANT_LIB="$PLANT_LIB" FORWARD=1 ATOL=1e-4 NODES=108 "$@" OUT="$R/$tag.rds" \
    Rscript "$H/run_record.R" > "$R/$tag.log" 2>&1
}
export -f one; export H PLANT_LIB R
case "${1:-}" in
  ladder)
    {
      for tol in 1e-3 3e-4 1e-4 3e-5 1e-5; do
        echo "plain_$tol TOL=$tol"; echo "split_$tol TOL=$tol SPLIT=1"
      done
      echo "split_1e-6 TOL=1e-6 SPLIT=1"; echo "split_1e-7 TOL=1e-7 SPLIT=1"
      echo "plain_1e-7 TOL=1e-7"
    } | xargs -P 3 -L 1 bash -c 'one "$@"' _
    ;;
  cost)
    for k in 1 2; do
      one "cost_plain_$k" TOL=1e-4; one "cost_split_$k" TOL=1e-4 SPLIT=1
      one "cost_plain_1e-5_$k" TOL=1e-5
    done
    ;;
  replays)
    for arm in plain split; do
      Rscript -e "o <- readRDS('$R/${arm}_1e-4.rds'); saveRDS(list(st = data.frame(time = o\$stand\$times[-1], h = o\$stand\$sizes[-1])), '$R/program_$arm.rds')"
    done
    {
      for r in 1e-3 -1e-3 1e-2 -1e-2 3e-2 -3e-2; do
        echo "rp_lma_$r TOL=1e-4 PROGRAM=$R/program_plain.rds LMA_REL=$r"
        echo "rs_lma_$r TOL=1e-4 PROGRAM=$R/program_split.rds LMA_REL=$r SPLIT=1"
      done
      echo "rs_lma_0 TOL=1e-4 PROGRAM=$R/program_split.rds SPLIT=1"
    } | xargs -P 3 -L 1 bash -c 'one "$@"' _
    ;;
  cost-loose)  # the loaded ladder's slowdown at 1e-3 and 3e-4, timed alone
    for k in 1 2; do
      for tol in 1e-3 3e-4; do
        one "cost_plain_${tol}_$k" TOL=$tol; one "cost_split_${tol}_$k" TOL=$tol SPLIT=1
      done
    done
    ;;
  diff)  # PLANT_LIB is the probe build (odelia sign-changes-diff)
    one diff_1e-4 TOL=1e-4 SPLIT=1
    Rscript -e "o <- readRDS('$R/diff_1e-4.rds'); saveRDS(list(st = data.frame(time = o\$stand\$times[-1], h = o\$stand\$sizes[-1])), '$R/program_diff.rds')"
    for r in 1e-3 -1e-3 1e-2 -1e-2 3e-2 -3e-2; do
      echo "diff_lma_$r TOL=1e-4 PROGRAM=$R/program_diff.rds LMA_REL=$r SPLIT=1"
    done | xargs -P 3 -L 1 bash -c 'one "$@"' _
    ;;
  scan)  # PLANT_LIB is the log build (odelia sign-changes-log, prereg.txt's third extension)
    for r in 0 1e-3 -1e-3; do
      echo "scan_$r TOL=1e-4 PROGRAM=$R/program_split.rds LMA_REL=$r SPLIT=1 ODELIA_SPLIT_LOG=$R/scan_$r.txt ODELIA_SPLIT_SCAN=1"
    done | xargs -P 3 -L 1 bash -c 'one "$@"' _
    ;;
  fix)  # PLANT_LIB is the fix probe (odelia sign-changes-scan)
    one fix_1e-4 TOL=1e-4 SPLIT=1
    Rscript -e "o <- readRDS('$R/fix_1e-4.rds'); saveRDS(list(st = data.frame(time = o\$stand\$times[-1], h = o\$stand\$sizes[-1])), '$R/program_fix.rds')"
    for r in 1e-3 -1e-3 1e-2 -1e-2 3e-2 -3e-2; do
      echo "fix_lma_$r TOL=1e-4 PROGRAM=$R/program_fix.rds LMA_REL=$r SPLIT=1"
    done | xargs -P 3 -L 1 bash -c 'one "$@"' _
    ;;
  fix-base)  # the fix probe's replay at r = 0, the base its second differences need
    one fix_lma_0 TOL=1e-4 PROGRAM=$R/program_fix.rds SPLIT=1
    ;;
  floor)  # PLANT_LIB is the sign-changes build: a change of 1e-12 in lma, plain and split,
          # and 1e-300, which leaves lma as it is and takes LMA_REL's path
    {
      for r in 0 1e-12 -1e-12; do echo "plain_lma_$r TOL=1e-4 PROGRAM=$R/program_plain.rds LMA_REL=$r"; done
      for r in 1e-12 -1e-12 1e-300; do echo "rs_lma_$r TOL=1e-4 PROGRAM=$R/program_split.rds LMA_REL=$r SPLIT=1"; done
    } | xargs -P 3 -L 1 bash -c 'one "$@"' _
    ;;
  floor-diff)  # PLANT_LIB is the probe build: its replay at r = 0, and the same changes
    for r in 0 1e-12 -1e-12 1e-300; do
      echo "diff_lma_$r TOL=1e-4 PROGRAM=$R/program_diff.rds LMA_REL=$r SPLIT=1"
    done | xargs -P 3 -L 1 bash -c 'one "$@"' _
    ;;
  fine)  # ARM=split (sign-changes build) or ARM=diff (probe build): ln J at r = k/32 1e-3
    for k in $(seq 0 2 32); do
      r=$(python3 -c "print(repr($k*1e-3/32))")
      echo "fine_${ARM}_k$k TOL=1e-4 PROGRAM=$R/program_$ARM.rds LMA_REL=$r SPLIT=1"
    done | xargs -P 3 -L 1 bash -c 'one "$@"' _
    ;;
  *) echo "usage: run.sh ladder|cost|cost-loose|replays|diff|scan|fix|fix-base|floor|floor-diff|fine"; exit 1 ;;
esac
