# Hypersensitivity, a mis-diagnosed blow-up, and extinction in a transported-measure IVP

A numerical-methods consult. No application context is needed or given. This **follows five prior
rounds** on the same initial-value problem. It is written to **stand alone** — assume none of the
prior thread.

**Why this round exists.** Every prior round described the failure of this system as a blow-up of the
**weights of a discretised measure**, and asked how to represent that measure better. We have since
instrumented the failing runs, and **that description is wrong**. On every trace we can instrument the
weights stay bounded — in one case at `10⁻¹²` of the scale where trouble would start — while a component
of the small **fast block** leaves its physical range inside a step and a near-singular chain amplifies
it to overflow. The diagnostic that we had been reading as "a weight diverged" fires whenever *any*
factor of a reduction is non-finite, and the non-finite factor was never the weight.

Two further measurements, both refutations of our own prior framing:
- We **built the conservative reformulation** that the old characterisation calls for (transport mass,
  not pointwise density). It rescues nothing and breaks a case that previously ran.
- The failures **go away under a 100× tighter local-error tolerance**, on both the historical reprex and
  a current stress trace, contradicting our recorded claim that "the divergence is in the equations, not
  the stepper".

So this round asks a different question from the last five. We want to know **what this coupled object
actually is, which block the difficulty lives in, and whether the readout's hypersensitivity and the
integrator's failure are one phenomenon or two.** Reject our framing if the data warrant; we have now
been wrong about it once, with confidence and at length.

---

## PART A — THE STRUCTURE, AND WHAT WE MEASURED ABOUT IT

### A1. The weight equation

The slow block is a discretised measure `μ_t = Σ_j ρ_j δ_{ξ_j}` on an ordered scalar coordinate line.
`ξ_j` is the member coordinate; `ρ_j ≥ 0` its weight. Members are **characteristics**:

```
ξ̇_j          = g(ξ_j, u, s, p*_j)                      the member velocity field
d(log ρ_j)/dt = − ∂g/∂ξ |_{ξ_j}  −  m(ξ_j, u, p*_j)     the transport/continuity equation
```

Three facts about it, all relevant to what follows:

1. **`∂g/∂ξ` is computed by a one-sided finite difference** on the member velocity, fixed step
   `ε = 10⁻⁶`, backward direction, no Richardson by default. It is the only rate that is itself a
   numerical derivative, and it differentiates `g` along the coordinate in which `g` may be non-smooth.
2. **`ρ` can in principle diverge both ways** — to `0` (absorbing; members are removed there) and to
   `+∞` wherever `∂g/∂ξ < 0` is sustained (characteristics converging).
3. **The loss `m` is the term that has actually overflowed.** In the model version we ran until
   recently, `m = A·exp(−B·q)` with `q` an instantaneous per-member productivity that goes strongly
   negative under stress: measured `m ≈ 1.6×10³` (`A = 5.5`, i.e. `exp(−Bq) ≈ 292`), unbounded above. The
   current version buffers `q` through a reserve state, which **bounds** `m` in `[A·e^{−B}, A]`. Both
   versions appear in the measurements below and each is labelled.

### A2. The inner control is discontinuous — measured, no longer in dispute

Each member solves an inner optimisation `p*_j = argmax_p P(p; ξ_j, u, s)` at every RHS evaluation, with
an active-constraint corner (`∂P/∂p ≈ −8.8 ≠ 0` at the optimum). Earlier rounds asserted `p*` is smooth
in the state. Corrected, measured: **`P` and `p*` are smooth within a feasibility branch and genuinely
discontinuous across the branch boundary.** Sweeping a state variable across the transition and refining
the step to `10⁻⁷`, `P` **jumps by ≈ 1.46**, and the jump does not shrink with the step — a true
discontinuity, not a sub-grid cliff. The shut-down branch's value sits strictly *below* the marginal
feasible optimum.

Consequence for A1: where a member sits near that boundary, `g` inherits a jump in `ξ`, and the one-sided
FD returns `≈ jump/10⁻⁶`. This mechanism is real, and it is the one place a weight *could* be driven up
spuriously. It is **not** what our failing runs do (Part C).

### A3. The conservative reformulation: built, measured, refuted

An independent consultation on the same weight equation — put from the discretisation angle, without the
failure data — returned the reformulation A1 invites:

> Carry per-member log-mass `λ_j = log ρ_j + log Δξ_j` instead of the pointwise `log ρ_j`. Then
> `dλ_j/dt = −m_j`: the compression `∂g/∂ξ` cancels identically and is never formed. `λ` is monotone
> between insertions, so **the overflow vanishes identically in all regimes**.

