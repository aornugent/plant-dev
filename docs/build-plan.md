# The odelia AD engine — build plan

Companion to [`design.md`](./design.md) (the *what*/*why*). This is the *how* and *in what order*: a
phased, parallelizable sequence that re-reaches the current plant#52 feature set (all four strategies
reverse-mode + TF24 soil coupling) on the clean engine, then the fixed-point layer. Supersedes the
archived `ad-engine-build-plan.md`; folds in the delivery ladder, the risk gates, and the build/test
mechanics surfaced from the prototype docs.

## Two axes: phases (primitives → strategies) × the delivery ladder (subgraph difficulty)

Progress is fastest when the two axes are worked together. The **delivery ladder is residents-first**
(the flip from the prototype's invasion-first — see `design.md` §2). It orders the *Jacobian rows* up the
resident subgraph; the mutant (L3, frozen field) path is the **deferred** additive variant, layered on
after the resident recording exists.

- **Rung 1 — resident single-metric sensitivity** (L2-recompute, self-shading; a single-state census
  weight): the primary path, minus the density-transport subtlety. Establishes the L2 recompute + the
  clean odelia/plant boundary.
- **Rung 2 — resident census, multi-variable + multi-species**: the weight `Ψ` reads the full cohort
  state; the functional is a vector of `m` reductions with species-major columns and cross-species
  shading terms. Adds the **`∂g/∂h` density-transport term** (the mass chart) — the only tier that needs
  it robust. This is the load-bearing target (`design.md` §8).
- **Rung 3 — `dR0/d(birth_rate)`** (the regnans equilibrium deliverable): the density-regulating feedback,
  on the resident self-shading path; then the fixed-point/selection layer (Phase 3).
- **Deferred rung — mutant invasion-fitness** (frozen L3 field, no `∂g/∂h`, no self-shading): the
  *cheapest* subgraph, but deferred per the current plan — it is an additive recorded-read variant, built
  once the resident recording and the L3 cache land. (It remains the selection-gradient persona's path.)

## Standing constraints (hold on every landing)
- **Bit-identity guard.** Nothing lands that moves the `double` path: `test-strategy-ff16(-reference-comparison).R`, the K93 "offspring production unchanged" snapshots, `test-control.R` (pins the Control field set). A changed number = broken bit-identity; **diff the FP order, not just the value.** (Sanctioned exception: the mass chart's ~0.169% K93 shift, opt-in for gradient runs.)
- **Each engine primitive ships its own verification before any plant consumer uses it** — the dot-product oracle `⟨Jv,u⟩=⟨v,Jᵀu⟩` for `separable_field`; IFT-vs-FD for the implicit-node; Richardson-FD-vs-analytic for `incomplete_gamma`. The scarce resource (hand-adjoint correctness) defended structurally.
- **Gate-0 is the oracle; the census metric is not.** Verify the active path at single-leaf/single-cohort clean FD (swept over δ). Never trust `compute_competition(0)` census FD (~%-noisy, fooled the prototype repeatedly).
- **UX-2 fixture gate.** Snapshot validated Jacobians to `tests/testthat/fixtures/gradient-baseline.rds` (two-tier tolerance). **Nothing merges without UX-2 green** — the AD-vs-AD regression net, distinct from Gate-0.
- **The one cross-track contract.** The engine must **tape the scheme as run** with a frozen, replayable control-flow schedule (L0 cohort schedule, L1 steps, L2 knots). Any parallel track (multirate) must keep its micro-schedule / event / pin decisions recordable in pass 1 and replayable in pass 2.
- **Clean odelia/plant boundary (the v2 emphasis).** odelia owns the tape, the primitives, and record/replay across the growing dimension; plant supplies only scalar-generic closed forms + residual/kernel declarations. No model code reaches the tape (this is what makes the boundary cleaner than the prototype's in-model `supplied_derivative` seam). One templated body per read — **never** parallel `!is_same_v<double>` overloads.
- **Build/test mechanics** (survival-critical — from `archive/ad-handover.md`): reinstall `odelia` after ANY odelia header edit (plant compiles against *installed* headers, not the submodule tree); `Sys.setenv(TESTTHAT_PARALLEL="false")`; build optimised once (`cd plant && make`, `-O2`) then `load_all` reuses the `.so`; regenerate RcppR6 only when adding/removing a registered field; on `undefined symbol`, `rm src/*.o src/*.so` and reinstall.

## ►► CURRENT WORK — AD-touchpoint remediation (2026-07-20 audit) ◄◄
Full findings + method: [`ad-touchpoint-audit.md`](./ad-touchpoint-audit.md). A
whole-surface audit (every model + engine header vs pre-AD `develop`) plus an
**empirical per-leaf certificate** (reverse-AD over every `AD_FIELDS` leaf vs a
reoptimising FD) established, mechanically rather than by reading, WHERE and WHETHER
a trait derivative is lost. The FF16 "a_l1 residual" that started this was one
symptom of a small, enumerable class of defects; the audit found the rest — including
two the file-reading missed (`omega`, K93 `k_I`).

**Certification status:** FF16 ✓ certified, K93 ✓ certified, **TF24 ✗ blocked
(reverse-AD numerically blown up, ~1e30 vs sane FD — a separate debugging track)**.
Completeness = static grounding census (finite: 63 `to_passive` + 36 `xad::value` +
36 `double` members + 2 un-templated helper classes) ∧ per-leaf empirical certificate.

**Two failure modes, one vocabulary:**
1. **Grounding** — a leaf's derivative flows *through* a node that grounds to `double`
   (un-templated helper class, bare-`double` member, `to_passive`, or a non-smooth
   clamp). Severs everything upstream.
2. **Un-registered leaf** — a param never wired onto the graph (`double` member not in
   `AD_FIELDS`). Its own gradient is simply absent.

**Remediation — Tranche (a): FF16/K93 (certified, ready to build).**
| # | fix | closes | mechanism / exemplar |
|---|---|---|---|
| a1 | **template `CanopyShape` on `S`** (eta/eta_c/eta_inverse become `S`) | `eta` SEVERED in **FF16 + K93 + TF24** at once | it is an un-templated class holding eta as `double`; methods template only the query. One class fix, three strategies. **structural → system-design first.** |
| a2 | **`smooth_positive`** the FF16 `net_mass_production_dt_>0 ? rate : 0` clamp (`ff16_strategy.h:300-326`, and establishment `:670-675`) | `a_l1`/`a_l2` PARTIAL (the a_l1 residual) | K93 exemplar `k93_strategy.h:253`; add an `FF16_Strategy` corner-radius member mirroring K93 `growth_eps=1e-4`. Re-baselines FF16 demography (r is the knob). |
| a3 | **IFT-lift the birth SIZE** and consume the lifted value in `area_leaf_0` + `establishment_probability` (not the raw `height_seed()` double root) | `omega` SEVERED (FF16 **and** TF24 — shared), establishment `height_0` | reuse `lift_birth_height`; `omega` flows only through the birth-size root-solve. |
| a4 | trace + lift K93 `k_I` growth-channel path | K93 `k_I` SEVERED (growth) | small magnitude; likely a passive in cumulative_basal_area/canopy. |
| a5 | **qk → `odelia::quadrature` primitive** (DX, no numeric change) | the `to_passive`-saturation smell | value+bound derivative already correct; move it off plant model code. |

**Remediation — Tranche (b): TF24 (blocked — its own track).**
- **b1 — debug TF24 reverse-AD blow-up (BLOCKER).** Reverse gradient is ~1e25–1e32 vs
  sane FD on every nonzero-gradient leaf. Non-functional, not merely missing a term.
  Candidates: the Leaf `supplied_derivative` seam partials, reverse over the stiff
  soil ODEs, or a tape/rebind issue. Check forward-mode too (isolate fwd vs rev).
- **b2 — plant#60 dropped-term** (once b1 is fixed): the seam differentiates the
  non-stationary co-output `soil_consumption_`/`E_up_` at fixed collar-ψ, dropping
  `(∂c/∂p)(∂p*/∂ψ)`. **Fix seam already present:** `dsoil_consumption_dpsi_collar_perlayer`
  (per-layer `∂c/∂p`) × `dprofit_droot_collar_psi` (exact IFT `∂p*/∂ψ`). Verify with a
  **reoptimising** FD on a real patch (a frozen-p* FD hides it).
- **b3 — register TF24's hardcoded-double leaves** (`root_c`, `root_b`, `beta_R_H`,
  `beta_R_V`, TF24f `k_acclim`, soil-env `K_s`/`a_psi`/`n_psi`/…) if their gradients
  are ever needed; **b4 — `smooth_positive`** the soil drought clamps
  (`tf24_environment.h:244/276/295/306`) and `max(light_openness,1e-4)`.

**Engine-level (both tranches):** guard `odelia::supplied_derivative()` — it injects a
value + partials with no stationarity check (the plant#60 invitation); keep it
reachable only via `register_implicit`, or debug-FD-check the partials at registration.

**Do NOT touch (verified correct):** density transport (dλ/dt=−mortality), reconstruct/
seed/spacing, the separable-field assembly+read, qk value+bound derivative,
`lift_birth_height` IFT, scm active-run gating, replay positions/counts/diagnostics,
`node.h:319` FD stencil (severed-by-design, dead on the mass chart).

**Diagnostics (scratchpad, re-runnable):** `certificate.R` (FF16/K93 per-leaf),
`tf24_cert.R` (TF24, shows the blow-up), `birth_sweep.R`/`state_tan.R`/`a_l1_diag.R`
(the a_l1 localisation). Certificate driver committed: `plant/tests/testthat/ad_certificate.cpp`.

## Phase 0 — validate the biggest bets (pure `double`, no build) — **DONE**
See [`phase0-results.md`](./phase0-results.md). **F1** confirmed the fixed-point route (Eulerian
transport operator faithful to the march, residual 8.6e-6; steady profile well-posed). **E2** redirected
the soil track (drainage/potential envelopes don't share a shape — 32 OOM; the desingularizing chart
makes it *worse*, 0.30–0.47×; kink-split cuts rejections 1.85×). Two Gate-0 deepening checks: **A**
(mass-chart stability) passed (bounded at the default clamp, 0.169% shift); **B** (leaf early-exit C⁰)
**refuted** the continuity assumption (a true ~1.46 profit jump → an honesty-condition refuse point, not
a breakpoint).

(PROTO-2 — the old "does the full-scalar replay capture the density→optimum cross-term" rescope gate —
is **resolved**; the density→optimum cross-term is captured, and the v2 work pursues clean odelia/plant
boundaries rather than re-proving it.)

**The front-loaded de-risk is now the odelia co-design ledger** (`design.md` §3). The load-bearing
*mechanism* (CD-A, the tape surviving mid-run resize) is **already verified** — so the front-loaded work
is the integration fixture CD-G (compose the confirmed pieces into the plant shape) + CD-B wiring, on the
clean-boundary axis the v2 emphasises:
- **CD-A — growing-dimension active replay** *(mechanism CONFIRMED — the remaining work is CD-G).* Does
  odelia's active tape survive a mid-`run()` `resize()`, taping-once across `[grow][resize][integrate]`?
  **Verified:** `test-ad-growing-resize.R` matches AD to closed-form (1e-8) and FD (1e-6) through
  post-resize cohorts, `reserve_state` on *and* off; the `AReal`-slot-index mechanism (odelia #6) makes
  the tape immune to the realloc move. So this is **not** an open architecture risk. What is left is the
  plant *composition* — CD-G — a new cohort's active ICs (`log_density=log(birth·estab/g)` reading the
  active stand), co-timed multi-species resize, the census over the growing set. **Exercise IC-seeding
  (ledger E) first on `IndividualRunner`** (fixed-dimension, clean single-plant), **then CD-G on
  K93-resident** (the cheapest full SCM: growing dim + L2 recompute + census, no leaf/quadrature).
- **CD-B — tape-from-`ode_rates` injection** is **resolved by the primitive design** (the model declares
  a residual; the odelia-owned implicit-node injects) — but the primitive must be *wired* so a plant rate
  path triggers it during replay without a model-held tape handle. Verify with P1a on a plant-shaped toy.
- **CD-G — the SCM census gradient (the integration fixture).** **Objective in lights:** *improve the
  odelia primitives so plant's DX is pain-free.* Build the K93 SCM census gradient, feel where plant must
  write tape-aware/boilerplate code, and push that pain into odelia.

  **What #52 actually has (verified 2026-07-17 against the PR head `780cfe49`, stack 4/4):** all four
  strategies scalar-templated; **Gate-0 gradients only** (IndividualRunner single-plant + leaf-level, FD-
  checked); the SCM census *plumbing* (dg/dh, geometric compression, species-major seeding). It has **no**
  SCM/census gradient entry, **no** `EmergentFunctional`, **no** `stand_gradient`, **no** LAI/biomass/R0
  functional. (The SCM gradient was the abandoned `AD-*` attempt — not trusted; `AD-9`/`spike` are
  contaminated reference at most.) So CD-G is a genuine v2 build.

  **Build (K93 first, then FF16, then TF24):**
  1. `Patch<T,E>` already satisfies the odelia System contract and grows; the SCM already runs active via
     the ode-times replay branch (`run_next_impl` `advance_fixed`, adaptive compiled out) grown by
     `introduce_new_nodes`. Active IC seeding is real (`node.h:210` `log_density=log(birth·pr_estab/g)`).
     **No `reserve_state`** — the `AReal` slot-index makes the tape resize-immune (verified).
     **The SCM is itself the runnable** (accessors landed, plant `593e2e78`): `get_system_ref()` returns
     the `patch` snapshot (seed target pre-`reset`, read target post-`run` — one object, structural). The
     **tape lives on the SCM**, not a wrapper (a wrapper would be a named object that only forwards —
     rejected under the DX / no-new-abstractions principle). Copyability for the R-facing SCM follows
     odelia `Solver`'s precedent: a `unique_ptr<tape_type>` member + a copy-ctor that resets the tape, added
     only if the build shows move-alone insufficient.
  2. **DX finding #1 (seeding flow):** the gradient driver seeds `ad_parameters()` then `reset()`s, but
     `Patch::ad_parameters()` points into the *live species* while `reset()` reseeds from a separate
     `parameters.strategies` copy — the seed is lost. `IndividualRunner` dodges this (reset re-derives from
     the seeded object). Make the SCM-runnable's seed target and reset source one and the same.
  3. **Functionals (the interface user-stories, `EmergentFunctional`, pure reductions):** a multivariate
     census **vector** `(LAI, biomass, basal area)` (codomain=3, one recording → 3 sweeps) **and** R0
     (`net_reproduction_ratio_by_node_weighted`, templated to `value_type`). K93 tracks size, so its census
     is a size/basal moment; LAI/biomass are FF16/TF24 metrics. Report all four together where useful.
  4. **Verify with the JVP=VJP dot-product oracle** (census FD is documented ~%-noisy). Needs
     `node_geometric_compression=TRUE` + `save_RK45_cache=TRUE`. A sourceCpp driver like the gate0 ones —
     **no `stand_gradient`/R surface yet** (settle the C++ boundary first). Guards the transport-default
     deletion and the `separable_field` swap.

  **Driver decomposition (build bottom-up, verify each layer — 2026-07-17 findings):**
  - **Finding: no C++ SCM construction.** `scm_base_parameters` / `birth_rate` (via `ExtrinsicDrivers`) /
    the node schedule are set up *R-side* (`scm_support.R`); the gradient needs an *active-typed* SCM
    rebuilt from those params. So the driver must either construct the K93 `Parameters<active>` in C++
    (replicating the R setup) or rebind a double SCM's params to active. This is real work v1 never did.
  - **Finding: the resident path is L2-recompute, not L3-freeze.** `has_recorded_field()` is false while a
    resident records/replays, so the active pass recomputes the field via `compute_environment(true)`
    (rescale on frozen knots) — self-shading flows. The driver's crux is handing the double run's recorded
    **knot positions** to the active SCM's rescale (L2), distinct from `run_mutant`'s `environment_history`
    freeze (L3, `has_recorded_field` true).
  - **Layers:** (a) build+run a double K93 SCM in C++, reduce a census metric, check vs R `run_scm`;
    (b) census functionals — basal/size moment (K93), LAI/biomass/basal vector (FF16/TF24), R0 via
    `net_reproduction_ratio_by_node_weighted` templated to `value_type`; (c) active SCM + L2 knot handoff +
    tape-on-SCM; (d) `compute_gradient` + `compute_jvp` + the oracle.

  **STATUS (2026-07-18) — ⚠️ CD-G gradients are WRONG for trajectory traits; the fix is the exact field.**
  A δ-swept finite-difference audit (2026-07-18) overturned the earlier "oracle-verified" claim. The SCM
  census + R0 drivers (`k93_scm_census_driver.cpp` / `ff16_scm_gradient_driver.cpp`) compute a gradient
  that is **~30× wrong** for any trait acting through the growth / self-shading trajectory (b_0, b_1 for
  K93; lma, a_l1, k_l for FF16), and correct *only* for traits acting directly on the metric (recruitment
  `d_0` → offspring is exact to the digit). What still stands: the SCM-as-runnable contract, the resident
  L1 ode-time replay, the value_type reproduction chain, tape-on-SCM, the mass-chart transport, and every
  double path (bit-identical). What does **not** stand: the gradient numbers and the "verified" label.

  - **Why the oracle lied.** JVP=VJP checks reverse-vs-forward *self-consistency*; both legs traverse the
    same lossy field representation, so they agree with each other while both being wrong vs the model.
    **New verification standard: every SCM gradient is gated by a δ-SWEPT FD (find the stable plateau),
    not the oracle.** The oracle stays only as a cheap self-consistency smoke test. (Single-δ census FD is
    noise-dominated — the documented trap — so the *sweep* is mandatory: plateau ≈ truth.)
  - **Root cause = the self-shading feedback derivative, dropped by the spline field.** `Patch::compute_
    environment` samples `compute_competition(x)` at *double* x and fits a `ResourceSpline`; the cohorts
    then read that spline. The query-height derivative is dropped (`get_value_at_height_frozen_query`) AND
    the feedback through the field doesn't survive on the reverse tape — unfreezing the read left the
    gradient bit-identical, so the frozen query is not the (whole) cause; the spline field-representation
    is. K93's "analytic, no L2" claim above was **also wrong** — K93 uses the light spline like FF16.
  - **The fix = `odelia::separable_field` as the environment's field representation** (the P1b intent:
    "interpolator demotes to non-separable fallback; exact separable_field field"). Assembled from the
    cohort population each step (O(N)), queried at the **active** cohort height (`at(a(z), rank(z))`), so
    the query-height derivative *and* the active source-factor self-shading both flow exactly. Conditioning
    is fine at K93's eta=12 (spike: field/slope vs direct sum to ~1e-15; the earlier "48-orders → needs
    deferred band" fear was wrong — same-sign terms, negligible far-source underflow). No robustness band
    needed.
  - **Integration seam + contract (DX-first).** Strategy declares the rank-3 Yokozawa factors
    `{a_p(z), a'_p(z), b_p(size)}` (one plant-side contract); `Patch::compute_environment` assembles the
    field from cohort factors instead of handing over a double sampler; `get_environment_at_height(z)`
    keeps its signature and queries `at(a(z), rank(z))` with `rank(z)` a binary search over descending
    cohort heights. Gate: K93 census gradient matches the δ-swept FD (b_0 ≈ 48800, b_1 ≈ -38700), then
    FF16/TF24, double path held bit-identical.
  - **Landed + still valid regardless of the gradient bug:** tape-on-SCM (`scm.h` lazy tape + copy-ctor,
    R ABI unchanged); value_type reproduction chain (`util::trapezium` accumulator, `Node::fecundity`/
    `weighted_fecundity`, `Species`/`Patch` reductions, double byte-identical); resident L1 replay via the
    public node-schedule surface; mass-chart K93 default transport.
  - **Superseded earlier claims (struck):** "CD-G layers (a)–(d) oracle-verified"; "K93 analytic / no L2";
    "separable_field deferred for eta conditioning"; "FF16 R0 verified". All corrected above.

  **UPDATE (2026-07-18) — ✅ K93 exact separable field INTEGRATED; census + R0 gradients FD-CORRECT.**
  The exact `separable_field` now backs K93's competition read (`CanopyShape` rank-3 factors →
  `Patch::compute_environment` assembles from cohorts → `K93_Environment::get_environment_at_height`
  queries `at(a(z), rank(z))` with an active query height). The self-shading feedback derivative now
  flows, and the K93 census AND offspring/R0 gradients **match the δ-swept FD** (in-test gate, tol 1e-3;
  census b_0 −490.9, elasticity ~−1.1 — sensible, vs the old spline model's absurd +111). The oracle is
  demoted to a self-consistency smoke test. The field is **faithful**: K93 double offspring within the
  1e-4 test tol (single- and multi-species); full K93 double suite green (strategy-k93 21/0, patch 145/0,
  scm 89/0, species/node clean); FF16/TF24 bit-identical (`env_has_competition_field` scopes it to K93).
  Two real bugs found+fixed by the FD gate (both UB the install tolerated): a **dangling `CanopyShape`
  pointer** (`&r_get_strategy().canopy_shape` on a temporary — the ~20% multi-species error) and a
  **missing `/area`** in the amplitude (the test-patch change-patch-size failures). Conditioning at eta=12
  is machine-precision (spike). ***DONE — the redundant K93 spline build is dropped*** (`Patch::compute_
  environment` assembles the exact field only for `env_has_competition_field` environments; the spline
  path stays for everything else). height_max reads the species not the spline, the slope surface has no
  callers, and fixed-environment cases build their own spline via `set_fixed_environment`, so the resident
  spline was dead weight; full K93 double suite + the FD-gated gradient tests stay green, FF16/TF24 take
  the unchanged else branch and are bit-identical.

  **UPDATE (2026-07-18) — FF16 reads the exact field (P2b objective); R0 gradient bug LOCALISED to the
  crown self-shading z–H linkage.** Added the δ-swept pinned-schedule FD gate to
  `ff16_scm_gradient_driver.cpp` (it was oracle-only); it exposed the same false confidence the oracle gave
  K93 (`d(R0)/d(lma)` reverse ~ +440 vs FD plateau ~ −255). FF16 now reads its deep-crown light from the
  same exact `separable_field` K93 uses (`field_supersedes_spline=false`, so FF16 still builds the spline
  for not-yet-assembled / fixed-environment reads; all double suites green within tol). A `freeze_query`
  channel-isolation switch on the field read splits the bug decisively: the field's SOURCE self-shading
  derivative is CORRECT (freeze_query reproduces the spline to the digit, −172.5/3.69/−7.29), and the
  ENTIRE error is the **query-height channel** the field newly adds (+615 for lma vs a true ~ −82). Root
  cause = FF16's crown integral reads at `z = node·H`, so the focal plant's self-shading `Q(z/H)=Q(node)`
  is H-invariant, but the separable factoring `a_p(z)·b_p(H)` treats z and H as independent and the focal
  self-shading query/source derivatives fail to cancel. K93 never hits this (reads at `z=H`, `Q(1)=0`).
  **CORRECTION (fix attempt refuted this):** the self-linkage was NOT the bug — freezing the focal
  cohort's own query contribution made the gradient worse (+442→+729). The query error is in the
  CROSS-cohort terms (+902 vs a true −82), leading suspect the FROZEN RANK (`n_sources_at_least` uses
  passive z, so `dA/dz` misses cohorts entering/leaving as the crown query sweeps). See the detailed
  update below. The FD gate is `expect_failure` (green now, red when fixed); `freeze_query` is the
  diagnostic. The field integration (source channel proven correct) stays; the query fix is open.
  (Earlier this session I wrongly guessed a "source-side" error and hastily reverted the field on DX
  grounds — corrected: the field is the objective, its source channel is proven correct, and it is now
  integrated. A shared `CompetitionField<S>` extraction is deferred until the FF16 read is correct, then
  K93+FF16 are its two consumers.) **Remaining:** the crown-linkage fix, then TF24 (P2c: leaf IFT via
  P1a + `incomplete_gamma` + soil coupling); the multi-species single-shared-canopy assumption.

## Phase 1 — engine primitives (odelia); P1a–P1e — **LANDED**
Each a standalone odelia addition with its own test, no plant dependency. All landed and verified on
`claude/odelia-ad-tape-reverse-496fuf` (each ships the dot-product oracle and/or an FD/analytic
self-check): **P1b** `separable_field`, **P1e** `cohort_spacing`/`log_density_rate`, **P1d**
`smooth_positive`/`is_finite` + `decide`/`diagnostic`, **P1a** `register_implicit`, **P1c**
`incomplete_gamma`. Two scoping refinements taken under the witness principle, recorded below:
- **P1a is scalar only.** Every Phase-2 inner solve (leaf `ci` root, collar optimum, birth height) is
  scalar; the dense/nested (KKT, tangent-over-adjoint) case has no witness until the fixed-point BVP
  (Phase 3), where it lands — an unsupported nested scalar type is a `static_assert`, not a silent path.
- **`decide` records in call order for a fixed replay schedule.** The commit-per-accepted-step wrapping
  that makes it exact across an *adaptive* recording pass (discarding rejected steps) belongs with the
  SCM System (P2a), like a recorded field's commit.

P1f (`QK<S>` templating) is plant-side and applies at P2b (see the ledger below).

**Reassessed order (2026-07-17): separable field first, not implicit-node.** The earlier "P1a first,
load-bearing, de-risk first" put the implicit-node at the front because the scary unknown was whether
the tape survives the growing-dimension resize / `ode_rates` injection. **That is now closed** (CD-A
verified — `test-ad-growing-resize.R`). So the front of Phase 1 optimises instead for the *shortest path
to one end-to-end verified resident gradient* — **K93 resident census**, the first visible win. K93 has
**no inner solve**, so P1a/P1c are not on its path (they are TF24 machinery, P2c). The K93 path is
**P1b (separable field) → P1e (mass transport) → P2a/CD-G**. Build order: **P1b, then P1e, then P1d (light,
structural), then P2a**; P1a+P1c land just before P2c, P1f with P2b. CD-B (tape-from-`ode_rates`) rides
P1a and is verified on a plant-shaped toy when P1a lands, not up front.

- **P1b — `separable_field`** *(first; the v2 core — **LANDED**).* Descending suffix scans build the field `A` and its query slope `∂A/∂z` from the separable factors; exact, non-adaptive. Verified: rank-3 separability, field/slope vs the direct O(N²) sum, and the dot-product oracle `⟨Jv,u⟩=⟨v,Jᵀu⟩` to machine precision (`odelia::separable_field`, `test-ad-separable-field.R`). *Deferred within P1b (noted):* the near-diagonal direct band `δ` and Neumaier compensation (robustness at high η), and the custom vectorised transpose (a tape-memory optimisation whose correctness target is the verified taped version).
- **P1a — `register_implicit`** *(**LANDED**).* First-order reverse-through-solve: `dy/dp = -(dF/dp)/(dF/dy)` by forward-differentiating the residual at the root, carried through double/forward/reverse, no nested tape; sign of `dF/dy` asserted; unsupported nested type a `static_assert`. **Scalar** (covers every Phase-2 solve); dense/nested reserved for Phase 3. Verified: reverse gradient vs analytic, IFT vs re-solve FD, the oracle (`test-ad-implicit-node.R`).
- **P1c — `incomplete_gamma`** *(**LANDED**; was "the γ node").* Lower incomplete gamma via the elementary everywhere-convergent series, so AD gives value + `∂/∂x` (the integrand/Leibniz endpoint) + `∂/∂a` (shape) off the same code — no hand digamma, no supplied-partial node. `∂²` reserved (Phase 3). Verified vs `pgamma`, the integrand, an FD, and the exact Weibull endpoint (`test-ad-incomplete-gamma.R`).
- **P1d — value guards** *(**LANDED**).* `smooth_positive(x,r)` (canonical, plant's own formula — bit-identical) + ADL `is_finite`; `decide`/`diagnostic` (`test-ad-value-guards.R`, `test-ad-decide.R`). The `xad::value`/`to_passive` grep ban switches on with the plant port (P2a). The harness (frozen-schedule FD, per-edge probes, dot-product oracle, M1 gate) is folded into each primitive's test.
- **P1e — mass transport** *(**LANDED but only HALF the design; superseded by P1e-λ below**).* `cohort_spacing` + `log_density_rate`; `C = cohort_spacing(g)/cohort_spacing(x)` shares the reduction operator by construction, so the compression cancels in value *and* parameter derivative in Δx-weighted reductions. Verified: the cancellation identity, the secant vs analytic `dg/dx`, the oracle (`test-ad-mass-transport.R`). **What landed is NOT the design's log-mass chart:** `log_density_rate` still transports log-density `ℓ` (`dℓ/dt = −C − loss`) and still COMPUTES `C`. It only realises the reduction-level cancellation, not the state-level one. Consequences (confirmed 2026-07-19): (a) `ℓ` overflows at growth-shutoff stalls — the #550-family density runaway (reproduced on TF24 drought *and* FF16 on Scheme B); (b) `C` is on the tape, so the sub-grid stencil variant severs its θ-derivative (the FF16 `O(1)` coupling-gradient error). K93 is stable+correct on it only because its growth is monotone (no stalls) and Δx-weighted reductions cancel — it is the benign case, **not** the correct chart.

- **P1e-λ — the transport-log-mass chart, as `design.md §88` actually specifies** *(the real fix; Oracle-confirmed twice, `oracle-response-transport-compression.md`).* Transport **log-mass `λ = ℓ + log Δx`**, not `ℓ`: `dλ/dt = −r` — the compression cancels **identically in the state rate**, so `C` (`∂ₓg`) is never computed anywhere. `λ` is monotone (`≤0` between insertions) ⇒ **no overflow, any regime**; no numerical `∂ₓ` on the tape ⇒ **no severance, correct gradient**; shorter tape. One scheme for K93+FF16 ⇒ **re-bless demography snapshots** (design's canonical-chart pairing). Model still expresses in log-density; odelia reconstructs it (`ℓ = λ − log Δx`) / density (`exp(λ)/Δx`) as an exact taped read-side view.

  **Touch-point map (traced 2026-07-19; `if constexpr strategy_supports_geometric_transport<T>` so non-geometric FF16-default/TF24 stay bit-identical):**
  - `node.h`: transported slot = `λ` (store `log_mass_`); `set_ode_state` loads `λ` (defers density); `ode_state` writes `λ`; `ode_rates` writes `dλ/dt`; `compute_rates` geometric branch sets the slot rate = `−mortality` (delete `growth_rate_gradient` from it); new `reconstruct_from_spacing(Δx)` sets `log_density = λ − log Δx`, `density = exp(λ)/Δx` (all downstream density readers unchanged).
  - `species.h`: delete the `log_density_rate`/compression block (no `C` computed); the rate is just `−mortality` from the node.
  - `patch.h` **ordering (the one hard constraint):** in `set_ode_state(it,time)` insert a density-reconstruction pass **between** the species state-load (`:806/807`) and `compute_environment(true)` (`:818`) — compute `Δx = cohort_spacing(heights)` per species and call `reconstruct_from_spacing` on each node, so the field reads the correct density. Same before `set_initial_state`'s `compute_environment(false)` (`:378`).
  - **Newborn mass seed (the one genuine modelling DECISION — affects the re-baseline, needs a call):** `compute_initial_conditions` must seed `λ₀ = log(m₀)`. Two options: **(A) reproduce birth density** `λ₀ = ℓ₀ + log Δx₀` (needs the newborn's post-insertion `Δx₀`; smallest trajectory change) vs **(B) flux×interval** `m₀ = birth·estab·Δt_insert` (the Oracle's "natural" choice; a mass directly from the boundary influx, no `Δx`; cleaner, larger re-baseline).
  - `R`/export/import/resume/`expand_state`: the exported density state slot is now `λ`; reconstruct on import; audit `r_log_densities`. Snapshots: re-bless K93 + FF16 demography.
  - **Gates (Oracle predictions):** M-trace `Σexp(λ)` bounded through the FF16 stall (overflow gone); reverse AD == FD (both models, coupling params); K93 gradient still correct.
  - **Build order:** K93 first (geometric, stable — validate identity + views + no trajectory pathology), then opt FF16 onto it (overflow must vanish), then re-bless snapshots, then R/resume.

  **FINDING (2026-07-19, first build attempt — the Δx-consistency requirement).** A first implementation
  (log-mass state + `reconstruct_from_spacing(cohort_spacing)` + option-A newborn seed, all gated to
  geometric strategies, `if constexpr`) COMPILED and RAN, but K93 offspring came out **0.00958 vs the
  stencil's 0.0753 (~8× off)** — far more than option A's intended minimal shift. Root cause: **the
  reconstruction and the reductions use DIFFERENT Δx.** `reconstruct_from_spacing` used the chart's
  *centred* `odelia::cohort_spacing` `Δx=(h[i-1]-h[i+1])/2`, but `Species::compute_competition` (the
  self-shading integral, and the census/offspring reductions built on it) is a **trapezium** rule
  weighting per-node contributions by the *adjacent gaps* `(h₁-h₀)`. So `density·(trapezium gap) ≠ mass`
  — the `/Δx` does not cancel, and the mismatch compounds. This is exactly the Oracle's caveat that "the
  reduction weights must be the chart's Δxᵢ" (`oracle-response-transport-compression.md`): the mass chart
  is only self-consistent if the SAME Δx appears in the transport, the view reconstruction, AND every
  Δx-weighted reduction. **So P1e-λ is bigger than "transport λ + reconstruct views": the competition
  integral / census quadrature must be rebuilt on the chart's `cohort_spacing` (a single consistent Δx),
  which itself re-baselines the double trajectory (larger than option A hoped).** This is the real crux
  and a genuine design point (which quadrature is canonical). The first-attempt code was reverted (tree
  clean); the log-mass state/view/seed structure is correct and re-usable once the reduction quadrature
  is reconciled. **Next: decide the canonical Δx (chart `cohort_spacing`) and rebuild `compute_competition`
  + the reductions on it, then re-run K93 (expect a consistent, characterised re-baseline, not 8×).**
- **P1f — `QK<S>` fixed-rule quadrature** (Cluster 4): template `QK::integrate` on the scalar **and the
  bound type** — the nodes are a deterministic affine image of the bound, so an *active* bound (a census
  integrated over an active plant height) tapes exactly through the moving nodes; **differentiate
  through, no recorded positions**. The `double` path is the `S=double` instantiation. (Not L2 — L2 is
  the adaptive light spline only.) **This is the v1 treatment** (the prototype already templated `qk.h`);
  it **stays plant's `qk.h`** — *not* moved to odelia (generic fixed-rule quadrature, one witness; defer
  the lift to a 2nd consumer). Delete the forked `integrate_ad`/`deep_crown_replay` spikes; don't touch
  the dormant adaptive `QAG`.

Named odelia follow-ups to fold in (from `archive/ad-issues.md`): #22 interpolator unification (the
replayable interpolator owns its own knots — the clean L2), #23 history rows, #27
functional-as-pure-reduction + driver-owns-replay, **#28 (done) — the three-cache record/replay + retire
`live|frozen`** (the model this build plan follows), #25/#26 comments/tests. The odelia-native
demonstrator (a shrink of FF16 resident light) exercises L1/L2 recompute + the L3 read + reuse + the
anti-staleness property against FD.

## Existing engine pieces (audited — see [`odelia-5-existing-pieces.md`](./odelia-5-existing-pieces.md))
The generic AD surface (Solver, gradient driver, functionals, record/replay, IC seeding,
growing-dimension) already exists and mostly needs no change. The audit adds these to the plan so it is
comprehensive:
- **Solver/SCM seam (Phase 1) — no new concept** (odelia #6). The SCM keeps its self-segmenting `run()`
  (HAS-A `Solver`, owns the `[grow][resize][integrate]` loop); the gradient driver keeps duck-typing it.
  Document the ~5 required methods in a **call-site comment** on `compute_jacobian`; the growing-dimension
  guarantee is the existing `test-ad-growing-resize.R`. **No `Runnable` concept / `static_assert`** — a
  `concept` can't check the runtime resize guarantee, so it would add a name without removing a bug class.
  **Deferred cleanup (1 witness):** odelia `Solver` owns the introduction loop → the SCM becomes a plain
  System; retrofit trigger = a 2nd growing-dimension System.
- **Interpolator simplification (with P1b).** `separable_field` (P1b) takes the separable coupling field and the
  mass chart takes `dg/dh`, so the interpolator demotes to the **non-separable fallback only** — **delete**
  its coupling-era bandaids (the frozen active-query derivative, the geometric-compression entanglement);
  keep clean construct/record/replay. Do **not** lift QAG into odelia (no adaptive-quadrature witness —
  crown is fixed-rule `QK`, P1f).
- **Multi-metric census test (Phase 2, high).** Verify the multivariate case we need: a
  multi-metric/multi-variable/**multi-species** resident-census Jacobian (persona 1: LAI+biomass+basal-area
  vs LMA+wood-density), FD-free-checked by the `compute_jvp` dot-product oracle + Gate-0 FD.
- **IC gradient (sequenced after the resident core).** Rests on **plant#499 / `78bd39`** (seed an initial
  size distribution at patch age 0 — landed). Wire `Patch::ad_initial_state()` to the age-0 seeded node
  states + a test; the resume-from-mid-run case stays fenced (the `scm.h:231` replay conflict).
- **Evaluate-then-decide (med/low)** (odelia #6). *Checkpointing:* measure peak tape memory on the
  largest resident census; if it breaches the budget (v1's one-tape run fit 0.5–4 GB) checkpoint at the
  node-introduction boundary using the **vendored `XAD::CheckpointCallback`** (reuse, no new abstraction).
  *`reserve_state`:* the spike shows the resize is amortized-O(N) slot-index-preserving POD moves (the
  tape is immune), so **delete `reserve_state`** unless a profile surprises us (then keep-and-call).
  Neither on the critical path; net **0 new named concepts**.
- **Naming pass (low).** Prose: bare "driver" → "**gradient driver**" (`compute_*`), distinct from the
  Solver *driving* the stepper and from `ExtrinsicDrivers` (forcings); glossary line; audit the odelia demo
  systems' driver members.
- **L0/L1:** done (adaptive-record → fixed-replay); confirm the SCM `run()` interleaves L0 introductions
  with L1 `advance_fixed` on the active replay (a test assertion). L3 deferred.

## Phase 2 — port plant onto the engine, bit-identity-guarded, in difficulty order
Sequential within plant; the critical path to #52 parity. Each strategy is taken **resident-first** up
the ladder (single-metric → multi-variable census → `dR0/db`); the mutant (L3) path is the deferred add.

**Base decided (2026-07-17): branch from the #52 tip (`780cfe49`), delete-and-replace, test-guarded.**
The history settles it: mechanical templating and AD pollution are *interleaved per strategy* — TF24's
Stage-A templating (`069bcc43`) is immediately followed by its FD seam (`ae34a72d`), so no commit has all
four strategies templated with no pollution. An earlier point (`~8cc44500`) is clean for K93/FF16 but
predates TF24 templating, so starting there means re-doing that templating *without* the green tests to
guard it. At #52 all templating is done, the pollution is localized (the Port map below enumerates it),
and the regression tests are green and encode the correct gradients — so we refactor *down* from a green
baseline, deleting each clunk and re-running the tests. The plant branch `claude/odelia-ad-tape-reverse-496fuf`
is cut from `780cfe49`; baseline K93-census and FF16 bit-identity tests pass (one unrelated pandoc/report
env failure). End state is base-independent; #52 is the safest path to it.

**Plant port ledger (all Phase-1 primitives landed; here is the plant edit each enables — status
*enabled*, not yet *applied*).** The primitive exists and is verified in odelia; the plant change waits
for Phase 2:
- **`separable_field` (P1b).** ***APPLIED at P2a (K93).*** Backs K93's coupling read: `CanopyShape`
  declares the rank-3 Yokozawa factors `{a_p(z), a'_p(z), b_p(size)}`, `Patch::compute_environment`
  assembles the field from the cohort population (`env_has_competition_field` scopes it), and
  `K93_Environment::get_environment_at_height` queries `at(a(z), rank(z))` at the active query height.
  The redundant K93 light spline is now dropped on this path. FF16 crown (P2b) still to come.
- **mass transport (P1e).** ***APPLIED at P2a — mass chart is now K93's default transport.*** The
  `Species::compute_rates` arm calls `odelia::log_density_rate`; the transport scheme is selected by a
  compile-time strategy marker `strategy_supports_geometric_transport` (K93 declares the nested
  `geometric_transport` type) **AND** the Control flag `node_geometric_compression` (default flipped to
  `true`). K93 defaults to the mass chart (flag still forces the stencil for the layer-(a) `geometric=FALSE`
  path); FF16/TF24 ignore the flag entirely (the secant is unstable for them) so the default flip leaves
  them **bit-identical**. `Node::growth_rate_gradient`'s active forward-over-reverse dg/dh block is
  **deleted** (dead once K93 is on the mass chart; FF16/TF24 never run an active SCM) — the double
  FD-stencil value path stays for FF16/TF24 production. **Sanctioned re-baseline applied:** K93 offspring
  `0.0753261 → 0.0754526` (single) and the three-species vector likewise (~0.17%); `test-strategy-k93.R`
  and the lone-cohort case in `test-node.R` updated. Verified: FF16/TF24/TF24f + gate0 bit-identical,
  node/patch/species/scm + K93 census/offspring gradients green.
- **`smooth_positive` / `is_finite` (P1d).** Plant `util::smooth_positive` magic radii → the canonical
  declared-radius form (**bit-identical formula**); double-only guard sites → ADL `is_finite`. Per strategy.
- **`decide` / `diagnostic` (P1d).** Value-branches (net-production sign, PPA layer index, `height_max`,
  leaf shut-down early-exits) → `decide`; dead `to_passive` reads → `diagnostic`. The commit-per-accepted-
  step wrapping (adaptive recording) and the `xad::value`/`to_passive` grep ban land wired into the SCM at P2a.
- **`register_implicit` (P1a), `incomplete_gamma` (P1c).** The TF24 leaf/soil deletions (FD seam, hand
  IFTs, hydraulic splines, `psi_soil_cache_`); apply at P2c. **`QK<S>` (P1f)** is plant's `qk.h`
  templating; applies at P2b.

- **P2a — K93** (simplest: closed-form rates, separable kernel, no inner solve). Uses P1b + P1e. Also the
  **CD-A/CD-G de-risk vehicle** (cheapest full SCM: growing dim + L2 recompute + census). Deletes
  `node.h::growth_rate_gradient`'s active block. Gate: FF16 bit-identity + the K93 census-FD targets
  (`b_0` 317.883, `b_1` −516.881, `cos=1.0`, `design.md` §10).
- **P2b — FF16** (adds crown quadrature = sub-grid field reads via the fixed-rule `QK<S>`, P1f; a
  breakpoint node for particle crossings). **PLANT-11:** fix the zero-height cohort NaN (`0·log(0)`) —
  establish `birth≥N` cohorts at `h0`; carries a test. Port FF16's transport term to `rebind` to inherit
  the shared mass chart (the census tier). **OPEN (2026-07-18): the FF16 R0 reverse gradient is WRONG**
  (FD gate: reverse ~ +440 vs FD plateau ~ −255) and the light-field representation is NOT the cause (the
  exact `separable_field` is FD-faithful but does not fix it — see the CD-G update above). The FD gate in
  `ff16_scm_gradient_driver.cpp` (asserted `expect_failure`) is the instrument to drive green.

  **Investigation (2026-07-18), narrowed but not yet root-caused.** Ruled OUT as the cause: the reverse
  tape itself (fwd==rev==wrong, so it is a *structural* derivative error present in BOTH AD modes, not a
  tape/adjoint bug); `QK::integrate` (correctly tapes the active crown bound + integrand; its `to_passive`
  are only the error/abs machinery); `assimilation_leaf` (clean Michaelis–Menten, no dropped derivative);
  the field read `optical_depth` (`dA/dz < 0` verified — taller ⇒ more light, correct sign). Gate-0
  (single plant, FIXED light) is FD-correct, so the untested channel is `d(·)/d(light)` — the self-shading
  FEEDBACK, exercised only in the coupled SCM. Characterised:
  - **Spline (committed) consistently UNDERSHOOTS ~40–50%** across a `max_patch_lifetime` sweep (L=35:
    AD −8.0 vs FD −16.0; L=50: −172 vs −256; same sign, ratio ~0.5–0.67 — a whole missing *channel*, not
    noise). The missing channel is the query-height self-shading feedback the fitted spline freezes (same
    physics as K93's 30× miss, milder for FF16 because growth is dominated by other terms).
  - **RESOLVED by channel isolation (the field IS the fix for the source channel; the query channel is
    the bug).** FF16 now reads the exact `separable_field` (double suites green, within tol). A
    `freeze_query` switch on the field read splits the two channels decisively:
    · field SOURCE-only (query derivative frozen): −172.5, 3.69, −7.29 — **reproduces the spline to the
      digit**, so the field's source self-shading derivative is CORRECT (the earlier "source-side error"
      guess was WRONG).
    · field FULL: +442.7, 38.3, 19.7 — wrong. So the ENTIRE error is the **query-height channel**, the
      new derivative the field adds over the spline (~ +615 for lma vs a true ~ −82).
  - **Self-shading-linkage hypothesis TESTED and REFUTED.** Freezing the focal cohort's own query
    contribution (value-preserving) made the gradient WORSE (+442 → +729). Decomposing: self-source query
    −287, cross query +902 — so the error is in the cross terms, not the focal self-term. Reverted.
  - **The field read is EXONERATED (proven).** `test-ad-ff16-field-crown.R` / `field_crown_probe.cpp`:
    the separable field's query derivative in the exact crown pattern (`z = node·H`, all source heights and
    weights scaling with the parameter as a single-species stand's cohorts do) matches a direct O(N²) sum
    AND finite differences to machine precision. The separable factoring is mathematically correct here, so
    the field read is NOT where the reverse gradient goes wrong. (The "frozen rank" suspect is also weak —
    cohorts leave the shading set exactly where their `Q(z/H)=Q(1)=0`, so no boundary term is dropped.)
  - **Transport, reproduction-weighting, establishment RULED OUT for offspring.** Census (which IS
    density-weighted) is wrong too, but that is the KNOWN dropped FF16 transport derivative (documented,
    deferred — census needs differentiable transport). Offspring does NOT route through the transported
    density: `weighted_fecundity = offspring_produced_survival_weighted · patch_density_at_birth · S_D`,
    where `patch_density_at_birth` is a birth-time double and the fecundity is an accumulated ODE state
    (node.h:96,208 — all `value_type`, no dropped derivative). Establishment reads light at the double
    `height_0`, so it carries no query derivative. `area_leaf_0` was tested (no effect).
  - **RESOLVED (2026-07-18) — the "truth" was misrepresented; the pinned-schedule FD is an ARTIFACT for
    FF16.** Oracle-consult §0 is the key: a value-exact gradient O(1) off FD means either a detached edge
    (JVP≡VJP can't see it) OR the FD re-adapts the schedule (dropped-schedule term). Running the Oracle's
    discriminating tests — a fully-adaptive, real-model R-level `run_scm` FD (T2, re-adapted schedule) vs
    the pinned-schedule FD (T1, frozen) — settles it:

    | | K93 `d(offspring)/d(b_0)` | FF16 `d(offspring)/d(lma)` |
    |---|---|---|
    | reverse AD (frozen schedule) | −0.11812 | +442 |
    | pinned-schedule FD (frozen)  | −0.11812 | −255 |
    | **adaptive FD (real model)** | **−0.11807** | **+4.2** |

    **K93: all three agree** — schedule-insensitive, no detached edge, genuinely correct. **FF16: all three
    disagree**, and the real (adaptive) gradient is **+4.2**, which neither the AD nor the pinned FD is near.
    FF16's R0 is a small net (+4.2) of large opposing terms (growth benefit vs self-shading cost); the
    record-once/replay-pinned method forces the perturbed dynamics onto the BASE schedule, and that
    schedule-mismatch error dwarfs the +4.2 signal. So the FD gate we built for FF16 was validating against
    a wrong target (−255), and the "field overshoot / detached edge / cross-shading query" narratives above
    were all chasing an artifact. The `separable_field` is correct (probe proves it); K93 is correct.
  - **The real issue is SCHEDULE SENSITIVITY, which is a declared scope fence** ("d(schedule)/dθ decided
    out — nuisance variable", Scope fences). It is negligible for K93 (robust gradient) but dominant for
    FF16.
  - **CHARACTERISATION across functionals (2026-07-19) — it is an FF16 DYNAMICS property, NOT a functional
    property.** The full matrix (AD frozen / pinned-FD / adaptive-FD real):

    | | AD | pinned-FD | adaptive-FD |
    |---|---|---|---|
    | K93 census `d/db_0`    | −490.9 | −491    | −489.9 |
    | K93 offspring `d/db_0` | −0.1181 | −0.1181 | −0.1181 |
    | FF16 census `d/dlma`   | +17.55 | −7.836  | **−0.64** |
    | FF16 offspring `d/dlma`| +442.7 | −254.9  | **+4.22** |

    K93 is uniformly schedule-INSENSITIVE (all three agree for BOTH functionals — every K93 gate is
    genuinely correct). FF16 is uniformly schedule-SENSITIVE (BOTH census and offspring show the spread;
    census does not route through reproduction yet is equally broken). So the sensitivity lives in FF16's
    trajectory on a fixed ODE schedule, and hits every emergent functional equally.
  - **This challenges option B.** Reformulating the *functional* cannot fix a *trajectory*-level property
    (census and offspring are affected identically). The fix must be at the schedule/dynamics level.
  - **L0 (node-introduction schedule) RESOLUTION tested and RULED OUT (2026-07-19).** Hypothesis: resolve
    the node schedule first (refine_schedule, 113→137 nodes) and use it as the basis of the frozen replay.
    Result: the frozen FD on the *resolved* L0 (with the resolved 238-step L1 recorded on top) still gives
    **−255**, identical to the default-L0 frozen FD. So the fragility is entirely **L1 (the adaptive RK
    step schedule)**, not L0. It is also not L1 under-resolution — the recorded L1 IS the resolved
    (adaptive) schedule; pinning it *at all*, at any resolution FF16 survives, is fragile. Only re-adapting
    L1 per perturbation recovers the real +4.2.
  - **The "detached edge" DISSOLVED (2026-07-19) — there is none; the AD is faithful.** Isolation probes
    (`ff16_single_rate_probe.cpp`, `ff16_feedback_probe.cpp`): (a) a single FF16 plant in fixed light has an
    EXACT `d(growth)/d(lma)` (AD == FD to 6 digits, every height); (b) ONE `compute_rates` + field assembly
    on a frozen multi-cohort state is EXACT (AD == FD to 6 digits), and `d(light)/d(lma)` through the frozen
    field is exactly 0 in both AD and FD (field assembly clean). Since the per-step computation is exact and
    the RK stepper is a linear stage combination (exact derivative), the reverse AD faithfully computes the
    frozen-schedule gradient (+442). The earlier "AD +442 ≠ pinned-FD −255 → detached edge" was a mirage:
    the pinned-FD is an IMPERFECTLY-frozen reference (pinning the ODE times does not freeze the
    node-establishment structure, which still re-adapts under perturbation), compounded by a stride bug
    (`rates[k*5]` vs the true `Node::ode_size()==7`) in an interim probe. So there is **no engine bug** for
    FF16.
  - **ROOT CAUSE (2026-07-19) — NOT schedule sensitivity; a WRONG replay schedule (a design flaw).**
    "Schedule sensitivity" and "option B" (above) are SUPERSEDED. The user's challenge ("a resolved
    schedule cannot have latent sensitivity") is correct. Data: pin the replay to the SOLVER-OWNED resolved
    schedule (`SCM::r_ode_times()` == `solver.times()`, what `run_scm(use_ode_times=TRUE)` uses) and the
    frozen R0(lma) tracks the adaptive curve to ~1e-5 with slope **+4.2** — i.e. no sensitivity, matching
    the adaptive model. The whole −255/+442 saga came from the standalone drivers pinning to
    `patch.step_history` (227 vs 230 entries; scm.h:347) — the LEGACY `run_mutant`/`save_RK45_cache` record,
    NOT the resident replay schedule. Pinning to `step_history` → −255; pinning to `r_ode_times()` → +4.2.
    So there is no schedule sensitivity, no detached edge, no need for option B, and no model bug: the AD is
    correct when replayed on the right (solver-owned) schedule.

  **CORRECTION (2026-07-19, later — supersedes the ROOT CAUSE block above).** The claim that pinning
  `r_ode_times()` yields `+4.2` was REFUTED by direct measurement. Two corrected facts (verified in double
  at R level, then in the C++ driver): (1) **No schedule sensitivity** — a frozen replay on the RESOLVED
  schedule (BOTH L0 `node_schedule_times` AND L1 `ode_times` from `run_scm(refine_schedule=TRUE)`) gives
  `+4.24`, matching the adaptive `+4.2`. `r_ode_times()` is the correct L1 *source* but NOT sufficient:
  the old drivers pinned only L1 onto the DEFAULT (unrefined) L0 — an inconsistent schedule, value-correct
  but derivative-wrong. (2) **An open reverse-AD dropped-derivative bug remains, schedule-independent**:
  on the identical resolved schedule, AD `≠` FD (metric=2 pure growth, life 40: AD `−6299` vs FD `−1630`),
  δ-independent (not a kink), forward AD == reverse AD (a structural code-derivative error, not a tape
  bug), `freeze_query`-irrelevant, coupling-only (single-plant fixed-light is exact). It lives in FF16's
  self-shading light→growth feedback — a dropped `to_passive` term FD sees through, not yet pinned to a
  line. Tape memory limits reverse AD to ~life 40 (life 50 OOMs; checkpointing deferred). The FF16 driver
  now replays the resolved schedule (passed from R) and its test gates value-exact + AD≠FD `expect_failure`
  at life 40. See `docs/HANDOFF.md` PART 2 for the full corrected write-up and next steps.

  **DESIGN (2026-07-19, system-design skill; Tier 2; floor wins) — one solver-owned schedule; retire the
  legacy path; gradients map onto the run workflow.** (Still valid and ORTHOGONAL to the open adjoint bug;
  the run-shaped entry must own refine→resolved-replay, which would have prevented the default-L0 saga.)

  *Architecture (grounded in the code, 2026-07-19; diffed vs odelia `master`).* odelia's AD engine is a
  ~28-commit branch (`claude/odelia-ad-tape-reverse-496fuf`, NOT merged to master — co-developed on this
  feature branch, installed and kept synced with plant per odelia/AGENTS). It is the substantial documented
  surface: the gradient driver (`compute_jacobian`/`gradient`/`jvp`), `separable_field`, `implicit_node`,
  `incomplete_gamma`, `decide`/value-guards, `mass_transport`, `supplied_derivative`, RODAS, and the Solver
  L1 record/replay (`advance_adaptive` records `solver.times()`/`recorded_steps()`, `advance_fixed`
  replays; `set_schedule()`/`run()` for the simple-System case). **AUTODIFF.md states the invariant the
  design relies on: `recorded_steps()` is the SINGLE source of the replay grid, so it "can't go
  inconsistent," guarded by one forgot-to-record check.** Plant's SCM HAS-A that Solver but **overrides the simple `run()`** with its own
  segmenting loop (`run_next_impl`: `advance_adaptive` to each introduction, `advance_fixed` on replay),
  and does L1 replay through its OWN `NodeSchedule.use_ode_times`. **This is where plant BROKE odelia's
  single-source invariant:** it introduced a SECOND replay-grid source, so the grid the odelia design
  guarantees "can't go inconsistent" now can. The **correct** L1 schedule is `SCM::r_ode_times()` ==
  `solver.times()` (scm.h:512, what `run_scm(use_ode_times=TRUE)` replays — the +4.2 path);
  `patch.step_history` is the SEPARATE `save_RK45_cache`/`run_mutant` L3 record (control.h:97, scm.h:347).
  **The correct resident record→replay ALREADY EXISTS and works** (run adaptive → capture `ode_times` →
  `run_scm(use_ode_times)`); the defect is that the standalone gradient drivers, given two sources,
  reimplemented replay by pinning `step_history` instead of reusing `r_ode_times()` — a bad replay the
  odelia workflow was designed to make impossible, only reachable because plant bypassed it. And there is **no
  SCM/R gradient entry at all** — `compute_gradient`/`DifferentiationTargets` appear only in the test
  drivers, so every gradient is a ~200-line bespoke driver (R2).

  Ledger: R1 a gradient is correct and a caller CANNOT select a wrong replay schedule (the failure was 60×
  wrong); R2 adding a gradient maps onto `run_scm` (bespoke driver → functional + one run-shaped call); R3
  the L1 schedule is the solver-recorded `r_ode_times()`, not a hand-set grid; R4 retire
  `save_RK45_cache`/`step_history`/`environment_history` to the deferred mutant path. Scarce resource:
  correctness of the replay schedule. **Floor (wins — mostly reuse + deletion, no new abstraction):** the
  gradient path reuses the SCM's existing (correct) adaptive-record → `use_ode_times`-replay coordination
  fed from `r_ode_times()`; a run-shaped gradient entry (a C++ `SCM` method + an R `run_scm` mode) owns that
  record→replay and takes a functional, so a caller never hands in a schedule; `step_history` is not on the
  resident/gradient path. **Commitment:** the resident replay schedule is produced ONLY by the adaptive
  run (`solver.times()`); a caller cannot express a replay grid, so cannot express a wrong one — kept true
  by the entry owning record→replay (no `ode_times`/`step_history` setter reachable from the gradient
  path). **Makes hard:** mutant (invasion) gradients (need the L3 `environment_history` that rode
  `save_RK45_cache`) — already deferred; they get their own recorder when un-deferred. **Kill condition:**
  mutant gradients become near-term → "one resident recording" gains a separate mutant recorder. Build
  deferred to user direction.
  - **A latent secondary bug, TESTED and RULED OUT for R0**: `area_leaf_0 = area_leaf(height_0)` with
    `height_0` a plain `double` (ff16_strategy.h:764/830) drops the birth-height-shift derivative `dh₀/dθ`
    that `initial_height_` (line 765) carries via the IFT lift. Rebuilding with `area_leaf(initial_height_)`
    (bit-identical value) left the R0 gradient identical to the digit (−172.54, 3.69, −7.29), so the
    seedling/establishment channel is NOT the ~40% undershoot — reverted (no earned win). Worth revisiting
    for the census functional, but it is not this bug.
  - **Next**: build a channel-isolation harness (feedback-severed reverse vs a frozen-to-base double FD via
    the double↔double mutant/`environment_history` path) to attribute the error per channel, then fix the
    field source-derivative (new_node boundary + `M`) and `area_leaf_0`. The lifetime sweep + per-trait
    ratios are the running signature to watch.
- **P2c — TF24** (the hard one; re-reaches #52 soil coupling). Leaf **residual** (the already-templated
  `assim_colimited_ad`/`hydraulic_cost_ad`) drives the reduced-gradient `G(q)` via N1/N3 as P1a
  scalar-IFT nodes — the **leaf solver stays `double`**, the engine auto-differentiates the residual (no
  per-trait hand `∂profit/∂θ`, the prototype's AD-9 body of work, deleted). `incomplete_gamma` via P1c. **Soil is active
  coupled state** (the leaf reads the soil state directly), not a field: resident soil integrates on the multirate sub-cycle
  (its adjoint rides tape-as-run); the `∂profit/∂(soil ψ)` channel is automatic. Deletes the ~150-line FD
  seam + `dsoil_consumption_dpsi_collar_perlayer`. Gate: `test-ad-gate0-tf24.R`,
  `test-ad-tf24-soil-coupling.R`, `test-ad-tf24f-collar-uptake.R` (all currently green — the parity
  target). Long-horizon resident stiffness held by the drift gate + recorded sub-stepping (below).
- **P2d — TF24f** (tracked-`q`). `q` an ODE state, rate `k·G` reusing P2c's `G`. Completes #52 parity.

**PLANT-4a (the resident-recompute correctness point):** the resident gradient must **re-run
`compute_environment` on the recorded L2 light-spline knots** with active cohorts (L2 recompute, L3
empty). Do **not** read the frozen field (that is the mutant/L3 path — silently the invasion gradient,
missing self-shading) and do **not** build a `stand_*_stage_history`. **PLANT-10:**
`d(net_reproduction_ratio)/d(birth_rate)` for the `R0=1` Newton solve (Rung 3; depends on PLANT-4a; feeds
Phase 3). **IC gradients** (`Patch::ad_initial_state`, ledger E) land after P2a's resident core — sequence
them once the L2 recompute path is solid; remove the `scm.h:231` resume stub as the IC path lands.

**Critical path to #52 parity (reassessed):** (F1/E2 done; CD-A verified; **all Phase-1 primitives
landed**) → **[decide the plant base]** → **P2a/CD-G (K93 resident census — the first visible win +
integration fixture)** → **P2b (FF16, +P1f)** → **P2c (TF24, applies P1a+P1c)** → **P2d (TF24f)**.
IC-seeding on IndividualRunner sequences after P2a's resident core. **The next gate is the plant-base
decision** (#52 vs develop vs earlier), not any further odelia primitive.

## Multirate soil — OUT OF THIS PLAN (pursued independently)
The multirate sub-cycle for the ≤5-state soil block (E2: kink-split at recorded rainfall knots; the
desingularizing coordinate dropped) is **owned by the user and pursued independently** — it is not a
task in this plan and nothing here waits on it. The AD engine neither depends on nor blocks it: resident
TF24 soil coupling (odelia #3) is correct on the shared global step; multirate is a *forward performance*
lift. **The one contract, if it later lands:** keep the soil micro-schedule / kink-splits recorded in
pass 1 and replayed frozen in pass 2 (the "recorded adaptive sub-stepping" shape), so the AD engine can
tape-as-run it with no new adjoint theory. Until then, long-horizon resident-TF24 stiffness is held by
the `tf24_stiffness_drift` **drift gate + runtime caveat** (bounded ~1e-4…1e-3 — a runtime cost, gated,
not a wrong number).

## Phase 3 — the fixed-point / equilibrium layer (secondary, deferred)
Gated on F1 (passed). The steady Eulerian-profile BVP (dim ~4+L) + IFT adjoint of the collocation
residual + the dominant-eigenvalue perturbation identity (one nested `adj⟨fwd⟩` sweep). Reuses the P1a
implicit-node + P1c `incomplete_gamma`'s **reserved** higher-order partials (`∂²γ/∂s²`, differentiated-IFT) —
additive registrations, not a rewrite. TF24f adds one `q`-state pinned by `G=0`, contributing the
`k·dG/dq` relaxation eigenvalue. Serves regnans' selection gradients + the `R0=1` equilibrium. Validate
against FD of the residual-solved equilibrium, **never** a re-march. Honesty conditions: monitor the
spectral gap, the marginally-active pinned set, and the hydraulic-failure cliff — **refuse**, don't
average through.

## Port map — what the new engine deletes/replaces
Symbolic anchors (base commit TBD — see the Phase 2 note). Line counts are the #52-prototype's, indicative.
| current plant site | fate | replacement |
|---|---|---|
| `node.h::growth_rate_gradient` active block (~70 ln) | **delete** | mass chart (compression vanishes) + `separable_field` `∂A/∂z` |
| `species.h` geometric-compression loop | **absorb** | the mass transport rule |
| `tf24_strategy.cpp` FD `supplied_derivative` seam (~150 ln) + `leaf_profit_at_fixed_collar` | **delete** | reduced-gradient `G(q)` via P1a nodes (N1, N3) |
| `leaf_model.cpp::dprofit_droot_collar_psi` (hand IFT) | **delete** | falls out of N1+N3 |
| `leaf_model.cpp::dsoil_consumption_dpsi_collar_perlayer` + FD uptake partials | **delete** | `incomplete_gamma` antiderivative difference + breakpoint (Leibniz) |
| interpolator on the coupling path | **replace (separable) / retain (fallback)** | `separable_field`; interpolator kept for `FlatTopSoftBox` |
| `get_environment_slope_at_height` frozen surrogate | **delete** | exact `∂A/∂z` from `separable_field` |
| 13 plant headers `#include <XAD/…>` | **reduce to one** | `<odelia/seam.hpp>` |
| scattered `to_passive` (77) | **replace where derivative-relevant** | `decide()`/`diagnostic()` firewall |
| `Solver::reserve_state` | **delete** | unused; growth correct via XAD slot indirection |

## Scope fences (do not silently re-scope in)
The introduction-schedule derivative `d(schedule)/dθ` (decided out — nuisance variable); general
HVP/Hessian (only the fixed-point eigenvalue path); Euler stepping and the stochastic engine
(non-differentiable); the hyperpar trait→param total derivative (v1 gives low-level partials);
leaf-level forward-mode stays plant-local. **In scope, sequenced:** IC gradients; resident TF24/TF24f
soil (via multirate). See `design.md` §11.

## Open before Phase 1 hardens
- **CD-G** (the integration fixture: active ICs × multi-species resize × census over the growing set) —
  the remaining growing-dimension work now that CD-A's mechanism is verified; on K93-resident.
- The `incomplete_gamma` `∂/∂s` implementation vs FD-fallback (P1c) — low-stakes, decide at build.
- Whether the mass chart is the *default* for gradient runs or stays opt-in (re-baseline the K93 ~0.169% snapshots if default).
- Which of the four leaf early-exits produces the hydraulic-failure cliff (isolate before Phase 3).
- The `∂profit/∂(soil ψ)` channel wiring for resident TF24 (automatic via `u()`, but verify at Gate-0).
