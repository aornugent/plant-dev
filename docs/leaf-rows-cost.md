# Where the reverse pass spends, how to find out, and what is left

The reverse-mode stand gradient costs **9.7 times** a plain double forward run at
century scale — **339 s against 35.1 s**, on a refiner-chosen schedule of 3,378
steps, one species, `ode_size` 1,361, three census metrics.

**The ratio is flat across two orders of run length** — 8.7 at a half-year
lifetime, 9.0 at three years, 9.7 here — so the sweep's cost tracks the run rather
than compounding with it. Break-even against re-running once per parameter sits at
about ten parameters and the model carries forty-seven.

**And the ranking has inverted.** The largest single cost is no longer the tape or
any part of the sweep: it is the leaf's supplied derivative rows, at about 39% of a
gradient, of which nearly half is one root-find re-run per perturbation. That is
where §4 starts.

This document states the method that locates a cost correctly, the principles that
decide which lever to reach for, and the levers that remain. It is not a record of
what was tried. Where a route is listed as closed, the reason is a property of the
model and is stated as one.

---

## 1. The instrument

**Three measurements, and any two of them will mislead you.**

| | answers | fails alone because |
|---|---|---|
| **structure** | what phases exist and what each calls | says nothing about how often or how dear |
| **count** | how many times each phase runs each primitive | unit costs differ by more than an order of magnitude |
| **cost** | what one call of a primitive costs | `-O2` inlining collapses frames, so attribution lies |

**share = count × price.** Rank by share, never by count and never by a profile's
own attribution.

That the third one lies is not a caution here, it is arithmetic: in §3's table
`toms748_solve` carries 41.5% cumulative and the leaf's rows carry 35.9%, and these
overlap almost entirely, because the root-find is *inside* the rows. Cumulative
shares of nested frames do not add.

### The procedure

1. **Read the control flow and name the phases.** The boundaries are where a
   distinct piece of work begins, not where a file begins.
2. **Count the expensive primitives per phase.** Counts have no variance; they need
   one run, not five. The model exports the one that matters —
   `boundary_condition_evaluations()` is the recorded rate count.
3. **Price each primitive** from a sampling profile, or from a controlled A/B that
   removes a known number of them.
4. **Attribute by asking the profile a question, not by reading its top.**
   `google-pprof --focus=<symbol>` restricts to stacks through a symbol and its
   subtotal is that symbol's true share; the flat table cannot tell you whether a
   hot leaf belongs to the forward pass or the gradient. Every number in §3 and §4
   was taken that way.
5. **Predict a lever's share before building it**, then hold the built lever to
   that prediction. A lever that returns a quarter of its projection has a wrong
   cost model behind it, and the model is the thing to fix.

### The harness

```sh
PLANT_TEST_LIB=<your lib> scripts/profile-gradient.sh scripts/profile-stand-gradient.R
```

Two passes in one command: it warms whatever the fixture must resolve first, in a
process with no profiler attached, then samples one forward run and one gradient.
It prints a flat profile and a by-function one, and archives the binary the samples
name.

### Five guards, each of which silently voids a measurement

**A no-op passes every correctness check.** A concept that is ill-formed evaluates
false, `if constexpr` takes the other branch, and the change never runs —
bit-identical, and worthless. Assert the path is live: a `static_assert` on the
concept at the point of use, or a counter that must be non-zero.

**Pin the compiler flags.** `pkgbuild::compile_dll` appends `-O0` unless
`debug = FALSE`, and the last `-O` wins. Build every arm through
`R_MAKEVARS_USER` with `CXX20FLAGS = -O2 -DNDEBUG -g`, and confirm from the log
that no `-O0` trails the `-O2`. `-g` changes no codegen and is what makes a profile
readable.

**Profile an INSTALLED plant, never a `load_all`ed one — archiving the binary does
not rescue it.** `pkgload` maps its own copy of `plant.so` and unlinks it *while it
is still mapped*, so the profile's maps trailer records the path with a literal
`(deleted)` suffix. No archived copy can be substituted for that, because what is
wrong is the map entry and not the file: `pprof` looks for a name that never
existed and every sample inside plant resolves to a bare hex address.

**Resolve whatever the fixture must set up in a different process from the one you
sample.** Schedule refinement bisects on trait-dependent errors and re-runs the
whole model many times — **206 s against a 35 s run** at century scale — so a
profile including it spends half its samples in the forward model and reads as if
the reverse pass were cheap. It also changes what a gradient-to-run *ratio* means,
because the denominator becomes many runs rather than one. This is what the
harness's first pass is for.

**Snapshot the maps before killing a long run.** gperftools writes the
`/proc/self/maps` trailer only at clean exit; a killed run leaves samples with
nothing to resolve them against. `cat /proc/<pid>/maps > file` while it lives and
the partial profile stays readable.

