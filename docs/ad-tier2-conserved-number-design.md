# Design: conserved-number SCM state for faithful reverse-mode gradients

Applying the system-design skill to the question left open after the Tier-1
experiment confirmed the conservation-pair diagnosis. Unlike the Oracle statements,
this uses full domain knowledge — and the domain turns out to settle the question the
domain-blind Oracles could not.

## Triage: 3 — expensive to reverse

Changes the core SCM demographic state variable, affects all four strategies
(K93, FF16, TF24, TF24f), the field assembly, the birth boundary, serialization/resume,
and the RcppR6 surface. Full procedure.

## The domain fact the Oracles could not use

The census/fitness functionals are **moments** `M = ∫ φ(x) n dx`. Integrating the
transport PDE `∂ₜn + ∂ₓ(gn) = −rn` by parts:

```
dM/dt = ∫ φ[−∂ₓ(gn) − rn] dx = ∫ (φ'g − φr) n dx + boundary flux      — no ∂ₓg
```

**The compression term `∂ₓg` is absent from the physics every functional measures.** It
appears on our tape only because we transport a *pointwise log-density* `ℓ`, whose ODE
`dℓ/dt = −∂ₓg − r` carries it. The Explore pass confirms the enabling conditions in the
real code: (a) no strategy rate reads its own density — rates are functions of the
shared field value and the individual's own size only; (b) every downstream density
consumer is a moment (light competition, TF24 soil-water depletion, biomass), with
pointwise density read only by R diagnostics and a finiteness guard. So the transport
term contaminates the *gradient* of every moment (via `ℓ → density`) while contributing
nothing to the moments' *physics*. This is why the domain-blind Oracles could not break
the keep-vs-drop tie: they could not see that the functionals are transport-free.

## Requirements ledger

- **R1 — correct reverse gradients, all parameters, all four strategies** (≤~1% vs
  converged FD). Now: K93 census wrong (transport-term derivative unfaithful — *proven*
  no pointwise fix); FF16/TF24/TF24f census gradients **unavailable** (the `dg/dh`
  derivative is dropped, awaiting a forward-mode rate-path port). The transport artifact
  contaminates every moment: light competition, soil-water depletion, biomass.
- **R2 — the forward solve stays a valid SCM discretization** of the McKendrick PDE
  (stable, convergent under refinement). Quantity: reference outputs re-baseline (values
  shift at truncation order); convergence order preserved.
- **R3 — one shared fix across strategies.** The transport lives in `Node`/`Species`
  (strategy-agnostic); the fix must too. Adding a strategy should mean writing
  `g / r / fecundity / field-coupling` only — no per-strategy transport-gradient work.
- **R4 — reverse-mode cost `O(1)` forward solves**, not `O(|θ|)`.
- **R5 — no rate or functional may need a quantity the new state can't supply.**
  Verified: no per-cohort rate reads its own pointwise density across all four
  strategies (challenged upward and checked, not assumed).

**Scarce resource:** a demographic state variable whose reverse-mode differentiation
does **not** manufacture a dependence on `∂ₓg` that the continuum moments provably do
not have. The pointwise log-density is exactly the variable that manufactures it.

## The floor

**No change** — keep log-density + the upwind FD-stencil compression, differentiate as
today. **Fails R1**, and not marginally: it is *proven* (Tier-1 investigation) that no
pointwise on-tape treatment of `d(∂ₓg)/dθ` is faithful for this representation, because
the compression is a cancelling pair split across two state pieces (`ℓ`'s ODE and the
geometry/quadrature weights) that are discretized by *different* operators. K93 census is
O(1) wrong; FF16/TF24/TF24f are unavailable. The floor cannot meet R1 by any local means.

## Candidates

