# Your noise-floor mechanism, tested: the floor is real but decoupled from the step size — a deep characterisation

A numerical-methods problem. No application context is given or needed. This **follows seven prior
rounds** on the same initial-value problem; the settled structure is restated inline so this stands
alone. Last round — given a measured refutation of the "removable-event" geography — you made a
**positive identification**: the step-size collapse is the embedded controller **bisecting against a
tolerance-independent noise floor** injected into the right-hand side by a **fixed-tolerance inner
bracketing search** (resolution floor `ε_p ~ (b−a)·φ⁻ⁿ ≈ τ`, where `τ` is the inner search's
bracket-width stop). You gave that diagnosis with its own falsification tests **E1** (measure the RHS
noise floor; sweep the inner tolerance and watch the floor walk down) and **E2** (tighten the inner
search at fixed outer tolerance; predict the rejection fraction collapses and the `h_min` wall drops,
`J` unchanged). You proposed a fix (converge the inner search off-tape, present it through an
implicit-function node) and, importantly, stated the refutation condition yourself: *"if the collapse
pattern is invariant in the inner iteration count, the mechanism is refuted and the residual is
genuinely intrinsic."*

**We ran E1 and E2.** The floor is exactly as you described **at the source** — and, by your own
criterion, **refuted as the step-size mechanism.** Below is not a defence of anything and not a set of
directed questions: it is the most complete, neutral characterisation of the system and its measured
numerical behaviour we can give, including a structural feature of the inner problem that neither of us
had written down. Please **re-derive what is going on from the structure and the data**, rank the
features yourself, and reject our framing — including your own prior one — wherever the numbers warrant.
Per your guidance to us, the refutation is stated bluntly, with numbers, and you are invited to update.

---

## 1. The system (established across prior rounds; do not re-litigate)

Initial-value problem `y' = f(y,t;θ)`, `y ∈ ℝ^N`, on `[0,T]`, integrated by an **adaptive embedded
explicit RK** (Cash–Karp 4(5)) with a local-error controller; `10³–10⁵` accepted steps at a single
global step size. State splits into:

- a **large block `x ∈ ℝ^M`** (`M ≈ 50–800`, growing as members are inserted on an adaptive schedule),
  each member `x_j` a low-dimensional sub-vector with an ordered scalar coordinate `ξ_j` and a
  non-negative weight `ρ_j`;
- a **small block `u ∈ ℝ^L`, `L = 5`**, an ordered chain of scalar reservoirs.

Coupling:
```
p_j*     = argmax_p  P(p ; x_j, u, s(x))          fixed-tolerance derivative-free bracketing search
ẋ_j      = g(x_j, u, s(x), p_j*)                                        j = 1..M
a_ℓ(x,u) = Σ_j ρ_j · c_ℓ(ξ_j, u, p_j*),   ℓ = 1..L          (channel 1: x→u, expensive, O(M))
u̇_ℓ      = b_ℓ(t) + T_ℓ(u) − a_ℓ(x,u)                                  (small-block balance)
s(x)     = cheap scalar aggregate of the whole large block             (channel 2: x→x, flat in M)
```

- **Channel 1 `a` (x→u):** a weight-weighted quadrature `∫ c(ξ,u,p(ξ)) ρ(ξ) dξ`; each `c_ℓ(ξ_j,u,p_j*)`
  is a byproduct of the same per-member solve that yields `ẋ_j`, so `a` costs the full O(M) solve set.
- **Channel 2 `s(x)` (x→x):** all-to-all among members through one cheap scalar; no `u`-dependence.
- **`b_ℓ(t)`** external forcing into reservoir `ℓ=1` (piecewise-smooth, known feature times); `T_ℓ(u)`
  an ordered one-way inter-reservoir transfer plus a **near-singular self-loss** `∝ u_ℓ^{q}`, `q≈16`,
  positivity-clamped at `u_min`.
- **The inner control `p_j*` is an argmax**, solved by a **fixed-tolerance golden-section bracketing
  search** with bracket-width stop `τ` (default `τ = 10⁻³`), returning the **midpoint of the final
  bracket** of width `≤ τ`. It was chosen over Newton/Brent deliberately: the reverse-mode tape
  differentiates through the member solve, and a fixed-tolerance search was believed to make `p_j*` a
  **smooth** function of its inputs. `∂P/∂p` is available **exactly** (implicit-function theorem +
  forward-AD of the analytic objective — this is in the code; it is *not* an envelope finite
  difference). The member solve first selects among feasibility branches (switch-off / zero-flux /
  degenerate-bracket / full search); prior instrumentation showed `≥99.7%` of solves take the full
  search and the degenerate-bracket branch fires **never**.
