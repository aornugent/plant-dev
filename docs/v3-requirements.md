# Constraint inventory — per component, with evidence

**What this is.** Not a synthesis. The individual constraints each component imposes, listed
separately so they can be reviewed in aggregate before the design space is reopened. Hundreds of
probes produced these; collapsing them into six R-lines threw away the specifics that any design must
actually satisfy, and an earlier draft of this file made exactly that mistake.

**Two kinds of statement are kept strictly apart.**

- **C-constraints (§2–§19)** — properties of plant, the models, the maths, or the AD substrate. True
  regardless of which design we choose. These are requirements.
- **D-facts (§21)** — properties of the *current candidate* (the step-local sweep). Real, measured,
  and **not requirements**. "Fresh tape per unit", "the change goes inside the unit", "what a stored
  unit carries" all live here: they are answers, and putting them in a requirements list pre-decides
  the design. Read §21 as "what we learned by building one candidate", not as constraints.

**§20 is the untested register** — per component, with what would settle each.

Every line cites a measurement, a code location, or an algebraic derivation. Where documents
disagreed with the code, the code won; §22 records the corrections.

---

## 1. The goal, unsynthesised

Exact trait/parameter gradients of the SCM's **emergent** outputs — census metrics (LAI, biomass,
basal area) and R0/offspring — for **K93, FF16 and TF24**, at **production lifetime**, with a concept
count a plant developer can hold, verifiable against finite differences, adding **no engine vocabulary
per model**, and without regressing the forward model.

Everything below is a constraint on *how* that can be achieved.

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

## 6. The light field — separability and its preconditions

| | constraint | evidence |
|---|---|---|
| **C6.1** | all three strategies shade with **one** rank-3 kernel: `{1, −2z^η, z^2η} · {amp, amp·H^−η, amp·H^−2η}` | algebra, checked against `canopy_shape.h:196-211` |
| **C6.2** | the factorisation is exact **only when the same η appears in query and source factors** | `(1−(z/H)^η)²` expands that way and no other |
| **C6.3** | **the field is assembled with ONE canopy, taken from `species[0]`** | `patch.h:757-759`, commented "any cohort's canopy (shared shape)" — an assumption, not a fact |
| **C6.4** | **so all species must share η.** Mixing it does not degrade, it **diverges**: the field computes **7.98e+14** where the exact kernel gives 0.118 (η 12 vs 4); 742 at η 12 vs 10 | `two-species-probe` |
| **C6.5** | only the **DeepCrown** profile is separable; `FlatTopBox`/`FlatTopSoftBox` have **no correct tangent route** | `canopy_shape.h`, `shading_rank`; both are explicitly pedagogical, defaults are DeepCrown |
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
| **C14.5** | R0/offspring is an **ODE state** (`offspring_produced_survival_weighted`), so it is still a final-state functional, not a cross-unit accumulator | `node.h` |

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
| **U2** | TF24 memory | **the ~89 MB per-unit tape is an extrapolation** — marginals stop at width 606, production is 987, and no TF24 *unit* tape has ever been measured. The whole memory case rests on it | TAPE_STATS on one restored TF24 unit; blocked by C11.7 |
| **U3** | TF24 leaf | the `Leaf` fix is unchosen, and the choice **changes C17.4/C17.5** | #37 |
| **U4** | multi-species | **no gradient has ever been taken with two species.** Replay is verified in double only, and only with **equal widths** at every segment | two species introduced on different schedules |
| **U5** | multi-species | C6.4 (shared η) has no **structural** enforcement — nothing stops a user configuring two ηs and getting 1e+14 | a precondition check, or per-η field blocks |
| **U6** | R0 | `set_birth_state` is called by no test, has **no public API** (C4.8), and the drift lands precisely in the slot R0 reads | #44 + #45 |
| **U7** | FF16 | its gate is **4 orders looser** than the truth (C10.8) | tighten after verifying the δ-sensitive FD |
| **U8** | the step unit | splitting `advance_fixed(e.times)` inside `SCM::run_next_impl` has **never been attempted**; TF24 needs it | #35 |
| **U9** | time | the 4.2× is an odelia toy at ~22 µs/unit; **no end-to-end plant sweep has been timed** | time a K93 sweep against its whole-run gradient |
| **U10** | structure determinism | C8.3 has **no structural defence**, only prose |  |
| **U11** | field | C6.8's empty-species-0 UB is unreachable on **one** schedule; not in general |  |
| **U12** | census | the per-unit path was witnessed with summed height and summed height²; **the real census Ψ (mass-consuming) has not run through it** | run `census_vector` through a unit |
| **U13** | soil | C12.3 holds down to rainfall 0.05; the guard remains a severance if a drier driver is ever used |  |

---

## 21. D-facts — properties of the current candidate, NOT requirements

Kept separate on purpose. These are what building the step-local sweep taught us. A different design
need not honour them; it must only honour §2–§19.

| | fact | evidence |
|---|---|---|
| **D1** | peak = whole ÷ units, and the reduction factor **is** the unit count | peak flat 6 560 B over 30→480 units while whole-run grows 91 636 → 1 438 036 B |
| **D2** | a **fresh tape per unit**, not a rewound one | forced by C2.3 |
| **D3** | the structural change must go **inside** the unit; between units, a stand-dependent newborn loses its adjoint — **19%**, silent, right sign | and C5.6 shows plant's newborns *are* stand-dependent, so this is live |
| **D4** | a stored unit carries: ODE state, per-species counts, light spline, and the three birth stamps. **Not** the aux (C4.5) | TF24: 20.7 MB trajectory + ~3.4 kB stamps |
| **D5** | **the chained state adjoint is exact in plant** — one tape over N units vs N tapes with λ carried: **1.4e-16 / 7.9e-15 / 3.4e-15** at 3 / 6 / 12 units, λ matching exactly, with cancelling per-unit terms (+1.55, −3.08) so a single bad unit could not hide | `chained-adjoint-probe` |
| **D6** | on a frozen trajectory a unit is FD-exact at **1.3e-09**; per-unit tape **0.96 MB** (K93 ~40 cohorts), **4.38 MB** at production lifetime | `unit-adjoint-probe` |
| **D7** | time cost is a **flat 4.2×**, memory saving grows with the run | the trade's shape is right |
| **D8** | the restore is **11–15%** of a unit — not the bottleneck |  |
| **D9** | the engine is five concepts: `Solver`, the `System` contract, a `Functional`, `implicit_value`, and one rule |  |
| **D10** | component leanness cannot close the gap — best genuine win 5.89× moved TF24's total by **0.018%** | which is why the *unit* was the answer, not a primitive |

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
