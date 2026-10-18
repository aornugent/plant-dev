#!/bin/bash
SP=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad
LIBS=$SP/dev/schedtest/adjmap/libS; O=$SP/refine/s05/epi-adG208; E=$SP/epi
for R in A B C D E F; do
  [ -f $E/runs/l1m_$R.rds ] && Rscript -e "q(status = is.null(readRDS('$E/runs/l1m_$R.rds')\$finished))" && continue
  Rscript $E/mixed.R $LIBS $O level1 s05 1 $R l1m_$R
done
echo E1_DONE
