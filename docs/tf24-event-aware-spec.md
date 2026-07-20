# TF24 event-aware integrator — implementation specification

*The current pathway (Oracle rounds 6–7). Supersedes the retired multirate
engine-port-spec + implementation-plan. Written from a verified read of the
odelia ↔ plant ↔ TF24 coupling (see "Coupling map" below); every touchpoint cites
real code. Baseline to beat: `scripts/tf24-benchmarks/BASELINE.md`.*

---

## 0. One-paragraph thesis

The time-integrator is not the lever, but the **global explicit RK wastes ~27–35%
of its step attempts on rejection bisection** discovering isolated non-smoothness
(measured), and one scenario fails outright. Make the *same* global explicit RK
**event-aware**: locate the RHS's C0 kinks with **0-solve margin functions on a
cheap dense-output interpolant**, step *to* them, and restart with a fresh
derivative — so each arc is smooth (design order) and no step is thrown away
discovering a kink. Build the **classifier that decides whether this pays off
first**; build the stepper only if it does; and keep everything switchable and
bit-identical when off.

---

## 1. Design discipline (system-design skill)

**Triage: Tier 2** — a new engine capability with a visible seam (a System trait +
an advance-loop variant), switchable and reversible; not a persisted format or
public wire protocol.

### Requirements ledger
- **R1 — accuracy:** reproduce the baseline offspring per scenario in J-units,
  rel err ≲ 1e-3 (J amplifies coupling error ~10×). *Non-negotiable.*
- **R2 — cost:** cut the reject fraction below the baseline 0.27–0.35 (and the
  accepted-step count); the ~30% wasted O(M) probes are the headroom.
- **R3 — correctness:** make `multispecies` **complete** (baseline: non-finite,
  H1 overshoot/overflow).
- **R4 — safety:** switchable; **bit-identical when off** (the invariant that has
  protected every experiment so far).
- **R5 — decide before building (challenged upward):** you asked for the
  event-aware *stepper*; the smallest thing that meets the goal is the
  **classifier measurement first** — it splits the 70–98% unattributed collapse
  into removable-events vs intrinsic, i.e. it decides whether the stepper can pay
  R2 at all. *Confirmed by the Oracle build order; the first deliverable is a
  measurement, not the stepper.*

**Scarce resource:** O(M) RHS evaluations. Rejection bisection spends ~5–15 of
them per kink to *locate* it; the whole design exists to locate kinks with **zero**
RHS evaluations (margin functions on the interpolant) instead.

### The floor
Global rkck + **forcing-kink step clipping** (clip trial steps to known rainfall
feature times — a 5-line change). *Fails R2:* removes only the 2–31% forcing share;
the 70–98% state-event collapse and R3 remain. So the floor is not enough — **but
the forcing clip ships anyway** (free, independent), and the true floor for the
*decision* is the **classifier** (Stage 1), which may reveal the residual is
intrinsic → then no stepper is built (a legal, good outcome).

### Candidates (for the stepper, IF the gate passes)
- **A [first thought] — full step-to-event.** Move: enumerate. Commitment: locate
  every event exactly on dense output, restart each arc. Pays R2 (no rejections at
  kinks) + R1 (design order per arc) + R3 (no overshoot). Costs: dense-output
  primitive, event hook, locator, restart, active-set, tracked-p — the most new
  names. Wins when: the residual is genuinely event-attributable *and* accuracy
  needs exact arcs.
- **B — proximity governor only.** Move: optimize-the-typical-case + detect.
  Commitment: never *locate*; just **cap the trial step** at ~1.2× time-to-nearest
  event (from margin values + drift) so the controller stops discovering kinks
  mid-step. Pays R2 (converts rejection bisection into short accepted steps) and
  likely R3 (caps the H1 overshoot). Costs: the event hook + a step cap; **no dense
  output, no restart, no transition handlers.** Wins when: the reject-fraction win
  is most of the value and exact event handling isn't needed for R1.
