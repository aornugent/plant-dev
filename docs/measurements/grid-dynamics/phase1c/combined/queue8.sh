#!/bin/bash
# ARK's arm B at lower soil weights (lib_ark, plant-dev d4e0535's harness in
# combined/snap4), 3e-5 tied, uniform 108, knots, HMAX=15, rule A's weight,
# WEIGHT_MAX=100, both roles' gradients, no walks. Each weight runs episodic,
# then long drought, and stops at a refusal or raise (arm_ok.R). Two lanes at
# most, each under nice:
#   bash queue8.sh 10      lane 1: soil weight 10
#   bash queue8.sh 30 50   lane 2: soil weights 30 then 50
D=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev
C=$D/phase1c/combined
T108=$D/window/t/t_u108.rds
cd $C/snap4 || exit 1
note() { echo "$1 $(date +%T)" >> $C/queue.out; }
rec() {
  local name=$1; shift
  if ! grep -q "failures" $C/full/$name.log 2>/dev/null; then
    note "start $name"
    env PLANT_LIB=$D/lib_ark TOL=3e-5 ATOL=1e-4 TIMES=$T108 METHOD=ark HMAX=15 WEIGHT_MAX=100 "$@" \
      OUT=$C/full/$name.rds nice -n 10 Rscript harness/run_record.R > $C/full/$name.log 2>&1
    note "done $name"
  else
    note "skip $name"
  fi
  Rscript $C/arm_ok.R $C/full/$name.rds > /dev/null
}
for w in "$@"; do
  if rec arkB_w${w}_epi REGIME=episodic WEIGHT_SOIL=$w WEIGHT=$D/window/rule_A/weight_episodic.rds; then
    rec arkB_w${w}_ld REGIME=long-drought WEIGHT_SOIL=$w WEIGHT=$D/window/rule_A/weight_long-drought.rds ||
      note "stop weight $w at arkB_w${w}_ld: $(Rscript $C/arm_ok.R $C/full/arkB_w${w}_ld.rds)"
  else
    note "stop weight $w at arkB_w${w}_epi: $(Rscript $C/arm_ok.R $C/full/arkB_w${w}_epi.rds)"
  fi
done
note "queue8 lane $* finished"
