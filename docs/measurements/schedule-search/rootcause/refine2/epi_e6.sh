#!/bin/bash
SP=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad
LIBS=$SP/dev/schedtest/adjmap/libS; O=$SP/refine/s05/epi-adG208; E=$SP/epi
while ! grep -q E5_DONE $E/e5.log; do sleep 15; done
Rscript $E/zones.R $LIBS $O level2 2 end2 l2z_end2
echo E6_DONE
