# Oracle response — the axis is wrong; the right cut is smooth arcs × events; and one "settled fact" is a live gradient bug

*Response to `oracle-consultation-tf24-recharacterized.md`. Recorded verbatim (lightly reformatted).
Hypotheses to test, not verdicts — §7 of the consultation guide applies: reduce each claim to the
cheapest falsifiable experiment (the Oracle supplies E1–E4) and run it before building.*

## 0. Framing correction (the Oracle owns its share)

The −0.91 `corr(logΔt,logd)` established **when** the cost occurs (excursions), not **what mechanism**
pays it. Excursions are exactly when members cross the threshold, argmax regimes flip, and the clamp
engages — event density and distance-from-balance were confounded. The new data separate them: the
dominant mechanism is **kink localization, not fast smooth motion** — 10⁻⁹·T steps at *scattered
isolated points*, an `h_min` wall that is a resolution limit, a `u`-rechart that changes nothing, and
a frozen-`x` decomposition 24% wrong before any approximation. **The 24% is the cleanest datum:**
sub-cycling `u` exactly while freezing `x` loses 24% in J → the macro-scale structure lives in `x`'s
motion, i.e. in the events that punctuate it.

## 1. The implicit-`u` experiment proves LESS than our payload claimed

The 21.7×→52.2× deficit *growing as tolerance tightens* is the signature of **order reduction in the
implicit method**, not of "the collapse isn't in `u`". Two confounders: RODAS4 needs a *consistent*
Jacobian for its order; we fed it a finite-difference Jacobian taken **through a fixed-iteration
bracketing search**, whose output is smooth only to the final bracket width → FD across those
micro-kinks yields Jacobian noise ∼δ/ε, and a Rosenbrock stage with a wrong linearization near a kink
spikes the embedded estimator. Degraded effective order ~2 vs explicit ~5 predicts step-ratio growth
~10^0.3 ≈ 2 per tolerance decade — we measured 2.4. **So the experiment firmly refutes (a) implicit-`u`
as a remedy and (b) the whole FD-Jacobian-through-the-member-solves route for any future implicit
idea** — but the relocation of the limiter to `x` rests on the **24% figure and the scattered-collapse
pattern**, which carry it fine. (⇒ the implicit-`u` ratios are *confounded* and must not be cited as
evidence for the `x`-relocation; the 24% is.)

## 2. Q1 — no block decomposition wins; a *temporal* decomposition does

Round-5's inequality stands: any correct scheme pays ≈ `n_f` coupling-accurate samples × `C(M)`, and
the global solver sits near that bound. What this round exposes: the global solver's step count is
`n_f` **plus a localization overhead** — at every controller-visible kink it locates the
non-smoothness by **rejection bisection**, paying O(M) member solves per probe (~5–15 probes/event),
plus locally degraded order (an explicit RK crossing a C⁰/C¹ kink mid-step drops to ~first order,
inflating steps on both sides).

**The leverage (the structural property the controller ignores): the event functions are decoupled
from the expensive RHS.**
- Whether member j crossed the threshold = a scalar test on `(ξ_j, u)` — **zero** member solves.
- Whether a forcing kink is inside the step = a table lookup.
- Whether member j's argmax hit its bound = **one** member solve, not M.

So localization — which the controller buys at M solves/probe — is available at ~0–1 solves/probe via
**dense-output root-finding**. And the skewed `ρ` — villain of every quadrature round — is here an
**ally**: the kink a crossing injects into the RHS scales with `ρ_j`, so **only the few heavy
members' crossings are controller-visible**; light members cross freely below tolerance. The event
set is small.

**Answer to Q1:** the fast/slow `(x,u)` axis is retired. The surviving decomposition is
**piecewise-smooth arcs separated by located events** — a hybrid-systems treatment of the *same global
explicit RK*: **step-to-event, restart, full order on every arc.** It removes rejection cascades,
restores design order (fewer steps *between* events too), deletes the `h_min` wall (kinks never
integrated across), and gives insertions clean tape boundaries. It does **not** beat the round-5 lower
bound; it **closes the gap** to it.

## 3. Q2 — classifying the non-smoothness sources + the cheap measurements

**Representational (removable):**
- Forcing kinks in `b(·,t)` — known times; align step boundaries. Trivial.
- Member insertion — we own the schedule; make insertions step boundaries (also tape hygiene).
- Threshold crossings — per-heavy-member event functions `ξ_j − boundary(u) = 0` on dense output,
  ~free; light members ignored below a `ρ·|c|`-scale tolerance; chattering members get
  hysteresis/clustering.
- Argmax regime/bound flips — event functions per member at ~5 one-member solves per localization; **or**
  remove the class entirely via the tracked-`p` variant (smoother near bounds), at the measured lag.
