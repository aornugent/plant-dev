# What this work measured, and what it cost to find out

The running record behind `one-program.md` and `one-order.md`: root causes chased
to a line, measurements that overturned a claim, and the two scares that turned out
to be something else. Kept because each one is a number somebody would otherwise
take again, and because three of them record a wrong answer before the right one.

**This is HISTORY, not a plan.** Nothing here is outstanding work. Read it when a
number in a live document needs its provenance, or before re-measuring something
that looks unmeasured. The live documents are `principles.md` -- the rules and the
map -- and `two-paths.md`, the work.

⚠️ **Every measurement here was true when taken, and some names have since moved.**
`solve_adjoint_over_insertions` became `Solver::solve_adjoint`;
`advance_over_insertions` and `insertion_steps` are gone. A figure is still good; a
symbol may not resolve.

## What is in here

* What de-risking found before a line was written
* Closed: the `adjoint_segments` scare, and the two real defects under it
* Root cause: the gradient's curvature is wrong, and the model is fine
* The rearchitecture: differentiate the residual, not the objective
* The root cause, localised to one point in 2,829,445
* UNBLOCKED: the century fixture answers
* All three sites, and the referee the region can actually have
* The helper, and where increment 2 actually starts
* Increment 2: what landed, and the one closed form that blocks the rest
* Increment 2 done: one form for every collar closure
* The two forms collapse, and the gradient's cost, measured
* The gradient's third: root cause
* Against ad/v3-forward: two regressions, not one
* What the leaf's derivative costs, measured
* The sweep is not walk-bound, and what the tape carries that nothing reads
* What the leaf's derivative costs, measured

---

# What de-risking found before a line was written

Three read-only sweeps, run before the build. Two killed claims this spec had
made; the rest are constraints worth having in one place.

## The two mechanisms that would have broken the row form

Section I chose a field over a row and priced two objections. One of them --
the recorded stage address -- **was deleted by step 6**, and the comment on
`push_inserted` still cites it. The other is worse than it looked:

⚠️ **A repeated time at a junction is SILENTLY DELETED.**
`NodeSchedule::distribute_ode_steps` skips any recorded step whose time is
bit-identical to `time_introduction()` or `time_end()`. An SCM insertion happens
exactly at an interval boundary, so *both* copies of a duplicated time are
dropped and the instruction never reaches the solver. No error, no trace.

⚠️ **The first and last instruction cannot be a junction.** `r_set_ode_steps`
requires `times.front() == 0.0` and `times.back() == max_time` **bit-exactly**.

Inside an interval a duplicate is no better: the NaN copy becomes
`step_to(t)` from `t`, which `set_time_max` permits, yielding a **zero-size
accepted step** and a recorded row; a sized copy advances the state by `h` while
assigning the clock back to `t`, desynchronising the two silently.

**So the flag-on-the-instruction form is not a preference. It is the only form
that does not corrupt the schedule.**

## What the R surface pins

* `parameters.ode_times` / `ode_step_sizes` are read at exactly one place,
  `make_node_schedule`. `Parameters::validate()` never looks at them.
* **The flag never reaches R.** `refine_schedule` writes only `.time` and
  `.step_size` into `Parameters`, so the field list is unchanged -- which matters
  because `scripts/refined-century.rds` is a whole serialised `Parameters` and a
  missing field is `Index out of bounds`, not a warning.
* `test-strategy-ff16.R:232` pins `length(ode_times) == 276`; `test-scm.R:424`
  pins `length(traj) == length(grid)`. **A junction as a row breaks these two
  first.**
* `Solver::history` and `SCM::history` are **not** residue: plant calls
  `set_collect(false)` and never re-enables, but the lorenz and leaf_thermal
  examples read odelia's through R, and `run_scm(collect = TRUE)`'s entire return
  value is built from plant's. `collect` gates nothing but those snapshots.

## What the tests actually guard

⚠️ **`test-gradient-ladder-identity.R` is blind to a junction-transpose error by
construction.** Every assertion in it compares the sweep to *itself* -- two
sweeps, a metric permutation, a split against the whole -- so a uniformly wrong
junction is uniformly wrong on both sides and all three blocks pass. The file
that reads like the decomposition test does not check the decomposition's
arithmetic.

**The guard rail is one file plus the captured reference:**

| | what it checks |
|---|---|
| `test-gradient-ladder-rung5.R:144-182` | the whole junction Jacobian, entry by entry, forward tangent vs the reverse transpose, at **1e-12**, at every widening |
| `test-gradient-ladder-reference.R:90-135` | five regimes against `reference/reference-gradient.tsv` -- the only instrument sharing no arithmetic with the sweep |
| `test-gradient-ladder-first-segment.R:66-97` | the lambda the walk *ends* holding, i.e. the composition of every junction transpose |

And a structural blind spot to respect: the insertion transpose is followed by
`if (lo < hi)`, so **on any fixture that introduces at t = 0 the range below the
first widening is empty and a skipped transpose there is unobservable.**
`ladder_stand_resumed` is the only fixture in the suite where that range carries
steps, which is exactly what `first-segment.R` exists for.

## `extra_splits` as an identity junction: five constraints

1. `expect_identical(split, whole)` -- the transpose must be **bit**-exact and add
   exactly zero to `parameter_adjoint`. Today no arithmetic runs at a split at all.
2. `expect_gt(ranges, unsplit_ranges)` -- a split must still increment the range
   count, and `swept` counts only ranges with `lo < hi`.
3. A split landing *on* a widening must stay a no-op -- today the `sort` +
   `std::unique` dedup does that.
4. The filters differ by one character: insertions use `at >= k_first`, splits use
   `at > k_first`. Unifying them changes `ranges` on `ladder_stand_resumed`, which
   `first-segment.R:56` pins as `n_widening + 1`.
5. Split points cross from R 1-based; `gradient_ladder.cpp` refuses `s < 1`.

## One claim in this spec was wrong about a deletion

`Solver::step()` is **live**, not dead. It is R-exposed through
`solver_interface.hpp`'s `Solver_step_impl` -> `Solver_step` ->
`lorenz-interface.R`, and the lorenz and leaf_thermal examples call it. This spec
listed it as residue on the strength of a grep for `\.step()` and `solver.step`,
which does not match `->step()`. The compiler caught it on the first install.

⚠️ **A member function reached through a pointer needs a grep that matches `->`.**
Every other name in the residue table above was checked by its bare identifier,
which does match both.

## Free subtractions this turned up

* **The last row index used as an address.** `sweep_range` passes its loop index
  `k` to `step_adjoint`, which re-derives `prev_steps.at(step).solved` from it --
  assuming `rec` spans that very `prev_steps`, which nothing checks. `sweep_range`
  already holds `rec[k]`, so `rec[k].solved` is the same object without the index
  or the assumption. This is the survivor of step 6's address removal.
* ~~`solve_adjoint`'s `!rec[hi].inserted.empty()` guard is unreachable-false.~~
  **Wrong, and it matters.** `stops` merges the junctions the run recorded with
  the cuts a caller asked for, and a cut's row has no recorded wider state -- so
  testing that state is exactly how a cut got to be free. The de-risking pass
  reached its conclusion from `insertion_rows` alone. The guard now reads the flag
  and says so.
* `state_at_segment`'s header comment is **stale**: it says no record holds the
  widened state, and `rec[start].inserted` holds exactly it.
* `apply_insertion`'s fallback path does not size `out` where the member path
  does -- latent, unreachable today.
* `man/run_scm.Rd` still documents `use_ode_times` and an `ode_step_sizes`
  argument that `run_scm` no longer takes.


---

# Closed: the `adjoint_segments` scare, and the two real defects under it

Recorded because the wrong conclusion was written down first and held for a while.
**There was no regression.** The pilot is exonerated, and it was never measured.

## The measurement was confounded, and the arms were not what they were labelled

The comparison read `adjoint_segments` as 0 before the pilot and 169 on it. Neither
arm was what its name said:

| directory | holds | built |
|---|---|---|
| `lib-copyB` | **plant only** | 08-28 10:02 |
| `lib-pilot` | **odelia only** | 08-28 15:23 |

Each arm therefore took its other half from the shared user library, whose plant
was built **08-27 11:56** -- a day and about thirty commits before the pilot. And
odelia's sweep is header-only: it compiles *into* plant. So the "pilot" arm ran
yesterday's sweep with the pilot's `odelia.so` linked beside it, and the pilot's own
plant (`plant/src/plant.so`, 15:27) was never installed anywhere the run could
reach it -- the profile scripts use `library(plant)`, deliberately, not `load_all`.

Both arms were pre-pilot plants a day apart. This is AGENTS.md hazard 4 exactly:
*a number taken across a swap is unattributable, and nothing announces the swap.*

## What actually moved the count: `c9aa4bed`, a day before the pilot

`c9aa4bed` *"One refusal, latched and returned; the exception goes"* (08-27 16:30)
sits inside the window between the two arms. Before it there were two ways to
refuse, and **the zeroing was attached to only one of them**: the removed lines are

```
-  } catch (gradient_refusal& e) {
-    why = e.site;
-    adjoint_segments = 0;
```

beside a second, *unthrown* route that set `why` from a latch and left the count
standing. So a refusal arriving by latch produced the all-NaN gradient **and** a
live range count. `c9aa4bed` collapsed the two representations into one latch and
put the zeroing on the unified path, and the count began agreeing with the refusal
beside it.

169 was the old bookkeeping, not new work. The fix predates the pilot.

## Confirmed on a properly paired library

One gradient call, in one process, with plant **and** odelia both built from the
pilot (`lib-pair-pilot`):

```
segments     0
metrics      3
  metric 1: 47/47 non-finite | refusal: TF24 gradient: the leaf's profit curvature
            at this operating point is 34.414226, against a floor of 0.001000 (sp 1)
```

The pilot reports **0**, the same as the newer pre-pilot plant. The pilot's merge is
not blocked.

End to end through `scripts/profile-stand-gradient.R` on that same paired library,
with the refusal now printed:

```
forward_s          31.91
gradient_s        108.56
ratio                3.4
rate_evaluations   20286
placements       2333500
swept_ranges           0
refusal            ... is 34.414226, which is not negative -- the profit is convex
                   here ... No curvature floor admits this point
```

`swept_ranges 0` agrees with the refusal beside it, which is the property target 19
buys.

⚠️ **The 185.7 s and 189.7 s in the table above are unattributable and must not be
carried forward.** They were taken on the mispaired arms. The paired figure is
108.6 s at a ratio of 3.4, and it is still the cost of a discarded sweep, so it is
a ceiling on the reverse pass rather than a measurement of one. **Every timing in
the cost model needs retaking on a fixture that answers** -- which is the one thing
this whole episode leaves open.

## The two defects that were real

**1. The century profiling fixture has been refusing all along, silently.** On all
three metrics, all 47 columns non-finite. The scripts printed timings, counts and
`swept_ranges` and never the refusal, so every number in the cost model is the price
of a full sweep whose result is discarded. The shares are still valid -- the refusal
is latched and polled after the sweep completes, so the work is real -- but the
fixture is not producing a gradient, and nothing said so. Fixed: the ladder's counts
call now returns the refusal and both profile scripts print it.

**1b. And it is not the refusal it appeared to be.** The guard is

```cpp
if (!(condition.slope < 0.0) || std::abs(condition.slope) < curvature_floor())
```

-- two limbs, one `refuse()` call, and one sentence naming the floor for both. The
century point has `slope = +34.414226`, which is **four orders of magnitude above**
the floor: the magnitude limb passes comfortably and it is the **sign** limb that
fires. The point is genuinely convex. Reading "34.414226, against a floor of
0.001000" as a magnitude failure is the natural reading and the wrong one, and it
is what sent this session looking at the floor and at the sweep instead of at the
model. **Two facts sharing one representation, and the reader pays.** Split, so the
convex case says it is convex and adds that no floor admits it.

This also contradicts a measurement the code states as its own justification.
`src/control.cpp` argues the floor from a 5625-state sweep in which "every one of
the 1351 interior points had a strictly negative curvature". The magnitude half of
that holds and is what the number rests on; the **sign** half does not -- the sweep
was over static leaf states in a named box, and a stand integrated for 105 years
reaches operating points outside it. Recorded there, beside the claim. **The sign
limb is live, not defensive**, which is exactly why it needs its own sentence.

