#!/bin/bash
# The rebuilt split's profiles (rebuilt_profile.txt): long drought's pinned split
# program at 1e-4, sampled by gperftools, then each profile's samples under the
# split's frames.
#   LIB=... PROGRAM=program_split.rds DIR=... bash rebuilt_profile.sh run|read
# A profile is read with the LIB it was run on.
set -u
: "${LIB:?}" "${PROGRAM:?}" "${DIR:?}"
cd "$(dirname "$0")/../../.."
profile() {  # name, then environment assignments
  local name=$1; shift
  env PLANT_LIB="$LIB" PLANT_TEST_LIB="$LIB" ATOL=1e-4 NODES=108 TOL=1e-4 SPLIT=1 \
    PROGRAM="$PROGRAM" "$@" bash scripts/profile-gradient.sh harness/profile_forward.R \
    "$DIR/$name" > "$DIR/$name.out" 2>&1
}
samples() {  # name, focus: the samples whose stacks the focus matches
  google-pprof --text --cum ${3:-} --focus="$2" "$DIR/$1/plant.so" "$DIR/$1/gradient.prof" \
    2>/dev/null
}
count() { samples "$@" | awk 'NR == 2 {print $4}'; }
case "${1:-}" in
  run)
    profile forward FORWARD=1
    profile gradient STAND_ONLY=1
    profile walk STAND_GRADIENT=0
    ;;
  read)
    for name in forward gradient walk; do
      [ -f "$DIR/$name/gradient.prof" ] || continue
      echo "== $name: $(samples "$name" . | sed -n 1p)"
      for f in 'SolverInternal.*::split\b' 'Step::integrate_pieces' \
        'taken_step::sign_changes' 'Solver::solve_adjoint' 'split_as_recorded' \
        'run_mutant' 'SolverInternal::take_recorded_splits' 'Patch::take_recorded_splits'; do
        printf "  %-40s %s\n" "$f" "$(count "$name" "$f")"
      done
      # The end evaluated again: odelia::ode::derivs under the split's frame.
      printf "  %-40s %s\n" "derivs under the split" "$(samples "$name" \
        'SolverInternal.*::split\b' | awk '$6 == "odelia::ode::derivs" {print $4; exit}')"
      # The sweep's evaluation at the end before the split, taped: the samples on
      # its line of LIB's ode_step.hpp, which must be the profiled build's.
      line=$(grep -n 'solved.at_state_before_split);' "$LIB/odelia/include/odelia/ode_step.hpp" \
        | cut -d: -f1)
      printf "  %-40s %s\n" "the end before the split, taped" "$(samples "$name" \
        'Step::step_adjoint' --lines | grep -E "step_adjoint::\{lambda#1\}::operator .*ode_step.hpp:$line\b" \
        | awk '{print $4; exit}')"
    done
    ;;
esac
