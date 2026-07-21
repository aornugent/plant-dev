# A coupled initial-value problem that resists approximation — an updated and complete numerical characterisation

This is a self-contained description of one numerical system and everything measured about its
resistance to approximation. There is no prior context to recover and none is needed. No application
domain is given; a reader can reconstruct the full mathematical model, its discretisation, and its
measured behaviour from what follows, and could not guess the field it comes from. Nothing here is a
question and nothing proposes a remedy — it is a characterisation. Precision and completeness are the
point; where a fact has a number, the number is given. This revision supersedes an earlier
characterisation and its addendum: it carries their errata already corrected, and adds three further
blocks of measurement (§9) run since.

Notation, fixed once and used throughout: `x` (a large block of `M` members), `u` (a small block of
`L` reservoirs), `p*` (an inner argmax), `a` and `s` (two coupling channels), `J` (a scalar functional
of the whole solve), `θ` (a small parameter vector), `τ` (an inner-solve tolerance), `τ_ins` (the
ordered coordinate along which members are inserted — the "lineage axis"). The forward solve and the
many approximations tried are described against this notation.

---

## 1. The system

An initial-value problem `y' = f(y, t; θ)`, `y ∈ ℝ^N`, integrated on `[0, T]`. The state partitions
into two blocks of very different size and role.

**The large block `x ∈ ℝ^M`.** `M` is not fixed: it starts small and **grows during the run**
(`M ≈ 50 … 800`) as new members are inserted on a schedule along an ordered coordinate `τ_ins` chosen
to resolve `x(t)`. Each member `x_j` is an independent low-dimensional sub-vector carrying an **ordered
scalar coordinate `ξ_j`** and a **non-negative scalar weight `ρ_j`**. The weight profile `ρ` is
**highly skewed and evolves**: most of the total weight concentrates in a few members while many
members have `ρ_j → 0` and are eventually removed at an **absorbing boundary `ρ = 0`**.

**The small block `u ∈ ℝ^L`, `L = 5`.** An **ordered chain of scalar reservoirs**. Reservoir `ℓ`
transfers one-way to reservoir `ℓ+1` only (no back-transfer, no cross-reservoir equilibration), and
each reservoir has a **near-singular self-loss** `loss_ℓ ∝ u_ℓ^{q}` with exponent **`q ≈ 16`**,
positivity-clamped at a floor `u_min`. An external forcing `b(t)` enters **only reservoir 1**. `b(t)`
is a **`C²` cubic spline** through known feature times (a few hundred knots per unit time, spacing
`≈ 3×10⁻³`, roughly 10× below the median accepted step); its third derivative is discontinuous at each
knot.

**The coupling.**
```
p_j*      = argmax_p  P(p ; x_j, u, s(x))          (inner solve, one per member, every RHS eval)
ẋ_j       = g(x_j, u, s(x), p_j*)                                          j = 1 … M
a_ℓ(x,u)  = Σ_j ρ_j · c_ℓ(ξ_j, u, p_j*),   ℓ = 1 … L        channel 1 (x → u), O(M), expensive
u̇_ℓ       = b_ℓ(t) + T_ℓ(u) − a_ℓ(x, u)                                    reservoir balance
s(x)      = cheap scalar aggregate of the whole large block   channel 2 (x → x), flat in M
```

- **Channel 1, `a` (x → u).** A weight-weighted quadrature `∫ c(ξ, u, p(ξ)) ρ(ξ) dξ` over the members —
  a **moment of the measure they discretise**. Each `c_ℓ(ξ_j, u, p_j*)` is a **byproduct of the same
  per-member inner solve** that yields `ẋ_j`, so a single evaluation of `a` costs the **full `O(M)` set
  of member solves**, and re-evaluating `a` at a new `u` (with `x` held) still re-runs all `M`. This is
  the dominant cost of `f`.
- **Channel 2, `s(x)` (x → x).** An all-to-all coupling through one cheap scalar; **no `u`-dependence**,
  cost flat in `M`.