---

# Root cause: the gradient's curvature is wrong, and the model is fine

Found with the systematic-debugging discipline. **Two hypotheses were formed and
both were wrong before the third held**, which is the part worth recording -- each
was killed by a measurement rather than by an argument.

## The measurements, in order

| # | hypothesis / question | verdict | how |
|---|---|---|---|
| 1 | `implicit_value`'s nested second derivative is wrong | **REFUTED**, exact to 1.2e-16 | new nested case in `odelia/tests/standalone/probe_implicit_tangent.cpp` |
| — | is it a regression? | **no** -- the sign limb has existed since the guard's first commit (`63235c78`, 08-11); the fixture's traits never changed | git archaeology |
| — | why did nothing catch it? | the verification convention was bit-identity, and **`identical(NaN, NaN)` is TRUE in R** -- every check compared one all-NaN gradient against another | archaeology |
| — | where is it? | NOT the final state; all 2,829,445 operating points in the run are `interior` | `ladder_rhs_adjoint_tf24`, 0.01 s |
| — | why does the margin look healthy? | `note_curvature` records `std::abs(...)`, so the min margin is 2.66 and the sign is discarded | code read |
| 2 | the collar solve returned a MINIMUM (a non-monotone marginal, three roots, TOMS748 landing on the upward crossing) | **REFUTED** | a probe dry of every returned root, over 2,829,445 interior solves: the marginal was found rising **zero** times |
| 3 | the nested-AD curvature disagrees with the marginal the solve rooted | **CONFIRMED** | below |

Hypothesis 2 was reasoned from a true premise -- an interior collar is reached only
on a bracket the marginal crosses downward, so a converged root with a positive
slope has to mean non-monotonicity -- and the *premise about the slope* was what
turned out to be false. **The reasoning was sound and the input was wrong**, which is
the failure mode a measurement catches and an argument does not.

## The confirmation

At the offending point on the century stand, collar x = 1.7984860121573381:

```
dprofit(x - h) = +1.7105919821513993e-05   (feasible)
dprofit(x + h) = -1.7544804400415615e-05   (feasible)
dprofit(x)     = -1e-06                    (a root)
                                  h = 1.798e-06

centred difference of the marginal  =  -9.6333037865457243
plant's collar_condition().slope    = +34.414225767561035
```

The marginal is **positive** wet of the collar and **negative** dry of it: it crosses
**downward**. The collar is a genuine interior **maximum**, its curvature is
**negative**, and the collar solve is correct.

**So the forward model is not wrong.** `Leaf::collar_condition` -- which differentiates
`Leaf::profit_at` twice in a nested forward-over-reverse scalar -- returns the wrong
**sign** and about 3.6x the wrong **magnitude**. The gradient refuses a perfectly good
operating point because it divides by a curvature it computed incorrectly.

This is the better of the two outcomes: **no model result changes**, and fixing it
makes the century fixture answer for the first time in its existence.

## What is being done about it

* **`CollarCondition::marginal`** -- the FIRST derivative the curvature is taken
  from, which the same sweep already computes and nothing was reading. At an
  interior point the solve put the collar where the marginal is zero, so this must
  be ~0; if it is not, `profit_at` is not the function the solve rooted and its
  second derivative is the curvature of something else. **Free, and it is the one
  check this derivation could not make about itself.** Its accessor,
  `odelia::ode::plain_adjoint`, is one `value` away from `directional_adjoint` and
  is named rather than written inline for that reason.
* **`Leaf::nonmonotone_collars`** -- kept even though hypothesis 2 was refuted,
  because it is what establishes the solve's innocence, and it would catch the
  failure it was written for if that ever does happen. One extra marginal
  evaluation per interior solve.

## Still open

Which factor of `profit_at`'s composition loses the curvature. `implicit_value` is
exonerated by measurement, so the fault is in what `profit_at` freezes around it:
every `to_passive(...)`, explicit `<double>`, and plain `double` local removes a
quantity's dependence on the collar, which is harmless for a first derivative when
the frozen value is the true partial at the point and can be fatal for a second.
The candidates are the flux inside the ci residual's denominator, the stem
potential's transport response, and any spline lookup whose second derivative is
piecewise where its first is not.

## Why the ladder never saw it

Every first-order check passes: the ladder referees gradients against forward
tangents and finite differences, and the curvature is not a gradient -- it is an
intermediate the interior derivation divides by. A wrong curvature does not perturb
a first derivative, it **refuses** it, and a refused metric is all-NaN, which
`identical()` cannot tell from another all-NaN. So the one fixture that exercises
this had no way to report it.

---

# The rearchitecture: differentiate the residual, not the objective

## What is fundamental

The leaf chooses a collar potential `p` maximising profit `π(p; θ)`. The optimum
satisfies `M(p*, θ) = 0` with `M = ∂π/∂p`. Differentiating an argmax **forces** the
implicit function theorem:

    dp*/dθ = −(∂M/∂θ) / (∂M/∂p)

so `∂M/∂p` — the curvature — is required, not incidental. Two consequences the code
already half-knows: **π's own row needs no curvature** (envelope theorem, `∂π/∂p = 0`
at `p*`), and **anything reading `p*` does** — the water outputs, hence
`resource_depletion`, hence dy/dt. Re-expressing consumers to avoid it is
**impossible**: the envelope theorem does not extend past the optimal value.

## The insight

`∂M/∂p` and `∂M/∂θ` are **first derivatives of M**. The code obtains them by
differentiating **π twice**. M already exists as a first-class function —
`dprofit_at_collar_psi` — and every other closure in this model differentiates its
own residual once: `bound_at` does, and `implicit_value(y*, dFdy, F)` *is* that
pattern, used for sigma, ci and both bounds.

**The interior point is the only place in the model that reaches for a second
derivative, and only because it differentiates the objective instead of the
condition.** `collar_condition`'s comment -- *"THIS IS THE ONE DERIVATIVE THAT
CROSSES A BOUNDARY AS A NUMBER, and it crosses because reverse mode cannot nest a
tangent above its own scalar"* -- describes a problem that exists **solely** as a
consequence of that choice.

## What the second derivative actually costs today

Not a nested scalar. **A parallel, hand-written second-order model with one consumer
and no referee.** `profit_at`'s entire p-side residual curvature comes from exactly
two frozen-`double` Taylor coefficients:

* `leaf_model.hpp:4557` -- `0.5 * d.d2psi * step * step`, the stem integral's psi
  curvature. Line `:4556` deliberately contributes **zero** curvature, so this one
  coefficient carries all of it. **No referee anywhere in the tree.**
* `roots.hpp:1598` -- `c.integrand_deriv`, the root flux curvature. Its sibling
  `c.deriv` (`:1595`) is the **interpolant's** slope while this is the **closed
  form's**, so the lift's first and second coefficients belong to two different
  functions.

The one tested closed-form second derivative that could referee the second --
`d2E_from_soil_dpsi_collar2`, checked against a difference to 1e-5 in
`test_leaf.cpp` -- **is called only from tests and never from production.**

⚠️ **And the probe that "exonerated" `implicit_value` proved less than claimed.** Its
residual `y^3 - p` has **F_pp = 0 and F_yp = 0**, so it verified only the
`F_yy * y'^2` term. It says nothing about whether those two surrogate lifts deliver
the right `F_pp` -- the term the collar curvature rests on. Retracted as over-broad;
the probe needs a residual with `F_pp != 0` and `F_yp != 0`.

## Measured: the AD curvature is right in general

On a 0.5-year stand at the default floor, at every interior point:

```
curv AD=-2.661353615  diff=-2.661353618  | marginal AD=-1.08e-14  solve=-5.11e-15
curv AD=-3.773735305  diff=-3.773735302  | marginal AD=-5.83e-15  solve=-9.33e-15
```

Nine significant figures, and both marginals ~1e-14 -- confirming algebraically what
the audit derived: **(A) and (B) are the same function to first order.** That stand's
gradient ANSWERS: 71 segments, 0/47 non-finite, no refusal, in 2.91 s.

**So the century failure is state-specific, not systemic.** The prime suspects are the
two branches keyed on passive values inside the flux:

* `roots.hpp:1540` -- `else if (std::is_same_v<T, double> && std::abs((collar_at -
  soil_at) - grav_head_z_[i]) < 1e-8)`. **The double path snaps that layer's flux to
  zero and the active path does not**, by explicit design: *"Left in place at double
  because the forward model's numbers are the snapped ones."* Where it fires the two
  paths are different functions and every derivative of them differs.
* `roots.hpp:1497` -- the equal-potentials arm is a **first-order-only lift**, so its
  curvature reads as exactly zero.

## The sentinel is not a barrier

`dprofit_at_collar_psi` returns an exact `0.0` where the collar is shut down or the
ci solve is infeasible. Asked whether anything depends on it: **two lines, both in
`differenced_curvature` (`gradient.hpp:625-626`)**, and its own comment says why --
*"the `feasible` out-parameter that would distinguish it is not carried through the R
binding."* The solve itself never reads the sentinel; it checks `ok_lo`/`ok_hi`
**before** the pin tests. A tree-wide grep for any other exact-zero test on a
marginal finds none.

So the sentinel's only value-consumer is the finite-difference referee for a second
derivative, and it exists in that form only because a bool could not cross an R
binding. **Under this rearchitecture both go.** It is not an obstacle; it is a
consequence of the thing being removed.

## What A subtracts

* **A whole scalar type and its vocabulary**: `directional_adjoint_scalar`,
  `directional_adjoint_tape`, `seed_inner_direction`, `directional_adjoint`,
  `plain_adjoint`, `CarriesDirectionUnderAdjoint`. odelia's scalars drop from three
  to two, and `xad::fwd_adj` stops being needed at all.
* **`implicit_value`'s second correction** -- the `if constexpr (SecondOrder<S>)`
  block, the `SecondOrder` concept, the second `record_with_derivatives`, and the
  paragraph explaining first-order-right/second-order-wrong.
* **The shadow second-order model**: both Taylor coefficients above, plus
  `ConditionCurvature`, the `condition_collar_slope` hand formula,
  `differenced_curvature`, `collar_step`, `shrink_decades`, and the sentinel logic.
* **The threaded `CollarCondition`** -- `collar_at`'s comment says an interior point
  is *"the only kind whose condition is a second derivative, so it is the only one
  whose gradient had to be taken in forward mode and handed over"*. Under A every
  kind's condition is first order, so the struct threaded through
  `collar_condition` -> `record_leaf_outputs` -> `collar_at` -> `outputs_at` goes.
* **The leaf's `static thread_local` tape** -- module state on a hot path.

## What A unlocks

* **The seam goes.** The leaf's derivative stops crossing as a number and composes on
  the caller's tape like every other closure. The interior point stops being special.
* **A failure class becomes unrepresentable.** `to_passive(...)` at an operating point
  is *correct* for a first derivative. Every defect in this document requires a
  second derivative of a first-order-correct assembly.
* **Performance twice over**: a nested `fwd_adj` scalar carries a dual value and a
  dual tape payload per operation, roughly 2x first order; and the per-operating-point
  tape (once measured at 89 s of a 217 s gradient) is replaced by the live one.

## Designed from the start

**M is the model's function and π is derived from it.** Today π is primary and M is a
hand-written sibling -- which is why M exists twice, at two scalars, in two
implementations, and why the two disagree. Under A: the solve roots M at `double`, the
gradient differentiates M once, π's row is the envelope theorem, and every closure in
the leaf is identical in shape. *One fact, one representation.*

"Inevitable" is the test and it passes: an argmax closed by a first-order condition
points at differentiating **the condition**. Differentiating the objective twice is
the decision that created everything above.

**The honest cost.** Templating M means templating its nested ci and psi_stem
root-finds -- real work, but `profit_at` already proves it achievable, doing exactly
that for sigma and ci. And the ladder is the referee: 673 assertions in 45 s.

---

# The root cause, localised to one point in 2,829,445

Threshold raised to a relative gap of 0.5, century stand, every interior point
compared against a centred difference of the solve's own marginal. **One
disagreement:**

```
rel=4.57  curv AD=34.41422577  diff=-9.633303787
marginal AD=-1.454809563e-06   solve=-1.454809794e-06
d(x-h)=1.710591982e-05(1)  d(x+h)=-1.75448044e-05(1)
x=1.798486012   nearest_soil=5.606982123e-08
```

