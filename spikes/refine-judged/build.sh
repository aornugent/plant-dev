#!/bin/bash
# Build odelia -> phylloptim -> plant (ODELIA-66 stack) into the private library.
set -e
W=/home/a/dev/plant-dev/.claude/worktrees/agent-a54dfbccfb0b3fb3b
LIB=/home/a/.claude/jobs/9d586e52/rlib-refine
LOG=/home/a/.claude/jobs/9d586e52/tmp/refine
export R_LIBS=$LIB MAKEFLAGS=-j5
for s in ${@:-odelia phylloptim plant}; do
  R CMD INSTALL --preclean --library=$LIB $W/$s > $LOG/build-$s.log 2>&1 || { echo FAIL $s; tail -30 $LOG/build-$s.log; exit 1; }
  echo ok $s
done