- **A [first thought] — Tier 1, geometric compression** *(move: align the
  discretization).* Replace the `ℓ`-ODE compression with `[g(x_{i+1}) − g(x_{i−1})]/
  (x_{i+1} − x_{i−1})`, the same discrete operator the geometry uses.
  *Commitment:* the two copies of `∂ₓg` are discretely identical → cancel on tape.
  *Pays R1:* measured machine-exact for both parameter classes; needs only neighbour
  `g`-values, so it works for all strategies with no rebind. *Costs:* keeps the
  log-density state, keeps the redundant cancelling pair (a difference of two `O(1/Δx)`
  terms — ~1–2 digits lost, and *silently re-breakable* if the two discretizations ever
  drift), retains the slope-read machinery elsewhere, and still carries a `∂ₓg` in the
  state. *Wins when:* a minimal, reversible change is paramount and the fragility is
  tolerable.
- **B — Tier 2, conserved-number state** *(move: change of variable).* Transport
  log-**number** `L` (`dL/dt = −r`); moments and fields become number-weighted sums.
  *Commitment:* the transported state is a conserved quantity, not a pointwise density;
  `∂ₓg` is never taped. *Pays R1:* transport-free by construction — the term is
  unstatable. *Costs:* core state reinterpretation across Node/Species/strategy initial
  conditions, the aggregation (spacing-weighted density → number sum), the birth map,
  serialization/RcppR6; re-baseline. *Wins when:* correctness across all strategies +
  soil, robustness, and deleting the whole `dg/dh` apparatus are worth a one-time
  migration.
- **C — keep the model, differentiate non-pointwise** *(move: move the boundary to the
  method).* Get the current model's gradient from the full self-consistent finite
  difference (which *does* cancel) or a continuous adjoint. *Costs:* FD is `O(|θ|)`
  solves (fails R4); a continuous adjoint differentiates a slightly different model
  (R2 mismatch) and is its own research problem. *Wins when:* the forward model is truly
  immutable — not our case.

**Winner: B.** Eliminations: the floor fails R1 (proven, cited above). C fails R4
(`O(|θ|)`) or R2 (adjoint model mismatch). **A meets R1 but is strictly dominated by B:**
A only makes the pair *cancel* — it still carries two large opposite terms whose
cancellation is fragile and re-breakable, keeps the density representation and the
slope-read machinery, and leaves `∂ₓg` in the state; B *removes* the term. Both are
shared-infra fixes (R3) and both re-baseline (R2 equal), so the tie breaks on robustness
and on the large apparatus B deletes. A is the reversible fallback if B's migration
proves too costly.

## The commitment

*The transported demographic state is the conserved cohort number (carried as
log-number); every coupling and every functional is a number-weighted moment; the
spatial derivative of growth is never a taped quantity on the rate path.*

**Kept true by structure:** there is no `∂ₓg` term in any state equation and no
field-slope read on the rate path — the transport term is *inexpressible*, so it cannot
be differentiated wrongly. Density is recoverable as `n = N/Δx` only in diagnostic/output
paths, off the rate tape.

## Kill question

*Assumption whose falsity makes this unnecessary:* that every rate and functional is a
moment — i.e. no per-cohort rate reads its own pointwise density. **Verdict: survives.**
Checked across K93/FF16/TF24/TF24f: rates read only the environment field and the
individual's own size; the only pointwise-density reads are R diagnostics and a
finiteness guard, neither of which produces a rate.

## What survives deletion

- Conserved-number state `L` → R1 (transport-free moments).
- Number-weighted aggregation → R1/R5 (light competition, soil-water depletion, biomass
  all become `Σ (per-plant)·e^L`).
- Birth-number map → R2 (correct boundary influx).
- `n = N/Δx` recovery → only where a diagnostic reports density; deletable if none does.
- **Deleted, not kept:** `growth_rate_gradient` and its entire apparatus — the upwind FD
  stencil, the K93 rebind / forward-over-reverse injection, and the environment
  slope-read / interpolator query-derivative machinery on the rate path. None is needed.
  This is a large simplification, not merely a fix.

## What this settles (states that can no longer occur)

- The self-force, the one-sided-slope pathology, the keep-vs-drop fork, and the finite-N
  cavity question are all **unstatable** (no slope read, no transport term).
- **FF16/TF24/TF24f census gradients become available with no forward-mode rate-path
  port** — the §15 blocker ("await their rebind") dissolves, because there is no `dg/dh`
  to instantiate. This is the direct payoff of "consider all four strategies."
