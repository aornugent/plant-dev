#!/bin/bash
# run_inv.sh: invaders at lma x0.5, x2 and theta' = theta on dry's E6 committed grid (the
# committed setting, the stand forward only), then their references at u215 and u429 (the
# dry reference's command, invaders added), one R process at a time.
A=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/adjmap
DEV=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev
MV=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/moved
D=/home/user/plant-dev/docs/measurements/schedule-search/rootcause/moved
H=/home/user/plant-dev
gate() { while [ "$(pgrep -c -f 'R --|Rscript|exec/R')" -gt 3 ]; do sleep 30; done; }
log() { echo "$1 $2 $(date +%T) $(df -h / | awk 'NR==2{print $4}') free" >> $MV/queue_inv.out; }
name=inv_dry_grid
if [ ! -s $MV/runs/$name.rds ]; then gate; log start $name
  env REGIME=dry ATOL=1e-4 WEIGHT_SOIL=10 WEIGHT_MAX=100 HMAX=15 SHARE=0.1 SPLIT=1 \
    WEIGHT=$DEV/window/rule_A/weight_dry.rds TOL=1e-4 LIB=$A/libS KNOTS=0 FORWARD=1 \
    INVADERS_REL="lma=0,lma=-0.5,lma=1" INVADER_GRADIENTS=1 \
    TIMES=$MV/sched/grid_dry.rds OUT=$MV/runs/$name.rds \
    Rscript $D/adj_run_inv.R > $MV/logs/$name.log 2>&1
  log "done $?" $name; fi
for n in 215 429; do name=inv_dry_u$n
  [ -s $MV/runs/$name.rds ] && grep -q "failures;" $MV/logs/$name.log && continue
  gate; log start $name
  (cd $H && env PLANT_LIB=$DEV/lib_109 REGIME=dry TOL=3e-5 ATOL=1e-4 WEIGHT_SOIL=10 \
    WEIGHT=$DEV/window/rule_A/weight_dry.rds WEIGHT_MAX=100 HMAX=15 SHARE=0.1 SPLIT=1 \
    NODES=$n INVADERS_REL="lma=-0.5,lma=1" INVADER_GRADIENTS=1 STAND_GRADIENT=0 \
    OUT=$MV/runs/$name.rds Rscript harness/run_record.R > $MV/logs/$name.log 2>&1)
  log "done $?" $name
done
log "all done" inv
