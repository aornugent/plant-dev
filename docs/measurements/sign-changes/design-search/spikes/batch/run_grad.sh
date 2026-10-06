#!/bin/bash
# Plain reverse-mode gradients (lib_rr, SPLIT=0) on each program in runs/: the
# nudge spread with and without the crossing steps cut into m. ARMS lists
# "m tol [split]" lines; the harness runs from the plant-dev root (read only).
set -u
DEV=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev
H=/home/user/plant-dev/harness
R=$(cd "$(dirname "$0")" && pwd)/runs
one() {  # m tol [split] [forward lma_rel]
  local tag="g_m$1_$2"
  [ "${3:-0}" = 1 ] && tag="${tag}_split"
  [ -n "${5:-}" ] && tag="f_m$1_$2_lma$5"
  [ -f "$R/$tag.rds" ] && return 0
  (cd /home/user/plant-dev && env PLANT_LIB=$DEV/lib_rr PROGRAM="$R/prog_m$1_$2.rds" SPLIT="${3:-0}" \
    STAND_ONLY=1 FORWARD="${4:-0}" LMA_REL="${5:-0}" ATOL=1e-4 NODES=108 TOL="$2" OUT="$R/$tag.rds" \
    Rscript "$H/run_record.R" > "$R/$tag.log" 2>&1)
}
export -f one; export DEV H R
xargs -P "${PAR:-3}" -L 1 bash -c 'one "$@"' _ < "${ARMS:-/dev/stdin}"
echo "JOB DONE run_grad $(date +%T)"