- The TF24/TF24f **soil-water depletion moment** is differentiated faithfully by the same
  number-weighting (its density factor was the same artifact); the stateful soil field
  composes — it is read as a value and coupled through a moment, exactly the clean case.

## What this makes hard

- A future functional genuinely needing pointwise density or `∂ₓn`: recover `n = N/Δx`
  (neighbour spacing — a smooth value read, no self-force) or an SPH/KDE field read.
  Priced: reintroduces neighbour coupling *at that read*, as a value.
- Forward values change (different quadrature/representation) → all reference tests
  re-baseline once. This is a re-baseline, **not a physics change**: both discretizations
  converge to the same PDE, and the number form is the canonical Escalator-Boxcar-Train
  state (number-per-cohort), i.e. the *more* standard of the two.

## Kill condition

A future strategy whose per-capita rate depends on its **own local density** (density-
dependent mortality/growth not mediated by the shared field). Then the number form needs
a local `n = N/Δx` read at that rate — still no `∂ₓg`, but neighbour-coupled. Hands off
to candidate A's territory only if that local read proves ill-conditioned.

## The design

- **State (Node).** Replace per-cohort `log_density` (a density) with `log_number` `L`.
  Rate: `dL/dt = −mortality`. Remove the transport term. `density` accessor becomes a
  derived `e^L / Δx` for diagnostics only.
- **Aggregation (Species/Patch).** `compute_competition` and `consumption_rate` change
  from a density-trapezoid (`Σ spacing·density·per-plant`) to a number sum
  (`Σ e^L·per-plant`); the spacing quadrature is absorbed into the number. Strategy-
  agnostic, so one change covers all four.
- **Birth map (Species boundary).** Newborn `L = log(birth influx × introduction
  interval)` — the number entering — replacing the density-at-birth `= birth_rate/g`
  boundary value. Differentiable, value-only.
- **Functionals (Patch/R).** Biomass/census/seed-rain = `Σ φ·e^L`. Fecundity/R0 already
  a transport-free moment over introduction times — unchanged.
