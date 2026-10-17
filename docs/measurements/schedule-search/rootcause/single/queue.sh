#!/bin/bash
# queue.sh JOBFILE SLOTS: run each line of JOBFILE (arguments to run.sh) with at most SLOTS of
# this study's R processes at once, and never more than 4 R/compile processes on the machine.
H=/home/user/plant-dev/docs/measurements/schedule-search/rootcause/single
slots=${2:-2}
while read -r line; do
  [ -z "$line" ] && continue
  while true; do
    mine=$(pgrep -f "adj_run_single.R" | wc -l); all=$(pgrep -f "exec/R|cc1plus" | wc -l)
    [ "$mine" -lt "$slots" ] && [ "$all" -lt 4 ] && break
    sleep 15
  done
  eval "$H/run.sh $line" &
  sleep 20
done < "$1"
wait
