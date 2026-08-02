# The density transport term when a plant carries physiology

The size-density equation's compression term, what it is when a cohort carries state beyond its
size, and why the change this project designed for it is now out of scope. Numbers are measured on
plant `p2/phase-2` (boundary reordering, fixed light fractions, fused slope reduction, collar polish)
against odelia `p1/audit-fixes`, at `-O2 -DNDEBUG`, unless attributed otherwise.

**Status: this report replaces report 04's conclusion, not its derivations.** Report 04's mathematics
is correct and its scope was never stated. The live thread is `aornugent/plant#69`, which is a
forward-model question for plant's maintainers and is deliberately not on this build's critical path
(§6). The implementation and every probe are preserved on plant `transport/cohort-grid-stencil`.

---

## 1. The term, and the two ways to get it

Along a cohort's trajectory the size-density equation reads

    d(log n)/dt  =  -dg/dh  -  mortality

with `n` the cohort density and `g` the height growth rate. `dg/dh` has no closed form, so it is
discretised, and there are two candidates.

**The sub-grid probe, which is what develop does.** `Node::growth_rate_gradient` copies the
`Individual`, sets its height to `h - node_gradient_eps` (`1e-6`, one-sided backward by default),
re-runs a complete rate evaluation, and differences against the already-computed rate. For TF24 that
re-run includes a full hydraulic optimisation, so **every cohort costs two leaf solves per
Runge-Kutta stage.**

**The cohort-grid difference, which report 04 proposes.** `(g_i - g_below)/(h_i - h_below)`, taking
the neighbour below, with the lowest cohort differencing against the inflow boundary node. Both
growth rates are already computed by the same `Species::compute_rates` pass, so it costs nothing and
**deletes one leaf solve per cohort per stage** — about 37% of forward time per accepted step,
measured (§4).

## 2. Report 04's identity is correct, and its scope is the whole question

Report 04 §2.1 derives the cohort-grid form from conservation. The spacing between two
characteristics has an exact rate, `d(dh)/dt = g_i - g_below`, so with `N = n · dh`,

    log n = log N - log dh   =>   d(log n)/dt = -mortality - (g_i - g_below)/(h_i - h_below)

Nothing in that is wrong, and it was verified numerically at all four model pairs: the hand-computed
quotient, `log_density_dt + mortality_rate`, and `-d(log dh)/dt` from a short integration agree to
every printed digit.

**What it does not state is the condition under which `d(log dh)/dt` is the compression term of a
density in height.** That condition is that `g` be a function of height alone. When a cohort carries
other state `s`, the two-node difference is a *total* derivative along the cohort grid,

    (g_i - g_below)/dh   ->   ∂g/∂h  +  Σ_k (∂g/∂s_k)(ds_k/dh)

and the second group does not vanish under refinement, because neighbouring cohorts differ in state
as well as in size. TF24's growth rate reads the NSC storage pool through a reserve gate
(`TF24_Strategy::compute_rates`, the logistic on relative reserves), so TF24 is squarely in that
case; K93 is not; FF16 is marginally, through heartwood.

## 3. The two candidates are different operators, measured

### 3.1 On one state

Evaluated on the same end-of-run patch state, over the interior cohorts, on a tree carrying both:

| strategy | non-height state in `g` | `cor(cohort-grid, sub-grid)` | mean disagreement |
|---|---|---|---|
| K93 | none | **0.9625** | 6% |
| FF16 | heartwood, weakly coupled | **0.9789** | 9% |
| **TF24** | storage, through the reserve gate | **0.0519** | **54%** |

On TF24 they are statistically unrelated. The per-cohort interior values of the cohort-grid form sweep
monotonically through zero (`-0.031` to `+0.039`) while the sub-grid values stay uniformly negative
(`-0.060` to `-0.234`), so they **disagree in sign** across most of the grid.

