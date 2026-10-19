# odelia-58 notes: every number and where it came from

Measured 2026-10-19, under `nice -n 19`. No figure: the whole game's
four printed lines carry the result.

## The whole game

`figures/odelia-58/whole_game.cpp`: the `Chooser` System of
`tests/standalone/r_free.cpp` at 6c62da2 (its counters dropped) with a
`main` that prints. Built against the ODELIA-56 worktree
(`scratchpad/v2own/od_56`, 6c62da2):

```sh
clang++ -std=c++20 -O1 -w -I$O/inst/include -c $O/src/Tape.cpp -o Tape.o
clang++ -std=c++20 -O1 -w -I$O/inst/include whole_game.cpp Tape.o -o whole
./whole
```

Output, pasted in comment 1:

```
steps 24, stage values per step 6
y(1): reads 148.412862315  stores 122.4403839  steps alone 122.4403839
stage values at s = 0.5: run 0  reads 0  stores 12
dy(1)/dr: reads 148.41251 (difference 148.41251)  stores 117.7283 (difference 117.7283)
```

- 24 steps × 6 = 144 stage values per recording.
- `t = 0.92` where the pass at r = 5 crosses y = 100: ln(100)/5 = 0.921.
- Cost counts in comment 2 (n copies, n more with states kept) are read
  from `stepper_step`'s `with_row` (`ode_solver_internal.hpp` at
  6c62da2), not measured.

## Tests

`tests/standalone` at 6c62da2:

- `make CXX=clang++`: 303 `ok` lines, `all checks passed`; the test
  prints `seeded sweep 117.7283048, difference 117.7283049` under
  Cash–Karp and `120.4014911, 120.4014911` under Dormand–Prince
  (`scratchpad/v2own/checks/o56_standalone.log`).
- `make CXX=g++` (13.3.0): `all checks passed`
  (`scratchpad/v2own/checks/o56_standalone_gcc.log`).

The current PR comment says GCC 13 hits an internal compiler error "as
on master". On master the standalone check compiles under GCC 13; the
crash was #57's (`instruction` gaining a `std::optional` member) and
bfa32cf fixed it before this branch.

## Not carried over from the current PR text

- The plant table (invader `R0′` at lma ×0.9 and ×1.1, the two-invader
  refusal, the 1.2e-5 lma row) is plant's measurement; comment 1
  points at aornugent/plant#116 and does not repeat it.
- "Headers +32/−9": `git diff --numstat origin/ODELIA-55
  origin/ODELIA-56` gives +29/−9 (`ode_solver.hpp` +8 −2,
  `ode_solver_internal.hpp` +21 −7).
- "links this branch's head (`f49e357`)": the head is 6c62da2.

## Words

The parameter of `advance_recorded` is named `seed`, and the solver's
row `row_copy_` and the test `test_a_pass_on_copied_rows_stores_its_own_values`.
The prose names these as symbols only and calls the argument "the
second argument, true".