Profiling needs no privileges: `perf` is blocked wherever
`kernel.perf_event_paranoid` is above 2 — it is 4 here — but gperftools'
`libprofiler` samples on `SIGPROF` and works unprivileged. `LD_PRELOAD` it onto the
**R binary** directly; via `Rscript` or the `R` wrapper the first signal arrives
during the exec chain and kills the process. `google-pprof` is in the
`google-perftools` package, which the `-dev` libs do not pull in. Set
`OPENBLAS_NUM_THREADS=1`; the pthread build's pool spins in `sched_yield` for about
2.5% of a run that does no BLAS.

### What verifies a change

In increasing order of what it can see. The cheap ones do not substitute.

1. **Bit-identity of the gradient**, for anything that only changes how much is
   computed. `identical()` on the returned object, not a tolerance. This is the
   whole test for a caching, hoisting or deletion change.
2. **The ladder and the FF16 tripwire**, for anything that reassociates. A
   reassociation moves the gradient at round-off and leaves the census value exact;
   ~1e-16 is reassociation, ~1e-9 is the solver floor, ~1e-4 is a real difference.
3. **`ladder_run_difference_pair()`** — a difference that rebuilds the strategy and
   re-runs, on a stand where two species compete. The only instrument that shares
   no assumption with the sweep, and the only one that can referee a change from
   differenced to analytic. It carries a step-stability guard because a reading
   taken at an unconverged step is a factor of two out.

A single-species reference is not evidence for anything the competition reaches:
rows six per cent out have agreed with one to `1e-06`.

---

## 2. The principles

Six moves, weakest first. **The first three reduce a cost; the last three remove
one.** Reach right before reaching left.

| | the move | what it needs to be legitimate |
|---|---|---|
| **cache** | same inputs, same answer — keep it | a key covering everything the value depends on, or no cache at all |
| **append** | the new answer is the old plus a term | the term is separable in the arithmetic *as written*, not merely in the algebra |
| **perturb** | the new answer is the old under an identity | the identity must hold for the object evaluated, not the object approximated |
| **avoid** | the call has no consumer | trace every reader; "written and never read" is an observation, not a conclusion |
| **shortcut** | the answer is known without computing it | a declared zero needs a proof and a name, never a silent absence |
| **trim** | the consumer needs less than is produced | enumerate outputs from the consumer's equations, not from what the producer exposes |

**Two rules about which lever is worth pulling.**

**An asymmetric lever beats a symmetric one when the objective is a ratio.** The
target is grad/run. A change that makes the forward model faster raises the bar it
is measured against: halving a cost the forward also pays moves the ratio by a
fraction of what it moves the absolute time. Rank levers by what they do to the
*reverse pass alone*, then check what they give back to the forward. Every item in
§4 is marked for this.

**Storage against recomputation is a decision, not a fact.** The per-cohort
decomposition rebuilt rather than stored because storage was the binding
constraint. Peak now holds a whole step rather than one cohort-step, so that
constraint has already been traded once, and §4.4 is the remaining half of the same
question.

**And the deepest form of the question is not "how do I compute this faster" but
"what is this a function of".** A quantity constant in time need not be recomputed
per step. A quantity linear in an input need not be re-differentiated. A quantity
the consumer discards need not be produced.

---

## 3. Where the cost is

Measured with `scripts/profile-gradient.sh` on the fixture named at the top:
105,308 samples at 250 Hz over one forward run and one gradient. The forward run is
35.3 s of the 384 s sampled, so **about 91% of these samples are the gradient's**.

Each share below is a `--focus` subtotal — the true share of stacks through that
symbol — so they nest rather than sum.

| phase | share of profile | asymmetric? |
|---|---|---|
| **`Step::step_adjoint`** — record the step, sweep it per seed | **74.1%** | yes |
| ⤷ **`record_leaf_outputs`** — the leaf's supplied rows | **35.9%** | **yes** |
| ⤷⤷ `prepare_collar_solve` — the feasible interval, per drive | **16.3%** | **yes** |
| ⤷⤷ `dprofit_droot_collar_psi` — the marginal-profit probes | **8.3%** | **yes** |
| ⤷ XAD's tape machinery — sweep, slot pushes, register/unregister | **~17%** flat | yes |
| **`store_trajectory`** — a second full forward pass | **8.5%** | **yes** |
| the light spline's reads (`basic_spline::operator`, `deriv`) | ~14% flat, over half inside the leaf's rows | no |
| the water supply (`MultiLayerRoots::uptake_impl`) | 9.7%, mostly inside the leaf's rows | no |

**Three facts follow, and they set §4's order.**

**The leaf's supplied rows are the dominant cost, and they are AD-only.** ~460
lines that form the opaque node's derivative rows by differencing, at 35.9% of the
profile and about 39% of a gradient. The forward model does not pay any of it, so
by §2's rule it outranks everything else here by a wide margin — and no sweep-side
change can touch it.

