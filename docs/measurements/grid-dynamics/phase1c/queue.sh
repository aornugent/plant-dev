#!/bin/bash
# Phase 1c: rule A's weight with every step capped (HMAX, days), on long drought,
# long-wet and episodic, at 3e-5 tied on uniform 108. In order of what decides
# the verdict: the patch's no-op check; episodic (where lma x2 raised) at 15 days,
# its full-gradient replay with eight invaders walked, then at 26 days with the
# walks alone; long drought and long-wet at 15 days, driver then full replay; the
# 26-day drivers there. One R process at a time, under nice, from the snapshot.
D=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev
W=$D/window
P=$D/phase1c
RA=/home/user/plant-dev/.claude/worktrees/agent-a12cdeaf09a1e3e8a/docs/measurements/grid-dynamics/window/rule_A
T108=$W/t/t_u108.rds
INV8="lma=2,lma=0.5,hmat=2,hmat=0.5,lma=1.4,lma=0.7,hmat=1.4,hmat=0.7"
mkdir -p $P/drv $P/full $P/walks
cd $P/snap || exit 1
note() { echo "$1 $(date +%T)" >> $P/queue.out; }
drv() {
  local name=$1; shift
  if grep -q "member evaluations" $P/drv/$name.log 2>/dev/null; then note "skip drv $name"; return; fi
  note "start drv $name"
  env PLANT_LIB=$D/lib_v12t METHOD=ck TOL=3e-5 ATOL=1e-4 TIMES=$T108 "$@" OUT=$P/drv/$name.rds \
    nice -n 10 Rscript harness/ark_prototype.R > $P/drv/$name.log 2>&1
  note "done drv $name"
}
rec() {
  local name=$1; shift
  if grep -q "failures" $P/full/$name.log 2>/dev/null; then note "skip full $name"; return; fi
  note "start full $name"
  env PLANT_LIB=$D/lib_guard TOL=3e-5 ATOL=1e-4 TIMES=$T108 "$@" OUT=$P/full/$name.rds \
    nice -n 10 Rscript harness/run_record.R > $P/full/$name.log 2>&1
  note "done full $name"
}
walks() {
  local name=$1; shift
  if grep -q "invader hmat=0.5" $P/walks/$name.log 2>/dev/null; then note "skip walks $name"; return; fi
  note "start walks $name"
  env PLANT_LIB=$D/lib_guard TOL=3e-5 ATOL=1e-4 TIMES=$T108 "$@" OUT=$P/walks/$name.rds \
    nice -n 10 Rscript harness/invader_window.R > $P/walks/$name.log 2>&1
  note "done walks $name"
}
drv episodic_ruleA_check REGIME=episodic WEIGHT=$RA/weight_episodic.rds
drv episodic_ruleA_h15 REGIME=episodic WEIGHT=$RA/weight_episodic.rds HMAX=15
rec epi_h15 REGIME=episodic PROGRAM=$P/drv/episodic_ruleA_h15.rds INVADERS="$INV8"
drv episodic_ruleA_h26 REGIME=episodic WEIGHT=$RA/weight_episodic.rds HMAX=26
walks epi_h26 REGIME=episodic PROGRAM=$P/drv/episodic_ruleA_h26.rds INVADERS="$INV8"
drv long-drought_ruleA_h15 REGIME=long-drought WEIGHT=$RA/weight_long-drought.rds HMAX=15
drv long-wet_ruleA_h15 REGIME=long-wet WEIGHT=$RA/weight_long-wet.rds HMAX=15
rec ld_h15 REGIME=long-drought PROGRAM=$P/drv/long-drought_ruleA_h15.rds INVADERS="$INV8"
rec wet_h15 REGIME=long-wet PROGRAM=$P/drv/long-wet_ruleA_h15.rds INVADERS="$INV8"
drv long-drought_ruleA_h26 REGIME=long-drought WEIGHT=$RA/weight_long-drought.rds HMAX=26
drv long-wet_ruleA_h26 REGIME=long-wet WEIGHT=$RA/weight_long-wet.rds HMAX=26
note "queue finished"
