# The storage pool fails its own invariants

`test-strategy-tf24.R` runs on `develop` and on this branch. The file's four
storage blocks are byte-identical between the two, checked by md5 of each
block's source. One side passes them.

| tree | plant | odelia | phylloptim | result |
|---|---|---|---|---|
| `develop` | `32151e87` | 0.3.1 | 0.8.0 | **75 pass, 0 fail, 0 skip** |
| `ad/V4-reverse-tf24` | `327b2bd3` | 0.5.0 | 0.9.0 | **65 pass, 15 fail, 0 skip** |

Both built by `R CMD INSTALL` at `-O2 -g0 -DNDEBUG` into private libraries in
one sitting, run with `NOT_CRAN=true` and the package namespace as the parent
environment. Everything below is that comparison and what it reaches.

## Seven of the fifteen are invariants, and they hold on `develop`

These assert properties of the non-structural carbohydrate pool that no
parameter choice can suspend. `tf24_storage_at` in `test-strategy-tf24.R` is
the probe for the first three.

| block | assertion | measured |
|---|---|---|
| storage cannot leave `[0, S_max]` under the exact flow | `dS <= 0` at the cap | `+1.9e-4`, `+5.1e-5`, `+6.4e-6` |
| the storage rate has no kink where the net flux changes sign | `abs(ratio[last] - 1) < 1e-3` | `0.998` |
| " | `max(excess[-1]/excess[-last]) < 0.3` | `1.03` |
| the storage rate relaxes on the pool's own timescale near empty | `abs(lambda)/own_rate < 10` | `250` |
| a negative storage state is refused by name, not floored | `compute_rates` throws | nothing thrown |

The first says the pool integrates past its own ceiling: at `S_max` the flow is
positive where it must be zero or negative. The last says the guard that names
a negative storage state has stopped firing, so a state outside the domain now
passes as an ordinary one.

## The other eight are pins, and they have tripled

Both blocks run at `birth_rate = 20`, the least favourable end of the range the
`scientific_version = 10` note records. Actual values as `testthat` prints
them, to three significant figures.

| block | pin | now | ratio |
|---|---|---|---|
| offspring arrival | 24.32140145 | 70.3 | 2.89 |
| " | 18.54300907 | 56.4 | 3.04 |
| " | 219.2668011 | 274.2 | 1.25 |
| " | 34.58766277 | 49.4 | 1.43 |
| the height-linear parameters reproduce the pre-path-integral results | 30.22207354 | 82.0 | 2.71 |
| " | 23.20349831 | 67.4 | 2.90 |
| " | 233.05915606 | 287.5 | 1.23 |
| " | 43.63800899 | 59.6 | 1.37 |

The height coordinate moves by about three, the birth-date coordinate by about
1.3. `catalog.md` describes these as "pinned scenario values this branch no
longer produces" and reads them as an operating point that moved. The control
above says the model that produces them is one whose storage pool is leaking at
the cap, so the size of the move is a symptom and not a calibration.

## Four symptoms, one pool

Each was found separately this session and read as unrelated.

`run_scm(use_ode_times = TRUE)` on `develop` dies at 1.3 s replaying the
century grid with *"TF24 storage is negative (-3.44164e-07 kg): the pool's flow
does not leave [0, capacity], so this is a step that overshot the empty
boundary"*. That is `develop`'s guard firing on an overshoot this branch's
guard does not report at all.

`storage_domain_tol` is declared in `tf24_strategy.h` and read by nothing: two
occurrences in the whole workspace, the declaration and one `NEWS.md` line
saying the tolerance would not have helped.

TF24 crosses a stiffness cliff a little past a patch lifetime of 3, where the
accepted step count goes 205 at lifetime 3 to 3324 at 3.5. `NEWS.md` records
the storage domain error being thrown and retried **480 times in a resident run
at `max_patch_lifetime = 20`** that then completes normally.

## Downstream, and why it waits

Nine gradient-suite failures sit behind this and describe the same pool moving.