- **Downstream:** reverse-mode gradients (a tape over every RK stage) of a scalar functional
  `J = Σ tw_j · φ(x_j)` w.r.t. small `θ`; the gradient must match a finite difference of the solver as
  run.

**Established quantitative facts (still standing):** `J` is **~10× hypersensitive** to coupling error,
with **~23% spread** between independently converged schemes at large `M`; global explicit RK reaches
converged `J` at modest tolerance and only fails ~3 decades past `J`-convergence at an `h_min` wall;
**~27–35% of step attempts are rejected**; scattered minimum steps `~10⁻⁸..10⁻⁹·T`; the prior round's
instrument showed the collapse is **broadband** — it does **not** co-locate with any event surface
(rejections within ±1 step of a branch/clamp flip: median 2%), and the only (weak) continuous
correlate of `log(step)` is the argmax feasible-interval width (`ρ≈0.24–0.42`).

---

## 2. Your hypothesis, and what E1/E2 measured (the payload)

### E1 — the inner floor exists at the source, and scales exactly as you predicted (confirmed)

Freeze the member solve; sweep one continuous state input finely; measure each output's deviation from
a near-exact reference solve (`τ = 10⁻⁸`) at `τ ∈ {10⁻³, 2.1·10⁻⁵, 4.5·10⁻⁷}` (i.e. `τ`, `τ·φ⁻⁸`,
`τ·φ⁻¹⁶`). Log–log slope of the deviation vs `τ`:

| quantity | slope | your prediction | result |
|---|---|---|---|
| argmax location `p*` | **1.10** | ~1 (`floor ~ τ`) | ✅ confirmed |
| a non-stationary output (`c`, `g` ingredient) | **1.01** | ~1, `O(ε_p)` | ✅ confirmed |
| the objective value `P(p*)` | **1.06** | **~2**, `O(ε_p²)` (envelope) | ❌ **refuted** |

So the argmax and the RHS ingredients it feeds do carry a floor `~τ` — **P1/P2 of your mechanism are
real.** But the "envelope asymmetry" you called the sharpest tell — objective error `O(ε_p²)` while the
non-stationary outputs err `O(ε_p)` — is **not there**: the objective errs `O(ε_p)` too.

### The reason the envelope fails: the argmax is a CORNER, not a smooth interior maximum

Mapping the objective `P(p)` finely across its optimum at fixed state (this is new — neither of us had
written the local geometry down):

```
 p − p*     P(p) − P(p*)
 −3·10⁻³     −1.500       ← wet side of p*: a near-vertical wall (a jump of fixed
 −1·10⁻⁴     −1.500          magnitude ~1.5; the "slope" is +5·10² → +5·10⁴ as the
  0           0              offset shrinks) sitting on a flat shelf 1.5 below the peak
 +1·10⁻⁴     −8.8·10⁻⁴    ← dry side of p*: a smooth linear decline, slope −8.8 (a
 +3·10⁻³     −2.6·10⁻²       finite O(1) constant)
```

`p*` is the **corner** at the top of the wall — the wet end of a smooth, **monotone-decreasing**
branch. It sits a small fixed distance (`~1%` of the feasible width, `~0.01` in coordinate units)
**inside** the feasible interval, above the wet feasibility boundary. `∂P/∂p` at `p*` is `≈ −8.8`,
**nonzero** — there is **no interior stationary point.** This holds across the state range (verified
wet→dry): a jump-wall on the wet side when the driving reservoir is benign, a flat-left / steep-right
kink when it is depleted; never a smooth `∂P/∂p = 0` maximum.

