#!/bin/bash
# After the long-drought reference pass: the self-test, the test steps, the
# reference check and the CK and DP walks of lma x2, one R process at a time,
# under nice, from the snapshot. A stage that has its output is skipped.
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
run selftest.log "ms per field" nice -n 10 Rscript selftest.R
run steps_ld_ruleA.log "^done" REC=ld_ruleA nice -n 10 Rscript steps.R
run analyze_ld_ruleA.log "worst cases" nice -n 10 Rscript analyze.R steps_ld_ruleA.rds
run refcheck_ld_ruleA.log "^columns" REC=ld_ruleA nice -n 10 Rscript refcheck.R
run walk_ld_ruleA_lma2_ck.log "walk of" REC=ld_ruleA INVADER=lma=2 METHOD=ck nice -n 10 Rscript walk.R
run walk_ld_ruleA_lma2_dp.log "walk of" REC=ld_ruleA INVADER=lma=2 METHOD=dp nice -n 10 Rscript walk.R
note "queue_ld finished"
