#!/bin/bash
# The combined gains in plant: the soil's weight x10, rule A's weight and a
# 15-day cap, plant's own adaptive runs on lib_sw, 3e-5 tied, uniform 108, with
# both roles' gradients and eight invaders walked. First a check that lib_sw with
# no weights repeats lib_guard's episodic run; then the three records; long-wet's
# missing 1e-5 reference; the +-5% tolerance nudges of the combined setting on
# long drought. One R process at a time, under nice, from the snapshot.
D=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev
C=$D/phase1c/combined
T108=$D/window/t/t_u108.rds
INV8="lma=2,lma=0.5,hmat=2,hmat=0.5,lma=1.4,lma=0.7,hmat=1.4,hmat=0.7"
cd $C/snap || exit 1
note() { echo "$1 $(date +%T)" >> $C/queue.out; }
rec() {
  local name=$1; shift
  if grep -q "failures" $C/full/$name.log 2>/dev/null; then note "skip $name"; return; fi
  note "start $name"
  env PLANT_LIB=$D/lib_sw TOL=3e-5 ATOL=1e-4 TIMES=$T108 "$@" OUT=$C/full/$name.rds \
    nice -n 10 Rscript harness/run_record.R > $C/full/$name.log 2>&1
  note "done $name"
}
comb() { local r=$1; shift; echo "WEIGHT_SOIL=10 WEIGHT=$D/window/rule_A/weight_$r.rds HMAX=15"; }
rec chk_epi_forward REGIME=episodic FORWARD=1
rec comb_epi REGIME=episodic $(comb episodic) INVADERS="$INV8"
rec comb_ld REGIME=long-drought $(comb long-drought) INVADERS="$INV8"
rec comb_wet REGIME=long-wet $(comb long-wet) INVADERS="$INV8"
rec wet_1e-5 REGIME=long-wet TOL=1e-5
rec comb_ld_2.85e-5 REGIME=long-drought $(comb long-drought) TOL=2.85e-5
rec comb_ld_3.15e-5 REGIME=long-drought $(comb long-drought) TOL=3.15e-5
note "queue finished"
