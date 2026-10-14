#!/bin/bash
# run.sh NAME CASE [VAR=value ...]: one run of CASE on libAG in the proper setting
# (one.sh defaults; long-drought records SHARE=0.1 SPLIT=1), output AG_out/runs/NAME.rds.
# Pass TIMES=... TOL=1e-4 for a schedule run, NODES=... for a uniform reference.
D=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev
nm=$1; cs=$2; shift 2
case $cs in
  episodic-lma) rec=episodic; extra="TRAIT_REL=lma=0.25"; w=episodic ;;
  dry-p50) rec=dry; extra="TRAIT_REL=root_P50=0.2"; w=dry ;;
  dry-flat) rec=dry-flat; extra=""; w=dry ;;
  wet-adG2) rec=long-wet; extra="TRAIT_REL=a_dG2=0.25"; w=long-wet ;;
  ld-102) rec=long-drought; extra="SEED=102"; w=long-drought ;;
  ld-105) rec=long-drought; extra="SEED=105"; w=long-drought ;;
  *) rec=$cs; extra=""; w=$cs ;;
esac
$D/schedtest/AG_out/one_ag.sh $nm $rec WEIGHT=$D/window/rule_A/weight_$w.rds \
  LIB=$D/schedtest/adjmap/libAG OUT=$D/schedtest/AG_out/runs/$nm.rds $extra "$@"
