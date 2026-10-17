#!/bin/bash
# gate.sh CMD...: start CMD only when the machine shows 3 or fewer R processes (the shared
# gate's pgrep, not counting shells whose command line merely names R).
nr() { local n=0; for p in $(pgrep -f "R --|Rscript|exec/R"); do c=$(ps -o comm= -p $p 2>/dev/null); case "$c" in R|Rscript) true ;; *) false ;; esac && n=$((n + 1)); done; echo $n; }
mine() { echo $(( $(grep -c '^start' $1/queue.out 2>/dev/null) - $(grep -c '^done' $1/queue.out 2>/dev/null) )); }
U=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/u
while [ $(nr) -ge 4 ] || [ $(mine $U) -ge 2 ]; do sleep $((5 + RANDOM % 10)); done
exec "$@"
