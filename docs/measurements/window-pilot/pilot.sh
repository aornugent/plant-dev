#!/bin/bash
# Item 7's gates (prereg.txt here, 2026-10-07): each record's pilot read into the
# window's weights by plant's control_window(), then the gate runs on them.
#   DEV=... bash pilot.sh [lanes]       # read with pilot7.R
set -u
: "${DEV:?}"
O=$DEV/window_pilot
H="$(cd "$(dirname "$0")/../../.." && pwd)"
L=$DEV/lib_106
mkdir -p "$O/runs" "$O/logs"
pilot() {  # record [VAR=value ...]
  local rec=$1; shift
  [ -f "$O/w_$rec.rds" ] && return 0
  (cd "$H" && env PLANT_LIB=$L REGIME=$rec TOL=1e-3 OUT="$O/w_$rec.rds" "$@" \
    Rscript harness/pilot_window.R > "$O/logs/pilot_$rec.log" 2>&1)
  echo "done pilot_$rec $? $(date +%T)" >> "$O/queue.out"
}
one() {  # name record [VAR=value ...]
  local name=$1 rec=$2; shift 2
  [ -f "$O/runs/$name.rds" ] && grep -q "failures;" "$O/logs/$name.log" 2>/dev/null && return 0
  echo "start $name $(date +%T)" >> "$O/queue.out"
  (cd "$H" && env PLANT_LIB=$L REGIME=$rec NODES=108 TOL=3e-5 ATOL=1e-4 WEIGHT_SOIL=10 \
    WEIGHT="$O/w_$rec.rds" WEIGHT_MAX=100 HMAX=15 SHARE=0.1 SPLIT=1 \
    OUT="$O/runs/$name.rds" "$@" Rscript harness/run_record.R > "$O/logs/$name.log" 2>&1)
  echo "done $name $? $(date +%T)" >> "$O/queue.out"
}
export -f pilot one
export O H L DEV
records="long-wet long-drought dry episodic constant"
for rec in $records; do
  if [ "$rec" = constant ]; then echo "$rec TIMES=$DEV/window/t/graded/t_const_Gb.rds"; else echo "$rec NODES=54"; fi
done | xargs -P "${1:-3}" -L 1 bash -c 'pilot "$@"' _
for rec in $records; do
  echo "p7_$rec $rec INVADERS=lma=0.5,lma=2,hmat=0.5,hmat=2 INVADER_GRADIENTS=1"
  echo "p7n_$rec $rec TOL=3.15e-5"
done | xargs -P "${1:-3}" -L 1 bash -c 'one "$@"' _
echo "JOB DONE pilot $(date +%T)" >> "$O/queue.out"
