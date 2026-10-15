#!/bin/bash
# L2 and L3 after L1's runs, at most three R processes machine-wide (gate.sh).
# L2: the nudge pair 3e-4 / 2.85e-4 with the stop on steps over 0.25 d, before b = 25
# only (scratch build libJTstopTmax), and both. L3: A and B pinned with step ends at the
# top-k clusters' first and last roots (l3_pins.R).
L=/home/user/plant-dev/docs/measurements/deep-search-nonsmooth/lean
S=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest
O=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/lean
T=$S/libJTstopTmax; H=JT_STOP_HMIN=0.000684932
while ! grep -q "start L1_9.5e-4_stop" $O/queue.out; do sleep 10; done
( [ -e $T/plant ] || $L/gate.sh $L/build_tmax.sh > $O/build_tmax.out 2>&1; touch $O/built ) &
{
  for t in 3e-4 2.85e-4; do echo "L2_h025_$t TOL=$t JT_STOP=1 JT_STOP_LOG=1 $H"; done
  for c in b10 b30 l30 b50; do
    echo "L3_${c}_A TOL=3e-4 PIN=$O/pin_L3_${c}_A.rds"
    echo "L3_${c}_B TOL=2.85e-4 PIN=$O/pin_L3_${c}_B.rds"
  done
  for t in 3e-4 2.85e-4; do echo "W L2_t25_$t TOL=$t JT_STOP=1 JT_STOP_LOG=1 JT_STOP_TMAX=25 LIB=$T"; done
  for t in 3e-4 2.85e-4; do echo "W L2_both_$t TOL=$t JT_STOP=1 JT_STOP_LOG=1 JT_STOP_TMAX=25 $H LIB=$T"; done
} | xargs -P 3 -L 1 bash -c 'if [ "$0" = W ]; then while [ ! -e '$O'/built ]; do sleep 10; done; set -- "$@"; exec '$L'/gate.sh '$L'/run.sh "$@"; else exec '$L'/gate.sh '$L'/run.sh "$0" "$@"; fi'
wait
