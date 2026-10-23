#!/bin/bash
# Installs the instrumented plant (a1e6c061 + leaf_probe.patch) into the
# private library; odelia 0.9.0 and phylloptim 0.11.0 are copied in from
# rlib-refine (their installed headers match 8b7b934 and ef75769).
set -e
LIB=/home/a/.claude/jobs/9d586e52/rlib-leaf
SRC=/home/a/dev/plant-dev/.claude/worktrees/agent-a9f1c333a8d4c65ef/plant
export MAKEFLAGS=-j4
# Makevars tracks no header dependencies: a header edit needs a clean build.
rm -f "$SRC"/src/*.o "$SRC"/src/*.so
export R_LIBS=$LIB
R CMD INSTALL --no-test-load -l "$LIB" "$SRC"