We built it: the chart, the inverse maps, and every reduction rewritten to consume `exp(λ)` so the
reconstructed density `exp(λ)/Δξ` is never formed. It is in production for two other model instances of
the same solver. Opting the instance that actually fails onto it — one build, one variable, six horizons
`H`:

| `H` | pointwise-density transport | log-mass transport |
|---|---|---|
| 20 | **completes** | **abort** at `t ≈ 3.7` |
| 25 | abort, `t = 13.14` | abort |
| 30 | abort, `t = 19.17` | abort, `t = 16.09` |
| 40 | abort, `t = 14.10` | abort |
| 50 | abort, `t = 7.18` | abort |
| 70 | abort, `t = 7.19` | abort, `t = 16.10` |

**Zero rescues in five; one regression.** The prediction is refuted, and the mechanism of the new failure
is the informative part: on the chart `λ` jumps from `−0.12` to **`+231.9` in a single RK stage**, on an
established interior member (not a newborn), whose loss rate at that moment is `m ≈ 1.6×10³`. `λ` is
monotone in exact arithmetic; an explicit stepper on a stiff negative rate is not. The change of variable
deletes the compression term but keeps `m` verbatim — and `m` is where the stiffness is.

---

## PART B — THE SYSTEM (complete, self-contained)

IVP `y' = f(y,t;θ)`, `y ∈ ℝ^N`, on `[0,T]` (`T` spans 10³–10⁴ forcing periods), integrated by an
**adaptive embedded explicit Runge–Kutta** with a local-error controller. Two two-way-coupled blocks.

**Slow block `x ∈ ℝ^M`** — `M ≈ 50–800`, **growing** during the run by insertion on a schedule chosen to
resolve `x(t)`. Each member carries `ξ_j`, `ρ_j`, and internal state (including an accumulated loss
variable and a buffer/reserve state). Members are removed at `ρ → 0`. Dynamics: `g` plus the weight
equation of A1.

**Fast block `u ∈ ℝ^L`, `L = 5`** — an ordered chain of reservoirs; one-way transfer `ℓ → ℓ+1`;
per-reservoir near-singular self-loss `κ(u_ℓ) = c u_ℓ^q`, `q ≈ 16`, with a closed-form
positivity-preserving exact recession available (verified to `1e-13`) **but not used inside the coupled
solve**; a floor `u_min` with clamps around it. External forcing enters reservoir 1 through a kinked gate
`max(0, 1 − α(u_1/σ)^β)`. Each `u_ℓ` has physical range ≈ `[0, 0.5]`.

**Coupling and readout**
```
p*_j      = argmax_p P(p ; x_j, u, s(x))       inner solve per member, every RHS eval
ξ̇_j       = g(ξ_j, u, s(x), p*_j)
d(log ρ_j)/dt = − ∂g/∂ξ|_{ξ_j} − m(·)
a_ℓ(x,u)  = Σ_j ρ_j c_ℓ(ξ_j, u, p*_j)          the coupling: O(M), the dominant cost
u̇_ℓ       = b_ℓ(u_1,t)·gate + [Tu]_ℓ − κ_ℓ(u_ℓ) − a_ℓ(x,u)
J         = Σ_j tw_j · φ(x_j)                  the scalar readout
```
`s(x)` is a cheap all-to-all scalar aggregate (flat in `M`, no `u`-dependence). `tw_j` carries the member
weight **and** a monotone-decreasing insertion-coordinate envelope, so `J`'s mass sits at small insertion
coordinate. Timescale separation `u : x ≈ 10²–10³`.

**Guards.** Two run-time guards abort the solve, both checked at **every** RHS evaluation: (i) any member
weight non-finite or `log ρ > 50`; (ii) any factor of the coupling reduction non-finite. Guard (ii) is
what fires on our stress traces, and it does **not** identify which factor went bad — the mistake this
round corrects.

---

## PART C — WHAT ACTUALLY FAILS (instrumented)

### C1. The failure is in the fast block; the measure is a bystander

Per-RHS-evaluation instrumentation of the two crashing stress traces, current model version (bounded
`m`). Both abort under guard (ii).

Trace 1, last four evaluations (`u` = the five reservoir components, physical range ≈ `[0, 0.5]`):

