# Constraint inventory — per component, with evidence

**What this is.** Not a synthesis. The individual constraints each component imposes, listed
separately so they can be reviewed in aggregate before the design space is reopened. Hundreds of
probes produced these; collapsing them into six R-lines threw away the specifics that any design must
actually satisfy, and an earlier draft of this file made exactly that mistake.

**Two kinds of statement are kept strictly apart.**

- **C-constraints (§2–§19)** — properties of plant, the models, the maths, or the AD substrate. True
  regardless of which design we choose. These are requirements.
- **Quarantine (§20b)** — claims recovered from the Oracle responses and the deepenings that WOULD be
  constraints if they still hold, but whose only evidence is a document. **Not usable until verified.**
  §20b carries each one's source, date, staleness risk and the test that would settle it.

**§20 is the untested register** — per component, with what would settle each. **§20c is the strategy
for proving §20 and §20b are not missing anything**, which is a different job from extending them.

The *current candidate's* properties are deliberately **not** in this file; §21 says where they live.

> **WHERE THE EVIDENCE LIVES.** This file is the only document kept on this branch. Every citation of
> the form `docs/reference/<probe>` or `v3-facts.md §N` resolves against **`claude/odelia-ad-tape-reverse-496fuf` at `afac480`**, where the
> probes and the four ledgers (`v3-facts.md`, `v3-dead-ends.md`, `v3-engine-design.md`,
> `v3-control-flow.md`, plus `HANDOFF.md`, `oracle/`, `deepenings/`, `archive/`) are intact. Recover any
> of it with:
>
> ```bash
> git checkout claude/odelia-ad-tape-reverse-496fuf -- docs/          # everything
> git checkout claude/odelia-ad-tape-reverse-496fuf -- docs/reference # just the runnable probes
> ```
>
> **The `docs/reference/*.{cpp,R}` probes are the evidence for most C-lines below**, so a line's
> re-run command is only executable once they are restored. **`scripts/` is also on that branch only**
> — it holds `gate0-a-masschart-stability.R` and `gate0-b-leaf-earlyexit.R`, the harnesses for §20b's
> Q25 and Q55:
>
> ```bash
> git checkout claude/odelia-ad-tape-reverse-496fuf -- scripts
> ```
>
> The one exception that survives here: `plant/tests/testthat/gate0_b_leaf_earlyexit_driver.cpp`, so
> Q25 can be driven without recovering anything.

**PROVENANCE RULE.** A line earns a place in §2–§19 only if its evidence is one of:
**(a)** a currently-passing test, **(b)** a probe in `docs/reference/` with a re-run command, or
**(c)** a code location read directly. **A claim whose only evidence is another document does NOT
qualify** — it goes to §20b (quarantine) until verified. This rule exists because a recorded "FF16 has
an open dropped-derivative bug" survived across four documents after it had been fixed (§22.1), and
because §20b's contents were written 2026-07-16 … 07-22, *before* the a1–a4 severance fixes, the mass
chart, and the leaf-seam deletion landed. Where documents disagreed with the code, the code won; §22
records the corrections.

---

## 1. The goal, unsynthesised

Exact trait/parameter gradients of the SCM's **emergent** outputs — census metrics (LAI, biomass,
basal area) and R0/offspring — for **K93, FF16 and TF24**, at **production lifetime**, with a concept
count a plant developer can hold, verifiable against finite differences, adding **no engine vocabulary
per model**, and without regressing the forward model.

Everything below is a constraint on *how* that can be achieved.

## 1b. The user stories the surface must serve

From `archive/ad-r-interface.md` §6 — the R experience of each persona, and **the recurring point is
what they never touch**. These are the DX specification; "concept count" is measured against them.

| | persona | asks for | status |
|---|---|---|---|
| **6.1** | forest ecologist | trait sensitivity of emergent LAI/biomass, resident with self-shading feedback — `stand_gradient(scm, metrics, traits, feedback="resident")` | **primary workflow.** FF16 census works; TF24 unverified (U1) |
| **6.2** | evolutionary ecologist | selection gradient of a rare mutant against a resident, to locate singular strategies — `offspring_production_gradient(...)` | **primary workflow.** Needs the mutant/frozen-canopy path (deferred) and R0 (U6) |
| **6.3** | modeller calibrating to data | a hot L-BFGS loop: `solver$set_observations(times, obs, obs_idx)` then `value_and_gradient(p)` returning **both from one recording** | **advanced, and "the story that most stresses the invariant". THIS IS `least_squares` — see C14.5b: it reads intermediate history as ACTIVE values, so a plain-valued trajectory breaks it** |
| **6.4** | plant developer | add an emergent metric with one scalar-templated kernel and a registered name; **no tape code, no odelia change** | the concept-count test |
| **6.5** | odelia downstream developer | implement the System contract, get gradients free, doubles only | R5 |
| **6.6** | maintainer | compare AD against a re-run FD in plain R, same shape | why only `double` crosses |
| **6.7** | anyone | forgot `save_RK45_cache` → a clear actionable error, never a crash | fail loud |
| **6.8** | odelia downstream developer | enable AD on a system with adaptive numerics | the L2 question, now vacuous |

**Two of these bind on open items and neither is a corner case: 6.3 is exactly the `least_squares`
incompatibility, and 6.1/6.2 are exactly what per-species η blocks** (§6 below).

---

## 2. The AD substrate (XAD)

| | constraint | evidence |
|---|---|---|
| **C2.1** | tape bytes are exactly `12·ops + 8·statements + 8·slots` | reproduces 12 764 B to the byte — `crown-preaccum-probe` |
| **C2.2** | **never give a deduced return type to a function or lambda returning an AD value** | operators return expression templates holding references to operands; a deduced return type hands back references to temporaries, records reused stack bytes as a tape slot, and the reverse sweep segfaults arbitrarily far from the cause. **valgrind cannot see it** — the storage is stack. Two live instances found historically (`ff16_strategy.h:823` was the second) |
| **C2.3** | rewinding a tape (`resetTo`) keeps the gradient exact but **does not release memory** | peak 48 kB → 742 kB over 60 → 960 units; time advantage reverses 1.48× → 8.42× |
| **C2.4** | a solve placed **on** the tape costs ~26× a solve taken off-tape, and returns a **wrong zero** gradient | `weibull_leaf_tape_profile` |
| **C2.5** | only `double` may cross the R boundary | project invariant |
| **C2.6** | a tape's memory is not freed by deactivation | `PLANT_TAPE_STATS` reads it after the sweep, by design |

## 3. The ODE solver, and the schedule (L0/L1)

| | constraint | evidence |
|---|---|---|
| **C3.1** | the correct frozen replay is the **resolved** schedule — L0 `node_schedule_times` **and** L1 `ode_times` | pinning L1 onto an unrefined L0 is value-correct but **derivative-wrong**; this cost a session |
| **C3.2** | `recorded_steps()` is the single source of the replay grid | `AUTODIFF.md`; plant broke this once by introducing a second source via `NodeSchedule.use_ode_times` |
| **C3.3** | **every introduction time lies on the ODE grid** — so a segment boundary is always a step boundary | 141/141, 233/233, 161/161, and TF24 141/141 |
| **C3.4** | steps per introduction segment: **K93 1.23, FF16 1.87, TF24 18.43** | the measurement that killed the segment as a universal unit |
| **C3.5** | `set_state_from_system` already refreshes `dydt_in` from the system | `ode_solver_internal.hpp:160-166` — why a "stale first stage" fix was inert |
| **C3.6** | on a frozen resolved schedule, frozen FD **==** adaptive FD (no schedule sensitivity) | verified in double at R level |

## 4. Patch state and the restore surface