- **C — mollify the switch.** Move: weaken exactness. Commitment: replace the hard
  leaf-shutdown switch with a smooth ramp of width w below J-sensitivity, so the
  dominant event class **stops being an event** (C1 RHS). Pays R2 by deletion.
  Costs: a declared model change + a measured dJ/dw budget; only touches the
  shutdown class, not the clamp/argmax. Wins when: the hard switch is a modelling
  idealization and smoothing is scientifically acceptable.

**Winner: staged B → (A-subset as needed), with C available as a targeted
deletion.** Eliminations: **A in full is overbuilt for R2** — the governor (B)
captures the reject-fraction win with the event hook alone, no locator/restart
(deletion pass: locator+restart pay only for *exact-arc accuracy*, which R1 may
already get from the governor's smaller steps — measure before building them). **C
alone can't pay R3** (overshoot isn't a shutdown event) and needs a science ruling,
so it is an optional accelerator, not the base. The full-location machinery (A) is
added only where the Stage-2 governor data show residual rejections that matter.

### The commitment
**Events are found by evaluating System-supplied scalar margin functions on a
cheap dense-output interpolant — the expensive O(M) RHS is never called to find or
locate an event.** Kept true by structure: the event-hook signature takes the
*interpolated state* and returns margins via a **separate cheap path** (functions
of θ + per-cohort constants), with no access to `compute_rates`; the governor and
locator are typed to consume only margins, so "probe the RHS to find an event" is
inexpressible.

### Kill question
*Assumption whose falsity kills the stepper:* that the 70–98% unattributed collapse
is **removable events**. If the classifier (Stage 1) shows it is **intrinsic fast
structure**, step-to-event buys nothing beyond the governor's reject win, and the
locator/active-set/tracked-p are not built. **Verdict: survives as staged —** which
is exactly why Stage 1 is a measurement gate, not a build.

### What this settles / makes hard
- **Settles:** no dense output or transition handlers are built until the gate and
  the governor data justify them; the forcing clip and governor are the cheap base.
- **Hard (priced):** exact event *accuracy* (A) is deferred — if a scenario needs
  exact arcs for R1 that the governor's small steps don't deliver, we add the
  locator then. Reverse-mode through located events (Leibniz jump) is out of scope
  for the forward build (see §6).

### Kill condition
If the classifier shows intrinsic-dominates, hand off to the losing frame's "wins
when": abandon the stepper, keep the governor + forcing clip, and return to the
**member mesh + J** frontier (§7) — where the Oracle says the real accuracy work is.

---

## 2. Coupling map (verified; the facts the design rests on)

- **odelia stepper.** `SolverInternal::step()` takes one accepted adaptive RKCK
  step (internal rejection retries); `advance_adaptive(system, t_max)` loops it
  (`ode_solver_internal.hpp`). **No dense output exists** — `step()` yields only
  `y(t+h)`, `yerr`, and `dydt_out`. The step start derivative `dydt_in` and
  `dydt_out` are both available (FSAL: `first_same_as_last=true`,
  `can_use_dydt_in=true`), so a **cubic Hermite interpolant on [t, t+h] is free**.
- **SCM driving.** The only imposed integration boundaries on the adaptive path are
  node introductions: `solver.advance_adaptive({t0, e.time_end()})` at
  `scm.h:252` (resume) and `:297` (normal). **This is the single hook point** — an
  event-aware advance replaces these calls.
- **RHS.** `Patch::set_ode_state(it,t)` → `compute_environment(true)` (light field)
  → `compute_rates()` → `compute_species_rates()` (per-cohort physiology + uptake)
  → `environment.compute_rates(assemble_resource_depletion())`. On the standard
  adaptive path everything is recomputed each eval (nothing frozen).