Consequences that fall straight out:
- It **explains E1's objective slope exactly**: no stationarity ⇒ `P(p*_τ) − P(p*_true) ≈ (−8.8)·(p*_τ
  − p*_true) = O(ε_p)`, not `O(ε_p²)`. The envelope theorem never applied because there is no interior
  optimum.
- The `O(ε_p)` "floor" you identified is really **the finite-precision location of a corner**: the
  bracketing search brackets the corner to width `τ` and returns its midpoint, so `|p*_τ − p*_true| ~
  τ` and every output carries `(one-sided slope)·τ`.

### The argmax *location* is smooth in state (even though the objective has a corner in `p`)

Separately: `p*(state)` traced against a smoothly-varying state input is **linear to the floor** (fit
slope `−1.0004`, max residual `≈ 4·10⁻⁵ ≈ τ`). So the corner *moves smoothly* with state; the member
outputs `c(p*(state)), g(p*(state))` are therefore smooth in state up to the `O(τ)` staircase. The
non-smoothness is in `P`-vs-`p` at fixed state, **not** in `p*`-vs-state.

### E2 — tightening the inner search does NOT change the step size (refuted, by your own criterion)

Rerun the full bank (five long sequences) at fixed outer tolerance `10⁻⁶`, inner tolerance `τ = 10⁻³`
vs `10⁻⁶` (a 1000× reduction of the floor):

| sequence | reject frac `τ=10⁻³` | reject frac `τ=10⁻⁶` | `h_min` (both) |
|---|---|---|---|
| A | 0.286 | 0.298 | `1·10⁻⁶·T` |
| B | 0.277 | 0.273 | `1·10⁻⁶·T` |
| C | 0.281 | 0.278 | `1·10⁻⁶·T` |
| D | 0.307 | 0.304 | `1·10⁻⁶·T` |
| E | 0.205 | 0.204 | `1·10⁻⁶·T` |

**The rejection fraction is invariant to a 1000× change in the floor, in every sequence.** By your
stated criterion, the noise-floor mechanism is **refuted as the step-size driver.** Two further facts:
- **The `h_min` wall is a configuration artifact**, not an emergent floor: `h_min` is *identical* in
  every run and equals exactly the solver's configured minimum step size (`= 10⁻⁶·T`), at which the
  controller is clamped and forced to accept. The "resolution limit, not stability limit" you recalled
  from an earlier round is neither — it is a hard-coded ⌊h⌋.
- The source floor is real (E1) but does not reach the controller. A plausible reason: the ripple is a
  **deterministic** function of state (same `y` → same `f`, bit-reproducible), so its systematic
  contribution largely **cancels in the embedded difference** `y₅ − y₄` across stages; and empirically,
  driving the floor from `10⁻³` (three decades above outer tol) to `10⁻⁶` (at outer tol) changes the
  rejection fraction by `<0.02`. Whatever sets the `27–35%` rejection, it is not the inner resolution.

### The one place the inner floor *does* bite: the reverse functional `J`, discontinuously

On sequence C (alternating extremes), the functional `J` as a function of the inner tolerance:

| `τ` | `J` |
|---|---|
| `10⁻³` (production default) | `1.412·10⁻⁷` |
| `10⁻⁴` | `5.90·10⁻⁸` |
| `10⁻⁵` | `1.413·10⁻⁷` |
| `10⁻⁶` | `5.871·10⁻⁸` |
| `10⁻⁸` | `5.868·10⁻⁸` |

**Non-monotone**, converging to `≈5.87·10⁻⁸` only for `τ ≤ 10⁻⁶`; the production default is **2.4×
wrong**. This is a **threshold bifurcation in the functional**: a marginal member's presence/absence in
the weighted reduction `J` flips as the `O(τ)` corner-location error nudges it across a survival
boundary in the full nonlinear trajectory. It is the "`J` is ~10× hypersensitive" fact made concrete —
and you **cannot tighten your way out reliably** (the value oscillates before it settles). The inner
floor is invisible to the forward step-size controller (E2) but **not** to the reverse functional.

---

## 3. Two decoupled behaviours — the central puzzle

The measurements split the problem cleanly into two behaviours that we had assumed were one:

- **Speed** (step size, rejection fraction, `h_min`) is **invariant** to the inner floor (E2), and — from
  the prior round — does not co-locate with events either. The `27–35%` rejection and the scattered
  small steps remain **unexplained**: not events, not the inner resolution. They track only weakly and
  continuously the inner feasible-interval width and reservoir depletion.
- **Accuracy** (the reverse functional `J`) **is** sensitive to the inner floor, but **discontinuously
  and non-monotonically** — a survival-threshold bifurcation, not a smooth floor — and only in
  bifurcation-prone sequences. Elsewhere `J` moves `<10⁻³` between `τ=10⁻³` and `10⁻⁶`.

So the inner search is **not** the speed lever (its floor never reaches the controller), and it **is** an
accuracy hazard, but through a discrete mechanism (a corner-location error tipping a survival threshold)
rather than the continuous error-estimator floor that was hypothesised.

---

## 4. Structural features — any may be load-bearing or incidental; we do not know which

The two coupling channels (`a`: x→u, O(M), `u`-dependent; `s(x)`: x→x, cheap, `u`-independent); the
inner argmax `p_j*`, whose objective `P(p)` is a **corner** (a one-sided wall/jump meeting a smooth
monotone-decreasing branch; `∂P/∂p ≈ −8.8 ≠ 0` at the optimum; no interior stationary point) sitting a
fixed small distance inside the feasible interval; the fact that the argmax **location** `p*(state)` is
nonetheless **smooth** (linear, slope −1, to the `O(τ)` floor); the exact `∂P/∂p` (IFT + forward-AD;
already available; not an envelope FD); the objective evaluator **clamps** its argument into the
feasible interval `[a_j,b_j]` (a perturbed evaluation past the boundary collapses onto it, degrading a
centred difference to one-sided); the `O(τ)` corner-location floor that reaches the outputs `c,g` but
**not** the step-size controller; the near-singular self-loss `q≈16` with a positivity clamp (never
engaged); the ordered one-way inter-reservoir transfer; the external forcing into reservoir 1 only; the
timescale separation `~10²–10³` between fast forced `u` and slow `x`; the single global step size; the
configured `h_min` (`=10⁻⁶·T`) that the controller sits on in the collapse episodes; the skewed evolving
weight profile `ρ` (mass in a few members; many `ρ_j → 0`); the member schedule placed to resolve
`x(t)`, not `∫c·ρ`; the all-`M` cost floor per RHS; the `~10×` amplification of coupling error into `J`
and the `~23%` inter-scheme spread; the reverse-mode tape whose cost tracks accepted steps; the
`27–35%` rejection that co-locates with **nothing** we can log and is **invariant to the inner
resolution**; the survival-threshold bifurcation in `J` that the inner floor trips non-monotonically;
the broadband, continuous character of the step collapse.

---

## 5. Facts an answer can rely on

- The inner tolerance `τ` is a free knob (a config field); E1/E2 need no code change and are cheap to
  re-run at any `τ`. The per-step monitor is bit-identical off; attribution runs offline on saved data.
- E1: argmax and non-stationary outputs carry a floor `~τ` (slopes 1.10, 1.01); the objective carries
  `~τ` too (slope 1.06), because the optimum is a corner (`∂P/∂p ≠ 0` there), not a smooth max.
- E2: rejection fraction and `h_min` are **invariant** to a 1000× change in `τ`, across all five
  sequences; `h_min` equals the configured minimum step, not an emergent floor.
- `J` converges only for `τ ≤ 10⁻⁶` on the bifurcating sequence and is 2.4× off at the default `τ=10⁻³`,
  non-monotonically; on non-bifurcating sequences `J` is insensitive to `τ`.
- `a(x,u)` is obtainable only via the M member solves; `ẋ_j` require all M regardless of how `u` is
  advanced. No forward-mode Jacobian of `f` exists. `∂P/∂p` is exact and cheap.
- `J` must match a finite difference of the solver **as run**; a documented, controlled change of the
  discretisation, the inner solve, or the functional is acceptable if forward solution and reverse
  gradient stay correct. Production must stay bit-identical when the experimental path is off.

---

## 6. What we are asking

Given the complete structure (§1, §4) and the measured behaviour (§2, §3): **re-derive what is
actually happening, and tell us where the leverage is.** Your prior mechanism is confirmed at the
source and refuted at the controller — the inner floor is real but decoupled from the step size — so the
`27–35%` rejection and the `h_min`-clamped small steps are, again, **unexplained**: not events, not
inner resolution. Is that residual **intrinsic fast structure** any same-order explicit method must
resolve at this outer tolerance (in which case: what is the structure — the coupled `(x,u)` stiffness,
the corner passing through the RK stages as `u` moves within a step, something in the controller
itself?), or is it an **artifact of a representational choice we have not questioned** (the single
global step; the member schedule; the objective evaluator's clamp; the corner itself)? And separately:
the inner floor's only measured consequence is a **discontinuous, non-monotone bifurcation in `J`** at
survival thresholds — is the leverage there to reduce `τ` (but it is non-monotone), to make the member
contribution enter `J` smoothly (soften the survival threshold), to converge the corner location
exactly (a locator on the corner's defining condition rather than on `∂P/∂p = 0`, since the latter has
no root), or is this the `J`-conditioning problem (the `~10×`/`23%`) that no time-stepping change can
touch? Rank the features in §4. Reject our variables where the numbers warrant — we still suspect we may
be looking at the step-size residual through the wrong one. Where a cheap discriminating measurement
would localise the answer, name it and we will run it before building anything.