| | constraint | evidence |
|---|---|---|
| **C4.1** | `Patch::r_set_state(time, state, counts, light)` restores state, per-species counts, and the light spline — **and nothing else** | `patch.h:832-847` |
| **C4.2** | `set_ode_state(it, time)` re-establishes the whole invariant itself — states, environment, time, finiteness check, `compute_environment(true)`, `compute_rates()` | `patch.h:360-380` |
| **C4.3** | `set_ode_state` is **iterator-templated**, so structure can be restored from plain values and the values then overwritten at the active scalar | `patch.h:132` — used by the chained-adjoint probe |
| **C4.4** | `compute_environment` runs **before** `compute_rates` inside `set_ode_state`, and the competition source weight is read from an aux slot `compute_rates` writes — **so the environment is not a pure function of `y`** | `patch.h:884-889` |
| **C4.5** | **settle exactly ONCE.** Refreshing aux makes the match *worse*, because the forward pass genuinely uses the lagged value | FF16 1.50e-36 → 1.61e-15 at segment 10; 1.65e-15 → 1.91e-05 at 90 |
| **C4.6** | restoring from plain values is **not bit-exact**: ~**2e-5 relative on live state** (TF24, worst live cohort) | the alarming 5.47 absolute is a cohort at `log_density` = −328, density 1e-143 |
| **C4.7** | restoring from a **whole `Patch` copy** *is* bit-exact for K93/FF16 (`0.00e+00` every segment) but not TF24 | the two columns are different storage models |
| **C4.8** | `Patch::at_species()` is **const-only** and `species` is private — **no public route to per-node birth state** | `patch.h:101,224`; probes must `const_cast` |
| **C4.9** | `Patch::r_at` **does not compile** (calls a nonexistent `at`) | `patch.h:179` — latent until instantiated |

## 5. Node introductions and birth bookkeeping

| | constraint | evidence |
|---|---|---|
| **C5.1** | `pr_patch_survival_at_birth` is **not** in `ode_state` and **divides the fecundity rate** | `node.h:74` says so, `node.h:217` does it |
| **C5.2** | omitting it puts the error **exclusively** in `offspring_produced_survival_weighted` — never height, mortality, fecundity, heartwood or log-density | measured every segment, both models; confirmed by discriminating prediction |
| **C5.3** | restoring all three stamps cuts relative drift **~10× (FF16)**, **~17× (TF24)** | `restore-stamp-probe` |
| **C5.4** | `patch_density_at_birth` and `node_introduction_time` feed **only** `weighted_fecundity` — **census gradients do not need them** | `node.h:87`; only readers `species.h:422,587` |
| **C5.5** | all three stamps are **deterministic doubles** recoverable from the schedule and disturbance regime — no derivative is needed | `survival_weighting->pr_survival(t_birth)` |
| **C5.6** | **a newborn's initial condition IS stand-dependent** — `log_density` moves **1.105** across entering-state perturbations, while height/mortality/fecundity/offspring do not move at all | `chained-adjoint-probe` → `newborn_state_sensitivity` |
| **C5.7** | `Species::set_birth_state(times, density, pr_survival)` exists but **no test calls it** | `species.h:132`; `patch.h:386-400` |

## 5b. Strategy preparation, and what a reset rebuilds  (read directly this session)

| | constraint | evidence |
|---|---|---|
| **C5b.1** | **`Patch::reset()` calls `prepare_strategy()` on every species** — deliberately, so a seeded parameter's derivative reaches the precomputed birth size / canopy shape / `eta_c` | `patch.h:318-329` |
| **C5b.2** | **TF24's `prepare_strategy()` CONSTRUCTS A FRESH `Leaf`** — `leaf = Leaf(to_passive(pars.vcmax_25), …)` | `tf24_strategy.cpp:1112` |
| **C5b.3** | the `Leaf` constructor runs `setup_transpiration(100)`, `setup_root_vulnerability(100)` and `setup_clean_leaf()`, which sets `ci_`, `stom_cond_CO2_` … to `NA_REAL` | `src/leaf_model.cpp:33-35`, `:65-75` |
| **C5b.4** | **`r_set_state` calls `reset()`** as its first act | `patch.h:838` |
| **C5b.5** | so the leaf's four interpolators are **constructor-built on a fixed 100-knot grid**, not per-solve state; they are rebuilt whenever `prepare_strategy` runs | `leaf_model.h:127-135`; `vulnerability_curve_ncontrol = 100` |
| **C5b.6** | the genuinely per-solve leaf state is `ci_`, `stom_cond_CO2_`, `opt_psi_stem_`, `opt_ci_`, `profit_`, `psi_soil_`, `psi_soil_inverted_`, and `root_vuln_integral_soil_` — the last documented as "Rebuilt in `find_root_collar_psi`" | `leaf_model.h:185-200` |
| **C5b.7** | **the `Leaf` is never templated on `S`** — it is always `double`, and `prepare_strategy` passes `to_passive(...)` parameters into it | `tf24_strategy.h:427-430`; `tf24_strategy.cpp:1112`. The S-path science lives in `assemble_leaf_from` instead, so this is a deliberate boundary rather than a severance — **but it means no derivative flows through the `leaf` object itself** |

## 6. The light field — separability and its preconditions

| | constraint | evidence |
|---|---|---|
| **C6.1** | all three strategies shade with **one** rank-3 kernel: `{1, −2z^η, z^2η} · {amp, amp·H^−η, amp·H^−2η}` | algebra, checked against `canopy_shape.h:196-211` |
| **C6.2** | the factorisation is exact **only when the same η appears in query and source factors** | `(1−(z/H)^η)²` expands that way and no other |
| **C6.3** | **the field is assembled with ONE canopy, taken from `species[0]`** | `patch.h:757-759`, commented "any cohort's canopy (shared shape)" — an assumption, not a fact |
| **C6.4** | **the current assembly is DEFECTIVE for species of differing η — this is a bug to fix, NOT a constraint to design around.** With one query-factor set the field computes **7.98e+14** where the exact kernel gives 0.118 (η 12 vs 4), and 742 at η 12 vs 10. Since η is read from `species[0]` only, **the forward value is wrong too**, latently — not just the gradient | `two-species-probe`; `patch.h:757-759` |
| **C6.4a** | **η is a declared differentiation target in ALL THREE models** — `X(eta)` appears in `FF16_AD_FIELDS`, `K93_AD_FIELDS` and `TF24_AD_FIELDS`. plant already says η is a trait to differentiate, and community assembly and selection gradients (stories 6.1/6.2) vary traits **across** species by definition | `ff16_strategy.h:113`, `k93_strategy.h:49`, `tf24_strategy.h:98` |
| **C6.4b** | **separability SURVIVES per-species η; the field is rank 3·n_η, not rank 3.** Group sources by η: `A(z) = Σ_η Σ_p a_p^η(z) · [Σ_{j: η_j = η} ampM_j · b_p^η(H_j)]`. Each group keeps its own descending-height cumulative sum, and a query sums 3·n_η terms. It **degenerates to today's rank 3 when all species share η**, and in the worst case (every species distinct) it costs the same as one field per species | algebra over `canopy_shape.h:198-211`; the requirement this imposes is in U15 |
| **C6.5** | there are **SIX** `ShadingModel` modes, and only **two** change the competition kernel: `FlatTopBox` → `Box` and `FlatTopSoftBox` → `SoftBox`. `DeepCrown`, `MeanLight`, `CrownCentre` **and `PPA`** all map to `Deep`, which is the separable one | `canopy_shape.h:50-52` (enum), `:129-131` (the mapping — `default: Deep`) |
| **C6.5a** | **TF24's default is `MeanLight`, NOT `DeepCrown`** (FF16's default is `DeepCrown`). The mode changes how *assimilation* integrates light over crown depth; it changes the *competition* contribution only for the two Box modes | `tf24_strategy.h:399`; `ff16_strategy.h:786`. **This corrects a claim that said "defaults are DeepCrown → separable"** — the conclusion survives, the reason was wrong, and it was wrong about TF24 |
| **C6.5b** | so the two modes with no correct tangent route are `FlatTopBox` (a hard step) and `FlatTopSoftBox` (a smoothstep) — and `PPA` is separable on the competition side whatever its assimilation kink | as above |
| **C6.6** | sources are merged in descending height with ties broken on the **flat concatenated index**, so the cumulative sum adds the same terms in the same order on every rebuild | `patch.h:741-748` |
| **C6.7** | that tie-break is **stable across a rebuild** with two species | `copy_abs` exactly 0 at every segment — but **equal widths only** (§20) |
| **C6.8** | **an empty `species[0]` is undefined behaviour** — the per-species loop skips empty species, the function early-returns only on zero *total* sources, so `patch.h:758` dereferences `node_begin()` on an empty vector | measured reachability **0** on an ordinary two-species run; undefended in general |
| **C6.9** | the field read is **66%** of the FF16 crown tape | `crown-preaccum-probe` |
| **C6.10** | FF16's crown reads the field with an **active** query height (not the frozen-query path) | `ff16_environment.h` |
| **C6.11** | on the rate path K93 and FF16 read the **exact field**, not the spline | why a spline-path-dependence hypothesis was refuted |

