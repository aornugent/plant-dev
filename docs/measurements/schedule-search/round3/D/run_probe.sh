#!/bin/bash
# run_probe.sh NAME SAVED_RUN [VAR=value ...]: probe.R pinned to SAVED_RUN, at that run's settings.
D=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev
A=$D/schedtest/adjmap; H=/home/user/plant-dev/docs/measurements/schedule-search/round3/D
name=$1; saved=$2; shift 2
O=$D/schedtest/D_out; mkdir -p $O
eval $(Rscript -e "x<-readRDS('$A/runs/$saved.rds'); e<-x\$setting\$env; cat(sprintf('TOL=%s ATOL=%s SPLIT=%s SHARE=\"%s\" LIB=%s TIMES_FILE=%s', x\$setting\$tol, x\$setting\$atol, e['SPLIT'], e['SHARE'], e['LIB'], 'x'))")
tf=$O/times_$saved.rds
Rscript -e "saveRDS(readRDS('$A/runs/$saved.rds')\$node_times, '$tf')"
env REGIME=long-drought TOL=$TOL ATOL=$ATOL WEIGHT_SOIL=10 WEIGHT=$D/window/rule_A/weight_long-drought.rds \
  WEIGHT_MAX=100 HMAX=15 SHARE="$SHARE" SPLIT=$SPLIT LIB=$LIB TIMES=$tf PIN=$A/runs/$saved.rds OUT=$O/$name.rds "$@" \
  Rscript $H/probe.R > $O/$name.log 2>&1
echo "done $name $?" >> $O/queue.out
