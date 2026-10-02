#!/bin/bash
# One soil-chain-alone run: chain.sh NAME [VAR=value ...]; log to $P/chain/NAME.log.
W=/home/user/plant-dev/.claude/worktrees/agent-a905e7af8eecaffd3
D=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev
P=$D/pi
name=$1; shift
mkdir -p $P/chain
cd $W || exit 1
env PLANT_LIB=$D/lib_v12t "$@" nice -n 10 Rscript ${CHAIN_SCRIPT:-harness/soil_chain.R} > $P/chain/$name.log 2>&1