## 7. The interpolator / spline

| | constraint | evidence |
|---|---|---|
| **C7.1** | **a spline cannot carry `d(light)/dz`** — mean relative error **950%** fitted to light, **227%** fitted to optical depth, at plant's production tolerance 1e-4 | `spline-tangent-probe` |
| **C7.2** | fitting to optical depth is consistently **2–4×** better and still not enough; mean under 1% needs **311–511 nodes** and max error is still 42% | same |
| **C7.3** | spline **values** are fine — error tracks the fitting tolerance | same |
| **C7.4** | value and slope must not come from different constructs | that is the detached-derivative pattern already deleted once |
| **C7.5** | refining through a plain-valued predictor is **5.89× leaner**, bit-identical, same nodes — and moved TF24's total by **0.018%** | the leanness ceiling in one line |
| **C7.6** | `basic_interpolator`/`Interpolator` are **two names for one type** | kept only so plant compiles unchanged |

## 8. Adaptive structure

| | constraint | evidence |
|---|---|---|
| **C8.1** | an adaptive node set is **bit-identical** built plain or active, with **nothing recorded** | 149 nodes, 149 matched, `max_abs_diff` exactly 0 |
| **C8.2** | node positions are `double` **by type**, and the refiner decides on `to_passive` values | so "record the structure" answers a question nobody has |
| **C8.3** | **structure must remain a deterministic function of plain values** | true today; a new environment sorting on an *active* key would break it, and **nothing structural prevents that** |
| **C8.4** | `quadrature::QK` nodes are a **fixed** rule affinely mapped — no adaptive structure in the crown integral | `qk.h:81-84` |

## 9. K93

| | constraint | evidence |
|---|---|---|
| **C9.1** | replays bit-exactly from a whole-patch copy; no leaf, no soil | so it isolates the adjoint from every other hazard |
| **C9.2** | 1.23 steps/segment — the event segment suffices, **no `run_next_impl` surgery** | C3.4 |
| **C9.3** | `k_I` had a growth-channel **severance**, since lifted | task a4 |
| **C9.4** | its AD fields are `height_0, b_0, b_1, b_2, c_0, c_1, d_0, d_1, S_D, eta, k_I` | `k93_strategy.h:47-49` |

## 10. FF16

| | constraint | evidence |
|---|---|---|
| **C10.1** | the coupled self-shading gradient is **exact to the FD's noise floor**: lma **2.64e-06**, a_l1 **6.06e-06**, k_l **1.31e-08** | measured today; **this supersedes a recorded 38% gap** — see §22.1 |
| **C10.2** | it required three severance fixes: templated `CanopyShape` (η), `smooth_positive` on the growth/fecundity clamp (a_l1/a_l2), and an IFT-lifted birth size (ω, height_0) | tasks a1–a3 |
| **C10.3** | the geometric **mass chart** made the pure-loss channel exact; the compression term cancels identically | `lambda = log density + log spacing` |
| **C10.4** | the reconstructed density `exp(λ)/dx` **overflows** at tiny-but-nonzero spacing — the source weight must be formed as `(M/dx)·exp(λ)·φ₀` | `patch.h:686-724`, odelia#46 |
| **C10.5** | a coincident cohort (`dx == 0`) must give **zero** source, by the −inf convention — not `gap/0` | same |
| **C10.6** | 1.87 steps/segment; whole-run tape ≈ **12 GB** at production | C3.4; `v3-control-flow.md` |
| **C10.7** | reverse AD fits only to about **life 40**; life 50 OOMs | `build-plan.md` |
| **C10.8** | its gradient test gates lma/a_l1 at **1e-2** while the truth is ~1e-6 — a **100× regression would pass green** | §22.1 |

## 11. TF24 — the leaf, and the implicit-function boundary

| | constraint | evidence |
|---|---|---|
| **C11.1** | `implicit_value` is the single IFT primitive; `register_implicit` was deleted (zero production callers) | its `sign(∂F/∂y)` guard survives as `denom_sign` |
| **C11.2** | a solve taken **off** tape costs ~**1.6k ops per solve, exactly independent of solver iterations** | `weibull_leaf_tape_profile` — this is the OOM proof |
| **C11.3** | the node sits **inside `ode_rates`**, so it is instantiated `cohorts × stages × nodes` times per step. **No improvement to the inversion touches that** | only bounding the run does |
| **C11.4** | the full 3-deep nest `p → ψ_stem → ci` differentiates correctly, including the bound/fold regime where branch death makes `dW/dp ≠ 0` | `weibull_leaf`, 39 assertions |
| **C11.5** | a field assembled **over** IFT source weights is exact — 5/5 channels FD-exact 6.9e-11…3.3e-9, assembly pinned to an analytic identity at **2.2e-16**, holding 2→40 sources and θ 0.5→0.05 | `test-ad-field-over-implicit.R`, 52 assertions |
| **C11.6** | severing the solve collapses **exactly** the coupled channels and leaves the others bit-identical — so C11.5 is not vacuous | same |
| **C11.7** | **the `Leaf` is shared through a Strategy pointer**, so a `Patch` copy shares one `Leaf` carrying per-solve state (`opt_psi_stem_`, `opt_ci_`, `profit_`, soil caches, four splines) | `individual.h:23` |
| **C11.8** | consequence: a **deferred** replay drifts **1.84e-13 / 4.99e-11 / 1.30e-08** where an **inline** replay is **exactly 0**; FF16/K93 zero both ways | `leaf-staleness-probe` — cause confirmed |
| **C11.9** | correctness needs the leaf **consistent with** the unit, not **owned by** it | which is why this is a design choice, not a foregone copy |
| **C11.10** | **`Leaf` has no structural boundary between parameters and per-solve scratch** — ~30 loose doubles, 5 vectors, 4 interpolators, interleaved, nothing marking which are transient | `leaf_model.h:139-200` — why "audit every cache" decays |
| **C11.11** | the TF24 leaf `p*` FD is a **δ/τ-indexed family, not one number**; the anchor is tight inner tolerance, δ in the window | `oracle/oracle-response-inner-argmax-adjoint.md` |
| **C11.12** | a TF24f tracked-collar residual of **2.9e-4** remains, δ-independent, therefore real | backlog #32 |

## 12. TF24 — soil

| | constraint | evidence |
|---|---|---|
| **C12.1** | soil water is **ODE state** (`ode_size() > 0`, 9 entries), so `d/dθ` is carried with no recording and no freezing decision | treating it as a background would drop the depletion feedback |
| **C12.2** | four non-smooth constructs: runoff floor (`:303`), conductivity floor (`:354`), retention floor (`:365`) are **kinks**; the **drying guard** (`:335`) is a **SEVERANCE** | it zeroes `d(rate)/d(θ)` *and* `d(rate)/d(depletion)` on a positive-measure set |
| **C12.3** | **the severance is structurally unreachable**: both water sinks shut off at **12.5× θ_r** (roots at `root_psi_crit` 5.87 MPa; drainage `K ∝ θ^16.14`, down 9 orders) | min θ measured 18.0/13.1/12.8/13.0/13.1× over a 20× rainfall sweep |
| **C12.4** | **do not smooth them** | smoothing was the wrong frame; a zero derivative is what the model means at a kink |
| **C12.5** | `rainfall = 0` throws plant's own non-finite-density guard — **the plants fail before the soil does** | soil-clamp-probe |
| **C12.6** | the soil sub-cycle adjoint, a node inside `ode_rates`, and the resize path are correct **together** | `soil_leaf`, 9 assertions, FD < 1e-9 |
| **C12.7** | `smooth_positive` is used 3× in `ff16_strategy.h` and **0×** in `tf24_environment.h` | the asymmetry is deliberate, per C12.4 |

