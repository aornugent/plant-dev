#!/bin/bash
# After queue3's soil-x10 check (pid $1): every combined run refuses its
# gradient, and the probes trace the refusal to the soil's weight times rule A's
# (x1000 late). So long-wet's 1e-5 reference is run forward only (ln J is the
# one combined quantity), long drought's 1e-5 reference is checked forward only,
# and the combined setting's +-5% tolerance nudges on long drought run with both
# roles' gradients and no walks. One R process at a time, under nice, from the
# snapshot.
D=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev
C=$D/phase1c/combined
T108=$D/window/t/t_u108.rds
while kill -0 $1 2>/dev/null; do sleep 5; done
cd $C/snap || exit 1
note() { echo "$1 $(date +%T)" >> $C/queue.out; }
note "queue4 starts"
rec() {
  local name=$1; shift
  if grep -q "failures" $C/full/$name.log 2>/dev/null; then note "skip $name"; return; fi
  note "start $name"
  env PLANT_LIB=$D/lib_sw TOL=3e-5 ATOL=1e-4 TIMES=$T108 "$@" OUT=$C/full/$name.rds \
    nice -n 10 Rscript harness/run_record.R > $C/full/$name.log 2>&1
  note "done $name"
}
comb() { echo "WEIGHT_SOIL=10 WEIGHT=$D/window/rule_A/weight_$1.rds HMAX=15"; }
rec chk_ld_1e-5_forward REGIME=long-drought TOL=1e-5 FORWARD=1
rec wet_1e-5_forward REGIME=long-wet TOL=1e-5 FORWARD=1
rec comb_ld_2.85e-5 REGIME=long-drought $(comb long-drought) TOL=2.85e-5
rec comb_ld_3.15e-5 REGIME=long-drought $(comb long-drought) TOL=3.15e-5
note "queue4 finished"
