#!/bin/bash
# run857.sh: the third reference rung (857 uniform nodes, the reference recipe of run.sh)
# for the named cases, after run.sh's queue and any earlier run857.sh have finished.
# Usage: bash run857.sh TAG case ...
D=/home/user/plant-dev/docs/measurements/schedule-search/rootcause/heldout
O=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/heldout
TAG=$1; shift
until grep -q "all done heldout" $O/queue.out; do sleep 60; done
[ "$TAG" != "a" ] && until grep -q "all done r857_a" $O/queue.out; do sleep 60; done
source <(sed -n '/^A=/,/^log()/p' $D/run.sh); source <(sed -n '/^spec()/,/^  esac; }/p;/^common()/p;/^ref()/,/^  log "done/p' $D/run.sh)
for cs in "$@"; do ref $cs 857; done
log "all done" r857_$TAG