- **Model-side alternative for the threshold:** a declared **mollification** of the switch-off — if the
  hard switch is an idealization, a smooth switch of width below J-sensitivity deletes the whole event
  class more cheaply than handling it.

**Intrinsic (keep paying):** `u`'s genuine fast smooth motion under the forcing between kinks —
resolved as now.

**Measurements (days, not weeks; size the headroom before building):**
- **E1** — one instrumented run logging, per accepted & rejected step, the **distance to the nearest
  event surface** (forcing-kink time, heavy-member threshold, argmax-bound flip, insertion, clamp).
  The smallest-decile steps and the rejections partition into event-attributable (removable) vs
  unattributed (intrinsic).
- **E2** — the five-line **time-kink alignment A/B** bounds the forcing-kink share alone.
- **E3** — prototype events for the **top-3 heaviest members + bound flips** on one episode; measure
  step & rejection reduction.

## 4. Q3/Q4 — the data close them

**Q3:** No integrator-class gain on the `x` side — `x` is not stiff (steps accuracy-driven), and any
implicit/exponential treatment needs Jacobian info through solves that are not AD citizens (the
implicit-`u` experiment just showed the cost). With the all-`M` floor per evaluation, the **global
step count is the only multiplier, and events are the only lever on it.** Remaining constant factors:
members are embarrassingly parallel per step (wall-time only); the bracket width is **not** a
loosening knob (`c` non-stationary in `p` → p*-error enters J at first order × 10).
**Q4:** approximate-`x` is forbidden as measured — 24% at zeroth order is `x`-motion error no anchor
(which corrects the coupling defect, not `x`'s advance) can touch. The m-reduction numbers re-tested
uniform subsampling (the class round 4 already refuted); the measure/integrand split remains unmeasured
but is **moot** — with the decomposition retired, nothing wants it.

## 5. The gradient landmine (independent, first-order)

Our settled-facts list said: `∂c/∂u` for the adjoint is an envelope-theorem FD **at fixed p***, "since
`∂P/∂p* = 0`, p*'s motion contributes nothing to first order." **That argument is valid only for
outputs stationary in p — and `c` is the non-stationary co-output** (the *value function* is
envelope-safe; the *flux/byproduct* driving `u` is not). The true derivative is
```
dc/du = ∂c/∂u|_{p*} + (∂c/∂p)·(∂p*/∂u)
```
and the current adjoint **drops the second term** — on the coupling channel, into a J that amplifies
10×. Worse, it **evades our own validation** if the FD reference also freezes p*; a true FD of the
solver as run **re-optimizes**, and would disagree.

**Fix (uses machinery we have):** `∂p*/∂u = −P_pu/P_pp` from the exact IFT `∂P/∂p` (`P_pp`, `P_pu` by
one more IFT pass or FD of the exact gradient); `∂c/∂p` by one extra objective-side eval at cached
setup. **Check the `ẋ`-channel too:** if `g`'s ingredient is the value function it is envelope-safe;
if not, same correction.

**Test — E4:** on two `θ`-components, FD with **re-solved argmax** vs FD at **frozen p*** — the gap is
the dropped term, measured before any code change.

**Gradient dividend of the event upgrade:** active event times (the Leibniz node) restore precisely
the schedule sensitivity the frozen-schedule contract drops — largest at kinks (the round-5 caveat).

## 6. Q5 ranking / Q6 missing

**Load-bearing:** the 24% frozen-`x` error (kills macro-freezing independent of cost); the scattered
10⁻⁹-step pattern (the event diagnosis); the envelope-at-fixed-p* recipe (gradient correctness — the
sleeper); J's 10× amplification (the currency); `ρ`-skewness (now positive — small event set).
**Incidental:** the implicit-`u` ratios (confounded); the `u`-rechart neutrality (corroborating, no
action); channel 2 (cheap, needs no leverage); the `h_min` wall (deleted by events); the exact-flow
map (shelved).

**Missing, in order of value:**
1. **The adjoint fix** (§5).
2. **The event upgrade**, sized by E1–E3.
3. **The member mesh is the true accuracy axis and it is refined for the wrong functional** — the
   insertion schedule resolves `x(t)` while J hangs on `∫ c·ρ`. Add a **coupling-weighted refinement
   indicator** (`ρ·|c|` mass + threshold-corridor resolution — *free*, the full-M byproducts exist
   every step) and re-run the round-5 M-refinement certification. Attacks the 24%-class errors and the
   23% inter-scheme spread at their root, which no integrator can.
4. The standing **J-conditioning** question — a functional this sensitive is barely an observable;
   reformulating it is worth more than any remaining numerics.

**Verdict (stable across two rounds):** global explicit RK, **event-aware, correctly adjointed**. The
frontier is the **member discretization and the functional**, not the time integrator.
