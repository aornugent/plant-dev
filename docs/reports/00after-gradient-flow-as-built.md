# The gradient, end to end: the flow as built and the flow to build

A complete map of the reverse pass — every level from the R entry point to the leaf's supplied
Jacobian — followed by the design that changes it, with the interactions between the changes
worked out rather than listed.

Read directly from plant `dad51118` and odelia `3bb2e46`, cited by symbol. Numbers labelled
**measured** were produced in wave 6; the commands are in `../implementation-notes.md` under
*Phase 3, wave 6*. Reports 00, 01, 02 and 04 own the design; this report owns the composition,
which none of them traced.

**Why it exists.** Every component of the design was verified separately and every component
held. The composition was never written down, and the composition is where the cost is.

---

## 1. Three passes, and what is allowed to cross between them

| pass | what it does | what it leaves behind |
|---|---|---|
| adaptive forward | `SCM::refine_schedule()` resolves the node schedule and the ODE grid | `recorded_steps()` — the single source of the replay grid |
| fixed forward | replays that schedule in `double`, recording each accepted step | `ode_step_record{time, step_size, state}`, 46 MB at production |
| active reverse | seeds at `T`, sweeps back to 0, accumulates trait adjoints | the gradient |

**Only state crosses, and that is deliberate.** Report 01 §1:

> the backward pass rebuilds those stage states by re-running the step in `double` rather than
> storing them, so each stage is evaluated once forward and once again on the way back.
> **Storage is independent of the stage count, which is what makes rebuilding preferable to
> storing.**

So `Patch::has_recorded_field()` returning `false`, and `record_stage(int)` and `replay_step()`
being empty bodies, are **correct**, not unfinished. The design's budget is two `double`
evaluations per stage. Nothing in the corpus asks for a field, a stage value or an operating
point to be carried.

Two things genuinely must cross and only one is implemented:

- **C6, `pr_patch_survival_at_birth`** — a per-`Node` `double` set at birth, not part of
  `ode_state`, which *divides* the fecundity rate. Report 01 C6: "recoverable deterministically
  from the schedule and the disturbance regime, so no derivative is needed, but the reverse pass
  must restore it." `Species::set_birth_state` exists and is called by no test.
- **The introduction structure** — a width alone under-determines the narrowing, because
  `Patch::ode_state` is species-major, so "drop the last node" is wrong when an earlier species
  shed one. Plant owns it (`nodes_introduced_at`, `remove_new_nodes`, `introduction_adjoint`);
  odelia takes a segment range. Built in wave 5.

And one thing must **not** cross: an operating point. Report 01 §10 rule 1, "nothing may carry
between cohorts", and C7 — "A future warm start in any inner solver would break it silently,
with every double-valued test still passing."

---

## 2. The map as built

`M` = census metrics (3), `S` = accepted steps, `B` = introduction boundaries, `C` = cohorts,
`n` = soil layers (5), `P` = 44 registered parameters.

| level | symbol | loops over | per call |
|---|---|---|---|
| 0 | `stand_gradient` (R) | — | takes `traits`, **which never reaches C++** |
| 1 | `SCM::census_trait_gradient` | `M` metrics × `B` segments | 1 extra forward run; `M` census recordings; `M · B` field builds in `widen_over_introductions`; `M · B` tapes in `introduction_adjoint` |
| 2 | `Solver::solve_adjoint` | `S` steps across the segments | bounded; hard-stops on `k_first >= k_last` |
| 3 | `Step::step_adjoint` | 6 stages, twice | 6 `ode::derivs` to rebuild the stage rates + 6 `set_ode_state_and_field` in `sweep_stages` |
| 4 | `Patch::ode_rates_adjoint` | once per stage | `soil_adjoint`, `offspring_adjoint`, **one** `cohort_block_adjoint`, `light_knot_adjoint`, `allometry_adjoint` |
| 5 | `Patch::cohort_block_adjoint` | `C` cohorts | one recording + one sweep each, 185 in → 12 out, on a tape cached as `block_state::tape` |
| 6 | `TF24_Strategy::graft_leaf_outputs` | 6 leaf outputs, **twice per block** | `Leaf::input_adjoints` × 6 per call |
| 7 | `Leaf::input_adjoints` | 15 parameters × 2 sides | ~14 tabulations of 100 `long double` incomplete-gamma knots |

**Counts per gradient call.** Block recordings `M · S · 6 · C`. Field builds `M · S · 12`
against the forward run's `S · 6`. Leaf Jacobians `M · S · 6 · C · 12`. At production
(`S = 4644`, `C ≈ 95`, `M = 3`) that is 7 941 240 block recordings and 95 million leaf Jacobians.

### The block's interface

| in | | out | |
|---|---|---|---|
| strategy state | 6 | strategy rates | 6 |
| light knot values | 65 | `log_density_rate` | 1 |
| light knot slopes | 65 | consumption rates | 5 |
| soil potentials | 5 | | |
| registered parameters | 44 | | |
| **total** | **185** | **total** | **12** |

`set_block_inputs` writes parameters **before** states, because `area_leaf(height)` reads `lma`.
Two of the 44 are inert: `x` carries all fifteen names the leaf declares, but `vcmax_25` and
`jmax_25` are not in `ad_parameters()`, so `x[i] - to_passive(x[i])` is identically zero there.

### The leaf's interface

`Leaf::inputs()` is `2n + 3 + 15`: `PPFD`, `psi_soil[0..n-1]`, `area_leaf`,
`mass_root[0..n-1]`, `leaf_specific_conductance_max`, then fifteen parameters. Six outputs:
`profit_` and `soil_consumption_[0..n-1]`. So the node is a **6 × 28 Jacobian** — 168 numbers.

| rows | `∂Π/∂param` | `∂R/∂param = ∂²Π/∂p∂param` |
|---|---|---|
| `vcmax_25`, `jmax_25`, `a`, `curv_fact_elec_trans`, `curv_fact_colim` | exact, `forward_derivative` | differenced |
| `beta2`, `g1_TF24` | exact, `forward_derivative` of `hydraulic_cost_ad` | differenced |
| `b`, `c`, `root_b`, `root_c` | **differenced**, through a tabulation rebuild | differenced |
| `psi_crit`, `root_psi_crit`, `rho`, `a_bio` | zero, skipped in the interior branch | not taken |

Seven of fifteen have an exact profit row; **none has an exact mixed second derivative.**

---

## 3. The two coupling channels, and what each requires of the reverse pass

Plants interact two ways, and the two have different shapes.

**Light is ordered.** `L(z) = exp(−A(z))` with `A` the leaf area above `z`, so taller shades
shorter, and the reduction is a trapezium up the height axis from the boundary node. The field is
65 knots at fixed fractions with **positions `double` and values and slopes carrying `S`**
(report 03). On the reverse pass the only thing held across the cohort loop is the **adjoint of
the field**, not the field: `light_knot_adjoint` chains `dL/dA = −L` per knot and distributes
through `compute_competition_and_slope_adjoint`.

