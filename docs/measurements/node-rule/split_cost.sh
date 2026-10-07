#!/bin/bash
# What the spread costs the split (prereg.txt, "The split's cost with the spread"):
# the stand and its gradient on long drought, lumped (lib_sort) and spread
# (lib_D2), splits on and off, each twice, alternated, with nothing else running.
#   DEV=... bash split_cost.sh       # read with split_cost.R
set -u
: "${DEV:?}"
O=$DEV/node_rule/split_cost
H="$(cd "$(dirname "$0")/../../.." && pwd)"
mkdir -p "$O/runs" "$O/logs"
one() {  # name lib [VAR=value ...]
  local name=$1 lib=$2; shift 2
  [ -f "$O/runs/$name.rds" ] && return 0
  (cd "$H" && env PLANT_LIB=$DEV/$lib REGIME=long-drought TIMES=$DEV/window/t/t_u108.rds \
    TOL=3e-5 ATOL=1e-4 WEIGHT_SOIL=10 WEIGHT=$DEV/window/rule_A/weight_long-drought.rds \
    WEIGHT_MAX=100 HMAX=15 SHARE=0.1 STAND_ONLY=1 OUT="$O/runs/$name.rds" "$@" \
    Rscript harness/run_record.R > "$O/logs/$name.log" 2>&1)
  echo "done $name $? $(date +%T)" >> "$O/queue.out"
}
for k in 1 2; do
  one "split_lumped_$k" lib_sort SPLIT=1
  one "split_spread_$k" lib_D2 SPLIT=1
  one "plain_lumped_$k" lib_sort
  one "plain_spread_$k" lib_D2
done
echo "JOB DONE split_cost $(date +%T)" >> "$O/queue.out"
