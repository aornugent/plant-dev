# The gradient flow as built: where the work goes, and what is invariant

A trace of the reverse pass this project actually has, level by level, against the design
reports 00, 01 and 02 specify. Written after the whole-run gradient was measured for the first
time. Numbers labelled **measured** were produced in wave 6 and the command that produced them
is in `../implementation-notes.md` under *Phase 3, wave 6*; everything else is read directly
from plant `dad51118` and odelia `3bb2e46`, cited by symbol.

**Why this report exists.** The design was verified in pieces and each piece held. Then the
whole was run end to end and cost about 300 times its budget. Nothing in the corpus traced the
composition, so nothing in the corpus could have predicted that. This is the composition.

---

## 0. The one-sentence finding

**The gradient is not expensive because it differentiates. It is expensive because invariant
work sits inside varying loops, at three nested levels at once.**

1. A table that depends on four numbers **constant for the whole run** is rebuilt in the
   innermost loop, on the order of 10¹⁰ times.
2. The leaf's parameter Jacobian, which **does not depend on the output seed**, is rebuilt once
   per seed — twelve times per cohort block.
3. The whole sweep, whose **recordings do not depend on which metric** is being differentiated,
   is repeated once per metric.

Every one of these is a property of the composition rather than of any component, which is
exactly why every component gate passed.

---

## 1. What the design specifies, and the status of each claim

| claim | where | status |
|---|---|---|
| store the trajectory in `double`, record and sweep one cohort at a time | report 01 §1 | **built and holds** |
| within a stage, cohorts couple only through one scalar field of height | report 01 §1 | **built and holds** |
| the leaf stays `double`; the tape gets one node with a supplied Jacobian | report 02 §6 | **built and holds** |
| carbon is an envelope row, no argmax derivative | report 02 §6.1 | **built, exact** |
| water is rank one in the argmax: one `μ_k = −s_k/Π_pp` per cohort | report 02 §6.2 | **built, exact** |
| the `2n+1` geometry directions collapse to a waist, `a` and `b` two shared scalars | report 02 §6.3 | **built, exact** (`dR_dflux`, `dR_dflux_slope`) |
| the pinned branch is the bound's own derivative | report 02 §6.7 | **built, exact** (`Leaf::bound_partials`) |
| `dp*/dθ` as a Jacobian never appears; cost is independent of trait count | report 00 §6.2 | **built and holds** — see §5 |
| the interpolants are built **once per `Leaf`** | report 02 §6.4 | **not built** — see §4 |
| `∇(∂Π/∂p)`, "the single new piece of code the whole design needs" | report 00 §7, §10 | **not built** — 11 rows are residual pairs |

Nine of eleven load-bearing claims are built and hold. The two that are not are the whole of
the cost.

---

## 2. The flow, level by level

`M` = census metrics (3 today), `S` = accepted steps, `B` = introduction boundaries,
`C` = cohorts, `P` = 44 registered parameters, `n` = soil layers.

```
SCM::census_trait_gradient
├── store_trajectory()                                   1 extra full forward run
│     ode_step_record is {time, step_size, state} only.
│     Patch::has_recorded_field() is false and record_stage() is an empty body,
│     so no field and no stage values are kept.
├── boundary detection, then newest-first narrowing       B
├── census_state_adjoint<Metrics>()                       M recordings of the reduction
└── for each metric m in M                                <<< the outer repetition
    ├── widen_over_introductions                          B field builds  (seed-independent)
    ├── for each segment j in B  (newest first)
    │   ├── Solver::solve_adjoint(sweep_states, lambda, b, k_last)
    │   │   └── for k = k_last down to k_first+1           S steps in total
    │   │       └── SolverInternal::step_adjoint
    │   │           └── Step::step_adjoint
    │   │               ├── rebuild the six stage rates    6 x ode::derivs, each a full
    │   │               │                                  field build; k1 re-derived
    │   │               │                                  because first-same-as-last
    │   │               │                                  carried it across steps forward
    │   │               └── sweep_stages, i = 5..0         6 x stage_state
    │   │                   └── per stage
    │   │                       ├── set_ode_state_and_field   <<< a second field build
    │   │                       ├── set_ode_aux(aux[i])
    │   │                       └── Patch::ode_rates_adjoint
    │   │                           ├── soil_adjoint          closed form
    │   │                           ├── offspring_adjoint     closed form
    │   │                           ├── cohort_block_adjoint  C recordings + C sweeps
    │   │                           ├── light_knot_adjoint    closed form
    │   │                           └── allometry_adjoint     closed form
    │   └── introduction_adjoint                          own tape, built and destroyed
    └── read live.trait_adjoint
```

