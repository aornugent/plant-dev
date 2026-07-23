# Oracle consultation — the compression term of a differentiated transport solve

**Status:** draft (outbound). Self-contained: assume none of any prior thread. Everything below is
abstract; a reader with no application knowledge should be able to reconstruct the full numerical model
and could not guess where it comes from.

**What we want from you.** One term in a discretised, then automatically-differentiated, transport solve
is simultaneously (a) the source of every value blow-up we see and (b) the source of every gradient
error we see, and the two symptoms appear to want *opposite* discretisations. We describe the system and
the measurements neutrally and ask you to tell us what is actually going on — whether the tension is
intrinsic to this term or an artifact of how we represent it, and what the right object is. We are not
asking you to grade a fix; we suspect we may be looking at this through the wrong variable.

---

## 1. The system

### 1.1 Continuum model

A one-dimensional conservation law is transported over a scalar coordinate `x ≥ x_b` on `t ∈ [0, T]`,
coupled to a nonlocal field and (in some instances) to a small auxiliary subsystem:

```
∂ₜ n(x,t) + ∂ₓ[ g(x, S, u; θ) · n ] = − r(x, S, u; θ) · n ,     x > x_b
S(z,t) = Ψ( ∫_{x ≥ z} κ(z, x; θ) · n(x,t) dx )                  (nonlocal, one-sided aggregate)
du/dt  = H( u, Q[n]; θ )                                        (auxiliary subsystem, dim ≈ 1–5, may be absent)
```

- `n(x,t) ≥ 0`: a density over `x`. `θ`: a parameter vector, `|θ| ≈ 5–20`, the differentiation inputs.
- `g`: a velocity that advects `n` along `x` (it is nonnegative and, once `x` is past `x_b`, typically
  positive — but see §1.5). `r ≥ 0`: a loss rate. Both are otherwise-smooth closed forms of `x`, `S`,
  `u`, `θ`.
- `S`: a scalar field over `x`, a pointwise-monotone map `Ψ` of a one-sided cumulative aggregate of `n`
  weighted by a kernel `κ`. `κ(z,x;θ)` is smooth, one-signed, defined for `x ≥ z`, low-rank-separable in
  `(z,x)`, and **vanishes on the diagonal**, `κ(z,z)=0`. The points interact **only** through `S` (and
  through `u`); there is no direct pairwise term.
- New points are inserted at `x_b` over the course of the solve, so the dimension grows.

### 1.2 Discretisation (method of characteristics)

The density is represented by `N(t)` moving points with strictly increasing coordinates
`x₁ < x₂ < … < x_N` and per-point scalar **log-densities** `ℓᵢ = log(density carried at xᵢ)`:

```
dxᵢ/dt = g(xᵢ, Sᵢ, u; θ)                         Sᵢ = S(xᵢ)
dℓᵢ/dt = − ( Cᵢ + r(xᵢ, Sᵢ, u; θ) )              Cᵢ = ∂ₓ[ g(x, S(x); θ) ] |_{xᵢ}
```

`Cᵢ` — the **compression** — is the spatial derivative of the velocity *evaluated along the reconstructed
field*: `Cᵢ = g_x + g_S · S′(x)` at `xᵢ`. It is unlike every other ingredient of the rates: (i) it is a
derivative with respect to the **coordinate `x`**, not with respect to a parameter; (ii) it is taken
through the field `S`, which the whole population generates self-consistently, so `S′` is the derivative
of a nonlocal reconstruction; (iii) it is evaluated at the point's **own moving coordinate** `xᵢ`, which
is both a query into `S` and a source of `S`; and (iv) `S` is known only as a reconstruction, so `Cᵢ` has
no closed form and is computed as a **finite difference**. It is the only rate that is itself a numerical
derivative.

The inter-point spacings `Δxᵢ` evolve as `d(Δxᵢ)/dt = g(xᵢ) − g(xᵢ₊₁)`, and they are the quadrature
weights of every reduction of the final state (the scalar outputs we differentiate — §1.6).

### 1.3 The coupling field, rebuilt every stage

`S` is rebuilt from the current `{xⱼ, ℓⱼ}` at **every Runge–Kutta stage** of every step (an explicit
adaptive RK integrator). Because `κ` is low-rank-separable and one-sided, `S(xᵢ)` is a weighting of a few
one-sided cumulative sums over the population — no dense pairwise cost.

### 1.4 Differentiation

We differentiate a **scalar reduction of the final state** with respect to `θ` by operator-overloading
automatic differentiation (reverse mode for the gradient; forward mode available as an independent
check). To keep the tape free of adaptive branching, the solve is run once at `double` to **record** the
step schedule (and the point-insertion schedule), then **replayed on that fixed schedule** on the active
(differentiated) pass. The correctness reference is a **δ-swept central finite difference of the model as
run** — i.e. perturb `θ`, re-run the *full adaptive* solve, difference; we confirmed the plateau in `δ`.

### 1.5 The floor on the velocity (a piecewise feature)

