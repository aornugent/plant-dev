#!/bin/bash
# Every number of the combined-gains reports:  bash report.sh
#   report.log          the combined setting as first run (refused gradients);
#   report_bounded.log  the combined setting with each state's weight at most 100;
#   report_ark.log      the implicit soil chain (lib_ark), arms A and B.
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
{
  echo "######## The rebuilt lib_sw with WEIGHT_MAX unset against lib_guard's episodic run"
  if [ -s full/chk_epi_forward_rebuilt.rds ]; then Rscript check_sw.R full/chk_epi_forward_rebuilt.rds; else echo "not run"; fi
  echo; echo "######## The episodic probes with the soil clamp tallies (the coordinator's grad_probe.R runs)"
  cat full/probe_epi_ruleA_h15_clamps.log full/probe_epi_soil10_ruleA_h15.log full/probe_epi_soil10_ruleA_h15_max100.log
  echo; echo "######## The bounded setting against plant's own unweighted runs and rule A with the 15-day cap"
  Rscript bounded_table.R
} > report_bounded.log 2>&1
{
  echo "######## lib_ark's arkc on long drought, forward and uncapped, against the driver's arkc"; Rscript check_arkc.R
  echo; echo "######## The implicit soil chain: arm A (arkc, 15 d) and arm B (A + rule A, each weight at most 100)"
  Rscript ark_table.R
  echo; echo "######## Every walk of the bounded and ARK runs: J', or RAISED"; Rscript walks_compact.R
  echo; echo "######## Where each arm stopped, if it did"; grep -E "stop arm|queue7 lane" queue.out || echo "neither arm stopped"
} > report_ark.log 2>&1
cat report_bounded.log report_ark.log
