# Handover

For implementing exact establishment counts, [aornugent/plant#93](https://github.com/aornugent/plant/issues/93), on plant's `develop`. Implementation started September 2026; **Progress** at the end records where it stands. Read in this order:
- #93 itself;
- `scope-schedule-controller.md` §1, the design, including its paragraph "Where it can land", which covers this work;
- this page, for the setup and the code on `develop`.

**Parked; do not start:**
- the stepper, `scope-imex-stepper.md`;
- the rest of the controller scope, `scope-schedule-controller.md` §2–6;
- the tests the performance answer proposed.

The consult and its answer (`oracle-*.md`) are background for those.

## The work

- **Branch.** `PLANT-93` on `aornugent/plant`, at `develop`'s `95256cf3`. It carries no commits yet.
- **One PR against the fork's `develop`, closing #93.** Its tests land in the same PR (AGENTS.md).
- **Independent of everything else.** Nothing here needs the stack (#91, #92) or anything parked. After it lands, the stack's rebase re-applies the birth-date branches in their templated form (scope §1, "What it costs").
- **Do not bump `plant-dev`'s submodule pointer.** It records the stack (`6613dd24`) until #93 merges.

## Setup

A new container has none of this, so it is all written as commands.

**1. Session start** (AGENTS.md):
- run `git submodule update --init --recursive`;
- call `add_repo` for `aornugent/odelia`, `aornugent/plant` and `aornugent/phylloptim`.

**2. A private library.** `develop` links `odelia (== 0.4.0)` and `phylloptim (== 0.8.1)` exactly. The site library holds 0.5.0 and 0.9.0, which `develop` will not build against. So build all three into a private library, never the site one, from worktrees that leave the submodules on the stack. `DEV` is any directory under the scratchpad.

```bash
mkdir -p $DEV/lib
git -C odelia     worktree add --detach $DEV/odelia     v0.4.0    # commit 4758d3e
git -C phylloptim worktree add --detach $DEV/phylloptim v0.8.1    # commit 54d7fe0
git -C plant fetch origin PLANT-93
git -C plant worktree add -b PLANT-93 $DEV/plant origin/PLANT-93
export R_LIBS=$DEV/lib MAKEFLAGS=-j3
for pkg in odelia phylloptim plant; do
  R CMD INSTALL --no-docs --library=$DEV/lib $DEV/$pkg > $DEV/install_$pkg.log 2>&1 || { echo "FAILED $pkg"; break; }
done
```

- *Measured September 2026:* 195 s in all, with no compiler warnings.
- *Rebuilding plant after a C++ edit.* Add `--preclean` to its `R CMD INSTALL` line. The build does not track header dependencies. Without it, an edit to a header recompiles only the `.cpp` files that changed and links objects built against two versions of the same templates; the birth-date path lives in the headers `node.h`, `species.h` and `patch.h`. A clean rebuild takes about 2.5 minutes at `-j3`.
- *Exposing a new value to R* means an entry in `inst/RcppR6_classes.yml`, then `RcppR6::RcppR6()` in the plant tree, before the rebuild.

**3. Tests against the installed build.** Run from `$DEV/plant`, with `R_LIBS` and `TESTTHAT_PARALLEL=false` set:

```r
library(odelia)
testthat::test_file("tests/testthat/test-strategy-ff16-reference-comparison.R",
                    package = "plant", load_package = "installed")
```

Choose files by the tiers in AGENTS.md. On `develop` before any change:
- `test-strategy-ff16-reference-comparison.R`: 17 pass;
- `test-strategy-ff16.R`: 53 pass and one error, from rendering `inst/reports/FF16_report.Rmd`, which needs `ggridges`, `patchwork` and `kableExtra`. The site library lacks all three. That error comes before this work, so leave it alone.

**4. The fixture.** `harness/long_drought.R` in this repo is the lifetime-40 long-drought TF24 stand from #92. It needs no scratchpad: it generates its own record and knots, and calls only exported functions, so it runs on `develop` and on the stack.
- *Loading plant.* Set `PLANT_LIB=$DEV/lib` to use the installed build. `PLANT_DIR` loads a source tree through `load_all` instead.
- *Running it.* `run_J(uniform_times(n))` returns `J`, the step count and the seconds.
- *Holding the time grid across a ladder.* Pass every rung the finest rung's creation times as `stops`.

**`develop`'s baseline:** at 108 cohorts, `J = 14.124246` in 11 185 steps and 82.9 s. It is not comparable with the stack's `J∞ = 12.5734`, which carries the establishment window. Run 215, 429 and 857 first: they are the "before" of the convergence test.

## Where the change goes on `develop`

Line numbers are at `95256cf3`.

**`Node::compute_initial_conditions`, `node.h:183`.** This is where `E` enters twice:
- the cumulative loss is seeded at `−log(pr_estab)` (line 194);
- on the birth-date path the log density is seeded at `log(birth_rate·pr_estab)` (line 209).

`Node::compute_rates` (line 146) weights offspring by `exp(−mortality)`, so `J` reads `E` through the loss seed.

**Decided: the masses integrate `E` alone,** `w_j = ∫ E φ_j`.
- *Where β goes.* The birth rate stays a point sample at `b_j`, as today: in the density seed, `log(birth_rate)`, and in `J`'s scalars.
- *Why.* `offspring_production` (scalars `β(b_j)`) and `net_reproduction_ratios` (scalars 1) then keep their meaning exactly, even under a varying birth rate. `E`, the rough factor, enters once, through the masses.
- *The seeds.* On the birth-date path a cohort starts with zero loss and log density `log(birth_rate)`. The height path keeps both of today's seeds.

**`Species::compute_rates`, `species.h:470`.** It calls `new_node.compute_initial_conditions` on every evaluation, so the boundary cohort's `pr_estab` is current there. That is the rate of the running mass `M₀`, and `(t − b_N)` times it is the rate of `M₁`.

**`Species::introduce_new_node`, `species.h:478`** (and the no-argument form at 249). This is where the panel closes:
- the newest cohort's mass takes `M₀ − M₁/Δ`;
- the new cohort's mass starts at `M₁/Δ`;
- the running pair restarts at zero.

**The species' ODE block.** `SpeciesBase` (`species_base.h`) builds `ode_size`, `set_ode_state`, `ode_state` and `ode_rates` from the nodes alone; `Species` overrides `set_ode_state` at `species.h:71`.
- *What to add:* the two running masses, and one mass per cohort, as species-level entries on the birth-date path only.
- *Why there:* `Node`'s layout, and with it the height path and the R state matrix, stays unchanged. Patch-state export and resume (`patch$ode_state`) carry the masses for free, so no change of representation is needed when the stack's adjoint later reads them.
- *Rates:* each cohort's mass has rate zero.

**Reductions, each a trapezium over point samples today:**
- `Species::compute_competition`, `species.h:348`. One loop is shared between the coordinates, so it gains one early birth-date branch, `Σ w_j·f_j`.
  - The open panel is split at every evaluation: `M₀ − M₁/(t − b_N)` goes to the newest cohort and `M₁/(t − b_N)` to the boundary cohort.
  - The boundary segment and the halving go from that branch.
- `Species::consumption_rate`, `species.h:532`. It opens with its own birth-date branch, a `util::trapezium` over `node_times()` plus the boundary cohort, which becomes the same weighted sum.
- `Patch::net_reproduction_ratio_for_species`, `patch.h:542`, which is `J`. Its `util::trapezium(times, net_prod·scalars)` becomes `Σ w_j·net_prod_j·scalars_j`, and the scalars are unchanged.

The patch-age weight `π(b)` stays in the per-recruit value, where it is smooth: `weighted_fecundity` multiplies by `patch_density_at_birth` (`node.h:71`).

## Tests (#93)

All forward, on the fixture unless named:
- the masses sum to a fine quadrature of `pr_estab` along the run;
- uniform ladders (108 → 857) converge at second order, with the time grid held;
- shifting the schedule by half a spacing moves `J` only at second order;
- removing the cohorts created inside closed bands moves `J` far less than today's discretisation error;
- the instantaneous gate converges in the schedule, which point samples cannot do on `develop`;
- FF16's references are unchanged (`test-strategy-ff16-reference-comparison.R`);
- the change in step count is reported.

Unit tests belong beside the existing birth-date ones, in `test-density-coordinate.R` and `test-node.R`. They cover:
- the insertion map's shares;
- the open-panel split;
- two creations at one instant.

## Three details to settle in the change

- **`refine_schedule`'s drop-one indicator reads cohort densities.** On this path it must read the masses, or refuse to run.
- **R code that reads birth-date densities gets per-recruit values.** The masses are a new column, or a new Species active.
- **Two creations at one instant give a zero-width panel.** Its share, `0/0`, is zero. `birth_dates_are_distinct()` (`species.h:517`) already detects the case.

## Code state

- **`plant-dev` records `plant` at `6613dd24`,** the head of the stack (`establishment-window` on `offspring-adjoint`): issues #91 and #92, no PRs.
- **#93 has only its branch, `PLANT-93`.**
- **Nothing from earlier sessions' scratchpads carries over.** What the next session needs is committed here: this page, the fixture and the scopes.

## Progress

**Implemented on `PLANT-93`** (September 2026):
- *Seeds* (`node.h`). On the birth-date path a node starts with zero loss and log density `log(birth_rate)`. The height path is unchanged, operation for operation.
- *State* (`species.h`). `Species` owns `ode_size`, `set_ode_state`, `ode_state` and `ode_rates`. On the birth-date path its block is the nodes' states, then `establishment_since_newest` and its first moment, then one `establishment_weight` per node (a plain `Node` member).
- *Rates.* The pair's rates are `establishment_rate` (the boundary node's `pr_estab`, computed once in `Species::compute_rates`) and `(t − b_N)` times it. They are zero with no nodes.
- *Introductions.* Both `introduce_new_node` forms call `split_establishment_since_newest()`.
- *Reductions.* Competition and uptake use `establishment_weighted_sum`, with the open interval split inline, so there is no per-call allocation. `J` uses `node_establishment_weights()`, the stored weights, with the scalars unchanged.
- *Height loop.* `compute_competition`'s height loop lost its birth-date branches; it is bit-identical.
- *R reporting.* On the birth-date path `log_densities` and the state matrix's `log_density` row are `log_birth_date_densities()`, then the Jacobian. An introduced node's value is its weight over half its neighbours' span; the boundary node's is `pr_estab·β`, exact. The new Species active `establishment_weights` has n+1 entries, boundary last.
- *Patch.* `node_ode_size()` counts node states only, since `SCM::r_set_node_schedule` reads it as "nodes exist". `ode_state_valid` skips each species' own entries.
- *Refusal.* `SCM::refine_schedule()` stops on the birth-date path, because its indicators read per-seed densities.
- *Tests.* `test-node.R` (seeds) and `test-density-coordinate.R` (rules, split, seeds, rejection per coordinate, reporting relations).

**K93 establishes every seed** (`E ≡ 1`), so its weights are the trapezium's, and its birth-date results should move only at round-off.
