# A multirate scheme that works, a win that evaporates where it matters, and a coupling that is not a function of its arguments

A numerical-methods consult. No application context is needed or given. This is **round 7** on the
same initial-value problem. It is written to **stand alone** — assume none of the prior thread.

**Why this round exists.** We built the multirate arbitrage a previous round endorsed. It works: the
expensive coupling is evaluated 40× less often on benign forcing, the escape from a known failure mode
is now certified rather than hoped, and the scheme completes traces the reference cannot. Then three
measurements, each taken to *confirm* something, refuted it instead:

1. Our "converged reference" was converged in one of two tolerance families. Every accuracy number we
   had published was wrong — **in the pessimistic direction**, which is why nothing tripped.
2. The observed order of the composed scheme **cannot be measured at all**: successive-difference
   ratios over a 8× span of macro step are `101.9`, `0.30` — non-monotone, one below 1. There is a
   `~2.7e-3` *deterministic* jitter floor in the readout with respect to step size.
3. Two evaluations of the expensive coupling **at the same slow state and the same fast state**
   disagree by up to **`2.454e-02`**, growing with forcing amplitude. We have checked and eliminated
   three candidate mechanisms. We do not know why.

Item 3 is the reason for this round. If the coupling is not a function of its arguments at the `1e-2`
level, then (2) is not a curiosity, the cost-optimisation program we are running is being conducted
against a noise floor larger than its own accuracy target, and several of our published comparisons
are meaningless. **We would like this framing attacked.** Two confident characterisations of this
system have already been overturned by instrumentation; we assume this one may be the third.

---

## PART A — THE SYSTEM (complete, self-contained)

IVP `y' = f(y,t;θ)` on `[0,T]`, `T` spanning `10³–10⁴` forcing periods. Two two-way-coupled blocks with
timescale separation `u : x ≈ 10²–10³`.

**Slow block `x ∈ ℝ^M`** — `M ≈ 50–800`, **growing** during the run by insertion on a schedule. A
discretised measure `μ = Σ_j ρ_j δ_{ξ_j}` on an ordered scalar coordinate; members are characteristics:

```
ξ̇_j           = g(ξ_j, u, s(x), p*_j)
d(log ρ_j)/dt = − ∂g/∂ξ|_{ξ_j} − m(·)          ∂g/∂ξ by one-sided FD, ε = 1e-6, fixed
p*_j          = argmax_p P(p ; ξ_j, u, s(x))   inner solve, EVERY member, EVERY RHS eval
```

`s(x)` is a cheap all-to-all scalar aggregate, flat in `M`, with **no `u`-dependence**.

**Fast block `u ∈ ℝ^L`, `L = 5`** — an ordered chain of reservoirs; one-way transfer `ℓ → ℓ+1`;
near-singular diagonal self-loss `κ(u_ℓ) = c·u_ℓ^q`, `q ≈ 16`; a floor with clamps; external forcing
into reservoir 1 through a kinked gate. Physical range per component ≈ `[0, 0.5]`.

**The coupling and the readout**
```
a_ℓ(x,u) = Σ_j ρ_j c_ℓ(ξ_j, u, p*_j)      ← O(M) member solves. THE DOMINANT COST.
u̇_ℓ      = b_ℓ(u_1,t)·gate + [Tu]_ℓ − κ_ℓ(u_ℓ) − a_ℓ(x,u)
J        = Σ_j tw_j · φ(x_j)               ← scalar readout, a moment of the measure
```

**What we exploit.** Members are ≤3% sensitive to sub-period detail of `u`; `a` is low-order in `u`.
So: freeze the slow block over a macro leg `H`, sub-cycle the fast block against an **affine
refreshed** coupling `â(u) = a₀ + G·(u − u₀)` where `G = ∂a/∂u` is an exact analytic Jacobian obtained
as a byproduct of the member loop, and re-capture `(a₀, G)` only when a trust monitor
`e² = (‖â − a₀‖_∞/‖a₀‖_∞)²` exceeds a tolerance. The macro/micro structure is a 3-node MRI-GARK
(order 3 on the slow advance); the micro steps use a Strang split with an **exact, positivity-preserving
closed-form recession for `κ`** (verified `1e-13`).

**Per leg, the scheme pays exactly 4 member sweeps** — 2 slow-advance stages (`F[0]`, `F[1]`) and 2
anchor captures, one at the start of each of the 2 sub-intervals.

