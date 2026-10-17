#!/bin/bash
# run857p.sh: third reference rungs in parallel lanes (machine free); each argument is a
# lane of space-separated cases run in turn. Usage: bash run857p.sh "a b" "c"
D=/home/user/plant-dev/docs/measurements/schedule-search/rootcause/heldout
source <(sed -n '/^A=/,/^log()/p' $D/run.sh); source <(sed -n '/^spec()/,/^  esac; }/p;/^common()/p;/^ref()/,/^  log "done/p' $D/run.sh)
gate() { :; }
for lane in "$@"; do ( for cs in $lane; do ref $cs 857; done ) & done; wait
log "all done" r857_p
