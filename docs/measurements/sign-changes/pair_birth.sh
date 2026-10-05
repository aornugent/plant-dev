#!/bin/bash
# What a choice of the split moves (prereg.txt, tenth extension): the pair and the
# passage pair_birth.R chooses from final.sh's scans, each bracketed by bisect.sh
# on the probe build, then replayed 1e-7 outside the bracket for the slopes.
#   DEV=... PROBE=lib OUTD=dir bash pair_birth.sh
set -u
D="$(cd "$(dirname "$0")" && pwd)"
PROG=$DEV/sc/runs/program_split.rds
OUTD=$OUTD PLANT_LIB=$PROBE Rscript "$D/pair_birth.R" choose | tee "$OUTD/choose.txt"
R_OTHER=-1e-3; LO=-1e-3; HI=0
if grep -q "^pair none" "$OUTD/choose.txt"; then
  # bisect.sh needs the scan at +1e-3 as a logged replay of its own.
  W=$OUTD/plus; mkdir -p $W
  env PLANT_LIB=$PROBE FORWARD=1 ATOL=1e-4 NODES=108 TOL=1e-4 SPLIT=1 PROGRAM=$PROG LMA_REL=1e-3 \
    ODELIA_SPLIT_LOG=$OUTD/scan_1e-3.txt OUT=$W/r_1e-3.rds Rscript "$D/../../../harness/run_record.R" > $W/out.txt 2>&1
  R_OTHER=1e-3
  R_OTHER=$R_OTHER OUTD=$OUTD PLANT_LIB=$PROBE Rscript "$D/pair_birth.R" choose | tee -a "$OUTD/choose.txt"
fi
one() {  # kind; the passage always from r = -1e-3 against 0, the pair from the last choice
  local line lo=$LO hi=$HI
  if [ "$1" = "pair" ]; then
    line=$(grep "^pair P=" "$OUTD/choose.txt" | tail -1)
    [ "$R_OTHER" = "1e-3" ] && { lo=0; hi=1e-3; }
  else
    line=$(grep "^passage P=" "$OUTD/choose.txt" | head -1)
  fi
  [ -z "$line" ] && { echo "$1: none to bisect" | tee -a "$OUTD/jumps.txt"; return; }
  local p=$(sed 's/.*P=\([0-9]*\).*/\1/' <<< "$line") ta=$(sed 's/.*TA=\([0-9.]*\).*/\1/' <<< "$line")
  local tb=$(sed 's/.*TB=\([0-9.]*\).*/\1/' <<< "$line")
  local W=$OUTD/$1
  LIB=$PROBE PROG=$PROG P=$p TA=$ta TB=$tb LO=$lo HI=$hi W=$W bash "$D/bisect.sh" | tee "$OUTD/$1_bisect.txt"
  read blo bhi <<< $(sed -n 's/^bracket \[\([^,]*\), \([^]]*\)\].*/\1 \2/p' "$OUTD/$1_bisect.txt")
  local olo=$(python3 -c "print(repr($blo - 1e-7))") ohi=$(python3 -c "print(repr($bhi + 1e-7))")
  for r in $olo $ohi; do
    [ -f "$W/r_$r.rds" ] || env PLANT_LIB=$PROBE FORWARD=1 ATOL=1e-4 NODES=108 TOL=1e-4 SPLIT=1 \
      PROGRAM=$PROG LMA_REL=$r ODELIA_SPLIT_LOG=$W/log_$r.txt OUT=$W/r_$r.rds \
      Rscript "$D/../../../harness/run_record.R" > $W/out_$r.txt 2>&1 &
  done
  wait
  echo "$1 (node $p, steps at $ta and $tb):" | tee -a "$OUTD/jumps.txt"
  Rscript "$D/pair_birth.R" jump $W $blo $bhi $olo $ohi | tee -a "$OUTD/jumps.txt"
}
one pair
one passage
echo "JOB DONE pair_birth $(date +%T)"
