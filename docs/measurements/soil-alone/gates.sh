#!/bin/bash
# The build's gates (prereg.txt, 2026-10-07): plant PLANT-105 on the records,
# three runs at a time from a snapshot of the harness, each skipped once it has
# finished.
#   DEV=... bash gates.sh plant     # every plant run
#   DEV=... bash gates.sh bank      # G5, the five records
#   DEV=... bash gates.sh cost      # G6, with nothing else on the machine
#   DEV=... bash gates.sh driver    # the aligned driver (harness/ark_prototype.R
#                                   # with sa_harness.diff and aligned.diff, in
#                                   # $DEV/soil_alone/gates/driver)
set -u
: "${DEV:?}"
G=$DEV/soil_alone/gates
H="$(cd "$(dirname "$0")/../../.." && pwd)/harness"
SNAP=$G/snap
mkdir -p "$G/runs" "$G/logs" "$SNAP"
[ -d "$SNAP/harness" ] || cp -r "$H" "$SNAP/harness"

# One run_record.R run: name, record, then settings; PLANT_LIB may be overridden.
one() {
  local name=$1 rec=$2; shift 2
  if [ -f "$G/runs/$name.rds" ] && grep -q "failures;" "$G/logs/$name.log" 2>/dev/null; then
    return 0
  fi
  local times=$DEV/window/t/t_u108.rds
  [ "$rec" = constant ] && times=$DEV/window/t/t_const_Gbf16.rds
  (cd "$SNAP" && env PLANT_LIB=$DEV/lib_105c REGIME=$rec TIMES=$times TOL=3e-5 ATOL=1e-4 \
    WEIGHT_SOIL=10 WEIGHT=$DEV/window/rule_A/weight_$rec.rds WEIGHT_MAX=100 HMAX=15 \
    "$@" OUT="$G/runs/$name.rds" nice -n 10 Rscript harness/run_record.R \
    > "$G/logs/$name.log" 2>&1)
  echo "done $name $(date +%T)" >> "$G/queue.out"
}
# The split run taken alone on long drought, then its program's replays.
chain() {
  one alone_split_long-drought long-drought SHARE=0.1 SPLIT=1
  Rscript -e "o <- readRDS('$G/runs/alone_split_long-drought.rds')\$stand
    saveRDS(list(st = data.frame(time = o\$times[-1], h = o\$sizes[-1]),
                 alone_slopes = o\$alone_slopes[-1], alone_steps = o\$alone_steps[-1]),
            '$G/runs/program_ld.rds')"
  local prog="PROGRAM=$G/runs/program_ld.rds SHARE=0.1 SPLIT=1 FORWARD=1"
  one rep long-drought $prog
  one up long-drought $prog LMA_REL=1e-3
  one down long-drought $prog LMA_REL=-1e-3
  for k in 1 2 -1 -2; do one "k$k" long-drought $prog LMA_REL=${k}e-12; done
}
# G5 on one record: the base with its walks, its program's replays at lma
# (1 +- 1e-3), and the nudge, on uniform 108 as the bank's references are.
bank5() {
  local rec=$1 u=TIMES=$DEV/window/t/t_u108.rds
  one "b5_$rec" $rec $u SHARE=0.1 SPLIT=1 INVADERS=lma=0.5,lma=2 INVADER_GRADIENTS=1
  Rscript -e "o <- readRDS('$G/runs/b5_$rec.rds')\$stand
    saveRDS(list(st = data.frame(time = o\$times[-1], h = o\$sizes[-1]),
                 alone_slopes = o\$alone_slopes[-1], alone_steps = o\$alone_steps[-1]),
            '$G/runs/b5prog_$rec.rds')"
  local prog="PROGRAM=$G/runs/b5prog_$rec.rds"
  one "b5up_$rec" $rec $u SHARE=0.1 SPLIT=1 FORWARD=1 $prog LMA_REL=1e-3
  one "b5down_$rec" $rec $u SHARE=0.1 SPLIT=1 FORWARD=1 $prog LMA_REL=-1e-3
  one "b5n_$rec" $rec $u SHARE=0.1 SPLIT=1 TOL=3.15e-5
}
# The aligned driver on a record, splits off.
drv() {
  local rec=$1 name=drv_$1
  if [ -f "$G/runs/$name.rds" ]; then
    return 0
  fi
  (cd "$G/driver" && env PLANT_LIB=$DEV/lib_105c REGIME=$rec TIMES=$DEV/window/t/t_u108.rds \
    TOL=3e-5 ATOL=1e-4 WEIGHT=$DEV/window/rule_A/weight_$rec.rds WEIGHT_MAX=100 HMAX=15 \
    METHOD=ck TOL_SOIL=10 MR_SHARE=0.1 MR_U1=stage OUT="$G/runs/$name.rds" \
    nice -n 10 Rscript harness/ark_prototype.R > "$G/logs/$name.log" 2>&1)
  echo "done $name $(date +%T)" >> "$G/queue.out"
}
job() {
  local kind=$1; shift
  case "$kind" in
    one) one "$@" ;;
    chain) chain ;;
    drv) drv "$@" ;;
    bank5) bank5 "$@" ;;
  esac
}
export -f one chain drv bank5 job
export G SNAP DEV