- **Remove.** `growth_rate_gradient` and callers; the FD stencil; the K93 forward-over-
  reverse and `strategy_has_rebind` transport path; `get_environment_slope_at_height` /
  `slope_at_height` and the interpolator's query-derivative reads *on the rate path*
  (the interpolator's value read stays).
- **Soil (TF24/TF24f).** No structural change: rates read soil values, depletion is a
  number-weighted moment. Benefits automatically; the stateful field's adjoint flows
  through its own ODE as before.

Data flow after: positions `xᵢ` evolve by `g` (field **value** read); numbers `Lᵢ` decay
by `r`; fields are `Σ (per-plant)(xⱼ)·e^{Lⱼ}`; moments are `Σ φ(xⱼ)·e^{Lⱼ}`. The reverse
gradient flows through `x`, `L`, and value-only field reads. No slope, no transport term,
one representation for all four strategies and both resource fields.

## Answers to the framing questions

- **Are model changes required?** Yes. It is proven that the current representation
  admits no cheap faithful gradient (candidate C is the only no-forward-change option and
  it fails R4/R2). The required change is *acceptable* because it removes a
  discretization artifact, not physics — moments are transport-free.
- **What does Tier 2 add over Tier 1?** Tier 1 makes the redundant pair cancel (fragile,
  keeps the density state and the slope machinery, keeps a `∂ₓg` in the state). Tier 2
  removes the redundancy, deletes the entire `dg/dh` apparatus, unblocks FF16/TF24/TF24f
  without a forward-mode port, and composes to the soil field — for a one-time migration
  cost.
- **How to weigh the model change?** As a re-baseline of a numerically-different but
  physically-equivalent (indeed more canonical) discretization, against the benefit of
  correct gradients for all four strategies and both resource fields plus a large code
  deletion.

---

## Addendum: converged review + refinements

Two independent domain-agnostic expert reviews of a neutrally-framed statement of this
problem *both* reproduced this design (conserved per-characteristic mass; loss-only mass
ODE; mass-weighted moments/fields; boring transpose reverse), reaching it with no domain
knowledge. Together with the derivation above and the Tier-1 experiment (which confirmed
the conservation-pair mechanism), that is four independent routes to the same method: the
method is settled; the open risk is implementation and re-baseline validation, not
correctness. Refinements to adopt:

- **Empirical-measure exactness (answers "which map is differentiated").** `n̂ = Σᵢ mᵢ
  δ(x−xᵢ)` is an *exact* weak/distributional solution of the transport law for the
  velocity field reconstructed each step; the moment weak form `dM/dt = Σ(φ'g − φr)mᵢ +
  boundary` holds as a discrete algebraic identity. The only approximations in the whole
  scheme are the field closure (knot aggregation + interpolation) and the time stepper —
  the same places the forward error already lives. The reverse gradient is the exact
  derivative of that frozen-schedule weighted-particle map; FD of it is the reference;
  the continuum limit is the parts-integrated moment law in which `∂ₓg` never appears.

- **Node placement: pre-ψ aggregate.** Deposit the aggregate `A(z_m) = Σⱼ mⱼ κ(z_m,xⱼ)`
  at the knots, reconstruct, apply `ψ = exp` per reader *after* reconstruction
  (`S(x) = ψ(B(x)·c_A)`). Source→node is then linear (exact rank-1 deposit, exact
  leave-one-out downdate if ever wanted), positivity/monotone attenuation are automatic,
  and `C¹` reconstruction suffices (the deepest field derivative anywhere is `S′` as an
  adjoint coefficient).

- **The one-sided edge seam is benign here (domain-confirmed).** A source crossing a knot
  would jump the deposit by `κ(z,z)·m` — but the crown kernel `Q(z,H) = (1−(z/H)^η)²`
  vanishes on its diagonal (`Q(H,H)=0`), so the value jump is zero. Only a
  deposit-*derivative* kink survives if `∂ₓκ(z,z)≠0`: `O(k/N)`, countable (near-knot
  source counter), erasable with a sub-knot `C¹` ramp if it ever fires.

- **Refinement/splitting is linear and moment-exact.** `(x,m) → (x⁻, αm), (x⁺, (1−α)m)`
  with smooth placement preserves every moment exactly through insertion and is
  tape-transparent; the trigger stays in the recorded pass, frozen.

- **Second / memory field composes.** Keep the memory linear in the mass deposits
  (`ċ_A = −c_A/τ + Σⱼ mⱼ κ(·,xⱼ)`), apply `ψ` per reader; one node, one transpose per
  field, nothing new to prove. (TF24/TF24f soil-water is exactly this case.)

- **Verification battery** (to run during implementation): JVP=VJP per primitive; FD of
  the *new* forward vs reverse, both parameter classes at the FD floor (now an unhedged
  prediction — no contested term remains); null-channel probe matching finite-N FD with
  **no cavity/mask anywhere**; a **reference twin** (exact pairwise one-sided sums over
  the frozen membership, reconstruction-free) diffed against the knot-node production
  gradient to isolate reconstruction bias; standing assertions on the recorded pass
  (order invariance, bitwise replay, near-knot-crossing counter); and an exact-mass
  conservation audit (`Σmᵢ` vs integrated loss + influx) as a free forward canary.

- **Claim to verify, not assume.** Both reviews assert the forward is *strictly better*
  (exact discrete conservation; a deleted secant/stiffness source; `m` bounded where
  `ℓ → ∞` under strong compression). Treat as a hypothesis: a parity run (both
  representations, moments + knot values over time, conservation, step-size behaviour) is
  part of acceptance, per the "never act on an Oracle claim without a test" discipline.

**Next phase:** this closes the *design* question. Implementation is a phased core
migration (state variable → mass; field assembly → mass-weighted deposit at a pre-ψ node;
birth map → influx mass; splitting → linear partition; serialization/resume/RcppR6;
reference re-baseline) with the verification battery as its acceptance gate — its own
planning pass, not undertaken here.

---

## Addendum — continuous-adjoint-lite probe (negative result)

**Question tested (user):** is there an advance that improves on Tier 1 *without*
reparameterising the model — specifically, can we keep the production forward pass
bit-exact (fd-stencil compression value) and still recover correct reverse-mode
gradients by injecting a well-conditioned derivative?

**Probe (`g_geom_seam`).** Keep the compression VALUE on the trajectory but tape the
geometric neighbour-difference DERIVATIVE `[g(x_{i-1})−g(x_{i+1})]/(x_{i-1}−x_{i+1})`
via a value/derivative seam `dgdh = geo − value(geo) + fd_value`. Idea: forward value =
production, taped derivative = Tier-1's ∂ₓg-cancelling operator.

**Result.** Reverse pass is machine-exact and cosine 1.0 — but against a *shifted*
finite-difference reference:

| param | baseline (production) FD | geom-seam FD |
|-------|--------------------------|--------------|
| b_0   | 319.38                   | 317.88       |
| k_I   | 0.144                    | 1.58e-6      |

The FD reference *moved* (b_0 −1.5; k_I collapsed five orders to Tier-1's value). A truly
pristine forward would leave the FD-of-model-as-run unchanged. It did not, for two
reasons that compound into one conclusion:

1. The substituted value (a cruder one-sided stencil) is not production's
   `gradient_fd`/Richardson value, so the trajectory forked immediately.
2. More fundamentally, the injected geometric derivative is Tier-1's mechanism, so the
   reverse is self-consistent with a **Tier-1 forward**, not production. The seam
   *reproduces Tier-1* while discarding production's exact value.

**Why it cannot be rescued.** Production's fd-stencil model genuinely has k_I sensitivity
≈0.144; Tier-1's geometric-compression model genuinely has ≈1.6e-6. These are *different
dynamical systems*. Correct AD *of production* must differentiate the fd stencil itself —
the ill-conditioned object the Oracle statement isolates, still unsolved. Any
well-conditioned derivative injected onto a pristine value yields the gradient of a
*different* model. There is no free lunch: forward-pristine-plus-gradients requires
faithfully differentiating the stencil (unsolved); well-conditioned gradients require the
model change (Tier 1). This confirms the "Land Tier 1" decision — Tier 1 is the minimal
correct model change, and nothing short of a model change delivers well-conditioned
gradients here.

---

## Landing note — Tier 1 shipped (opt-in)

Tier 1 landed in `plant` (`claude/ad-gate1-scm`, commit `abbf253a`) as an opt-in
Control flag, `node_geometric_compression` (default `FALSE`):

- **On:** the log-density transport `-∂ₓg` is the geometric neighbour difference of
  the growth rate across adjacent cohorts — the same discrete operator as the
  competition-quadrature spacings — so both copies of `∂ₓg` cancel on the reverse
  tape. Census gradients are machine-exact (`cosine(ad, fd) = 1.0`; `b_0` 317.883
  vs FD 317.883; `k_I` 2.04e-6 vs FD 2.04e-6). Compression moved from
  `Node::compute_rates` to `Species::compute_rates` (needs the neighbour list).
- **Off (default):** the upwind finite-difference stencil, bit-for-bit the
  published model. Full test suite green with the flag off (the K93
  "offspring production is unchanged" snapshots pass untouched).

**Why gated rather than unconditional.** Enabling it moves the K93 forward
trajectory ~0.2% off the upwind stencil (offspring production 0.075325 →
0.075453). That is a change to a *published* model's output, so it is opt-in:
ordinary simulations reproduce the paper, and differentiable runs enable the flag
(their forward is then self-consistent with the gradient). Scope is K93 (the only
forward-mode-instantiable strategy today); FF16/TF24/TF24f are unaffected. Flip
the default to `TRUE` if the geometric forward is later adopted as the canonical
K93 numerics.

This is the production endpoint for the census-gradient work; Tier 2
(conserved-number reparameterisation, above) remains the design-optimal but
higher-cost alternative, not required for correct gradients.