In some parameter regimes and for some points, the velocity `g` is driven to a hard floor: it is the
positive part of an interior expression, `g = max(0, ĝ(x, S, u; θ))`, and once a point crosses into
`ĝ ≤ 0` its `g` is pinned at `0`. This makes `g` piecewise in `(x, S, u, θ)` — continuous but with a
first-derivative kink across the surface `ĝ = 0`. Where a run has some points at `g = 0` adjacent to
points with `g > 0`, the coordinate field has a **one-sided stall**: characteristics on the moving side
converge toward the stalled ones.

### 1.6 What we reduce to
Scalar functionals of the replayed final state: e.g. `Σᵢ h(xᵢ)`, or a density-weighted aggregate
`Σᵢ w(xᵢ)·exp(ℓᵢ)·Δxᵢ`, or a time-integral over `[0,T]` of a per-point source term weighted by
`exp(ℓᵢ)`. The gradient of any of these w.r.t. `θ` is what must match the finite-difference reference.

---

## 2. The two discretisations of `Cᵢ`, and what each does (measured)

`Cᵢ = ∂ₓg` has no closed form; we have implemented and measured two finite-difference discretisations of
it. **Both are numerically consistent (→ the same continuum `∂ₓg` as the grid refines).** They differ in
where the derivative sample is taken.

**Scheme A — one-sided, sub-grid.** A per-point one-sided finite difference of `g` in `x` about `xᵢ`,
taken at a fixed small increment (a private evaluation of `g` at `xᵢ ± ε`, not using neighbours). This is
the upwind-style sample.

**Scheme B — centred neighbour secant.** `Cᵢ = ( g(xᵢ₋₁) − g(xᵢ₊₁) ) / ( xᵢ₋₁ − xᵢ₊₁ )` (one-sided at the
two ends), i.e. the difference quotient over the *existing neighbouring points*. This choice has an exact
algebraic identity: term-for-term, `Cᵢ` computed this way **equals** `d(log Δxᵢ)/dt` built from the same
spacings. Consequently, in a reduction whose weights are those same `Δxᵢ`, the compression contribution
and the spacing-evolution contribution are the *same discrete quantity with opposite sign*, and cancel.

### 2.1 Value behaviour (the integrated trajectory, no differentiation)

- **Scheme A: bounded.** The `double` trajectory stays finite across the regimes we run, including where
  some points sit at the `g = 0` floor (§1.5). It is our production scheme; it defines the reference
  trajectory.
- **Scheme B: overflows.** On ordinary runs (no extreme forcing) the log-density `ℓᵢ` of points just
  above a stalled region integrates upward without bound until `exp(ℓᵢ)` overflows. Instrumentation at
  the blow-up: the compression magnitude is **moderate** (`|Cᵢ| ≈ 25`, not a spike), the neighbour
  spacings are **normal** (no `Δx → 0`), but the neighbouring velocities are **exactly `g = 0`** — the
  stall of §1.5. The centred secant across the stall/no-stall boundary sustains a positive `Cᵢ` that the
  one-sided sample does not, and the density piles up. (A separate, documented instance: **Scheme A
  itself** overflows the same way, but only under **extreme forcing** of the auxiliary subsystem `u`,
  where `ĝ` crashes steeply over `x`. Same overflow of the same equation; different trigger.)

### 2.2 Gradient behaviour (reverse-mode AD vs the finite-difference reference)

- **Scheme A: gradient wrong.** Reverse AD through Scheme A is *internally consistent* (forward-mode
  tangent = reverse-mode adjoint to machine precision) and *value-exact* (bit-identical trajectory), yet
  the gradient disagrees with the finite-difference reference by an **`O(1)`, non-vanishing factor**,
  **concentrated in the parameters `θ` that reach the reduction only through the coupling field `S`**.
  The disagreement is `δ`-independent (holds as the FD step → 0), so it is not a step-size artifact. The
  mechanism: Scheme A's sub-grid sample is evaluated as a plain numeric value on the active pass and its
  `θ`-derivative is **not carried**; the field `S` is a function of the density, so the missing
  compression derivative corrupts `dS/dθ` and hence every coupled gradient. Direct example (one
  parameter, one instance): reverse AD `+729` vs FD `+4.2` before, tracing to this term.
- **Scheme B: gradient correct.** Reverse AD through Scheme B matches the finite-difference reference to
  **0.5–1%** across parameters and across the reductions of §1.6 (ratios 0.988–0.999). This is measured
  on the instances where Scheme B's value does *not* overflow (short horizons) or by using Scheme B for
  the derivative while holding Scheme A's value — see §2.3.

### 2.3 A hybrid we tried (a data point, not a proposal)

