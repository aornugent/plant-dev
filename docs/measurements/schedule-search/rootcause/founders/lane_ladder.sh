#!/bin/bash
# lane_ladder.sh A|B: the Simpson ladder's runs, one lane at a time (run.sh, P=1).
# A: the trapezium ladder on libF with the variable unset (the S0 guard showed libF and
# libS differ, so both arms run on libF). B: the guard (libF, variable unset, forward), then
# Simpson on libF with PLANT_SIMPSON_UNTIL at each case's bF.
FD=/home/user/plant-dev/docs/measurements/schedule-search/rootcause/founders
SC=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/founders/build
export P=1
if [ "$1" = A ]; then
  for f in 12 6 24 48; do EXTRA="LIB=$SC/libF" $FD/run.sh ladT$f dry episodic-lma; done
else
  EXTRA="LIB=$SC/libF FORWARD=1" $FD/run.sh ladG12 dry
  for f in 12 6 24; do
    EXTRA="LIB=$SC/libF PLANT_SIMPSON_UNTIL=3.4958177877" $FD/run.sh ladS$f dry
    EXTRA="LIB=$SC/libF PLANT_SIMPSON_UNTIL=3.6561814130" $FD/run.sh ladS$f episodic-lma
  done
fi
