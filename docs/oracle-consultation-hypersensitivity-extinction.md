# Hypersensitivity, weight blow-up, and extinction in a transported-measure IVP — a corrected and completed characterisation

A numerical-methods consult. No application context is needed or given. This **follows five prior
rounds** on the same initial-value problem. It is written to **stand alone** — assume none of the
prior thread.

**Why this round exists.** Every prior round described this system's slow block as a discretised
measure whose weights `ρ_j` evolve toward an **absorbing boundary at `ρ = 0`**. That description was
**materially incomplete, and in one respect wrong**. We never gave you the **weight equation**, and
it turns out to be the single structure that explains three pathologies we had been treating as
separate. We also asserted a smoothness property that a newly-surfaced measurement contradicts.

We are not asking you to validate a fix. We want to know **what this class of object actually is,
whether the pathologies are intrinsic or representational, and whether the formulation can be
mollified.** Reject our framing if the data warrant.

---

## PART A — THE CORRECTION

### A1. The omitted structure: the weight equation

The slow block is a discretised measure `μ_t = Σ_j ρ_j δ_{ξ_j}` on an ordered scalar coordinate line.
`ξ_j` is the member coordinate; `ρ_j ≥ 0` its weight. Members are **characteristics**. What we never
stated is how `ρ_j` evolves. It is the **transport/continuity equation along characteristics**:

```
ξ̇_j          = g(ξ_j, u, s, p*_j)                      the member velocity field
d(log ρ_j)/dt = − ∂g/∂ξ |_{ξ_j}  −  m(ξ_j, u, p*_j)     THE WEIGHT EQUATION  ← never disclosed
```

Three consequences we had not put in front of you:

1. **The weight dynamics differentiate the velocity field in the member coordinate.** Any
   non-smoothness of `g` *in ξ* is not merely inherited by the weights — it is **differentiated**,
   converting a bounded kink into an unbounded spike.
2. **`ρ` can diverge to `+∞`.** Whenever `∂g/∂ξ < 0` (velocity *decreasing* along the coordinate —
   characteristics **converging**), `log ρ` integrates *upward*. Prior rounds told you only about the
   absorbing boundary `ρ → 0`. The opposite divergence is real, and is the failure we actually hit.
3. **`∂g/∂ξ` is computed by a one-sided finite difference** on the member velocity, fixed step
   `ε = 10⁻⁶`, backward direction, no Richardson by default (a Richardson option exists, off). So the
   term is an FD of a possibly-kinked function, at a step far below the kink scale.

### A2. The smoothness claim we made that is contradicted

Prior rounds characterised the per-member inner control `p*` (an argmax with an active-constraint
corner, `∂P/∂p ≈ −8.8 ≠ 0` at the optimum) and asserted:

> *"the location `p*(state)` is nonetheless **smooth in the state** (traced linear to the τ-floor,
> slope ≈ −1.0004)"*

That trace was taken along a *state* direction. An independent diagnosis of the blow-up (recorded in
our own issue tracker, and closed **as not planned**) states the opposite in the direction that
matters:

> *"[the optimiser's output] jumps discontinuously in [the member coordinate] … Because [the
> velocity] `g` inherits that jump, the finite-differenced `∂g/∂ξ` explodes and the [weight]
> characteristic drives [the weight] to overflow."*

So: **`p*` may be smooth in `u` while being discontinuous in `ξ`** — and `ξ` is precisely the
direction the weight equation differentiates. We consider this contradiction **unresolved**; we have
not ourselves traced `p*` against `ξ` at fixed `(u, s)` under stress conditions. It is the first
measurement we would run on your instruction.

---

## PART B — THE SYSTEM (complete, self-contained)

IVP `y' = f(y,t;θ)`, `y ∈ ℝ^N`, on `[0,T]` (`T` spans 10³–10⁴ forcing periods), integrated by an
**adaptive embedded explicit Runge–Kutta** with a local-error controller, at converged tolerance
(10⁻¹²). Two two-way-coupled blocks.

**Slow block `x ∈ ℝ^M`** — `M ≈ 50–800`, **growing** during the run by insertion on a schedule chosen
to resolve `x(t)`. Each member carries the ordered coordinate `ξ_j`, weight `ρ_j`, and internal state
(including an accumulated loss variable and a **buffer/reserve state**, see B4). Members are removed
at `ρ → 0`. Dynamics: the velocity `g` plus **the weight equation of A1**.

