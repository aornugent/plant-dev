# What the templating commit dropped

`a02588c1` folded `src/tf24_strategy.cpp` into `tf24_strategy.h` as a template.
Its parent is `32151e87`, which is develop's tip, so it should have been a
refactor at identical arithmetic. It transcribed `compute_rates`'s storage block
from a copy predating `745dd600` (#619, `TF24@v9`), and the deleted `.cpp` made
that invisible: git shows a file removed and a header rewritten, never a hunk
reverted.

```cpp
// what #619 wrote, what the transcription lost, and what 27e1f57b puts back
const S charge = Ppos * (1.0 - G);      // surplus the gate withheld
const S drain  = Ppos - P;              // shortfall met from reserves
vars.set_rate(state_idx_storage, charge * (1.0 - r) - drain * r);
```

Restoring that rate, the unclamped read it needs and the domain refusal beside
it takes `test-strategy-tf24.R` from 65 pass 15 fail to 80 pass 0 fail. The four storage
invariants hold, and the eight scenario pins come back from `82.09` and `67.54`
on the height coordinate -- values this file's own comment records as the ones
#619 replaced -- to the pinned `30.22` and `23.20`.

## It happened twice, and the audit says not a third

`dafa22cf` caught the first instance on 11 September: `pars.use_energy_balance`
and `pars.d` were set on the Leaf in the `.cpp` and the port did not carry the
pair, so leaf temperature reported the air temperature exactly on every run with
the balance switched on. Upstream's #645 tests found it.

Nothing is left. Extract each top-level definition from `32151e87`'s
`src/tf24_strategy.cpp` and header, normalise for the templating, and compare
against the branch's header: 18 of 72 shared bodies differ and every one but
`compute_rates` is the intended work -- `this->` on dependent names,
`if constexpr` splits at the leaf boundary, the clamp counters, `seed_geometry`,
`record_leaf_outputs`. The same comparison on `src/tf24f_strategy.cpp`, the only
other source the commit deleted, finds no reversion at all. Those two files are
the whole exposure: every other file it touched was edited in place, where a
reversion is an ordinary hunk in its own diff.

## What the pool was carrying

| what | with the pool reverted | bounded |
|---|---|---|
| `test-strategy-tf24.R` | 65 pass, 15 fail | **80 pass, 0 fail** |
| TF24 at patch lifetime 5, default schedule | 9576 steps, 267 s | **407 steps, 7.3 s** |
| `test-mutant.R`'s replay, 89 introductions | 12714 steps, 623 s | **497 steps, 18 s** |
| `test-events.R` | recorded as not finishing | **107 s, 144 checks** |

The middle two rows are why `AGENTS.md` described a stiffness cliff a little past
a patch lifetime of 3 and told everyone to count introductions. The cliff was the
pool integrating past its own ceiling. Cost is smooth in the lifetime now and the
introduction count is still the lever, spanning 73x where the lifetime spans 2.4.

Three lists of drivers went with it. `parity_range_gap`, `reference_range_gap`
and the incidence block on the light floor each named the stands whose descent
leaves the range a double holds; every one of them answers on the bounded pool,
so all three are empty and assert that. Two clamp sites went too -- nothing
floors the pool at either end, so `storage_floor` and `reserve_ceiling` had no
call site.

## The refusal is sounder here than on develop

`compute_rates` refuses a pool more than round-off below empty, and the solver
answers by shrinking and retrying. On develop that holds on the adaptive path
only: odelia 0.3.1's `step_to` takes one unconditional step with no `try` around
it and no validity check after it, which is what `NEWS.md` records under #642 as
killing `run_mutant()` and `run_scm(use_ode_times = TRUE)` alike. odelia 0.5.0
subdivides a refused pinned step to the same endpoint, so the recorded times are
unchanged.

That subdivision is #642, and it is `dfb9cad6` -- the FIRST commit on this
branch, built so this refusal could be honoured on a pinned grid. `a02588c1` then
deleted the refusal, and nothing has thrown since.

## Two things the fix did not explain

**The dry pins.** `test-gradient-incidence.R` asserted that fewer than 5 per cent
of a dry stand's solves land on the pinned branch and the stand returns 54.65.
The stem path integral moved it, and through its SHAPE rather than its level.
Held height-linear and raised uniformly by 1.2x to 2.978x, resistance takes the
share to zero: a stand that transpires less keeps its soil. Held at the 1 m
anchor by re-deriving `K_s` and swept in `D_c`, it takes 0.90, 6.34, 16.53,
26.83, 46.96 and 54.65 per cent at `D_c` = 0 to 0.20, with the stand's minimum
soil moisture falling 0.13204 to 0.13017. That is the channel `tf24_strategy.h`'s
v10 note already names: a plant taller than the anchor pays 0.35 of the
height-linear resistance, transpires faster, and takes the shared column with it.
The band was written at `ebd6c32c`, two days before that merge, and the stand
sits on a plateau past the knee -- rainfall 0.50 to 0.20 gives 0.11, 13.45,
45.40, 52.22, 54.65 and 60.82 per cent.

**K93's survivor count.** `test-stochastic-patch-runner.R` carried a note saying
both sides had moved its baseline, that the merged value is neither, and to
re-bless from a run of the merged tree. Nobody did, so it has been one failure
red since the merge. K93 reads neither a storage pool nor a leaf, so the light
field holding its knot data once is the only change here it can see.

## One thing the fix made visible, and it is a defect

`reference_range_gap` held `shaded` and `clamped`, so the captured whole-run
difference has never refereed them, though it has carried 280 rows for each all
along. Refereed now, ten columns disagree by about one per cent, and **the sweep
is the one that is wrong**.

Every one of the ten is `theta` or `omega`, the birth-size pair, on the species
the stand suppresses. Nothing else disagrees on any regime.

Three mechanisms were tested and none holds. Sweeping `k_I`, the gap does not
track `shade-death` -- at `k_I` = 5 a stand reaches it with no light floor at all
and agrees to `8e-04` -- nor the light floor, which clamps heavily at `k_I` = 8,
10, 15 and 40 where the columns agree. Tightening the solver tolerance a
hundredfold moves the sweep by 0.14 per cent and leaves the gap at 0.85.

What settles it is scanning the census against `theta` directly. On the clamped
stand it is smooth to `3e-09` relative over the innermost ±`2e-05`, and its
fitted local slope is **1105.19** where the sweep reports **1094.71**. A forward
tangent of the same trajectory reproduces the sweep to `1e-11`, so both
differentiated paths carry the same error. That is the one failure no other rung
can see, and the reason this one compares against arithmetic it shares nothing
with.

The row is not yet localised. `seed_geometry()` carries the seed height's
derivative through `implicit_value`, so the helper comment in
`helper-gradient-ladder.R` saying both differentiated paths impose it to zero no
longer matches the code, and which of birth size's channels is short is the next
question. Until then the rung holds an exact expected count, 4 and 6, rather than
a widened floor: a floor wide enough to pass is wide enough to hide the next
one.

## Where the suite stands

Measured on one build at `-O2 -g0 -DNDEBUG` in a private library, with
`NOT_CRAN=true` and the package namespace as the parent environment, over all 77
files in one sitting: **4221 pass, 2 fail, 0 error, 6 skip**, from 77 `RESULT`
lines, so nothing crashed unreported.

The two failures are `test-mutant.R`'s ten-mutant panels, which `catalog.md`
already carries: FF16 pins that this branch moves by 2-4e-4, measured against a
referee that owes develop nothing and parked under A1. The six skips are two
suggested packages, three load-path gates on the FF16 AD probes, and one opt-in
environment variable. All fourteen gradient-ladder files report zero skips across
615 checks, which is what they are supposed to report.

⚠️ **`NOT_CRAN=true` or the drift guard does not run.** `expect_snapshot_value`
calls `skip_on_cran()` internally, so `test-model-version.R` reports `skip=4`
without it and its real state with it.
