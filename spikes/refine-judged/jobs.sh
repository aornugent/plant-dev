#!/bin/bash
# Run jobs, one per argument ("loop CASE" or "ref CASE N"), keeping at most five of this
# spike's SCM processes alive, counting ones started elsewhere.
#   bash spikes/refine-judged/jobs.sh "loop dry" "ref dry 429" ...
W=/home/a/dev/plant-dev/.claude/worktrees/agent-a54dfbccfb0b3fb3b
OUT=/home/a/.claude/jobs/9d586e52/tmp/refine/out
export PLANT_LIB=/home/a/.claude/jobs/9d586e52/rlib-refine PLANT_DEV=$W
cd $W
running() { pgrep -fc "R --no-echo.*spikes/refine-judged/(refine_judged|reference).R"; }
for job in "$@"; do
  set -- $job
  while [ "$(running)" -ge 5 ]; do sleep 15; done
  if [ "$1" = loop ]; then
    (Rscript spikes/refine-judged/refine_judged.R $2 $OUT $3 > $OUT/log-loop-$2$3.txt 2>&1; echo "done $job exit $?") &
  else
    (Rscript spikes/refine-judged/reference.R $2 $3 $OUT > $OUT/log-ref-$2-$3.txt 2>&1; echo "done $job exit $?") &
  fi
  sleep 5
done
wait
