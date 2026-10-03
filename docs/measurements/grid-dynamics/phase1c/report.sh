#!/bin/bash
# Every number of the phase-1c report, from the runs in this directory:
#   bash report.sh   (writes report.log)
P=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/phase1c
cd $P || exit 1
{
  echo "######## P0: HMAX unset against the window phase's episodic rule-A run"; Rscript check_p0.R
  echo; echo "######## The driver's runs (rows, forward, savings, longest step, J)"; Rscript drv_table.R
  echo; echo "######## Every invader walk on every program"; Rscript walk_table.R
  echo; echo "######## Where the raises sit, and episodic's steps there"; Rscript raise_step.R; Rscript near_failure.R
  echo; echo "######## Both pairs on the pool's test equation"; Rscript test_equation.R
  echo; echo "######## Quantities in eps, and every walk with its J' move"; Rscript quantities.R
  echo; echo "######## Against each record's tolerance nudge (post hoc)"; Rscript compare_nudge.R
  echo; echo "######## Episodic against plant's run at 1e-5 (post hoc)"
  if [ -s full/epi_1e-5.rds ]; then Rscript ref_1e-5.R; else echo "not run"; fi
  echo; echo "######## Long drought against the assessment's run at 1e-5 (post hoc)"; Rscript ref_ld_1e-5.R
} > report.log 2>&1
cat report.log
