#!/bin/bash
# Phase 1c, queue3's order with rule A capped at 10 days added (where
# Dormand-Prince's lowest stage reaches the -0.78 Cash-Karp walked at 22 days),
# once queue3's running driver exits. On episodic lma x2 runs at 15 and 22 days and raises at 26.
# 1. The 20-day walks: past Cash-Karp's positivity limit, 23% inside stability.
# 2. Rule A capped at 7 days (Dormand-Prince's positivity limit is 7.3 d), on
#    episodic and long drought, priced in rows against rule A uncapped.
# 3. Rule A capped at 22 days on long drought and long-wet (driver), and
#    episodic's 22-day program replayed with gradients.
# 4. Episodic's unweighted run capped at 15 days, driver then full replay with
#    the range-end invaders; episodic at 1e-5 under plant's own control.
# 5. Long-wet's rule-A program (which the 26-day cap leaves bit for bit)
#    replayed with gradients and the range-end invaders walked.
# 6. Long drought's unweighted run capped at 15 days; the cap with rule A's
#    thinned nodes; long-wet's unweighted run capped.
# One R process at a time, under nice, from the snapshot.
D=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev
W=$D/window
P=$D/phase1c
RA=/home/user/plant-dev/.claude/worktrees/agent-a12cdeaf09a1e3e8a/docs/measurements/grid-dynamics/window/rule_A
T108=$W/t/t_u108.rds
INV4="lma=2,lma=0.5,hmat=2,hmat=0.5"
INNER="lma=1.4,lma=0.7,hmat=1.4,hmat=0.7"
INV8="$INV4,$INNER"
WAIT_PID=$1
while kill -0 $WAIT_PID 2>/dev/null; do sleep 5; done
cd $P/snap || exit 1
note() { echo "$1 $(date +%T)" >> $P/queue.out; }
note "queue4 starts after pid $WAIT_PID"
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
drv episodic_ruleA_h20 REGIME=episodic TIMES=$T108 WEIGHT=$RA/weight_episodic.rds HMAX=20
walks epi_h20 REGIME=episodic TIMES=$T108 PROGRAM=$P/drv/episodic_ruleA_h20.rds INVADERS="$INV8"
drv episodic_ruleA_h7 REGIME=episodic TIMES=$T108 WEIGHT=$RA/weight_episodic.rds HMAX=7
drv long-drought_ruleA_h7 REGIME=long-drought TIMES=$T108 WEIGHT=$RA/weight_long-drought.rds HMAX=7
drv long-drought_ruleA_h22 REGIME=long-drought TIMES=$T108 WEIGHT=$RA/weight_long-drought.rds HMAX=22
drv long-wet_ruleA_h22 REGIME=long-wet TIMES=$T108 WEIGHT=$RA/weight_long-wet.rds HMAX=22
rec epi_h22 REGIME=episodic TIMES=$T108 PROGRAM=$P/drv/episodic_ruleA_h22.rds
drv episodic_base_h15 REGIME=episodic TIMES=$T108 HMAX=15
rec epi_base_h15 REGIME=episodic TIMES=$T108 PROGRAM=$P/drv/episodic_base_h15.rds INVADERS="$INV4"
rec epi_1e-5 REGIME=episodic TIMES=$T108 TOL=1e-5
drv episodic_ruleA_h10 REGIME=episodic TIMES=$T108 WEIGHT=$RA/weight_episodic.rds HMAX=10
drv long-drought_ruleA_h10 REGIME=long-drought TIMES=$T108 WEIGHT=$RA/weight_long-drought.rds HMAX=10
rec wet_ruleA REGIME=long-wet TIMES=$T108 PROGRAM=$W/drv/long-wet_rule.rds INVADERS="$INV4"
drv long-drought_base_h15 REGIME=long-drought TIMES=$T108 HMAX=15
rec ld_base_h15 REGIME=long-drought TIMES=$T108 PROGRAM=$P/drv/long-drought_base_h15.rds
for r in episodic long-drought long-wet; do
  drv ${r}_ruleA_thin_h15 REGIME=$r TIMES=$RA/t_${r}_rule.rds WEIGHT=$RA/weight_$r.rds HMAX=15
done
drv long-wet_base_h15 REGIME=long-wet TIMES=$T108 HMAX=15
rec wet_base_h15 REGIME=long-wet TIMES=$T108 PROGRAM=$P/drv/long-wet_base_h15.rds
note "queue4 finished"