Three facts, and together they name the culprit.

**1. The two marginals agree to seven significant figures.** `profit_at` and
`dprofit_at_collar_psi` are the same function, and its FIRST derivative is right
even at this point. This **rules out `roots.hpp:1540`'s `is_same_v<T,double>`
gravity snap**: a different-function defect moves the first derivative too, and it
does not move. The scalar-gated branch is a real defect and is NOT this one.

**2. Only the second derivative diverges** -- 4.6x relative, sign flipped.

**3. `nearest_soil = 5.6e-08`.** This is the single state in 2.8 million where the
collar nearly coincides with a soil layer's potential. It sits just OUTSIDE the 1e-8
equal-potentials threshold, so that arm does not fire and the general branch runs
with a near-degenerate flux numerator.

So: same function, correct first derivative, wrong second derivative, at a
near-degeneracy in the root/soil flux. That is `roots.hpp:1598`'s second-order
Taylor surrogate `c.integrand_deriv` -- whose sibling first coefficient `c.deriv`
(`:1595`) is the **interpolant's** slope while it is the **closed form's**. Two
different functions supplying the two coefficients of one lift, which is precisely
what blows up near a degeneracy.

## What this does to the options

**It is now evidence for A rather than taste.** The first-order path is demonstrably
correct at the exact point where the second-order path fails. A is built on the half
that works and deletes the half that fails -- and the surrogate is only needed
because something takes a second derivative of it.

Ranked by what the evidence supports:

1. **A -- differentiate the residual once.** Deletes the surrogate, the nested
   scalar, and the failure mode. Measured support: first derivatives correct to 7-14
   digits everywhere including the offending point.
2. **Fix `roots.hpp:1598`** so both coefficients of the lift come from the same
   function. Small, targeted, and leaves the shadow second-order model in place with
   still no referee.
3. **Guard the near-degenerate configuration.** Treats the symptom; the surrogate
   stays wrong wherever else it is stressed.

`roots.hpp:1540` and `canopy_shape.h:284` are separate, real defects found on the
way. The second is fixed; the first is a derivative of `1/r_R` against a
locally-constant forward function, and its value gap is discarded at the plant
boundary.

## The instrument, and its price

`PLANT_COMPARE_COLLAR_CURVATURE` compares the AD curvature against a centred
difference at every interior point and prints only disagreements above 0.5. It costs
a leaf copy and two marginal evaluations apiece -- the century gradient goes from
108 s to 708 s -- so it stays environment-gated. It is the check that turns "the
curvature is wrong somewhere" into one line of output, and there was no way to ask
that question before.

---

# UNBLOCKED: the century fixture answers

```
forward_s     36.22
gradient_s   391.46
segments        169
metric 1: 0/47 non-finite | refusal: NONE
metric 2: 0/47 non-finite | refusal: NONE
metric 3: 0/47 non-finite | refusal: NONE
```

**The first real gradient this fixture has ever produced.** And `segments = 169` is the
number that opened this whole investigation as a supposed regression -- it was the
honest count all along, never reported because the gradient always refused.

## The chain, end to end

1. The layer's mean conductivity is a **divided difference** of a TABULATED cumulative
   curve: `span / (G(max) - G(min))`.
2. At one operating point of 2,829,445 the collar came within **5.6e-08** of a soil
   layer's potential, so that span is 5.6e-08 and the denominator differences two
   nearly-equal table reads.
3. The VALUE survives it (~4e-10). Every derivative divides by the span again:
   `duptake_dpsi` carries ~0.7%, and the AD curvature -- which differentiates the value
   path TWICE -- carries ~0.13 relative.
4. The corrupted marginal is what the collar solve roots, so it returned a **MINIMUM**
   of profit.
5. plant's guard refused to divide by a positive curvature -- **correctly** -- and
   refusal is metric-level, so 3 metrics x 47 columns went not-a-number.

One cohort at one instant, and the whole census lost.

## The fix, and why this form

Below the crossover the mean of the integrand over the interval is its **midpoint
value**, to O(span^2). Written as ARITHMETIC from the curve's own closed form -- one
exp and one pow -- so AD supplies every order and both trait rows exactly. No
differencing, no cancellation, and no lift whose value comes from a tabulation while
its coefficients come from two other functions.

`vulnerability_curve_at<T>` is that closed form at any scalar and the double
`vulnerability_curve` delegates to it: **one definition**. It is the cumulative
INTEGRAL that needs tabulating, and differencing that integral is what caused all of
this.

Applied to both paths, because they have different consumers and I got it wrong the
first time: `duptake_dpsi_impl` feeds the marginal and therefore the SOLVE, while the
templated `uptake` is what plant's curvature is differentiated through. Fixing only
the first moved the operating point and left it convex.

## The threshold is measured, not chosen

`test_leaf`'s "the mean conductivity" table differences the two forms across eleven
decades of span and finds a clean V bottoming at ~1e-11:

| span | rel gap | regime |
|---|---|---|
| 1e-2 | 5.751e-07 | midpoint truncation, span^2 |
| 1e-4 | 5.700e-11 | |
| **1e-5** | **9.763e-12** | **crossover** |
| 1e-7 | 4.102e-10 | difference cancellation, 1/span |
| 1e-11 | 1.370e-05 | |

## What the session's wrong turns were worth

Three hypotheses died by measurement, and the last two died because **the instrument
was the thing at fault**:

* a finite difference at 1e-6 straddles a 5.6e-08 feature by 32x, and at 1e-8 and
  below is swamped by the marginal's own ~1e-6 noise divided by the step. Refined
  across three steps it read -9.63, +166, -10588. **It never converged, so it was
  never evidence** -- and a probe built on the same step size reported zero exceptions
  in 2.8 million.
* the two analytic routes agreed with each other because they **share the corrupted
  input**, not because they were right. Agreement between routes is only evidence when
  the routes are independent, and these were not.

The rule this leaves: near a coincidence like this, **no finite difference is a
referee**, and two routes agreeing prove nothing until you have checked what they
share.


---

# All three sites, and the referee the region can actually have

`d2uptake_dpsi2` had the worst of the three cancellations, because `quotient_d2T` is
built ON `quotient_dT` -- so the numerator that already spent one order of the span
spends another. Fixed the same way, which completes the set:

| site | consumer | fixed |
|---|---|---|
| templated `uptake` | what plant's curvature is differentiated through | yes |
| `duptake_dpsi_impl` | the marginal, and therefore the SOLVE | yes |
| `d2uptake_dpsi2` | `marginal_collar_slope()`, the second analytic route | yes |

**And all three now read ONE definition of the curve.** `duptake_dpsi_impl`'s midpoint
reads had been taking the CLAMPED TABLE while the other two read the function;
`vulnerability_curve_at<T>` and `vulnerability_curve_slope_at<T>` are that one
definition, with the double versions delegating. `f''` comes from a tangent through the
same closed form rather than a hand-derived sibling that could drift.

That was the original defect stated exactly: a lift whose value came from a tabulation
and whose two coefficients came from two other functions.

## The referee, which is continuity rather than a difference

A difference cannot check this region -- that is *why* the midpoint form exists -- so
the new check sweeps the collar onto a layer's potential across the crossover and
requires the sequence to stay smooth and finite:

```
span       dE/dT                  d2E/dT2
5.0e-03    7.68627512125918e-06   -2.7085922002691e-08
1.0e-05    7.68640995784061e-06   -2.69753108270189e-08   <- crossover
5.0e-06    7.68641009250731e-06   -2.69615862470371e-08
5.0e-08    7.68641022596688e-06   -2.69614732344725e-08
```

No jump at the switch; worst step-to-step change 1.4e-05 and 3.8e-03, the latter at the
crossover itself and being the divided difference's own error there. Before this the
sweep went to noise below ~1e-07.

## Where it lands

```
forward_s  32.15   gradient_s  112.16   ratio 3.5
segments   169     0/47 non-finite      refusal: NONE
```

odelia 346, ladder 673, non-ladder 3295, test_leaf 1121 -- all at baseline. **And the
plan's cost model finally has numbers taken on a fixture that answers**, which every
figure before this was not.

---

# The helper, and where increment 2 actually starts

## Seven copies of one mean

Every derivative of the uptake is a MEAN over the layer's suction interval -- the
conductivity curve for the resistance, one of its trait derivatives for a trait row.
Seven callers each formed their own as `integral / span`, each "replicated bit-for-bit
from uptake_impl" in their own words, and each inheriting the same cancellation.

They now read `layer_mean`, `layer_mean_dtrait`, `layer_mean_dbound`,
`layer_mean_dtrait_dbound`, `layer_mean_dbound2` and `layer_mean_dbound_mixed`, and
**not one of them builds an integral any more**. `layer_integral` -- the replicated
construction -- exists once.

Writing them in means is what removes the span from the algebra: `k*span/integral` is
`k/mean`, `-k*span*dinteg/integral^2` is `-k*mean_d/mean^2`, and the second
derivatives are the quotient rule on those. The span was what the accuracy was being
spent on, and it is gone from every formula.

Two further collapses fell out: the choice of accessor past the knots (issue #1's,
"and NOT the conductivity read") is made in one place instead of at each caller, and
`integrand_dtrait_kernel<T>` gives the trait curve's value and its psi-slope from one
expression.

## Two of my own errors, and the check that caught them

⚠️ **The midpoint limits are f'/2, f''/3 and f''/6. I first wrote the last two as
f''/4.** The continuity sweep could not see it -- those terms contribute little to
dE/dT at the state it walks -- so it needed a check that compares the two forms
directly. They meet at 5.4e-06, 8.8e-05 and 2.0e-06, which is what confirms the
constants: an f''/4 would bottom out near 25%.

⚠️ **And that check found a second error: ONE threshold was wrong for two of three
quantities.** The divided difference divides by the span once for the mean, twice for
its bound derivative and three times for the second, so each degrades a decade or more
earlier than the last:

| span | d/dbound | d2/dbound2 | mixed |
|---|---|---|---|
| 5.0e-03 | 5.131e-04 | 4.653e-04 | **6.032e-07** |
| 5.0e-04 | 5.133e-05 | **1.595e-06** | 8.811e-05 |
| 5.0e-05 | **5.436e-06** | 2.948e-02 | 5.897e-02 |

A single 1e-5 left both second derivatives on the degraded form across a band two and
three decades wide. Now 1e-5, 5e-4 and 5e-3, each measured.

**The lesson repeats the session's:** a quantity whose referee cannot discriminate an
error is a quantity with no referee. The continuity test was real and passed; it was
simply blind to this, and only a direct comparison of the two forms could see it.

## Where increment 2 starts, and why not here

`implicit_value<S>(p*, dM/dp, M)` needs M evaluated with ACTIVE PARAMETERS. M contains
`dE_up/dp`, which is `duptake_dpsi`, which is `double`-only. So increment 2's enabling
step is templating the supply's collar derivative:

1. generalise `uptake`'s `G_integral` lift -- it is a local lambda capturing eight
   pieces of per-loop context (`use_integral_cache`, `collar_at`, `soil_at`,
   `G_at_T_collar`, the layer index, `at_scalar`, `root_b0`, `root_c0`)
2. template `layer_integral`, `layer_mean` and `layer_mean_dbound` on it
3. template `duptake_dpsi_impl`, which is now four lines of arithmetic over those
4. build M at scalar S in `leaf_model`, and rewire `collar_at`
5. delete `CollarCondition`, `collar_condition`, `plain_adjoint` and plant's threading

**The helper is what makes 1-3 tractable**: the enabling step went from seven
scattered rewrites to three functions, because no caller forms an integral any more.

And there is a referee waiting for it: `d(duptake_dpsi)/dT` taken at a tangent must
equal `d2uptake_dpsi2` -- two independent routes to one number, which is the only kind
of check this region admits.

⚠️ **Also still unrefereed, and the reason increment 2 is worth doing beyond
tidiness:** `cond.gradient` is `dM/dtheta = d2(profit)/dp dtheta`, the same
second-order class as the curvature, from the same nested pass, and nothing checks it.
Only the curvature has been measured. Under increment 2 it comes from `implicit_value`
recording M's own tape -- first order, and refereeable.

