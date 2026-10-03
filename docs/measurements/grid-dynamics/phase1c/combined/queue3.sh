#!/bin/bash
# After the long-wet combined run (pid $1) exits: every combined run refused its
# gradient (phylloptim stem_curve_domain), while phase 1a's soil x10 replay and
# phase 1c's rule-A-and-cap replays did not. Four episodic probes, the stand and
# its gradient only, each part of the combined setting alone and in pairs; then
# lib_sw's soil-x10 run on long drought against the driver's soil-x10 program,
# the lib_sw check of long drought's 1e-5 reference, and long-wet's 1e-5
# reference. One R process
# at a time, under nice, from the snapshot.
D=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev
C=$D/phase1c/combined
T108=$D/window/t/t_u108.rds
W=$D/window/rule_A/weight_episodic.rds
while kill -0 $1 2>/dev/null; do sleep 5; done
cd $C/snap || exit 1
note() { echo "$1 $(date +%T)" >> $C/queue.out; }
note "queue3 starts"
probe() {
  local name=$1; shift
  if grep -q "refusal" $C/full/$name.log 2>/dev/null; then note "skip $name"; return; fi
  note "start $name"
  env PLANT_LIB=$D/lib_sw TOL=3e-5 ATOL=1e-4 TIMES=$T108 REGIME=episodic "$@" OUT=$C/full/$name.rds \
    nice -n 10 Rscript grad_probe.R > $C/full/$name.log 2>&1
  note "done $name"
}
rec() {
  local name=$1; shift
  if grep -q "failures" $C/full/$name.log 2>/dev/null; then note "skip $name"; return; fi
  note "start $name"
  env PLANT_LIB=$D/lib_sw TOL=3e-5 ATOL=1e-4 TIMES=$T108 "$@" OUT=$C/full/$name.rds \
    nice -n 10 Rscript harness/run_record.R > $C/full/$name.log 2>&1
  note "done $name"
}
probe probe_epi_soil10 WEIGHT_SOIL=10
probe probe_epi_ruleA_h15 WEIGHT=$W HMAX=15
probe probe_epi_soil10_h15 WEIGHT_SOIL=10 HMAX=15
probe probe_epi_soil10_ruleA WEIGHT_SOIL=10 WEIGHT=$W
rec chk_ld_soil10_forward REGIME=long-drought WEIGHT_SOIL=10 FORWARD=1
rec chk_ld_1e-5_forward REGIME=long-drought TOL=1e-5 FORWARD=1
rec wet_1e-5 REGIME=long-wet TOL=1e-5
note "queue3 finished"