## 13. Density transport

| | constraint | evidence |
|---|---|---|
| **C13.1** | plant transports **log-mass λ**, not log-density ℓ; density is a **spacing view** | task #8/#2 |
| **C13.2** | the SCM has its own **non-finite-density guard** and it fires on plausible configurations — two-species FF16 at `birth_rate` 20 over life 20, and η = 2 or 4 | `two-species-probe`; the message names `max_patch_lifetime` and extreme drivers |
| **C13.3** | a numerically extinct cohort reaches `log_density ≈ −328` (density 1e-143) and **absolute** errors there are meaningless | why an error metric without its reference magnitude is not evidence |

## 14. Census metrics and functionals

| | constraint | evidence |
|---|---|---|
| **C14.1** | census is a **mass-consuming reduction**, `Species::census<Ψ>`, S-templated | stages 1–2 |
| **C14.2** | three census Ψ exist: LAI, biomass, basal area, as a **codomain-3** functional | stage 3, FD-verified |
| **C14.3** | **several Jacobian rows come off one recording** — a census 3-vector costs a scalar's tape | toy; whole-run plant; and now **+0.38%** through the per-unit path |
| **C14.4** | a functional must be a **pure reduction** — it reads state and returns scalars | the `Functional` contract |
| **C14.5b** | **the `Functional` contract currently permits reading INTERMEDIATE history states as ACTIVE values, and `least_squares` does exactly that** — `solver.get_history_step(idx)` then `sys.ode_state(...)` into `value_type` | `odelia/inst/include/odelia/gradient.hpp:226-245`, verified live. **Any design that stores the trajectory as plain `double` breaks it silently — the value stays right and the derivative through the observations is lost.** The fix is a contract change ("declare the steps you read and contribute a per-step adjoint seed"), i.e. **a new concept**; and calibration is one of `AUTODIFF.md`'s three axes, so it is not a corner case. **Final-state functionals (census, R0) are unaffected** |
| **C14.5** | R0/offspring is an **ODE state** (`offspring_produced_survival_weighted`), so it is still a final-state functional, not a cross-unit accumulator | `node.h` |

### 14b. Further verified surface facts (read this session)

| | constraint | evidence |
|---|---|---|
| **C14b.1** | `Internals::auxs` **is** `std::vector<S>` — the templating requirement (`height → area_leaf → rate` flows through an aux slot) **is met**, so there is no severance there | `internals.h:41,46,51` |
| **C14b.2** | the exact-`double`-keyed soil cache hazard **is already closed structurally**: `if constexpr (!std::is_same_v<S, double>) cache_stale = true;` — on the active path the cache is never served, with the reason in a comment ("a value-only exact compare cannot see a changed derivative") | `tf24_environment.h:394-400`. **This resolves what two independent documents flagged (Oracle Q23, catalog Q37)** |
| **C14b.3** | the genuine iterative inner solves in the whole family are **N1** (`ci` root), **N3** (collar optimum `q*`), **birth height** (one Newton step at an existing root), and — outside plant — regnans' BVP collocation and demographic-equilibrium fixed point. **Everything else is closed-form / Leibniz / reduction and carries no hand adjoint** | `design.md` §7, cross-checked against the deepening inventories |
| **C14b.4** | `⟨Jv,u⟩ = ⟨v,Jᵀu⟩` is **self-consistency, not correctness** — forward and reverse can traverse the same lossy representation and agree while both wrong | stated independently in `v3-north-star.md` §8, the Oracle's transport response, and the catalog. **Three sources; treat as a rule** |
| **C14b.5** | `height_max = max` over cohorts sets the **light-spline domain** — a replayed argmax over values | `v3-l2-audit.md`; the guard survey classes it Kind A |
| **C14b.6** | the two `freeze_*` statics are **live diagnostics but mutable globals on a production class** — correctness rests on every entry point setting them | `v3-l2-audit.md`, "Also settled while reading the code" |
| **C14b.7** | the R boundary is **one** exported entry point reading **by native pointer into the live Patch**; an `Rcpp::as<Environment>` round-trip is **lossy for crown-sampled light and O(stand) slow** | `design.md` §8 |
| **C14b.8** | Box/SoftBox shading is the **kill condition for deleting L2**: if anyone needs a gradient through such a stand, the deferred positions path is required again | `v3-l2-audit.md` "What this makes hard" |

## 15. Multi-species