---

# Increment 2: what landed, and the one closed form that blocks the rest

## Three of the five steps subtracted before writing any code

The scoped plan was: generalise the `G_integral` lift, template the layer-mean
helpers, template `duptake_dpsi_impl`, build M at scalar S, rewire `collar_at`.

**Steps 1-3 turned out to be unnecessary.** Inside `implicit_value(p*, dM/dp, F)`, F
is called with the collar PASSIVE and only the parameters active -- so `duptake_dpsi`
never needs templating on the collar. What is needed is `dE_up/dp` carrying its
PARAMETER derivatives, and the model already computes those in closed form:
`d2uptake_dpsi_droot_curve`, `d2uptake_dpsi_dpsi_soil`, and `duptake_droot_carbon`'s
mixed term -- all tested, none with a production consumer.

Two more fell out while reading: **`transpiration` IS `flux`** by the T1 residual
(`kmax*(G(sigma) - G(collar)) - flux = 0`), which `profit_at` already builds at S, so
no lift for it; and `LeafInputs::rebind_from<double>()` already exists, so the passive
inputs for `dM/dp` come from the active ones with no new mapping.

## What landed

**odelia: the theorem reports, and the policy belongs to the caller.** `implicit_root`
and `implicit_value` are the same theorem -- the header says "the two differ only in
whether the row is supplied or taped, and both take the slope". They also differed in
what a degenerate slope does, and that difference is real: a BOUND's value IS what the
equation defines, so a missing row is a structural zero nothing can detect and it must
stop; an INTERIOR optimum is still the point it was, and an output the envelope
theorem spares does not read the collar at all, so it can report. That is now
`implicit_value_reported` (the theorem) plus `implicit_value` (it, and the stop), with
the choice made at the call site instead of by which name you reach for.

**phylloptim: the marginal reads its inputs.** `marginal_assembled` reached for the
leaf's MEMBERS -- kmax, the stem parameters, and the kernels' vcmax/jmax/curvature/
respiration through their one-argument overloads. At double that is the same
arithmetic; at an active scalar it is a silent zero in every parameter it touches.
Verified as a no-op where it must be: the closed slope still matches a difference to
the identical **2.560e-09**.

## The one thing that blocks the rest

Building M at an active scalar needs `d(dE_up/dp)/d(theta)` for EVERY active input.
The model has it for traits, soil potentials and layer carbon. **It does not have it
for the two resistance inputs** -- `r_R_H_min` and `r_R_V_sum`, which are what plant
actually makes active, having mapped carbon onto them on its own side.

They are mechanical from `r_R = k/g + V` and
`dE_i/dT = (r_R - num * dr_dT)/r_R^2`, and they can be refereed against a difference
in the fast harness. But they are hand algebra of exactly the kind that produced two
wrong constants in this session's previous increment -- both caught only because a
direct referee was built first. So the order is: **write the referee, then the
algebra**, not the other way round.

## What deleting the interior case's `implicit_root` will take with it

`implicit_root` has exactly ONE caller in the tree: `collar_at`'s Interior case. When
that moves onto a taped residual, the following go with it -- `implicit_root`,
`CollarCondition`, `Leaf::collar_condition`, `odelia::ode::plain_adjoint`, and the
threading of a condition struct through `record_leaf_outputs` -> `collar_at` ->
`outputs_at` in plant.

⚠️ And the reason it is worth doing is not tidiness. `cond.gradient` is
`d2(profit)/dp dtheta` -- the same second-order class as the curvature, from the same
nested pass over an assembly whose second-order content nothing referees. Only the
curvature was ever measured, and it was wrong. Under the taped residual that quantity
becomes first order and refereeable.

---

# Increment 2 done: one form for every collar closure

```
Interior                   -> implicit_value_reported(p*, marginal_collar_slope(), marginal_at)
PinnedWet, ShadeDeath      -> bound_at -> implicit_value
PinnedDryRootCrit          -> bound_at -> implicit_value
PinnedDryRootPsiCrit       -> the bound IS the trait
HydraulicShutdown          -> does not move
```

`collar_at` had one case that did not look like the others. The bounds each closed on
a residual; the interior point called `implicit_root` with rows handed over as
NUMBERS -- because those rows needed a second derivative of the profit, which is the
thing this session found wrong.

## Deleted

* `odelia::implicit_root` -- the supplied-row form. One consumer in the family, and it
  is gone.
* `odelia::ode::plain_adjoint` -- its only use was inside the nested pass.
* `Leaf::CollarCondition` and `Leaf::collar_condition` -- the struct and the pass that
  filled it.
* the condition threaded through `record_leaf_outputs` -> `collar_at` -> `outputs_at`
  in plant: one fewer parameter on two calls, one fewer type to learn.
* one of the refusal message's two readings of the marginal. It carried both because
  the question was whether they agreed; they do, and the assembly that made them
  differ is gone.

odelia's R tests are RETARGETED, not deleted: the same theorem reached through a
residual whose derivatives ARE the two slopes and whose value at the root is zero, so
every expectation survives -- the quotient, the chain through the root, the fold
reported rather than thrown, and a non-finite row refused after the quotient.

## Added, and why each is the smaller thing

* `implicit_value_reported` -- the theorem, returning its report. `implicit_value` is
  it plus the stop. The two forms differed in what a degenerate slope does and that
  difference is REAL: a bound's value IS what the equation defines, an interior
  optimum is still the point it was. The policy moves to the call site.
* `duptake_dpsi_at<T>` -- the supply's collar derivative at any scalar, four lines
  over the shared layer means. The marginal needs it; nothing else could supply it.
* `collar_coords_at<S>` -- the flux, the stem potential and the intercellular CO2,
  built ONCE and read by both `profit_at` and `marginal_at`, which would otherwise
  carry the same two implicit closures apiece.

## The referee came before the algebra

Twice this session an error survived because the check could not discriminate it. So
the templated supply derivative was refereed two ways before anything was wired to it:

* against the double form it replaces: **gap exactly 0.000e+00**, bit-identical
* against `d2E_from_soil_dpsi_collar2`, computed by an entirely different route:
  **7.327e-15**

## And one lean failure of my own, found by reading rather than timing

The helper made every caller read `layer_mean` and then `layer_mean_dbound`, and the
second formed the integral AGAIN -- four table reads per layer where there had been
two, and two passes of lifts on the active path where one will do. The mean is now
passed. Cleaner and slower is not the trade.

⚠️ **No timing is claimed from today.** The machine is under a load average of 13 from
another user's jobs and a forward pass that runs in 32 s clean took 53 s. This was
found in the call graph, not on a clock.

## What plant gained

The guard now tests the SAME slope the closure divides by. It used to read
`condition.slope` from one pass while the closure divided by it and took its parameter
rows -- `d2(profit)/dp dtheta`, the same second-order class as the curvature that came
back positive at an interior maximum -- from the same unrefereed place. Those rows are
now taped from the condition itself.

---

# The two forms collapse, and the gradient's cost, measured

## `implicit_value_reported` goes, and the `point` channel with it

I added it earlier the same day, arguing the policy belonged to the caller: a BOUND
must stop, since its value IS what the equation defines and a missing row would be a
structural zero nothing could detect, while an INTERIOR optimum could carry on and say
so, because the envelope theorem spares the objective. Both statements are true of the
theorem. **Neither is true of the consumer**, and reading the consumer is what settled
it:

* the report was filled by ONE of `collar_at`'s five arms;
* it was read in exactly ONE place, where plant turned it into `refuse(...)`;
* which is what the catch around the throws already does, at the same metric-level
  grain.

Two mechanisms, one outcome. Deleted: the function, `LeafOutputs::point`, the
out-parameter on `collar_at` and `outputs_at`'s signature, and plant's branch. What is
left is one theorem with one way to fail, and `collar_at` is finally one shape for all
five kinds with nothing threaded through it but the inputs.

The R harness catches the throw and reports it back, so every expectation survives.

## The gradient costs a third more, and that is measured rather than guessed

Both arms built from source, INTERLEAVED in one session, three pairs:

| rep | forward before -> after | gradient before -> after | ratio | load |
|---|---|---|---|---|
| 1 | 41.71 -> 39.98 | 140.45 -> 179.64 | 1.28 | 10.4 / 8.9 |
| 2 | 35.14 -> 39.63 | 131.89 -> 186.05 | 1.41 | 12.4 / 12.0 |
| 3 | 39.40 -> 32.94 | 109.66 -> 144.11 | 1.31 | 2.7 / 1.2 |

**+33% on the gradient, and nothing on the forward** (mean ratio 0.98). The ratio holds
across loads from 1.2 to 12.4, which is the whole reason for interleaving -- the
absolute numbers move by 60% between reps and the ratio does not. Both arms answer
identically: 169 segments, all three metrics, no refusal.

**Where it goes.** The old interior closure took ONE nested pass over `profit_at` and
read three things off it. The new one evaluates `marginal_at` at the active scalar,
which builds the operating point's coordinates again and then does a full per-layer
supply-derivative pass -- work the old path got implicitly from differentiating the
flux twice on a tape it was already paying for.

**What it buys**, so the trade is on the table rather than implied:

* `dM/dtheta` is first order and refereeable. It was `d2(profit)/dp dtheta` from a
  nested pass, the same class as the curvature that came back positive at an interior
  maximum, and NOTHING checked it.
* one closure form for all five kinds, and five concepts gone -- `implicit_root`,
  `plain_adjoint`, `CollarCondition`, `collar_condition`, `point`.

**Where to look if the third is wanted back**: `collar_at` builds the coordinates for
`marginal_at`, then `outputs_at` builds them again for `profit_at`, per node per step.
They are at different collars -- one is the residual's variable, the other the placed
value -- so they cannot simply be shared, but that is where the duplicated work is.

---

# The gradient's third: root cause

The +33% was real, and it is one function. Found with the four-phase discipline;
what it cost to find was two profiles and one grep, because the counted numbers
ruled out most of the space before any timing was read.

## What the counts ruled out first

Both arms profiled back-to-back in one session at 250 Hz, arm A the pre-increment-2
commits and arm B increment 2, each verified by grepping its INSTALLED headers
rather than by the directory it sat in:

| | arm A | arm B |
|---|---|---|
| forward | 37.06 s | 34.82 s |
| gradient | 118.04 s | **154.34 s** |
| rate evaluations | 20,286 | 20,286 |
| placements | 2,333,500 | 2,333,500 |
| swept ranges | 169 | 169 |
| metrics | 3 | 3 |

**Every counted number is identical, so it is not more calls -- it is more work per
call.** And the forward is unchanged, so it is the recording path. Sample totals
reconcile with the wall clock to under 1% on both arms, which is what says the
profiles are of the thing that was timed.

## What the profile says, and what it eliminates

Self time, arm A -> arm B, in samples:

| | A | B | delta |
|---|---|---|---|
| `computeAdjointsToImpl` + its lambda | 6,826 | 11,440 | +4,614 |
| `OperationsContainerPaired::for_each` | 2,140 | 2,813 | +673 |
| `append_n` | 1,454 | 1,987 | +533 |
| `unregisterVariable` | 1,113 | 1,652 | +539 |
| `std::max` (the slot high-water mark) | 995 | 1,498 | +503 |
| `memset` + `__fill_a1` (`initDerivatives`) | 859 | 1,840 | +981 |

Those sum to about 8,500 against a total delta of 8,523. **Essentially all of the
regression is XAD bookkeeping -- writing the tape and walking it -- and none of it
is the model's arithmetic**, which got CHEAPER: `uptake_impl` 5,285 -> 4,544,
`duptake_dpsi_impl` 2,799 -> 2,385, `toms748_solve` 8,498 -> 8,001. That eliminates
the double-precision path, the midpoint work and the layer means in one reading.

## The cause: a tangent above the adjoint, on plant's tape

`marginal_assembled` is **11.6% of the whole profile, about 22 s, and does not
exist in arm A at all** -- roughly 60% of the regression in one function.

`leaf_model.hpp:1197` is `using TT = typename xad::fwd<T>::active_type`. At the
gradient `T` is `active_scalar<double>`, so **TT is `FReal<AReal<double>>`: a
tangent wrapping an adjoint.** Every operation on it carries a value and a
derivative, both of which are `AReal<double>`, so **both halves record onto
plant's tape** -- which is then swept once per census metric, three times.

