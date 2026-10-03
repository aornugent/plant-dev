#!/bin/bash
# Drive sp_cg.R under callgrind: instrumentation on at READY, dump and off at
# SWEEPEND. cg/cg_<tag>.out.<pid>.1 then holds the sweep alone.
#   bash sp_cg.sh <tag> <lib> <spread|-> [T]
SPD=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/sweep_profile
CGD=$SPD/cg
TAG=$1; LIB=$2; SPREAD=$3; T=${4:-5}
LOG=$SPD/logs/cg_${TAG}.log
CTL=$CGD/${TAG}.ctl
rm -f $CGD/${TAG}_go $CGD/${TAG}_stop
cd $CGD
echo "start $(date -u +%FT%TZ) tag=$TAG lib=$LIB spread=$SPREAD T=$T load $(cat /proc/loadavg)" > $CTL
if [ "$SPREAD" = "-" ]; then
  export PLANT_LIB=$LIB
else
  export PLANT_LIB=$LIB PLANT_PROBE_SPREAD=$SPREAD
fi
export T PROF_TAG=$TAG
nice -n 10 R -d "valgrind --tool=callgrind --instr-atstart=no --callgrind-out-file=$CGD/cg_${TAG}.out.%p" --vanilla --no-echo -f $SPD/sp_cg.R > $LOG 2>&1 &
RPID=$!
until grep -q READY $LOG 2>/dev/null || ! kill -0 $RPID 2>/dev/null; do sleep 1; done
VPID=$(grep -o '^pid [0-9]*' $LOG | awk '{print $2}')
echo "valgrind pid $VPID" >> $CTL
date +%s > $CGD/${TAG}.t_on
callgrind_control -i on $VPID >> $CTL 2>&1
touch $CGD/${TAG}_go
until grep -q SWEEPEND $LOG 2>/dev/null || ! kill -0 $RPID 2>/dev/null; do sleep 2; done
date +%s > $CGD/${TAG}.t_off
callgrind_control -d $VPID >> $CTL 2>&1
callgrind_control -i off $VPID >> $CTL 2>&1
touch $CGD/${TAG}_stop
wait $RPID
echo "CGDRIVER EXIT $? $(date -u +%FT%TZ)" >> $LOG
echo "end $(date -u +%FT%TZ) load $(cat /proc/loadavg)" >> $CTL
