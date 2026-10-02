#!/bin/bash
# Run the next unfinished item of the extra list (the last tolerances' blocks,
# in the order the queue would reach them reversed), one run per call.
E=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/events
done_log() { grep -q " J [0-9]" "$E/runs/$1.log" 2>/dev/null; }
running() { pgrep -f "R --no-echo --no-restore --file=.*runs/snap/$1\.R" > /dev/null; }
items=()
for T in 1.015e-4 9.85e-5; do
  items+=("g $T" "spq $T")
  for trait in a_dG1 d_I a_dG2 lma; do for r in 1e-3 -1e-3; do items+=("fq $T $trait $r"); done; done
  for r in 1e-3 -1e-3; do items+=("rp $T a_dG1 $r"); done
done
# The 1.03e-4 block's ends only: the queue reaches its lma and control runs
# last, after six split points of its own.
items+=("g 1.03e-4" "spq 1.03e-4" "fq 1.03e-4 lma 1e-3" "fq 1.03e-4 lma -1e-3" "rp 1.03e-4 a_dG1 1e-3" "rp 1.03e-4 a_dG1 -1e-3")
for it in "${items[@]}"; do
  set -- $it
  case $1 in g) tag=g_$2 ;; spq) tag=spq_$2 ;; *) tag=$1_$2_$3_$4 ;; esac
  if done_log $tag || running $tag; then continue; fi
  exec bash $E/exr.sh $it
done
echo "extra list done"
