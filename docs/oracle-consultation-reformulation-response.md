# Oracle response — reformulation: one cause, three symptoms; the state carries the wrong asymptotics

*Response to [`oracle-consultation-reformulation.md`](./oracle-consultation-reformulation.md). Recorded
verbatim (lightly reformatted). Dated 2026-07-17. Hypotheses to test, not verdicts (guide §7); the
response names **T1 (fit the sink exponent γ, evaluate the Osgood integral) as the experiment that decides
everything** — run it before building. Note the response **reverses an earlier round's ruling** against the
log transform, on the strength of the new decomposition.*

---

## One cause, three symptoms — and the state is carrying the wrong asymptotics

Verdict first. The near-bound difficulty is a single mechanism — **extraction responds to scarcity through
a steep power law, so the sink shuts itself off non-Lipschitz-fast as the stock empties** — expressed as
three symptoms of *different status*: the **stiffness is intrinsic** (it is a residence time, and no change
of variables touches it); the **singularity is a chart artifact** (the u-chart puts bounded physics through
unbounded coefficients, and also through a catastrophic floating-point range); the **clamp is a derived
object** (either a numerical guard for a boundary the continuous model cannot reach, or a stand-in for
member shutoff physics — in neither case is a hard clamp on `u` the right primitive). One measurable
exponent decides the whole design, and you can fit it from data you already have.

## 1. The intrinsic core: the fast rate is throughput over stock (Q1's obstruction)