Because A is value-stable and B is derivative-correct, we measured a construction that takes the **value
from A** and the **parameter-derivative from B**: `Cᵢ = to_passive(A) + (B − to_passive(B))` (identity on
the value, derivative equal to B's). Result:
- For one model instance (the one with the `g = 0` floor active), this matches the FD reference
  (0.995–0.999) and is stable — the value never touches B.
- For a different model instance (velocity strictly positive, no floor, so B's value is itself stable),
  the same construction is **wrong**: reverse AD `−451.9` vs FD `+139.9`. There, A and B produce
  *different trajectories* (they differ at ~0.2% in the reduced output), so B's derivative is the
  derivative of a trajectory the value did not take. When A and B agree in value, the hybrid is correct;
  when they diverge, it is not.

So the hybrid is not universally valid; its correctness is contingent on A and B coinciding, which they
do not always.

---

## 3. Structural features — any of which may be load-bearing or incidental; we do not know which

Listed flat, deliberately unranked:

1. `Cᵢ` is a spatial derivative (`∂ₓ`), computed by finite difference, of a **field the population
   generates self-consistently**, evaluated at each point's **own moving coordinate**.
2. The velocity has a **piecewise floor** `g = max(0, ĝ)`; a positive-measure subset of points can sit at
   `g = 0`, adjacent to points with `g > 0` (a moving one-sided stall).
3. Two consistent discretisations of `Cᵢ` (one-sided sub-grid vs centred neighbour secant) have
   **opposite** stability behaviour and **opposite** ease-of-differentiation behaviour.
4. The centred secant equals `d(log Δxᵢ)/dt` exactly, so in reductions weighted by `Δxᵢ` a
   compression/spacing cancellation holds identically — a property the one-sided sample lacks.
5. Differentiation is **record-once / replay-on-a-fixed-schedule**; the schedule is frozen on the
   gradient pass; the correctness reference re-adapts the schedule.
6. The blow-up is in the **value** (`ℓ → ∞`), driven by a *sustained moderate* positive `Cᵢ` at the
   stall boundary — not a `1/Δx` spike, not `Δx → 0`.
7. The gradient error is in the **`θ`-derivative** of the same `Cᵢ`, is `O(1)`, `δ`-independent, and
   lives **only in the coupling channel** (parameters that reach the output only through `S`).
8. The kernel `κ` is one-sided, low-rank-separable, and vanishes on the diagonal `κ(z,z)=0`.
9. The dimension **grows** (points inserted during the solve); reductions integrate over the moving set.
10. `Cᵢ` is the **only** rate defined as a numerical derivative; every other rate is a pointwise closed
    form (modulo the floor and one embedded solve not central here).

---

## 4. Facts an answer can rely on (constraints)

- The differentiation engine is operator-overloading AD (reverse + forward), scalar-templated, with a
  record/replay of the adaptive schedule; no closed-form adjoint is imposed from outside — the tape
  carries whatever the code computes. Second derivatives are only partially available.
- "Correct" means: agrees with the δ-swept central finite difference of the **full adaptive** solve.
- The value scheme currently in production is Scheme A; a **bounded shift** of the production value
  (order `10⁻³` relative) is acceptable *if* it buys a single scheme that is both stable and exactly
  differentiable, but an unbounded change of behaviour (or loss of stability) is not.
- Whatever is chosen must work across model instances that differ in whether the `g = 0` floor is ever
  active and in whether the auxiliary subsystem `u` is present.
- Point insertion (growing dimension) and the one-sided low-rank field are fixed features of the solve.
- Performance matters but is secondary to (i) not overflowing and (ii) a correct gradient; the field is
  already cheap (low-rank one-sided sums).

---

## 5. The question

Open, and phrased to invite reframing:

1. **What is actually going on with `Cᵢ`?** Is the observed tension — one discretisation stable in value
   but wrong in gradient, the other correct in gradient but unstable in value — **intrinsic** to
   differentiating this compression term, or an **artifact of a representational choice we have not
   questioned** (the transported variable `ℓ`; computing `∂ₓg` as a finite difference at all; the choice
   of what the reduction weights are)?
2. If **intrinsic**, state the precise obstruction: what property of `∂ₓg`-at-a-self-generated-field, or
   of the `g = 0` stall, forces stability and differentiability apart, and what is the least-cost way to
   live with it?
3. If **representational**, what is the minimal change — a different **transported variable**, a
   different **object to carry the compression as** (something that is not a numerical `∂ₓ` of a
   reconstruction), or a different **reduction weighting** — that makes value-stability and
   gradient-correctness the *same* scheme, and what does it cost (accuracy, bit-shift, memory, code)?
4. Separately for the two failure modes, because they may have different resolutions: the **value
   overflow** at the `g = 0` stall (a sustained moderate positive compression where characteristics
   converge), and the **`O(1)` coupling-only gradient error** of the sub-grid sample. Are these two faces
   of one object, or two problems that happen to live in the same term?
5. Where is the compression's `θ`-derivative **genuine sensitivity** and where is it a **discretisation
   artifact** that should not be differentiated at all (given the `g = 0` kink and the moving query into
   a reconstructed field)?

We are open to being told that `ℓ` (a pointwise log-density) is the wrong transported variable, that
`∂ₓg` should never be formed as a numerical derivative, or that the stability and gradient questions
have a single common resolution we have not seen. If you can name a falsifiable prediction that
distinguishes your reframe from the status quo (e.g. "reformulate as X and both the overflow and the
coupling-gradient error vanish together; if the overflow persists, the cause is Y instead"), we will run
exactly that experiment before building anything.
