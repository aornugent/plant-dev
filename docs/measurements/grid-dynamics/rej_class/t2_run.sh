#!/bin/bash
# One driver run of pics_3e-5's command line on the probe build, from this
# session's worktree (harness/ark_prototype.R with t2_driver.patch applied):
#   bash DEV/rej_class/t2_run.sh NAME [VAR=value ...]
# Outputs: runs/NAME.rds (OUT), runs/att_NAME.rds (ATTEMPT_LOG),
# runs/side_NAME.rds (CLASS_SIDE), logs/NAME.log.
W=/home/user/plant-dev/.claude/worktrees/agent-a4dae3c2572021890
D=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev
R=$D/rej_class
name=$1; shift
mkdir -p $R/runs $R/logs
for f in $R/runs/$name.rds $R/runs/att_$name.rds $R/runs/side_$name.rds $R/logs/$name.log; do
  if [ -e "$f" ]; then echo "refusing to overwrite $f"; exit 1; fi
done
cd $W || exit 1
echo "start $(date +%T) $name $*" >> $R/runs.out
env PLANT_LIB=$D/lib_probe CONTROL=pi \
  CHAIN_SEED=$W/docs/measurements/grid-dynamics/soil_chain_ld_theta.rds \
  TOL=3e-5 ATOL=1e-4 \
  ATTEMPT_LOG=$R/runs/att_$name.rds OUT=$R/runs/$name.rds CLASS_SIDE=$R/runs/side_$name.rds \
  "$@" nice -n 10 Rscript harness/ark_prototype.R > $R/logs/$name.log 2>&1
status=$?
echo "done $(date +%T) $name status $status" >> $R/runs.out
exit $status