**Soil is unordered and all-to-all.** `U_i = Σ_k n_k c_{k,i} w_k / area`, θ evolves by a drainage
cascade, and `ψ_i = psi_from_soil_moist(θ_i)` feeds back into every plant's hydraulics. What
`soil_adjoint` needs, and has:

1. the cascade transposable — it is, lower bidiagonal, via `environment.compute_rates_adjoint`;
2. per-layer uptake attributable back to cohorts — `consumption_rate_adjoint` returns
   `{uptake, height, log_density}` per node, the `height` entry being the quadrature-weight term
   report 00 §6.3 warns is easy to forget, and which is **per species**, not per patch;
3. `ψ(θ)` differentiable — `dpsi_from_soil_moist_dtheta`, applied in the block's scatter;
4. uptake a pure function of `(state, θ)` with nothing carried — which is what P0.1 and P0.2 were
   for, and why report 01 C7 forbids a warm start;
5. the four cumulative-flux accumulators are **not** free: two of them read θ, and
   `rate[n+3] = Σ U_i` adds `+λ_{n+3}` to every uptake adjoint (report 00's head correction).

**The soil coupling is why the leaf has six outputs rather than one**, and therefore why a
VJP-per-output costs six times a Jacobian. The channel structure is the cost structure.

---

## 4. The invariants the design rests on, each verified

Everything in §5 depends on these. They are stated separately so a future reader can re-check
them rather than trust the design.

| invariant | how it was established |
|---|---|
| the reverse pass is **linear in the seed** | structural: that is what an adjoint is |
| `Leaf::input_adjoints` is **linear in its seed** | read: `dprofit_dpar`, `dE_dpar`, `dR_dpar` are seed-independent; `μ = −s/Π_pp` with `s = Σ λ_j(−dE_dr_j)` |
| the argmax channel is **rank one** | report 02 §6.2; every layer shares one `p*` |
| the vulnerability tabulations are **pure functions of `(b, c, resolution)`** | read: every value in their bodies comes from arguments and literals; no member, height, potential or time |
| `b`, `c`, `root_b`, `root_c` are **constant across a run** | read: plain members of `TF24_Pars`, written only on active-scalar copies by `set_block_inputs`, `introduce`, `rebind_from` |
| the integral spline is queried at **`n + 2` points** | the code's own comment: the only arguments "resolve to exactly one of `{-psi_soil[i], -P_x_r, 0}`"; `refresh_soil_potentials` does `n` |
| the series is **always in its fast regime** | measured: `X(psi_max) = (psi_max/b)^c = log(100)` for **any** `b`, `c`, so `x ∈ [0, 4.605]`, 10–35 terms |
| the tape does **not** leak | measured: `block_recording_size` flat at 79 744 over 1 000 calls, `block_sweeps` advancing by `node_count` |
| the trait count is **free** | read: `ad_parameters()` unconditional, no per-trait loop; `traits = "lma"` changes no evaluation count |

**The last one is the design's central promise and it holds.** Report 00 §6.2's claim that
`dp*/dθ` never appears in reverse mode is true as built. The expensive axis is the codomain.

---

## 5. Which terms `d(census)/d(trait)` needs

A census is `Σ_k n_k ψ(state_k)`, a trapezium over the cohort heights at one time. A trait reaches
it through every cohort's rates at every step. Not every term in the leaf's Jacobian is needed for
every trait, and the difference decides how much work a gradient does.

**The leaf has two kinds of input and they cost different amounts.**

| kind | count | how the row is obtained | cost |
|---|---|---|---|
| state: `PPFD`, `psi_soil[n]`, `area_leaf`, `mass_root[n]`, `leaf_specific_conductance_max` | `2n + 3` = 13 | envelope row for profit; two shared scalars plus `∂E_i/∂area_leaf = −E_i/area_leaf` for uptake | cheap, and exact today |
| parameter: the fifteen names `Leaf::inputs()` declares | 15 | one two-sided difference **per parameter** | expensive; four of them rebuild a tabulation |

**Most registered traits are not leaf parameters, and need no parameter row at all.** `lma` is the
worked case. It is absent from the fifteen names. It reaches the leaf only through
`area_leaf(height)`, which is a state input, so the tape records `area_leaf` as a function of
`lma` and the graft supplies `∂output/∂area_leaf`. **A gradient with respect to `lma` therefore
needs none of the fifteen parameter rows**, and none of the tabulation that four of them cause.

Eleven of the 44 registered traits are leaf parameters — `b`, `c`, `psi_crit`, `beta2`,
`g1_TF24`, `a`, `curv_fact_elec_trans`, `curv_fact_colim`, `root_b`, `root_c`, `root_psi_crit`.
Only for these does a parameter row have to exist.

**Where the design's cost promise breaks.** Reverse mode makes the trait count free on the tape,
and that is verified: `ad_parameters()` is unconditional and there is no per-trait loop. Inside
the leaf it is not free, because the parameter rows are computed one parameter at a time by
differencing. **The leaf's supplied Jacobian is the one place in the whole gradient where cost is
proportional to the number of traits**, and C3 and C4 are the two ways to remove that.

### `∇(∂Π/∂p)`: needed, partly built, and needed for one reason only

`R = ∂Π/∂p` is the derivative of profit with respect to the collar potential, and `∇R` is its
gradient with respect to the leaf's inputs. It is needed **only for the uptake rows**:

- **Profit does not need it.** `profit_` is evaluated at its own maximiser, so `dΠ/dp = 0` there
  and the row is `∂Π/∂u` at frozen `p*`, with no `dp*/du` term. This is the envelope theorem and
  it is why the profit row is cheap.
- **Uptake does need it.** `E_i` consumes `p*` rather than being stationary in it, so it carries
  `dp*/du = −(∂²Π/∂p∂u) / Π_pp`. Every layer shares one `p*`, so the whole channel is one scalar
  `μ_j = dE_dr[j] / Π_pp` times one shared vector `∇R`.

Its two halves have different status:

| directions of `∇R` | status |
|---|---|
| the `2n + 1` state directions | **built and exact.** `dR/du = a·dE_up/du + b·d(dE_up/dr)/du`, two scalars shared across all of them; `b` closed form, `a` from one extra residual pair. In the code as `dR_dflux_slope` and `dR_dflux` |
| the 15 parameter directions | **not built.** Each is a two-sided difference of the residual. This is what report 00 §10 means by "the single new piece of code the whole design needs" |

So report 00 §10's item is the parameter half of `∇R`, and C3 supplies the transport part of it in
closed form. The remaining parameter directions are the seven already exact through the templated
evaluators plus the four that are structurally zero.

---

## 6. The design to build

Five components. Each states its mechanism, what it must not break, and the gate that
discriminates it.

### C1 — one sweep, many seeds

**Mechanism.** The reverse pass is linear in `λ`, so `M` metrics do not need `M` sweeps; they
need one sweep carrying `M` columns. Every expensive object — stage rebuilds, field builds, block
recordings, leaf Jacobians — is seed-independent. Only the contraction varies.

**Shape.** `step_adjoint` takes `K` adjoint columns; the stage rebuild happens once;
`ode_rates_adjoint` is called once per stage with `K` columns; `cohort_block_adjoint` records once
per cohort and **sweeps `K` times** against that one recording. `trait_adjoint` becomes `K`
accumulators. `introduction_adjoint` likewise records once and sweeps `K` times.
`widen_over_introductions` runs once rather than `M` times.

**Interactions.** Removes the `×M` on the stage rebuild without touching report 01's
rebuild-versus-store decision, which stays as designed. Composes multiplicatively with C2.
Weakens C5: an exactly-zero skip needs all `K` columns zero, so the skip becomes rarer.

**What it must not break.** The narrowing between segments must apply identically to all `K`
columns. `Patch::ode_state` is species-major, so the per-species newcomer list is shared across
columns — no new structure, but the check must be per column.

**Gate.** Each column bitwise equal to the corresponding single-seed sweep's result. This is a
strong gate because linearity makes exact agreement the expectation, not a tolerance.

**Open.** Whether XAD supports multiple adjoint seedings against one recording here — a recording
can be swept repeatedly if derivatives are cleared and reseeded between sweeps, but that must be
confirmed against `odelia::ode::vector_jacobian_product`, which currently calls `clearAll()` and
`newRecording()` on entry and so destroys the recording it would need to reuse.

### C2 — one leaf Jacobian, not six vector products

**Mechanism.** Report 02 §6 says "one node whose local **Jacobian** is supplied". The code
supplies a vector-Jacobian product and calls it once per output row, recomputing every
seed-independent quantity six times.

**Shape, and it should be factored rather than dense**, because §6.2's structure is the whole
economy:

```
dPi_du     (28)        the envelope row
dE_du      (n x 28)    explicit and sparse: diagonal in psi, lower triangular in root mass,
                       exactly -E_i/area_leaf for leaf area
gradR      (28)        a * dE_up/du + b * d(dE_up/dr)/du, two scalars shared
                       across all 2n+1 state directions
Pi_pp      (1)         negative at every state sampled, -1.09 to -198
dE_dr      (n)         from which mu_j = dE_dr[j] / Pi_pp
```

Then `row_profit = dPi_du` and `row_uptake_j = dE_du[j] + mu_j * gradR`. A dense 6×28 would work
and would hide the sparsity and the rank-one structure, so the factored form is preferred.

**Interactions.** Multiplies with C3: C2 reduces how many Jacobians are built, C3 reduces what
each costs. Independent of C1.

**What it must not break.** `Leaf::bound_partials` must supply the same factored object on the
pinned path — it currently produces rows directly, and repeats the four-parameter differencing, so
a pinned cohort pays twice. `graft`'s `util::check_length` against `x` stays: rows must be full
length so a widened boundary is a hard failure rather than a short vector. That guard is the one
that caught the two-wave truncation and must not be relaxed.

**Gate.** The six rows bitwise identical to six separate `input_adjoints` calls, at four or more
states including production-like ones, interior **and** pinned.

### C3 — the transport algebra in closed form

**Mechanism.** The object being tabulated is the lower incomplete gamma.
`odelia::incomplete_gamma<S>(a, x)` implements it as an everywhere-convergent series in
**elementary operations**, so a tape reads value, `d/dx` and `d/da` off the same code. With
`a = 1/c` and `X = (m/b)^c`,

```
integral_0^m exp(-(s/b)^c) ds = (b/c) * gamma(1/c, X)
```

**Measured against the tabulation it replaces**: value agrees to **1.42e-15** (stem) and
**1.67e-15** (root) over 4 001 points in and past range; the Leibniz endpoint
`dG/dm = exp(-(m/b)^c)` is recovered to **9.0e-14** and **2.3e-13** in range; `dG/db` and `dG/dc`
by AD match a central difference of the closed form **with a clean plateau in all sixteen cases**,
floor 3.3e-12 to 2.3e-10. Cost per call: one 100-knot tabulation **121.2 us**; one closed-form
value **0.074 us**; one value-plus-`d/da`-plus-`d/dx` on a reused tape **0.68 us**.

**Why closed form rather than a cache.** A 100-knot table costs 100 gamma evaluations to build
and then answers each query with a spline lookup. The forward solve makes many queries per solve —
one per Newton iteration per layer — so the build cost is spread over them and the table is the
cheaper choice. **The derivative path makes `n + 2` queries and then discards the table**, so it
pays 100 evaluations to answer seven. A cache
keyed on `(b, c, root_b, root_c, resolution)` would comply with report 01 §10 rule 3 and would
help, but it is the wrong shape: it makes a mis-sized structure cheap instead of removing it, and
it adds a third cache to a corpus that already documents two keyed on less than they depend on.

**The inverse.** `psi_from_transpiration` is the inverse of the same integral. It should be
declared by its residual through `odelia::implicit_value`, whose derivative is then free:
`dpsi/dG = 1 / G'(psi) = exp((psi/b)^c)`. `implicit_value` exists in odelia, is used **nowhere**
in plant — one occurrence, inside a `static_assert` message in `TF24_Strategy::height_seed` which
instructs a reader to do exactly this — and building it here also supplies what `height_seed`
needs.

**Tape lifetime is a design constraint, not a detail.** Measured: a fresh tape per evaluation is
**34.8 us**, a reused tape **0.68 us** — a 50× swing that decides whether this component is worth
building. So the leaf's Jacobian needs a persistent tape. `Patch::cohort_block_adjoint` already
caches one as `block_state::tape` and holds never-recorded templates to copy from, which is the
precedent to follow. Report 01 §10's hazard governs: **no active value may outlive a recording**,
because `clearAll()` resets the slot counter.

**The boundary this moves, stated precisely.** Report 02's load-bearing claim is *never
differentiate the iteration that found the root*, and it stays intact: golden section, the two
bracket root-finds and the `ci` root-find remain `double` and untaped. What changes is the weaker
implementation choice that *the whole leaf* is `double`. **The solve stays `double`; the transport
algebra carries `S` inside `jacobian()` and only doubles cross back out.** That is a smaller claim
than report 02 defends.

**One source of truth, or this violates a rule the plan already sets.** `build-plan.md` §2.1 rules
out a parallel near-copy of an existing path, and a closed form beside a tabulation of the same
function is exactly that. The resolution: **the closed form is the definition and the forward
spline is a cache built from it.** Then there is one expression of the physics, the forward hot
path keeps the table it needs for its many queries, and the knot grid becomes part of a cache rather
than a second definition.

**What it must not break.** The forward model must be bit-identical: `42.411799695604159` and
4 644 accepted steps, at `max_patch_lifetime = 105.32`, `lma = 0.1978791`, `Control()`,
`refine_schedule = FALSE`. If a forward number moves, the change is not what it claims.

**Gate.** All fifteen parameter rows against the current differenced rows, at production-like
states, with the difference-step swept and a plateau required — and the four transport rows
additionally against the closed form's own AD, which is the only reference that does not straddle
the knot-count step.

**Known boundary.** The series returns NaN for `x` beyond about 700 by `exp(x)`-scale overflow,
where boost survives. Unreachable here **by construction**, not by luck: `X(psi_max) = log(100)`
for any `b`, `c`, so `x <= 4.605`, 150× inside the limit. Worth an assertion rather than trust.

**One correction to the header.** It says `dG/dm == exp(-(m/b)^c)` "exactly". That is an analytic
statement; in double it is ~1e-13 in range and degrades in the tail where the series cancels. Ten
percent of sampled points do agree bitwise. Anyone gating on the word "exactly" will be
disappointed.

### C4 — compute only the rows the caller asked for

**Mechanism.** `traits` does not reach C++; `ad_parameters()` is unconditional. Section 5 gives
the rule: a trait that is not one of the fifteen leaf parameter names needs **no leaf parameter
row at all**. So for `lma`, and for the 33 other registered traits that are not leaf parameters,
all fifteen parameter rows can be skipped — the eleven residual pairs and the tabulation together.
The rows are independent columns of the Jacobian, so not computing them is exact rather than
approximate.

This is larger than skipping the four transport rows. It removes the whole parameter loop for the
common case.

**Interaction: C4 and C3 are substitutes for the same cost, not complements.** If C3 lands, a
requested leaf parameter is cheap and C4 saves little. If C4 lands, an unrequested leaf parameter
costs nothing and C3 matters only to callers who ask for `b`, `c`, `root_b` or `root_c`. **Decide
which one to build for cost; do not build both for cost.** They differ in what else they give: C3
makes the four transport rows *exact*, which C4 does not; C4 makes the API honest about what a
gradient costs, which C3 does not.

**The hazard that governs it.** A skipped row must be **absent, never zero**. Exactly-zero reads
as an answer and is this design's worst failure mode; it has already cost two waves here, when
fifteen correctly computed rows were truncated and eleven trait columns read exactly 0 behind five
green gates. So the mechanism is a per-parameter computed flag with a hard failure on reading an
uncomputed row, and returned columns that are absent rather than zeroed — never a zero fill.

**Gate.** The requested column bitwise identical to the unrestricted build's, plus a
demonstration that reading an unrequested row fails loudly.

**Built and measured** on plant `p3/trait-mask` (`5fb631a1`), as a spike rather than a shipping
design. Trait selection did not reach C++ at all: `R/stand_gradient.R` computed the whole matrix
and subset it, `census_trait_gradient_tf24` took one argument, and `Leaf::input_adjoints` had no
notion of a request.

| gate | result |
|---|---|
| `traits = "lma"`, all 15 leaf rows skipped | **0 of 3 entries differ**, dumps byte-identical |
| `traits = b, c, root_b, root_c, lma`, 11 of 15 skipped | **0 of 15 differ** |
| requesting a masked row | refused by name; requesting it properly returns the real column |
| forward run | `42.411799695604159` / 4 644, bit-identical |
| speed, lifetime 0.2, same box, back to back | 512.9 s -> 76.8 s, **6.68x** |
| **control: all four transport rows requested** | 509.4 s -> 513.9 s, **1.00x** |

**The control is the result.** Masking buys 6.68x when the transport rows are not wanted and
nothing when they are, so **the whole cost is those four rows**. C3 and C4 are substitutes for the
same cost, measured rather than argued.

**`set_parameter`'s restore is bit-exact**, which the exactness gate establishes as a side effect:
skipping all fifteen perturbation cycles moved nothing to the last bit through 78 steps of an
adaptive solve. So the present rows do not depend on the order of perturbations.

**`Leaf::bound_partials` carries a second transport differencing loop** over the same four
parameters, so the pinned-collar branch pays the tabulation independently of `input_adjoints`. A
function-level profile cannot separate the two, because both land in the same leaf functions.

**The residual cost after masking is the same tabulation, not a new one.** Profiled on the masked
build with `traits = "lma"`, 60 samples, 60 usable: **50 of 60 are in
`Leaf::build_cumulative_vulnerability_integral` called from `Leaf::input_adjoints`**, 49 of them
inside boost's `long double` incomplete gamma. The two base grid builds sit **above** the mask's
guards — at `src/leaf_model.cpp` lines 1456-1458 before the `transport_pars` loop whose body checks
`par_wanted(k)` at 1465, and again at 1704-1706 before the loop guarded at 1813 — so they run
unconditionally on every call while the per-row work is suppressed.

The arithmetic closes: 14 tabulations per call reduced to 2 is 7x, and the spike measured 6.68x;
2 of 14 is 14% of the cost, and 842 us against 5 620 us is 15%. **Building the grids only when a
transport row is wanted is a two-line change and should take the tabulation to zero for a
non-leaf trait.**

Two predictions were refuted by the same profile and are recorded because they were wrong for
instructive reasons. The residual evaluations are **not** the cost — `dprofit_droot_collar_psi`
4/60, `dR_dcollar_at` **0**/60, `dR_dflux_from_layer` 1/60 — so an argument from counting call
sites in the source gave the wrong answer. And the pinned branch is not involved here:
`bound_partials` 0/60, `prepare_collar_solve` 0/60.

**What becomes visible once the tabulation is masked: the forward leaf solve.**
`find_root_collar_psi` 5/60 and `polish_root_collar_psi` 3/60, against 0 of 30 before masking,
reached through `Individual::growth_rate_gradient`'s finite difference on the forward path —
29 of 60 samples carry that frame. So the next cost centre after C3 and C4 is the sub-grid probe
re-solving the leaf, which is report 10's deferred saving of 37% per accepted step and
`aornugent/plant#69`.

**An unresolved 18x, and every absolute figure in this report depends on it.** The same call at the
same configuration on the same build read **76.8 s** from a harness using
`pkgload::load_all(export_all = TRUE)` and **4.2 s** from one using `library(plant)` plus the
`asNamespace` attach. Section 11.5 of `ORCHESTRATOR.md` records that `load_all` forces its own
`-O0 -g` build and ignores `R_MAKEVARS_USER`. If that is the cause, then 202 s, 512.9 s, 19.9 ms
and 842 us per block are all measurements of an unoptimised build. **The ratios in this report are
same-session and survive either way; the absolute values do not.** Being resolved separately.

### C2b — call the leaf once with the arrived seed, not six times with unit seeds

**This supersedes C2 and is measured.** `Leaf::input_adjoints(lambda_profit, lambda_uptake, row)`
already **takes the seed**, so it is a vector-Jacobian product. It is called six times with unit
vectors only because `graft_leaf_outputs` must hand the tape its partials *before* the reverse
sweep exists. XAD's `CheckpointCallback` removes the "before": `computeAdjoint(Tape*)` runs during
the sweep with the adjoint arrived.

**The premise, measured on the real leaf.** One general-seed call against the six unit rows
contracted, 4 states x 28 inputs, `lp = 0.37`, `lu = (0.11, -0.29, 0.53, 0.07, -0.83)`:

| | |
|---|---|
| max relative difference | **4.4e-16** — one to two ulp, summation order |
| entries above 1e-14 relative | **0** of 112 |
| branches covered | two interior (`pinned = 0`) and two pinned (early return through `bound_partials`) |
| timing | one general call 1.73-2.72 ms against six unit calls 10.5-16.2 ms, ratio **5.97-6.11** |

The cost is seed-independent, so the saving is exactly the call count: 12 calls per block
(21-33 ms) become 2 (3.5-5.5 ms).

**The mechanism, read from `Tape.cpp` and prototyped.** Two containers:

    std::vector<chkpt_type> checkpoints_;               // registration: position -> cb
    std::vector<CheckpointCallback<Tape>*> callbacks_;  // ownership

`insertCallback` writes only `checkpoints_`; `pushCallback` writes only `callbacks_`. Both
`clearAll()` and `newRecording()` clear `checkpoints_` and touch neither `callbacks_` nor the
object, so a callback survives as an object and stops firing. **That is safe here only by
ordering**: `vector_jacobian_product` calls `clearAll()` and `newRecording()` on entry, before `f`
runs, so a callback inserted during `f` is live for that sweep.

**One callback can span all six outputs.** `getAndResetOutputAdjoint` takes an arbitrary slot with
only a bounds check, and `computeAdjointsTo` sweeps everything recorded after the insertion point
**before** firing the callback, so all six adjoints have arrived when it does. `SuppliedDerivative`'s
single `output_` is its own choice, not an interface constraint.

**Prototyped**: a 3-input, 2-output function with a known Jacobian, attached by the algebraic graft
and by a lazy multi-output callback, one reverse sweep, one tape reused across four states with
`clearAll()`/`newRecording()` between. Input adjoints **bitwise identical** — max abs and max rel
difference exactly 0 — and VJP invocations **2 against 1**, the ratio being the output count.

**A constraint that is mandatory, not a refinement.** `callbacks_` is never pruned; the only
`delete` is `~Tape`. Measured across four reuses of one tape, `getNumCallbacks()` read 1, 2, 3, 4.
At production, 2 grafts x 7.94M blocks is on the order of **16 million callback objects** held on
the cached tape until it dies, each carrying a slot and two 28-element vectors — gigabytes, against
a 2 GB gate the current gradient meets at 0.26 GiB. The fix follows from the same two containers:
**`pushCallback` once at workspace creation, `insertCallback` per recording.**
`odelia::ode::supplied_derivative` calls both together, which is correct for a one-shot graft and
wrong for a hot loop.

**What this does not change.** The leaf stays `double`; the solve stays untaped; report 02's
boundary is not relaxed at all. So C2b needs no re-bless, no `scientific_version` bump and no
owner decision, and it makes C3 and C4 optional rather than load-bearing.

**Owed before building it**: the same measurement end to end on a real patch rather than on a toy,
and a decision on callback pruning. Also unexplained: two dry leaf states (`psi_soil` approaching
`psi_crit`) **segfaulted** inside the solve during the linearity harness, before `input_adjoints`
was reached. That is not the `psi_stem_to_ci` `util::stop` already recorded — it is a crash, and it
is undiagnosed.

### C5 — skip exactly-zero cohorts

**Mechanism.** `soil_adjoint` already skips resources whose adjoint is exactly zero. Cohorts at
density exactly zero — 6 of 95 at production, and 327 of 10 153 records carry `mortality = Inf`
— contribute exactly zero and can be skipped in `cohort_block_adjoint` on the same argument.

**Interactions.** Weakened by C1: with `K` columns the skip requires all `K` to be zero. Touches
the owner's `mortality = Inf` question only if it changes a **value**, which it must not — this is
a skip of work whose contribution is exactly zero, not a change to the reduction.

**Gate.** Bitwise identical gradient with the skip on and off.

---

## 6. The interactions, as a matrix

| | C1 seeds | C2 Jacobian | C3 closed form | C4 requested rows | C5 zero skip |
|---|---|---|---|---|---|
| **C1** | — | independent, multiplies | independent | independent | **weakens C5** |
| **C2** | | — | multiplies: C2 cuts count, C3 cuts unit cost | C2 makes C4 cheaper to implement (one place) | independent |
| **C3** | | | — | **substitutes** — same cost argument | independent |
| **C4** | | | | — | independent |
| **C5** | | | | | — |

**Order that respects the dependencies.** C1 and C2 relax nothing and are consequences of
linearity, so they go first and their gates are exact-equality rather than tolerance. C3 is the
component that moves a boundary and needs the tape-lifetime decision, so it goes after C2 — which
also reduces how many call sites it must serve. C4 should be decided **after** C3, because C3 may
remove its purpose. C5 is independent and small.

---

## 6b. The design, and its static profile

### What each component is, in build order

**1. The guard fix — built, `p3/trait-mask` `1a06e4c5`.** The two
`build_cumulative_vulnerability_integral` calls in `Leaf::input_adjoints` and
`Leaf::bound_partials` move under `par_wanted(PAR_B) || par_wanted(PAR_C) ||
par_wanted(PAR_ROOT_B) || par_wanted(PAR_ROOT_C)`, which is exactly `rebuilds_transport`'s set and
exactly the condition under which `set_parameter` reads the knots. Grid contents unchanged.

**2. Trait masking — built as a spike, `p3/trait-mask` `5fb631a1`, needs shipping rework.** A
requested-trait set reaches C++ and `Leaf` skips the parameter rows nobody asked for. Section 5's
rule is why this is large rather than marginal: a trait that is not one of the fifteen leaf
parameter names needs **no leaf parameter row at all**, and 33 of the 44 registered traits are in
that position.

Three properties the spike established and any shipping version must keep:
- **absent, not zero** — masked rows are poisoned with NaN, and `x` and the partials row are
  compacted so the NaN cannot enter arithmetic; the boundary refuses an absent column by name;
- both `Leaf::input_adjoints` **and** `Leaf::bound_partials` are masked, or the pinned branch pays;
- `set_parameter`'s restore is bit-exact, so skipping perturbation cycles moves nothing else —
  measured, 0 of 3 and 0 of 15 entries differing, dumps byte-identical.

What the spike did for expedience and a shipping version should not: `census_trait_gradient` takes
two name lists (`traits` and `want`) so the refusal is testable, and the mask is not
species-qualified.

**3. Call the leaf once with the arrived seed — designed and prototyped, not built.** C2b above.
`Leaf::input_adjoints` is already a vector-Jacobian product; a lazy multi-output
`CheckpointCallback` replaces the algebraic graft so it is called once per graft with the true seed
instead of six times with unit vectors. `input_adjoints`' signature does not change.

Two things this needs that the prototype settled:
- **one callback for all six outputs**, reading all six arrived adjoints in one `computeAdjoint`
  and calling `input_adjoints` once. Legal: `getAndResetOutputAdjoint` takes an arbitrary slot, and
  `computeAdjointsTo` sweeps everything after the insertion point before firing.
- **`pushCallback` once at workspace creation, `insertCallback` per recording.** `callbacks_` is
  never pruned by `clearAll()` or `newRecording()`, so registering ownership per graft would
  accumulate about 16 million objects at production.
  `odelia::ode::supplied_derivative` calls both together, which suits a one-shot graft and not a
  hot loop.

It also enables something the unit-seed form cannot: **when `lambda_uptake` arrives as exactly
zero, `Pi_pp`, `grad R` and the parameter rows are not needed at all** — `soil_adjoint` already
skips resources whose adjoint is exactly zero, so the case occurs.

**4. The transport algebra in closed form — conditional on requirements.** `odelia::incomplete_gamma`
replaces the tabulation for `b`, `c`, `root_b`, `root_c`. **Its case is correctness, not speed.**
Those four rows are differenced across a grid whose knot *count* steps 100 to 101 under a 1e-6
relative parameter move, with measured errors of 47x, 131x and 10 245x — so when those columns are
computed today they are unreliable. The closed form makes them exact: value agrees to 1.7e-15, the
Leibniz endpoint `dG/dm = exp(-(m/b)^c)` to 1e-13, and the shape channel matches a **plateauing**
reference to 1e-11.

So the decision is a requirements one. **If no gradient with respect to a hydraulic vulnerability
parameter is ever wanted, mask those four and do not build this.** If one is wanted, they are
broken now. Two further pieces come with it: the inverse `psi_from_transpiration` wants
`odelia::implicit_value` on its residual, whose derivative is then `1/G'(psi) = exp((psi/b)^c)`;
and the closed form should become the definition with the forward spline a cache built from it, or
it is the parallel near-copy `build-plan.md` section 2.1 rules out.

### Static profile, per cohort block

Each factor is measured; the composition is arithmetic on measured factors and is **not** itself
measured. Provenance is given for every number because they come from sessions whose absolute
speeds differ by up to 30%, so only the ratios transfer.

| configuration | per-block | how obtained |
|---|---|---|
| as built, unmasked | **19.9 ms** | measured, 1 000-call loop, 81-node patch |
| masked, grids still built | **842 us** | measured, `elapsed / (steps x nodes x 6 x 3)` |
| masked + guard fix, non-leaf trait | **~147 us** | 842 us divided by the **measured 5.71x** |
| the above + one call per graft | **~25 us** | 147 us divided by the **measured 5.97-6.11x** |
| leaf trait requested, + one call per graft | **~940 us** | 5 620 us unmasked at that config, divided by 6 |
| leaf trait requested, + closed form | **~150 us** | 16 tabulations at ~110 us replaced by ~110 closed-form evaluations at 0.68 us |

**The apparent inconsistency in these numbers is resolved, and it corrects the whole table's
denominator.** `graft_leaf_outputs` calls `input_adjoints` **`1 + max_soil_layer`** times, not six:

    const size_t n = static_cast<size_t>(leaf.max_soil_layer);
    for (size_t j = 0; j < n_layer; ++j) {
      if (j >= n) { leaf_soil_consumption_[j] = leaf.soil_consumption_[j]; continue; }  // no call

`max_soil_layer` is the last layer carrying root mass, set from rooting depth `min(height, 1.5)`.
At `max_patch_lifetime = 0.2` cohorts are 0.34-0.5 m tall and root into one or two of five layers,
so a block makes **4 to 6 calls, not 12**. Dividing correctly, `1090 us / (4 to 6 calls x 2
tabulations)` is **91 to 136 us per tabulation**, bracketing the microbenchmark's **121 us**. The
earlier reading of a factor of three came from assuming twelve calls at every configuration.

**So the leaf's call count scales with rooting depth, hence with plant size, hence with lifetime**,
and per-block cost is not a constant of the model. A packet had already observed the symptom — two
per-block figures disagreeing by 1.9x — and attributed it to the node-count divisor; this is the
cause. **C2b's saving is therefore `1 + max_soil_layer`**: close to 6x for fully rooted trees at
production, 2-3x for seedlings.

### The production figure, and what it does and does not license

The production `lma` gradient of **2 995 s** was taken on the guard-fixed build, so its tabulations
were already near zero. Over `4644 x 141 x 6 x 3 = 11.8M` blocks that is **254 us per block**, and
at production every cohort roots to 1.5 m so the count is 12 calls — about **21 us per
`input_adjoints` call**, which is residual-evaluation cost rather than tabulation.

| | projected | basis |
|---|---|---|
| `lma` at production, + C2b | **~700-900 s** | 254 us/block reduced by the measured 5.97-6.11x |
| a leaf parameter, + C2b only | **~6 hours** | tabulations return: 2 calls x 8 tabulations x ~110 us |
| a leaf parameter, + C2b + closed form | **~700-900 s** | tabulations removed |

**The limit on this: there is no profile of the guard-fixed build.** The 50-of-60 histogram was
taken before the guard fix, so what dominates the 254 us is **inferred** to be `input_adjoints` and
not measured. C2b's factor applies to the whole block only if that inference holds, and one
sampling run settles it. Three predictions of this shape have been made in this wave and all three
were wrong, so **that measurement should precede the build, not follow it.**

### What registering a supplied derivative is, precisely

The mechanism is worth stating exactly, because the name `graft_leaf_outputs` describes an
algebraic trick rather than what happens, and the trick is what goes away.

**The leaf's outputs are tape leaves, not tape results.** The tape holds no operations connecting
the leaf's inputs to its outputs — the leaf was solved in `double`, off tape. Four steps:

1. the six output values become fresh tape leaves (`registerInput`, which reads oddly: they are
   inputs *from the tape's point of view*);
2. the input slots are recorded;
3. a checkpoint edge is inserted **at the current tape position**, after the inputs are registered
   and before any downstream use of the outputs;
4. on the reverse sweep, `computeAdjointsTo` sweeps everything recorded after that position, so by
   the time the edge fires all six output adjoints have arrived; the edge reads them, asks the leaf
   for one vector-Jacobian product, and increments the input slots.

Two consequences follow from step 1 and should be kept in `plant/agents.md` §13. The block's forward
value stays independent of a supplied input, so **a block-level finite difference still cannot
referee these partials** — that property belongs to the off-tape solve, not to the algebra, and it
survives the change. And the edge's position is load-bearing: inserted before the inputs are
registered it would fire too early.

### Naming

`graft` and its identity `value + Σ partial_i·(x_i − to_passive(x_i))` are deleted. What replaces
them:

| | |
|---|---|
| odelia | `supplied_derivative(tape, y_values, inputs, vjp)` — a **multi-output overload** of the existing `supplied_derivative`, taking a callable instead of a constant partials vector, and returning the active outputs. The existing single-output, constant-partials form stays for one-shot use. |
| plant | `TF24_Strategy::supply_leaf_derivatives(radiation, area_leaf, psi_soil, kappa)` — replaces `graft_leaf_outputs`. It states what happens: the leaf supplies the derivatives of its own outputs. |
| plant | `Leaf::input_adjoints` — **unchanged**, signature and body. It is already the vector-Jacobian product the callable needs. |

Net effect on concept count: one hand-rolled idiom in plant is deleted, one odelia primitive gains
an overload, and nothing new is introduced. `odelia/AGENTS.md` asks for exactly this — "AD code is
glue around the vendored XAD facilities … invoke them, don't re-implement them."

### Forward spline, closed-form reverse, and how they stay one thing

The two paths want different structures for the same function, and that is not a duplication if it
is arranged as a definition and a cache.

`G(psi) = (b/c)·gamma(1/c, (psi/b)^c)`, the cumulative Weibull vulnerability integral.

| path | structure | why |
|---|---|---|
| forward solve, `double` | 100-knot spline, built once per `Leaf` at construction | many queries per solve — one per Newton iteration per layer — so a 100-evaluation build is amortised and a lookup is the right cost |
| reverse, derivative | **no table**; evaluate the closed form at the points actually needed | the code's own comment says the queries "resolve to exactly one of `{-psi_soil[i], -P_x_r, 0}`", and `refresh_soil_potentials` does `n` of them, so the derivative path makes **`n + 2` = 7 queries** and never amortises a build |

**The measured consequence.** One tabulation is **121 us**; seven closed-form evaluations are
**0.5 us** value-only or **4.8 us** carrying value, `d/dx` and `d/da` on a reused tape — 25x to
250x for the same information. The derivative path also stops needing a central difference at all:
`d/db` and `d/dc` come from the same evaluation, so the four hydraulic rows become exact and can no
longer straddle the knot-count step that gives them errors of 47x, 131x and 10 245x today.

**One expression of the physics.** `Leaf::set_transpiration_at`,
`Leaf::set_root_vulnerability_at` and `Leaf::build_cumulative_vulnerability_integral` all evaluate
`boost::math::tgamma_lower` per knot. Those become calls to `odelia::incomplete_gamma`, so the
spline is built **from** the closed form and there is one definition with a cache in front of it,
rather than the parallel near-copy `build-plan.md` §2.1 rules out.

**And that unification moves a forward number, so it is staged.** `incomplete_gamma` agrees with
`tgamma_lower` to **1.7e-15**, not to the last bit, and the adaptive controller amplifies last-bit
differences into a different accepted grid. So:

- **stage A, no re-bless**: the reverse path uses the closed form; the forward tabulation keeps
  `boost::math`. The forward model is bit-identical by construction because nothing on the `double`
  path changes. Two expressions of `G` exist, agreeing to 1.7e-15 — a duplication that is measured
  rather than assumed, and recorded as owed.
- **stage B, with a re-bless**: the forward tabulation is rebuilt from `incomplete_gamma`, leaving
  one definition. This moves offspring and the accepted step count by roughly the 0.145% that
  report 01 §2 measures between two builds of one tree, so it needs the owner and a
  `scientific_version` bump.

**Open, and it is the one thing that could enlarge stage A**: `psi_from_transpiration` is the
*inverse* of `G`, and if the reverse path reads it then it needs `odelia::implicit_value` on the
residual, with `dpsi/dG = 1 / G'(psi) = exp((psi/b)^c)` closed form. It is read by
`find_psi_stem_from_psi_root`, which is part of the `double` forward solve, so it may not be on the
derivative path at all. **Check before scoping; do not assume either way.**

### The three properties this is trying to hold together

**Clean.** One primitive replaces one hand-rolled idiom; `graft` and its identity are deleted;
`Leaf::input_adjoints` is untouched; `G` has one definition with a cache in front of it. Concept
count goes down, not up.

**Performant.** Every factor below is measured; the products are arithmetic on them and are marked
as such.

| | per block | at production |
|---|---|---|
| as built, all traits | 19.9 us x 1000 = 19.9 ms | — |
| guard fix + mask, `lma` | **254 us** (measured) | **2 995 s** (measured) |
| + one call per graft | ~40-80 us | ~700-900 s |
| a hydraulic parameter, as built | ~14 ms | ~46 hours |
| + one call per graft | ~2.3 ms | ~7.7 hours |
| + closed-form reverse | ~128 us | **~1 500 s** |

**Stable.** The leaf stays `double` and its solve stays untaped, so report 02's boundary does not
move. Stage A changes no forward number, so every gate is bitwise equality against the build before
it rather than a new tolerance. `pushCallback` once and `insertCallback` per recording bounds
callback allocation, which the naive registration does not. And the four hydraulic columns go from
*silently wrong* to exact, which is a stability improvement that no timing shows.

### What the design does not touch

The leaf stays `double`. The solve stays untaped. `Leaf::input_adjoints`' signature is unchanged.
Report 02's boundary is not relaxed by components 1 to 3, so none of them needs a re-bless, a
`scientific_version` bump or an owner decision, and each is gated by bitwise equality against the
build before it. Only component 4 touches the forward path, and only if the spline becomes a cache
of the closed form.

---

## 7. What remains open, and what each open item blocks

- **`∇(∂Π/∂p)` is still the design's one unbuilt expression.** Report 00 §10: "It is one
  derivative of one closed-form expression, it must include the `ci` root-find's own
  implicit-function term, and it is the single new piece of code the whole design needs." C3
  supplies the transport part of it; the rest is a derivation. Report 00 §9 records its
  conditioning as never measured, which is a gate problem as much as a maths one.
- **`Π_pp` cannot be refereed by report 02 §6.9's stationarity identity**, because `dp*/du` is
  formed from `Π_pp` and cancels — a real 2% error survived it at 4.54e-10, bit-for-bit unchanged
  before and after the fix. So no gate above may use that identity as its reference.
- **The 65 us per-block figure is not a fair target.** It was measured before P3.3's leaf
  parameter rows were wired, when `graft_leaf_outputs` truncated all fifteen with `row.resize` —
  so it is very likely the cost of a block whose leaf parameter Jacobian was *absent*. The cost
  model wants re-deriving against a block that carries its rows.
- **Interior production-like leaf states abort** inside `input_adjoints` through `util::stop` in
  `Leaf::psi_stem_to_ci` when TOMS748 fails to bracket. So no gate above can currently be seeded
  at a state that is both interior and production-like, which is a hole under every one of them.
- **The four hydraulic vulnerability columns are incorrect as computed, and are recorded as a known
  defect rather than fixed.** `b`, `c`, `root_b` and `root_c` are obtained by a central difference
  across a grid whose knot **count** steps between 100 and 101 under a 1e-6 relative parameter move,
  with measured errors of **47x, 131x and 10 245x**. A gradient requested for any of those four
  should be treated as unreliable until the closed form lands. The other 40 registered traits are
  unaffected: 33 are not leaf parameters at all, and the remaining seven have exact profit rows.
- **`beta_R_H` and `beta_R_V` have no row**, so a strategy varying either reads exactly zero.
- **`psi_crit` and `root_psi_crit`** are zero except when pinned, and the pinned-state gap —
  adjoint 0 against a whole-solve difference of −2.39e-04, rel 1.0 — is unexplained.
- **There is no cost gate anywhere.** Nothing asserts a block VJP costs what it was measured to
  cost, which is how a 300× regression sat behind a probe reading 2, a clean leaf gate, V1 at
  3.33e-15 and a green suite for three waves. Every component above should land with one.
- **`Patch::block_recording_size` and `block_sweeps` are not exported to R**, so the instrument
  for this design's worst failure mode needs a C++ harness to read.
- **`Species::set_birth_state` exists and is called by no test**, while report 01 C6 says the
  reverse pass must restore what it sets.

---

## 8b. Adversarial review of this design

Five defects and one omission found by re-tracing the design against the code rather than against
itself. Two would have failed a build; one changes which components are optional.

### A. The callback reads leaf state that has been overwritten by the time it fires

**This is a correctness defect, not a cost one, and it invalidates the naive form of C2b.**

`supply_leaf_derivatives` runs during the block's forward recording, while the `Leaf` holds the
operating point the graft belongs to. `computeAdjoint` runs later, on the reverse sweep. Between
those two moments the same `Leaf` object is re-solved: `Individual::log_density_rate` calls
`growth_rate_gradient`, which copies the `Individual`, **shares the strategy and therefore the
`Leaf`**, and re-solves it at `height - 1e-6`. So a lazily-computed Jacobian for the *first* graft
would be evaluated at the *probe's* operating point.

The algebraic graft is immune because it materialises its partials immediately, while the operating
point is still correct. The corpus records the sibling hazard — "no active value may outlive a
recording" — and this is its off-tape twin: **no off-tape state a callback reads may be mutated
between the recording and the sweep.**

**The fix, and it keeps the saving.** The callback captures the leaf's operating point at
registration and restores it before calling `input_adjoints`. That is a handful of scalars plus
three short vectors — `p*`, `psi_stem`, `ci`, `E_up_`, `soil_consumption_`, `psi_soil_inverted_`,
`root_vuln_integral_soil_`, `vcmax_`, `jmax_`, `electron_transport_`, `R_d_`, `area_leaf_`, `PPFD_`,
`leaf_specific_conductance_max_`, `max_soil_layer`, `collar_pinned_` — on the order of a hundred
bytes per graft, against six vector-Jacobian products. `Leaf::input_adjoints` already saves and
restores its outputs for the same reason, so the precedent and the field list both exist.

**Gate for it**: a block with two grafts must give adjoints bitwise equal to the algebraic graft's.
A single-graft test would pass with the defect present, so the gate has to be a block whose
`log_density_rate` probe fires — which is every real block, and no toy.

### B. The callback is reverse-only; the graft is mode-agnostic

`CheckpointCallback` is a `Tape` concept. It does not exist in forward mode. The algebraic graft
works for **both** active types, because `graft_leaf_outputs` is guarded only by
`if constexpr (!std::is_same_v<S, double>)` and its arithmetic is valid for `FReal` as for `AReal`.

So **deleting the graft removes the ability to differentiate the block in forward mode**, which is
the one exact referee available for the whole-run accumulation. The claim in §6b that `graft` is
deleted is wrong if a tangent mode is ever wanted.

**Resolution**: dispatch on the mode — callback for reverse, algebraic graft for forward — which
keeps both paths and means the concept count does **not** fall. That is a real cost of C2b and §6b
overstated its cleanliness.

### C. The profile omits the field-rebuild term, and Amdahl bounds C2b well below 6x

§6b divides the whole 254 us per block by the measured 5.97-6.11x. That is wrong, because a
significant share of the gradient is not in the block at all.

`Step::step_adjoint` does **12 field builds per step per metric** — six `ode::derivs` to rebuild the
stage rates and six `set_ode_state_and_field` in the sweep. From the measured forward run, 138.6 s
over 4 644 steps is 29.8 ms per step for six stages, so a stage costs about **5 ms** at 141 cohorts.
Twelve per step over 4 644 steps and three metrics is **on the order of 600-840 s of the 2 995 s**,
i.e. **20-28%**, and C2b does not touch any of it.

    C2b alone:  0.25 + 0.75/6  =  0.375  ->  about 2.7x, not 6x
    C1 + C2b:   (0.25 + 0.75/6) / 3      ->  about 8x

**So C1 — one sweep carrying `M` seeds — is not optional, it is what makes C2b worth having.** It
divides the field term by `M` as well as everything else. §6b's projections should be read as:

| | projected | note |
|---|---|---|
| `lma`, + C2b only | ~1 100 s | Amdahl-bounded by the field term |
| `lma`, + C1 and C2b | **~375 s** | |
| a hydraulic parameter, + C1, C2b, closed form | ~450 s | |

These are arithmetic on measured factors, and the field share is derived from a forward-run
timing rather than measured in the reverse pass, so treat 20-28% as a bracket.

### D. Report 02 §6.8 under-counts the leaf's parameter inputs, and misses the costly ones

§6.8's table lists **12**: `vcmax_25`, `jmax_25`, `a`, `curv_fact_elec_trans`, `curv_fact_colim`,
`b`, `c`, `psi_crit`, `beta2`, `g1_TF24`, `rho`, `a_bio`. The code has **15** — it adds `root_b`,
`root_c`, `root_psi_crit`, and two of those three are among the four that rebuild a tabulation.

And §6.8's scaling claim covers only the state directions: *"Nor does it grow with the layer count
in the expensive direction: the `2n + 1` potential, root-mass and leaf-area directions cost the two
scalars of §6.3 however large `n` is."* True as written, and **silent on the parameter directions**,
which cost one residual pair each. **The design asserted a scaling property for the cheap half of
the bundle and said nothing about the expensive half.**

### E. `Leaf::translation_partials` is not dead, and an earlier note here was wrong

It is called by `scratch/leaf_jac_gate.cpp`, the committed gate harness — §6.9 verification
machinery rather than a production channel. An earlier version of this report called it dead on a
grep of `src/` and `inst/` only.

### F. The positive-sum item: the ecologically meaningful census costs the same as this one

`census_trait_gradient` differentiates the census **at one patch age**. The stand-level quantity is
the disturbance-weighted integral over patch ages, `integral rho(t) census(t) dt`, which is what
`R0` already is for fecundity — and it is what an ecologist would want a sensitivity of.

For an adjoint that is **the same single sweep**. A functional distributed in time changes the
adjoint ODE from `lambda' = -lambda^T df/dy` to `lambda' = -lambda^T df/dy - dg/dy`, i.e. inject
`rho(t) d(census)/dy` as a source at each step of the sweep the code already runs. The trait
accumulation is unchanged. **A time-integrated census gradient therefore costs the same as a
terminal one**, where a finite difference would pay for it again at every age.

`Patch` already carries the disturbance weighting (`r_density`, `pr_survival`,
`survival_weighting_cdf`), and `SCM::census_state_adjoint` already builds the seed at one time, so
the change is a seed injected per step rather than once. Recorded as an opportunity, not scoped.

---

## 9. Summary

Three of the four subsystems represent their physics in a form a tape can differentiate directly.
The light field is an interpolant with `double` knot positions and values and slopes carrying `S`.
The soil cascade is closed form and its transpose is written out. A cohort block is elementary
arithmetic recorded on a tape.

The leaf represents its transport as a table of 100 knots, built from the four parameters whose
derivatives are wanted, on a grid whose spacing and count are functions of those parameters. The
table is built inside the innermost loop: 14 tables per `Leaf::input_adjoints` call, 12 calls per
cohort block, one set of blocks per census metric. Each table is built to answer `n + 2` = seven
queries and is then discarded.

Four existing documents state what the leaf should do instead:

- report 01 §4.1 — do not build the four 100-knot interpolators per cohort per stage.
- report 01 §10 rule 3 — a cache must be keyed on everything its value depends on, or not exist.
- report 02 §6.4 — the interpolant positions are constant and the values carry the parameter.
- report 03 — that arrangement, built and working, for the light field.

The work in §6 makes the leaf match them.
