# TF24 soil–leaf–demography system: a general numerical formulation, and the question of whether it is misspecified

_Session 10 (2026-07-21), branch `claude/odelia-ad-tape-reverse-496fuf`. Written to pose one
question precisely: **is the TF24 coupled system misspecified in a way that frustrates BOTH the
forward leaf-optimisation solver AND the reverse-mode AD gradient?** It compiles the formulation
from first principles, states every pathology we have measured, and cross-checks against the
independent multirate-stepper review on `claude/multirate-stepper-review-r6dpwn`, which reached a
convergent answer from the forward-solver side. Sources are cited inline; quotes are verbatim._

---

## 0. Why this document exists

Two independent investigations, on two branches, hit the same wall at the same place:

- **This branch (reverse-mode AD).** The resident TF24 reverse-mode gradient is exact for short
  patch lifetimes but **blows up at life ≥ 3** (`max|ad|` 5e5 → 1.65e10 → 2.56e14 across life
  2→3→4; the double/FD path stays ~1e6). Session-10 localisation (below) traced it to the
  **soil-water feedback channel near the dry bound**, not the leaf assembly.
- **The multirate branch (forward adaptive stepper).** The adaptive RK step controller **collapses**
  (10³–10⁵ steps) at the same dry-end regime; the review diagnosed it as "**accuracy-driven, not
  stability-driven, localised to a small block's near-singular excursions**"
  (`docs/oracle-consultation-multirate-update.md`), and its reformulation thread concluded the model
  is "**posed in the wrong state variable**" with "the clamp, the floor, the singular slopes, and
  most of the gradient pathology … the chart's artifacts, not the model's"
  (`docs/oracle-consultation-reformulation-response.md`).

The hypothesis this document sharpens: **these are one pathology seen through two lenses.** If so,
the reverse-mode blow-up is not (only) an AD bug to patch in `assemble_leaf_from` — it is the
gradient reporting that the model, as charted, is near-singular exactly where drought sensitivity
lives, and the fix is a reformulation the forward-side work has already designed and validated.

---

## 1. The general numerical formulation

### 1.1 State

A patch integrates one coupled IVP `y' = f(y, t; θ)` on `[0, T]`, `θ` the seeded trait/parameter
vector. `y` splits into two blocks of very different size and character (the multirate review's
`x`/`u` split, `docs/oracle-consultation-multirate-update.md`):

- **Large block `x ∈ ℝ^M`, `M ≈ 50–800`** — the size-structured cohort state. Per cohort: log-mass
  `λ = ℓ + log Δx` (the P1e transport chart), height, and heartwood/other allocation states. The
  competition/light field `s(x)` is a cheap O(1) aggregate of the whole block.
- **Small block `u ∈ ℝ^L`, `L ≤ 5`** — the 5 soil-water layers, volumetric water content `θ_ℓ`
  (overloaded name; soil θ, not traits θ — disambiguated by context below).

### 1.2 Rates

- **Cohorts.** `ẋ_j = φ(x_j, u, s(x))`. Each `φ` is the plant's growth/fecundity/mortality, and its
  carbon engine is an **iterative leaf solve** (§1.3) that **reads the soil state `u`**. Evaluating
  all `M` leaf solves is 95–100% of the cost of one `f` (`docs/oracle-consultation-multirate-update.md`).
