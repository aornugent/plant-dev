#!/bin/sh
cd "$(dirname "$0")"
TOL=1e-4 METHODS=dense2 Rscript exp1b.R > exp1_dense2_1e-4.log 2>&1
METHODS=dense2,split Rscript exp3.R > exp3b.log 2>&1
METHOD=dense2 TOL=1e-4 Rscript exp2.R >> exp2.log 2>&1
echo done >> exp3b.log