**One pair, to make it concrete.** Two cohorts 4.6 cm apart, `g = 0.0306` above and `g = 0.1475`
below: the lower plant grows 4.8× faster than the one above it. The sub-grid probe reports
`dg/dh ≈ -0.157`, which over 4.6 cm predicts `g` changing by 0.007; it changes by 0.117. A height
difference cannot produce that. It is a freshly recruited seedling with full reserves against a
neighbour that has drawn its reserves down.

### 3.2 On the forward model

| strategy | offspring | steps |
|---|---|---|
| K93 | +1.39% | 234 -> 169 |
| FF16 | +16.4% | 210 -> 236 |
| TF24 | **+932% (10.32x)** | 4 730 -> 1 248 |

Divergence is not gradual. Total density tracks closely until `t ≈ 6` and then jumps about tenfold
**at each cohort introduction** through the recruitment window — where the storage gap between a
recruit and an established neighbour is widest.

### 3.3 Refinement cannot settle it, and that is the result

Midpoint insertion into `node_schedule_times`, so both arms see byte-identical schedules at each
level. `refine_schedule = TRUE` was rejected: adaptive refinement picks arm-dependent times and the
levels would not be comparable.

| spacing | sub-grid | cohort grid | gap |
|---|---|---|---|
| default, 141 introductions | 42.13 | 434.77 | 392.6 |
| /2, 281 | 54.80 | 436.05 | 381.3 |
| /4, 561 | 58.75 | 422.80 | 364.1 |

The gap shrinks 2.9% then 4.5% per halving where first-order convergence to a shared limit would halve
it. **Each arm converges to its own limit** — Aitken on the sub-grid arm gives ≈60, the cohort arm sits
within ±3% of ≈430 with no trend. Two stable limits about 370 apart, which is the numerical
confirmation of §2's mechanism taken independently of it.

**A second thing refinement establishes: develop's blessed TF24 offspring is not converged.** 42.13 ->
54.80 -> 58.75, moving +30% on the first halving. Whatever is decided, the current baseline is a
coarse-grid value of the sub-grid operator.

## 4. What the cohort-grid form would have bought

Recorded because it is the reason the change was designed, and it is unchanged by the above.

| | ms per accepted step |
|---|---|
| sub-grid, two-pass loop | 33.15 |
| cohort grid | 21.40 |
| plus the deletions | 21.07 |

**37% per accepted step**, consistent with halving the leaf solves, and a 6x wall clock because the
accepted step count also falls 3.8x — dropping a `1e-6`-probe derivative from the right-hand side made
it markedly less stiff.

And it removes a conservation defect. The count between two characteristics should decay at exactly
the mortality rate; `mortality` is a state, so `log N + mortality = const` is checkable with no
instrumentation:

| | worst single cohort | summed drift |
|---|---|---|
| TF24 sub-grid | **3.4x the count conservation allows** | +3.99 |
| TF24 cohort grid | 6.6e-05 | -2.97e-06 |
| K93 sub-grid | 2.2x | -0.135 |
| K93 cohort grid | 2.5e-04 | -6.91e-06 |

The sub-grid drift is monotone out of the transient, so it is a systematic source rather than
roundoff. Report 04 §2.2 predicts exactly this at `O(dh · g'')`, and the prediction holds — six orders
on TF24, four on K93.

**Per report 04 §2.2's own caveat, this is about the dynamics of `N_j` and not about how well
`sum_j N_j` estimates the true population.** `N = n · dh` is a rectangle estimate and mortality is
applied at one cohort's rate across the interval, both first order in the gap. Neither candidate
changes that. Related: peak total stand count differs by a stable **5.3x** between the arms after
refinement (≈103 against ≈19.6); at production spacing the ratio looks like 17, and most of that is a
coarse-grid artefact that converges away.

## 5. What the model's own premises imply

Two statements from the model's owner, and following them through is what took this out of the build.

- **plant is size-structured by intention.** Not an artefact of implementation.
- **A cohort is a density of equivalent plants at a size**, not one plant.

