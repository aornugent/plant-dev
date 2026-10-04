#!/bin/bash
# Bisect in r (LMA_REL) for where one logged split changes: node p's splits in
# the steps starting at TA and TB (4 decimals; TA = TB tracks one step). Replays
# the split's program on the log build (log_probe.patch) three interior points a
# round, in parallel, and ends when the bracket is under 2e-9 wide. Prints J at
# the bracket's ends and the smooth change at d ln J/dr = -8.3 beside it.
#   LIB=... PROG=program_split.rds P=0 TA=7.3288 TB=7.3339 LO=-1e-3 HI=0 W=dir \
#     bash bisect.sh
set -u
cd "$(dirname "$0")/../../.."
run() {
  local r=$1
  if [ ! -f "$W/r_$r.rds" ]; then
    env PLANT_LIB=$LIB FORWARD=1 ATOL=1e-4 NODES=108 TOL=1e-4 SPLIT=1 PROGRAM=$PROG LMA_REL=$r \
      ODELIA_SPLIT_LOG=$W/log_$r.txt OUT=$W/r_$r.rds Rscript harness/run_record.R > $W/out_$r.txt 2>&1
  fi
}
# A: split at TA alone; B: at TB alone; ?11 both, ? neither.
state() {
  awk -v p=$P -v ta=$TA -v tb=$TB '$1=="split" && $4==p { t=sprintf("%.4f",$2); if (t==ta) a=1; if (t==tb) b=1 }
    END { if (a && !b) print "A"; else if (b && !a) print "B"; else print "?" a b }' $W/log_$1.txt
}
export -f run; export LIB PROG W
mkdir -p $W
lo=$LO; hi=$HI
run $lo & run $hi & wait
sl=$(state $lo); sh=$(state $hi); echo "start: $lo $sl, $hi $sh"
for round in $(seq 1 14); do
  pts=$(python3 -c "lo,hi=$lo,$hi; print(' '.join(repr(lo+(hi-lo)*k/4) for k in (1,2,3)))")
  for x in $pts; do run $x & done; wait
  prev=$lo; ps=$sl; nlo=""; nhi=""
  for x in $pts $hi; do
    s=$( [ "$x" = "$hi" ] && echo $sh || state $x )
    if [ "$s" != "$ps" ] && [ -z "$nlo" ]; then nlo=$prev; nhi=$x; nsl=$ps; nsh=$s; fi
    prev=$x; ps=$s
  done
  lo=$nlo; hi=$nhi; sl=$nsl; sh=$nsh
  echo "round $round: [$lo, $hi] $sl -> $sh  width $(python3 -c "print('%.3g' % ($hi - $lo))")"
  python3 -c "import sys; sys.exit(0 if ($hi - $lo) < 2e-9 else 1)" && break
done
Rscript -e "a <- readRDS('$W/r_$lo.rds')\$stand\$J; b <- readRDS('$W/r_$hi.rds')\$stand\$J; cat(sprintf('bracket [%s, %s]: J %.15f -> %.15f, ln J change %+.3e; smooth change at d ln J/dr = -8.3: %+.3e\n', '$lo', '$hi', a, b, log(b/a), -8.3 * ($hi - ($lo))))"