- **Event surfaces (C0 kinks), all with 0-solve margins from θ + constants:**
  - **Leaf shutdown** (`leaf_model.cpp`): `E_up→0` is a hard jump
    (`set_shutdown_state`). Cheapest global margin `psi_crit − |ψ_soil,wettest|`
    (site 1, a pure comparison; `ψ_soil` from θ via `psi_from_soil_moist`). Tighter
    margins (`E_column<0`, the continuity root) cost 1 eval / 1 solve. After a solve,
    `psi_crit − opt_psi_stem_` is exactly 0 in shutdown.
  - **Soil clamps** (`tf24_environment.h`): K(θ) clamp to `[0,θ_sat]` (margins
    `θ`, `θ_sat−θ`), ψ floor at θ_res + ceiling at `soil_psi_max_=1e3`
    (margins `θ−θ_res`, `1e3−ψ`), infiltration runoff `max(0, 1−a(θ0/sat)^b)`
    (margin = the runoff arg). `drainage_touchdown_time()` **already** computes the
    closed-form θ_res contact time — a ready-made event time.
  - **Argmax bound flips** (`prepare_collar_solve`): `bound_a=−root_zero_E`,
    `bound_b=max(−root_crit,−root_psi_crit)`; collapsed interval when
    `|bound_b−bound_a| ≤ GSS_tol`. **Bounds are local vars, currently discarded** —
    exposing bound-proximity requires retaining them.
  - **Internal solve branches** (candidate un-hypothesized events): the
    `prepare_collar_solve` feasibility-exit vs real-search return; per-layer
    equal-potential / gravity-balance / ψ=0 branches in
    `E_from_Soil_to_Root_Collar`; the exact NaN-kink set enumerated by
    `dE_from_soil_dpsi_collar`. `find_root_psi`'s own comment argues these are
    **bit-level kinks (~1e-6 slope jump), likely sub-tolerance** — the classifier
    settles whether any are controller-visible.
- **Forcing.** Rainfall is a **cubic spline (C2)** through daily nodes
  (`extrinsic_drivers` → odelia interpolator). Rain events are **smooth
  high-curvature features, not true kinks** — a cubic through spiky daily rain
  overshoots. `basic_spline` supports **linear interpolation** (`cubic_spline=false`):
  switching rainfall to piecewise-linear makes rain events **true C1 events** at
  known times (and removes the spurious overshoot) — a candidate simplification.
- **Instrumentation already present:** odelia `step_diag` (per-attempt step log,
  off by default); `SCM::r_ode_times()` (accepted step times); node-schedule times.

---

## 3. Stage 1 — the classifier (the gate; build this first)

**Purpose (R5):** split the 70–98% unattributed step-collapse into
event-attributable vs intrinsic, and surface un-hypothesized event surfaces. **No
new integrator** — it only observes.

**odelia (generic):** extend `step_diag` so that, when a **monitor hook** is
present on the System, each accepted step also records the System's returned
vector of (a) `double` event-margin values and (b) `int` branch-signature codes,
alongside `(t, h, ok)`. One new optional System method, probed by a trait
(mirroring `has_partition`): `void step_monitor(std::vector<double>& margins,
std::vector<int>& sig) const`. Zero cost when absent.

**plant (TF24-specific):** implement `step_monitor` on `Patch` returning, from the
state already computed this step (no extra solve):
- margins: per-layer `θ−θ_res`, `θ_sat−θ`, `1e3−ψ`, runoff arg; per-heavy-cohort
  shutdown margin `psi_crit−|ψ_soil,wettest|` and `psi_crit−opt_psi_stem_`
  (heavy = top-h by `ρ·|c|` + a rising watchlist); forcing-feature proximity.
- branch signatures: `prepare_collar_solve` feasibility-exit flag per heavy cohort;
  the per-layer `E_from_Soil_to_Root_Collar` branch index; the `bound_b` min/max
  selector. (Requires surfacing a few currently-discarded locals — small, additive.)

**Analysis (R script, `scripts/tf24-benchmarks/`):** run the bank with the monitor;
for each small/rejected step, a **sign change or signature flip** in the preceding
interval = event-attributable; none = candidate-intrinsic. Then the **smooth-arc
test** on candidate-intrinsic windows: re-integrate at 10× tol and fit the
dense-output of θ and heavy margins with one high-order polynomial — smooth feature
refines ∝ h^p (fit good); undetected kink leaves an O(h·jump) residual at a point
(→ a new event surface; find it in the signatures).

