#!/bin/bash
# bash rs.sh SCRIPT.R args...: an analysis script with the guard library on the path,
# from the worktree root.
export R_LIBS=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/lib_guard
cd /home/user/plant-dev/.claude/worktrees/agent-a2ac0b96ecd6256ba || exit 1
script="$1"; shift
exec Rscript "$script" "$@"
