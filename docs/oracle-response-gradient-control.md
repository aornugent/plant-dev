# Oracle response: control algorithms with guarantees

Reply to `oracle-consultation-gradient-control.md`, captured verbatim. The
assessment of it, and the one branch that resolves against it, are in
`docs/measurements/README.md` and the consult's own corrections.

---

Both failures are one theorem: an estimator built from the samples cannot
certify what lies between them. The embedded difference is an exact zero on a
missed event; a drop-one Richardson estimate is `O(1)` in a straddled jump. What
breaks the theorem is information from *off* the samples, and here it exists
before the run: the record's knots, and the establishment predicate evaluated on
a fine `b`-scan. Once the grid is placed by that information, the on-sample
estimators become valid again, and H1 turns from a constraint into the guarantee
you want.

## 1. Step rule

**(a)** The pointwise minimum is the right *stability* grid and the wrong
*sampling* grid. `h < w/0.3` guarantees the increment reads the event, not that
it integrates it. On a step containing knots of the `C¹` reconstruction, `s` is
only `C^{1,1}`, so the increment's quadrature is `O(h³)` local (Peano kernel with
`k = 2`, constant in the jump of `s''`) and the embedded difference is another
`O(h³)` quantity with an unrelated constant: the estimate is not asymptotically
correct on those steps, the tolerance means nothing there, and M13's 0.10%
residue is that term. A stop at each of the 2931 active knots makes `s` a single
cubic on every step; the local error expansion holds, the estimator estimates
what it claims to, order 5 returns, and rejections fall 43% (M14) because the
controller stops reacting to noise. So the object is

`𝒢_t = 𝒢_f^{act} ∪ 𝒢_b ∪ { fill at h = β/(mΛ(t)) }`

with `Λ` enveloping, over the θ-box, the chain's post-event relaxation *and* the
member fixed-point rate `(c+d)/z_max`. Every domain throw is the explicit step
overshooting that fast attracting fixed point, `h(c+d)/z_max` past the tableau's
real stability interval, and a designed grid has no retry. (For the adaptive
reference run, `a_dydt = 1` gives those near-zero components weight in the norm
and turns throws into ordinary rejections.) `β` sits inside the increment's real
stability interval, about 3 for a fifth-order six-stage tableau, so 2.5 with
margin. The `w/0.3` cap is then dominated and can go. Note the smooth-record cost
is stiffness-bound: `TΛ/β ≈ 40/0.003/3 ≈ 4400`, which is the 3972 you measured
with the controller riding the boundary (`u_L` binding 77%). No explicit grid
lowers it; only a linearly implicit chain does (H5, but five states, analytic
bidiagonal Jacobian, and the adjoint of the solve is the transposed bidiagonal
solve).

What it guarantees about `dJ/dθ`: on a frozen grid with `f` analytic on each
step, the global error has the Gragg–Stetter expansion
`J_h(θ) − J(θ) = h⁵e(θ) + …` with `e` smooth in θ, because the tangent of an RK
step is the same RK step on the variational equation. Hence
`∇J_h − ∇J = h⁵∇e + …`, and the discrete adjoint returns `∇J_h` exactly. A
passive `h` is the *correct* AD treatment, not a compromise: differentiating the
controller produces derivatives that do not converge (Eberhard & Bischof 1999;
Alexe & Sandu 2009). Two things the argument does not cover: a step crossing a
switching surface of `P` (`C⁰`, locally order 1; benign at the healthy point per
M1, not at `J = 1e-10`), and the establishment set, which is question 3.

