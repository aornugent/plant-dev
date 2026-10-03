#!/bin/bash
# Install odelia (state-weights a62e97c, exported), phylloptim (378b083, a copy
# of sw_phylloptim) and plant (pf-invader-subset) into the private library
# pf_thin/lib, in dependency order.
#   build.sh [odelia] [phylloptim] [plant]   (default: all three)
D=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev
P=$D/pf_thin
export R_LIBS=$P/lib MAKEFLAGS=-j2
mkdir -p "$P/lib" "$P/logs"
pkgs=${*:-odelia phylloptim plant}
for pkg in $pkgs; do
  case $pkg in
    odelia) src=$P/odelia; extra="" ;;
    phylloptim) src=$P/phylloptim; extra="--preclean" ;;
    plant) src=$P/plant; extra="--preclean" ;;
  esac
  while awk '{exit !($1 >= 4)}' /proc/loadavg; do sleep 30; done
  echo "start $pkg $(date +%T)" >> "$P/build.out"
  nice -n 10 R CMD INSTALL --no-docs $extra --library="$P/lib" "$src" > "$P/logs/install_$pkg.log" 2>&1
  status=$?
  echo "done $pkg status $status $(date +%T)" >> "$P/build.out"
  [ $status -eq 0 ] || exit $status
done
echo "build finished $(date +%T)" >> "$P/build.out"