**Fast block `u ∈ ℝ^L`, `L = 5`** — an ordered chain of reservoirs; one-way transfer `ℓ → ℓ+1`;
per-reservoir near-singular self-loss `κ(u_ℓ) = c u_ℓ^q`, `q ≈ 16`, with a closed-form
positivity-preserving exact recession and a floor `u_min`; external forcing enters reservoir 1
through a kinked gate `max(0, 1 − α(u_1/σ)^β)`.

**Coupling and readout**
```
p*_j      = argmax_p P(p ; x_j, u, s(x))       inner solve per member, every RHS eval
ξ̇_j       = g(ξ_j, u, s(x), p*_j)
d(log ρ_j)/dt = − ∂g/∂ξ|_{ξ_j} − m(·)          ← the weight equation
a_ℓ(x,u)  = Σ_j ρ_j c_ℓ(ξ_j, u, p*_j)          the coupling: O(M), the dominant cost
u̇_ℓ       = b_ℓ(u_1,t)·gate + [Tu]_ℓ − κ_ℓ(u_ℓ) − a_ℓ(x,u)
J         = Σ_j tw_j · φ(x_j)                  the scalar readout
```
`s(x)` is a cheap all-to-all scalar aggregate (flat in `M`, no `u`-dependence). `tw_j` carries the
member weight **and** a monotone-decreasing insertion-coordinate envelope, so `J`'s mass sits at small
insertion coordinate. Timescale separation `u : x ≈ 10²–10³`.

**B4 — a buffering state was added to the model and did not remove the pathology.** Motivated
*specifically* by this blow-up, the member gained a **reserve state**: the velocity `g` and the loss
`m` now respond to a *buffered* quantity rather than the instantaneous one, with `m` reserve-gated and
**bounded in `[m_min, m_max]`** (`m = A·exp(−B·r)`, `r` = relative reserve). Our own release notes call
this *"the root-cause fix"* for the blow-up. **We verified we are running that version, with the
reserve state active — and the blow-up still occurs.** So bounded loss + buffered velocity **reduce but
do not eliminate** it. This is a measured refutation of our own recorded fix.

---

## PART C — THREE PRESENTATIONS OF ONE PATHOLOGY (the cross-characterisation you asked for)

We had been treating these as three problems. A1 suggests they may be one. We cannot prove that.

### C1. Weight divergence (`ρ → +∞`) — "the blow-up"
The integrator aborts. Instrumentation shows **the weight of a single member reaching `+Inf`** while
**every other quantity stays finite**: member internal state healthy, all `L` reservoir components
finite, per-member contributions finite. A guard now traps it at `log ρ > 50`. The recorded internal
comment states: *"Smaller ODE steps do not help (the divergence is in the equations, not the
stepper)."* Triggering regime: strong periodic forcing (amplitude 0.4 about mean 0.5, i.e. the drive
swings 0.1–0.9) over horizons of 20–70 forcing periods.

**Our reading, offered for your judgement:** this is the signature of **characteristics converging** —
`∂g/∂ξ < 0` sustained ⇒ `log ρ` grows ⇒ `ρ` grows exponentially. In transport terms that is a
**caustic / shock in the transported measure**, at which the *pointwise density* along characteristics
genuinely ceases to exist while the **measure itself remains perfectly well-defined**. If that reading
is right, no integrator and no step size can survive it, because the object being integrated is the
one that blows up — and the fix is a change of representation, not of solver.

### C2. Functional hypersensitivity — "`J` amplifies everything"
Measured, in the *benign* regime: a **0.8 %** perturbation of the coupling `a` (and of the resulting
`u`) produces a **≈ 9 %** error in `J` — a **~10× amplification**. This has held as a stable rule of
thumb across rounds, and forced us to restate every accuracy budget in `J`-units.

But it is **not a constant**. Approaching the stressed regime the amplification **diverges**: `J`
becomes non-convergent (C3) and the reference integrator aborts (C1). There is then **no finite
conversion factor** between trajectory-units and `J`-units.

**Link to A1:** `J = Σ tw_j φ` is a **moment of the same measure** whose weights obey the weight
equation. If `ρ` is developing a caustic, a moment of it is exactly the quantity that becomes
ill-conditioned. Amplification and blow-up would then be the same phenomenon at different severities.

