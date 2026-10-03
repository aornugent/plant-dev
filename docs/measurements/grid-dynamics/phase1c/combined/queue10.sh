#!/bin/bash
# Constant rain on its resolved grid (window/t/t_const_Gbf16.rds), from
# combined/snap4, 3e-5 tied, HMAX=15, both roles' gradients and eight walks. One
# R process at a time, each under nice and started only when the 1-minute load
# is under 4. An arm stops at a refusal or raise (arm_ok.R).
#   bash queue10.sh main     unweighted CK, the 1e-5 CK reference, bounded CK,
#                            ARK arms A and B
#   bash queue10.sh ark1e-5 A|B    an ARK arm at 1e-5
#   bash queue10.sh nudge A|B      an ARK arm's +-5% nudges, gradients only
D=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev
C=$D/phase1c/combined
TC=$D/window/t/t_const_Gbf16.rds
WC=$D/window/rule_A/weight_constant.rds
INV8="lma=2,lma=0.5,hmat=2,hmat=0.5,lma=1.4,lma=0.7,hmat=1.4,hmat=0.7"
cd $C/snap4 || exit 1
note() { echo "$1 $(date +%T)" >> $C/queue.out; }
wait_load() {
  while awk '{exit !($1 >= 4)}' /proc/loadavg; do sleep 30; done
}
# rec <name> <lib> <arm or -> env...: runs unless its log shows it finished; an
# arm's failing run ends the lane.
rec() {
  local name=$1 lib=$2 arm=$3; shift 3
  if ! grep -q "failures" $C/full/$name.log 2>/dev/null; then
    wait_load
    note "start $name (load $(cut -d' ' -f1 /proc/loadavg))"
    env PLANT_LIB=$D/$lib REGIME=constant TOL=3e-5 ATOL=1e-4 TIMES=$TC "$@" OUT=$C/full/$name.rds \
      nice -n 10 Rscript harness/run_record.R > $C/full/$name.log 2>&1
    note "done $name"
  else
    note "skip $name"
  fi
  if [ "$arm" != - ] && ! why=$(Rscript $C/arm_ok.R $C/full/$name.rds); then
    note "stop arm $arm at $name: $why"
    return 1
  fi
}
ark() { echo "METHOD=ark WEIGHT_SOIL=100 HMAX=15"; }
case $1 in
  main)
    rec const_ck lib_sw - HMAX=15 INVADERS="$INV8"
    rec const_ck_1e-5 lib_sw - TOL=1e-5 INVADERS="$INV8"
    rec const_bnd lib_sw - WEIGHT_SOIL=10 WEIGHT=$WC WEIGHT_MAX=100 HMAX=15 INVADERS="$INV8"
    rec const_arkA lib_ark A $(ark) INVADERS="$INV8"
    rec const_arkB lib_ark B $(ark) WEIGHT=$WC WEIGHT_MAX=100 INVADERS="$INV8" ;;
  ark1e-5)
    if [ "$2" = A ]; then rec const_arkA_1e-5 lib_ark A $(ark) TOL=1e-5 INVADERS="$INV8"; fi
    if [ "$2" = B ]; then rec const_arkB_1e-5 lib_ark B $(ark) WEIGHT=$WC WEIGHT_MAX=100 TOL=1e-5 INVADERS="$INV8"; fi ;;
  nudge)
    if [ "$2" = A ]; then
      rec const_arkA_2.85e-5 lib_ark A $(ark) TOL=2.85e-5 && rec const_arkA_3.15e-5 lib_ark A $(ark) TOL=3.15e-5
    fi
    if [ "$2" = B ]; then
      rec const_arkB_2.85e-5 lib_ark B $(ark) WEIGHT=$WC WEIGHT_MAX=100 TOL=2.85e-5 &&
        rec const_arkB_3.15e-5 lib_ark B $(ark) WEIGHT=$WC WEIGHT_MAX=100 TOL=3.15e-5
    fi ;;
esac
note "queue10 $* finished"
