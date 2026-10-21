#!/bin/bash
# Run the named climates in turn, each into roadtest-<climate>.{rds,log} in
# the current directory. PLANT_LIB names the plant library.
#   PLANT_LIB=<lib> ./queue.sh dry long-drought seasonal
here=$(dirname "$(readlink -f "$0")")
for c in "$@"; do
  nice -n 10 Rscript "$here/roadtest.R" "$c" "roadtest-$c.rds" > "roadtest-$c.log" 2>&1
done
