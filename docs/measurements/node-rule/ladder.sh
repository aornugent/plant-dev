#!/bin/bash
# Item 6's ladders (prereg.txt, "The ladders", 2026-10-07): the spread's uniform
# rungs on long-wet, dry and episodic and the constant record's front rungs, each
# with its introductions moved a quarter spacing at the two finest rungs.
#   DEV=... bash ladder.sh [lanes]       # read with ladder.R
set -u
: "${DEV:?}"
O=$DEV/node_rule/ladder
H="$(cd "$(dirname "$0")/../../.." && pwd)"
L=$DEV/lib_109
mkdir -p "$O/runs" "$O/logs"
# The constant record's moved grids: each introduction after the first a quarter
# of the way to the next, the last a quarter of the spacing before it.
for g in Gbf16 Gbf32; do
  [ -f "$O/t_const_${g}_q.rds" ] || Rscript -e "t <- readRDS('$DEV/window/t/t_const_$g.rds')
    d <- diff(t); t[-1] <- t[-1] + c(d[-1], d[length(d)]) / 4
    stopifnot(!is.unsorted(t, strictly = TRUE)); saveRDS(t, '$O/t_const_${g}_q.rds')"
done
one() {  # name record [VAR=value ...]
  local name=$1 rec=$2; shift 2
  [ -f "$O/runs/$name.rds" ] && grep -q "failures;" "$O/logs/$name.log" 2>/dev/null && return 0
  echo "start $name $(date +%T)" >> "$O/queue.out"
  (cd "$H" && env PLANT_LIB=$L REGIME=$rec TOL=3e-5 ATOL=1e-4 WEIGHT_SOIL=10 \
    WEIGHT=$DEV/window/rule_A/weight_$rec.rds WEIGHT_MAX=100 HMAX=15 SHARE=0.1 SPLIT=1 \
    OUT="$O/runs/$name.rds" "$@" Rscript harness/run_record.R > "$O/logs/$name.log" 2>&1)
  echo "done $name $? $(date +%T)" >> "$O/queue.out"
}
export -f one
export O H L DEV
# The longest first, so the lanes finish together.
{
  for rec in long-wet dry episodic; do
    echo "u429_$rec $rec NODES=429"
    echo "s429_$rec $rec NODES=429 SHIFT=0.25"
  done
  for rec in long-wet dry episodic; do
    echo "u215_$rec $rec NODES=215"
    echo "s215_$rec $rec NODES=215 SHIFT=0.25"
    echo "u108_$rec $rec NODES=108"
  done
  for g in Gbf32 Gbf16 Gbf8; do echo "c_$g constant TIMES=$DEV/window/t/t_const_$g.rds"; done
  for g in Gbf32 Gbf16; do echo "cs_$g constant TIMES=$O/t_const_${g}_q.rds"; done
} | xargs -P "${1:-3}" -L 1 bash -c 'one "$@"' _
echo "JOB DONE ladder $(date +%T)" >> "$O/queue.out"