If cohort heights are ordered then the map from height to cohort is injective, so at any instant the
storage pool **is a function of height**, `s = s(h, t)`. A plant at height `h` then grows at
`g̃(h, t) := g(h, s(h, t))`, which is a genuine velocity field on `(h, t)`; the size-density equation
is the ordinary one in that field; and **cohorts are exactly its characteristics**, since a cohort at
`h_j` with storage `s_j` moves at `g(h_j, s_j) = g̃(h_j, t)`. So the compression term is

    ∂g̃/∂h  =  ∂g/∂h  +  (∂g/∂s)(∂s/∂h)

**develop computes the first term only.** That is not a coarse discretisation of the right quantity;
it is a different quantity, missing a term that is identically zero for K93, nearly zero for FF16, and
dominant for TF24 — which is precisely the ordering §3.1 measures.

**So "density in height" does not imply the frozen partial.** There is no fixed physiology in a
size-structured population, because physiology is a function of size; freezing storage and
differentiating in height describes a plant that is not in the stand. This is the opposite of what the
phrase suggests, and it is why the question needed the model's owner rather than a measurement.

### 5.1 The treatment this points at, which is neither candidate

    compression  =  ∂g/∂h  +  (∂g/∂s)(∂s/∂h)

with `∂g/∂h` and `∂g/∂s` analytic or taken by automatic differentiation — both are strategy
properties — and only `∂s/∂h` coming from the stand. That has the cohort-grid form's semantics with
none of its numerical exposure: no `1e-6` divisor, and no growth-rate difference divided by a cohort
gap whose measured minimum is `8.2e-06` m with 23.5% below `1e-4`. It also puts the modelling
assumption in one visible place instead of inside a difference quotient.

**Making storage an explicit function of size and environment** would make `∂s/∂h` analytic too, close
the whole term, and make the size-structured premise true by construction rather than true because
cohort heights happen to stay ordered. Larger change; no loose ends. Recorded as the owner's
preference at the time of writing, not as a decision.

## 6. Why this is not on the build's critical path

**The reverse pass differentiates whatever the forward model does.** Report 04 §5 records that
evaluating the existing sub-grid stencil at the active scalar leaves the value bit-identical and yields
the derivative of the discretisation actually solved. So the transport term's treatment is a
forward-model question, and the build proceeds under whichever answer the maintainers reach.

**What deferring costs, stated so it is not rediscovered:**

- **The 37% per-step forward saving is not taken**, and the leaf solve count stays at two per cohort
  per stage.
- **The conservation defect of §4 stays** — 3.4x on one cohort at production lifetime.
- **A `1e-6` divisor stays on the gradient path.** Report 04 §5: differencing two parameter
  derivatives and dividing by `1e-6` leaves about `1e-10` of absolute error before any non-smoothness,
  and the cohort grid's divisor is 3 470x larger at the median spacing.
- **The reverse pass's transport adjoint doubles in cost, and changes shape.** Under the cohort grid a
  cohort's `g` feeds its neighbours' `log_density_dt`, so `lambda_g` is a closed-form seed formed
  before any block is swept — `build-plan.md` §2.4 step (a). Under the sub-grid probe,
  `log_density_dt` reads `g` at `h` **and** at `h - eps`, so the second reading is the output of a
  *second evaluation of the cohort block at a different input*. That means two block recordings and
  two sweeps per cohort per stage rather than one, and `build-plan.md` §2.4's step (a) and P3.5 are
  written for the other shape. **This is the load-bearing consequence for Phase 3 and it is the one to
  design against.** Symmetric with the forward cost: the probe is two leaf solves forward and two
  block recordings in reverse.

## 7. What is preserved, and where

**plant `transport/cohort-grid-stencil`**, off `p2/phase-2`:

| commit | what |
|---|---|
| two-pass loop | `Species::compute_rates` splits so a cohort can read its neighbour's rate. **Bit-identical**, which is what makes everything after it attributable |
| the cohort-grid stencil | `Species::growth_rate_gradient(i)`, guarded on `!(dh > 0.0)` so a zero-width or non-descending pair takes the compression above |
| the deletions | `Node::growth_rate_gradient`, `r_growth_rate_gradient`, `Individual::growth_rate_given_height`, the four `node_gradient_*` `Control` fields, and the `NEWS.md` migration |
| the split census | `transport_split_census.h`, behind `PLANT_SPLIT_CENSUS`, separating the boundary pair's contribution from the interior's |

