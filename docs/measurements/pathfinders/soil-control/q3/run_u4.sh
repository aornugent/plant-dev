#!/bin/bash
# bnd's d_I pair at r = 1e-4, each started once fewer than four heavy R processes run.
M=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/pf_soil/mr
P=$(dirname $(dirname $M))/pf_soil/runs/q1_ld.rds
for s in p m; do
  r=$([ $s = p ] && echo 1e-4 || echo -1e-4)
  while [ "$(pgrep -fc 'harness[_a-z]*/(run_record|ark_prototype)[.]R')" -ge 4 ]; do sleep 20; done
  bash $M/drv.sh el_ld_bnd_d_I_u4_$s long-drought PROGRAM=$P THETA=d_I THETA_REL=$r THETA_AFTER=1
done