- **Soil.** Per layer, `dθ_ℓ/dt = (inflow_ℓ − K(θ_ℓ) − uptake_ℓ)/dz`, i.e. `u̇ = b(u,t) − a(x,u)`:
  - `b` (**cheap, closed-form**): infiltration (with saturation-excess runoff), the one-directional
    inter-layer drainage cascade `win_ℓ = wout_{ℓ−1}`, and gravitational drainage
    **`K(θ) = K_sat·(θ/θ_sat)^p`, `p = 2·n_ψ + 3 ≈ 16.14`** (plant#53; `tf24-rd-ecological-characterisation.md`).
  - `a(x,u) = Σ_{j=1}^M c_ℓ(x_j, u)` (**expensive, non-separable**): aggregate root uptake, a
    byproduct of the same `M` leaf solves. It is **not separately cheap** and must move with `u`.
- **Two-way coupling.** `f_u` reads the uptake aggregate `a`; `f_x` reads the soil potential `u` (via
  `ψ_soil`) and `s(x)`. This closed loop — trait → leaf → uptake → soil state → next leaf — is the
  one the reverse-mode blow-up lives in (§2).

### 1.3 The leaf operating point (the inner solve `φ` reads)

Per cohort, at the converged soil state, TF24 solves a water/carbon optimisation:

- Retention: **`ψ_soil(θ) = a_ψ·(θ/θ_sat)^{−n_ψ}`, `n_ψ ≈ 6.57`** — diverges as `θ → 0`, **capped**
  at `soil_psi_max_ = 1e3 MPa`.
- Hydraulic path soil→root→stem with a **Weibull vulnerability** `exp(−(ψ/b)^c)`; the stem
  critical potential `ψ_crit = b·(ln 20)^{1/c}` is the vulnerability limit.
- Collar potential `p*` chosen by `find_root_collar_psi` (golden-section max of carbon profit over
  `[bound_a, bound_b]`), with ψ_stem and c_i as nested implicit (root-find) solves.
- **Regime branches** (`leaf_model.cpp`): interior optimum; **bound** (`p*` clamped to `bound_b`,
  ψ_stem pinned at ψ_crit, continuity `E_column = 0`); several **shutdown** states
  (`profit = −R_d − hydraulic_cost_TF(ψ_crit)`), entered when the wettest layer is drier than
  ψ_crit or the soil cannot supply the demanded flux.

### 1.4 Reverse-mode AD over this

The resident gradient records the whole adaptive run on one tape and replays it on the resolved
schedule; one reverse sweep yields `d(metric)/dθ`. The leaf solve is double-only; its parameter
sensitivity is injected via `supplied_derivative` — the leaf re-assembled as active scalars on a
per-call local tape (`assemble_leaf_from`), exact partials `d(profit)/d(input)` and
`d(uptake_ℓ)/d(input)` handed to the run tape (P2c steps 5–6). The soil ODE, cohort transport, and
competition field are recorded normally.

---

## 2. What we measured on THIS branch (reverse mode)

Certificate = reverse-AD gradient vs a pinned-schedule central FD, per seeded field, across patch
lifetime (`scratchpad/tf24_cert.R`, parallelised driver `ad_certificate.cpp`).

| life | ode_times | max\|ad\| | max\|fd\| | verdict |
|---|---|---|---|---|
| 1–2 | 128–165 | ~5e5 | ~5e5 | clean |
| 3 | 203 | 1.65e10 | 9.2e5 | blow-up begins |
| 4 | 361 | 2.56e14 | 1.2e6 | all channels BLOWN |
| 10 | 1664 | — | — | reverse run OOMs (>15 GB tape) |

**Localisation (session 10, all measured, diagnostics since reverted):**

1. **AD-only**; the FD/double path grows smoothly (5e5→1.2e6). Onset is **sharp** (life 2→3) and
   **uniform** across all seeded channels (~1e8 ratio) — one shared near-singular quantity's adjoint
   propagating to everything.
2. **Not the leaf assembly's magnitude.** The injected leaf partials are **bounded** across all
   495 826 leaf calls (`max|d profit/d input| = 9421`, `max|d uptake| = 3.0`). The interior p\*
   node's denominator `P_pp` is **healthy** (min ≈ 2.5, never near 0); the bound regime is **never
   entered** in these runs (0/495 826).
3. **It IS the soil-water feedback.** Zeroing the injected partials w.r.t. the `θ_soil` **state**
   inputs drops `max|ad|` **2.56e14 → 3.05e5 (sane)**. Since the true `max|fd| ≈ 1.2e6` sits ABOVE
   the killed value, the soil feedback is a **legitimate** gradient channel that the reverse sweep
   **amplifies ~1e8** over the dry, long trajectory.

**Arbiter (FD-step sweep, DONE).** At life=4, `d(Σheight)/d(theta)`: AD = **−2.565e14**; FD across
`h` = 1e-2 … 1e-5 = **−1.154e6, −1.154e6, −1.157e6, −1.147e6, −1.199e6, −1.077e6, −1.544e6** — a flat
**plateau at ~1.15e6 across three decades of step size** (the wobble at the smallest `h` is roundoff;
the `omega` column sign-flips there). FD does **not** climb toward AD as `h → 0`. **Verdict: the true
(smooth-model) sensitivity is a sane ~1e6; the AD's 1e14 is spurious by ~1e8.** So the reverse mode is
NOT faithfully reporting a genuine near-singular *smooth* truth (that would show FD climbing) — it is
faithfully differentiating a near-singular **discrete trajectory** (the misspecified θ-chart's, with
its clamps and diverging `∂a/∂θ ~ δ^{γ−1}`) that FD steps over. Both facts hold at once: the true
gradient is finite and well-behaved, AND our reverse AD carries a spurious 1e8 term rooted in the
chart's near-singularity.

---

## 3. What the multirate branch measured (forward mode) — the convergent diagnosis

The forward adaptive stepper collapses at the **same dry-end coupling**, and the reformulation
thread ran it to ground. Verbatim, from docs I read directly:

- **One cause, three symptoms** (`oracle-consultation-reformulation-response.md`): "extraction
  responds to scarcity through a steep power law, so the sink shuts itself off non-Lipschitz-fast as
  the stock empties", expressed as "the **stiffness is intrinsic** (it is a residence time, and no
  change of variables touches it); the **singularity is a chart artifact** (the u-chart puts bounded
  physics through unbounded coefficients, and also through a catastrophic floating-point range); the
  **clamp is a derived object** … in neither case is a hard clamp on `u` the right primitive."
- **The intrinsic rate is a residence time**: `λ = γ·r/(d·δ*)` = turnover / stock, **chart-invariant**,
  `→ ∞` as inputs dry. "No coordinate removes it; it must be stepped over (implicit/Rosenbrock on an
  `L ≤ 5` block) or slaved."
