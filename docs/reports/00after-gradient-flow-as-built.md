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

## 5. The design to build

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
gradR      (28)        the waist: a * dE_up/du + b * d(dE_up/dr)/du
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

**Why closed form rather than a cache.** A tabulation is amortisation. The forward solve
amortises it over many Newton iterations times layers, so a spline is right there. **The
derivative path queries `n + 2` points and throws the table away** — it never amortises. A cache
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
path keeps its amortisation, and the knot grid becomes an implementation detail of a cache rather
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

**Mechanism.** `traits` does not reach C++; `ad_parameters()` is unconditional. The four
expensive rows are needed only when a hydraulic trait is requested, and the rows are independent
columns, so not computing them is exact rather than approximate.

**Interaction, and it is the important one: C4 and C3 are substitutes, not complements.** If C3
lands, the transport rows are cheap and C4's cost argument evaporates. C4's residual value is then
API honesty — one trait costs one trait's work — and a narrower blast radius for the forward
model's knot-count defect, since a caller who never requests `b` never differences across the
moving grid. **Do not build both for the same reason.**

**The hazard that governs it.** A skipped row must be **absent, never zero**. Exactly-zero reads
as an answer and is this design's worst failure mode; it has already cost two waves here, when
fifteen correctly computed rows were truncated and eleven trait columns read exactly 0 behind five
green gates. So the mechanism is a per-parameter computed flag with a hard failure on reading an
uncomputed row, and returned columns that are absent rather than zeroed — never a zero fill.

**Gate.** The requested column bitwise identical to the unrestricted build's, plus a
demonstration that reading an unrequested row fails loudly.

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

## 7. What remains open, and what each open item blocks

- **`∇(∂Π/∂p)` is still the design's one unbuilt expression.** Report 00 §10: "It is one
  derivative of one closed-form expression, it must include the `ci` root-find's own
  implicit-function term, and it is the single new piece of code the whole design needs." C3
  supplies the transport part of it; the rest is a derivation. Report 00 §9 records its
  conditioning as never measured, which is a gate problem as much as a maths one.
- **`Π_pp` cannot be refereed by report 02 §6.9's stationarity identity**, because `dp*/du` is
  formed from `Π_pp` and cancels — a real 2% error survived it at 4.54e-10, bit-for-bit unchanged
  before and after the fix. So none of the gates above may lean on that identity.
- **The 65 us per-block figure is not a fair target.** It was measured before P3.3's leaf
  parameter rows were wired, when `graft_leaf_outputs` truncated all fifteen with `row.resize` —
  so it is very likely the cost of a block whose leaf parameter Jacobian was *absent*. The cost
  model wants re-deriving against a block that carries its rows.
- **Interior production-like leaf states abort** inside `input_adjoints` through `util::stop` in
  `Leaf::psi_stem_to_ci` when TOMS748 fails to bracket. So no gate above can currently be seeded
  at a state that is both interior and production-like, which is a hole under every one of them.
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

## 8. The shape of the whole thing, in one paragraph

Light, soil and the cohort blocks each represent their physics in a form that differentiates
cleanly: a fixed-position interpolant whose values carry the scalar, a closed-form bidiagonal
cascade, and elementary arithmetic on a tape. The leaf alone represents its transport as a table
rebuilt from the parameters being differentiated, on a grid that is itself a function of them —
and the table is rebuilt inside the innermost loop of a five-deep nest, to answer seven queries,
twelve times per cohort block, once per census metric. The design's own documents forbid this from
four directions: report 01 §4.1 forbids building those interpolators per cohort per stage, report
01 §10 rule 3 forbids the cache that would paper over it, report 02 §6.4 specifies constant
positions with values carrying the parameter, and report 03 has that arrangement built and working
for the light field. The work is to make the leaf conform.