**(b)** For discontinuities at a priori known locations the established treatment
is stop-and-restart there (Gear & Østerby 1984; Hairer–Nørsett–Wanner I §II.6; it
is what `tstop` in SUNDIALS exists for). Defect control off the stage abscissae
and dense output checked against a finer rule are for *unknown* locations
(Enright–Jackson–Nørsett–Thomsen 1988); their asymptotic-correctness guarantees
assume smoothness, and they find only what their samples land on, the same
blindness with a different sample set. Hierarchy: breakpoint stops guarantee the
local error expansion, hence the estimator and the order; the cap guarantees one
nonzero read per feature and nothing quantitative; defect and dense-output checks
add nothing here. M13's `y' = s` run, exact to `4e-12` with zero rejections once
forced to the breakpoints, is the demonstration. One non-smoothness survives the
knots: the saturation-excess partition `min(s, I(u))` switches on the *state*, so
its breakpoints are not a priori. Event-locate it or give it a declared smooth
width; probably small, but measure it.

**(c)** For the guarantee "every step lies in one polynomial span", the active
knots *are* the minimal set, and the premise that stops should be minimised is
wrong: a stop carries no member, cost is `Σ M(t)` over steps, and the aligned run
at loose tolerance took 8683 steps against 11 319. When a record's knot density
exceeds what the controller would take anyway (sub-daily data), change the
guarantee to "forcing-quadrature error ≤ ε_n per step". Because `s` is known,
that error is computable *exactly* offline for the increment's own weights,
`E(t_n,h) = |∫ s − hΣ b_i s(t_n + c_i h)|`. Sweep greedily to the farthest `h`
under the stability cap whose bound stays below `ε_n`; greedy farthest-feasible
is count-optimal for a predicate closed under sub-intervals (use the Peano
surrogate `h³·max|s''|` for the guarantee, the exact `E` to tighten it), and it
adapts to any spread of feature widths because it evaluates the integrand rather
than a width statistic. Keep stops at the ends of each wet run so dry steps stay
exact. Since `v̇ = s` is pure quadrature, `Σ_n E_n` is *exactly* the water-balance
error: the guarantee is by construction.

**(d)** Legitimate, with standard numerics: a time-triggered impulsive ODE is
integrated as smooth flow between known jump times with the jump map applied and
a restart at each; the method keeps its order (there is no forcing quadrature
left to lose), and the adjoint picks up `λ⁻ = (∂Φ/∂x)ᵀλ⁺` automatically if `Φ` is
on the tape. The flow's error estimate is better founded than now, autonomous and
smooth between jumps. But it buys nothing over knot stops (1387 impulses against
2931 stops, same order of cost), and it is a real model change: with `q ≈ 16`,
`∫κu₁^q` over the day after 40 mm delivered instantaneously differs materially
from the same water spread over a day, and the partition is currently bypassed on
that path. Daily totals contain no sub-daily shape, so the `C¹` hump is invented
too; the choice is hydrological (infiltration-excess needs a rate,
saturation-excess a volume), to be declared and its effect on `J` measured. There
is no numerical reason to move.

## 2. Cohort mesh

**(a)** First the object. The cohort set is a characteristics (escalator-boxcar)
discretisation of a size-structured transport equation with nonlocal canopy
coupling; its convergence proofs (Brännström–Carlsson–Simpson 2013) assume a
smooth birth flux. Yours is `1[G(b) > 0]·(…)`; transport carries the
discontinuity along characteristics and never smooths it, so the jumps are in the
continuum `J`, not an artefact of the mesh. The standard construction for a
quadrature with known discontinuities is composite: panel boundaries at the edges
`β_i` (roots of `G(·)` on the reference environment, to the `1e-3` the switching
surfaces are resolved), any rule inside. Under H3 the five reductions share
nodes, so one edge set fixes all five. Inside the support, equidistribute
`M = max(|∂_b²(wφ)|, floor)^{1/3}`, the trapezium's optimal monitor, floored so
the floor carries about half of `∫M` (Huang–Russell), and, since the deliverable
is the gradient, maxed with `|∂_b²∂_θ(wφ)|^{1/3}` for the parameters that matter,
from the reference adjoint. Guarantee:
`|J − J_N| ≤ (∫_Ω M)³/(12N²) + Σ_i g(β_i⁺)·δ_i`, with `δ_i` the edge-location
error. The second term is first order in `δ_i` and does not shrink with `N`. The
present indicator's defects (leaf-area normalisation, max of absolutes, wrong
term) are real but secondary: a drop-one estimate across a straddled jump is
`O(1)` in the jump for a rule of any order.

**(b)** Yes, second order returns for the value; M7's orders of 1.3–1.9 are what
the current mixed regime looks like, an `O(Δ)` straddled-jump term added to
`O(Δ²)`. Inside panels the integrand decays like `e^{−b/τ}` with `τ ≈ 0.75` yr
(your 8% per sixteenth), so `w'' ~ w/τ²` and the trapezium's panel error at
`Δ = 1/16` is about `1e-4` relative. A higher-order output rule is free on nested
nodes (Romberg) but is not the binding term (M11); the forward canopy reduction
is, and its weights are also passive constants under H3, so a composite
higher-order rule over the support is available there too. Raise both or neither,
since M11's sign pairing decides whether raising one helps. The warning: a node
placed *on* an edge is the node that flips first under any `δθ`, moving `J_N` by
`w⁺Δ/2 ≈ 0.4%` here. Nodes at the jumps are the right value construction only
together with 3(a).

**(c)** The jump set is causal: establishment at `b` depends on cohorts born
before `b`, so it is a triangular fixed point that a construction marching in `b`
resolves in one pass. The loop cycles because it rebuilds the whole mesh and
reruns, letting later nodes' canopy changes reclassify earlier nodes wholesale,
which is M17's `+6.19/−12.76%`. The remaining dependence of `φ_j` on later
cohorts through the canopy is smooth, is ordinary discretisation error, and
converges under refinement without iteration (M11's smooth-record ladder). What
is known: alternating solve/remesh converges when the monitor–solution map is
smooth (de Boor; MMPDE theory); with a map that flips there is no theory, and
cycling is the expected outcome. Build causally at `θ_ref`, run once, re-scan `G`
on the realised environment (3b), insert a node where an edge moved, run once
more, freeze.

**(d)** Clean form. Let `R(b)` be the member-evaluations a node created at `b`
incurs, stages times steps remaining, known from the reference run. Cost is
`∫R n_b db`, trapezium error `∫M³n_b^{−2}db/12`, and the Lagrangian gives
`n_b ∝ M·R^{−1/3}`, or `R^{−1/(p+1)}` for a rule of order `p`. `R` spans about
20× between `b = 0` and `b = 38` here, so the cube root coarsens the early mesh
about 2.7× relative to a monitor-only mesh at equal total error. The dyadic
generator's `Δ ∝ b` density is the opposite of what the weight asks, and M17's
17-node graded mesh says the monitor doesn't ask for it either. The multiplier is
set by the certificate's error target.

## 3. Converged answer, usable derivative

**(a)** The reading is right. With `E(θ) = {b : G(b,θ) > 0}`,

`dJ/dθ = ∫_E ∂_θ g db + Σ_i ± g(β_i)·∂_θβ_i`,  `∂_θβ_i = −∂_θG/∂_bG |_{β_i}`

— the Reynolds/Leibniz transport term, the same object as the adjoint jump
condition in hybrid-systems sensitivity (Galán–Feehery–Barton 1999). The
fixed-set adjoint computes the first term on the frozen set and misses the
second, and `J_N(θ)` itself jumps at flips (M1's 0.3–0.4% steps). One check
first: if `P_est(G) → 0` continuously as `G → 0⁺`, `w` is `C⁰` with a steep ramp
of width `a/|∂_bG|` and the transport term is *zero*, the sentinel marking only
an unresolved ramp; if `P_est(0⁺) > 0`, it is a true jump. Treatments, ordered by
how much they change the model: (i) add the term explicitly, `∂_θG` by AD of the
pointwise scalar and `∂_bG` by differencing along the record; cheap and exact in
the limit, but the pair (`J_N`, corrected gradient) is inconsistent near flips
and a line search will notice. (ii) `σ_ε(G)`: the tape then carries
`∫σ_ε'(G)∂_θG·g db`, which *is* the transport term smoothed; `J_N(θ)` is smooth,
and the mesh must resolve features of width `ℓ_i = ε/|∂_bG_i|` wherever the edge
sits over the box. (iii) `C⁰` collapse, `P_est ∝ G⁺` near zero: no transport
term, kinks only; the trapezium keeps `O(Δ²)` because only `O(1)` panels straddle
a kink at `O(Δ²[w'])` each, and the gradient is continuous.

