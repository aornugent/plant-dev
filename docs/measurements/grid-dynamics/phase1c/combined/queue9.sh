#!/bin/bash
# ARK at 1e-5 (lib_ark, plant-dev d4e0535's harness in combined/snap4), ATOL=1e-4,
# uniform 108, knots, HMAX=15, METHOD=ark, WEIGHT_SOIL=100, both roles'
# gradients, no walks. An arm runs episodic, then long drought, and stops at a
# refusal or raise (arm_ok.R). Two lanes at most, each under nice:
#   bash queue9.sh A    arm A
#   bash queue9.sh B    arm B: plus rule A's weight and WEIGHT_MAX=100
#   bash queue9.sh N<arm>   long drought's +-5% nudges (9.5e-6, 1.05e-5) for that arm
D=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev
C=$D/phase1c/combined
T108=$D/window/t/t_u108.rds
cd $C/snap4 || exit 1
note() { echo "$1 $(date +%T)" >> $C/queue.out; }
rec() {
  local name=$1; shift
  if ! grep -q "failures" $C/full/$name.log 2>/dev/null; then
    note "start $name"
    env PLANT_LIB=$D/lib_ark TOL=1e-5 ATOL=1e-4 TIMES=$T108 METHOD=ark WEIGHT_SOIL=100 HMAX=15 "$@" \
      OUT=$C/full/$name.rds nice -n 10 Rscript harness/run_record.R > $C/full/$name.log 2>&1
    note "done $name"
  else
    note "skip $name"
  fi
  if ! why=$(Rscript $C/arm_ok.R $C/full/$name.rds); then
    note "stop arm $ARM at $name: $why"
    note "queue9 lane $ARM finished"
    exit 0
  fi
}
ARM=$1
ruleA() { echo "WEIGHT=$D/window/rule_A/weight_$1.rds WEIGHT_MAX=100"; }
case $ARM in
  A) rec arkA_1e-5_epi REGIME=episodic
     rec arkA_1e-5_ld REGIME=long-drought ;;
  B) rec arkB_1e-5_epi REGIME=episodic $(ruleA episodic)
     rec arkB_1e-5_ld REGIME=long-drought $(ruleA long-drought) ;;
  NA) rec arkA_1e-5_ld_9.5e-6 REGIME=long-drought TOL=9.5e-6
      rec arkA_1e-5_ld_1.05e-5 REGIME=long-drought TOL=1.05e-5 ;;
  NB) rec arkB_1e-5_ld_9.5e-6 REGIME=long-drought $(ruleA long-drought) TOL=9.5e-6
      rec arkB_1e-5_ld_1.05e-5 REGIME=long-drought $(ruleA long-drought) TOL=1.05e-5 ;;
esac
note "queue9 lane $ARM finished"
