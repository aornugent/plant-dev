#!/bin/bash
# Score every finished combination's ladder, self-referenced (L1 + (L1 - L2)/3 from the last two levels).
cd /tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/edges
for rec in episodic dry long-wet; do for tag in th0 lma125 p50; do
  SELF=1 Rscript ladder_self.R $rec m_${tag}_$rec,m_${tag}2_$rec,m_${tag}4_$rec 2>&1 | tail -7
done; done
