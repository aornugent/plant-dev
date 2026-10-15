#!/bin/bash
# X3 (not pre-registered): the reference's own nudge (stopped 2.85e-5) and unstopped
# 1e-4's nudge (9.5e-5).
L=/home/user/plant-dev/docs/measurements/deep-search-nonsmooth/lean
printf '%s\n' "X3_ref_2.85e-5_stop TOL=2.85e-5 JT_STOP=1 JT_STOP_LOG=1" "X3_9.5e-5_none TOL=9.5e-5" | xargs -P 2 -L 1 $L/run.sh
