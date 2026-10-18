#!/bin/bash
SP=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad
LIBS=$SP/dev/schedtest/adjmap/libS; O=$SP/refine/s05/epi-adG208; E=$SP/epi
for R in C D E; do Rscript $E/mixed.R $LIBS $O level2 s05 2 $R l2m_$R; done
echo E2_DONE
