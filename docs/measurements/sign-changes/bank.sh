#!/bin/bash
# The eighteenth extension's runs (prereg.txt): the split and plain on every
# record of the bank, three at a time, from a snapshot of the harness.
#   DEV=... LIB=lib OUTD=dir bash bank.sh
set -u
H="$(cd "$(dirname "$0")/../../.." && pwd)/harness"
SNAP=$OUTD/snap
mkdir -p "$OUTD" "$SNAP"
[ -d "$SNAP/harness" ] || cp -r "$H" "$SNAP/harness"

# One run_record.R run unless its output already finished: name, then settings.
one() {
  local name=$1; shift
  if [ -f "$OUTD/$name.rds" ] && grep -q "failures;" "$OUTD/$name.log" 2>/dev/null; then
    return 0
  fi
  (cd "$SNAP" && env PLANT_LIB="$LIB" ATOL=1e-4 NODES=108 "$@" OUT="$OUTD/$name.rds" \
    nice -n 10 Rscript harness/run_record.R > "$OUTD/$name.log" 2>&1)
}
# The split base, then the replays of its own program at lma (1 +/- 1e-3).
chain() {
  local r=$1 tag=$2
  one "${tag}_split" REGIME="$r" TOL=1e-4 SPLIT=1 INVADERS="lma=0.5,lma=2" \
    INVADER_GRADIENTS=1
  Rscript -e "o <- readRDS('$OUTD/${tag}_split.rds'); saveRDS(list(st = data.frame(time = o\$stand\$times[-1], h = o\$stand\$sizes[-1])), '$OUTD/${tag}_program.rds')"
  one "${tag}_up" REGIME="$r" TOL=1e-4 SPLIT=1 FORWARD=1 PROGRAM="$OUTD/${tag}_program.rds" LMA_REL=1e-3
  one "${tag}_down" REGIME="$r" TOL=1e-4 SPLIT=1 FORWARD=1 PROGRAM="$OUTD/${tag}_program.rds" LMA_REL=-1e-3
}
job() {
  local kind=$1 r=$2 tag=$3
  case "$kind" in
    chain) chain "$r" "$tag" ;;
    plain) one "${tag}_plain" REGIME="$r" TOL=1e-4 ;;
    nsplit) one "${tag}_nsplit" REGIME="$r" TOL=1.05e-4 SPLIT=1 ;;
    nplain) one "${tag}_nplain" REGIME="$r" TOL=1.05e-4 ;;
    ref) one "${tag}_ref" REGIME="$r" TOL=1e-6 SPLIT=1 FORWARD=1 ;;
  esac
  echo "$kind $tag $(date +%T)" >> "$OUTD/queue.out"
}
export -f one chain job
export OUTD LIB SNAP

# The costliest records first, so the last jobs are the short ones.
for spec in long-wet:wet long-drought:ld episodic:epi dry:dry constant:const; do
  r=${spec%%:*}; tag=${spec##*:}
  for kind in chain plain nsplit nplain ref; do echo "$kind $r $tag"; done
done | xargs -P 3 -L 1 bash -c 'job "$@"' _
echo "JOB DONE bank $(date +%T)" >> "$OUTD/queue.out"