Three kernels and thirteen `lift`s run at that scalar per interior placement,
2,333,500 of them. The focused profile settles what they spend it on: inside
`marginal_assembled`, `exp_inline` is about 148 samples and everything else is
`registerVariable`, `std::max`, `pushLhs`, `append_n` and `BinaryExpr`. **The
arithmetic is a rounding error; the cost is the tape.**

Beside it: `collar_coords_at` at 3,484 samples is the SECOND coordinate build at
the active scalar, and `duptake_dpsi_at` at 811 is the extra active per-layer walk.
Those are the rest of the delta.

⚠️ **Increment 2 did not delete the nested scalar. It deleted odelia's NAMED one
and rebuilt the opposite nesting by hand in the hot path.** `directional_adjoint_scalar`
was `AReal<FReal<double>>`, adjoint outside; this is `FReal<AReal<double>>`, tangent
outside. It does not grep as what it is, because it is spelled
`xad::fwd<T>::active_type` at the use site. And `ode_interface.hpp` claimed beside
the deleted alias that *"no tangent scalar wraps an adjoint one"* -- which the
family had been doing, per placement, since increment 2 landed.

## The second defect, which is free

`marginal_collar_slope(in.profit.rebind_from<double>())` is evaluated **twice per
interior placement with identical arguments**: `tf24_strategy.h:1352` for the
curvature guard, `leaf_model.hpp:4882` as the closure's `dFdy`. The comment above
the first says *"⚠️ THE SAME NUMBER THE CLOSURE DIVIDES BY"* -- so the code states
the identity and then computes it a second time. It is double-precision work, so
it is a small share of the regression; it is still two sources for one fact, and
the guard's agreement with the divisor is today a coincidence of construction
rather than something that cannot be otherwise.

## What is NOT available, priced so nobody pays for it twice

* **Dropping the tangent's value half.** Only `xad::derivative(...)` is read off
  the three kernels, so the value looks discardable. It is not: forward mode forms
  the derivative FROM the values, and those values carry the parameter rows, so
  their statements are load-bearing.
* **A closed form for `A'` and `C'`.** That is the hand-written second-order
  sibling this whole increment removed, and the one that produced two wrong
  constants earlier in this session. Not that.
* **Sharing the two coordinate builds.** They are at the same collar VALUE and a
  different derivative structure -- `marginal_at` needs the collar passive for the
  theorem, `profit_at` needs it active. Same numbers, genuinely different
  recordings.

## What is available

1. ~~**Sweep once for three metrics** (`one-reverse-pass.md` mechanic 8,
   `xad::adj<T, 3>`). The regression is amplified threefold by being walked once
   per metric, and the sweep is the larger half of it.~~ **MEASURED SHUT** -- see
   "The sweep is not walk-bound" below. The walk is not what three sweeps repeat
   that costs anything: at `N = 3` one wide walk beats three narrow ones by 1.06x,
   and by `N = 8` it is 0.57x, i.e. slower. The premise that the cost is
   "amplified threefold" is wrong.
2. **The duplicated slope**, above. LANDED -- `collar_at` now takes it from the
   caller that already refused on it.
3. **Accept it.** What the third bought is stated in the previous section and has
   not changed: `dM/dtheta` is first order and refereeable where it was an
   unrefereed second-order pass, and five concepts are gone.

---

# Against ad/v3-forward: two regressions, not one

The remembered figure was right. Three arms, interleaved, two reps agreeing within
0.5%, on a quiet machine, every arm identified by grepping its INSTALLED headers:

| arm | forward | gradient |
|---|---|---|
| `ad/v3-forward` (odelia 03a14a9, phylloptim edde81f, plant 68a4fcc3) | 30.68 / 30.74 | 103.27 / 103.44 |
| the midpoint era, before the helper | 35.02 / 34.97 | 109.67 / 109.81 |
| HEAD | 32.50 / 32.62 | 142.96 / 143.40 |

`evaluations` 20,286 and `placements` 2,333,500 on **all three**, so the trajectory
never moved and the arms are doing the same work.

⚠️ **The confound this looked like it had, and does not.** The v3 arm REFUSES on this
fixture -- it predates the midpoint form -- so its gradient could have been cheap
because it did less. It is not: v3 already carries the latched refusal rather than the
exception, and a latched refusal skips only the final `record_with_derivatives` per
non-objective output. `collar_at` and `outputs_at` run in full either way. Both arms
sweep the whole recording.

**+38.6% on the gradient, in two independent pieces.**

## Piece one: the midpoint era, +6.2% gradient and +14% forward

The forward is the cleaner signal, because it carries no tape. Profiled both ends:
7,940 samples against 8,496, **+556 ≈ +2.2 s**, agreeing with the clock.

| | v3 | HEAD | delta |
|---|---|---|---|
| `use_midpoint_mean` | **did not exist** | 113 self | **+113** |
| `root_vuln_integral_at` (cum) | 619 | 782 | +163 |
| `uptake_impl` (cum) | 1,112 | 1,291 | +179 |
| `duptake_dpsi_impl` (cum) | 1,342 | 1,580 | +238 |

**`use_midpoint_mean` alone is a fifth of the forward regression.** It is inlined and
it is two comparisons -- and it runs at **ten call sites, per layer, per evaluation**,
tens of millions of times, to select a branch that fires at ONE operating point in
2,829,445. The rest is the restructured mean path reading the curve more often.

**The defect is not the correction, it is where the question is asked.** The span is a
property of the layer and the collar, fixed for one evaluation of the supply; the
regime it selects is asked once per QUANTITY per layer per evaluation instead. And
there are three thresholds, so there are three regimes, not one -- which is a
structure the loop should carry, not a predicate each caller re-derives.

The layer-mean helper later returned about half of it (35.0 -> 32.5), by removing the
second integral each caller formed.

## Piece two: increment 2, +30.6% gradient

`marginal_assembled` at `FReal<AReal<double>>`, recorded on plant's tape and walked
once per metric. Rooted causally in the section above.

## And the escape that is measured shut

`one-reverse-pass.md` mechanic 8 -- three metrics in one walk at `xad::adj<T,3>` --
is the lever this regression makes look attractive, and **it was already measured and
it is not there**: odelia `828cd83` reports width three at **1.15x to 0.97x**, from 15%
slower to 3% faster, decided only by whether the derivative array still fits in cache
at three times the size. The walk is shared; the scatter is N times the bytes. Both
places that proposed it now carry the number.

---

---

# What the leaf's derivative costs, measured

The design these produced is **`one-order.md`**, which is the prescription and stands
on its own. What is here is the evidence, in the units a design decision turns on:
counted numbers, not timings. Four probes produce all of it and can be re-run --
`probe_leaf_tape`, `probe_rank`, `probe_primitive` in `phylloptim/tests/cpp`, and
`probe_width` in `odelia/tests/standalone`.

## One placement, on plant's tape

At five soil layers, the century fixture's width, at an interior point:

| | statements | operations |
|---|---|---|
| `collar_at` | 616 | 858 |
| ...`collar_coords_at` | 117 | |
| ...`duptake_dpsi_at` | 101 | |
| ...`marginal_assembled` | **396** | |
| `outputs_at` -- everything plant reads | 245 | 399 |
| **one placement** | **861** | **1,257** |
| the supply alone, `E` and `S` | **187** | |

**The collar residual is three quarters of the leaf's tape and it produces one
number.** Plant records one of these per cohort per stage per step, 2,333,500 times.

## The two ratios that decide where to look

| | |
|---|---|
| record one placement, marginal, on a live tape | 28.2 us |
| sweep it once | 1.80 us |
| **record : sweep** | **16 : 1** |
| clear + release + register, on a REUSED tape | **0.14 us** |

⚠️ Sixteen to one means **every proposal that moves tape between tapes argues about a
sixteenth of the cost.** What matters is what gets recorded at all. And the cycle is
free, so it was never the objection to a private tape -- though constructing a `Tape`
reserves 192 MiB of chunks, so one must be a held member.

## The nesting, which is the whole of increment 2's regression

Same three kernels, same point:

| | statements |
|---|---|
| at the working scalar `A` | **31** |
| at `TT = FReal<A>`, a tangent ABOVE the adjoint | **566** -- electron 197, colimited 288, cost 81 |
| | **18.3x** |

Not 2x. `FReal` holds value and derivative as separate members and assigns each
separately, so the expression template cannot fuse across the nesting.

⚠️ **The other nesting is nearly free.** `outputs_at` at `AReal<FReal<double>>` --
adjoint above tangent -- is **261 statements against 245**. But that route is not
usable as it stands: the probe read `d2(profit)/dp d(vcmax)` as **exactly zero**
against a differenced 2.97e-03, because `to_passive` strips every layer and every
`implicit_value` correction is built as `x - to_passive(x)`.

## Landed: a dual whose derivative is structurally zero

`J0` was built at `TT` from four `lift(...)` arguments -- value set, direction zero --
so its tangent half carried no information at a cost of 197 statements. Evaluated at
`T` and lifted it is the same `TT`.

**1,057 -> 861 statements.** Four interleaved pairs on a quiet machine, forward
unchanged at 32.6 s:

| rep | before | after |
|---|---|---|
| 1 | 143.44 | 132.55 |
| 2 | 143.55 | 131.44 |
| 3 | 142.72 | 131.52 |
| 4 | 143.32 | 132.05 |

**143.3 -> 131.9 s, -7.9%**, spread under 0.6%. So an 18.5% cut in the leaf's tape is
7.9% of the gradient: **the leaf is about a third of it**, and that is the multiplier
to carry.

## The rank, proven on this model

`probe_rank` is built so it can fail. Inputs that reach profit DIRECTLY must not fit,
and they do not -- relative residual **1.000**, the whole value. It also reports how
much of the `S` column is independent of `E`, because a two-column fit over collinear
columns is satisfied by anything; it is **98.4% to 99.9%**. The layers carry distinct
potentials so no result can come from an accidental symmetry.

Seven states, interior and pinned-wet, one three and five layers, wet to the root
limit, at one forward tangent with no tape:

| | worst relative residual |
|---|---|
| profit = c * E | **1.4e-15 to 9.9e-15** |
| R = a * E + b * S | **1.3e-15 to 3.6e-14** |

**Seventeen supply-side inputs collapse onto one number and two numbers, at machine
precision, everywhere tried.**

## The two slopes the model computes instead of having

`probe_primitive`, at the operating point the solve returned:

| | |
|---|---|
| `dA/dci`, closed form against the tangent | **rel 2.14e-16** |
| `dC/dsigma`, closed form against the tangent | **rel 0.000e+00**, bit-identical |
| the two kernels' VALUES at the adjoint | 26 statements |
| their SLOPES as primitives, same scalar | **13 statements** |
| the same information by the nested tangent | **566 statements** |
| | **14.5x** |

`dC/dsigma` is one line over the slope the vulnerability curve already has. `dA/dci`
is eight: the two limited rates, their own slopes, and the colimitation's quotient
rule.

---

**The design that follows from all of it is `one-order.md`.** It carries the rule, the
eight connected components, the data structure, the landing order with its referees,
and the list of what is already refuted and must not be re-proposed.

---

# The sweep is not walk-bound, and what the tape carries that nothing reads

Taken on `ad/one-program` with all three packages built at `-O2 -g` into a private
library, because the shared one was three days stale and the cached makevars carried
`-g0`, which strips the symbols the profile needs. `scripts/profile-gradient.sh
scripts/profile-stand-reverse.R`.

```
forward_s   32.74      steps 3378        placements  2,330,530
gradient_s 104.22      ratio 3.2         swept_ranges      169
rate_evaluations 20,268   metrics 3      refusal          none
```

Against the 131.9 s in the previous section, with the forward unchanged at 32.74 s
against 32.6 s -- so the fixture and the machine are the same and the gradient is
21% faster than the last figure here. `marginal_assembled`, 11.6% and about 22 s
there, is 3.9% and 4.6 s.

34,411 samples at 250 Hz is 137.6 s against 136.96 s of wall, and a focus on
`ladder_boundary_evaluations_tf24` is 26,055 samples = 104.22 s exactly. Both arms
of that reconciliation matter: the first says the profile is of the run that was
timed, the second that the gradient's share of it is not an estimate.