**Counts per gradient call.** Block recordings `M · S · 6 · C`. Field builds `M · S · 12`
against the forward run's `S · 6`. Tapes constructed and destroyed `M · B` in
`introduction_adjoint` alone. The block's tape is the exception and is cached on the patch
(`block_state::tape`) — but `odelia::ode::vector_jacobian_product` calls `clearAll()` and
`newRecording()` on entry, so what persists is the allocation, not the recording.

At production — `S = 4644`, `C ≈ 95`, `M = 3` — that is **7 941 240 block recordings**.

---

## 3. Inside one block: what is exact and what is differenced

One `cohort_block_adjoint` records 185 inputs to 12 outputs per cohort, both counts computed
rather than literal:

| in | | out | |
|---|---|---|---|
| strategy state | 6 | strategy rates | 6 |
| light knot values | 65 | `log_density_rate` | 1 |
| light knot slopes | 65 | consumption rates | 5 |
| soil potentials | 5 | | |
| registered parameters | 44 | | |
| **total** | **185** | **total** | **12** |

Around it sit four closed-form transposes (`soil_adjoint`, `offspring_adjoint`,
`light_knot_adjoint`, `allometry_adjoint`), all cheap and all exact. Inside it,
`TF24_Strategy::graft_leaf_outputs` attaches the leaf's supplied Jacobian, obtained from
`Leaf::input_adjoints`.

Two of the 44 registered parameters are worth noting as inert: `x` picks up all fifteen names
the leaf declares, but `vcmax_25` and `jmax_25` are **not** in `ad_parameters()`, so
`x[i] - to_passive(x[i])` is identically zero for them and their rows never reach an adjoint.

`Leaf::inputs()` is `2n + 3 + 15`: `PPFD`, `psi_soil[0..n-1]`, `area_leaf`,
`mass_root[0..n-1]`, `leaf_specific_conductance_max`, then fifteen named parameters.

The fifteen parameter rows, read off `input_adjoints`:

| rows | `∂Π/∂param` | `∂R/∂param = ∂²Π/∂p∂param` |
|---|---|---|
| `vcmax_25`, `jmax_25`, `a`, `curv_fact_elec_trans`, `curv_fact_colim` | **exact**, `forward_derivative` of the templated evaluators | **differenced** |
| `beta2`, `g1_TF24` | **exact**, `forward_derivative` of `hydraulic_cost_ad` | **differenced** |
| `b`, `c`, `root_b`, `root_c` | **differenced**, through a transport rebuild | **differenced** |
| `psi_crit`, `root_psi_crit`, `rho`, `a_bio` | zero by construction, skipped in the interior branch | not taken |

So **7 of 15 have an exact profit row and 0 of 15 have an exact mixed second derivative.**
Every parameter that reaches the operating point costs two evaluations of
`dprofit_droot_collar_psi`; the four transport parameters additionally cost, per side, a
`refresh_soil_potentials`, a `find_psi_stem_from_psi_root`, a `profit_psi_stem_TF` and an
`E_from_Soil_to_Root_Collar`. `PPFD` and `leaf_specific_conductance_max` get their own residual
pairs outside the parameter loop.

### 3a. Twelve Jacobians per block, eleven of them redundant

`graft_leaf_outputs` calls `Leaf::input_adjoints` **once for profit and once per rooted layer**:

