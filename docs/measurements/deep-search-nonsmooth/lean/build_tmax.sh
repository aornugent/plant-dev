#!/bin/sh
# libJTstopTmax: libJTstop (its odelia and phylloptim copied, plant from the same source)
# plus JT_STOP_TMAX (yr): a step starting after it is never cut.
set -e
S=/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest
N=$S/libJTstopTmax; SRC=$S/JT_src/plant_stop_tmax
test ! -e $N
mkdir -p $N $S/JT_src/tmp
cp -a $S/libJTstop/odelia $S/libJTstop/phylloptim $N/
H=$N/odelia/include/odelia/ode_solver_internal.hpp
python3 - "$H" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
a = '''          static const double stop_hmin = hmin_env ? std::atof(hmin_env) : 0.0;
'''
b = a + '''          static const char* const tmax_env = std::getenv("JT_STOP_TMAX");
          static const double stop_tmax = tmax_env ? std::atof(tmax_env) : HUGE_VAL;
'''
c = '''              step_size > stop_hmin) {'''
d = '''              step_size > stop_hmin && time_orig <= stop_tmax) {'''
assert s.count(a) == 1 and s.count(c) == 1
open(p, 'w').write(s.replace(a, b).replace(c, d))
PY
rm -rf $SRC; cp -a $S/JT_src/plant_stop $SRC
rm -f $SRC/src/*.o $SRC/src/*.so
TMPDIR=$S/JT_src/tmp R_MAKEVARS_USER=$S/JT_src/Makevars.nodebug R_LIBS=$N MAKEFLAGS=-j2 R CMD INSTALL --library=$N $SRC > $N.build.log 2>&1
echo built