---

## PART B — WHAT IS ESTABLISHED AND NOT IN DISPUTE

**B1. The escape is certified.** The known failure of the ancestral scheme was a *held-coupling*
plateau: freezing `a` outright omits `−∂a/∂u` from the fast block's restoring stiffness, which near
bounds is 50–291× the retained part, so the subsystem relaxes to a displaced balance — an O(1) error
no refresh rate can fix. The affine model carries that transfer function exactly at the anchor. The
certification, run with the monitor **off** and the re-anchor rate `R` forced: error falls
monotonically with `R` in **all 9** `{wet,mid,dry}×{drought,drizzle,storm}` regimes — smooth ones
`~O(1/R²)`, kinked ones `~O(1/R)` — with **no floor above the `~3e-7` splitting error**. The held-`a`
comparison shows a floor at `O(0.1)`. The escape is structural, not empirical.

**B2. The trust monitor's death mode does not occur.** Re-expansions run `0.11–0.53` per leg against a
"degenerated to global RK" threshold of ~40. On benign forcing it is **exactly 0**.

**B3. The cost reduction is real and strongly regime-dependent.** Expensive-coupling evaluations vs the
cheap frozen-residual count: **40×** on constant forcing, **3.8×** in a dynamic regime at the same leg,
**3–10×** on a stress bank. *We no longer quote a single number.*

**B4. The monitor trigger had to be the second-order remainder.** Triggering on the first-order
excursion `‖G·δu‖` over-triggers 12×, because `a` genuinely moves a lot — that is the entire point.
`e²` correlates with the true linearisation error at `0.985`.

---

## PART C — THE THREE REFUTATIONS

### C1. The reference was the outlier (and it flattered nothing, which is why it survived)

The integrator carries two independent tolerance families: an inner-solve family and an outer
time-integration family (default `1e-4`). For an entire work-cycle we tightened only the inner family
to `1e-12`, called the result "the converged reference", and left the outer at default.

| reference outer tol | `J` | cost |
|---|---|---|
| `1e-4` (what we used) | 35.1148736 | 112 s |
| `1e-5` | **35.2448663** | 508 s |
| `1e-6` | (>2900 s, abandoned) | — |
| — | *our scheme's own converged limit ≈ **35.24*** | — |

**The reference was wrong and the scheme under test was right.** Our scheme reports `yerr = 0` (always
accept), so the outer tolerance does not control it — tightening "the tolerance" moved the *reference
only*, and a shared under-converged reference silently mis-scores every method that ignores it.

Corrected frontier (dynamic regime, converged reference):

| macro leg `H` (days) | rel err in `J` | expensive-coupling evals | vs reference's 16581 RHS evals |
|---|---|---|---|
| 14 | 8.4e-2 | 2278 | 7.3× fewer |
| **7 (operating point)** | **3.5e-3** | 4358 | **3.8× fewer** |
| 3.5 | 2.7e-3 | 8518 | 1.9× fewer |
| 1.75 | ≤4e-4 (reference-limited) | 16868 | **~1.0× — no saving** |

**The arbitrage's advantage evaporates exactly where its accuracy becomes good.** Below ~`1e-3` it buys
nothing. This is the central economic fact and we do not know whether it is intrinsic.

### C2. The observed order is unmeasurable — there is a jitter floor in `J` vs `H`

Reference-free successive differences `|J(H) − J(H/2)|` should shrink by `2^p`. Measured over
`H ∈ [1.75, 14]` days: **`2.85e+00`, `2.80e-02`, `9.38e-02`** → ratios **`101.9`, `0.30`**. Non-monotone,
one below 1. The scheme is **not in an asymptotic regime anywhere we operate**, and there is a
`~2.7e-3` relative **deterministic** (repeatable, not stochastic) jitter floor in `J` with respect to
`H`. No reference quality fixes this; the floor is in the scheme's `H`-dependence.

Candidates we can name but have not separated: leg boundaries aligning differently with the member
insertion schedule and with the forcing; the adaptive ramp from the initial step. **Note the floor
`2.7e-3` is the same order as the operating point's error `3.5e-3` — we may have been "measuring" an
error that is mostly this.**

### C3. ⚠ The coupling is not a function of its arguments at the `1e-2` level

**This is the new finding and the reason for the round.**