**Gate output:** the fraction of the residual that is removable events, per
scenario, and the list of controller-visible event surfaces. **If removable
dominates → build Stage 2. If intrinsic dominates → stop; keep governor + forcing
clip; go to §7.**

---

## 4. Stage 2 — the event-aware stepper (only if the gate passes)

Built in odelia against a **toy** (a scalar system with a known shutdown-like
switch + a clamp, where the exact event time is analytic) before wiring TF24.
Codesign: the mechanism is generic; TF24 supplies the event functions.

**4a. Dense output (odelia, generic).** Add a cubic **Hermite interpolant** to the
stepper: `state_type interpolate(theta01)` from `y(t)`, `y(t+h)`, `dydt_in`,
`dydt_out` — 3rd-order, **zero extra RHS evals**. Enables interior evaluation of
margins for location. (RKCK has no free 5th-order dense output; 3rd-order Hermite
is sufficient to *bracket + locate* a margin zero, which is then the truncation
point — accuracy of the arc itself is unaffected because we restart with the exact
RHS.)

**4b. Event-function hook (System trait).** One method the System provides:
`void event_functions(const state_type& y_interp, double t, std::vector<double>&
g) const` — the margins as **functions of the interpolated state only, never
calling `compute_rates`** (the commitment, enforced by the signature). plant
reuses the Stage-1 margin code. Directions/kinds (which side is "on") travel with
the hook.

**4c. Step-to-event + restart (odelia, generic).** New advance variant
`advance_adaptive_events(system, t_max)`:
1. take a normal `step()`; on accept, evaluate `event_functions` at the endpoints
   (+ 2–3 interior Hermite samples) — all 0-solve.
2. if a margin brackets a sign change: **Brent on the Hermite interpolant** (0
   solves) → `t*`; truncate the step to `t*`; set `y = interpolate(t*/h)`; call a
   System `on_event(idx, y)` transition; **restart** with `dydt_in_is_clean=false`
   (invalidate FSAL — the RHS jumps across the event).
3. else keep the step.
Never reuse stages/FSAL across an event (the naive order-killer; the
`dydt_in_is_clean` flag already exists for exactly this).

**4d. Proximity governor (odelia, generic) — the cheap R2 win, ship before 4c
location if the gate allows.** Before each step, cap the trial `h` at
`≈1.2×` the smallest `|g_i| / |ġ_i|` (drift from consecutive monitor samples). The
event lands inside a step where dense output brackets it, converting
rejection bisection (O(M)×5–15) into one 0-solve Brent. **Watch-set criterion:** an
event is worth capping/locating iff `|RHS jump| × h > local error tol` — make the
margin threshold exactly that, adaptively (protects against over-resolving
sub-tolerance/bit-level branches).

**4e. Transition handlers (plant `on_event`):**
- **shutdown:** flip the cohort's shutdown state (already a clean switch).
- **soil clamp:** **active-set** — pin the clamped layer (integrate the reduced
  system), release on the exact release condition; not hysteresis. `analytic_flow`
  / `drainage_touchdown_time` already provide the θ_res contact machinery.
- **argmax bound / tracked-p:** prefer the **TF24f tracked-control** variant
  (`dq/dt = k·dprofit`) to delete the argmax-bound event class entirely (smooth by
  construction; lag budgeted); fall back to a bound-flip event if not.

**4f. Forcing.** Offer piecewise-linear rainfall (`cubic_spline=false`) so rain
events are true C1 events at known times, clipped exactly (build-order item 1). C2
cubic stays the default until the gate/accuracy say otherwise.

---

## 5. Codesign split (what lives where)