Also on that branch: the four replacement tests for the two that were pinned to the sub-grid stencil's
definition — the two-cohort difference quotient, the lowest cohort against the boundary node, the three
zero-width cases, and the §2.1 identity by differencing `dh` over a short integration. The last is the
only one that reads the dynamics rather than the arithmetic, and it is the one that would catch a
staggering error.

Probes and raw outputs: `k93_ff16.R`, `conserve.R`, `refine.R`, `operators.R` and their outputs, plus
per-level `sum_j N_j` time series.

## 8. Two smaller findings, each wanting its own decision

**The inflow boundary node is not a transported characteristic.** `Species::new_node` sits at
`height_0` permanently. Pairing the lowest cohort against it gives that pair a mean `|stencil|` of
**8.36** against **0.129** for interior pairs, a maximum of **161.7**, and every one of the degenerate
cases. Measured over 1 078 893 guarded pairs on one production run:

    zero-width      141, every one the boundary pair -- one per introduction, as report 04 s7.1 predicts
    non-descending   12, every one the boundary pair, minimum dh -0.0273 m
    interior grid    never non-descending

**Excluding the boundary pair entirely does not recover the baseline** — offspring stays at 469.1, 11x
— so it is the worst instance of §2's problem rather than a separate one. It still needs a treatment,
and report 04 §2.3's reading (a collapsing newborn interval recovers the boundary condition in the
limit) and the fixed-boundary reading (`d(dh)/dt = g_i - 0`, since `height_0` does not move) are a
genuine fork that no measurement here settles.

**Cohort heights can stop being descending.** 12 occurrences, all at the boundary pair, minimum
`-0.0273` m. `Species::compute_competition_unordered` already handles the unordered case for the
competition profile, but **a size-structured density strictly requires the ordering** (§5), so those
12 are the premise failing rather than a numerical nuisance. Anything pairing `nodes[i]` with
`nodes[i+1]` and taking list order for height order needs a guard; `Species::growth_rate_gradient`'s
`!(dh > 0.0)` is one.

## 9. Measured, versus inferred

**Measured on `p2/phase-2` at the pinned build:** every figure in §3, §4, §8, and the refinement table
in §3.3. The two arms are one commit apart and the sub-grid arm reproduces its baseline offspring to
all digits, so the arms are correctly identified.

**Read from the code:** `Node::growth_rate_gradient`'s construction and defaults;
`TF24_Strategy::compute_rates`'s reserve gate; `Species::new_node`'s fixed height.

**Derived, not measured:** §5's field argument, which is mathematics rather than a probe. §6's claim
that the reverse pass's transport adjoint doubles is read from `build-plan.md` §2.4's structure and
has not been built.

**Not claimed:** which candidate the model intends — that is `aornugent/plant#69`, and it is open.
Nor anything about a multi-species stand: every number here is single-species.

## 10. What would falsify or settle this

- **The stochastic solver as an external oracle.** The SCM is the deterministic limit of an
  individual-based model, and an IBM has no compression term — plants are counted, not transported as
  a density. A stochastic TF24 run at matched parameters is therefore an oracle neither candidate can
  bias. If it lands near ≈430 the omitted term is real; near ≈60 it is not. **This is the single
  measurement that adjudicates from outside both, and it has not been taken.**
- **Freeze the storage pool** (or FF16's heartwood) and confirm the two operators come back into
  agreement, recovering K93's 0.96 correlation. A direct test of §2's mechanism rather than of its
  consequences, and cheap.
- **§5's field argument is wrong** if the non-height states are independent coordinates of the density
  rather than functions of height along it. That is decidable on paper and it is what `#69` asks.
- **The refinement plateau reverses** at a spacing finer than `/4`. Two levels is not many, and the
  cohort arm's `-3%` at the last level is not obviously trendless.
