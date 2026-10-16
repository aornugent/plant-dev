#!/bin/bash
# slot.sh CMD...: run CMD in one of the two process slots run.sh shares: hold new runs,
# wait until at most one run is going, run CMD, release.
SU=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/summing
touch $SU/hold
while [ $(( $(grep -c '^start ' $SU/queue.out) - $(grep -c '^done ' $SU/queue.out) )) -ge 2 ]; do sleep 5; done
"$@"; st=$?
rm -f $SU/hold
exit $st