- **Float conditioning**: "`φ = u^{−6.6}` spans ~15–20 orders across a 2–3-order range of `u` …
  **any quantity computed through `u^{−q}` near the bound is currently losing most of its significand
  before the tape ever sees it**."
- **T1 measured a latent correctness bug — a dead gradient**
  (`oracle-consultation-reformulation-response.md`): "As `θ` falls below ≈0.11, the retention-curve
  ceiling (`soil_psi_max_=1e3`) pins uptake at a **constant** 5.2e-4 … and `∂uptake/∂θ = 0` all the
  way to the bound … **the reverse-mode gradient through uptake is silently zero for θ < ≈0.11 — a
  latent correctness defect exactly where drought sensitivity matters.**"
- **T4**: the stiffness is at the **stress transition** θ ≈ 0.11–0.16 (eigenvalues to −87/day,
  **strictly real**), not the bound (Jacobian identically zero at the floor).
- **The reformulated scheme's reverse-mode gradient is exact** (T3): log-depletion chart
  `ζ = ln(θ − θ_res)` + smooth vulnerability shutoff → "**Adjoint == FD to max_abs_err 1.7e-7**",
  the residual scaling as `eps²` ("tape is exact, FD is noisy").

The reformulation prescription (validated end-to-end on a windowed prototype, T2/T3):

1. **R-C — smooth vulnerability shutoff** (prerequisite): replace the ψ-ceiling floor + positivity
   clamp with a smooth stress function over a declared (ecological) moisture scale. Restores the
   drought-sensitivity gradient (kills the dead channel); makes uptake → 0 at the wilting point.
2. **R-D — log-depletion chart** `ζ = ln(θ − θ_res)`: `θ = θ_res` becomes `ζ = −∞`, unreachable by a
   finite step (positivity structural, clamp deleted); coupling slope `∂a/∂ζ ≈ γ·a` bounded by the
   flux; float range O(10). "R-C and R-D … **must land together**."
3. **Residence-time stiffness remains** and is handed to an `L ≤ 5` implicit (Rosenbrock) micro-step;
   the multirate MRI-GARK engine sub-cycles the soil against coarse cohort steps.

Note the honest caveat (`tf24-rd-ecological-characterisation.md` §5): R-D alone "**buys
code-cleanliness and a structural guarantee, not performance or robustness**"; the stiff-regime step
win is the implicit stepper's, and the dry-end feasibility is the vulnerability shutoff's — "**no
chart saves you**" if uptake does not vanish at the floor.

---

## 4. The ecological mischaracterisations (issues #53, #62, and the branch)

These are not merely numerical — they shape the regime the solver and the gradient get stuck in.

- **#62 — hydraulic shutdown is structurally unreachable.** TF24 shutdown keys on the **wettest
  accessible layer**, so "a persistent wet deep layer prevents hydraulic shutdown even under
  multi-year drought." Measured: top two layers reach ψ ≈ 5.1–5.3 MPa (right at ψ_crit ≈ 5.6) while
  the bottom sits at ψ ≈ 0.37 MPa; shutdown "essentially never" fires; the stand dies of
  **carbon starvation** instead. Contributing structural choices flagged in the issue: shutdown keys
  on one layer (not a root-weighted whole-profile criterion); **no upward capillary flux** between
  layers; deep-layer retention with drainage collapsed (`K ∝ θ^16`). **Consequence for us:** the top
  layers dry to and **park at ψ_crit** (the near-singular vulnerability limit) for long stretches —
  exactly the persistent near-bound coupling in which our reverse-AD blow-up (life ≥ 3) and the
  forward step-collapse both live.
