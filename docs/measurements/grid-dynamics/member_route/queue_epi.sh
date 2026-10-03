#!/bin/bash
# Episodic, where plant's lma x2 walk raised on rule A's program (t = 32.568):
# the resident recording with states, the CK and DP walks of lma x2 (does the
# member-level walk raise where plant's did?), the reference pass, the test
# steps and their tables. One R process at a time, under nice, from the snapshot.
D=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev
S=$D/spike_methods
L=$D/lib_guard
WAIT_PID=$1
while [ -n "$WAIT_PID" ] && kill -0 $WAIT_PID 2>/dev/null; do sleep 5; done
cd $S/snap || exit 1
note() { echo "$1 $(date +%T)" >> $S/queue.out; }
run() {
  local log=$1 done_pat=$2; shift 2
  if grep -q "$done_pat" $S/$log 2>/dev/null; then note "skip $log"; return; fi
  note "start $log"
  env PLANT_LIB=$L "$@" > $S/$log 2>&1
  note "done $log"
}
if ! grep -q "member evaluations" $S/epi_ruleA.log 2>/dev/null; then
  note "start epi_ruleA driver"
  REGIME=episodic NAME=epi_ruleA bash $S/run_resident.sh
  note "done epi_ruleA driver"
fi
run walk_epi_ruleA_lma2_ck.log "walk of" REC=epi_ruleA REGIME=episodic INVADER=lma=2 METHOD=ck nice -n 10 Rscript walk.R
run walk_epi_ruleA_lma2_dp.log "walk of" REC=epi_ruleA REGIME=episodic INVADER=lma=2 METHOD=dp nice -n 10 Rscript walk.R
run pass1_epi_ruleA.log "^done" REC=epi_ruleA REGIME=episodic RTOL=1e-8 \
  MEMBERS=1,5,9,13,17,21,25,29,33,37,41,45,49,53,57,61,65,69,73,77,81,85,89,93,97,101,105 \
  OUT=pass1_epi_ruleA.rds nice -n 10 Rscript pass1.R
run steps_epi_ruleA.log "^done" REC=epi_ruleA REGIME=episodic nice -n 10 Rscript steps.R
run analyze_epi_ruleA.log "worst cases" nice -n 10 Rscript analyze.R steps_epi_ruleA.rds
note "queue_epi finished"