### C3. Extinction / collapse of the readout — "`J → 0`, non-convergently"
Under the stress traces `J` lands at **10⁻⁸ … 10⁻¹³** (replacement is `J ≈ 1`), and the collapse is
**sharp in the forcing amplitude**. Holding mean drive fixed at the sustaining level and increasing
the periodic amplitude `A` (readout well-conditioned and reference alive at the top two rows):

| amplitude `A` | `J` |
|---|---|
| 0.0 | 44.90 |
| 0.3 | 35.11 |
| 0.6 | **0.774** |
| 0.9 | **0.0251** |

A **45× drop between `A = 0.3` and `A = 0.6`** — a cliff, not a gradient. Note this straddles exactly
the amplitude (0.4) at which C1's blow-up was first reported.

In the collapsed regime **`J` is not a usable observable for any method**:
- **Self-convergence is non-monotone.** Refining our own scheme's time-discretisation 4× moves `J` by
  **10²–10³** and *non-monotonically* (e.g. 8.2e-8 → 1.5e-8 → 4.7e-6), before the two finest rungs
  finally agree to <2 %. The **trajectory** converges fine (≤5.5e-4); the **moment of it** does not.
- **Two independent methods disagree by ~1400×.** On the one stress trace where we can obtain a
  reference at all, the reference gives `J = 5.65e-10` and our multirate scheme gives `4.06e-13`
  (relative error 0.999), with all other settings matched.
- **No parameter choice escapes it.** A sweep of the member trait over a 25× range is **monotone
  decreasing** (best 2.2e-10, worst 2.5e-24). A sweep scaling the *magnitude* of the drive 1×→20×
  never lifts `J` above ~2e-9. Scaling the source/insertion rate 100× does not prevent C1 either.
  **The collapse is a property of the drive's temporal structure, not of its magnitude or of the
  member parameters.**

### C4. What is NOT the cause (measured; please do not re-derive these)
- **Not an ill-conditioned coupling fixed point.** A Krylov spectrum of the coupling-field
  self-consistency map has ρ(T′) ≈ 7 but **nothing at +1** (min|λ−1| ≈ 0.05–0.2, cond ≈ 5–22). The
  field map is well-conditioned; `J`'s sensitivity does not come from there.
- **Not a heavy atom needing splitting.** Max single-member weight fraction is **~1.6 %** and scales
  **∝ 1/M** — the measure refines cleanly.
- **Not member placement, and not survivor flips.** A decomposition of a separate non-convergence
  attributed **100 %** to a smooth shift of the fast-block field, diffuse across members, at small
  insertion coordinate — explicitly *not* placement and *not* members entering/leaving.
- **Not the stiff self-loss.** The `q ≈ 16` term has an exact closed-form recession (verified to
  1e-13) and the fast-block states are **verified finite** at the moment of the C1 abort. We had a
  hypothesis that C1 was an overflow of this term; **it is refuted** — the two failure modes carry
  distinct diagnostics and the fast-block mode never fired.
- **Not the inner-solve tolerance alone.** The inner solves run at converged tolerance (10⁻¹²) in all
  results above.

### C5. One intervention that partially works (our strongest causal evidence)
Replacing the derivative-free bracketing argmax for `p*` with a **safeguarded root-find on the exact
first-order condition** `∂P/∂p = 0` (with an endpoint-sign safeguard selecting the boundary branch)
— i.e. resolving the operating point sharply instead of to a bracket width — **rescues one of three
crashing traces** (it completes, `J = 5.65e-10`); the other two still diverge, and reach divergence
*earlier* in simulated time. Accuracy cost of the switch: max relative 6.8e-4; runtime 1.20×.

**This is our best evidence that part of C1 is representational** (a spurious FD spike off a poorly
resolved corner) **and part may be genuine** (true compression of characteristics).

---

## PART D — INCONSISTENCIES IN OUR OWN RECORD (we cannot resolve these; they may be diagnostic)

1. **Is the weight profile skewed or not?** Round 4 reported the evolved profile as *"highly skewed,
   mass concentrated in a few members"*, and built an entire estimator argument on it. C4 reports max
   weight fraction **~1.6 %, ∝ 1/M** — a *flat* measure. Both are ours; both were measured. Possible
   reconciliations: different objects (raw weight `ρ` vs the readout weight `tw` including the
   insertion envelope), different maturities, or different regimes. **Unresolved.**
2. **Is `p*` smooth in the member coordinate?** A2. Directly contradictory statements. **Unresolved,
   and load-bearing** — it decides whether C1 is artifact or intrinsic.