- **Timescale separation.** `u` is fast and forced; `x` is slow. The separation is `~10² … 10³`.

**The inner argmax `p_j*` and its local geometry.** `P(p ; ·)` is maximised over a feasible interval by
a **fixed-tolerance derivative-free bracketing search** with bracket-width stop `τ` (default `10⁻³`),
returning the bracket midpoint. Traced finely at fixed state, `P(p)` is a **flat shelf, then a jump of
fixed magnitude at `p*`, then a smooth monotone decline of finite slope** (`∂P/∂p ≈ −8.8 ≠ 0` at `p*`).
`p*` is the **corner at the top of that jump** — the last point on a surviving branch, an
**active-constraint locus, not an interior maximum**: on one side a nested inner root ceases to exist
and the solve returns a fixed fallback value. Two further measured facts: (i) the location `p*(state)`
is nonetheless **smooth in the state** (traced linear to the `τ`-floor, slope `≈ −1.0004`); (ii) the
member solve first selects among a few feasibility branches (a switch-off exit, a zero-flux exit, a
degenerate-bracket exit, and the full search) — in practice **≥ 99.7 % take the full search**, the
switch-off exits fire on **< 0.5 %**, and the **degenerate-bracket branch never fires (0 occurrences)**.

**A second nonlinearity, the switch-off threshold.** `c_ℓ(ξ, u, ·)` is smooth on one side of a boundary
in `(ξ, u)` and **identically zero** on the other (a member contributes nothing to `a`). The switch-off
test is a reduction over the reservoir components a member accesses: it fires only when a scalar
`w(u) := max_ℓ (−m_ℓ(u_ℓ))` (the *least-extreme* accessible reservoir through a monotone `m_ℓ`) crosses
a fixed constant — i.e. only when **every** accessible reservoir is past the boundary. This surface is
**nearly unreachable by construction** (one benign reservoir keeps a member on).

**The functional.** A scalar `J = Σ_j tw_j · φ(x_j)` — a weight-weighted reduction over members. The
reduction is a quadrature over the insertion coordinate `τ_ins`, and `tw_j` carries the member weight
**and** a **monotone-decreasing insertion-time envelope `w(τ_ins)`**, so `J`'s mass sits at *small*
`τ_ins`. (`J` is also differentiated in reverse mode over the RK tape for `dJ/dθ`; the reverse direction
is **out of scope for this characterisation** and is not discussed further — everything below is the
forward solve and the value `J`.)

---

## 2. The dynamical system, formally

Read as a dynamical system, the object sits in a specific class, and its resistance to approximation is
a consequence of that class. Four structural facts.

**(i) A measure transported by a mean-field flow.** `x` is not a generic vector in `ℝ^M`; it is a
**discretised measure** `μ_t = Σ_j ρ_j δ_{ξ_j}` on the coordinate line. Members are **characteristics**:
`ξ_j` advects, `ρ_j` evolves, atoms are **born** (insertion) and **absorbed** (`ρ_j → 0`). Members
interact **only through the low-dimensional shared channels** `s(x)` and `u`, whose drive
`a = ∫ c(ξ,u,p*) dμ` is a **moment of the measure**. Each member sees the same `s` and `u`, and the
distribution evolves under those same dynamics — a **mean-field / McKean–Vlasov** coupling.

**(ii) A fast, forced, dissipative cascade with an absorbing boundary.** `u` is an ordered chain with
one-way transfer, a near-singular power-law self-loss, and an absorbing floor `u_min`, driven at the
head by `b(t)` and drained by the moment `a`. Alone it is a stiff contraction toward a moving
equilibrium `b + T(u) = a` — but that equilibrium is a functional of `μ`, so the fast subsystem's slow
manifold is set by the slow block.

**(iii) An embedded optimisation makes the vector field piecewise-smooth (Filippov), not smooth.** The
control `p*` solves a pointwise optimisation per member; its solution is an **active-constraint corner**
(`∂P/∂p ≠ 0`, a nonzero multiplier), so the active set changes across codimension-1 switching surfaces.
`f` is Lipschitz but **not `C¹`** across them; a second family of switching surfaces comes from the
member switch-off. Both move with the state; members cross them at scattered times.

