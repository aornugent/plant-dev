#!/bin/bash
# Phase 1c extras, after queue1: the 15-day cap with rule A's thinned nodes on
# each record, and episodic's thinned-and-capped program walked; the unweighted
# programs walked by the x0.7 and x1.4 invaders, for their J' moves; long-wet's
# rule-A program replayed with gradients, which the window phase did not run.
# One R process at a time, under nice, from the snapshot.
D=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev
W=$D/window
P=$D/phase1c
RA=/home/user/plant-dev/.claude/worktrees/agent-a12cdeaf09a1e3e8a/docs/measurements/grid-dynamics/window/rule_A
T108=$W/t/t_u108.rds
INV4="lma=2,lma=0.5,hmat=2,hmat=0.5"
INNER="lma=1.4,lma=0.7,hmat=1.4,hmat=0.7"
INV8="$INV4,$INNER"
until grep -q "queue finished" $P/queue.out 2>/dev/null; do sleep 20; done
cd $P/snap || exit 1
note() { echo "$1 $(date +%T)" >> $P/queue.out; }
drv() {
  local name=$1; shift
  if grep -q "member evaluations" $P/drv/$name.log 2>/dev/null; then note "skip drv $name"; return; fi
  note "start drv $name"
  env PLANT_LIB=$D/lib_v12t METHOD=ck TOL=3e-5 ATOL=1e-4 "$@" OUT=$P/drv/$name.rds \
    nice -n 10 Rscript harness/ark_prototype.R > $P/drv/$name.log 2>&1
  note "done drv $name"
}
rec() {
  local name=$1; shift
  if grep -q "failures" $P/full/$name.log 2>/dev/null; then note "skip full $name"; return; fi
  note "start full $name"
  env PLANT_LIB=$D/lib_guard TOL=3e-5 ATOL=1e-4 "$@" OUT=$P/full/$name.rds \
    nice -n 10 Rscript harness/run_record.R > $P/full/$name.log 2>&1
  note "done full $name"
}
walks() {
  local name=$1; shift
  if grep -q "invader hmat=0.7" $P/walks/$name.log 2>/dev/null; then note "skip walks $name"; return; fi
  note "start walks $name"
  env PLANT_LIB=$D/lib_guard TOL=3e-5 ATOL=1e-4 "$@" OUT=$P/walks/$name.rds \
    nice -n 10 Rscript harness/invader_window.R > $P/walks/$name.log 2>&1
  note "done walks $name"
}
for r in episodic long-drought long-wet; do
  drv ${r}_ruleA_thin_h15 REGIME=$r TIMES=$RA/t_${r}_rule.rds WEIGHT=$RA/weight_$r.rds HMAX=15
done
walks epi_thin_h15 REGIME=episodic TIMES=$RA/t_episodic_rule.rds PROGRAM=$P/drv/episodic_ruleA_thin_h15.rds INVADERS="$INV8"
walks epi_base_inner REGIME=episodic TIMES=$T108 PROGRAM=$W/drv/episodic_base.rds INVADERS="$INNER"
walks ld_base_inner REGIME=long-drought TIMES=$T108 PROGRAM=$D/rej/tied_3e-5_soil1.rds INVADERS="$INNER"
walks wet_base_inner REGIME=long-wet TIMES=$T108 PROGRAM=$W/drv/long-wet_base.rds INVADERS="$INNER"
rec wet_ruleA REGIME=long-wet TIMES=$T108 PROGRAM=$W/drv/long-wet_rule.rds INVADERS="$INV4"
note "queue2 finished"