Counting the 4 member sweeps per leg, we observed that 2 of them — the anchor captures — occur at
*exactly* the `(x, u)` at which the slow-advance sweep immediately preceding them was evaluated. The
ordering in the macro step is:

```
F[0] = slow_rates(x0, u0)          ← sweep 1
freeze_slow(x0); subcycle(u0)      ← sweep 2 = anchor capture at (x0, u0)
x0 → x1
F[1] = slow_rates(x1, u1)          ← sweep 3
freeze_slow(x1); subcycle(u1)      ← sweep 4 = anchor capture at (x1, u1)
```

and the slow-advance sweep already computes both anchor quantities (`a₀` is its coupling sum; `G` is a
byproduct it already fills). So sweeps 2 and 4 looked like pure duplicates. Counting confirmed the
*call pattern* exactly: `3308 captures = 2 × 1654 legs`, to the unit, with **zero** genuine
mid-subcycle re-expansions; and the duplicate share is **100%** at forcing amplitudes 0/0.3/0.6, 84.8%
at 0.9.

We made the anchor adopt the already-computed values. **The cost result was exactly as predicted:**

| | before | after |
|---|---|---|
| expensive captures | 4358 | **0** |
| member sweeps / leg | 4.00 | **2.00** |
| wall-clock | 124 s | **81 s (1.53×)** |
| genuine captures at amplitude 0.9 | 782 predicted | **783 actual** |

**And `J` moved by `1.5e-2`** (35.1212 → 34.5828), ~4× the error the scheme is trusted at.

Since the adoption is exact by construction — the same computation at the same arguments — any drift
falsifies the premise. So we measured the premise directly: on a matched state, sweep anyway and
compare the adopted anchor against the freshly-swept one.

| forcing amplitude | matched-state comparisons | max relative difference |
|---|---|---|
| 0.0 | 1208 | **3.487e-05** |
| 0.3 | 1208 | **2.454e-02** |

**Two evaluations of the O(M) coupling, at the same slow state and the same fast state, disagree by up
to 2.45e-02, and the disagreement grows with forcing amplitude.**

**Mechanisms we have checked and eliminated** (source-level, all three):
- *Not a stale derived-state cache.* The fast block's derived potential cache is **value-keyed** (it
  compares stored inputs against current inputs element-wise), so call ordering cannot stale it.
- *Not a non-idempotent field rebuild.* Both call sites rebuild the all-to-all field with the same
  flag; the rebuild rescales the existing knot grid from `[min, max_old]` to `[min, max_new]` and
  re-evaluates. With the slow state unchanged, `max_new == max_old` and the map is the identity.
- *Not a lagged auxiliary.* The per-member quantity the field is built from is a pure function of the
  member coordinate, written when the state is set, not when rates are computed.

**What remains, and what we cannot distinguish:** the two call sites differ only in that one rebuilds
the all-to-all field before sweeping and the other relies on the rebuild performed by the intervening
freeze. If the field rebuild and the member loop are in a **Picard/lagged relationship** — each
consuming the other's previous output — then successive calls are successive fixed-point iterates and
`2.4e-2` is the iterate gap, which would grow with how far the state has moved (i.e. with forcing
amplitude, as observed). We have not found the feedback path in the source. **The amplitude scaling is
the strongest clue and it points at the fast block, not at the all-to-all field.**

---

## PART D — A FOURTH FACT FROM A PARALLEL INVESTIGATION, WHICH MAY BE THE SAME OBJECT

