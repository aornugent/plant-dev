# TF24 resident reverse-AD gradient: an investigation of the life ≥ 3 blow-up

_Session 10 (2026-07-21), branch `claude/odelia-ad-tape-reverse-496fuf`. This is an **objective log of
my own investigation** into a specific defect: the resident TF24 reverse-mode gradient is correct at
short patch lifetimes and blows up at longer ones. It records what I measured, what those measurements
establish, and what remains open. A superficially similar pathology exists on the forward-solver side
(the multirate-stepper review, branch `claude/multirate-stepper-review-r6dpwn`); §5 treats that as an
**unverified, possibly-unrelated** parallel and proposes how to test the linkage — it does **not**
assume it. Quotes from other docs are verbatim and attributed._

_Standing caution (mine, this session): I twice over-concluded from a non-representative probe
(bound-regime observations from a frozen-p\* chain that the real path never enters). Every claim below
is tagged **[measured]** or **[hypothesis]**. Gradients are the sharpest diagnostic we have here — I am
the first to add them to this model — so the aim is to let a gradient identify the exact defect, not to
pattern-match a symptom._

---

## 1. The system being differentiated (formulation)

A patch integrates one coupled IVP `y' = f(y, t; θ)` on `[0, T]`, `θ` the seeded traits/parameters,
reduced to a scalar metric (here Σ cohort height). `y` has two blocks:

- **Cohorts `x ∈ ℝ^M`** (`M` grows with patch age). Per cohort: transported log-mass `λ`, height,
  allocation states. Rate `ẋ_j = φ(x_j, u, s(x))`; `φ`'s carbon engine is an **iterative leaf solve**
  (§1.1) that **reads the soil state**. `s(x)` is the cheap competition/light aggregate.
- **Soil `u ∈ ℝ^L`, `L = 5`** — volumetric water content `θ_soil` per layer. Rate
  `dθ_ℓ/dt = (inflow_ℓ − K(θ_ℓ) − uptake_ℓ)/dz`, with drainage `K(θ) = K_sat·(θ/θ_sat)^{2n_ψ+3}`
  (`≈ θ^16.14`) and matric potential `ψ_soil(θ) = a_ψ·(θ/θ_sat)^{−n_ψ}` (`≈ θ^{−6.57}`, capped at
  `soil_psi_max_ = 1e3 MPa`). The leaf reads `ψ_soil`; its uptake feeds back as the soil sink.

Two-way coupling: leaf → uptake → soil state → ψ_soil → next leaf. **This closed soil-water loop is
where the blow-up lives (§2).**

### 1.1 The leaf operating point

Per cohort, TF24 solves a water/carbon optimum: collar potential `p*` by golden-section max of profit
over `[bound_a, bound_b]`; ψ_stem and c_i by nested root-finds; a Weibull vulnerability `exp(−(ψ/b)^c)`
with stem-critical `ψ_crit`. Regime branches (`leaf_model.cpp`): **interior** optimum; **bound**
(`p*` at `bound_b`, ψ_stem pinned at ψ_crit); **shutdown** (`profit = −R_d − hydraulic_cost(ψ_crit)`).
The leaf is `double`-only; its parameter sensitivity reaches the tape via `supplied_derivative` — the
leaf re-assembled as active scalars on a per-call local tape (`assemble_leaf_from`, P2c steps 5–6),
injecting exact `d(profit)/d(input)` and `d(uptake_ℓ)/d(input)` into the run tape.

---

## 2. What I measured (my investigation)

Certificate: reverse-AD gradient vs a pinned-schedule central FD, per seeded field, across patch
lifetime (`scratchpad/tf24_cert.R`; parallelised driver `ad_certificate.cpp`).

| life | ode_times | max\|ad\| | max\|fd\| | |
|---|---|---|---|---|
| 1–2 | 128–165 | ~5e5 | ~5e5 | clean [measured] |
| 3 | 203 | 1.65e10 | 9.2e5 | blow-up begins [measured] |
| 4 | 361 | 2.56e14 | 1.2e6 | all channels BLOWN [measured] |
| 10 | 1664 | — | — | reverse run OOMs >15 GB [measured] |

Localisation (session 10; all env-guarded diagnostics since reverted, tree clean):

