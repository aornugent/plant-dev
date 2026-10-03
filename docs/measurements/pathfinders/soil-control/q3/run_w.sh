#!/bin/bash
# mrw forwards, each started once fewer than four heavy R processes run.
M=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/pf_soil/mr
for job in "mrw_ld long-drought" "mrw_epi episodic"; do
  while [ "$(pgrep -fc 'harness[_a-z]*/(run_record|ark_prototype)[.]R')" -ge 4 ]; do sleep 20; done
  bash $M/drv_w.sh $job MR_SHARE=0.1 MR_COUPLE=member
done
