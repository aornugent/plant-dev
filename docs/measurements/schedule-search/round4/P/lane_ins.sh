#!/bin/bash
# The inset pairs, c and f of one case side by side (two processes at a time).
P=/home/user/plant-dev/docs/measurements/schedule-search/round4/P
for cs in episodic-lma dry-flat dry dry-p50 episodic long-wet long-drought ld-102 ld-105 wet-adG2; do
  $P/run.sh insc $cs & $P/run.sh insf $cs & wait
  echo "pair $cs $(date +%T)"
done
echo "lane done"