What sets `ε`: from below, the resolution of `G`, the `1e-3` classification
tolerance and the tabulation's `1e-5` second derivative, because beneath it you
differentiate classifier noise; from above, the bias, which for a symmetric
switch is `O(ε²)` with constants in `g'(β_i)/(∂_bG_i)²`, computable from the
reference run; node cost falls with `ε` as `Σ_i 5(sweep_i·|∂_bG_i|/ε + 1)`, so
take the largest `ε` the bias budget admits. Wet edges have `|∂_bG|` of order
per-day and give needlessly narrow ramps; a declared establishment window, `Ḡ` as
an exponential-moving-average state with timescale `τ_g` of weeks, bounds
`|∂_bḠ| ≤ G_max/τ_g` and makes the ramps uniform. Both `ε` and `τ_g` have
modelling readings, since establishment is not a step in reality, and that is the
defensible justification, declared and measured.

**(b)** Once the integrand is smooth between nodes, DWR is available and assumes
no power law: `J − J_N ≈ Σ_t λ_a(t)·[canopy quadrature defect](t) + [output-rule
defect]`, defects from a higher-order rule on the same samples (Estep 1995;
Cao–Petzold 2004 for the time part). Before that, no on-node estimator can
certify what lies between nodes, the same theorem as M12. What can: `G(b)` for a
hypothetical newborn is a pointwise scalar of the recorded environment, so a
daily scan after the run (14 599 evaluations) verifies that no `b` between nodes
is misclassified relative to the panel structure. The certificate has three
parts: the scan agrees with the panels; panel-wise Richardson or DWR on the
smooth part; adjoint-weighted defect for the time grid. M17's two independent
constructions agreeing to 0.20% when both resolve `[5, 11]` is the informal form.