```cpp
leaf.input_adjoints(1.0, lambda, row);
leaf_profit_ = graft(leaf.profit_, row, x);
...
for (size_t j = 0; j < n_layer; ++j) {
  ...
  lambda[j] = 1.0;
  leaf.input_adjoints(0.0, lambda, row);
  leaf_soil_consumption_[j] = graft(leaf.soil_consumption_[j], row, x);
}
```

That is `1 + max_soil_layer = 6` calls. And `graft_leaf_outputs` itself runs **twice** per block,
because `Individual::log_density_rate` calls `growth_rate_gradient`, which copies the individual
— sharing the strategy, hence the `Leaf` — and re-runs a complete rate evaluation at
`height − 1e-6`. **So one block costs 12 `input_adjoints` calls**, and at the defaults
(`node_gradient_direction = -1`, `node_gradient_richardson = false`) that is exactly one extra
evaluation; centred differencing would make it 18 and Richardson at depth 4 would make it 54.

**The expensive part of each call is seed-independent.** The differencing loop fills
`dprofit_dpar`, `dE_dpar` and `dR_dpar`, and the seed enters only in the final contraction:

```cpp
input_adjoints[i_par0 + k] = lambda_profit * dprofit_dpar[k];
for (int j = 0; j < n && !dE_dpar[k].empty(); ++j) {
  input_adjoints[i_par0 + k] += lambda_uptake[j] * dE_dpar[k][j];
}
```
plus `input_adjoints[i_par0 + k] += mu * dR_dpar[k]` on the interior branch. So the six calls
per graft compute **one** parameter Jacobian six times and use each copy for one seed. This is a
vector-Jacobian product being used where a Jacobian-then-contract would serve, and it is the
same error as level 3 of §0 one loop further in.

**On the pinned path it doubles again**: `bound_partials` repeats the grid capture and the same
four-parameter differencing, so a pinned cohort pays the transport rows twice.

### 3b. The four transport parameters reach the block only through the leaf

Exhaustively: `pars.b`, `pars.c`, `pars.root_b`, `pars.root_c` appear at four kinds of site —
`ad_parameters()`, `leaf_parameter_address`, `TF24_Pars::field_ptrs()`, and the `Leaf`
construction in `prepare_strategy`. No allometry, respiration, turnover, mortality, fecundity,
storage or root-profile equation reads them, and `TF24f_Strategy` adds no reader.

Stronger still: `Leaf`'s own `b`, `c`, `root_b`, `root_c` are set **at construction only** —
`set_physiology`'s signature contains no `b` or `c` argument — so writing `pars.b` after
`prepare_strategy()` does not change the leaf's forward answer at all. The derivative exists
purely as the supplied row, which is what `graft_leaf_outputs` means by "the block's value is
deliberately independent of them and a block-level difference cannot referee them."

They are also constant across a run. They are plain value members of `TF24_Pars<S>`; the only
writers anywhere — `set_block_inputs`, `introduction_adjoint`'s `introduce` lambda, and
`rebind_from` — all write onto an **active-scalar** copy, never the resident `double` strategy,
whose `pars` is untouched after `prepare_strategy()` runs once inside `make_strategy_ptr`.

---

## 4. The invariance, which is the finding

`Leaf::build_cumulative_vulnerability_integral`, `Leaf::set_transpiration_at` and
`Leaf::set_root_vulnerability_at` are **pure functions of `(b, c, resolution)` and
`(b_at, c_at, x)`**. Every value in their bodies comes from those arguments and from literals.
None reads `area_leaf_`, `psi_soil_`, `PPFD_`, `root_collar_psi_`,
`leaf_specific_conductance_max_`, a height, a cohort index or a time. `vulnerability_curve_ncontrol`
is set at construction and never reassigned.

`b`, `c`, `root_b` and `root_c` are strategy parameters, fixed for the duration of a run.

