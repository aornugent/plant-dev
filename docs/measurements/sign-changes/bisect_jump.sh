#!/bin/bash
# Bisect in r (LMA_REL) for the largest jump in ln J: each round replays three
# interior points in parallel and keeps the sub-interval whose change in ln J
# departs most from the smooth one, SLOPE * dr. Ends when the bracket is under
# 2e-9 wide, and prints the departure across it.
#   LIB=... PROG=... LO=5e-4 HI=5.625e-4 SLOPE=-8.297 W=dir bash bisect_jump.sh
set -u
cd "$(dirname "$0")/../../.."
run() {
  local r=$1
  if [ ! -f "$W/r_$r.rds" ]; then
    env PLANT_LIB=$LIB FORWARD=1 ATOL=1e-4 NODES=108 TOL=1e-4 SPLIT=1 PROGRAM=$PROG LMA_REL=$r \
      ODELIA_SPLIT_LOG=$W/log_$r.txt OUT=$W/r_$r.rds Rscript harness/run_record.R > $W/out_$r.txt 2>&1
  fi
}
lnJ() { Rscript -e "cat(sprintf('%.17g', log(readRDS('$W/r_$1.rds')\$stand\$J)))"; }
export -f run; export LIB PROG W
mkdir -p $W
lo=$LO; hi=$HI
run $lo & run $hi & wait
for round in $(seq 1 16); do
  pts=$(python3 -c "lo,hi=$lo,$hi; print(' '.join(repr(lo+(hi-lo)*k/4) for k in (1,2,3)))")
  for x in $pts; do run $x & done; wait
  all="$lo $pts $hi"; vals=""
  for x in $all; do vals="$vals $(lnJ $x)"; done
  read lo hi dev <<< $(python3 -c "
xs=[float(v) for v in '$all'.split()]; ys=[float(v) for v in '$vals'.split()]; names='$all'.split()
d=[(ys[i+1]-ys[i])-$SLOPE*(xs[i+1]-xs[i]) for i in range(4)]
i=max(range(4), key=lambda i: abs(d[i])); print(names[i], names[i+1], '%.3e' % d[i])")
  echo "round $round: [$lo, $hi] departure $dev width $(python3 -c "print('%.3g' % ($hi - $lo))")"
  python3 -c "import sys; sys.exit(0 if ($hi - $lo) < 2e-9 else 1)" && break
done