## Where the gradient's 104 s goes

Recording is 61.4 s and sweeping 42.2 s, of which the three walks are 38.5 s.

| | share of the gradient | s |
|---|---|---|
| XAD tape | 56.1% | 58.5 |
| libstdc++ containers -- operation pairs, the slot high-water `std::max`, `clearDerivatives` | 14.1% | 14.7 |
| libm | 14.3% | 14.9 |
| phylloptim's arithmetic | **7.1%** | 7.4 |
| odelia's interpolator | 4.2% | 4.4 |
| plant | 1.9% | 2.0 |
| boost root solvers | 1.3% | 1.3 |

Tape bookkeeping is about 70% of the gradient and the model's arithmetic a
fourteenth of it, which is the same reading the previous section took by counting
statements rather than samples.

## The sweep is bound by the derivative vector, not by the walk

XAD carries vector mode already: `Vec<T, N>` in `XAD/Vec.hpp`, `DerivativesTraits<T,
N>` -- which collapses to plain `T` at `N = 1`, so an unused width costs nothing --
and `xad::adj<T, N = 1>`. odelia writes `xad::adj<T>` and takes the default. Two
things stand between that and a wide sweep, and both are real:

* `adjoint_is_zero` in `odelia/src/Tape.cpp` recurses through a nested scalar's
  `value()` and `derivative()`. A `Vec` has neither, so a width above one does not
  compile without an overload.
* `Tape.cpp` explicitly instantiates `Tape<double>` only, under a note that the
  instantiated set is the downstream linking contract.

Patched past both in a standalone toy, every width is bit-identical to three narrow
sweeps -- gap exactly zero -- and:

| width | one wide walk against N narrow ones |
|---|---|
| 2 | 1.06x |
| 3 | **1.06x** |
| 4 | 1.19x |
| 8 | **0.57x**, i.e. slower |

⚠️ **The walk is not the repeated cost.** Tripling the derivative type triples the
bytes `derivatives_` occupies, and past `N = 4` the cache gives back more than the
saved traversal is worth. At the family's three metrics the whole prize is about
2.3 s of 104 s, for a change that touches odelia's ABI. **DO NOT re-propose
`xad::adj<T, 3>` as a way to pay for the sweep once**; the arithmetic and the memory
are per seed either way, and only the traversal is shared.

## What the tape carries that nothing reads: at most 13.4%

A counter in the sweep, on the statements whose adjoint is zero when the walk
reaches them:

```
statements 10,233,015,654   skipped 1,374,854,384   13.4%
```

Read that against the three metrics being swept separately: a statement feeding one
metric is zero in the other two walks, so wholly disjoint cones would give 66.7%.
Observing 13.4% says the metrics share nearly the whole tape, and it puts a
**ceiling of 13.4% on statements dead in every sweep** -- about 8 s of the 61.4 s of
recording. It also explains the table above: statements with a zero adjoint already
skip their operations, so not re-walking them is worth little.

One instance found and closed. `plant/qk.h` carried `result_gauss`, `mean` and `err`
as active scalars whose only consumers were `to_passive` -- they produce
`last_error` and `mean_value`, both doubles a user reads. At the active scalar
`result_gauss` recorded a statement per Gauss node and every row of it was thrown
away. Carrying the three as doubles is **8-11% of the rule's tape statements**, at
identical value and derivative, and the golden file's 223 stale mismatches did not
move.

The general form of that is a detector worth having: an active value whose every
consumer is `to_passive` is a value that should not have been active. The sweep is
the one place that can see it, because it is the only place that knows which
recording earned its keep.

## Landed here

* The duplicated `marginal_collar_slope`, 5.6% of the gradient. `collar_at` takes
  `interior_curvature` from the caller that already computed it to refuse on, so the
  guard's number and the divisor are now the same number rather than two calls that
  agree by construction -- which is what the ⚠️ above the guard always asked for.
* `qk.h`'s three passive-only actives, above.
* `std::getenv("PLANT_COMPARE_COLLAR_CURVATURE")` ran on every one of 2.33 million
  interior placements, scanning the environment for a flag unset in every run that
  is not chasing it. Latched in a function-local static.

What the three are worth together, interleaved in one session with no profiler
attached, so both arms pay the same and neither is a figure from another machine
state:

| rep | before | after |
|---|---|---|
| 1 | 102.86 | 98.18 |
| 2 | 102.19 | 97.78 |

**102.5 -> 98.0 s, -4.4%**, spreads under 0.7%, the forward unchanged at 32.05 ->
32.12 s, and placements, swept ranges, rate evaluations and refusal identical on all
four runs -- the same work, which is what makes it a speed-up rather than a
different answer. In the profile the three land where they were predicted to:
`marginal_collar_slope` 1,462 -> 737 samples (exactly halved), `QK::integrate`
4,015 -> 3,666 (-8.7%), and `getenv` gone from the profile.

---

# The gradient's needles, and what they are

Isolated cells of a trait-space grid carry gradients two orders of magnitude
above their neighbours -- at the worst, an elasticity norm of 1277 against a grid
median of 6.05, 211x. Chased with the systematic-debugging procedure, because two
plausible causes turned out to be wrong and a third would have been guessed at
next.

## Refuted first

* **An elasticity dividing by a near-zero metric.** The census at those cells is
  ordinary: 8.4 against a grid median of 10.9, and the whole grid spans a factor
  of two. `cor(log|e|, log(1/value))` is 0.40. The **raw** gradient at the worst
  cell is 5.0e+07, so the spike is in the gradient and not in the normalisation.
* **A profit curvature inside its floor.** The interior derivation divides by
  dM/dp, so a small one inflates the gradient without refusing. All three worst
  cells still answer with `gradient_curvature_floor` raised a hundredfold to
  1e-1.

⚠️ **And the first reproduction attempt failed because the trait values were read
off a rounded printout** -- `hmat` 3.72 instead of 3.72192216625689. That moved
the elasticity norm from 1277 to 7.22. It is not an aside: it is the measurement
that says how narrow the feature is.

## What it is

`fraction_allocation_reproduction(h) = a_f1 / (1 + exp(a_f2 * (1 - h/hmat)))`,
with `a_f2` = 50, is a near-step in height: 0.7% of `a_f1` at 0.9*hmat and 99.3%
at 1.1*hmat. A cohort grows through that band inside one or two ODE steps. **The
sweep differentiates the discrete trajectory exactly**, so the gradient is
dominated by which step caught the crossing -- and that changes discontinuously
with `hmat`. The integrated census averages over the transition and stays smooth.

Sweeping `hmat` through the worst cell, with `lma` held:

| offset in `hmat` | \|e\| | e[a_f1] | mass |
|---|---|---|---|
| -3e-4 | 6.69 | -5.88 | 8.4286 |
| 0 | **1276.73** | **848.67** | 8.4322 |
| +3e-4 | 11.97 | 1.10 | 8.4356 |
| +1e-3 | **1888.61** | **-1069.52** | 8.4435 |
| +3e-3 | 6.28 | -5.94 | 8.4641 |
| +1e-2 | **193.93** | 150.22 | 8.5344 |

Isolated needles at irregular spacing, with ordinary values between them, while
mass runs smoothly and monotonically through the lot. No continuous mechanism
produces a feature narrower than 3e-4 in a parameter; an unresolved discrete
event does.

Softening the step confirms it. At the needle cell, against a calm cell as the
control:

| `a_f2` | \|e\| at the needle | e[a_f1] | \|e\| at the control |
|---|---|---|---|
| 50 (default) | **1276.73** | +848.67 | 5.95 |
| 25 | 7.83 | -7.31 | |
| 10 | 12.45 | -10.84 | 10.04 |
| 5 | 8.55 | -7.61 | |

**Halving `a_f2` collapses the needle 163x** and restores the negative sign every
calm cell has. Softening does not create pathology at the control, so it is the
sharpness that matters and not the change itself.

## The same edge, in a different disguise

A trait vector that refuses to refine at all -- "Detected non-finite
contribution" -- bisects to `hmat`+`omega` at a 60-year lifetime. But
`lma`+`hmat`+`omega` and `rho`+`hmat`+`omega`, which both CONTAIN that pair, run
fine. **A failure that adding a trait repairs is not a domain violation.** It is
the same knife-edge: a point the discretisation cannot do, narrow enough that any
perturbation escapes it.

## What follows

The gradient is not wrong. It is the exact derivative of a trajectory that
resolves the maturation switch crudely, and this is the same story as the
finite-difference noise floor of 2.5% and the schedule sensitivity recorded
above: **differentiating an adaptive solver gives the derivative of the discrete
map, and near an unresolved event that is not the derivative of the model.**

* The principled repair is event detection -- force a step at `h = hmat` so the
  crossing is resolved identically every time. That is work in the stepper and
  nothing here needs it yet.
* ⚠️ **DO NOT average over the needles, and DO NOT form a covariance from a grid
  containing one.** A single cell 211x the median dominates any second moment,
  which is the first thing an active-subspace workflow computes.
* A gradient far outside its neighbourhood is a *diagnostic*: it marks an
  unresolved event, and the cheapest response is to nudge the trait a fraction of
  a percent and take the answer that is stable.

⚠️ **`a_f1` is a poor example to teach with, for the same reason it is the loudest
column.** It is the amplitude of that switch; with `a_f1` = 1.0 a plant past
`hmat` puts all of its production into seed and none into wood. Its dominance
over above-ground mass restates equation 16 rather than finding anything, it is
not a trait any database reports, and its default sits exactly on the boundary of
the admissible set, so half of its perturbation direction is meaningless.

## Real species do not fit through this parameterisation

Scoping the fingerprints demo on seven south-eastern Australian woody species --
the wet sclerophyll to cool-temperate-rainforest gradient, plus the dry
sclerophyll end -- with representative values for the four traits a database
reports: `lma`, `rho`, `hmat` and seed mass.

Six of the seven were unusable, in an order that tracks seed mass exactly:

| species | seed mass against the TF24 default | \|e\| |
|---|---|---|
| Banksia serrata | 1.6x **above** | **17.62** |
| Acacia dealbata | 3.5x below | 1.1e+05 |
| Atherosperma moschatum | 7.6x below | 1.4e+58 |
| Allocasuarina littoralis | 9.5x below | 1.2e+128 |
| Nothofagus cunninghamii | 19x below | 0.00 |
| Eucalyptus regnans | 25x below | 0.00 |
| Pomaderris aspera | 127x below | would not run |

**The one species with a seed heavier than the default is the only one that
behaved.** `fecundity_dt` divides by `(omega + a_f3)` and hyperpar sets
`a_f3 = 3*omega`, so the whole denominator is about `4*omega`: a seed an order of
magnitude below the calibration point is an order of magnitude more offspring per
unit of production. `omega` defaults to 3.8e-5 kg and real seeds run one to two
orders below that.

⚠️ **DO NOT parameterise TF24 from a trait database without checking seed mass
against 3.8e-5 kg.** The failure is silent at the top of the range -- a plausible
mass and a gradient of 1e+58 -- and only becomes an error two orders down.

Holding `omega` and `hmat` at their defaults and varying only leaf and wood
economics gets three of the seven to a stable answer, and the other four onto
needles: a 0.1% nudge in `lma` moves their gradient by more than 3x, mountain ash
worst at \|e\| = 60,736. The three that survive are 32-56 degrees apart and agree
on their largest lever, so the reduced comparison is meaningful as far as it goes.

**What this costs the demo:** a comparative-fingerprints document over named
species is not buildable on this parameterisation. Either the model is recalibrated
for the seed masses real species have, or the demo varies only leaf and wood
economics and states that it is doing so, and still needs the nudge-and-check
protocol on every row.

---

# The upstream merge cost the reverse gradient 2.26x, and the forward 11% less

Interleaved A/B, one machine, one session, arms alternating, two reps each, a cold
process per rep. Arm A is `ad/v3-forward`'s pre-merge tip (odelia fec3b00,
phylloptim 33e0048, plant c085582d), arm B its merged tip; both built at `-O2 -g`
with `R CMD INSTALL` into their own private library.
`scripts/profile-stand-reverse.R`.

| arm | forward_s | gradient_s | ratio |
|---|---|---|---|
| A pre-merge | 50.79 / 50.99 | 192.61 / 187.40 | 3.8 / 3.7 |
| B merged | 45.46 / 45.44 | 428.35 / 429.31 | 9.4 / 9.4 |