- **#53 — the stiff/singular drainage term, with a closed-form flow.** `θ̇ = −c·θ^p`, `p ≈ 16.14`
  has an exact positivity-preserving recession `θ(t) = [θ0^{1−p} + (p−1)c·t]^{−1/(p−1)}` (R1),
  verified to ~1e-13, which "removes the explicit-stepping positivity clamp … and eliminates a
  non-differentiability." A wet-end win (not the dry-end prize), but it deletes one clamp/kink from
  the tape.
- **The dead-gradient floor (§3, T1)** is itself an ecological mischaracterisation: the ψ-ceiling
  pins uptake at ~6% of peak with zero derivative for θ < 0.11 — the model draws water **past
  hydraulic death** with no down-regulation, "the opposite of drought physiology."

---

## 5. The question, posed

**Is the TF24 system misspecified?** The evidence says **yes, in a specific, actionable sense**: the
soil state `θ` **carries the wrong asymptotics**. The physics (a scarcity-driven sink shutting off)
is sound and its residence-time stiffness is intrinsic; but posing it in `θ` routes bounded physics
through unbounded coefficients (`ψ = θ^{−6.57}`, 15–20 orders of float range), stands a positivity
clamp and a ψ-ceiling floor in for the natural asymptote, and leaves a **dead reverse-mode gradient**
across the drought regime. The forward solver meets this as accuracy-driven step collapse; the
reverse mode meets it as our life ≥ 3 blow-up. **They are the same near-singular-bound pathology.**

If that reading holds, then the reverse-mode blow-up is **not primarily a bug in
`assemble_leaf_from`** — patching the leaf partials would be treating a symptom. The root fix is the
reformulation the forward-side work has already designed and validated on a prototype: **R-C (smooth
vulnerability shutoff) + R-D (log-depletion chart), with the residence-time stiffness handed to an
`L ≤ 5` implicit micro-step.** Its T3 result — **reformulated adjoint == FD to 1e-7** — is direct
evidence that the reformulation cures the reverse-mode pathology, not just the forward one.

**What "something is missing" concretely means here:**
1. **R-C smooth shutoff** — removes the ψ-ceiling floor and its dead gradient (a correctness bug),
   and makes uptake vanish smoothly at ψ_crit.
2. **R-D log-depletion chart** — makes θ_res unreachable by construction, deleting the clamp and
   restoring conditioning.
3. **Ecological (#62)** — a root-weighted whole-profile hydraulic criterion and/or inter-layer
   capillary redistribution, so the top layers do not park at ψ_crit indefinitely (the regime that
   sustains the blow-up).

**The arbiter is in (§2): FD plateaus at ~1e6; AD's 1e14 is spurious.** So the true gradient is
sane and finite — the model is not genuinely infinitely-sensitive — but our reverse mode manufactures
a ~1e8 error because it differentiates the misspecified chart's near-singular *discrete* trajectory
(diverging `∂a/∂θ`, clamps, ψ-ceiling) exactly, where FD averages over it. This is precisely the
class the reformulation thread named: on a well-conditioned chart the discrete near-singularity is
gone and **adjoint == FD** (their T3 = 1e-7). Conclusion: **the chart is the root cause; a leaf-partial
patch on the current chart would be treating a symptom the reformulation deletes.**

---

## 6. Recommendation

1. **Do not ship a resident TF24 gradient at life ≥ 3 on the current chart.** It is either wrong
   (spurious) or faithfully near-singular (unusable) — the sweep decides which, but neither is a
   gradient to trust.
2. **Adopt R-C + R-D for TF24** (they are `plant`-side model changes: `leaf_model.cpp` vulnerability
   shutoff; soil state in `ζ`). This is the shared fix for the forward stepper and the reverse
   gradient. Coordinate with the multirate branch — the prototype and validation already exist there.
3. **File the reverse-mode witness** back to the plant#60/#62 thread: the resident reverse-AD
   blow-up is a fourth, independent confirmation (after forward step-collapse, the dead-gradient T1,
   and the 5–6-order adjoint-vs-FD kink discrepancy) that the dry-end chart is the root cause.
4. **The FD-step arbiter is settled (§2): the true gradient is ~1e6, AD's 1e14 is spurious.** Do NOT
   invest in a leaf-partial patch on the current chart first — it would treat a symptom the
   reformulation deletes. The reformulation (R-C + R-D) is the fix for both value and gradient.
