#!/bin/sh
cd "$(dirname "$0")"
Rscript local_slope.R > local_slope.log 2>&1
TOL=1e-4 METHODS=slope Rscript exp1b.R > exp1_slope_1e-4.log 2>&1
METHODS=slope Rscript exp3.R > exp3c.log 2>&1
METHOD=slope TOL=1e-4 Rscript exp2.R >> exp2.log 2>&1
echo done >> exp3c.log