`steps` 3378, `rate_evaluations` 20,268, `placements` 2,330,530, `swept_ranges`
169, `refusal` none on all four -- the same trajectory doing the same work.

**The forward got FASTER.** The regression is entirely on the reverse path.

⚠️ **THIS MACHINE IS ~1.56x SLOWER than the one the sections above were taken on**:
it runs the pre-merge arm at 50.8 s forward where they record 32.5 s. Absolute
seconds here are not comparable to them; the RATIO is, which is why the ratio is
the number to read. And the branch had already drifted 3.2 -> 3.8 before the merge,
so "3.2 against 9.4" is two regressions read as one.

## Where it went, counted rather than timed

One interior placement, five soil layers, `CostCurve::TF24`, from
`probe_leaf_tape` on arm A and a port of it to the merged surface:

| | pre-merge | merged | |
|---|---|---|---|
| the supply draw | 187 stmt / 320 ops | 123 / 256 | 0.66x -- cheaper |
| **`collar_at`** | **99 / 184** | **1251 / 1452** | **12.6x** |
| `outputs_at` | 74 / 132 | 618 / 755 | 8.4x |
| **one placement** | **360 / 636** | **1992 / 2463** | **5.5x** |

Arm A measures `one-order.md`'s budget exactly. The merged tip is 5.5x that and
2.3x worse than the 861 statements that work replaced. `collar_at` is 1251 at one,
three AND five layers, so it is a fixed per-placement cost.

⚠️ The two arms' probe fixtures are not the same physical leaf -- arm A's drivers
place no feasible interior point on the rebuilt surface, so arm B uses
`test_transpose.cpp`'s. Statement counts are structural, and 12.6x is far outside
what a fixture explains, but the operating points differ in value.

## The cause is a tangent above the adjoint, which one-order.md forbids by name

`marginal_at` lifts the cost kernel to `tangent_scalar<S>` where `S` already
carries an adjoint, to take `dC/dsigma` from upstream's own kernel rather than
from a slope written out beside it. That is the construction "What this forbids"
prices at 18.3x, and about 535 of `collar_at`'s 1,152-statement growth is it.

**It is a correctness trade, not a mistake.** The assembly it replaced needs four
significant digits held through a 1e+05 cancellation and then multiplied by
8.1e+04, and returns an eighth of the answer with the right sign. What went wrong
is that the trade was never priced -- and `probe_leaf_tape`, the instrument that
prices it, was cut by the merge's own first commit.

## Ruled out, each by measurement

* **The central-difference curvature.** `marginal_collar_slope` costs two
  `dprofit_at_collar_psi` evaluations and the code warns this pattern once made a
  century stand 191 s against 32 s -- but `collar_at` guards it with
  `if constexpr`, plant computes it once and passes it in, and the profile puts it
  at **4.7 s, 1.0%**.
* **The forward paying for the reverse.** `record_leaf_outputs` is called only
  under `if constexpr (!std::is_same_v<S, double>)`, and the forward got faster.
* **The 19-slot parameter pack.** An active assigned from a double takes no slot
  and records nothing.
* **Long-double libm.** `powl_helper` and `__ieee754_logl` are genuinely on the
  active path and total ~3-6 s of 451.

# A NaN in the census gradient that nothing named

Three of five census drivers -- `drought`, `shaded`, `clamped` -- return NaN in
every trait column of all three metrics, and `stand_gradient_refused()` reports
nothing refused. `wet` and `seasonal` are clean.

45 of the 46 columns go. The survivor is `a_f3`, the one column declared zero by
construction because it reaches no metric the census reads -- so it is the only
one that never touches the accumulator the NaN is in.

## The invariant is documented and enforced nowhere

`stand_gradient`'s own documentation states it: "A refused metric's whole row is
NaN ... Every other number is one the sweep computed, an exact zero included."
Both halves of the enforcement are missing.

* `census_trait_gradient` (scm.h) fills a row with NaN **on a declared refusal**
  and otherwise copies `trait_adjoint` out verbatim. An arithmetic NaN in the
  accumulator is returned as a number the sweep computed.
* `record_leaf_outputs`' `carry` validates the row it HANDS OVER, which is the
  constant `1.0` and therefore always finite. A sentinel already on the tape
  behind `from` passes `record_report::whole` and never reaches `refuse`.

So the contract holds in one direction only: a refusal implies NaN. NaN does not
imply a refusal, and nothing checks.

## Where the NaN is, by measurement at each boundary

| driver | census | census seed | direct term | gradient |
| --- | --- | --- | --- | --- |
| drought, lifetime 1--4.5 | finite | 0 / 2142 | 0 / 138 | 0 / 138 |
| drought, lifetime 5 | finite | 0 / 2142 | 0 / 138 | **135 / 138** |
| wet, lifetime 5 | finite | 0 / 2142 | 0 / 138 | 0 / 138 |

The seed the reverse pass starts from and the census's own direct reading of the
traits are both clean at every lifetime. **The reverse sweep introduces it.**

Narrowed by patch lifetime, holding everything else:

| lifetime | nan | nodes | steps | state |
| --- | --- | --- | --- | --- |
| 4.5 | 0 | 87 | 3359 | 706 |
| 4.6 | 0 | 88 | 3446 | 714 |
| 4.9 | 0 | 88 | 3488 | 714 |
| 5.0 | **135** | 88 | 3598 | 714 |

⚠️ NOT AN INTRODUCTION. The node count and the state size are already 4.6's at
every later lifetime, and 4.6 is clean. What separates 4.9 from 5.0 is 110 more
recorded steps and nothing structural, so it is a state the trajectory reaches in
the last tenth of the patch's life and not a range the sweep narrows across.

Deterministic and independent of call order: 135 of 138 in all five of gradient
alone, gradient twice on one object, accessors first, a fresh object with
accessors first, and a fresh object with the gradient alone.

## Where the drought run is at that age

The dry bound binds there, and it is heavily amplified. Measured single-layer at
plant's own conductance (kmax 3.1e-05, not the leaf fixtures' 0.2, which is six
thousand times more conductive and never reaches this kind at all): 301
`boundary-crit` points, all at psi_soil between 5.45 and 5.87 MPa -- against
root_psi_crit 5.8703 -- and the theorem there divides by

    dT_dx = -kmax * G'(x) - dflux_dx

which runs **-2.1e-06 to -5.7e-06**. Both terms collapse together as the soil
closes on the margin. `implicit_value` refuses a NON-FINITE denominator and has no
floor under a tiny one, so the collar's rows are amplified about a millionfold:
`dcollar/dkmax` runs 812 down to 30 across that band. Finite at every one of the
301 points, so this is not by itself the NaN -- but it is the amplifier any
imprecision at that margin passes through, and it is where the run is when the
NaN appears.

## It is the transpose, in the soil channel

`census_trait_gradient` also returns `at_first_state`, the reverse pass's adjoint
with respect to the FIRST recorded state, which `stand_gradient` drops. That state
is the environment's ten entries: five soil moistures, then five cumulative-flux
accumulators.

| lifetime | steps | soil adjoint | flux adjoint | trait rows |
| --- | --- | --- | --- | --- |
| 3.0 | 843 | 3.990e-03 | 0 | 1.984e+03 |
| 4.0 | 2385 | 3.302e-04 | 0 | 8.658e+02 |
| 4.5 | 3359 | 3.231e-03 | 0 | 2.573e+03 |
| 4.7 | 3446 | 1.601e-03 | 0 | 1.206e+03 |
| 4.9 | 3488 | 1.519e-03 | 0 | 1.293e+03 |
| 5.0 | 3598 | **NaN** | 0 | **NaN** |

All five soil columns go together; the five accumulators are exactly zero
throughout, because the census does not read them. `ranges` is 88 either way.

**It is a discrete event in the 110 recorded steps between t = 4.9 and t = 5.0,
not accumulation**: the soil adjoint is flat at order 1e-03 through 3488 steps and
then not a number at 3598.

## Ruled out by measurement

* **The forward block, at every state the sweep visits.** `set_ode_state` to each
  of the 3598 recorded states in turn and take the block Jacobian: **every one
  finite**, including the terminal state at the lifetime that produces the NaN. So
  the tangent is clean where the transpose is not.
* **The leaf's own adjoint surface.** 342 points at plant's own conductance
  (kmax 3.1e-05), one, three and five layers, soil closing on the dry margin,
  driven the way `record_leaf_outputs` drives it -- tape, `collar_at`,
  `outputs_at`, seeded on profit and every layer's uptake. **No non-finite input
  adjoint anywhere.**
* **A new branch.** The operating-point tally is `interior` and `boundary-crit`
  at both lifetimes and nothing else; the clamps are `storage_floor`,
  `reserve_ceiling` (16 at both) and `rooting_depth` at both. Nothing turns on.
* **The soil retention cap.** `psi_from_soil_moist` saturates at 1000 MPa for
  theta below about 0.05. The trajectory's driest layer is **0.1331 at 4.9 and
  0.1329 at 5.0** -- 3.83 and 3.88 MPa, nowhere near it.
* **Exponential growth in the reverse pass.** See the table above: flat, then NaN.
* **Call order and nondeterminism.** 135 of 138 in all five of gradient alone,
  twice on one object, accessors first, a fresh object either way.

* **The kink sentinel at a wet bound.** `duptake_dpsi` returns NaN by contract
  where its analytic branch is not valid, `supply_draw_at` stored it per layer,
  and `outputs_at` grafted `NaN * step` onto every layer's uptake. That is a real
  defect, it took 396 of 396 shade-death points in phylloptim's own sweep, and
  fixing it left plant's counts **unchanged to the digit** -- `drought` has no
  shade-death arm at all.
* **The radiation row.** Attaching it moves `1.k_I` from finite to NaN in the
  same already-NaN rows and changes nothing else: 44 columns become 45.
* **A metric-level cause.** All three metrics go together, which is what one NaN
  in a shared accumulator does rather than three separate failures.

# The water rows carry the leaf's spline resolution

`test-gradient-ladder-factorisation.R` reports the supplied `uptake x psi_soil`
block against a difference of the double path at 1.78e-04 relative, against a
budget of 1e-05. The disagreement is entirely in the COLLAR CHANNEL, and it is
the vulnerability curve's interpolation error.

## Measured against the leaf's knot count

`ladder_patch(..., control = ladder_control(vulnerability_curve_ncontrol = n))`.

| n | residual | reference spread | second singular value |
| --- | --- | --- | --- |
| 50 | 1.027e-03 | 8.8e-07 | 6.9e-08 |
| 100 (shipped) | **1.781e-04** | 1.2e-08 | 5.1e-07 |
| 200 | 1.078e-04 | 1.5e-08 | 6.2e-07 |
| 400 | 2.915e-05 | 3.4e-08 | 2.7e-06 |
| 800 | 1.918e-06 | 1.3e-08 | 2.2e-05 |

535x over a 16x resolution increase, with the reference resolved at ~1e-8
throughout and the difference rank one the whole way. **The budget the test
asserts is one the shipped resolution cannot meet**: 1e-05 is reached somewhere
past 400 knots.

## What one table bought

G and G^-1 were two tabulations of one function on the same knots with the axes
swapped, so they agreed at the knots and nowhere between them. Inverting the
forward table instead makes `P' * G' - 1` exactly zero at any resolution, where
it had been 3.8e-05 at the shipped 100 knots and O(h^3).

| n | residual before | after | factor |
| --- | --- | --- | --- |
| 50 | 1.027e-03 | 4.876e-05 | 21x |
| 100 (shipped) | **1.781e-04** | **7.966e-06** | **22x** |
| 200 | 1.078e-04 | 5.217e-06 | 21x |
| 400 | 2.915e-05 | 1.406e-06 | 21x |
| 800 | 1.918e-06 | 1.046e-07 | 18x |

Three of the file's five checks now pass, and the leaf-trait referee -- an
independent instrument, differencing a rebuilt forward model -- improved with
them, 5.64e-03 to 2.52e-04. The two that remain are the AMPLIFIED directions,
where the residue is divided by a cancellation the fixture measures at 16.3x:
1.24x and 1.40x of budget, against 24.1x and 1.60x before. The residue still
scales with resolution, so it is the forward table's own interpolation error and
the shipped knot count is what sets it.

