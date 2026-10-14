#!/bin/bash
# run.sh VARIANT CASE [VAR=value ...]: one a09-setting committed run of a P_out schedule on lib19.
D=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev
v=$1; cs=$2; shift 2
case $cs in
  episodic-lma) rec=episodic; extra="TRAIT_REL=lma=0.25"; w=episodic ;;
  dry-p50) rec=dry; extra="TRAIT_REL=root_P50=0.2"; w=dry ;;
  dry-flat) rec=dry-flat; extra=""; w=dry ;;
  wet-adG2) rec=long-wet; extra="TRAIT_REL=a_dG2=0.25"; w=long-wet ;;
  ld-102) rec=long-drought; extra="SEED=102"; w=long-drought ;;
  ld-105) rec=long-drought; extra="SEED=105"; w=long-drought ;;
  *) rec=$cs; extra=""; w=$cs ;;
esac
$D/schedtest/adjmap/one.sh P_${v}_${cs} $rec TIMES=$D/schedtest/P_out/sched/${v}_${cs}.rds WEIGHT=$D/window/rule_A/weight_$w.rds \
  TOL=1e-4 LIB=$D/schedtest/adjmap/lib19 OUT=$D/schedtest/P_out/runs/P_${v}_${cs}.rds $extra "$@"
