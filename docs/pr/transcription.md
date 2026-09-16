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

Restoring those three lines and the domain refusal beside them takes
`test-strategy-tf24.R` from 65 pass 15 fail to 80 pass 0 fail. The four storage
invariants hold, and the eight scenario pins come back from `82.09` and `67.54`
on the height coordinate -- values this file's own comment records as the ones
#619 replaced -- to the pinned `30.22` and `23.20`.

## It happened twice, and the second time is the only one left

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
The stem path integral is what moved it, not the pool: resistance rises for a
plant shorter than the anchor and falls for a taller one, so a seedling in a dry
stand reaches its critical potential where it used to stay interior. Measured on
the same stand with `D_c`, `theta_c` and `L_tip` at zero and `K_s` at 1, the
configuration `test-strategy-tf24.R` states recovers the model the path integral
replaced: **0.90 per cent against 54.65**. The band was written at `ebd6c32c`,
two days before that merge.

**K93's survivor count.** `test-stochastic-patch-runner.R` carried a note saying
both sides had moved its baseline, that the merged value is neither, and to
re-bless from a run of the merged tree. Nobody did, so it has been one failure
red since the merge. K93 reads neither a storage pool nor a leaf, so the light
field holding its knot data once is the only change here it can see.

## One thing the fix made visible

`reference_range_gap` held `shaded` and `clamped`, so the captured whole-run
difference has never refereed them, though it has carried 280 rows for each all
along. Refereed now, they disagree at `9.9e-03` and `8.0e-03` where the other
three regimes sit at or under `1.1e-03`, and the split is exactly the two that
reach `shade-death`. That exit places the collar on the wet bound, where
phylloptim's `duptake_dpsi` returns its not-a-number sentinel to say the analytic
branch does not hold and the marginal profit falls back to a central difference
at the same collar. So the rung compares two difference schemes across a kink
there, and its floor now follows the counter instead of the regime's name.

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

⚠️ **Do not rebuild a library a run is reading.** One measurement was lost that
way: a library was reinstalled while the suite was still open on it, and the
numbers from that run are unattributable.
