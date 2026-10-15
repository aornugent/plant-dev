#!/bin/bash
# L1: the stopped reference (3e-5), stopped 1e-3 and its nudge 9.5e-4, unstopped 1e-4
# (JT_STOP unset: no detection), at most three at once.
L=/home/user/plant-dev/docs/measurements/deep-search-nonsmooth/lean
printf '%s\n' \
  "L1_ref_3e-5_stop TOL=3e-5 JT_STOP=1 JT_STOP_LOG=1" \
  "L1_1e-3_stop TOL=1e-3 JT_STOP=1 JT_STOP_LOG=1" \
  "L1_1e-4_none TOL=1e-4" \
  "L1_9.5e-4_stop TOL=9.5e-4 JT_STOP=1 JT_STOP_LOG=1" |
  xargs -P 3 -L 1 $L/run.sh
