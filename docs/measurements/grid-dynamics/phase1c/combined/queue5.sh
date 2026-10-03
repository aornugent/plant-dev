#!/bin/bash
# The bounded combined setting (soil x10, rule A, 15-day cap, each state's weight
# at most 100), plant's own adaptive runs on lib_sw from plant-dev 4bb85f5's
# harness with the soil clamp tallies (snap2), 3e-5 tied, uniform 108. Two lanes,
# at most two R processes, each under nice:
#   lane a: long-wet with both roles' gradients and eight walks; long-wet's 1e-5
#           reference with gradients;
#   lane b: long drought and episodic with gradients and walks; long drought's
#           +-5% tolerance nudges with both roles' gradients and no walks.
#   bash queue5.sh a|b
D=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev
C=$D/phase1c/combined
T108=$D/window/t/t_u108.rds
INV8="lma=2,lma=0.5,hmat=2,hmat=0.5,lma=1.4,lma=0.7,hmat=1.4,hmat=0.7"
cd $C/snap2 || exit 1
note() { echo "$1 $(date +%T)" >> $C/queue.out; }
rec() {
  local name=$1; shift
  if grep -q "failures" $C/full/$name.log 2>/dev/null; then note "skip $name"; return; fi
  note "start $name"
  env PLANT_LIB=$D/lib_sw TOL=3e-5 ATOL=1e-4 TIMES=$T108 "$@" OUT=$C/full/$name.rds \
    nice -n 10 Rscript harness/run_record.R > $C/full/$name.log 2>&1
  note "done $name"
}
bounded() { echo "WEIGHT_SOIL=10 WEIGHT=$D/window/rule_A/weight_$1.rds HMAX=15 WEIGHT_MAX=100"; }
if [ "$1" = a ]; then
  rec bnd_wet REGIME=long-wet $(bounded long-wet) INVADERS="$INV8"
  rec wet_1e-5 REGIME=long-wet TOL=1e-5
fi
if [ "$1" = b ]; then
  rec bnd_ld REGIME=long-drought $(bounded long-drought) INVADERS="$INV8"
  rec bnd_epi REGIME=episodic $(bounded episodic) INVADERS="$INV8"
  rec bnd_ld_2.85e-5 REGIME=long-drought $(bounded long-drought) TOL=2.85e-5
  rec bnd_ld_3.15e-5 REGIME=long-drought $(bounded long-drought) TOL=3.15e-5
fi
note "queue5 lane $1 finished"