**(iv) The readout is a moment across a bifurcation manifold.** `J = ∫ φ dμ` is a **moment** of the
transported measure. The weights obey dynamics with an **absorbing state at `ρ = 0`**; near it lies a
transcritical/saddle-node-type bifurcation (a marginal atom enters or leaves the measure). So `J` is
**continuous along a trajectory but only piecewise-`C¹` in the parameters and in numerical
discretisation choices**: at the extinction/insertion manifold its derivative carries a jump (a branch
slope plus the crossing atom's contribution). Small coupling perturbations move heavy atoms near
thresholds disproportionately.

**Why the class resists approximation** — each standard reduction deletes a load-bearing structure:
reducing the measure (collocation) re-quadratures a near-singular measure at nodes placed for the
characteristics, not the moment; freezing/held-coupling breaks the mean-field self-consistency;
fast/slow reduction targets the fast block while the accuracy limit and the cost sit in the slow measure
transport; relaxing the embedded optimisation to a flow has no fixed point at an active-constraint
corner; implicit/stabilised methods find no stability limit to relax and a Jacobian differenced through
the non-`C¹` inner solve is noisy.

---

## 3. Discretisation and controller

- **Method.** A single adaptive embedded explicit Runge–Kutta pair, **Cash–Karp 4(5)**, with a
  local-error controller and a **single global step size** shared by both blocks. A run takes
  `10³ … 10⁵` accepted steps. There is no dense output.
- **Error norm.** Componentwise scaled error `r_i = |e_i| / (atol + rtol·(a_y|y_i| + a_dydt|h y'_i|))`,
  reduced by max over `i` to `rmax`.
- **Controller.** Elementary (integral) with a dead-band: accept and hold while `0.5 ≤ rmax ≤ 1.1`;
  grow up to `5×` when `rmax < 0.5`; reject and shrink when `rmax > 1.1`. A rejected step re-runs the
  full `O(M)` member set.
- **Tolerances.** The outer tolerance at which `J` is converged (see §5) is modest; the inner argmax
  tolerance is `τ` (default `10⁻³`).
- **Member insertion.** Members are introduced on a schedule of `τ_ins` values, aligned to accepted-step
  boundaries. The **default production schedule is fixed** (not adaptively refined); an adaptive refiner
  exists but re-runs the whole forward solve many times to place members and is expensive (`>15` min per
  refined schedule at moderate `T`).

## 4. The correctness reference

"Truth" for the forward solution is the same integrator at a **tight tolerance** (self-convergence).
Approximate schemes are judged in **`J`-units**: `J` amplifies coupling error about tenfold (§5), so a
scheme neutral on the trajectory can still move `J`.

## 5. What the system does under the reference integrator (measured)

- Converged `J` is reached at **modest tolerance and cost**; the method does not fail on accuracy.
- **`27–35 %` of step attempts are rejected** (rejection-bisection overhead), uniformly across very
  different forcing sequences.
- Rejected attempts are **systematically larger than accepted ones** (median ratio `2.4–4.0×`).
- There is **no catastrophic mid-run step collapse**: the smallest steps occur at `t = 0`; away from
  start-up the accepted-step distribution is healthy; a hard floor on the step is essentially never
  touched. The reported `min h / T ≈ 1.4×10⁻⁸ … 5.0×10⁻⁸` equals the initial step divided by the
  horizon in every sequence.
- **The step size is accuracy-limited, not stability-limited.** Across a `3000×` sweep of the self-loss
  stiffness, `100 %` of steps run at `h·|λ_local| ≈ 10⁻³` — three to four decades below the explicit
  stability ceiling; `0 %` of steps are stability-limited. Softening the near-singular exponents does
  not move the step-size wall; **shrinking the minimum explicit step clears the tight-tolerance wall**
  (identical eval counts at `10⁻⁹` and `10⁻¹²`), the signature of a localised non-smoothness, not
  global stiffness.
- **The stiffness that exists is in the coupling, not the reservoirs.** `|J_full|` near `u_min` (a
  reservoir near its bound with members drawing against it) is **`50–291×`** the reservoir-only
  Jacobian; the amplifier is the `u`-dependence of the coupling `a`.
- **Cost.** `95–100 %` of one `f`-evaluation is the `O(M)` member solves. Whole-run cost scales
  `~M^{1.4}` (eval count `~M^{0.4}`, per-eval `O(M)`). A dense fixed schedule over a long horizon is
  minutes per single forward pass.
- **`J` is pathologically sensitive.** Two independently converged schemes disagree by **`~23 %`** at
  `M ≈ 350`; small coupling errors amplify **`~10×`** into `J`. On one sequence, `J` flips
  non-monotonically between two values (`≈1.41×10⁻⁷` and `≈5.87×10⁻⁸`, a `2.4×` jump) as `τ` varies,
  converging only once `τ ≤ 10⁻⁶` — one member crossing a weight-removal threshold.
- **The error norm's argmax.** Among rejected attempts, **192–345 distinct components** attain the max
  scaled error (normalised entropy `0.77–0.83`); members dominate reservoirs (~70/30); the attaining
  component drifts (consecutive persistence `0.23–0.28`) — non-memoryless but too diffuse for a serial
  predictor. A predictive (PI/Gustafsson) controller lowers the reject fraction (`0.28 → 0.19–0.24`)
  but raises total work `13–29 %`.
- **The forcing knots contribute little.** A step spanning a `C²` knot rejects `+12–36` pp more than an
  identically-sized step between knots, but only **`1.3–3.9` pp of the `~30 %` rejection** is
  knot-attributable; `84–92 %` of steps are sub-knot on smooth arcs. The smallest-decile steps cluster
  in **low-forcing intervals, away from forcing features** (`69–100 %` not near a feature).

## 6. The measure axis, measured

- The default **fixed** insertion schedule is **far from mesh-converged**: on one sequence its `J`
  (`≈2.15×10⁻⁶`, `M≈96`) is **~6×** an adaptively-refined value (`≈3.4×10⁻⁷`), and even two *refined*
  meshes (`M=173` vs `320`) differ **~2.3 %**.
- **Fixed uniform densification is not asymptotic.** A Richardson study on uniformly densified schedules
  gave order `p≈0.2` with a negative extrapolant — count, not placement, does not converge the measure
  cleanly.
- **The inter-mesh `J` difference along `τ_ins`** (a coarse vs a 2× mesh, `~62 %` apart, one sequence):
  the **absolute** discrepancy concentrates exactly where `J`'s mass sits (small `τ_ins`, `50 %` of the
  mass in `1.7 %` of the axis); the **relative** discrepancy is **diffuse** (median `0.53` over half the
  axis) **with an isolated spike** (`1532×` at one `τ_ins` — a member present in one mesh and absorbed in
  the other). §9c below refines this with schedule-neutral measurements.