Near the bound the self-loss is microscopic (`κu^p`, `p≈16`, at small `u` — your measurement 2's "≥99%
remains" is exactly this), so the local balance is `a(x,u*) ≈ r`. Let `δ` be the distance to the singular
point and write the aggregate sink's local behavior as `a ≈ A·δ^γ`. Your measured divergence
`∂a/∂u ~ δ^{γ−1}` says `γ < 1`. Then:

```
δ* ≈ (r/A)^{1/γ},     λ = a′(δ*)/d = γ·r/(d·δ*)   —   turnover = throughput / stock.
```

That eigenvalue is chart-invariant: at a hyperbolic quasi-equilibrium, the linearization's spectrum
transforms by similarity under any state diffeomorphism (the drift-curvature correction is subdominant
exactly where the mode is fast). And it *genuinely diverges* as inputs dry: `λ ∝ r^{1−1/γ} → ∞` as
`r → 0` with `γ < 1`. A nearly-empty pool with finite flux through it turns over fast — that is physics, not
representation. **No coordinate removes it; it must be stepped over (implicit/Rosenbrock on an L ≤ 5 block —
cheap) or slaved (DAE) where it is fast.**

This also reconciles your two apparently conflicting regimes into two near-bound sub-regimes: the **fall**
(input collapses, the old balance evaporates, `u` genuinely moves fast — accuracy-limited, no method
enlarges those steps) and the **floor** (sitting at the depleted balance, slaved by the diverging feedback
— stability-limited, where explicit dies and implicit takes steps set by the *slow* drift). Expect the step
budget to split accordingly: implicit + the right chart should expand floor steps by roughly
`λ_floor/λ_slow` and leave fall steps alone.

## 2. The chart: log-depletion if the bound is unreachable; the (1−γ)-power if contact is real (Q1's answer)

The deciding test is Osgood reachability of the bound under worst-case input (`r = 0`): is
`∫₀^{δ₀} d·dδ / S(δ)` finite, `S` the total sink? Two cases:

**Case A — unreachable (likely, given your own structure).** You report members cross shutoff thresholds as
the bound is approached. Once the last member shuts off, `S ~ g ~ κδ^p` with `p ≈ 16`, and the integral
diverges enormously: the continuous trajectory *freezes just below the last shutoff and never contacts the
bound*. The clamp is then purely a guard against **discrete overshoot in the u-chart** — a linear step
crossing a curved invariant boundary. The right chart is the **log-depletion coordinate**

```
ζ = ln δ      (affine to ln φ:  ln φ = ln B − q·ζ  —  log-scarcity is the same chart)
ζ′ = ( r − g − a ) / ( d·e^ζ )      — every original process ↦ its specific (per-stock) rate
```

with these properties, each removing one pathology at zero approximation cost: the coupling slope becomes
`∂a/∂ζ = δ·∂a/∂δ ≈ γ·a` — **bounded by the flux itself**; the member problem is fed `ln φ = lnB − qζ`
directly, so **no singular composition and no floor exist anywhere on the tape** (the floor inside `φ` is a
second, hidden clamp — a zeroed gradient channel whenever active — and it dies with the chart); **positivity
is structural** — no finite step in ζ can cross a boundary at −∞, so the clamp's job is deleted rather than
smoothed; and **floating-point conditioning is restored** — `φ = u^{−6.6}` spans ~15–20 orders across a
2–3-order range of `u` (surely why the floor exists), while ζ spans O(10). Term-by-term interpretability is
preserved and arguably improved: each process appears as its specific rate, the natural per-capita form.
Costs: the discrete trajectory changes (a documented re-discretization, allowed by your ground rules); the
error controller now measures *relative* error in δ — decide that deliberately, though it is almost
certainly what you want near the bound.

I should own a reversal here: in an earlier round I ruled out the log transform on the grounds that
depletion-to-contact at finite rate was real physics. Your new decomposition — self-terms ~1% of the
spectral radius, the sink's feedback diverging, member shutoffs above the bound — is precisely the evidence
that reopens it. The Osgood test is the arbiter, and it is one integral over a curve you can measure tonight
(T1 below).

**Case B — contact is real** (pure power sink to the boundary, no shutoff floor): then finite-time
extinction is genuine, the log chart would chase ζ → ∞ in finite time (the difficulty *moved*, not removed —
the failure mode your "without moving it elsewhere" clause is guarding against). The correct chart is the
desingularizing power `z = δ^{1−γ}`: touchdown becomes a **regular transversal crossing**
(`z′ → −(1−γ)A/d`, finite, at `z = 0`), the coupling slope `∂a/∂z` is a bounded constant, and contact is
handled as a located event + pinned active set with the standard event adjoint. Same machinery you already
have; the chart just makes the event ordinary instead of singular.

## 3. The clamp and the member thresholds are the differentiability story (Q2)

Your 5–6-order gradient discrepancy has a precise anatomy: a member crossing its threshold moves a kink
*through the aggregate*, whose θ-derivative contains a Leibniz boundary term `[jump]·d(location)/dθ`. A
subgradient tape drops that term entirely; FD smears it over the perturbation; the ratio between "missing"
and "smeared" is unbounded. Smoothing the switch at a declared scale is the correct model-side fix — it
converts the boundary term into an ordinary smooth contribution (your 1e-9 agreement is the confirmation),
it *also* rescues the member-quadrature's convergence order (a kink crossing collocation nodes destroys it),
and it rounds the corner of `a(δ)` itself, nudging the system toward Case A. The exact alternative — an
active root at the crossing with split quadrature — remains available if the smoothing scale is ever
scientifically contested. Either way, note the composition: chart (deletes the u-clamp and the φ-floor) +
declared smoothing (deletes the member-threshold kinks) leaves **no nonsmooth object near the bound at all**
in Case A, and exactly one well-posed event in Case B.

## 4. What remains after the chart, and the structure that makes it cheap

Stiffness remains, by §1 — but now with smooth, bounded, closed-form coefficients, which is all an implicit
method needs. Two structural facts make the implicit treatment nearly free. First, the u-block Jacobian is
**lower-bidiagonal (cascade) + diagonal (self-loss and own-component coupling feedback)**: the cascade is
one-directional, so it creates no feedback loops — the spectrum is (real, negative) diagonal entries if
`a_i` reads mainly `φ(u_i)`, and remains real-dominated with a small dense correction otherwise. Check
eigen-realness in the decomposition data you already have: real spectrum means no oscillatory stiffness,
Rosenbrock solves by forward substitution, and better adjoint conditioning. Second, the DAE/slaving limit
(u algebraic at the floor) exists as the `λ → ∞` idealization; with L ≤ 5 and a Rosenbrock in the right
chart achieving the same step sizes, I would document it and not build it unless floor steps still dominate
after the chart change.

## 5. Ranking (Q3)

The **true source is neither the balance form, nor φ, nor the clamp alone — it is the composition `a∘φ`
near the bound, summarized by the effective sink exponent γ** (equivalently the Osgood integrability of the
total sink). φ supplies the divergence, but the member response could have neutralized it; your measurement
says it doesn't until the shutoffs. Given that: load-bearing — γ and the shutoff structure (they pick the
chart and decide Case A/B); the capacity `d` (the only knob in the intrinsic rate); the member thresholds
(the differentiability site). Derived — the clamp and the φ-floor (guards standing in for chart deficiency
or shutoff physics). Incidental — the balance form otherwise; the large-p self-loss near the bound (your
measurement 2; it matters only episodically at the top, where the same stepper absorbs `g′ ~ 10³–10⁴`); the
cascade (no loops — but see below); the kinked forcing (schedule-aligned splits, plus one more smoothed
switch in the attenuation `max(0, 1−α(u/u_max)^β)` at the upper end); the O(M) cost (an orthogonal axis,
except that the thresholds live inside the aggregate, tying the smoothing scale to the member model).