**Therefore the perturbed tables at `b ± h`, `c ± h`, `root_b ± h`, `root_c ± h` are
bit-identical at every cohort, every stage and every step of a run.** `input_adjoints` builds
about fourteen of them per call — two grid builds plus three `set_*_at` calls per transport
parameter — each roughly a hundred `boost::math::tgamma_lower` evaluations. With **12
`input_adjoints` calls per block** (§3a) that is on the order of 1.7 × 10⁴ incomplete-gamma
evaluations per block, and at production, across `M · S · 6 · C` blocks, on the order of
**10¹¹ incomplete-gamma evaluations to produce a few hundred distinct numbers.**

Measured, and this is what makes the reading more than arithmetic: **28 of 30 gdb samples land
inside `boost::math::gamma_incomplete_imp<long double, …>`** called from those three builders,
24 of 30 inside glibc's `__ieee754_powl` / `powl_helper` / `__ieee754_logl` beneath them, and
**0 of 30 inside any leaf solve** — not `find_root_collar_psi`, `polish_root_collar_psi`,
`prepare_collar_solve`, `optimise_psi_stem`, `assim_colimited`, `E_from_Soil_to_Root_Collar` or
`dR_dcollar`. No sample has an `xad::` function as a frame, so it is not recording overhead
either.

The `long double` is not deliberate: no policy argument is passed and no `BOOST_MATH_*` macro
exists in the package, so it is boost's default `promote_double<true>`.

**Report 02 §6.4 already specified the invariance**, in words this project read past twice:

> The transpiration and root-vulnerability interpolants are **built once per `Leaf`** from `b`,
> `c`, `root_b` and `root_c` over a hundred control points. Their positions are constant and
> their values carry the parameter.

Both halves are true of the design. The first half — once per `Leaf` — is not what the code
does. The second half, constant positions, **is** what the code does *on the derivative path*:
`input_adjoints` captures `knots_stem` and `knots_root` once before its loop and passes them to
the `_at` variants, precisely so the grid is held still. The moving-grid defect recorded against
§6.4 belongs to the **forward** builder, which sets `psi_max = b·log(100)^(1/c)` with a
`psi <= psi_max` loop bound and so steps its knot count between 100 and 101. Those are two
different sites and this corpus has conflated them.

---

## 5. What the design got right, and it is worth stating plainly

**The trait count really is free.** `TF24_Strategy::ad_parameters()` returns all 44 pointers
unconditionally; there is no per-trait loop anywhere in the sweep, and `traits = "lma"` versus
all 44 changes no evaluation count. The trait count enters only as the accumulator's length and
as 44 extra registered inputs per block. Report 00 §6.2's central cost claim — that `dp*/dθ`
never appears and cost is independent of trait count — **holds as built**.

**The expensive axis is the codomain, not the domain.** Reverse mode is cheap per input and
dear per output, and the outputs are the census tuple. `plant/agents.md` §13 says a metric is
added "without touching the reduction, the reverse pass or `odelia`", which is true of the code
and false of the cost: each metric is a full extra sweep of `S · 6 · C` recordings. A fourth
metric is a 33% cost increase, and nothing says so.

---

## 6. The three proposals, re-evaluated against the trace

| | what it does | class | what the trace says it buys |
|---|---|---|---|
| **1** | derive `∇(∂Π/∂p)`, replacing 11 residual pairs | derivative-only, forward bit-identical | removes the **pairs**. Does not remove the tabulations, which are the measured cost. Still owed: report 00 §10 calls it the design's one new piece of code, and §9 records its conditioning as never measured |
| **2** | fix the forward builder's moving knot grid | **forward model**, `scientific_version` bump, owner's | fixes the 47× / 131× / 10 245× straddling **in the forward model**. Buys no adjoint speed |
| **3** | hold the base grid on the derivative path | — | **already implemented.** `input_adjoints` captures the grids before its loop |

None of the three addresses the measured cost. That is the report's most useful negative
result, and it is the reason to write the trace before choosing a fix.

---

## 7. What the trace suggests instead, ordered by ratio of gain to risk