| capability | odelia (generic, toy-first) | plant (TF24-specific) |
|---|---|---|
| step monitor log | `step_diag` + `has_step_monitor` trait | `Patch::step_monitor` (margins + signatures) |
| dense output | Hermite `interpolate()` on the stepper | — |
| event hook | `has_event_functions` trait; consumes margins only | `Patch::event_functions` (0-solve margins) |
| step-to-event + restart | `advance_adaptive_events`, Brent-on-interpolant, FSAL invalidation | `Patch::on_event` transitions |
| proximity governor | trial-`h` cap from margins+drift | (uses the same margins) |
| selection | `Method`/control flag (bit-identical off) | `control$ode_method="rkck_events"` (or a bool) |

Same discipline as the MRI partition hooks: engine offers traits; plant supplies
the model logic; absent-trait Systems compile and run unchanged (R4).

---

## 6. Reverse-mode / tape (scope note, not this build)

Located event times are **active scalar-IFT nodes**; the adjoint needs the Leibniz
jump `(f⁺−f⁻)ᵀλ·t̄*` once the truncated-step length is active, and the record→replay
must record event times (pass-1) and replay them pinned (pass-2, polished as active
roots). This is **out of scope for the forward build** and belongs with the
reverse-mode branch work (`claude/odelia-ad-tape-reverse-496fuf`, plant#60). Note
the dividend: active event times restore exactly the schedule sensitivity the
frozen-schedule contract drops at kinks. Design 4b/4c so the event time is a
first-class recorded quantity to make this retrofit cheap.

---

## 7. The real frontier (after / alongside the stepper)

The Oracle's standing verdict: the integrator is not where accuracy lives.
Independently of Stage 1/2:
- **Coupling-weighted mesh refinement:** the node schedule refines for `x(t)` but J
  depends on `∫c·ρ`. Add a `ρ·|c|` refinement indicator (free — the full-M
  byproducts exist every step) and re-run the M-refinement certification of J.
  Attacks the 24%-class error and the 23% inter-scheme spread at the root.
- **J conditioning:** 10× amplification + 23% spread → J is barely an observable;
  reformulation may beat any numerics (a model-side decision).

---

## 8. Build order & acceptance (against `BASELINE.md`)

1. **Forcing-kink step clipping** (floor freebie; independent).
2. **Stage 1 classifier** (odelia `step_monitor` trait + plant `step_monitor` +
   analysis). **Gate:** removable-events fraction per scenario. *Accept:* a clear
   split + the controller-visible event list.
3. **Proximity governor** (4d). *Accept:* reject fraction < baseline 0.27–0.35 on
   the bank at matched offspring (R1, R2); multispecies completes (R3).
4. **Dense-output location + restart + active-set + tracked-p** (4a–4e) — only for
   the event classes the gate proved controller-visible and only if the governor's
   residual rejections still cost. *Accept:* further reject-fraction drop at
   matched J; each arc at design order.
5. **Mesh/J frontier** (§7).

Every stage: bit-identical when off (R4); re-measure with
`scripts/tf24-benchmarks/event_sizing.R` and append a candidate row to
`BASELINE.md` (never overwrite).

## 9. Open questions / risks

- **Gate risk:** the residual may be intrinsic (kill question) → no stepper; the
  governor + forcing clip + mesh work are still worth it. This is a *good* outcome,
  not a failure.
- **Argmax bound exposure** requires retaining currently-discarded locals in
  `prepare_collar_solve` — small but touches hot code; keep it a byproduct, no
  extra solve.
- **Chattering** at the shutdown boundary / clamp: hysteresis (guard only), event
  clustering (aggregate > k light-member crossings into one located event), or
  mollification (candidate C, budgeted dJ/dw). Sized by the Stage-1 census.
- **R-D interaction:** the ζ=ln(θ−θ_res) chart (pending revert) *removes* the
  θ_res clamp event by making positivity structural — a minor point in its favour
  for the event pathway. Weigh against its named-machinery cost when finalising the
  revert; the dominant events are cohort-layer regardless.
- **3rd-order Hermite** vs the 5th-order step: adequate for *locating* a margin
  zero (the arc restarts with the exact RHS), but verify the located `t*` is
  accurate enough that the post-event arc matches truth in J-units.