## 6. What you're missing (Q4)

The cascade telescopes: `Σ d_i u_i′ = r_1 − g(u_L) − Σ_i a_i`. The total stock `D = Σ d_i u_i` obeys a
single scalar balance with only the *end* loss and total extraction — a free invariant that exercises every
coupling channel, in value **and** in gradient (`∂D(T)/∂θ` must equal the time-integral of the boundary
terms' sensitivities): harness gold of the same rank as the earlier mass identity. Second, γ is already in
your data — the slope of your measured `∂a/∂u` divergence on a log-log axis is `γ − 1`; no new
instrumentation. Third, the fall/floor decomposition of §1 turns "implicit manages but does not remove" into
a quantitative prediction you can falsify (floor steps expand by `λ_floor/λ_slow`; fall steps don't).
Fourth, the conditioning point is not cosmetic: any quantity computed through `u^{−q}` near the bound is
currently losing most of its significand before the tape ever sees it — the chart is also the numerically
honest representation of the model you already have.

## 7. Tests, in order

**T1 (decides everything):** at a few frozen population states, sweep `u` toward the bound and record the
full sink curve `S(δ)` including shutoffs; fit γ; evaluate the Osgood integral → Case A or B, hence the
chart. **T2:** windowed prototype — chart + Rosenbrock on recorded episodes; predictions: clamp/floor
activations → 0 (Case A), floor step counts expand by the §1 ratio, fall steps unchanged, trajectory matches
tight-tolerance truth. **T3:** taped adjoint of the chart scheme vs FD-as-run (expect your smoothed-switch
1e-9), plus the telescoped-invariant gradient identity. **T4:** eigen-realness of the block Jacobian from
the decomposition you already ran — it licenses the cheapest stepper and certifies no oscillatory stiffness
is hiding in the cascade.

One-line summary: keep the stiffness (it's a residence time — hand it to a 5-dimensional implicit solve),
and stop representing bounded physics in a chart whose coefficients, floating point, and boundary all blow
up at the interesting end; the clamp, the floor, the singular slopes, and most of the gradient pathology are
the chart's artifacts, not the model's.

---

## Our reading / next action

**This is a genuine reframe, and it converges with our own measured decomposition.** The response accepts
the two-regime finding and re-reads it: the near-`u_min` difficulty is **one mechanism** (a steep,
scarcity-driven sink shutting off non-Lipschitz-fast) wearing **three hats of different status**:

| symptom | status per Oracle | consequence |
|---|---|---|
| **stiffness** | **intrinsic** — a residence time `λ = γr/(d·δ*)`, chart-invariant | keep it; hand the `L≤5` block to an implicit/Rosenbrock solve (cheap) — matches our committed micro-stepper |
| **singularity** (`ψ=θ^{−q}`) | **chart artifact** — bounded physics through unbounded coefficients + 15–20 orders of float range | change the state variable to log-depletion (Case A) or a power chart (Case B) |
| **clamp** at `θ_res` | **derived object** — a guard, not a primitive | deleted by the chart (Case A) or replaced by one clean event (Case B) |

**Mapping to TF24:** `u = θ` (soil moisture), `u_min = θ_res = 1e-2`, `δ = θ − θ_res`; the near-singular map
`φ = ψ(θ) = a_ψ(θ/θ_sat)^{−n_ψ}`, `q = n_ψ = 6.57`, diverging as `θ → 0`; the self-loss `g = K(θ) ∝ θ^{16}`;
the total sink `S(θ) = drainage K(θ) + root uptake a(θ)`; the member shutoffs = cohorts crossing the
water-stress cutoff as the soil dries. The Oracle's **"log-depletion coordinate"** `ζ = ln(θ − θ_res)` (or
`ln θ`) is a soil-model reformulation with a clean ecological reading: **integrate the model in
log-scarcity** — the natural variable is how close each layer is to the wilting point, on a log scale,
exactly the axis on which matric potential and plant stress are linear-ish. It keeps every process
term-by-term and, per the Oracle, deletes the positivity clamp, the `ψ` ceiling/floor, and the significand
loss at once.

**The reversal is notable and the guide anticipates it (§7 — Oracles are confidently wrong, and
confidently right, and only a test distinguishes them):** the same Oracle earlier ruled the log transform
out; the new decomposition reopened it; the **Osgood integral is the single arbiter**. So we run T1 before
adopting any chart.

**Next action — T1 (the decider), run before building:** at frozen stand states, sweep `θ` down toward
`θ_res` under **zero inflow** (the Oracle's worst-case `r=0`), record the **total sink** `S(θ) = K(θ) +
a(θ)` including the cohort shutoffs, fit the near-bound exponent γ, and evaluate the Osgood integral
`∫ dz·dθ / S(θ)`:
- **diverges → Case A** (bound unreachable; uptake shuts off above `θ_res`, leaving `S ~ K ~ θ^{16}`): adopt
  the **log-depletion chart** `ζ = ln(θ − θ_res)`; the clamp is a pure discrete-overshoot guard and is
  deleted.
- **converges → Case B** (contact real; uptake persists as `θ^γ`, `γ<1`, to the bound): adopt the **power
  chart** `z = (θ−θ_res)^{1−γ}` and treat touchdown as a located event.

Bonus, free from data in hand: **T4** — eigen-realness of the soil-block Jacobian (already computed in
`r1_split_payoff.R`) → licenses forward-substitution Rosenbrock and certifies no oscillatory stiffness; and
the **γ−1 cross-check** = slope of the measured `∂a/∂θ` divergence on a log-log axis.

## T1 measured (2026-07-17) — `scripts/tf24-multirate/t1_osgood_chart.R` — Case A *after* fixing the shutoff; a dead gradient channel found

Frozen stand, **zero inflow** (worst-case `r=0`), sweep `θ → θ_res=0.01`; total sink `S=K(θ)+uptake(θ)`
backed out of the real patch derivs; Osgood integral `τ=∫ dz·dθ/S`; plus the γ cross-check and T4
eigen-realness.

**Finding 1 — the current model's uptake does NOT shut off; it is floored with a dead gradient.** As `θ`
falls below ≈0.11, the retention-curve ceiling (`soil_psi_max_=1e3`, capping `ψ=θ^{−6.57}`) pins uptake at
a **constant** 5.2e-4 (≈6% of peak) and `∂uptake/∂θ = 0` all the way to the bound. This is precisely the
Oracle's predicted "**hidden second clamp — a zeroed gradient channel whenever active**" (§2). It is not
just a performance issue: **the reverse-mode gradient through uptake is silently zero for θ < ≈0.11** — a
latent correctness defect exactly where drought sensitivity matters.

**Finding 2 (T4) — the stiffness is in the stress *transition*, not at the bound, and its spectrum is
real.** Soil-block Jacobian eigenvalues:
- θ=0.13 (active water-stress transition): `−86.9, −11.3, −3.98, −1.54, −0.423` — stiff, **strictly real**
  (max|Im|/max|Re| = 0) → forward-substitution Rosenbrock licensed, no oscillatory stiffness hiding in the
  cascade (Oracle §4 confirmed).
- θ=0.02 (floor regime): Jacobian **identically zero** — no stiffness *and* no gradient (everything
  clamped/floored). The difficulty is entirely the **transition** θ≈0.11–0.16, i.e. the onset of water
  stress, not the bound itself.

**Finding 3 — the divergence exponent equals the retention exponent, confirming the chart.** The uptake
feedback diverges as `∂a/∂θ ~ δ^{γ−1}` with `γ−1 ≈ −6.56`, i.e. `γ−1 ≈ −n_ψ = −6.57`. So the near-
singularity is exactly the `ψ = θ^{−q}` composition, and `ln ψ = lnB − q·ln θ` is **linear in
log-scarcity** — the **log chart is the linearizing coordinate**, confirmed at the exponent level (§2).

**Finding 4 — Osgood: reachable as coded, unreachable once fixed.** With the artifact floor in place, the
zero-inflow drain time converges (`τ`: 29 → 49 → 59 → 65 → 70 → **72 d**, increments shrinking) → the bound
is **reachable in finite time** → a degenerate **Case B by artifact** (the constant-floor uptake keeps
draining). Remove the artifact — represent the water-stress shutoff correctly so uptake `→ 0` at the
wilting point (reformulation **R-C**) — and the total sink collapses to drainage `S ~ K ~ θ^{16} → 0`, the
Osgood integral **diverges**, and the system is **Case A (bound unreachable)**.

**Verdict — the reformulation is a composition, and it fixes a correctness bug as well as the numerics.**
1. **R-C (smooth water-stress shutoff)** is the *prerequisite*: it removes the ψ-ceiling floor and its dead
   gradient channel, restores the drought-sensitivity gradient, and — by making uptake vanish at the
   wilting point — puts the system in **Case A**.
2. **The log-depletion chart** `ζ = ln(θ − θ_res)` (equivalently log-scarcity `ln ψ`, since `γ−1 = −q`) is
   then the right state variable: it deletes the positivity clamp (a step in ζ can't cross a bound at −∞),
   deletes the ψ-ceiling, restores floating-point conditioning (`θ^{−6.57}` spans ~15 orders over a 1.5-order
   θ-range; ζ spans O(10)), and bounds the coupling slope — while every process stays term-by-term as its
   per-stock rate. The residence-time stiffness in the transition (real spectrum, T4) **remains** and is
   handed to the `L≤5` Rosenbrock solve, as the committed design already does.

The Oracle's binary sharpens to: **the model as coded is a degenerate Case B held up by an artifact you
should remove anyway; remove it (R-C) and you are in Case A, where the log-depletion chart is exactly
right.** Next: T2 (windowed chart + Rosenbrock prototype — clamp/floor activations → 0, transition steps
expand, trajectory matches truth) and T3 (taped adjoint of the chart scheme + the telescoped
`D=Σd_iθ_i` invariant), before building.

## T2 + T3 measured (2026-07-17) — `t2_logchart_prototype.R`, `t3_chart_ad.cpp`/`t3_test.R` — reformulation confirmed

Both windowed-prototype tests pass on a faithful self-contained soil block (drainage `θ^16` + cascade +
saturation-excess forcing + root uptake with a **smooth vulnerability shutoff**, R-C).

**T2 — forward (values), log-depletion chart `ζ=ln(θ−θ_res)` + Rosenbrock ROS2 vs a tight reference:**
- **Trajectory matches truth** — the chart is a re-discretization, not a model change: max|Δθ| ≈ 8e-5 at
  ζ-step H=0.02, degrading gracefully with H.
- **Zero clamp activations at every step size** — positivity is structural in ζ (`θ = θ_res + e^ζ > θ_res`
  always). With the smooth shutoff the trajectory also asymptotes to the bound (Case A), so no overshoot
  occurs in either chart — the clamp is unnecessary once the model is smooth, and *impossible to violate*
  in the chart.
- **Fall vs floor, as predicted.** Drying passage ("fall", accuracy-limited): ~4–10× fewer steps. Parked
  in the stiff water-stress transition ("floor", θ≈0.13, ψ≈4.5 MPa): explicit is stability-limited at 2000
  steps, ζ+ROS2 matches accuracy in **50 steps — 40× fewer**. The intrinsic residence-time stiffness
  remains (handed to the implicit solve); the chart makes those steps large and clamp-free.

**T3 — reverse (gradients), XAD tape of the log-chart scheme, adjoint vs FD-as-run:**
- **Adjoint == FD** to max_abs_err 1.7e-7 (rel 2.7e-8) on all three differentiable params (uptake scale,
  vulnerability midpoint, drainage scale).
- **The adjoint is exact; the residual is FD truncation, not adjoint error** — the eps_fd sweep scales the
  discrepancy as eps² (1e-4→1.7e-3, 1e-6→1.7e-7) down to the FD roundoff floor (~3e-9 at 1e-7). The classic
  "tape is exact, FD is noisy" signature. The smooth shutoff means no kink, so no B3-style degradation.
- **Telescoped conservation invariant holds:** `D(T)−D(0) = −0.22947` vs `∫(infil − K_bottom − Σuptake) =
  −0.22986`, residual 4e-4 (RK4 quadrature-limited); its *gradient* is the F=D(T) adjoint check above.

**Verdict — the reformulation is validated end-to-end.** Log-depletion chart + smooth vulnerability shutoff
(R-C + R-D): the forward scheme reproduces truth with the clamp/floor/singularity deleted and a 40× step
cut in the stiff regime, and the reverse-mode gradient stays exact for the scheme as run with the
conservation invariant intact. The residence-time stiffness is real and stays with the `L≤5` implicit
solve, as the committed design already provides. What remains is the production build itself: pose the soil
block in `ζ`, let the existing hydraulic vulnerability curve run smoothly to zero (removing the ψ-ceiling
floor and its dead gradient), and step it with the `L≤5` Rosenbrock — the same micro-stepper the multirate
design commits to, now in the honest coordinate.
