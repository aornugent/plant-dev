#!/bin/bash
# Sample a stand gradient and resolve the profile, following the procedure in
# docs/leaf-rows-cost.md section 1. Read that first: this script automates the
# four guards it lists, but it cannot make a badly-scoped measurement useful.
#
#   scripts/profile-gradient.sh <r-script> [outdir]
#
# <r-script> runs the work to be measured; it is sourced by R with the profiler
# already attached, so everything it does is sampled. Keep it to one gradient of
# one fixture -- share = count x price, and a script doing two things gives
# neither.
#
# Set PLANT_TEST_LIB to a private library holding your odelia build.
#
# What the guards are for, since a broken one voids the measurement silently:
#
#   perf is unusable wherever kernel.perf_event_paranoid > 2, so this samples
#   with gperftools' libprofiler, which needs no privileges. It is LD_PRELOADed
#   onto the R BINARY, not the `R` wrapper script and not Rscript: via those the
#   first SIGPROF arrives during the exec chain and kills the process.
#
#   pkgload copies plant.so to a temp directory and unlinks it at exit, so a
#   profile outlives the binary it names and its addresses become unresolvable.
#   The .so is archived here BEFORE the run and the profile is resolved against
#   the archive.
#
#   OPENBLAS_NUM_THREADS=1, because the pthread build's pool spins in
#   sched_yield for a couple of per cent of a run that does no BLAS.
#
# Resolution is google-pprof, from the `google-perftools` package -- which the
# dev libs do not pull in, so install it explicitly.
set -u

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
SCRIPT=${1:?usage: profile-gradient.sh <r-script> [outdir]}
OUT=${2:-}

if [ ! -f "$SCRIPT" ]; then
  echo "no such R script: $SCRIPT" >&2
  exit 1
fi
if [ -z "$OUT" ]; then
  OUT=$(mktemp -d)
fi
mkdir -p "$OUT" || exit 1
echo "output: $OUT"

# An INSTALLED plant, by preference. pkgload::load_all maps its own copy and
# unlinks it while mapped, so the profile records the path with a "(deleted)"
# suffix and nothing can be substituted for it -- archiving the binary does not
# rescue that, because it is the map entry and not the file that is wrong.
SO=""
if [ -n "${PLANT_TEST_LIB:-}" ] && [ -f "$PLANT_TEST_LIB/plant/libs/plant.so" ]; then
  SO=$PLANT_TEST_LIB/plant/libs/plant.so
else
  SO=$(Rscript -e 'cat(system.file("libs", "plant.so", package = "plant"))' 2>/dev/null)
fi
if [ -z "$SO" ] || [ ! -f "$SO" ]; then
  echo "no installed plant.so found." >&2
  echo "Profiling needs plant INSTALLED, not load_all()ed:" >&2
  echo "  R_MAKEVARS_USER=<Makevars-O2> R CMD INSTALL -l \$PLANT_TEST_LIB plant" >&2
  exit 1
fi
echo "binary: $SO"

PRELOAD=$(ls /usr/lib/*/libprofiler.so 2>/dev/null | head -1)
if [ -z "$PRELOAD" ]; then
  echo "libprofiler.so not found; install libgoogle-perftools-dev" >&2
  exit 1
fi

# -g is what makes the profile readable and changes no codegen, so a build
# without it is a build whose samples resolve to nothing useful. Warn rather
# than refuse: the run still measures total time correctly.
if ! readelf -S "$SO" 2>/dev/null | grep -q debug_info; then
  echo "warning: $SO carries no debug info, so symbols will not resolve." >&2
  echo "         rebuild with CXX20FLAGS = -O2 -DNDEBUG -g" >&2
fi

ARCHIVE=$OUT/plant.so
cp "$SO" "$ARCHIVE"

PROFILE=$OUT/gradient.prof
LIBS=${PLANT_TEST_LIB:+$PLANT_TEST_LIB:}$(Rscript -e 'cat(paste(.libPaths(), collapse=":"))')

# exec/R rather than `R` or `Rscript`, per the note above. It needs R_HOME.
R_HOME=${R_HOME:-$(R RHOME)}
EXEC=$R_HOME/bin/exec/R
if [ ! -x "$EXEC" ]; then
  echo "no R binary at $EXEC" >&2
  exit 1
fi

# Warm whatever the script wants to set up, in a process with no profiler attached.
# A fixture that has to resolve something expensive before it can be measured --
# plant's schedule refinement re-runs the whole model many times -- would otherwise
# be sampled along with the work, and half the profile would be setup. The script
# is expected to honour PLANT_PROFILE_PREPARE by stopping once it has cached.
echo "preparing: $SCRIPT"
(
  cd "$ROOT" || exit 1
  R_HOME="${R_HOME:-$(R RHOME)}" R_LIBS="$LIBS" \
  OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 PLANT_PROFILE_PREPARE=1 \
    Rscript "$SCRIPT"
) 2>&1 | tee "$OUT/prepare.log"

echo "sampling: $SCRIPT"
(
  cd "$ROOT" || exit 1
  R_HOME="$R_HOME" R_LIBS="$LIBS" \
  OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 \
  TESTTHAT_PARALLEL=false \
  LD_PRELOAD="$PRELOAD" CPUPROFILE="$PROFILE" CPUPROFILE_FREQUENCY=250 \
    "$EXEC" --no-save --no-restore -q -f "$SCRIPT"
) 2>&1 | tee "$OUT/run.log"

if [ ! -s "$PROFILE" ]; then
  echo "no profile written at $PROFILE." >&2
  echo "A run that is killed rather than exiting cleanly writes no maps" >&2
  echo "trailer; snapshot /proc/<pid>/maps while it lives if you must kill it." >&2
  exit 1
fi

# Put the archived .so back where the run loaded it from. pkgload loads plant
# from a copy under its own temp directory and unlinks that at exit, and the
# profile's maps trailer names the copy -- so pprof looks for a file that no
# longer exists and every sample in plant reads as a bare hex address. Restoring
# the path is what makes archiving the binary worth doing.
RESTORED=$(python3 - "$PROFILE" "$ARCHIVE" <<'PY'
import shutil, sys, os, re
profile, archive = sys.argv[1], sys.argv[2]
blob = open(profile, "rb").read()
tail = blob[blob.rfind(b"\x00\x00\x00\x00\x00\x00\x00\x00"):].decode("utf-8", "replace")
done = []
for path in set(re.findall(r"(/\S*plant\.so)", tail)):
    if os.path.exists(path):
        continue
    try:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        shutil.copyfile(archive, path)
        done.append(path)
    except OSError as e:
        print(f"could not restore {path}: {e}", file=sys.stderr)
print(" ".join(done))
PY
)
if [ -n "$RESTORED" ]; then
  echo "restored for resolution: $RESTORED"
fi

echo
echo "=== flat profile ==="
google-pprof --text --lines "$ARCHIVE" "$PROFILE" 2>/dev/null \
  | head -45 | tee "$OUT/symbols.txt"
echo
echo "=== by function, callers folded in ==="
google-pprof --text "$ARCHIVE" "$PROFILE" 2>/dev/null \
  | head -30 | tee "$OUT/functions.txt"

echo
echo "profile:   $PROFILE"
echo "flat:      $OUT/symbols.txt"
echo "functions: $OUT/functions.txt"
echo "run log:   $OUT/run.log"
echo
echo "Read these as WHICH primitives are hot, never as how much each costs:"
echo "at -O2 an inlined callee has no frame and its samples land on its caller."
echo "Rank by count x price -- counts are in the run log, prices from an A/B."
