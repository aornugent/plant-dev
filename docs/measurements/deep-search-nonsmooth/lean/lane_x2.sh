#!/bin/bash
# X2 (not pre-registered): at 1e-4 / 9.5e-5, the full stop and the stop before b = 25
# only, to see which restriction loses the nudge there. Four at once (coordinator's cap).
L=/home/user/plant-dev/docs/measurements/deep-search-nonsmooth/lean
T=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/libJTstopTmax
{ for t in 1e-4 9.5e-5; do echo "X2_stop_$t TOL=$t JT_STOP=1 JT_STOP_LOG=1"; done
  for t in 1e-4 9.5e-5; do echo "X2_t25_$t TOL=$t JT_STOP=1 JT_STOP_LOG=1 JT_STOP_TMAX=25 LIB=$T"; done; } |
  xargs -P 4 -L 1 $L/run.sh