- **[measured] AD-only, sharp onset, uniform.** FD/double grows smoothly (5e5→1.2e6). Onset sharp
  (life 2→3), and at life=4 every seeded channel is off by the *same* ~1e8 ratio — one shared
  quantity's adjoint reaching all inputs. Reproduced identically via the monolithic driver (not a
  refactor artifact).
- **[measured] Not the leaf-assembly partial magnitude.** Injected leaf partials are bounded across
  all 495 826 leaf calls: `max|d profit/d input| = 9421`, `max|d uptake| = 3.0`. The interior p\*
  node's denominator `P_pp` is healthy (min ≈ 2.5); the bound regime is **never entered** (0/495 826).
- **[measured] It is the soil-water STATE feedback.** Zeroing the injected partials w.r.t. the
  `θ_soil`-state inputs drops `max|ad|` **2.56e14 → 3.05e5**. The soil feedback is a real channel (the
  killed value 3e5 is *below* the true `max|fd|` ≈ 1.2e6) that the reverse sweep **amplifies ~1e8**.
- **[measured] FD-step arbiter.** At life=4, `d(Σh)/d(theta)`: AD = −2.565e14; FD across `h` = 1e-2 …
  1e-5 = −1.154e6, −1.154e6, −1.157e6, −1.147e6, −1.199e6, −1.077e6, −1.544e6 — a **flat plateau at
  ~1.15e6 over three decades of `h`** (smallest-`h` wobble is roundoff; the `omega` column sign-flips
  there). FD does not climb toward AD.

**[measured→inferred] What the arbiter establishes.** The true (smooth-model) sensitivity is a sane
~1e6; the AD's 1e14 is spurious by ~1e8. AD is the *exact* derivative of the discrete recorded
computation, and FD (a secant of the *same* computation) plateaus far below it — so the recorded
forward computation is **non-smooth or near-singular at the operating point** in the soil-water loop:
AD returns a one-sided/near-singular slope, FD secants across it. This is a genuine defect of the
gradient as computed on the current discretisation; the value path is unaffected (double bit-identical).

**[open] What I have NOT yet localised.** *Which* recorded operation in the soil-water loop is
non-smooth/near-singular, and whether the injected per-call `d(uptake_ℓ)/d(θ_soil)` partials are
themselves wrong or merely correct-but-amplified through the recorded soil ODE. The decisive probe is
in §4.

---

## 3. Candidate mechanisms (mine, hypotheses to test)

Given the arbiter (a near-singular/non-smooth recorded op in the soil loop), the concrete suspects,
each falsifiable:

- **H1 — the retention curve `ψ_soil = a_ψ·θ^{−6.57}`.** `dψ/dθ ∝ θ^{−7.57}` is genuinely huge as a
  layer dries; the leaf reads ψ_soil, so `d(leaf)/dθ_soil` inherits it. This is steep but *smooth*, so
  it should not by itself make AD ≠ FD (FD sees the same slope). Only becomes a discrepancy if composed
  with a non-smooth op below.
