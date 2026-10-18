#!/bin/bash
# Sample prof.R (the loop's three runs on one case) with gperftools at 250 Hz.
#   bash prof.sh CASE LIB OUTDIR
D=/home/user/plant-dev/docs/measurements/schedule-search/rootcause/refine2/perf
C=$1; LIB=$2; OUT=$3; mkdir -p $OUT
cp $LIB/plant/libs/plant.so $OUT/plant.so
R_HOME=$(R RHOME)
env R_HOME=$R_HOME PLANT_LIB=$LIB CASE=$C OUT=$OUT/times.rds OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 \
  LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libprofiler.so CPUPROFILE=$OUT/run.prof CPUPROFILE_FREQUENCY=250 \
  $R_HOME/bin/exec/R --no-save --no-restore -q -f $D/prof.R > $OUT/run.log 2>&1
google-pprof --text --cum $OUT/plant.so $OUT/run.prof > $OUT/cum.txt 2>/dev/null
google-pprof --text $OUT/plant.so $OUT/run.prof > $OUT/flat.txt 2>/dev/null
echo "exit $?" >> $OUT/run.log
