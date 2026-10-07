#!/bin/bash
# The sort's gates (prereg.txt): long drought's forward at 108 and 429 uniform
# introductions on the sorting build and on the one that walks.
#   DEV=... bash sort.sh identity   # S1, beside other jobs
#   DEV=... bash sort.sh timed      # S2, with nothing else on the machine
set -u
: "${DEV:?}"
O=$DEV/node_rule/sort
H="$(cd "$(dirname "$0")/../../.." && pwd)"
mkdir -p "$O"
one() {  # name, library, nodes
  [ -f "$O/$1.rds" ] && grep -q "failures;" "$O/$1.log" 2>/dev/null && return 0
  (cd "$H" && env PLANT_LIB=$2 REGIME=long-drought NODES=$3 TOL=3e-5 ATOL=1e-4 \
    WEIGHT_SOIL=10 WEIGHT=$DEV/window/rule_A/weight_long-drought.rds WEIGHT_MAX=100 \
    HMAX=15 FORWARD=1 OUT="$O/$1.rds" Rscript harness/run_record.R > "$O/$1.log" 2>&1)
}
case "${1:-}" in
  identity)
    one s108_sort $DEV/lib_sort 108
    one s108_walk $DEV/lib_105c 108
    ;;
  timed)
    for k in 1 2; do
      one s429_sort$k $DEV/lib_sort 429
      one s429_walk$k $DEV/lib_105c 429
    done
    ;;
esac
