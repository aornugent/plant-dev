#!/bin/bash
SP=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad
LIBS=$SP/dev/schedtest/adjmap/libS; O=$SP/refine/s05/epi-adG208; E=$SP/epi
Rscript $E/zones.R $LIBS $O level1 1 short l1z_short
Rscript $E/zones.R $LIBS $O level2 2 short l2z_short
echo E4_DONE