| t | max `log ρ` | min member gap | `u` |
|---|---|---|---|
| 10.0955 | −1.678 | 1.62e-05 | 0.128, 0.211, 0.226, 0.234, 0.240 |
| 10.1432 | −1.941 | 1.62e-05 | **8.84**, 0.211, 0.225, 0.234, 0.239 |
| 10.2865 | −2.910 | 1.58e-05 | **−346**, **+312**, 0.224, 0.232, 0.237 |
| 10.4774 | +0.008 | 1.72e-05 | **+770**, **−1009**, **+337**, 0.230, 0.235 |

Trace 2:

| t | max `log ρ` | min member gap | `u` |
|---|---|---|---|
| 38.2156 | −26.94 | 3.24e-07 | 0.405, 0.199, 0.208, 0.214, 0.218 |
| 38.4312 | −28.09 | 3.14e-07 | **−191**, **+190**, 0.208, 0.213, 0.218 |
| 38.7187 | −24.67 | 3.46e-07 | **+413**, **−916**, **+507**, 0.213, 0.217 |

- **The weights never diverge.** Max `ρ ≈ 1` in trace 1 and `≈ 2×10⁻¹²` in trace 2, against a guard
  ceiling of `e⁵⁰`. Guard (i) runs every evaluation and never fires, which independently certifies that
  no weight was non-finite or above the ceiling at any point.
- **The member spacing does not collapse.** `min Δξ` is flat across the event in both traces: no
  concentration, no caustic, no `Δξ → 0`.
- **A reservoir component leaves its physical range inside a step** (`8.84` against a ceiling of ≈0.5;
  then `−191`). The one-way chain then moves equal and opposite quantities between neighbours and the
  pair amplifies — `1e0 → 1e2 → 1e3` here, `1e6 → 1e108` on the reprex of C2 — until a factor is
  non-finite.
- The reduction that finally trips guard (ii) is `Σ_j ρ_j c_ℓ`, non-finite **in `c_ℓ`** — the per-member
  coupling coefficient evaluated against `u = −916` — with `ρ_j` finite and tiny.

