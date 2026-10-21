#!/bin/bash
set -u
S=/tmp/claude-0/-home-user-plant-dev/77e342d7-638e-5fbe-b300-9d8d967ef31a/scratchpad
P=$S/wt/spike; O=$S/wt/odelia-sweep
build_plant() { cd $P && rm -f src/*.o src/*.so && R_LIBS=$1 MAKEFLAGS=-j4 R CMD INSTALL -l $1 . > $1.plant.log 2>&1; tail -1 $1.plant.log; }
build_odelia() { cd $O && rm -f src/*.o src/*.so && R CMD INSTALL --no-test-load -l $1 . > $1.odelia.log 2>&1; tail -1 $1.odelia.log; }
# plant-only variants on F2's odelia
for v in crown excl; do
  L=$S/libX_$v; rm -rf $L; mkdir -p $L; cp -r $S/libF2/odelia $L/
  cd $P
  case $v in
    crown) sed -i '1188s/if (assimilation_deep_crown_rows(/if (false \&\& assimilation_deep_crown_rows(/' inst/include/plant/models/ff16_strategy.h ;;
    excl)  sed -i '1478s/double read_below = 0.0;/double read_below = std::numeric_limits<double>::infinity();/' inst/include/plant/patch.h ;;
  esac
  git diff --stat | tail -1
  build_plant $L
  cd $P && git checkout -q inst/include/plant/models/ff16_strategy.h inst/include/plant/patch.h
done
# odelia variants
for v in reseat basis reduced; do
  L=$S/libX_$v; rm -rf $L; mkdir -p $L
  cd $O
  case $v in
    reseat)  sed -i '345s/if constexpr (requires(system_type\& a) { a.assign_from(passive); }) {/if constexpr (false) {/' inst/include/odelia/adjoint.hpp ;;
    basis)   sed -i '469s/if (basis.carries_every_row() || basis.kept.empty()) {/if (true) {/' inst/include/odelia/ode_solver.hpp ;;
    reduced) sed -i '56s|^#define XAD_REDUCED_MEMORY|// #define XAD_REDUCED_MEMORY|' inst/include/XAD/Config.hpp ;;
  esac
  git diff --stat | tail -1
  build_odelia $L; build_plant $L
  cd $O && git checkout -q inst/include/odelia/adjoint.hpp inst/include/odelia/ode_solver.hpp inst/include/XAD/Config.hpp
done
cd $P && git status --short; cd $O && git status --short
echo BUILDS-DONE