## 7. The record of approximations tried (measured)

Every entry is a mechanism, a measured result, and the numerical reason it did or did not survive. The
reference is always the global explicit RK at converged tolerance.

- **Global implicit / A-stable / quasi-steady elimination of `u`.** Retired by measurement: the collapse
  is accuracy-driven, so there is no stability limit to relax. Rosenbrock (RODAS4, forward-AD or
  block-FD Jacobian) is `~1.5×` more steps and `~5×` slower on a reservoir-only surrogate; on the coupled
  system a dense Jacobian is `O(M²)`/`O(M³)` → `~470×` slower at `M≈205`. (For calibration the same method
  wins `~13×` on a genuinely stability-limited stiff test.)
- **Implicit treatment of `u` alone (IMEX, RODAS4, `L×L` Jacobian FD'd through the full RHS).** Accurate
  but `20–50×` slower, and the deficit **grows with tighter tolerance** (`21.7× → 52.2×` per tolerance
  decade) — order reduction from feeding the implicit solver a Jacobian differenced **through the
  fixed-iteration bracketing search** (noise `~δ/ε`). Retires implicit-`u` and, generally, any route
  that finite-differences a Jacobian through the member solves.
- **Held-coupling multirate / Lie–Trotter freeze** (sub-cycle `u` with `a` held piecewise-constant,
  refreshed `R×` per unit). Tracks truth only at `R ≈ 50/unit`; in stiff regimes **plateaus at a fixed
  error `≈0.1–0.12` regardless of `R`** — freezing `a` deletes the `∂a/∂u` restoring feedback, so the
  subsystem relaxes to the wrong balance. Error set by balance displacement, not refresh rate.
- **Per-macro linearisation / separable tabulation of `a(u)`.** `3–4×` relative error (linearisation)
  and absolute `0.06–0.76` (tabulation) once any component moves toward its bound — the `u`-dependence
  is non-separable with first-order cross-response.
- **MRI-GARK multirate skeleton.** Order verified on a smooth surrogate; but crossing a forcing feature
  within a macro step negates the order, and on the real system the fast sub-cycle needs `~10`
  accuracy-driven micro-steps with `a` re-evaluated **inside** the loop → `~13×` more member solves;
  full decomposition measured **`6–25×` slower** than global. Any scheme that puts the `O(M)` coupling
  inside a sub-cycle loses.
- **Member collocation / quadrature of `a`** (reconstruct from `m ≪ M`). On a prescribed
  quadrature-friendly member set, `m ≈ 15–20` gives `<0.5 %`; on the **evolved** set, `m = 20` is `14 %`
  and `m = 40` is `2.4 %` at `M ≈ 350` — the members are placed for the characteristics, not the moment.
- **Warm-started / continuation inner solve.** The inner solve is fixed-iteration by design (not
  warm-startable), and warm Newton diverges toward the bound over a realistic excursion.
- **Tracked control** (replace `p* = argmax` by a relaxed state `ṗ = k·∂P/∂p`). Matches a re-optimising
  reference on a smooth surrogate; on the real system it **fails at every gain** because the objective
  has no interior stationary point — a gradient flow has no fixed point at an active-constraint corner.
- **Event / step-to-event location.** An instrument logged, per accepted step, every candidate event
  margin plus an integer branch signature from inside each member solve (bit-identical). Rejections
  co-locate with an event flip only **`2–4 %`** of the time; enrichment `P(event|hard)/P(event|easy)
  ≈ 0.8–1.0`. The collapse is **broadband**, not a locatable set of crossings.
- **Forcing-feature step clipping.** Bit-identical, cost-neutral, small reject reduction; only `~2 %` of
  accepted steps land on features.
- **Inner-tolerance sweep.** Tightening `τ` by `1000×` leaves the rejection fraction unchanged
  (`0.20–0.31`); the inner floor is real at the source (co-outputs inherit `O(τ)`) but does not set the
  step size. Its one consequence is the `J(τ)` non-monotonicity above.
- **State reformulations.** A log-depletion re-chart of the reservoirs is `J`-neutral (the self-loss
  singularity is not the limiter); an exact closed-form flow of the singular self-loss matches to
  `10⁻¹³` but does not help the coupled step count (accuracy-set); additive-forcing / Sundman /
  gradient-flow re-charts are ruled out structurally.

## 8. Reduced and surrogate models systematically mislead (measured)

Every property that makes this system hard is *absent* from the natural simplifications, so a surrogate
does not merely lose accuracy — it reports the **opposite** conclusion, exposed only on the full coupled
object with an **evolved** measure. Measured instances: a cheap-coupling surrogate made
multirate/decomposition look `~1200×` faster and flat in `M` (real: `6–25×` slower); a reservoir-only
stiffness analysis pointed at implicit methods (real: not stability-limited at all); a prescribed
quadrature-friendly measure gave `<0.5 %` member-reduction error (evolved: `25–279 %`); a
smooth-interior-optimum surrogate made tracked-control look convergent (real: fails at every gain, the
operating point is an active-constraint corner). The through-line: any claim not measured on the full
coupled object with an evolved measure has, in this project's experience, a substantial chance of being
sign-wrong.

## 9. Three further blocks of measurement (run since the earlier characterisation)

These are new, and are stated as measurements only.

### 9a. A zero-feedback passive probe of the lineage axis

Because members interact **only** through the aggregates `a` and `s`, a member carried with **zero
contribution to both** — its own `x_j`, `ρ_j`, inner solve, but excluded from the sums — is an exact
passive probe of "what a member inserted at a given `τ_ins` would do," up to the self-feedback it would
have exerted. Given one saved forward solution's `(u, s)(t)` fields, such a probe is integrated against
them with no feedback, pinned to the recorded step times, at `~1/M` of a full solve.

Measured, comparing a probe's `J`-contribution against the **same** member's contribution when it is a
full participant (feeds back), as its weight fraction of the total is varied:

| participant weight fraction | 0.388 | 0.060 | 0.0064 | 0.0006 |
|---|---|---|---|---|
| relative `J` discrepancy (probe vs participant) | 63.4 | 0.42 | 0.036 | 0.003 |
| ratio participant/probe `J` | 0.016 | 0.70 | 0.966 | 0.997 |

The discrepancy is **`O(weight fraction)` and `→ 0` as `ρ → 0`**; the participant's `J` → the probe's
`J` as the weight vanishes. A self-consistency check (probe a member identical to an existing
participant, at that participant's own field) reproduced its `J` to `~3×10⁻⁹`. Separately, below a
threshold horizon the functional sits at the arithmetic floor (`J ~ 10⁻¹⁵`), rising to a resolved
regime (`J ~ 10⁻⁷`) only past it — the probe is meaningful only in the resolved regime.

(Infrastructure note, not a property of the system: the per-RK-stage record→replay of the `(u,s)(t)`
field had been storing build-only interpolation workspace — an adaptive-interpolant builder and a
band-solve buffer — never read on replay. Storing only the evaluatable field (interpolant knots+values
and the small-block state) reproduces the replay to every printed digit at `~⅓`–`1/6` the memory, which
is what made the long-horizon probes above feasible.)

### 9b. Contraction of a self-consistency iteration on the coupling

Consider the fixed-point map `T`: hold the coupling function `a(t)`; integrate the small block `u`
against it; advance all `M` members against the resulting `(u, s)(t)`, each independently; reassemble
`a(t)`. Its fixed point is the exact coupled solution. Measured the contraction near the reference fixed
point `a*` on saved fields,
```
κ(δ) = || T(a* + δ·a*) − T(a*) || / (δ · ||a*||),
```
global over `[0,T]` and per window (six equal windows):

| δ | κ (global) | κ per window |
|---|---|---|
| 10⁻³ | 9.93 | 5.4  9.9  7.4  6.9  11.8  11.3 |
| 10⁻² | 10.27 | 5.1  8.9  9.9  10.2  12.1  11.3 |

`κ ≈ 10 ≫ 1`, consistent across `δ` (a linear regime) and across every window; a round-trip identity
check (`δ = 0`) reproduced `a*` to `~1 %`. So one sweep of this iteration **amplifies** a perturbation
of `a` about tenfold. This is the same order as the measured `~10×` amplification of coupling error into
`J` and is consistent with the `50–291×` coupling Jacobian near `u_min`.

### 9c. Convergence of `J` under member-mesh refinement

Refining the member count `1× → 2× → 4×` for three placement families — the default fixed schedule,
uniform-in-time placement, and placement by equidistributing the `J`-contribution mass `|g_j|` (dense
where `J`'s integrand is large) — on two forcing sequences:

*Sequence A (deep evolved measure):* `J(N), J(2N), J(4N)` =
default `1.79, 1.85, 1.54 (×10⁻³)`; uniform `1.52, 1.83, 1.63 (×10⁻³)`; mass `2.08, 1.97, 1.49 (×10⁻³)`.
*Sequence B (repeated boundary excursions):* default `2.10, 0.424, 0.222 (×10⁻⁶)`; uniform
`1.69, 1.64, 1.21 (×10⁻⁷)`; mass `2.38, 1.90, 1.67 (×10⁻⁷)`.

Two readings. (i) **`J` does not converge under refinement for any family**: the successive relative
changes do not shrink monotonically (they grow — e.g. `0.03 → 0.20` and `0.06 → 0.33` on A), and the
three families land on **different** values at the finest level (`~9 %` apart on A, `~45 %` apart on B).
(ii) A single-solve interpolation-defect (hierarchical-surplus) indicator of `g_j` is **anti-correlated**
with the actual per-member difference between a mesh and its refinement (rank correlation `−0.56 … −0.86`
on three of four sequences; `+0.66` on the deep-measure one), while the **absolute** difference sits
`~100 %` at small `τ_ins` (where the envelope `w` concentrates `J`'s mass). Placement by `|g|`-mass does
not robustly beat uniform (it wins on boundary-excursion sequences and loses on the deep-measure one).
The default fixed schedule is far from any of the refinements (up to `~10×` at its own count on B); a
uniform schedule at the same count is `3–35×` closer to a refined solve across sequences.

## 10. Structural features (a flat inventory; any may be load-bearing or incidental)

The two coupling channels (`a`: x→u, `O(M)`, non-separably `u`-dependent, dominant cost; `s`: x→x, cheap,
`u`-independent); the inner argmax `p*` (active-constraint corner, `∂P/∂p ≠ 0`, no interior stationary
point, location smooth in state); the exact closed-form `∂P/∂p` (available, unused by the forward
solve); the fixed-iteration derivative-free bracketing to width `τ`; the feasibility branches (only the
full search materially exercised); the switch-off threshold keyed on the least-extreme accessible
reservoir (nearly unreachable); the near-singular reservoir self-loss (`q ≈ 16`) with a positivity clamp
(never engaged); the one-way inter-reservoir transfer; the `C²`-spline forcing into reservoir 1 with
known knots; the `~10²–10³` timescale separation; the single global step; the growing member count
inserted along `τ_ins` to resolve `x(t)` (not the moment); the skewed evolving weight profile with an
absorbing boundary `ρ→0`; the all-`M` cost floor per RHS eval; the `~10×` amplification of coupling error
into `J` and the `~23 %` inter-scheme spread; the moment functional whose mass sits at small `τ_ins` via
a monotone envelope; the step function of `J` across weight-removal thresholds; the `27–35 %` rejection
fraction invariant to inner tolerance and controller; the accuracy-limited step size `3–4` decades below
the stability ceiling; the zero-feedback probe whose error is `O(weight fraction)`; the self-consistency
iteration on `a` with contraction `κ ≈ 10`; the non-convergence of `J` under member-mesh refinement.

## 11. Facts an answer can rely on

- `95–100 %` of one RHS evaluation is the `O(M)` member solves; `ẋ_j` and `a` both need all `M`.
- The step size is accuracy-limited, not stability-limited (`3–4` decades below the ceiling); softening
  reservoir stiffness does not change the step count.
- The rejection fraction (`~30 %`) is invariant to a `1000×` inner-tolerance change and rises in total
  work under a predictive controller; the minimum step is the initial step.
- The coupling `a` is non-separably `u`-dependent; putting `a` inside any sub-cycle costs `6–25×` global.
- Member reduction is accurate on a quadrature-friendly set but not on the evolved set.
- `J` amplifies coupling error `~10×`; schemes are judged in `J`-units.
- A zero-feedback probe of the lineage axis is exact to `O(weight fraction)` and `→0` as `ρ→0`.
- A self-consistency iteration on `a(t)` has contraction `κ ≈ 10` (expansive), uniform across windows.
- `J` does not converge under member-mesh refinement (families disagree `9–45 %` at `4×`); the absolute
  inter-mesh difference concentrates where `J`'s mass sits (small `τ_ins`).
- The forward solution is the object of interest; the reference integrator already reaches converged `J`
  at modest cost.
