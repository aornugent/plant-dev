# TF24 multirate engine — port specification (read this first)

**Purpose.** This is the authoritative, self-contained build spec for porting the TF24 soil multirate
integrator into the odelia engine, **beyond prototypes**. Every design choice below is forced by a
measurement (all reproduced in `scripts/tf24-multirate/`), refined by four Oracle rounds, and recorded
so the port can proceed without the prototyping context. If you are picking this up cold, read §1 (map),
§2 (design in one page), §4–§6 (what to build), then §8 (build order).

Status at freeze: **numerics settled, all load-bearing claims measured; nothing gates the design.**
Remaining is the engine port itself + the plant-side exposures (§6, tracked in the plant issue).

**Port progress (odelia branch `claude/tf24-multirate-engine`, off master `c9ae31b`):**
- ✅ **Slice 1 — MRI skeleton + toy (forward).** `inst/include/odelia/mri.hpp` (`MRICoupling` + tables
  incl. MRI-GARK-ERK33a; `mri_macro_step`/`mri_advance`; `FastLeg` — the fast block presented as a plain
  System so the existing `SolverInternal` sub-cycles it, no parallel RK). `inst/include/examples/two_rate_system.hpp`
  (scalable demonstrator). `src/mri_interface.cpp`, `tests/testthat/test-example-two-rate.R`. Gates: outer
  ERK order (2/3/3), resolved coupling order (ERK33a→3), stiff consistency, fast-cost flat in M.
- ✅ **Slice 2 — reverse mode by record→replay.** Macro step templated on the scalar; one record-or-replay
  fast-leg driver (`if constexpr` guards the double-only adaptive branch); `MRISchedule`. `two_rate_gradient`
  in the interface. Gate: adjoint = frozen-schedule FD ~1e-9 across k; eps-independent.
- ✅ **Slice 3 — optional splitting inner (ROS34PW2).** `inst/include/odelia/rosenbrock.hpp` (ROS34PW2,
  verified order 3 + L-stable). The inner sub-cycle is a **policy** (`AdaptiveSubcycle` default,
  `SplitSubcycle` opt-in) threaded through `mri_advance`; `subcycle_split` does Strang(exact `analytic_flow`,
  ROS34PW2 `residual_rhs`, flow). `examples/drainage_system.hpp` (stiff power-law drainage + closed-form
  recession, TF24-shaped) is the A/B subject: **~6× fewer fast steps at matched accuracy, flat as drainage
  stiffness grows 1000×**, positivity preserved. Splitting is opt-in (only compiles for models with the
  hooks) so the same model runs both ways — this is the harness for measuring the plant#53 exposure impact.
  Reverse mode *through* the split inner is done too: `ros34pw2_step` templated on the scalar with a
  **passive value-Jacobian** + double-matrix/active-rhs solve; `drainage_gradient_split` matches
  frozen-schedule FD ~1e-9 (exact because the drainage residual is linear in u — a nonlinear residual
  would differ by the omitted ∂J terms, the intended W-property approximation / §9 open item).