**Nearly half of that is one root-find re-run per perturbation.**
`prepare_collar_solve` alone is 16.3%. It resolves the feasible interval for the
collar solve, and it runs again for every drive the differencing takes.

**The tape is no longer 30%.** An earlier reading measured XAD's machinery at about
30% when ~18,000 tapes were created and cleared per run, one per cohort per stage.
One recording now spans a whole step and the tape is reused across the walk, so the
per-recording fixed cost is paid 3,378 times rather than eighteen thousand, and the
machinery measures **~17% flat**. The ruling that the tape is worth attacking was
true of the earlier distribution; it is the second question now, not the first.

**The count that pairs with these prices:** 20,268 rate evaluations against 3,378
steps is exactly six per step, with three metrics asked for — so the recording does
not scale with the metric count at production width, which is what "record once,
sweep per seed" claims and had not been checked at this width.

---

## 4. What is left

Ranked by share of the reverse pass, asymmetric items first, because that is what
§2 says to rank by.

### 4.1 Hoist the collar-solve preparation — 16.3%, and the argument is already made

`prepare_collar_solve` runs two root-finds for the feasible interval, and every
drive of the differencing re-runs it. **The interval does not move for a
perturbation that moves no water**, so the hoist is legitimate per family and wrong
applied to the whole loop: radiation and maximum conductance cannot move it, a soil
potential or a layer's root carbon can.

So this is a **cache** under §2's weakest move, and its key is not a value but a
*family*: which drives leave the water balance alone. That list is small, stated in
the rows' own structure, and is the whole of the risk — a key that covers almost
every mutator is worse than no cache.

*Predicted share:* the radiation and conductance families are two of the five that
difference, so a per-family hoist should return a little under half of the 16.3%.
Hold the built lever to that.

*Verified by:* bit-identity. A hoist that changes no arithmetic must return the
same gradient object under `identical()`, and if it does not, the interval did
move and the family list is wrong.

### 4.2 The marginal-profit probes, and the conductance rows for free — 8.3%

`dprofit_droot_collar_psi` is the curvature probe and the perturbed marginal-profit
evaluations. Two routes, and the second is a correctness check whether or not the
saving is wanted.

**The conductance rows are closed form.** Report 05 §7.3 establishes
`R = F(E_up, dE_up/dp; p, phi)` with two scalars `a` and `b`. Maximum leaf-specific
conductance enters `F` **only** as the scale on both intermediates, so Euler's
relation on that homogeneity gives

    dPi/dkappa = -b * E_up / kappa
    dR/dkappa  = -( a * E_up + b * dE_up/dp ) / kappa

both exact, both from scalars two drives already fix, and both replacing a central
difference and its two bracket root-finds.

**Take the check even if the saving is not wanted.** If `dPi/dkappa` does not match
the existing difference at wet, dry and shaded states, the same identity underwrites
report 05 §7.3's whole rank-two factorisation, and that is a correctness finding
rather than a performance one.

**The photosynthesis marginal row has no drive to remove yet.** `a`,
`curv_fact_elec_trans` and `curv_fact_colim`: the profit half is derived and
verified, the marginal half needs `A''` and a mixed second partial. Both sit on
kernels containing no interpolator, cache or root-find — the one place in the leaf
where an active scalar raises no correctness question. Until both halves exist
there is nothing to delete.

### 4.3 The tape — ~17%, and the mechanisms are named

Three costs with three different fixes:

- **Thread-local lookups on every active value's construction and destruction** are
  already gone: `XAD_NO_THREADLOCAL` is in both packages' `Makevars`. They must stay
  in step — the define changes the storage class of a symbol whose mangled name does
  not change, so a build with the packages disagreeing links and then misbehaves —
  and it forfeits thread safety permanently, which is correct while neither package
  contains a thread and a thing to revisit if one ever does.
- **Register/unregister churn**, visible as `unregisterVariable` at 1.6% and
  `append_n` at 2.9%, counts short-lived active temporaries in the recorded
  arithmetic. `to_passive` on passive subexpressions is the usual fix.
- **Identity statements from by-value active parameters.** `Internals<S>`'s
  accessors return `S` **by value**, and about sixty strategy signatures take `S` by
  value. With a tape active an `AReal` copy is not a copy: it registers a variable,
  pushes a slot with multiplier 1.0, pushes a statement, and the destructor
  unregisters — so each records a full `y = 1.0*x` and is swept as such.
  `net_mass_production_dt` is the clearest instance, taking `S height_inverse` by
  value and discarding it with `(void)`. Taking these by `const S&` should be
  bit-identical, since a multiplier-1.0 chain is exact, and it shrinks the sweep as
  well as the recording.

