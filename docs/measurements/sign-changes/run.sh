#!/bin/bash
# Step 2's gates (prereg.txt). PLANT_LIB is the sign-changes build; R holds the
# runs. Lanes run three at a time; the cost pair runs alone.
#   PLANT_LIB=... R=... bash run.sh ladder|cost|replays|diff
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
  diff)  # PLANT_LIB is the probe build (odelia sign-changes-diff)
    one diff_1e-4 TOL=1e-4 SPLIT=1
    Rscript -e "o <- readRDS('$R/diff_1e-4.rds'); saveRDS(list(st = data.frame(time = o\$stand\$times[-1], h = o\$stand\$sizes[-1])), '$R/program_diff.rds')"
    for r in 1e-3 -1e-3 1e-2 -1e-2 3e-2 -3e-2; do
      echo "diff_lma_$r TOL=1e-4 PROGRAM=$R/program_diff.rds LMA_REL=$r SPLIT=1"
    done | xargs -P 3 -L 1 bash -c 'one "$@"' _
    ;;
  *) echo "usage: run.sh ladder|cost|replays|diff"; exit 1 ;;
esac
