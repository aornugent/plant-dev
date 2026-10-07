#!/bin/bash
# Why episodic's ladder misses the square law (prereg.txt, the ladders'
# results): the stand's forward on each uniform rung, lumped (lib_sort) beside
# the spread's ladder runs, at the ladders' setting.
#   DEV=... bash episodic.sh       # read with episodic.R
set -u
: "${DEV:?}"
O=$DEV/node_rule/episodic
H="$(cd "$(dirname "$0")/../../.." && pwd)"
mkdir -p "$O/runs" "$O/logs"
one() {  # name lib record [VAR=value ...]
  local name=$1 lib=$2 rec=$3; shift 3
  [ -f "$O/runs/$name.rds" ] && grep -q "failures;" "$O/logs/$name.log" 2>/dev/null && return 0
  (cd "$H" && env PLANT_LIB=$DEV/$lib REGIME=$rec TOL=3e-5 ATOL=1e-4 WEIGHT_SOIL=10 \
    WEIGHT=$DEV/window/rule_A/weight_$rec.rds WEIGHT_MAX=100 HMAX=15 SHARE=0.1 SPLIT=1 \
    FORWARD=1 OUT="$O/runs/$name.rds" "$@" Rscript harness/run_record.R > "$O/logs/$name.log" 2>&1)
  echo "done $name $? $(date +%T)" >> "$O/queue.out"
}
export -f one
export O H DEV
{
  for n in 429 215 108; do echo "lumped_u${n}_episodic lib_sort episodic NODES=$n"; done
  # One rung finer on both builds: whether the moves start to fall.
  echo "lumped_u857_episodic lib_sort episodic NODES=857"
  echo "spread_u857_episodic lib_109 episodic NODES=857"
} | xargs -P "${1:-2}" -L 1 bash -c 'one "$@"' _
echo "JOB DONE episodic $(date +%T)" >> "$O/queue.out"