### 4.4 The trajectory re-run — 8.5%, pure recomputation with a producer already

`census_trait_gradient` opens by calling `store_trajectory()`, which re-runs the
whole model to record per-step states. **The caller has just run it.** This is an
**avoid**, not a cache: the work has a producer, and what is missing is that the
first run does not record. The cost of making it record is memory, about 25 MB at
century scale, against a step-recording peak that is already the binding term.

The hazard is the validity key. A trajectory reused after any mutation is a
gradient of a different model, and the failure is silent. Either the first run
records unconditionally, or the reuse is keyed on something that covers every
mutator — and a key that covers *almost* every mutator is worse than no cache.

⚠️ **Revolve and binomial checkpointing do not apply and would make this worse.**
Their purpose is to bound tape memory below `O(M)` by trading storage for a `log M`
recomputation factor. The move on this axis is the opposite one: store more.

### 4.5 Spline reductions — deferred, and on another branch

The field build evaluates a reduction over every cohort at every knot. The Yokozawa
kernel is a polynomial in `u^η`, so three running sums over height-ordered cohorts
give every knot at once and the build is `O(K + N)` rather than `O(K·N)`.

**This work is proceeding on another branch and must not be duplicated here.** Two
things to know when it lands. It is **symmetric** — the forward model pays the same
reduction — so it improves absolute time considerably and the ratio much less. And
it does not remove a build: it makes each one cheaper.

### 4.6 What has stopped being a lever

Stated because each was ranked highly by the previous reading and a reader coming
back to that ranking will otherwise spend the search:

- **The per-cohort block's field registration.** The block registered all `2K` knot
  values and slopes and read one scalar, and the fix was to register the scalar. There
  is no per-cohort block: the step recording registers the state and the parameters,
  and the field is an intermediate.
- **The boundary's active field build**, previously ~13%. The inflow condition's
  separate recording is gone; it is an intermediate of the step recording.
- **The plain-double stage rebuild**, previously 6%. A stage recording could not be
  taken until its state existed in double; a step recording builds those states as
  its own intermediates. This is most of what took the gradient from 463 s to 339 s.

### 4.7 The disturbance weighting — a map, not a saving

⚠️ **Scenario-specific.** Patch disturbance is one scenario and no-disturbance runs
are also required, so this is not a general cost lever. What it is, is a statement
of where a *disturbed* run's answer lives.

The census is seeded at `max_patch_lifetime = 105.32` years against a Weibull regime
with a mean interval of 30.0 years, so survivorship at the seeding age is 6.25e-5:
3.67% of the disturbance-weighted mass sits above 50 years, 0.345% above 70. Under
that scenario the weighted integral over patch ages is the object the ecology wants,
and for an adjoint it is the same single sweep — inject `rho(t)·dC/dy` as a per-step
source instead of seeding once at `T`. `Patch` already carries the weighting, so it
costs nothing and it changes what the number *is* rather than how fast it arrives.

**On an undisturbed run there is no weighting to exploit** and the terminal census
at the full lifetime is the object, so run length stays a modelling choice. Treat
this as a correctness note for the disturbed scenario.

---

## 5. What not to do

**Do not hold the vulnerability curve's grid across a trait perturbation.** The grid
is `psi_max = b·log(100)^(1/c)` and `set_traits` rebuilds it whenever a curve trait
moves, so the moving grid is part of the function being differentiated. A held grid,
or the homogeneity rescale in `b`, differentiates the base spline stretched — a
different function. The test is one question: **does the forward model rebuild the
grid when the parameter moves?** If it does, the motion is the model.

**Do not substitute a closed form for a tabulated derivative.** Where the forward
solve reads a spline, the derivative belonging on the tape is the spline's. The
closed forms are worth having as a replacement for the *table*, in the forward
model, as one change with one re-blessing — not as a drop-in for its derivative.

**Do not read a hoist as safe because a value is written and never read.** Whether a
dropped accumulator matters depends on whether its upstream quantity carries a
derivative, and a later declaration can change that.

**Do not rank by the profile's flat table.** §3's shares nest; the hot leaves belong
to callers that decide whether they are the forward pass's or the gradient's, and
only `--focus` answers that.

---

## 6. Sequencing

Land one family at a time and hold each to the values it replaces before moving on.
A change from differenced to analytic returns a finite, plausible, wrong gradient
when it is wrong, and the differenced implementation is the reference — it exists
today, and it stops existing the moment it is deleted. **Capture the reference
before removing the differencing.**

The order the shares imply: §4.1 first, because it is the largest asymmetric item
and a hoist rather than a re-derivation, so bit-identity refereeing it is enough.
Then §4.2's conductance identity, which is a correctness check that happens to pay.
Then §4.4, which is bounded by a memory decision rather than by arithmetic. §4.3
last of the four, because its three parts are each small and one of them touches
sixty signatures.
