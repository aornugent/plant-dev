#!/bin/bash
# The inset pairs at tolerance 3e-4, c and f side by side.
P=/home/user/plant-dev/docs/measurements/schedule-search/round4/P
for cs in dry-flat ld-102 dry dry-p50 episodic-lma episodic long-wet long-drought ld-105 wet-adG2; do
  $P/run.sh ins3c $cs TOL=3e-4 & $P/run.sh ins3f $cs TOL=3e-4 & wait
  echo "pair $cs $(date +%T)"
done
echo "lane done"