`test-gradient-parity.R` loses two claims. `seasonal` moved from answered to
refused; the in-loop assertion that a refusal names `ladder_range_refusal`
passes for it, so the refusal is the known descent-out-of-range gap and not a
new branch. `shaded` no longer reaches `shade-death`, which is the branch it
exists to reach; `clamped` still reaches it.

`test-gradient-incidence.R` loses one block entirely. On `incidence_of(0.25, 10)`
the dry pins are **92.4%** of solves against a pinned band of 5, `interior` is
207,790 against a dry total of 2,510,686, and the stand that was refused for
its descent range now answers with a finite gradient.

Recalibrating either file fits a fixture to a model whose invariants are
violated. They are listed here so the next session takes them in the right
order.

## What is green

The failure is local. Measured on the same build in the same sitting:

| file | result |
|---|---|
| `test-model-version.R` | 23 pass, 0 fail, 0 skip |
| `test-strategy-tf24f.R` | 58 pass, 0 fail |
| `test-strategy-ff16.R` | 55 pass, 0 fail |
| `test-strategy-k93.R` | 21 pass, 0 fail |
| `test-scm.R` | 159 pass, 0 fail |
| `test-canopy-methods.R` | 191 pass, 0 fail |
| `test-patch.R` | 176 pass, 0 fail |
| `test-individual.R` | 131 pass, 0 fail |
| `test-gradient-ladder-introductions.R` | 110 pass, 0 fail |

`test-strategy-tf24f.R` passing at 58 checks is worth its own line: TF24f
inherits TF24's equations, so whatever moved is reached by the blocks TF24 has
and TF24f does not.

## Two commits already attest the version

`84f6f85a` declares `scientific_version = 11` and `327b2bd3` accepts the
scientific surface at it. Both were made before this control was run. Neither
asserts the model is correct, since a version names a change and a snapshot
records defaults, but a reader meeting `TF24@v11` will take it as the number under
which this behaviour was intended. They are the last two commits on the branch
and revert cleanly if the pool turns out to be wrong.

## Reproducing the control

```sh
# phylloptim 0.8.0 is 845390c; the tags plant@develop pins are odelia v0.3.1
# and that commit. Build them in dependency order into one private library.
BENCH=/tmp/bench; mkdir -p $BENCH/lib-develop
printf 'CXXFLAGS = -O2 -g0 -DNDEBUG\nCXX17FLAGS = -O2 -g0 -DNDEBUG\nCXX20FLAGS = -O2 -g0 -DNDEBUG\n' > $BENCH/mk-O2
git -C odelia     worktree add --detach $BENCH/wt-odelia v0.3.1
git -C phylloptim worktree add --detach $BENCH/wt-phylloptim 845390c
git -C plant      worktree add --detach $BENCH/wt-plant develop

export R_LIBS="$BENCH/lib-develop:/usr/local/lib/R/site-library"
export R_MAKEVARS_USER="$BENCH/mk-O2"
for pkg in wt-odelia wt-phylloptim wt-plant; do
  R CMD INSTALL --no-multiarch --preclean -l "$BENCH/lib-develop" "$BENCH/$pkg"
done

cd $BENCH/wt-plant/tests/testthat
NOT_CRAN=true Rscript -e 'suppressMessages(library(odelia)); suppressMessages(library(plant))
  testthat::test_file("test-strategy-tf24.R",
    env = new.env(parent = asNamespace("plant")), stop_on_failure = FALSE)'
```

⚠️ **Do not rebuild the library a run is reading.** One measurement was lost
this session that way: `lib-hygiene` was reinstalled at v11 while the suite was
still open on it, and the numbers from that run are unattributable.

⚠️ **`NOT_CRAN=true` or the drift guard does not run.** `expect_snapshot_value`
calls `skip_on_cran()` internally, so `test-model-version.R` reports `skip=4`
without it and `fail=4` with it. Three passes over that file this session read
the skips as passes.
