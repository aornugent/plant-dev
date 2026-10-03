#!/bin/bash
# Every number of the combined-gains report:  bash report.sh  (writes report.log)
C=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/phase1c/combined
cd $C || exit 1
{
  echo "######## lib_sw with no weights against lib_guard's episodic run"; Rscript check_sw.R
  echo; echo "######## lib_sw at 1e-5 against the assessment's long drought reference"; Rscript check_ld_ref.R
  echo; echo "######## The long-wet rerun against the run the restart killed"; Rscript check_rerun.R
  echo; echo "######## The combined setting against plant's own unweighted runs"; Rscript combined_table.R
  echo; echo "######## Every gradient refusal"; Rscript refusals.R
  echo; echo "######## The episodic probes: which part refuses"; Rscript probe_table.R
  echo; echo "######## lib_sw's soil x10 and rule-A-capped runs against the driver's programs"
  Rscript check_soil10.R; Rscript cap_semantics.R
} > report.log 2>&1
cat report.log