An independent instrumentation round on the *crashes* of this system (previously and wrongly attributed
to a divergence of the measure's weights) established:

- **The weights never diverge**; the abort is a **fast-block component leaving its physical range
  inside a step** (`8.84`, then `−191`, then `+770/−1009` against a range of `[0, 0.5]`), after which
  the one-way chain moves equal and opposite quantities between neighbours and amplifies to overflow.
- **A 100× tighter tolerance converts the abort into a completed run.** It is an explicit integrator
  violating positivity on a stiff term, not a singularity of the equations.
- **The exact positivity-preserving recession for `κ` exists and is verified — but is NOT used inside
  the coupled adaptive solve** (only inside our multirate scheme's micro-steps).
- **Floating-point reassociation of one coupling sum** — `w·(c₁+c₂)` → `w·c₁ + w·c₂`, same sum,
  different rounding, nothing else — **moved the abort time by 3.07 units of horizon** (19.174 →
  16.109), reproducibly, and restoring the association restored the abort time to the digit.

That last item and C3 are the same *kind* of object: the system's behaviour depends on things that are
not its state. **We do not know whether they are the same phenomenon at different magnitudes.**

---

## PART E — WHAT WE ARE ASKING

We are not asking whether the arbitrage works; B1–B3 answer that. We are asking whether we are
optimising the right thing, and whether the ground under the measurements is solid.

1. **C3 first: what single measurement would you run?** Two evaluations of an O(M) reduction at
   identical arguments differ by `2.4e-2`, amplitude-scaling, with the three obvious caching/idempotence
   mechanisms eliminated. Is the Picard/lagged-coupling hypothesis the right one to test, and what is
   the decisive discriminator? If it *is* a lagged fixed point, note the consequence: **the "converged"
   coupled solve is converging to a fixed point of an iteration nobody declared**, and the local error
   controller is controlling a quantity that is not the residual of the stated ODE.

2. **Are C2 (the `2.7e-3` jitter floor in `J` vs `H`) and C3 (the `2.4e-2` same-state discrepancy) one
   phenomenon?** If the coupling carries a state-independent perturbation of order `10⁻²` locally, is a
   `10⁻³` floor in an integrated moment the expected signature? If so, **no scheme of any order can be
   measured below that floor**, our entire order/accuracy program is mis-specified, and the right move
   is to fix the reproducibility before touching the discretisation.

3. **Given C1's frontier, is the arbitrage the right structure at all?** It gives 3.8× at `3.5e-3` and
   nothing at `4e-4`. Meanwhile Part D says the accuracy ceiling and the crashes both come from an
   explicit treatment of a near-singular diagonal for which we hold an exact positivity-preserving flow
   *that we do not use in the reference solve*. Is the honest conclusion that **we have been optimising
   the cost of a scheme whose accuracy is limited by something the same toolbox already fixes** — i.e.
   that exact-flow splitting of the fast block belongs in the *baseline*, not only in the multirate
   inner, and the multirate question should be re-asked afterwards against a better baseline?

4. **The per-leg cost floor.** Four member sweeps per leg; the obvious 2× (adopting the slow stage's
   already-computed coupling) is blocked by C3. If C3 is resolved, is that adoption sound in principle,
   or does the anchor legitimately need a sweep the slow stage cannot provide? A previous round noted
   that inside a leg the fast subsystem is a 5-D closed form — constant linear part plus scalar
   nonlinear forcing in one component — suggesting `recession ∘ expm(T−G) ∘ 1-D forcing solve`,
   Strang-arranged, with every sub-flow exact. **Does that also dissolve the per-leg floor, or only the
   micro-step count?**

5. **What is a defensible validation protocol** when a bit-level reassociation moves a failure by 3
   horizon units and two evaluations at the same state differ by `2.4e-2`? What would you require
   before believing *any* accuracy number from this system?

6. **What are we missing?** Two confident, fully-argued characterisations of this system have already
   been overturned by instrumentation — the weight-blow-up story and, this week, the duplicate-sweep
   story. In both cases the error was **inferring value-equality from structural equality** and then
   constructing an argument that made the inference self-validating. If there is a third instance of
   that pattern visible in the above, we would rather hear it now.

## PART F — FACTS AN ANSWER CAN RELY ON

- All counters are per-evaluation and exact; the duplicate/genuine capture split was verified two ways
  (`3308 = 2 × 1654` exactly, and the predicted 782 vs actual 783 genuine captures under the change).
- The `2.454e-02` is a max over 1208 matched-state comparisons in a single run, instrumented inside the
  solver, comparing the adopted values against a fresh sweep at the same arguments.
- The exact recession is verified to `1e-13` and is positivity-preserving by construction. A full
  operator split of the fast block is available and verified in isolation. Neither is used in the
  reference solve.
- The analytic coupling Jacobian `G` is validated against finite differences of a full operating-point
  re-solve (`1.0e-5` median in the hard regime).
- The reverse mode is proven on a toy (record→replay adjoint vs FD `<1e-6`) but **not wired on the real
  system**; it is required eventually, so a change that destroys differentiability is expensive.
- We may change the discretisation, the representation, the inner solve, or the integrator, **provided**
  the readout and its reverse-mode derivative stay correct and the default configuration is
  reproducible bit-for-bit when the change is disabled.
