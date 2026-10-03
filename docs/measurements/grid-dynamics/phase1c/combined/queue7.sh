#!/bin/bash
# The implicit soil chain in plant (lib_ark, plant-dev 1ffb6ab's harness with the
# clamp tallies, combined/snap3), 3e-5 tied, uniform 108, knots, HMAX=15. Two
# lanes, at most two R processes, each under nice; an arm stops at the first
# record that refuses a gradient or raises (arm_ok.R).
#   lane A: METHOD=ark WEIGHT_SOIL=100 on episodic, long drought, long-wet with
#           both roles' gradients and eight walks; long drought's +-5% nudges with
#           gradients and no walks;
#   lane B: lane A's setting plus rule A's WEIGHT and WEIGHT_MAX=100, the three
#           records with gradients and walks.
#   bash queue7.sh A|B
D=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev
C=$D/phase1c/combined
T108=$D/window/t/t_u108.rds
INV8="lma=2,lma=0.5,hmat=2,hmat=0.5,lma=1.4,lma=0.7,hmat=1.4,hmat=0.7"
cd $C/snap3 || exit 1
note() { echo "$1 $(date +%T)" >> $C/queue.out; }
rec() {
  local name=$1; shift
  if ! grep -q "failures" $C/full/$name.log 2>/dev/null; then
    note "start $name"
    env PLANT_LIB=$D/lib_ark TOL=3e-5 ATOL=1e-4 TIMES=$T108 METHOD=ark WEIGHT_SOIL=100 HMAX=15 "$@" \
      OUT=$C/full/$name.rds nice -n 10 Rscript harness/run_record.R > $C/full/$name.log 2>&1
    note "done $name"
  else
    note "skip $name"
  fi
  if ! why=$(Rscript $C/arm_ok.R $C/full/$name.rds); then
    note "stop arm $ARM at $name: $why"
    note "queue7 lane $ARM finished"
    exit 0
  fi
}
ARM=$1
ruleA() { echo "WEIGHT=$D/window/rule_A/weight_$1.rds WEIGHT_MAX=100"; }
if [ "$ARM" = A ]; then
  rec arkA_epi REGIME=episodic INVADERS="$INV8"
  rec arkA_ld REGIME=long-drought INVADERS="$INV8"
  rec arkA_wet REGIME=long-wet INVADERS="$INV8"
  rec arkA_ld_2.85e-5 REGIME=long-drought TOL=2.85e-5
  rec arkA_ld_3.15e-5 REGIME=long-drought TOL=3.15e-5
fi
if [ "$ARM" = B ]; then
  rec arkB_epi REGIME=episodic $(ruleA episodic) INVADERS="$INV8"
  rec arkB_ld REGIME=long-drought $(ruleA long-drought) INVADERS="$INV8"
  rec arkB_wet REGIME=long-wet $(ruleA long-wet) INVADERS="$INV8"
fi
note "queue7 lane $ARM finished"