- ⏳ **Slice 4 — TF24/TF24f in plant** (needs aornugent/plant#53), then full-patch MRI-vs-RK45 + the split-vs-unsplit A/B on the real soil.

odelia PR: aornugent/odelia#45 (`claude/tf24-multirate-engine`).

**Boundary refinement (vs §4.4/§4.5 below):** collocation and the control-block collapse are **model**
concerns (how TF24 implements `aggregate`/`fast_rates`), **not** engine machinery. odelia stays
model-agnostic: the MRI skeleton, inner steppers, and record→replay tape. A multirate System = a plain
odelia System **+** `{fast_size, slow_rates, fast_rates, aggregate}` (`aggregate` linear-homogeneous).

---

## 1. Map — where everything is

**Docs (read in this order):**
1. `tf24-rodas-multirate.md` / aornugent/odelia#43 (OP) — RODAS is accuracy-limited & O(N³); multirate is the fix.
2. `tf24-multirate-implementation-plan.md` — the MRI-GARK plan + forward draft (mri_core.hpp).
3. `tf24-multirate-real-patch-results.md` — the real-patch benchmark; the coupling is the crux.
4. `tf24-multirate-factoring-probe.md` — cost is the per-cohort physiology, not the light field; no cheap uptake surrogate.
5. `oracle-consultation-{multirate-update,multirate-followon,commit-review}{,-response}.md` — the four Oracle rounds; the design re-derived from the cost structure.
6. `oracle-consultation-multirate-followon-response.md` §E1–E4 — the go/no-go measurements.
7. `tf24-reformulations-evaluation.md` — R1 (exact drainage flow) + R5 (batch); R2–R4 deferred.
8. `oracle-consultation-h0-missive.md` — the open envelope-collapse question (future models).
9. **this doc** — the consolidated port spec.

**Key scripts (prototypes; the engine reimplements these in C++).** ⚠ **All of `scripts/tf24-multirate/`
is throwaway scaffolding — SAFE TO DELETE once the engine port lands and its own tests reproduce these
results.** See [`scripts/tf24-multirate/README.md`](../scripts/tf24-multirate/README.md) for the manifest
(each artifact → the spec claim it backs, and the ★ reuse-candidates: `mri_core.hpp`, `mri_ad.hpp`,
`e4_fast_ad.cpp`). The durable record is this `docs/` set + aornugent/odelia#43; nothing in production
depends on the scaffolding.
`mri_core.hpp` (MRI tables + macro step, collapse+order verified) · `mri_ad.hpp`/`mri_ad_runner.cpp`
(two-level record→replay reverse mode) · `bench_real_patch.R`+`real_patch_probe.R` (real-patch premise +
global-vs-multirate) · `factor_probe{,2,3}.R` (cost decomposition, surrogate refutation) ·
`e1_setup_decomp.R`/`e1_continuation.R` (setup cacheable, tracked-q vs optimise) · `e2_collocation.R`
(m-member convergence) · `e2_e3_patch.R` (tracked-q reproduces QSS soil, no plateau) · `e4_fast_ad.cpp`+
`e4_test.R`+`e4_bias_test.R` (reverse-mode certification + gradient-reduction-bias) · `h0_envelope_check.R`
· `r1_drainage_flow_check.R` (exact drainage recession).

**Issues:** aornugent/odelia#43 (the design synthesis, public record) · aornugent/plant#53 (plant-side R1 + coupling seams; body in `docs/plant-issue-R1-exposure.md`). **Branch:** `claude/tf24-multi-rate-stepper-n5audm` (plant-dev); odelia study branch
`tf24-multirate-study`.

**Build environment (measured-good):** odelia@master (`c9ae31b`) + plant@develop (`141dc8df`, includes
traitecoevo/plant#554 NSC fix). XAD tape available in odelia@master. `cd plant && make` after
`R CMD INSTALL odelia`.

---

## 2. The design in one page (forced by the measurements)

Integrate the TF24 patch with a **multirate-infinitesimal (MRI-GARK-ERK) skeleton**: outer ERK on the
slow block (cohort geometry + light field), each stage-transition a short inner IVP on the **fast
block**, component partition, **macro grid aligned to the daily rainfall kinks**.

The **fast block is `(u ∈ ℝ^L, control state)`**, `L ≤ 5` soil states. The cohort→soil coupling
(per-layer root uptake `a`) is evaluated **exactly and continuously** in the sub-cycle — it cannot be
frozen or surrogated in `u` (measured). Two compressions make the exact coupling cheap:
- **Collocation over cohorts:** `a_ℓ = Σ_{n=1}^m W_n c_ℓ(x̂_n, u, p̂_n)`, `m ≈ 15–20 ≪ N` (O(m⁻²)→
  piecewise-Chebyshev for spectral; §5-B3).
- **Tracked controls:** the per-cohort collar-potential optimisation is a differential state
  `ṗ = k·∂P/∂p` (= TF24f), evaluate-not-optimise; **collapse to ~1 shared control** + closed-form
  per-node correction (§5-B1).

**Micro-stepper: ROS34PW2 (Rosenbrock-W)** on the `(L+control)` system, with **R1 operator-splitting**:
the gravitational drainage (a closed-form power-law recession) is integrated **exactly** (Strang),
leaving the micro-stepper only the gentle coupling. Per-cohort **feasibility clamp** on the control is an
active event.

**Reverse mode:** two-level **record→replay** — a `double` adaptive pass records the micro schedule; an
active pass replays it fixed-step so the tape is the exact discrete adjoint. Argmax off-tape
(initialisation only); collocation weights active, node placement passive, W-Jacobian passive.
**Certified:** adjoint = frozen-record FD to ~1e-8 across k, m (§7).

Config defaults: daily macro grid; MRI-GARK-ERK33a; m≈15–20; `k_acclim≈20`; ROS34PW2 inner; smooth-floor
near the residual bound; checkpoint at macro boundaries.

---

## 3. The forced-choice chain (why this and not something else)

| choice | forced by (measured) |
|---|---|
| Multirate, not global-implicit | Step collapse accuracy-limited (RK45 flat over 3000× stiffness); RODAS 5× slower, global dense RODAS O(N³) 470× slower |
| Fast block = the ≤5 soil states | ~300× timescale separation on the real patch (`∂θ̇/∂θ ≈ 343/day`) |
| Coupling evaluated exactly & continuously | Freezing/periodic-refresh **plateaus** at fixed error (held `a` = wrong fast system); surrogates in `u` refuted (linear 3–4× rel; separable 0.06–0.76 abs) |
| Cost lever = collocate over cohorts | Per-cohort physiology dominates (95–100%, scales with N); light field cheap/flat. Aggregate converges O(m⁻²), m≈15–20 → <0.5% |
| Control = tracked (TF24f), not re-optimised in loop | Warm-start Newton on argmax fragile (diverges to bound); tracked reproduces QSS to <1e-3, no plateau; better-posed near the bound |
| Micro-stepper Rosenbrock-W + R1 split | Wet-end drainage stiff (`dK/dθ` large); R1 integrates the drainage recession exactly (closed form, ~1e-13), removing the stiffness *and* the positivity clamp |
| Reverse = two-level record→replay | Tape of scheme-as-run = exact discrete adjoint; reductions (k lag, m quad) don't amplify in the gradient |

---

## 4. odelia components to build

The engine is **model-agnostic**; it consumes plant through the seams in §6. Build, in odelia:

**4.1 MRICoupling + MRIStepper (Layer-N orchestration).** Port `mri_core.hpp`: coupling tables (`c`,
`Γ^{(k)}`), `mri_macro_step`, collapse-identity + order gates (`test_mri.cpp`). Table: **MRI-GARK-ERK33a**
default, ERK45a optional. Diff-test against ARKODE MRIStep. **Macro grid = the daily forcing-kink grid**
(a hard requirement — legs must not straddle rainfall kinks; measured: H>1 negates high order).

**4.2 InnerStepper seam.** A `MRIStepInnerStepper`-shaped interface the macro step drives over each leg.
Two concrete inners, both behind the seam:
- (default, generic) black-box adaptive RK on the fast block;
- **(R1, the target) a splitting inner stepper** — see 4.3.

**4.3 R1 splitting inner stepper (folded into the plan).** Over each leg, integrate the fast block by
**Strang composition**:
```
½ step: exact flow of the model's declared analytic partial-flow   (drainage recession; §6-R1)
1  step: ROS34PW2 on the residual coupling RHS  (infiltration + inter-layer cascade + uptake + control)
½ step: exact flow again
```
- The **exact-flow map is supplied by the model** (§6): the stepper calls `System::analytic_partial_flow(u, Δt)`
  and `System::residual_rhs(u, …)`; it does **not** know the closed form. If a model doesn't provide the
  flow, the seam falls back to the black-box inner (4.2) — R1 is opt-in per model.
- The residual step is ROS34PW2 (Rosenbrock-W): L-stable, stiffly accurate, valid for the semi-explicit
  index-1 form the control block takes; embedded pair for pass-1 error control. Approximate Jacobian OK
  (W-property) → recorded **passive** on the tape. Jacobian arrow structure
  `[[∂(b−a)/∂u, −W·∂c/∂p̂],[k·∂G/∂u, k·diag(P_pp)]]`; eliminate the diagonal control block scalar-wise,
  solve the L×L Schur complement; store pass-1 factorisation pieces so pass-2 adjoint is transposed
  backsolves with recorded matrices (no refactorisation).
- **Events:** the analytic touchdown to the residual bound is a closed-form root of the recession
  (§6-R1); the control feasibility clamp is a projected-gradient-flow event (touch/pin/release), located
  on the ROS dense output (pass-1 bracket passive, pass-2 active scalar-IFT root so the substep length is
  active — carries the Leibniz adjoint term automatically). **Guard transversality** (assert `|dg/dt|`
  not small at any located event — grazing silently blows up the adjoint).

**4.4 Collocation aggregate.** Consume the model's factored coupling at `m` collocation nodes:
`a_ℓ(u) = Σ_n W_n c_ℓ(x̂_n, u, p̂_n)`. **Piecewise-Chebyshev (barycentric)** nodes per smooth piece;
weights `W_n = Σ_j ℓ_n(x_j) w_j` **active** in the member coordinates, built once per leg (pass-1);
node placement **passive** (pass-1 chosen, replayed, FD-injected). **Free anchored defect correction:**
the full-M aggregate is computed anyway at each macro stage → record `Δ = a_full − a_colloc` at the stage
and use `a := a_colloc(u) + Δ` across the leg (Δ constant in `u` → fast Jacobian untouched). Monitor
`Σ|W_n|/|ΣW_n|` (Lebesgue proxy).

**4.5 Control block.** Carry the tracked control(s) as fast states. **Collapse to ~1 shared control**
`p̄` with `ṗ̄ = k·Σ_n ω_n G(p̄;x̂_n,u)` and per-node correction
`p̂_n = clamp(p̄ − G/P_pp)` using the exact `P_pp` (§5-B1); degeneracy guard switches a node to a per-node
tracked state near the bound (pass-1 recorded decision, replayed passive). **k fixed at the knee
(`≈20`), never adapted** (§5-B2). Keep the argmax variant (TF24 re-optimise) and the index-1 DAE limit
(k→∞) as documented alternatives behind the same seam.

**4.6 Two-level record→replay tape.** Pass 1: `double` adaptive, records per-leg micro schedules, event
brackets, node placement, W-Jacobian factorisation pieces, all micro states (kB/episode). Pass 2:
fixed-step active replay = exact discrete adjoint; passive-record contract in §5-D6/§7. Checkpoint
canonical `(x,u)` + records at macro boundaries; pass-2 re-record is solve-free.

---

## 5. Oracle amendments (fold into the build)

- **B1 — collapse the control block** from m states to ~1 shared + closed-form correction (4.5). Biggest
  perf win; sizing measurement: spread `max_n|p*_n − p̄*|` + `P_pp` margin (do on real cohorts at build).
- **B2 — k is a regularised index-1 DAE knob.** Fix at the measured knee; DAE (k→∞) is the exactness
  escape hatch, not a tuning direction.
- **B3 — quadrature:** piecewise-Chebyshev + anchored defect correction (4.4). **Footgun:** adjoint=FD
  certifies consistency, *not* reduction accuracy — add **gradient-vs-m and gradient-vs-k Richardson
  checks** vs a full-M/small-lag reference to the harness (see §7; `e4_bias_test.R` shows a hard member
  kink breaks it and smoothing restores it).
- **D4 — methods/refs:** MRI-GARK-ERK33a (Sandu SINUM 2019; MIS: Wensch–Knoth–Galant BIT 2009; H-Tol:
  Fish & Reynolds; ARKODE MRIStep). ROS34PW2 (Rang & Angermann ~2005); ROS3PRw (Rang ~2015) if
  order-reduction shows.
- **D5 — elegant vs naive:** per-leg pass-1 node/weight construction; k fixed; setup cache identity-keyed
  per (leg,node) not value-keyed; checkpoints kB/episode; align member insertion to macro boundaries.
- **D6 — footguns:** (1) gradient-reduction bias → Richardson checks; (2) kink-crossing quad error whose
  u-derivative oscillates → model-level smoothing; (3) clamp chattering → pass-1 hysteresis; (4) grazing
  events → hard transversality assert; (5) two clocks (kinks in t, polys in τ) → never straddle a kink;
  (6) `1/P_pp` divisions → sign-definiteness assert + recorded hybrid switch; (7) argmax-off-tape init
  layer `O(e^{−kt})` → doc it (irrelevant at production T).

---

## 6. plant-side exposures (the model↔engine seam) — filed as aornugent/plant#53 (body in `docs/plant-issue-R1-exposure.md`)

The engine consumes plant through these. **R1 is the headline; the others are the coupling factoring.**

- **R1 (analytic drainage split) [primary of the plant issue]:** expose the TF24 soil RHS as
  `{analytic_partial_flow(u,Δt)} + {residual_rhs(u, uptake, t)}`. The drainage
  `K(θ)=K_sat(θ/θ_sat)^{2n_ψ+3}` per layer has the closed-form recession
  `θ(t)=[θ0^{1−p}+(p−1)c·Δt]^{−1/(p−1)}`, `p=2n_ψ+3`, `c=K_sat/(dz·θ_sat^p)` (verified ~1e-13,
  positivity-preserving). Also expose the analytic **touchdown time** to `θ_res`. Standalone value:
  helps single-rate soil integration too (land it first).
- **Factored coupling (`StateView.u()`):** the per-layer uptake `c_ℓ(cohort, θ, control)` evaluable at an
  arbitrary cohort given the leg-frozen light field, at `m` collocation cohorts — not only as the full-N
  aggregate. This is the fast/slow factoring the engine's collocation consumes.
- **Control acquisition at the nodes:** TF24f already tracks `q` (`dq/dt=k·dprofit`, exact IFT
  `dprofit_droot_collar_psi`, `k_acclim` settable) — reuse it; TF24 re-optimises (`find_root_collar_psi`).
  Expose `∂P/∂p` (have it) and `∂²P/∂p²` (P_pp, for B1/B2/Schur — closed-form via the same IFT).
- **Per-cohort feasibility clamp** of the control as an event (production `evaluate_root_collar_psi`
  already clamps to the feasible interval — expose it as an event predicate).
- **R5 batched physiology kernel:** the m per-cohort solves are data-parallel → SoA/SIMD batch kernel;
  pass-1 runs in `double`. Orthogonal plant optimisation, helps every caller.
- **Setup cache seam:** the θ-independent per-cohort setup (temperature/photosynthesis Arrhenius,
  electron transport at frozen PPFD) is already memoised — expose a "recompute only the θ-dependent
  soil-side part" entry so the micro-RHS pays only the cheap part per step.

---

## 6b. TF24 patch multirate adapter (designed; the next build)

The odelia `method="mri"` surface is ready (§8 step 2). To run it on the real patch, plant needs a
multirate **System** — a `MultiratePatch<T,E>` adapter wrapping `Patch<T,E>`, selected switchably (a new
runner / "TF24split" path; production TF24 untouched). The map that fixes the design:

- The Solver drives **`Patch<T,E>`** (scm.h). State layout is **`[cohort states | soil θ (L) | 4 aux]`** —
  cohorts first, the environment (soil+aux) block **contiguous at the tail** (patch.h `ode_state`
  = species then environment).
- Per-layer uptake `resource_depletion` is assembled in `Patch::compute_rates` (sum over cohorts'
  `consumption_rate(i)`) and **is a function of θ** (each cohort's `leaf.soil_consumption_` comes from
  `psi_soil(θ)`); re-running `compute_rates` at a new θ re-evaluates it.
- The **light spline is frozen per step** (rebuilt only in `compute_environment`, from `set_ode_state`),
  so cohorts+light can be held while θ varies.

**Adapter design (no odelia change beyond the `freeze_slow` hook, already added):**
- Fast block = the environment block (soil θ + aux); slow block = cohorts. `coupling_size = 0` — the fast
  rates read the **frozen Patch** (cohorts+light), not a linear aggregate `g`.
- Present **soil-first** to odelia: `ode_state`/`set_ode_state` gather/scatter between the odelia view
  `[soil | cohorts]` and the inner Patch `[cohorts | soil]`. (Keeps `MriStep` fast-first — no engine change.)
- `freeze_slow(x_cohorts)`: set the inner Patch cohorts from x, `compute_environment` (rebuild light) once
  per leg. `fast_rates(u_soil)`: set the soil block = u, `compute_rates` (re-eval uptake at θ from the
  frozen cohorts+light), extract the soil rates. `slow_rates(x,u)`: full patch RHS, extract cohort rates.
- Correctness first with **full-N uptake** in `fast_rates` (so the A/B runs; each fast step ≈ a full patch
  RHS, so MRI is *correct + stable* but not yet *faster*). The cost win needs plant#53 items 4+
  (collocation → uptake at m cohorts). R1 split vs unsplit is measurable immediately (soil stiffness).
- Wiring: a new `OdeRunner`-style RcppR6 binding `Solver<MultiratePatch<TF24,TF24_Env>>` + `method="mri"`;
  test: MRI vs `rkck`/`rodas` on a real patch (correctness + stability at the daily macro grid), then the
  split-vs-unsplit and MRI-vs-RK45 A/B.

## 7. Measured evidence (do not re-derive)

- **Premise:** soil ~300× faster (`real_patch_probe.R`). Cheap soil RHS reproduces patch soil deriv to
  machine precision given uptake (`bench_real_patch.R`).
- **Cost:** per-cohort physiology 95–100% of a patch RHS, scales with N; light field 2–30%, flat
  (`factor_probe.R`, `e1_setup_decomp.R`). Setup cacheable (flat in vuln-ctrl & layers).
- **Surrogate-in-u refuted:** linear rel 3–4×, separable nonlinear abs 0.06–0.76 (`factor_probe2/3.R`).
- **Collocation:** O(m⁻²); m=8/12/20/40 → wet 0.24/0.10/0.036/0.008%, dry 1.24/0.51/0.17/0.03%
  (`e2_collocation.R`).
- **Tracked-q:** spin-up matches QSS uptake to 4 dp; semiarid soil tracks QSS to <1e-3 at k=5, 2.6e-4 at
  k=20, no plateau (`e2_e3_patch.R`). wet/drought need per-cohort feasibility clamp (mechanical).
- **Reverse mode:** adjoint=FD ~1e-8 across k∈{1..1000}, m∈{4..64}; reductions don't amplify; k=100
  anomaly = FD roundoff not adjoint error (`e4_test.R`). Hard member kink breaks adjoint=FD → smoothing
  restores (`e4_bias_test.R`) — this is the B3 footgun, real.
- **R1:** drainage recession closed form matches tight RK ~1e-13, positivity-preserving
  (`r1_drainage_flow_check.R`).
- **H0:** envelope collapse does NOT hold for TF24 (coupling is a water flux, not ∂P/∂θ);
  both models supported without it (`h0_envelope_check.md`, missive).

---

## 8. Build order + gates

1. **plant R1 exposure** (§6, plant issue): analytic drainage flow + residual RHS + touchdown. Gate:
   split soil integration matches the current monolithic soil solve on the 5 scenarios.
   ✅ **DONE** — aornugent/plant#54 (branch `claude/plant-53-drainage-split`): `TF24_Environment::analytic_partial_flow` /
   `residual_rhs` / `drainage_touchdown_time` + `test-tf24-soil-split.R` (decomposition identity exact ~1e-10;
   exact flow ~1e-7; Strang converges to monolithic drought→monsoon). `compute_rates` unchanged; infiltration shared.
   Items 4–8 of plant#53 (factored coupling, P_pp, feasibility-clamp event, setup cache, batched kernel) still to do.
2. **odelia MRIStepper + InnerStepper seam** (4.1–4.2): port mri_core, collapse+order gates, ARKODE
   diff-test. Gate: order 1/2/2/3 tables; base-ERK & pure-inner collapse to machine precision.
   ✅ **DONE + wired into the method surface.** odelia master fast-forwarded to upstream (RODAS #35/#37,
   which added the `Method` enum + `stepper_step` dispatch). MRI is now `method="mri"` — a first-class peer
   of rkck/rodas: `MriStep<System>` matches the Step interface, a System opts in via `is_multirate`
   (declares fast/slow split, state fast-first); driven by fixed macro steps (the kink grid), adaptivity in
   the fast sub-cycle. Gate: `method="mri"` via the Solver is stable+accurate on the daily grid where
   fixed-step rkck blows up. **This is the surface the SCM selects** — plant just passes `method="mri"` once
   its patch System declares the soil block as fast (fast-first layout; needs plant#53 items 4+ for a cheap
   fast_rates). Assumptions to honour in the plant adapter: **state laid out fast(soil)-first**, and
   **fixed macro grid** (MRI reports no macro error, so drive with advance_fixed, not advance_adaptive).
3. **R1 splitting inner + ROS34PW2** (4.3): Gate: matches an adaptive inner on the fast block; drainage
   stiffness gone (measure `‖[drainage, residual]‖` commutator + `‖∂a/∂u‖` — decides if the residual
   step can go explicit; R1's step-enlargement magnitude).
4. **Factored coupling + collocation** (4.4, §6): Gate: aggregate to <0.5% at m≈15–20 on real cohorts;
   Lebesgue proxy bounded.
5. **Control block** (4.5): tracked-q via TF24f; B1 collapse. Gate: B1 sizing (p* spread, P_pp margin);
   tracked reproduces QSS soil to <1e-3 across scenarios.
6. **Reverse mode** (4.6): two-level record→replay; passive/active contract; events. Gate: adjoint=FD to
   ~1e-8 **and the new gradient-vs-(m,k) Richardson check** (B3 footgun) on the real coupling.
7. **Full patch integration** across drought→monsoon: MRI vs global RK45 — accuracy, stability,
   expensive-eval + wall-time win (the deliverable the R prototypes proxied).

---

## 9. Open items (carry forward)

- **H0 generalization** (pending Oracle, `h0-missive.md`): characterize the coupling class where the
  envelope collapse holds → a future strategy posed in marginal-coupled form drops the control apparatus
  for free. One-identity triage per new model.
- **B1 sizing** on real cohorts (spread of p*, P_pp margin) — decides rung 1 vs polynomial vs per-node.
- **R1 commutator sizing** — 2× vs 20× step enlargement; and `‖∂a/∂u‖` (explicit residual step?).
- **Gradient-reduction Richardson check** — add to the AD harness before trusting reduced-m gradients in
  an outer optimizer (B3 footgun; not yet in the certification on the *real* coupling). Already
  **prototyped on the surrogate** in `scripts/tf24-multirate/e4_bias_test.R` (a hard member kink breaks
  adjoint=FD; model-level smoothing restores it) — port that check to the real coupling.
- **R2/R3/R4** deferred (rainfall multiplicative; R1 pre-empts R3; H0/gradient-structure fail for R4) —
  revisit only if a gate above fails or a future model changes the structure.