- **H2 — the ψ-ceiling cap `min(ψ, 1e3)`.** A hard clamp; where active, `dψ/dθ` switches to 0.
  *Against H2:* the soil equilibrates at ψ ≈ 0.02–3.9 MPa in real runs (R-D doc §3; #62 evidence), far
  from the 1e3 cap — so probably not hit. **Check directly.**
- **H3 — a leaf regime switch** (interior↔bound↔shutdown) moving through cohorts as layers dry: a
  moving kink in the aggregate whose subgradient AD ≠ FD secant. *Partly against:* bound never entered;
  shutdown frequency not yet measured. **Check shutdown/interior switching over the run.**
- **H4 — the injected `d(uptake_ℓ)/d(θ_soil)` partial is wrong** (bounded but incorrect), compounding
  through the soil ODE reverse. **This is the one the §4 probe settles directly.**
- **H5 — a positivity/finite-state guard** on the soil ODE (`check_finite_ode_state`, an infiltration
  `min/max`) non-smooth in the dry regime.

I will not privilege any of these by resemblance to the forward-side story; §4 discriminates.

---

## 4. The decisive gradient diagnostic (next step)

Use the gradient at the finest grain it affords: **compare the injected per-call leaf partial to a
re-solve double FD of the real leaf**, at real dry-regime operating points, isolated from the SCM
feedback.

Driver (standalone, no SCM loop): set up a TF24 strategy + environment at a swept soil state (wet→dry,
spanning the θ ≈ 0.11–0.16 transition), and for one `net_mass_production_dt` call compute
`d(profit)/d(θ_soil_ℓ)` and `d(uptake_ℓ)/d(θ_soil_ℓ')` two ways:
1. **AD** — one reverse call through the real `assemble_leaf_from` + `supplied_derivative` path (the
   injected partial), and
2. **FD** — perturb that soil layer's potential, re-run the double leaf solve, central difference.

- **If AD ≠ FD per call** → the leaf soil-coupling partial is wrong (H4): defect localised to
  `assemble_leaf_from`, and the mismatched input/output names the term. Fix it there.
- **If AD == FD per call** across the sweep → the per-call partials are correct; the ~1e8 is
  manufactured by the **recorded soil-ODE reverse propagation** compounding a correct-but-stiff
  feedback (H1/H3/H5 territory) — a different fix (smooth the offending recorded op, or the chart).

This is the localization I deferred earlier; it is the right next action and I should not have written a
synthesis ahead of it.

---

## 5. The forward-side parallel — possibly related, NOT established

The multirate-stepper review (`claude/multirate-stepper-review-r6dpwn`) describes a forward-solver
step-collapse on a system with the same block structure (their `x`/`u` split maps to cohorts/soil), at
the dry soil bound. I read the load-bearing docs directly. Points of genuine interest — and the reasons
to be cautious about assuming it is my problem:

- Their diagnosis is **forward accuracy-driven step collapse**; mine is a **reverse-mode gradient
  blow-up**. These *can* share a root (a near-singular coupling) but need not: a step controller and an
  adjoint sweep fail on different things.
- Their reformulation thread proposed **R-C** (smooth vulnerability shutoff) and **R-D** (log-depletion
  chart `ζ = ln(θ − θ_res)`). **R-D was measured to do very little to the numerics and was reverted** —
  its own doc says it "buys code-cleanliness and a structural guarantee, not performance or robustness,"
  and the RODAS benchmark shows "`ζ+RKCK ≈ θ+RKCK` at every stiffness." So R-D is **not** a fix to
  reach for on faith.
- One forward-side measurement *is* directly checkable against mine: their T1 found the ψ-ceiling floor
  gives `∂uptake/∂θ = 0` for θ < 0.11 (a *dead* gradient — AD too small). My blow-up is AD *too large*.
  Opposite sign of defect; if both are real they are different events (mine in the θ ≈ 0.11–0.16
  transition, theirs at the floor).
- Their reformulated prototype reported adjoint == FD to 1e-7 — but on a **windowed, self-contained
  soil block**, not the resident coupled SCM run where my blow-up occurs.

**How to test the linkage (empirically, before claiming it):** cherry-pick R-C (and, separately, R-D)
from the multirate branch onto this branch, rebuild, and re-run my certificate at life = 3/4. If R-C
alone collapses `max|ad|` to ~1e6, my defect *is* the dry-end shutoff non-smoothness and R-C is the fix.
If neither changes my blow-up, the problems are distinct and I fix mine (via §4) on its own terms.
Until that experiment runs, I will not link this evidence to plant#60/#62.

---

## 6b. RESOLUTION (the actual bug — a sign error, found by the §4 gradient diagnostic)

The §4 per-call diagnostic ran (`TF24_LEAFFD`, in-place AD-vs-re-solve-FD at dry/tall calls): the
injected `d(profit)/d(psi_soil_L)` partials are **wrong** — a clean **sign flip** (ratio −1, magnitude
exact) on the dominant layers, plus magnitude errors on the wettest layers:

| layer | psi_soil | injected | re-solve fd | ratio |
|---|---|---|---|---|
| 0 | 0.272 | +2.3254 | −2.3254 | −1.00 |
| 1 | 1.500 | +0.1136 | −0.1230 | −0.92 |
| 2 | 0.740 | +0.0348 | −0.0348 | −1.00 |
| 3 | 0.222 | +0.0128 | +0.1141 | +0.11 |
| 4 | 0.132 | +0.0036 | +0.2092 | +0.017 |

**Root cause [measured/confirmed]:** the local tape seeds `lpsi[L] = −psi_soil_S[L]` (the leaf's
`psi_soil_inverted_` convention) but injects the resulting `d(·)/d(lpsi)` against the run-tape input
`psi_soil_S` **without the chain-rule factor `d(lpsi)/d(psi_soil_S) = −1`**. So every soil-state
partial is sign-flipped. A sign-flipped feedback partial turns the soil-water loop's negative feedback
positive → the resident reverse sweep amplifies exponentially once the soil dries (life ≥ 3) — the
blow-up. Negligible at life ≤ 2 (soil near-static), matching the sharp onset.

**Fix (plant, this session):** negate the `src==3` (psi_soil) partials at injection —
`profit_partials[k] *= (src[k]==3 ? -1 : 1)`, likewise `uptake_partials`. Active branch only; double
path bit-identical.

**Result:** the blow-up is gone. life=3 `max|ad|` 1.65e10 → **3.71e5**; life=4 2.56e14 → **5.31e5**
(vs `max|fd|` 9.2e5 / 1.15e6); no BLOWN class.

**Residual [measured, OPEN] — localised precisely.** After the sign fix: certificate life=1 clean
(~0.99); life=2 PARTIAL (~0.75–0.92, right sign); life=4 `max|ad|` 5.3e5 vs `max|fd|` 1.15e6 (~0.46,
signs now mixed). Re-running the per-call diagnostic (post-fix) pins it:

| layer | psi_soil | profit inj/fd (ratio) | uptake inj/fd (ratio) |
|---|---|---|---|
| 0 | 0.272 | −2.325 / −2.325 (1.0) | (1.15) |
| 1 | 1.500 | −0.114 / −0.123 (0.92) | (1.0) |
| 2 | 0.740 | −0.035 / −0.035 (1.0) | (1.0) |
| 3 | 0.222 | −0.0128 / **+0.114** (−0.11) | (1.0) |
| 4 | 0.132 | −0.0036 / **+0.209** (−0.017) | (1.0) |

**The per-layer `uptake` partials are now ALL correct (ratio 1.0)** — the sign fix fully fixed them.
The residual is only in the **profit** partial, and only for the **wet deep layers (3,4)**: they have
*tiny* uptake sensitivity (~1e-6) yet a *large positive* profit FD (+0.11, +0.21). So profit's
sensitivity to a wet layer flows **not through that layer's uptake but through the collar
re-optimisation (the p\* channel)** — which the assembly mishandles for weakly-coupled layers. By the
envelope theorem this p\* channel should be ~0; the fact that the re-solve FD sees it large means the
leaf is **not at a stationary interior optimum** there (flat / near-fold), so either the interior p\*
node's `dp*/dpsi_soil` is wrong OR the single-leaf re-solve FD is itself noisy at the flat optimum
(**not yet disambiguated — do not over-conclude**). This is a leaf-adjoint issue (the p\*/envelope
channel), still NOT the chart. Next: (a) h-sweep the single-leaf FD for L=3,4 to test if it is a real
plateau or noise; (b) check `dprofit/dp*` at those operating points (stationary or not); (c) if real,
fix the p\* channel's `dp*/dpsi_soil` for weakly-coupled layers. The SCM-level residual (0.46, from the
trusted pinned FD) is real regardless of (a).

**Correction to my earlier framing:** the "chart misspecification / near-singular discrete trajectory /
possibly the same as the forward step-collapse" reading in §5 was NOT the cause of this blow-up. The
cause was a plain sign bug in my own soil-coupling adjoint. The forward-side reformulation material
remains a separate, unproven line; do not link.

## 6. Where this stands

- **[established, mine]** The resident TF24 reverse-AD gradient is wrong at life ≥ 3 by ~1e8; the true
  gradient is ~1e6 (FD plateau); the defect is a near-singular/non-smooth recorded operation in the
  soil-water feedback loop; the value path is unaffected.
- **[not established]** Which operation; whether the leaf partial is wrong vs amplified; whether this is
  the same problem the forward-side review found.
- **Next actions, in order:** (1) run the §4 per-call AD-vs-FD leaf diagnostic to localise; (2)
  independently, cherry-pick R-C and R-D and measure their effect on my certificate (§5 experiment);
  (3) only then decide the fix and whether to link to plant#60/#62.
- **Do not** ship a resident TF24 gradient at life ≥ 3 until this is resolved; FF16/K93 gradients are
  unaffected (no soil coupling).