3. **Does the buffering fix work?** Our release notes call it *"the root-cause fix"*; our runs on that
   exact version still blow up (B4). At minimum it is incomplete.
4. **Is the divergence "in the equations, not the stepper"?** Our own code says so; yet C5 shows a
   *numerical* change (how `p*` is solved) removes it in one case. Both cannot be fully true.

---

## PART E — STRUCTURAL FEATURES (flat inventory; any may be load-bearing or incidental)

The weight equation `d log ρ/dt = −∂g/∂ξ − m` and its **FD evaluation** (one-sided, `ε=10⁻⁶`, fixed,
Richardson available but off); `ρ`'s **two-sided** pathology (absorbing 0 *and* divergence to +∞);
the readout as a **moment** of that measure; the insertion-coordinate envelope weighting `J` toward
small insertion coordinate; the **active-constraint corner** of `p*` (`∂P/∂p ≠ 0`) and its
bracket-width tolerance; the member **switch-off** boundary (`c ≡ 0` on one side); the buffered
reserve state and **bounded** loss `m ∈ [m_min, m_max]`; the near-singular `q≈16` self-loss with exact
recession and floor `u_min`; the kinked gate on the drive; growing `M` with insertion/removal; the
one-way reservoir chain; the O(M) coupling as a **moment**; the ~10× benign `J` amplification and its
divergence under stress; the 45× cliff in `J` between forcing amplitudes 0.3 and 0.6; the trait sweep
being monotone; the drive-magnitude sweep being ineffective; the well-conditioned coupling fixed point
(no eigenvalue at +1); the 1.6%-max weight fraction ∝1/M; the fact that the **trajectory converges
(≤5.5e-4) while its moment does not**; the 1400× two-method disagreement; the partial rescue by exact
`p*` resolution.

## PART F — FACTS AN ANSWER CAN RELY ON

- The weight equation is as stated; `∂g/∂ξ` is the *only* place the velocity field is differentiated
  in the member coordinate, and it is finite-differenced.
- At the C1 abort: one weight `+Inf`; **all** fast-block states finite; member internal states finite.
- The fast block's stiff term has an exact recession; a full operator-split of the fast block is
  available and verified.
- The exact first-order condition `∂P/∂p` for the inner control is available in closed form, and an
  exact implicit-function derivative of `p*` w.r.t. the fast block is available and validated (6.1e-4).
- We may change the discretisation, the representation of the measure, or the inner solve, **provided**
  the readout and its reverse-mode derivative remain correct, and provided the default configuration
  is reproducible bit-for-bit when the change is disabled.
- Reverse-mode differentiation of `J` is required eventually (not in this round's scope), so a
  representation that destroys differentiability is expensive to us.

## PART G — QUESTIONS (open; please rank, and reject the framing if warranted)

1. **Is C1 a caustic in a transported measure — i.e. is the pointwise density along characteristics
   simply the wrong dependent variable?** If so, is the correct move a **conservative / mass-based
   representation** (carry per-member integrated mass over its interval rather than a pointwise
   weight, so the blow-up becomes a harmless concentration of a bounded quantity), a finite-volume
   form of the transport equation, or something else? What breaks — in particular for a **moment
   readout** and for reverse-mode differentiability?
2. **Can this class be mollified at all without changing the answer?** We can smooth the corner in
   `p*`, smooth the switch-off, or regularise the weight equation. Which of these changes the
   *converged* readout and which only changes its *resolvability*? Is there a principled
   regularisation whose vanishing limit provably recovers the same `J`?
3. **Are C1, C2 and C3 one phenomenon or three?** Our A1 argument says the moment of a measure
   developing a caustic must be ill-conditioned, which would unify them. If they are distinct, name
   the discriminating measurement.
4. **Is `J` the wrong functional?** The trajectory converges to ≤5.5e-4 while `J` does not converge at
   all. Is there a reconditioned readout (a regularised moment, a time-windowed or mass-weighted
   variant, a different normalisation) that is well-posed under the same dynamics near collapse — or
   is the non-convergence telling us something structural that must be respected rather than smoothed?
5. **What is the right validation protocol when the reference itself cannot run?** Two independent
   methods disagree 1400× in a regime where the model is documented to diverge and where neither can
   be certified. Is there anything better than "report the trajectory tier and declare the moment
   unresolved"?
6. **Which of D1–D4 would you resolve first**, and by what measurement?
7. **What are we missing** — a structural simplification, a hidden cost, an assumption our data
   quietly contradict, or a frame in which this whole object is better posed?