**We therefore withdraw the characterisation of prior rounds** ("the weight of a single member reaching
`+Inf` while every other quantity stays finite; all `L` reservoir components finite"). It is backwards.
We do not claim no regime exhibits a weight blow-up: the historical report that started this thread did,
on the older unbounded-`m` version, and bounding `m` plausibly removed it.

### C2. Smaller steps *do* help — so the divergence is not "in the equations"

Our own code and issue record assert that step refinement does not help. Measured, twice:

On the historical reprex (older, unbounded-`m` version), which still aborts there:

| controller tolerance | max step | outcome |
|---|---|---|
| 1e-4 (default) | 5 | abort at `t = 19.174` |
| **1e-6** | 5 | **completes**, `J = 1.0642e-08` |
| **1e-6** | 0.05 | **completes**, `J = 1.06471e-08` |
| 1e-8 | 5 | controlled stop: "cannot achieve the desired accuracy" |
| 1e-10 | 5 | controlled stop: same |

On trace 1 of C1 (current version): default `1e-4` aborts at `t = 10.48`; at **`1e-6` it completes**,
`J = 3.82e-08`.

A 100× tighter tolerance converts the abort into a completed run, and on the reprex two step-size regimes
agree on `J` to `5e-4` relative. That is an integrator violating a positivity constraint on a stiff term,
not a singularity of the ODE. The `1e-8`/`1e-10` rows are the ordinary explicit-RK accuracy floor at the
non-smooth features of A2 — a controlled stop, not a blow-up.

### C3. Functional hypersensitivity — `J` amplifies everything

Measured in the benign regime: a **0.8 %** perturbation of the coupling `a` (and of the resulting `u`)
produces a **≈ 9 %** error in `J` — a **~10×** amplification, stable across rounds. Approaching the
stressed regime the amplification **diverges**: `J` becomes non-convergent (C4) and the reference
integrator aborts (C1), so there is no finite conversion factor between trajectory-units and `J`-units.

### C4. Extinction / collapse of the readout — `J → 0`, non-convergently

Under the stress traces `J` lands at `10⁻⁸ … 10⁻¹³` (replacement is `J ≈ 1`), and the collapse is
**sharp in the forcing amplitude**. Holding mean drive fixed and increasing the periodic amplitude `A`:

| amplitude `A` | `J` |
|---|---|
| 0.0 | 44.90 |
| 0.3 | 35.11 |
| 0.6 | **0.774** |
| 0.9 | **0.0251** |

A **45× drop between `A = 0.3` and `A = 0.6`** — a cliff, not a gradient. In the collapsed regime `J` is
not a usable observable for any method:
- **Self-convergence is non-monotone.** Refining our own scheme's time-discretisation 4× moves `J` by
  `10²–10³`, non-monotonically (8.2e-8 → 1.5e-8 → 4.7e-6), before the two finest rungs agree to <2 %. The
  **trajectory** converges fine (≤5.5e-4); the **moment of it** does not.
- **Two independent methods disagree by ~1400×** on the one stress trace where a reference exists
  (5.65e-10 vs 4.06e-13, all other settings matched).
- **No parameter choice escapes it.** A 25× sweep of the member trait is monotone decreasing (best
  2.2e-10, worst 2.5e-24); scaling the drive magnitude 1×→20× never lifts `J` above ~2e-9; scaling the
  insertion rate 100× does not prevent the abort. The collapse is a property of the drive's **temporal
  structure**, not of its magnitude or of the member parameters.

### C5. The abort time is not reproducible under floating-point reassociation

Found by accident, and load-bearing for how C3–C4 should be read. One reduction in the coupling was
rewritten from `w·(c_{k−1} + c_k)` to `w·c_{k−1} + w·c_k` — the same sum, a different rounding, nothing
else changed:

| association | abort |
|---|---|
| `w·(c_{k−1} + c_k)` | `t = 19.173798` |
| `w·c_{k−1} + w·c_k` | `t = 16.108785` |

**Rounding alone moved the failure 3.07 units of horizon.** Restoring the association restored the abort
time to the digit. Any statement of the form "scheme A survives to `t` and scheme B does not" carries no
information at the resolution we have been quoting it.

### C6. One intervention that partially works

Replacing the derivative-free bracketing argmax for `p*` with a **safeguarded root-find on the exact
first-order condition** `∂P/∂p = 0` (endpoint-sign safeguard selecting the boundary branch) **rescues one
of three crashing traces** (it completes, `J = 5.65e-10`); the other two still diverge, and reach
divergence *earlier* in simulated time. Accuracy cost: max relative 6.8e-4; runtime 1.20×.

### C7. What is NOT the cause (measured; please do not re-derive)

- **Not an ill-conditioned coupling fixed point.** A Krylov spectrum of the coupling-field
  self-consistency map has `ρ(T′) ≈ 7` but **nothing at +1** (`min|λ−1| ≈ 0.05–0.2`, cond ≈ 5–22).
- **Not a heavy atom needing splitting.** Max single-member weight fraction is **~1.6 %**, scaling
  `∝ 1/M` — the measure refines cleanly.
- **Not member placement, and not survivor flips.** A decomposition of a separate non-convergence
  attributed **100 %** to a smooth shift of the fast-block field, diffuse across members.
- **Not the inner-solve tolerance alone.** The inner solves run at converged tolerance (`10⁻¹²`)
  throughout.
- **Not a caustic in the transported measure** (C1), and not curable by changing what the measure carries
  (A3).

---

## PART D — WHAT REMAINS UNRESOLVED IN OUR OWN RECORD

1. **Is the weight profile skewed or flat?** An earlier round reported the evolved profile as "highly
   skewed, mass concentrated in a few members" and built an estimator argument on it; C7 reports a max
   weight fraction of ~1.6 %, `∝ 1/M`. Possible reconciliations: the raw weight `ρ` versus the readout
   weight `tw` including the insertion envelope; different maturities; different regimes. **Unresolved.**
2. **Does a weight blow-up occur in any regime we still run?** Historically reported, and reproducible on
   the older version with unbounded `m`; not observed on any current instrumented trace. If it does not,
   an entire branch of our reasoning — and A1's consequence 2 — is inert in practice.
3. **Why does the fast block leave its range at all?** Three candidates and we have not isolated which
   produces the first out-of-range value: the near-singular loss `κ = c u^q`, `q ≈ 16` (whose exact
   positivity-preserving recession we have verified but do **not** use in the coupled solve); the kinked
   gate on the drive; the coupling `a`, a large sum evaluated at RK stage states.
4. **Is `J`'s hypersensitivity (C3–C4) connected to the fast-block failure (C1) at all?** They co-occur in
   the same regime. We previously unified them under a caustic story that C1 refutes, and we have no
   replacement.

---

## PART E — STRUCTURAL FEATURES (flat inventory; any may be load-bearing or incidental)

The weight equation and its one-sided FD compression (`ε=10⁻⁶`, fixed, Richardson available but off); the
measured discontinuity of `P`/`p*` across the feasibility boundary (jump ≈1.46, step-refined to `10⁻⁷`);
the loss `m` bounded in `[A·e^{−B}, A]` in the current version and unbounded (measured `1.6×10³`) in the
previous one; the near-singular `q≈16` self-loss with an exact recession **available but unused in the
coupled solve**; the one-way reservoir chain that moves equal and opposite quantities between neighbours;
the floor `u_min` and its clamps; the kinked gate on the drive; the explicit embedded RK with a
local-error controller and **no positivity constraint**; the readout as a moment of the measure with a
monotone insertion-coordinate envelope; the O(M) coupling as a moment; growing `M` with
insertion/removal; the ~10× benign `J` amplification and its divergence under stress; the 45× cliff in
`J` between forcing amplitudes 0.3 and 0.6; the trait sweep being monotone; the drive-magnitude sweep
being ineffective; the well-conditioned coupling fixed point; the 1.6%-max weight fraction `∝1/M`; the
trajectory converging (≤5.5e-4) while its moment does not; the 1400× two-method disagreement; the
3.07-horizon shift under floating-point reassociation; the tolerance dependence of the abort; the partial
rescue by exact `p*` resolution; the failure of the conservative reformulation.

## PART F — FACTS AN ANSWER CAN RELY ON

- The instrumentation in C1 is per-RHS-evaluation and prints the extremes of the measure and every
  reservoir component; both guards are checked at every evaluation.
- The exact recession of the `q≈16` term is verified to `1e-13` and is positivity-preserving by
  construction; a full operator split of the fast block is available and verified in isolation. Neither
  is currently used inside the coupled adaptive solve.
- The exact first-order condition `∂P/∂p` is available in closed form, as is an exact implicit-function
  derivative of `p*` with respect to the fast block (validated to 6.1e-4).
- We may change the discretisation, the representation of the measure, the inner solve, or the
  integrator, **provided** the readout and its reverse-mode derivative remain correct and the default
  configuration is reproducible bit-for-bit when the change is disabled.
- Reverse-mode differentiation of `J` is required eventually (not in this round's scope), so a
  representation or a solver that destroys differentiability is expensive to us. Adaptive branching is
  handled by recording the schedule and replaying it.
- Two model versions appear above and every measurement is labelled; the current version bounds `m`.

## PART G — QUESTIONS (open; please rank, and reject the framing if warranted)

1. **Given C1 and C2, what is the right treatment of the fast block?** It is a short one-way chain with a
   near-singular diagonal loss, a kinked source, and a coupling term that is a large sum over the slow
   block; an explicit adaptive RK drives components far outside their physical range in a single step and
   the chain then amplifies the excursion. We hold an exact positivity-preserving recession for the
   diagonal part, unused. What is the least-cost formulation that cannot leave the physical range —
   exact-flow splitting, an implicit or exponential treatment of the diagonal, a positivity-preserving
   embedded pair, a projected controller — and what does each cost in accuracy, in differentiability, and
   under the timescale separation `u : x ≈ 10²–10³`?
2. **Are the readout's hypersensitivity (C3), its non-convergence (C4), and the fast-block failure (C1)
   one phenomenon or two?** Our unifying story was a caustic in the measure, and C1 refutes it. If they
   are distinct, name the discriminating measurement. If the amplification is a property of the coupled
   spectrum rather than of the measure, what is the right conditioning diagnostic to compute?
3. **Is `J` the wrong functional?** The trajectory converges to ≤5.5e-4 while `J` moves by `10²–10³`
   under refinement in the collapsed regime. Is there a reconditioned readout — a regularised moment, a
   time-windowed or differently normalised variant — that is well-posed under the same dynamics near
   collapse, or is the non-convergence structural, to be respected rather than smoothed?
4. **What is a defensible validation protocol here?** Two methods disagree 1400× in a regime where the
   reference itself aborts, and C5 shows a bit-level reassociation moves the failure by 3 units of
   horizon. Is there anything better than "report the trajectory tier and declare the moment unresolved"?
   What would you require before believing *any* number from this regime?
5. **Which of D1–D4 would you resolve first, and by what measurement?** In particular D3: we have not
   isolated which of the three fast-block terms produces the first out-of-range value, and that looks
   cheap to settle if you can say which measurement is decisive.
6. **What are we missing** — a structural simplification, a hidden cost, an assumption our data quietly
   contradict, or a frame in which this object is better posed? One confident, fully argued
   characterisation of this system has already been overturned by instrumentation; assume others may be.