Cost: `find_root_collar_psi` 7.38 to 8.46 us, +14.6%. Two Newton steps in 3613 of
4999 inversions, three in 1165, from a start 1.5e-04 out, final error exactly
zero. `psi_stem:TF` unchanged -- that path never reads the inverse.

⚠️ AND IT MOVES OUTPUTS, BY UP TO 62%. At zero flux the round trip used to put
the stem 1e-07 below the collar, which is a reversed gradient the model does not
have, so there was a spurious infeasible sliver about 1e-06 wide above bound_a --
and the leaf's wet-bound pins sit inside it, 6.1e-07 to 1.3e-06 above the bound.
Their flux is tiny, so where the pin sits is a large relative change in
assimilation. Every golden point that moved is a `boundary-soil` pin in that
band; every `interior` point, 0.04 to 0.46 away, is untouched. The pins were
being placed by the two tables' round-trip error rather than by the model.

⚠️ THE KNOB IS THE PATCH'S `control`, NOT ITS `parameters`. `ladder_parameters()`
returns no `$control` at all, so setting `ncontrol` there changes nothing and
every row of the sweep comes back byte-identical -- which reads exactly like a
resolution-independent residual. The check that the knob bites is
`max|block(50) - block(800)|`, which is 5.7 against a block whose largest entry
is 5.9e+05.

## Ruled out, each by measurement

* **The per-layer collar slopes.** `duptake_dp` and `flux.slope` against a
  difference of `uptake_at` at a GIVEN collar -- no root-find, referee converged
  to ~1e-10 -- agree to **3.9e-12 to 1.1e-11**. The `u` side of the rank-one
  channel is exact, so the whole error is in `dcollar/dpsi`.
* **The curvature's step size.** The central difference `marginal_collar_slope`
  takes is converged: the spread over h in {1e-4, 1e-5, 1e-6} is 4.1e-06 to
  1.3e-05, which is 18x too small to carry a 1.78e-04 error.
* **The stem spline against its inverse.** `1/G'(psi)` versus `P'(G(psi))` is
  2.7e-08 to 4.9e-07 at the collars these fixtures actually sit at (1.16 to 1.51
  MPa). The 2.36e-05 worst over [0.1, 5.0] MPa is at the DRY end and describes no
  operating point here -- a worst-case quoted at a point the model never reaches
  is not evidence about the point it does.

## Two instruments that cannot referee this, and why

Differencing anything whose value is placed by a root-find is quantised at that
solver's tolerance, not at the step size. Measured:

* `dcollar/dpsi_soil` by re-solving the leaf at a bumped layer: the referee's own
  spread over three steps is **4.4e-04 to 1.3e+06**, against a disagreement of
  1e-03. It resolves nothing.
* `dM/dpsi_soil` by differencing `dprofit_at_collar_psi` at a fixed collar: spread
  1.8e-03 to 3.9e-02, against a disagreement of 1.7e-04 to 6.5e-03. Also nothing.

The ladder's own block difference is the instrument that works, because uptake is
dominated by the direct channel and the collar's quantisation is a small part of
the OUTPUT even though it is the whole of `dcollar/dpsi`.

# The unnamed NaN, named

D closed the drought reproduction. On the same box, at the same drivers, and with
nothing else changed:

| driver | before D | after D |
| --- | --- | --- |
| drought, lifetime 5 | 135 / 138 | **0 / 138** |
| wet, seasonal | 0 / 138 | 0 / 138 |
| shaded (k_I 20), clamped (k_I 40) | non-finite | non-finite |

`ODELIA_ADJOINT_TRACE` on the drought stand prints nothing at all, so the sweep
carries no non-finite adjoint anywhere in it. The gradient suite's remaining
eight failures are then two things and not one: six are this NaN on other
drivers, and two are the water rows' resolution dependence above.

## It is TWO regimes, not one, and only one of them is a state

Measured over the recorded trajectory itself -- every state the sweep replays,
counted for non-finite entries:

| driver | records | carrying a non-finite state | forward tally |
| --- | --- | --- | --- |
| wet | 522 | 0 | interior |
| drought | 3820 | 0 | interior, boundary-crit |
| dry, lifetime 10 | 4991 | **0** | interior, boundary-crit |
| shaded, k_I 20 | 11722 | **9545 of 11722** | interior, shade-death |
| clamped, k_I 40 | 11028 | **10769 of 11028** | interior, shade-death |

So the two shade drivers record a trajectory that is not differentiable, and the
lifetime-10 dry stand -- 135 of 138 non-finite, no refusal -- records one that
is. They are separate problems and were being read as one.

## What the shade drivers carry, and where it is written

Nine nodes of 88 at k_I = 20, ten of 88 at k_I = 40, in exactly two slots:

    mortality    = +Inf
    log_density  = -Inf

Both appear at an INTRODUCTION row -- two records at the same time, t = 1.5 --
and the record before it holds mortality 0.32216592 and log_density 2.4738867.
So it is not integration: `Node::compute_initial_conditions` writes both, from
one establishment probability of exactly zero.

    individual.set_state("mortality", -log(pr_estab));       // +Inf
    set_log_density(density_at_birth > 0 ? log(density_at_birth)
                                        : value_type(log(0.0)));

`TF24_Strategy::establishment_probability` returns a literal `0.0` wherever net
mass production is non-positive, which deep shade reaches. The density half of
that case is already constructed deliberately, with a comment saying why; the
hazard half is `-log(0)` and was not.

## Why nothing declared it

Every reader of the hazard is guarded, so the forward model is correct at +Inf
and says nothing:

* `Node::survival_individual` reads `exp(-mortality)`, which is exactly zero for
  anything past 745.14, and tests `is_finite` on the result.
* `TF24_Strategy::mortality_dt` tests `is_finite(cumulative_mortality)` and
  returns a constant `0.0`, so the state does not move again.
* `Individual::log_density_rate` is `-mortality_dt` on the birth-date
  coordinate, so log_density does not move either.
* `Patch::check_finite_ode_state` tests the cohort DENSITY -- `exp(-Inf)` is 0,
  which is finite -- and the environment's own states. Six of the eight slots a
  node carries are not looked at.

Held at 750 instead, because `exp(-x)` is exactly zero past 745.14: every reader
of the hazard then reads the number +Inf gave it, and the state is finite.

⚠️ AND THE PARKED RATE HAS TO BE KEYED ON THE CEILING, not left on `is_finite`.
`mortality_dt` returns a constant zero for a cohort whose hazard is not finite,
and that is what stops the state moving again; a finite hazard passes that test,
so the rate returns and each held cohort integrates
`a_dG1 + mortality_growth_independent_dt` ~= 5.5/yr against `ode_tol_rel` 1e-4 --
a different run from the one +Inf produced, through `log_density_dt`, `yerr` and
so the step the controller chooses. Keyed on the ceiling instead, in all three
strategies, the value AND the rate are what +Inf gave.

⚠️ NO TIMING WAS MEASURED FOR THAT, AND A FIRST PASS HERE CLAIMED ONE. The
shaded solve read 126 s before and 680 s after, and the cause is neither the
sentinel nor the rate: `pkgbuild::compile_dll()` defaults to `debug = TRUE` and
builds at **-O0 with -UNDEBUG**, where every earlier measurement in this file
came from an -O2 build. That also moves the trajectory -- 10879 records against
11722, and the operating-point tally by 7% -- which is this repo's own documented
FMA-contraction difference and not the change under test. **Read the -O flags out
of the build log before comparing a run with a recorded one.**

## The sweep does not meet a bad step; it arrives at one already enormous

With the trace reporting the magnitude one step above the failure:

    step 10861 of [9941, 10878], entry 624 of 714, worst |lambda| one step
    above 1.65665e+295

The range's top is 10878 and the seed the sweep starts from is the census's own,
measured clean. So **lambda reaches 1.66e+295 within 17 steps** -- about 1e+17
per step -- and the next multiplication overflows, after which Inf - Inf is
not a number. That disposes of the reading this file carried from the drought
stand, where the soil adjoint looked flat and then not a number: flat was the
range below, and the growth is in the range above it.

`entry 624 of 714` is node 79's height on both drivers, which is the last node
before the block of held cohorts at k_I = 20 and inside it at k_I = 40.

## What the finite hazard bought, and what it did not

Every recorded state is finite now, on all five drivers, and the forward run is
unchanged -- the two shade drivers come back with the same record count, step
count, cohort count and operating-point tally as the -O2 runs taken before the
change:

| driver | records | steps | tally | non-finite states |
| --- | --- | --- | --- | --- |
| shaded k_I 20 | 11722 | 11634 | interior 10386508, shade-death 1201107 | **0** |
| clamped k_I 40 | 11028 | 10940 | interior 9295667, shade-death 1434291 | **0** |
| dry lifetime 10 | 4991 | 4898 | interior 5319036, boundary-crit 26903 | 0 |
| wet | 522 | 434 | interior 222709 | 0 |
| drought | 3820 | 3732 | interior 3496882, boundary-crit 345393 | 0 |

**AND THE GRADIENT IS STILL NOT A NUMBER ON THREE OF THEM** -- 135 of 138 on
shaded, clamped and dry-10, wet clean. The infinite state was a real defect and
it was not this one: the sweep overflows.

## The amplifier, located

`max|J|` of the 714x714 tangent Jacobian, at 18 records spread over the final
range of the shaded stand, is **2.019e+07** at every one of them, always in the
same entry:

    node 79 mortality  <-  node 79 storage

with the worst column sum, 4.06e+07, on that same storage slot. Sustained rather
than a spike, and node 79 is the entry the trace names on both shade drivers.

The route is the only one the model has from storage to mortality:
`mortality_dt = a_dG1 * exp(-a_dG2 * r)` at `r = storage / storage_capacity`, so
the derivative carries `a_dG1 * a_dG2 / storage_capacity` -- 110 over the storage
capacity of a seedling that is dying in deep shade.

The forward pass survives it because the controller resolves the STATE: it is
crawling at `h = 2.248e-06` through this stretch, which is what makes the shaded
stand 11722 steps against wet's 522. The sweep has no such control. It is a
product of step Jacobians, `h * max|J|` is 45.4 per step at that step size and
3.7e+05 at the 0.0185 the failing step took, and 17 of those reach 1.5e+295.

So this is the model's own stiffness, reported faithfully. The census really is
that sensitive to node 79's storage in the linearised model, and no arithmetic in
the transpose is wrong.

⚠️ AND `drought` HAS 345393 DRY PINS AGAINST DRY-10's 26903 AND IS CLEAN, so the
incidence of an amplified branch is not what decides this. What differs is how
long the sweep multiplies: 10 years against 5.

## Ruled out, each by measurement

* **The Jacobian at every stage state of the offending step.** The adjoint step
  re-runs the whole RKCK step on a tape, so it evaluates `derivs` at six stage
  states, five of which no record holds -- the earlier "finite at every recorded
  state" measurement does not cover them. Reconstructed from the tableau and
  measured at all six, on both drivers: **rates finite, tangent Jacobian
  714x714 finite, trait Jacobian 714x46 finite**, on the shaded step whose state
  carries 18 non-finite entries and on the dry-10 step whose state carries none.
* **The reverse of the same six evaluations.** `ladder_rhs_adjoint` at each stage
  state, seeded flat: finite, no refusal, and agreeing with the tangent's column
  sums to **3.2e-11 to 1.4e-10**. So one evaluation transposes cleanly in both
  directions at every stage of the step the sweep breaks on, which puts what
  breaks in the whole-step recording rather than in any evaluation of it.
* **The insertion transpose.** The trace prints one line per range. Where the
  reported step is the range's own `k_last` the adjoint arrived non-finite from
  the range above, which is propagation; the two origins reported here are 17 and
  196 steps below their range's top.
* **A new branch.** No sweep sets `non-finite-gradient` on any driver, and the
  tally after the sweep is twice the forward run's in every kind -- so the replay
  classifies every point the way the run did.
* **The root vulnerability integral's cap.** It fires 5087 times at k_I = 20 and
  2962 at k_I = 40, against zero on wet and drought, so it is the one clamp that
  tracks the affected drivers. It is not the cause: the lifetime-10 dry stand
  never reaches it and fails anyway.