**(c)** Relative gradient error `η = ‖ĝ − g‖/‖g‖ < 1` gives descent; `η ≲ 0.3`
gives near-nominal rates; trust-region methods converge globally with `η` up to
about `1 − η₂` (Carter 1991). Quasi-Newton updates need the error small relative
to the gradient *difference* `y_k` (Xie–Byrd–Nocedal 2020), stricter near
convergence, and the inexact frameworks require `‖e_k‖ ≤ κ·min(‖ĝ_k‖, Δ_k)`
(Kouri–Heinkenschloss–Ridzal–van Bloemen Waanders 2013): the error must shrink as
you converge, which a fixed grid cannot do, so refinement in the loop (4c) is
part of the method, not a repair. M6's 1.6–4.6% is a descent-quality gradient;
M5's short-horizon sign flip is `η > 1` and fatal, but not the case at `T = 40`.
For the *answer* rather than the path, `‖θ*_N − θ*‖ ≈ ‖H⁻¹δg‖` with `δg` the
gradient *bias* (transport term, `O(Δ²)`, `O(ε²)`, `O(h⁵)`), so the target is
`‖δg‖ ≲ σ_min(H)·δθ_target`, and `δθ_target` need be no finer than the
data-limited posterior width. Two implications: the certificate in (b) must bound
the gradient bias, not the value's; and optimise `J_{N,ε}` with its own exact
adjoint gradient, discretise-then-optimise, never a discrete objective paired
with a continuum-corrected gradient.

## 4. One grid across θ and records

**(a)** The value DWR does not certify the gradient: `∇J_h − ∇J = h^p∇e`, and
`∇e` is not controlled by `e`. The principled certificate is the DWR of the
functional `∂_kJ`, whose adjoint is the θ-tangent of the adjoint:
forward-over-reverse, one seed per parameter (17× the adjoint cost, or a few
random directions for a probabilistic bound), run once per certificate, not per
iteration. The cheaper sufficient condition, and what inexact-TR frameworks
actually consume, is the nested-grid gradient difference `‖∇J_{N'} − ∇J_N‖` at a
few points spanning the box, plus a combinatorial check that no discrete event
differs between them: no cohort flip, no inner-classification change on the tape.
M5's tangent agreement certifies the differentiation, not the discretisation;
they are different objects.

**(b)** Yes, dominant, and computable. Under a hard switch, node `j` flips at
first-order radius `r_j = |G_j|/‖∂_θG_j‖`, so the frozen-grid trust region is
`min_j r_j`, zero for a node on an edge, and over a box the frozen-edge error is
`Σ_i w⁺_iΔ_i` in the value and the transport term `Σ_i g(β_i)|∂_θβ_i|` in the
gradient, `O(1)` in `Δ`. Under `σ_ε`, the trust region is where the mesh resolves
the swept feature: bound `β_i(θ)` over the box by evaluating `G` on the daily
scan at the box corners (or `β_i ± Σ_k|∂_{θ_k}β_i|δθ_k`) and check `Δ ≤ ℓ_i/5` on
that interval. All of it from the reference environment and a scalar function.

**(c)** Yes, with two additions. One designed time grid per record (active knots
plus `β/(mΛ)` fill, `Λ` enveloped over the box) and one cohort mesh per record
*per box* (swept edge intervals plus cost-weighted equidistribution on the
support), recaptured when the optimiser leaves the box or the post-run scan flips
a node. Zero transfer across records is expected; the rules transfer, the grids
do not. A recapture changes the discrete objective, so nest the new grid over the
old on the overlap (the change is then certified small) inside a trust-region
loop that tolerates model changes between iterations. And the stability envelope
is the primary certificate: M10's wrong replays sat at `h|λ|` 1.7–3.2× the
adaptive run's. A frozen grid fails by instability before it fails by accuracy,
and unlike the controller it cannot retry a throw.

Order I would do it in: knot stops and enveloped fill (cheap, and it shrinks the
run); read `P_est(0⁺)`; causal cost-weighted mesh with edges or swept bands;
`σ_ε` or `C⁰` collapse, declared; then the three-part certificate.
