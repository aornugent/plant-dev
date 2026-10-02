#!/bin/bash
# Rscript moves.R on the given runs, with the guard library on the path.
export R_LIBS=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/lib_guard
cd /home/user/plant-dev/.claude/worktrees/agent-a2ac0b96ecd6256ba || exit 1
exec Rscript /tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/comb/scripts/moves.R "$@"
