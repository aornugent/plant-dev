#!/bin/bash
# Run plant's testthat files concurrently, one R process per file.
#
# testthat's own parallel workers cannot see a pkgload::load_all()ed package, so
# the suite has to run with TESTTHAT_PARALLEL=false -- which makes a single
# test_dir() serial, and its wall time its CPU time. Fanning the files out across
# processes gets the concurrency back: load_all() costs about two seconds per
# process and the files are independent, so wall time becomes the slowest single
# file rather than the sum. Measured on sixteen cores, the gradient ladder is 17 s
# this way against about twenty minutes serial, and the 57 non-ladder files are
# 86 s against about six minutes.
#
#   scripts/run-tests.sh <pattern> [outdir] [invert]
#
# <pattern> is an extended regex over the file names, so it selects a ladder tier
# the same way testthat's own `filter` does. `invert` runs every file that does
# NOT match, which is how the non-ladder sweep is taken.
#
#   scripts/run-tests.sh '^test-gradient-ladder'          # the whole ladder
#   scripts/run-tests.sh 'gradient-ladder-(injection|rung3|factorisation)'
#   scripts/run-tests.sh '^test-gradient' "" invert       # everything else
#
# Set PLANT_TEST_LIB to a private library holding your odelia build, to keep a
# run out of the race with other sessions installing into the shared one.
#
# A crashed process writes no result line and is otherwise silent, which is the
# one thing this loses that test_dir() does not -- so they are reported at the
# end, and the exit status is non-zero if any file crashed or failed.
set -u

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
TESTS=$ROOT/plant/tests/testthat
PATTERN=${1:?usage: run-tests.sh <pattern> [outdir] [invert]}
OUT=${2:-}
INVERT=${3:-}

if [ -z "$OUT" ]; then
  OUT=$(mktemp -d)
  echo "logs: $OUT"
fi
mkdir -p "$OUT" || exit 1
rm -f "$OUT"/*.log

if [ ! -d "$TESTS" ]; then
  echo "no test directory at $TESTS" >&2
  exit 1
fi

ALL=$(ls "$TESTS" | grep -E '^test-.*\.[Rr]$')
if [ "$INVERT" = "invert" ]; then
  FILES=$(echo "$ALL" | grep -Ev "$PATTERN")
else
  FILES=$(echo "$ALL" | grep -E "$PATTERN")
fi
if [ -z "$FILES" ]; then
  echo "no test files match '$PATTERN'" >&2
  exit 1
fi
echo "files: $(echo "$FILES" | wc -l | tr -d ' ')"

# A private library goes ahead of the user library rather than replacing it:
# R_LIBS prepends, where R_LIBS_USER would hide Rcpp, BH, testthat and the rest.
LIBS=${PLANT_TEST_LIB:+$PLANT_TEST_LIB:}$(Rscript -e 'cat(paste(.libPaths(), collapse=":"))')

for f in $FILES; do
  (
    R_LIBS="$LIBS" TESTTHAT_PARALLEL=false \
    Rscript -e "
      setwd('$ROOT')
      library(odelia); pkgload::load_all('plant', quiet = TRUE)
      r <- testthat::test_file('$TESTS/$f', reporter = 'silent')
      d <- as.data.frame(r)
      cat(sprintf('RESULT $f pass=%d fail=%d error=%d skip=%d\n',
                  sum(d\$passed), sum(d\$failed), sum(d\$error), sum(d\$skipped)))
      # A silent reporter gives the count and not the reason, so a parallel run
      # said WHICH file failed and nothing about WHY. Each failure prints its own
      # message here, tagged so it survives being interleaved with every other
      # file's output.
      for (res in r) {
        for (x in res\$results) {
          if (inherits(x, 'expectation_failure') || inherits(x, 'expectation_error')) {
            cat(sprintf('WHY $f [%s] %s\n', res\$test,
                        gsub('\n', ' | ', conditionMessage(x))))
          }
        }
      }
    " > "$OUT/$f.log" 2>&1
  ) &
done
wait

if grep -qh "^WHY" "$OUT"/*.log 2>/dev/null; then
  echo "--- why ---"
  grep -h "^WHY" "$OUT"/*.log 2>/dev/null | sed 's/^WHY /  /' | sort
fi
echo "--- per file ---"
grep -h "^RESULT" "$OUT"/*.log 2>/dev/null | sort
echo "--- totals ---"
grep -h "^RESULT" "$OUT"/*.log 2>/dev/null \
  | sed 's/.*pass=\([0-9]*\) fail=\([0-9]*\) error=\([0-9]*\) skip=\([0-9]*\)/\1 \2 \3 \4/' \
  | awk '{p+=$1; f+=$2; e+=$3; s+=$4}
         END {printf "pass=%d fail=%d error=%d skip=%d\n", p, f, e, s
              if (f + e > 0) exit 1}'
status=$?

crashed=0
for l in "$OUT"/*.log; do
  if ! grep -q "^RESULT" "$l"; then
    if [ "$crashed" -eq 0 ]; then
      echo "--- produced no result line, so the process died: read these ---"
      crashed=1
    fi
    echo "  $l"
  fi
done

[ "$crashed" -eq 0 ] || exit 1
exit $status
