#!/bin/sh
cd "$(dirname "$0")"
for m in endpoint plain bracket; do
  METHOD=$m TOL=1e-4 Rscript exp2.R >> exp2.log 2>&1
done
METHODS=plain,endpoint,bracket Rscript exp3.R > exp3.log 2>&1
echo done >> exp3.log
