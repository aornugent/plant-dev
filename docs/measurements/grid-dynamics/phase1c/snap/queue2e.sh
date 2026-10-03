#!/bin/bash
# Phase 1c extras, after queue1, in order of value. On episodic lma x2's walk
# runs on rule A's program capped at 15 days and raises capped at 26; the
# unweighted programs take no step over 22 days before the weight starts.
# 1. Episodic, rule A capped at 22 and at 20 days, driver then walks: where
#    between 15 and 26 days the walk stops raising, and whether a cap that leaves
#    the floors' programs untouched before the window protects it.
# 2. Episodic's unweighted run capped at 15 days, driver then full replay with
#    the range-end invaders: the cap's own move, and the weight's under the cap.
# 3. Episodic at 1e-5 under plant's own control, both roles' gradients: a
#    tighter reference, to see whether the capped run sits farther from it.
# 4. Long-wet's rule-A program replayed with gradients and the range-end
#    invaders walked, which the window phase did not run.
# 5. The cap with rule A's thinned nodes (driver), each record.
# 6. Long drought's and long-wet's unweighted runs capped, driver then replay.
# 7. If time allows: episodic's thinned-and-capped program walked; the
#    unweighted programs walked by the x0.7 and x1.4 invaders.
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
for h in 22 20; do
  drv episodic_ruleA_h$h REGIME=episodic TIMES=$T108 WEIGHT=$RA/weight_episodic.rds HMAX=$h
  walks epi_h$h REGIME=episodic TIMES=$T108 PROGRAM=$P/drv/episodic_ruleA_h$h.rds INVADERS="$INV8"
done
drv episodic_base_h15 REGIME=episodic TIMES=$T108 HMAX=15
rec epi_base_h15 REGIME=episodic TIMES=$T108 PROGRAM=$P/drv/episodic_base_h15.rds INVADERS="$INV4"
rec epi_1e-5 REGIME=episodic TIMES=$T108 TOL=1e-5
rec wet_ruleA REGIME=long-wet TIMES=$T108 PROGRAM=$W/drv/long-wet_rule.rds INVADERS="$INV4"
for r in episodic long-drought long-wet; do
  drv ${r}_ruleA_thin_h15 REGIME=$r TIMES=$RA/t_${r}_rule.rds WEIGHT=$RA/weight_$r.rds HMAX=15
done
drv long-drought_base_h15 REGIME=long-drought TIMES=$T108 HMAX=15
rec ld_base_h15 REGIME=long-drought TIMES=$T108 PROGRAM=$P/drv/long-drought_base_h15.rds
drv long-wet_base_h15 REGIME=long-wet TIMES=$T108 HMAX=15
rec wet_base_h15 REGIME=long-wet TIMES=$T108 PROGRAM=$P/drv/long-wet_base_h15.rds
walks epi_thin_h15 REGIME=episodic TIMES=$RA/t_episodic_rule.rds PROGRAM=$P/drv/episodic_ruleA_thin_h15.rds INVADERS="$INV8"
walks epi_base_inner REGIME=episodic TIMES=$T108 PROGRAM=$W/drv/episodic_base.rds INVADERS="$INNER"
walks ld_base_inner REGIME=long-drought TIMES=$T108 PROGRAM=$D/rej/tied_3e-5_soil1.rds INVADERS="$INNER"
walks wet_base_inner REGIME=long-wet TIMES=$T108 PROGRAM=$W/drv/long-wet_base.rds INVADERS="$INNER"
note "queue2 finished"