| | constraint | evidence |
|---|---|---|
| **C15.1** | sources are built **per species** (each species' own canopy, own trapezium measure) and then merged | `patch.h:676-760` |
| **C15.2** | the merge imposes C6.4 (shared η) and C6.8 (empty species 0) |  |
| **C15.3** | `introduce_new_nodes` takes a **vector of species indices**; a unit may open with several | `patch.h` |
| **C15.4** | per-species counts are needed to reconstruct width **and** the tie-break index | C6.6 |

## 16. Disturbance and patch survival

| | constraint | evidence |
|---|---|---|
| **C16.1** | patch survival is **deterministic** and disturbance gradients are **out of scope** | owner's steer |
| **C16.2** | `pr_survival(t)` is a function of time available from `survival_weighting` | so C5.5 holds |
| **C16.3** | production lifetime is **`life = 105.32`**; TF24 there is **987 node states + 9 soil over 2 598 ODE steps**, FF16 **987 over 264** | forward run, no AD |

## 17. Strategy ownership and AD seeding

| | constraint | evidence |
|---|---|---|
| **C17.1** | `Strategy::ptr` is a **`std::shared_ptr`**; `SpeciesBase` holds one and **every Node holds a copy** | `k93_strategy.h:68`; `species.h:31,158`; `strategy.h:20` |
| **C17.2** | `Species::ad_parameters()` returns `strategy->field_ptrs()` — **pointers INTO the Strategy's `pars`** | `species.h:141-142` |
| **C17.3** | therefore a `Patch` **copy shares** the seeded AD input; a Patch built fresh from `Parameters` does **not** | measured by pointer identity |
| **C17.4** | with a shared Strategy, trait adjoints **accumulate automatically**; with per-unit Strategies each unit is a **distinct input** and one read gives **41–51%** of the answer — right sign, nothing thrown | `unit-adjoint-probe` |
| **C17.5** | re-seating a per-unit Strategy copy must reach the Species **and every Node**, and `Individual`'s only entry point is its **constructor** — a half-re-seated patch is **silently mixed state** | `species.h:31,158` |
| **C17.6** | `field_ptrs()` and `field_names()` are generated from one macro list, so they cannot disagree in membership or order | `k93_strategy.h:296-306` |
| **C17.7** | `Patch::reset` **re-prepares the strategy from the seeded parameters**, which is what makes the lifted birth size flow | why a3 works |

## 18. Verification

| | constraint | evidence |
|---|---|---|
| **C18.1** | **verify the FD reference before trusting any ratio** | a TF24 FD is a δ/τ family; too small → staircase noise (a retracted "12×"), too large → non-finite (#550) |
| **C18.2** | the anchor is AD vs FD on the **identical resolved schedule** at tight inner tolerance, δ in the window | Oracle Decisive Experiment 2 — **not** a loose-τ swept plateau |
| **C18.3** | AD == FD failure on an identical schedule is a **real derivative bug**, not a replay artefact — forward AD == reverse AD yet both ≠ a δ-independent FD means the code computes a wrong analytic derivative | how the a1–a4 severances were found |
| **C18.4** | for a **unit** the FD is **roundoff-dominated**: it improves as δ *grows* — 3.4e-09 at `d_rel` 1e-3 degrading to 2.6e-04 at 1e-8 | `unit-adjoint-probe` |
| **C18.5** | a **trivial adjoint is a vacuous test.** A summed-height functional gives λ ≡ 1 on heights and ~1e-12 elsewhere; a density-weighted one moves λ's scale to **592** and produces cancelling per-unit terms | `chained-adjoint-probe`; the same vacuity hid the 19% newborn error from a constant-IC toy |
| **C18.6** | **check a gradient test did not skip** — `skip_if_not(built, …)` turns a build failure into a skip, which silently disabled 11 FD assertions once |  |
| **C18.7** | the correctness reference is the fully-adaptive real-model FD, verified **in double at R level** first |  |

## 19. Build, test and DX mechanics

| | constraint | evidence |
|---|---|---|
| **C19.1** | **the two packages need opposite invocations**: odelia via `library()` from a real install (never `load_all` — it silently skips the AD workflow); plant via `pkgload::load_all` (many tests call internals) | three sessions lost to this |
| **C19.2** | `testthat` caps failures at 10 and **prints the cap as the total** — `set_max_fails(Inf)` before quoting any count |  |
| **C19.3** | plant header changes do **not** recompile via a plain `R CMD INSTALL`; `rm -f plant/src/*.o *.so` first (~3 min) |  |
| **C19.4** | plant compiles against the **installed** odelia headers, not the submodule tree |  |
| **C19.5** | the full plant suite **OOMs the box** — use focused files |  |
| **C19.6** | current surface: plant touches **34** odelia names; odelia is **19** headers; suite **0 fail / 535 pass / 5 skip** |  |
| **C19.7** | a named object that merely relocates complexity makes DX **worse** — 697 lines and 4 primitives were deleted for having no consumer but their own demo | the standing discipline |
| **C19.8** | the forward model must not regress: develop **49.57 s / 2 621 steps** vs branch **50.31 s / 2 599** | `tf24-develop-benchmark.sh` |

---

## 20. UNTESTED, per component

| | component | what is not established | what would settle it |
|---|---|---|---|
| **U1** | TF24 end to end | **TF24 gradients have never been FD-verified.** Its test asserts only `is.finite` and value reproduction; FD verification is explicitly `OPEN — staircase reference needed` (#27) | C18.2's anchor |
| **U2** | TF24 memory | **UNBLOCKED by QC** (no longer waiting on #37). **The ~89 MB per-unit tape is an extrapolation** — marginals stop at width 606, production is 987, and no TF24 *unit* tape has ever been measured. The whole memory case rests on it | TAPE_STATS on one restored TF24 unit; blocked by C11.7 |
| ~~**U3**~~ | TF24 leaf | **CLOSED** — no fix is needed; the restore path already gives a leaf consistent with the unit | done, §20b QC |
| **U4** | multi-species | **no gradient has ever been taken with two species.** Replay is verified in double only, and only with **equal widths** at every segment | two species introduced on different schedules |
| **U15** | the light field | **PER-SPECIES η IS A REQUIREMENT, AND THE FIELD DOES NOT MEET IT.** Not "untested" — a known defect (C6.4) blocking stories 6.1/6.2. The fix is C6.4b's rank-3·n_η grouping; what is untested is its cost at realistic assembly sizes and whether the per-group cumulative sums preserve the tie-break determinism of C6.6/C6.7 | implement the grouping; re-run `two-species-probe` (it must go exact) and the tie-break check with differing η |
| **U14** | functionals | **user story 6.3 (calibration) is incompatible with a plain-valued trajectory** (C14.5b). Whether the contract change is one concept or several, and whether `value_and_gradient` can still return both from one recording, is undecided | design it against story 6.3, not against `least_squares` in isolation |
| **U6** | R0 | `set_birth_state` is called by no test, has **no public API** (C4.8), and the drift lands precisely in the slot R0 reads | #44 + #45 |
| **U7** | FF16 | its gate is **4 orders looser** than the truth (C10.8) | tighten after verifying the δ-sensitive FD |
| **U8** | the step unit | splitting `advance_fixed(e.times)` inside `SCM::run_next_impl` has **never been attempted**; TF24 needs it | #35 |
| **U9** | time | the 4.2× is an odelia toy at ~22 µs/unit; **no end-to-end plant sweep has been timed** | time a K93 sweep against its whole-run gradient |
| **U10** | structure determinism | C8.3 has **no structural defence**, only prose |  |
| **U11** | field | C6.8's empty-species-0 UB is unreachable on **one** schedule; not in general |  |
| **U12** | census | the per-unit path was witnessed with summed height and summed height²; **the real census Ψ (mass-consuming) has not run through it** | run `census_vector` through a unit |
| **U13** | soil | C12.3 holds down to rainfall 0.05; the guard remains a severance if a drier driver is ever used |  |

---

## 20b. QUARANTINE — corpus claims that are not yet evidence

These were recovered by combing `oracle/` and `deepenings/`. **Every one would be a constraint if it
still holds**, and several are the kind that ends a design. **None is usable yet**: their only evidence
is a document, they were written **2026-07-16 … 07-22**, and the a1–a4 severance fixes, the geometric
mass chart, the `leaf_output` absorption and the FD-seam deletion all landed *after*. The FF16 episode
(§22.1) is the precedent — a recorded blocker outlived its fix by four documents.

**Staleness risk** is my read of how likely the claim has been overtaken: **HIGH** = the code it
describes has since been rewritten; **MED** = adjacent code changed; **LOW** = a measurement or a
theorem that later work would not have touched.

### From `oracle-response-inner-argmax-adjoint.md` (2026-07-22) — the `p*` search

| | claim | risk | what would settle it |
|---|---|---|---|
| **Q1** | the `p*` solve is comparison-based (golden section), so `p̂` is a **staircase**: exactly affine inside each comparison cell with a slope carrying **no information about the objective** (γ = 0.6298; within-cell −0.573 vs distributional 0.652) | HIGH — #23 later called the residual "a reference artefact"; the solver may have changed | read the current leaf solve; if still comparison-terminated, Oracle experiment 1 (fix δ, sweep τ) |
| **Q2** | any θ entering through `P` but **not** through the bracket `(A,B)` has literal sensitivity **exactly zero** at sub-cell δ — the comparisons quantise it away | HIGH | the reductio probe: find such a θ, take a sub-cell FD |
| **Q3** | in the **corner/fold** regime the shipped node divides by shelf curvature ≈ 0, so the gradient is **undefined in principle**, not "14% off" | HIGH | corner census: per-call branch flags + \|P_p(p̂)\| histogram |
| **Q4** | the robust selector is **discrete and free** — read the sub-solve's branch indicator at both ends of the final bracket; same branch ⇒ interior IFT, different ⇒ fold IFT `−F_σ/F_p` | MED — prescriptive, may be partly implemented | grep the leaf for a branch-flag read |
| **Q5** | freezing `p*` inside `c` and `g` drops an **O(1)** term **even at a perfect interior optimum** — the envelope theorem zeroes `(∂P/∂p)p*′` and says nothing about `(∂c/∂p)p*′` | LOW — a theorem | confirm no code freezes `p*` in a consumer |
| **Q6** | taping **through** the search reproduces the surrogate slope and is uniquely meaningless — forbidden | LOW | grep that no path tapes the search |
| **Q7** | the FD family obeys `\|AD − FD_δ\| ≤ C(δ² + τ/δ)`, floor **O(τ^{2/3})** at `δ* ~ τ^{1/3}` | LOW | it is the basis of the δ-window rule already in C18.2 |
| **Q8** | a **clean sub-cell plateau that is τ-invariant while the envelope moves** is the signature of an inner-solve artefact, not of the gradient | LOW | already partly encoded in C18.1 |
| **Q9** | **transition continuity is unknown**: if `p*` slides into the wall it is a kink and piecewise-IFT selection suffices; if the global argmax **swaps at a value tie** it jumps and needs switching-time sensitivity with an **adjoint jump term** | MED | instrument `p̂` across regime flips: O(τ) vs O(1) |
| **Q10** | the resolvent `‖(I−T′)⁻¹‖ ≈ 5–22`, so a per-unit error propagates **~10×** and stops | MED | re-measure if the fixed-point layer is built |
| **Q11** | after any polish the **next** binding accuracy limit is that the unit schedule resolves `x(t)`, **not** the quadrature `∫c·ρ` — a **~23% inter-scheme spread** | MED — bears directly on census accuracy | compare census under two quadrature schemes on one trajectory |
| **Q12** | value ties are a **forward-noise hotspot** — comparisons decide by O(τ²) objective differences, so the search dithers | MED | tie census |

### From `oracle-response-transport-compression.md` (2026-07-19) — transport, and four general theorems

| | claim | risk | what would settle it |
|---|---|---|---|
| **Q13** | **engine rule: a rate defined as a numerical derivative must be computed from ACTIVE quantities. Any private numeric probe of an active field severs the tape** | LOW — general, and the diagnosis was confirmed | grep the model surface for `±eps` probes and central differences of active fields |
| **Q14** | **JVP == VJP proves nothing** — both read the same recorded graph | LOW | it invalidates a check we currently make; see C18 |
| **Q15** | **closeness of values does not imply closeness of gradients**: a **0.2%** value gap gave a **sign-flipped** gradient (−451.9 vs +139.9) in a nonlinearly self-coupled system | LOW | **this weakens `scm_jacobian`'s R5 value-reproduction check as evidence of gradient correctness** |
| **Q16** | the hybrid is a **theorem**: `value(A) + [B − passive(B)]` is the derivative of trajectory B on the value of trajectory A — correct **iff** A ≡ B | LOW | the general prohibition on detached derivatives |
| **Q17** | log-mass is **monotone nonincreasing pointwise and unconditionally**: `dλ/dt = −r ≤ 0`, so the value can never overflow | MED — the chart landed, so this should now be checkable | λ-monotonicity audit: log `ℓ + log Δx` per point per step |
| **Q18** | **insertion re-indexing can cause a silent mass jump** (a new point changes neighbours' `Δx` with no compensating `ℓ` change); one-sided end formulas are the other suspect | MED | the same audit, keyed to step + index |
| **Q19** | a newborn needs a **mass** `m₀ = influx density × initial cell width` — "the only genuinely new modelling content" | MED — the chart landed | read the current birth IC |
| **Q20** | a reduction weighted by `exp(ℓ)` **alone** (no `Δx`) is pointwise-density-weighted; **if the continuum object is `∫(…)·n dx`, a `Δx` was dropped** | MED — bears on every census metric | audit the census reductions' weights |
| **Q21** | the kernel is low-rank separable with **`κ(z,z) = 0`**, so the diagonal boundary term vanishes by the double zero and `S′` is closed form | LOW | algebra; consistent with C6.1 |
| **Q22** | `∂C/∂θ` is genuine **everywhere**, including the query-motion and coupling components — there is no legitimate "don't differentiate it" | LOW | — |
| **Q23** | **value-keyed caches on field reads** are a suspected second severance class ("replayed-not-recomputed knot values") | MED | grep for caches keyed on values |
| **Q24** | the **frozen-schedule** approximation band is **0.5–1%**, distinct from the kink | MED — and it appears to sit **in tension with C3.6** (frozen-resolved FD == adaptive FD) | reconcile: C3.6 is the *resolved* schedule, Q24 may describe a merely-frozen one |

### From `deepenings/` (2026-07-16 … 07-19) — the leaf, the soil, the transported state

| | claim | risk | what would settle it |
|---|---|---|---|
| **Q25** | **the leaf shut-down boundary is a TRUE DISCONTINUITY, not a kink** — profit jumps **≈1.46** and does not shrink as the θ step refines to 1e-7. So **no Leibniz/breakpoint term applies and the derivative is undefined at the boundary**; treating it as a continuous breakpoint would be a silent gradient bug *in the opposite direction from the one first feared*. Four early-exits select it; **which one produces the cliff was never isolated** (`E_column < 0` the prime suspect) | MED — **its harness exists and is re-runnable, but not on this branch**: `scripts/gate0-b-leaf-earlyexit.R`, driver at `scripts/gate0_b_leaf_earlyexit_driver.cpp` **and** at `plant/tests/testthat/gate0_b_leaf_earlyexit_driver.cpp` (that copy is still here). An earlier claim that the script was gone checked `plant/scripts/` and was wrong | `git checkout claude/odelia-ad-tape-reverse-496fuf -- scripts` then run it; **or** drive the surviving `plant/tests/testthat/` copy. Then isolate which of the four exits produces the cliff (refine θ to 1e-7 across the transition, 5 layers, height 5 m), then isolate which of the four exits produces the cliff |
| **Q26** | N1 (stomatal `ci`) has a **sign-definite** denominator `dg/dci > 0` strictly | LOW | the node's registered assertion |
| **Q27** | N3 (`q*`) has `dG/dq < 0` at the maximiser, and the node **refuses** rather than returning a spurious optimum on a flat/non-concave landscape | LOW | same |
| **Q28** | N2 (`ψ_stem`) is **not** an inner solve, but `E_up′` returns **NaN** at a soil-layer-crossing boundary and the code **falls back to a central difference** | HIGH — the FD seam was deleted in P2c | grep for the fallback |
| **Q29** | base TF24 has **no collar-ψ channel** (envelope, `seam_collar_psi_input() == nullptr`); TF24f **does** — `q` becomes a tracked state, **+1 pinned state and a new eigenvalue** | MED | read `tf24f_strategy` |
| **Q30** | per-layer uptake `E_i` is an **antiderivative difference** of an incomplete gamma, so Leibniz gives both endpoint partials exactly (`dG/d(endpoint) = f_r(endpoint)`); two of its three branches are measure-zero | LOW | consistent with C12.6 |
| **Q31** | **density is the only transported state**; `offspring_produced_survival_weighted` is an output accumulator integrated **along** a characteristic, never redistributed across size; the boundary flux `F = g·n = birth_rate·pr_estab` is **never carried as a state** | MED — the mass chart changed the transported variable | read `node.h` |
| **Q32** | a **general** η routes through `std::pow` while η ∈ {1,2,4,8,10,12} use exact multiply chains — **bit-identity is conditional on both paths agreeing** | MED | compare `a_p`/`a_p′` on a general η |
| **Q33** | `FlatTopSoftBox`'s interpolator fallback must be a **per-`ShadingModel` decision at strategy setup**, not a runtime branch on the hot path | MED | read `canopy_shape.h:190` |
| **Q34** | the birth density IC `log(birth·estab/g)` is a genuine **kink at density → 0** — measure-zero, zero downstream weight, recorded as a `decide()` | LOW | `node.h:227` |

### QC — RESOLVED BY MEASUREMENT: the `Leaf` blocker does not exist on the design's path

**Status: CONFIRMED, and the mechanism I predicted was wrong.** Kept here in full because the reasoning
is the record; the numbers are in `v3-facts.md` §4f and the refutations in `v3-dead-ends.md`.

**Result.** Via `r_set_state`, deferred and inline replays are **identical** (1.11e-13 / 7.64e-12 /
8.69e-11 at segments 20/40/60) while the copy path still splits — positive control intact, nothing to
detect. **But `reset()` does not wipe the leaf to `NA`**: measured, `ci_` goes 26.479476 →
**27.27942 / 27.19419 / 27.11116**, i.e. *segment-specific*. The leaf is reconstructed **and re-solved
against the restored state**, making it a function of the unit rather than of history. Cost: `prepare_strategy`
is **260.9 µs = 8.6%** of TF24's restore (K93 0.5 µs, FF16 2.0 µs), so ~1.25% of a unit.
**Consequences: C17.4's accumulation hazard and C17.5's re-seating hazard are moot, U2/U3 unblock, and
"skip `prepare_strategy` to speed the restore" is now a known foot-gun.**

The original deduction follows, unedited.

Four facts, each read directly this session and recorded as C5b.1–C5b.4:

1. `r_set_state` calls `reset()` (`patch.h:838`)
2. `reset()` calls `prepare_strategy()` on **every** species (`patch.h:325`)
3. TF24's `prepare_strategy()` does `leaf = Leaf(...)` — a **fresh** Leaf (`tf24_strategy.cpp:1112`)
4. the `Leaf` constructor runs `setup_clean_leaf()`, setting the per-solve fields to `NA_REAL`
   (`src/leaf_model.cpp:35`)

**Therefore a unit restored through `r_set_state` appears to get a leaf with no history at all** — and
the whole blocker (#37) was measured on the **copy** path. `leaf-staleness-probe` replays via
`replay(copy, …)`, a whole-`Patch` copy with `set_state_from_system()`; it never calls `r_set_state`, so
the shared Strategy's leaf keeps its end-of-run state. That is exactly the arrangement the design does
**not** use.

**Why this is not yet a conclusion.** `segment-rerecord-probe`'s `rebuilt` column *does* use
`r_set_state` and TF24 still drifts there (4.35e-13 … 5.47). §4b attributes that to the dropped birth
stamps plus dead cohorts, with a live-state worst of ~2e-5 — but nobody has separated "no leaf
staleness" from "stamp drift" on that path. The project's own rule applies: **diff the objects, do not
propose mechanisms.**

**The discriminating experiment, and it is cheap.** `leaf-staleness-probe` already runs both orderings.
Add a *rebuilt* variant: replay each segment via `r_set_state` instead of from a copy, deferred **and**
inline. Prediction if this deduction holds: on the rebuilt path deferred and inline are **identical**
(no staleness signal at all), while the copy path keeps its 1.84e-13 / 4.99e-11 / 1.30e-08 split.

**What it would change.** If confirmed, #37 largely dissolves: no per-unit Strategy copy, so C17.4's
accumulation hazard never arises, C17.5's re-seating problem never arises, and U2/U3 unblock. If
refuted, we learn which leaf field survives a `reset()`, which is just as valuable. Either way the
recorded cost of Leaf-fix candidate 1 — "pays 4 spline rebuilds × 2 598 units" — needs restating:
`prepare_strategy` **already** rebuilds those interpolators on every restore, so that cost is already
inside the measured 11–15% restore, not an extra charge against one candidate.

### From `v3-step-local-adjoint.md` §4, `phase0-results.md`, the guard survey, and `v3-north-star.md`

| | claim | risk | what would settle it |
|---|---|---|---|
| **Q46** | **a future WARM START in any strategy's inner solver would make a step path-dependent and break re-recording SILENTLY, with every double test still green.** TF24's `find_root_collar_psi` was verified to run a *fresh* `golden_section_max` over bounds derived from current soil state, so re-recording is currently a pure function of (state, traits) | MED — a live foot-gun class, and "it wants a structural guard, not a comment" | re-verify no warm start exists; then decide whether a guard is expressible |
| **Q47** | the stored trajectory must also restore TF24's derived caches `psi_soil_inverted_` / `root_vuln_integral_soil_` | **probably MOOT** — C5b.2/C5b.6 show `prepare_strategy` rebuilds the Leaf and `root_vuln_integral_soil_` is "Rebuilt in `find_root_collar_psi`" | confirm both are re-derived, not inherited |
| **Q48** | **TF24's net-production sign branch `if(net>0){grow}else{zero}` is a HARD un-smoothed gate**, where FF16 uses `smooth_positive` — a genuine kink at the carbon compensation point | MED | read `tf24_strategy`; classify per the manifest |
| **Q49** | K93's `smooth_positive` radii (**1e-4** growth, **1e-5** mortality) are **magic per-strategy constants**, not declared model parameters — the subgradient radius is undeclared | LOW | read `k93_strategy.h:242` |
| **Q50** | two more Kind-A sites need recorded decisions: the **PPA layer index** `floor(τ/…)`, and the **node survival squash** `if(!is_finite(survival)) survival = 0` | MED | the manifest again |
| **Q51** | the guard survey's **Kind A/B/C/D taxonomy** (off-derivative / on-derivative-off-tape / on-tape / *the operation IS a derivative*) with ~11 enumerated sites and a prescribed treatment each. **Kind D — "never differenced" — is the rule that the FD stencil violated** | LOW as a frame; MED per site | walk the 11 sites against current code (this is S4 + S7) |
| **Q52** | the acceptance criterion on record is a **number**: FF16 and TF24 census + R0 at `max_patch_lifetime = 105.32`, **under 2 GB peak**, FD-verified against the tight-τ frozen-schedule reference | LOW | adopt or restate it |
| **Q53** | a step-local sweep may have to **drop `xad::computeJacobian`** (which owns record-once/sweep-m-rows) and hand-roll m sweeps per step, carrying m λ vectors | **partly refuted already** — our codomain-2 probe got both rows off one recording through `computeJacobian` at +0.38% | re-check at m = 3 with λ chaining |
| **Q54** | the soil step-collapse is **multirate + kink-split, NOT a coordinate artifact fixable by one chart** (E2, measured) | LOW | recorded as decided |
| **Q55** | mass-chart forward stability **PASSED** (gate0-a): geometric path bounded, `max|log n|` **21.09** vs the FD stencil's 21.15, still bounded at lifetime 110 (143 cohorts, 29.5), forward shift **0.169%** — so the instability that forced the FD stencil does not recur | MED — **its harness `scripts/gate0-a-masschart-stability.R` exists on `claude/odelia-ad-tape-reverse-496fuf`, not on this branch** (an earlier claim that it was gone checked `plant/scripts/` and was wrong). Unlike gate0-b it has **no driver copy inside plant**, so recovery is the only route | `git checkout claude/odelia-ad-tape-reverse-496fuf -- scripts` then run it; cheapest check on Oracle Q17 (λ-monotonicity) |

### From `archive/ad-touchpoint-catalog.md` (the exhaustive four-part survey)

| | claim | risk | what would settle it |
|---|---|---|---|
| **Q35** | **QAG's adaptive subdivision has `max_iterations = 1` everywhere, so it never fires** — dormant, on no differentiated graph | MED | read `qag.h:85` and the callers |
| **Q36** | the **light spline is the ONLY adaptive field** in any system; ODE steps are L1, the introduction schedule is L0, and the leaf's interpolators, extrinsic drivers, the vulnerability grid and `CanopyShape` are all **fixed-knot** | MED — consistent with our L2 deletion, and C5b.5 confirms the leaf half | the census is a closed enumeration; re-run the greps |
| **Q37 — RESOLVED, VERIFIED CLOSED** (see C14b.2; kept for the trail) | **mutable caches keyed on EXACT `double` comparison** are a distinct AD hazard class: `psi_soil_cache_` invalidated by `psi_soil_cache_state_[i] != vars.state(i)` (`tf24_environment.h:304-329`), the per-time `cached_driver_` (`:295-300`), and the leaf's inverted-soil / operating-point caches. A cache keyed on `value(x)` can go stale **or poison the tape** | **closed** — the active path never serves the cache (`if constexpr`), and `cached_driver_` caches plain `double` drivers only | done: `tf24_environment.h:394-400` |
| **Q38** | **a gradient is only well-defined relative to a fixed `Control`** — `fixed_time_step` switches RKCK↔Euler, `schedule_eps/nsteps` changes cohort structure, `shading_model` changes the mode, `GSS_tol_abs`/`ci_*` change the leaf solve. Several knobs silently move the trajectory and therefore the gradient | LOW — `control.h` is stable | enumerate which Control the design differentiates at, and state it |
| **Q39** | the **FD node-gradient** (`growth_rate_gradient`) and its **`thread_local` scratch** may or may not carry the trait derivative — recorded as *unmeasured either way* | HIGH — this is what AD replaces; it may be gone | grep for it; if live, test whether it carries the derivative |
| **Q40** | **`birth_rate` is an extrinsic driver, not a strategy field**, so how it is seeded as a differentiation target was never settled | MED — and it interacts with C5.6: `is_variable_birth_rate = true` is what makes seed rain stand-dependent | read `extrinsic_drivers.h`; try seeding it |
| **Q41** | the dropped **`d(schedule)/d(trait)`** from freezing the refined schedule was *argued* below tolerance, never measured | MED — C3.6 measured no schedule *sensitivity* on the resolved schedule, which may or may not be the same question | compare an adaptive-FD against a resolved-frozen-FD across traits |
| **Q42** | the SCM is a **growing-dimension** system and "does reverse-mode AD survive `set_state_from_system()` resizing mid-run" was called **the pivotal risk** | LOW — now answered in the affirmative by our own probes (§4d/§4e run introductions on tape) | already largely settled; keep for the record |
| **Q43** | **six competition modes exist and two of them do not run at all** (`FlatTopBox`, PPA-hard) | verified — see C6.5/C6.5a | done |
| **Q44** | the kink manifest — `max(0,spline)`/`cap→1.0` (`resource_spline.h:88`), K93 growth/`mu` clamps, FF16 `step_light`/`smooth_floor`, `CanopyShape` box/softbox steps, TF24 soil positivity resets, leaf `abs(·)<1e-8` special-cases, every `is_finite`/`stop` guard — was to be **classified once** into selector / kink / guard and recorded. **The manifest was specified but there is no sign it was ever produced** | MED | this is S3's enumeration; produce it |
| **Q45** | `IndividualRunner` is "the clean AD target the whole plan skipped" | MED | read it; it may be a cheaper first witness than the SCM |

**Three of these would change a design decision if confirmed**, and they are the reason this section
exists rather than being folded in: **Q15** (a value-reproduction check is not evidence of gradient
correctness — and `scm_jacobian` currently relies on one), **Q25** (a true discontinuity in the fitness
landscape, where no breakpoint term is admissible), and **Q11/Q20** (the census quadrature may be the
next accuracy limit, and a `Δx` may be missing from a reduction). **QC above outranks all three**: it
could remove the project's only remaining blocker, and it costs one probe variant.

## 20c. Strategy for proving §20 and §20b are not missing anything

Extending a list is not the same as bounding it. Four of these five mechanisms are **closed
enumerations** — they can be *completed*, so their output is a table with holes rather than a judgement.

**S1 — Provenance audit of §2–§19 (mechanical, cheap).** Every C-line must cite a passing test, a
`docs/reference/` probe, or a code location. Any line whose evidence is only a document moves to §20b.
This is enforceable by `check-docs.sh` and it bounds *this file's* own reliability, which nothing
currently does. Do this first: it may demote lines I have already written.

**S2 — Differentiation-target × functional coverage matrix (closed).** Enumerate every entry of each
model's `*_AD_FIELDS` macro (K93 declares 11) crossed with every functional (3 census + R0). Mark each
cell FD-verified / value-only / never exercised. **The holes are the answer**, and the enumeration is
complete by construction because the macro list *is* the set of differentiation targets (C17.6
guarantees `field_ptrs` and `field_names` cannot disagree). This is the single strongest check available
and it does not exist today.

**S3 — Branch and boundary census on a production run (closed per-branch).** Instrument one TF24 and
one FF16 production run to count how often each discrete construct is taken: the four leaf early-exits,
the four soil clamps, `E_i`'s three branches, the `dx == 0` coincident-cohort case, the density guard,
the shut-down closed form, `smooth_positive`'s corner radius. **Any branch with nonzero incidence and no
recorded derivative treatment is a missing constraint.** This generalises the Oracle's corner census and
directly tests Q3, Q9, Q12, Q25.

**S4 — Severance-pattern sweep of the model surface (closed per-pattern).** Grep for the known
signatures, each of which has produced a real bug: `to_passive` on a live channel; private numeric
probes (`±eps`, central differences) of an active field (Q13); value-keyed caches (Q23); ternaries and
`std::max/min` on active predicates; NaN fallbacks (Q28); deduced return types on AD-valued functions
(C2.2). Task #11 did this once; the code has moved since, and the pattern list is now longer.

**S5 — Continuous invariant audits (catch classes, not instances).** λ-monotonicity (Q17), mass
conservation across insertions (Q18), active-value == double reproduction, node-set bit-identity
(C8.1), and the field's order-invariance. These run cheaply and fail loudly on whole classes of error
rather than on the instance you thought to test.

**S6 — The adversarial question, per component.** For each of §2–§19: *what does this component do that
no probe has ever caused it to do?* Known answers already: `FlatTopBox`/`FlatTopSoftBox` (C6.5),
`is_variable_birth_rate = true` (which is what makes seed rain stand-dependent and may change C5.6),
two species with different η (C6.4), FF16 beyond life 40 (C10.7), rainfall below 0.05 (U13), a general
non-specialised η (Q32). Each is a configuration nothing has run.

**S7 — Reconcile against the enumerations that already exist. THE SWEEP HAS NOW NAMED THEM**, so this
step is concrete rather than aspirational. Four closed lists exist and each should be walked against
§2–§19:

| enumeration | where | size |
|---|---|---|
| the **AD-guard survey** — every value-touch site → Kind A/B/C/D → prescribed treatment | `archive/odelia-4-value-firewall.md` | ~11 sites |
| the **kink manifest** it specifies (`resource_spline.h:88`, K93 clamps, FF16 `step_light`, Box/SoftBox steps, soil positivity resets, leaf `abs(·)<1e-8`, every `is_finite`/`stop` guard) | `archive/ad-touchpoint-catalog.md` Cluster 7 | **specified, apparently never produced** |
| the **adaptive-component census** — the light spline is the only L2 field | catalog VII.1 | 8 components |
| the **nested-solve inventory** — N1, N3, birth height (+ regnans BVP, equilibrium) | `design.md` §7, deepenings 1/2/3 | 3 in plant |
| the **five silent-wrongness modes** of a step-local sweep | `v3-step-local-adjoint.md` §4 | 5 |

**The kink manifest is the one real hole**: it was specified as the deliverable that stops "a silently
wrong subgradient shipping unnoticed", and nothing suggests it was ever produced. Producing it *is* S3.

**Order.** S1 (bounds this file) → S7 (cheap, uses existing enumerations) → S2 (the strongest new
check) → S4 (cheap, mechanical) → S3 (needs instrumentation) → S5 → S6. S2 and S3 together are what
would let anyone say "§20 is complete" with a straight face.

## 21. The current candidate lives elsewhere — on purpose

The step-local sweep's own properties are **not** in this file. They are requirements-shaped only if you
have already chosen it, and an earlier draft of this document listed ten of them here, which is how
"fresh tape per unit" came to look like a constraint on the problem rather than a property of one answer.

They live in their real homes, all verified present before this section was emptied:

| the candidate's property | where it lives |
|---|---|
| peak = whole ÷ units; peak flat at 6 560 B | `v3-facts.md` §2 |
| a fresh tape per unit, not a rewound one | `v3-facts.md` §2; `v3-control-flow.md` |
| the structural change goes inside the unit (19%) | `v3-facts.md` §2; `v3-engine-design.md` |
| what a stored unit carries | `v3-facts.md` §4b; `v3-engine-design.md` |
| the chained state adjoint in plant | `v3-facts.md` §4e |
| a unit on a frozen trajectory; per-unit tape | `v3-facts.md` §4d |
| a flat 4.2× in time | `v3-facts.md` §2 |
| the restore is 11–15% of a unit | `v3-facts.md` §3c |
| the engine is five concepts | `v3-engine-design.md` |
| component leanness tops out (0.018%) | `v3-facts.md` §1 |

**The design itself is [`v3-engine-design.md`](./v3-engine-design.md) and
[`v3-control-flow.md`](./v3-control-flow.md).** Read this file to judge a design; read those to know
what the current one is.

## 22. Corrections made in compiling this

**22.1 — "FF16 has an open dropped-derivative bug" was STALE, and the truth is the opposite.**
`HANDOFF.md` Part 1 cited *"FF16's current open bug; see PART 2"* at a Part 2 that had been rewritten,
`build-plan.md` records **AD −6299 vs FD −1630**, and the test's own STATUS header described a **38%
`a_l1` gap** as "the remaining work for an exact FF16 gradient". Measured today it is **closed**
(C10.1): lma 2.64e-06, a_l1 6.06e-06, k_l 1.31e-08, value exact, `jvp == dot`, 6/6 passing with no
skips. **A design blocked on it would have been blocked on nothing.** Corrected in Part 1, in the test
header, and here. The loose 1e-2 gate (C10.8) is what let the stale story survive.

**22.2 — the exactness facts and the current path are different columns.** `from_copy_abs` (whole-
`Patch` storage) is exactly 0 for K93/FF16; `rebuilt_abs` (plain values + restore) drifts. "K93
replays bit-exactly" describes the column the candidate does *not* use.

**22.3 — the aux-lag question is closed** (C4.5); `v3-control-flow.md` now carries the answer inline.

**22.4 — an earlier draft of this file synthesised all of the above into six R-lines and twelve
preconditions, and mixed D-facts into them.** That is why §2–§19 are per-component and why §21 exists:
a requirements list containing "fresh tape per unit" has already chosen the design.