Stated as candidates with their evidence, not as a plan.

**A. Hoist the parameter-only tabulations out of the inner loop.** Cache the perturbed spline
sets on the `Leaf`, keyed on `(b, c, root_b, root_c, vulnerability_curve_ncontrol)`, and build
them once per gradient rather than once per call. Justified by §4: they carry no state.
Derivative-only, forward bit-identical, needs no new mathematics and no owner decision. It
addresses the site holding 28 of 30 samples.

**A′. Contract one leaf Jacobian against all six seeds** instead of rebuilding it per seed
(§3a). The differencing loop's outputs are seed-independent; only the final combination is not.
This is the same hoist as **A** one loop further out, it is confined to `graft_leaf_outputs` and
`input_adjoints`, and it is worth up to 6× before **A** removes the tabulations underneath it.
Under the current control defaults it compounds with the probe's second evaluation for 12.

**B. Share one block recording across the metric loop.** The recording's inputs carry no seed;
only `out_adjoint` does. Record once, contract `M` times — or seed all `M` at once in vector
mode. A factor of `M`, today 3, for no change in mathematics.

**C. Stop rebuilding the field twice per step.** `M · S · 12` field builds against the forward
run's `S · 6`. Six are the stage-rate rebuild and six are `set_ode_state_and_field` in the
sweep, at the same stage states. Whether they can share is a design question about
`has_recorded_field()`, which is currently `false` with `record_stage()` an empty body.

**D. Make the sub-grid probe pay once.** Half the `input_adjoints` calls come from
`growth_rate_gradient` re-running everything at `h − 1e-6`. The two evaluations differ by a
micron in height and share every parameter-derived object; under **A** they would share the
tabulations outright.

**E. Treat the cost and the accuracy defect as one.** Only a finite difference can straddle a
moving knot count. Remove the differencing (**1**) or fix the grid (**2**) and the 10 245×
error cannot arise. These have been tracked as two items in two documents; they are one
mechanism seen from two sides.

**F. `promote_double<false>`.** Boost is promoting to `long double` by default and nothing here
asks for it. Worth noting mainly for what it illustrates: under **A** the constant-factor
argument becomes irrelevant, which is the general shape of a structural fix beating a
constant-factor one.

**G. The uncomfortable one.** §11.4 of `ORCHESTRATOR.md` budgets record-and-sweep against
*recorded arithmetic* and wave 2 measured the block as "dominated by the leaf solve rather than
by recorded arithmetic", at a tape-less overhead of 1.19×. Both are consistent with the truth
being neither: the cost is in **parameter-only tabulation that should not be in the inner loop
at all.** The cost model wants re-deriving against this trace, not against either earlier
reading.

---

## 8. Open, and named so it is not mistaken for settled

- **Whether A reaches V4.** Production is **measured** at 12.16 hours per trait against a
  ~516 s budget. A removes most of the gamma work and B a factor of `M`, but neither has been
  measured and this report deliberately contains no projection of their product.
- **`∇(∂Π/∂p)`'s conditioning**, which report 00 §9 has listed as unmeasured since the design.
- **`beta_R_H` and `beta_R_V` have no row**, so a strategy varying either reads exactly zero.
- **`psi_crit` and `root_psi_crit` are zero except when pinned**, and the pinned-state gap
  (adjoint 0 against a whole-solve difference of −2.39e-04, rel 1.0) is unexplained.
- **Interior production-like leaf states abort** inside `input_adjoints` through `util::stop` in
  `Leaf::psi_stem_to_ci` under the parameter perturbations, so the eight-state Jacobian gate
  covers no state that is both interior and production-like.
- **There is no cost gate anywhere.** No assertion says a block VJP costs what wave 2 measured,
  which is why a 300× regression sat behind a probe reading 2, a clean leaf gate, V1 at
  3.33e-15 and a green suite for three waves.
- **`Patch::block_recording_size` and `block_sweeps` are not exported to R.** They are the
  instrument for this design's stated worst failure mode and reading them needed a C++ harness.