case "${1:-plant}" in
  plant)
    {
      for rec in long-drought episodic; do
        echo "one ref_$rec $rec TOL=1e-5"
        echo "one bnd_$rec $rec"
        echo "one alone_$rec $rec SHARE=0.1"
      done
      echo "chain"
      echo "one alone_split_episodic episodic SHARE=0.1 SPLIT=1"
      echo "one alone_constant constant SHARE=0.1 FORWARD=1"
      echo "one bnd_constant constant FORWARD=1"
      for rec in long-drought episodic; do
        echo "one off104_$rec $rec PLANT_LIB=$DEV/lib_104 FORWARD=1"
      done
      echo "one off104_split long-drought PLANT_LIB=$DEV/lib_104 FORWARD=1 SPLIT=1"
      echo "one off105_split long-drought FORWARD=1 SPLIT=1"
    } | xargs -P 3 -L 1 bash -c 'job "$@"' _
    ;;
  driver)
    printf 'drv long-drought\ndrv episodic\n' | xargs -P 2 -L 1 bash -c 'job "$@"' _
    ;;
  bank)
    printf 'bank5 %s\n' long-wet long-drought episodic dry constant |
      xargs -P 3 -L 1 bash -c 'job "$@"' _
    ;;
  cost)
    for k in 1 2; do
      one "c6a$k" long-drought SHARE=0.1
      one "c6b$k" long-drought
    done
    mkdir -p "$G/profile"
    (cd "$(dirname "$H")" && env PLANT_LIB=$DEV/lib_105c PLANT_TEST_LIB=$DEV/lib_105c \
      REGIME=long-drought TIMES=$DEV/window/t/t_u108.rds TOL=3e-5 ATOL=1e-4 WEIGHT_SOIL=10 \
      WEIGHT=$DEV/window/rule_A/weight_long-drought.rds WEIGHT_MAX=100 HMAX=15 SHARE=0.1 \
      FORWARD=1 bash scripts/profile-gradient.sh harness/profile_forward.R \
      "$G/profile/alone_fwd" > "$G/profile/alone_fwd.out" 2>&1)
    for focus in . alone_ends; do
      echo "$focus: $(google-pprof --text --cum --focus="$focus" \
        "$G/profile/alone_fwd/plant.so" "$G/profile/alone_fwd/gradient.prof" 2>/dev/null |
        sed -n 1p)" >> "$G/profile/alone_fwd.read"
    done
    ;;
esac
echo "JOB DONE gates ${1:-plant} $(date +%T)" >> "$G/queue.out"
