#!/bin/bash
# Q1: bounded Cash-Karp on the driver with the soil diagnostics, both records, one at a time.
P=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/pf_soil
bash $P/drv.sh q1_ld long-drought SOIL_DIAG=1 COUPLED_REF=10
bash $P/drv.sh q1_epi episodic SOIL_DIAG=1 COUPLED_REF=10
echo "q1 finished $(date +%T)" >> $P/queue.out
