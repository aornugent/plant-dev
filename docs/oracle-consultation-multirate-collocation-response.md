# Oracle response — reduced-member coupling on the evolved member set

*Response to [`oracle-consultation-multirate-collocation.md`](./oracle-consultation-multirate-collocation.md).
Recorded verbatim (lightly reformatted). Dated 2026-07-18. Hypotheses to test, not verdicts; supplies
experiments E0 / E-A — run E-A (exact-flow split composed) as the deciding datum; E0 (offline estimator
shootout) can run in parallel.*

---

## Headline: Probe C refutes an estimator class, not the lever; Probe D re-denominates every tolerance; Lever 1 is promoted to primary

Three verdicts up front. **First:** member-count reduction remains a valid lever, but the estimator you
measured is the wrong species — all three Probe-C variants *subsample the measure*, and a skewed measure
punishes that with exactly the ~10² constant you saw. The fix is to separate measure from integrand: the
skewed, rough object (ρ) gets integrated **exactly** over all M members — which costs O(M) *arithmetic*
but **zero member solves** — while only the smooth object (c∘p in ξ) is reduced. **Second:** Probe D does
not forbid approximate coupling; it changes the currency. Every accuracy budget in the scheme — including
ones already accepted — must be restated in J-units, ~10× tighter than u-units, and that applies
retroactively to the built skeleton's "0.5% forward match." **Third:** the exact-flow split is now the
highest-ranked lever, because it is exact (no accuracy knob, no bias risk), unmeasured (the deciding datum
is missing), and it cuts the *reverse-mode tape* by the same factor as the forward cost — so measure it
composed before investing anything further in Lever 2.

## 1. The distinction Probe C surfaces: expensive-O(M) versus free-O(M)

Your cost unit is one member *solve*. A sum over all M members' already-known state — `ξ_j`, `ρ_j`, both
plain components of `y` — costs nothing in that currency. Every estimator in Probe C tried to avoid
touching all M members even arithmetically: uniform-index subsampling drops most of ρ's mass;
interpolating ρ onto synthetic coordinates smooths a spiky, huge-dynamic-range object (hence the NaNs in
log ρ); subsampling own-(ξ,ρ) still represents a concentrated measure by a sparse unweighted sample. None
of that is necessary. Write the coupling as measure × integrand and reduce only the integrand:

```
a_ℓ(u) = Σ_j ρ_j c_ℓ(ξ_j, u, p_j) ≈ Σ_{r=1}^{d} β_{ℓr}(u) · G_r ,
G_r = Σ_{j=1}^{M} ρ_j φ_r(ξ_j)      ← exact, once per leg, zero solves
```

The `G_r` are generalized moments of the frozen member measure — O(M·d) flops per leg, computed from
state the leg already holds. The coefficients `β(u)` come from evaluating `c` at d node members per micro
step. All the skewness lives in `G_r`, integrated exactly; the only approximation is interpolating
`c(ξ, u, p(ξ))` in ξ — and **the smoothness that licenses that is a property of the physics, not of the
member placement**. Probe B verified it and nothing in the evolved set touches it; what evolved is ρ,
which this estimator never approximates. Prediction: the ~10² constant collapses back toward Probe-B
levels. That prediction is testable offline in a day (§5, E0), on the saved mature state, before writing
any solver code.

Note also what this means for gradients specifically: the moment/interpolatory weights are active in *all*
M members' `(ξ_j, ρ_j)`, so every member keeps its measure-channel sensitivity even when only m are solved
per micro step. Index subsampling zeroed the adjoints of dropped members outright — with skewed ρ that
deletes the *dominant* sensitivity channels. Probe C's estimator was even worse for the gradient than for
the value.

## 2. The estimator, best-in-class form for a skewed evolved set

**(a) Peel the heavy atoms.** Skewness is an asset once you stop fighting it: the h members individually
carrying a large mass fraction (choose by `ρ_j`, or `ρ_j`×a bound on |c|) are evaluated exactly at the
micro rate. By your own description h is small. Their full nonlinear-in-u channel — value and adjoint —
is exact.

**(b) Quadrature the tail.** For the smooth remainder: pick m_tail node members by approximate-Fekete/Leja
selection over the candidate ξ's (column-pivoted QR on the Vandermonde — Bos–Sommariva–Vianello's discrete
extremal sets; per smooth piece, split at the regime boundaries you already track), then solve the small
moment-matching system so the node weights reproduce the exact tail moments `G_r`. If you want guaranteed
nonnegative weights supported on existing members, Carathéodory recombination (Litterer–Lyons 2012;
Tchernychova–Lyons) reduces the M-atom tail to ≤ d+1 atoms matching d moments exactly — the principled
upgrade if the QR-selected weights ever go badly signed (monitor `Σ|W|/|ΣW|` as before).

**(c) Anchor and monitor.** Your Q3 proposal is endorsed, with its limit stated: carrying
`Δ = a_full(u₀) − a_red(u₀)` across the leg leaves a residual equal to the *variation* of the defect over
the leg's u-motion, so anchoring rescues a good estimator and cannot rescue a bad one (a 38% defect from
missed mass has a comparably large u-derivative). With peel+moments the defect is small *and* flat, and Δ₀
mops up the remainder. Optionally add the first-order anchor `Δ₁ = ∂_u(a_full − a_red)|_{u₀}` — cheap via
closed-form `∂c/∂u` at the stage, constant matrix, so the fast Jacobian treatment is untouched (and note
this does not fall under the refuted linearization: it linearizes the *defect* of an exact-in-u model, not
`a` itself). Most valuable of all: the anchor is a **free realized-error meter** — at every macro stage the
fresh full-M value against the reduced prediction measures the leg's actual defect drift, at zero solve
cost, feeding pass-1 adaptation of (h, d, splits). Probe D demands exactly this closed loop.

**(d) The sacred property is preserved.** The reduction is exact in u — `c` is evaluated at the live
micro-state u at every node; only the ξ-integration is approximated, and the fast Jacobian's coupling block
is the same quadrature applied to `∂c/∂u`, with the same small relative error. The refuted
frozen/low-order-in-u class is not re-entered.

## 3. Lever ranking, and the experiment that decides it

**Lever 1 first, and not only for forward cost.** The recession map is exact physics with no accuracy
knob, and it is a superb tape citizen: one closed-form, smooth elementary expression replaces dozens of
stiff micro-steps of taped RK arithmetic — the reverse sweep's cost tracks micro steps, so Lever 1 cuts
forward *and* adjoint cost with zero bias. Lever 2, whatever its form, carries bias risk that Probe D
amplifies 10×. That asymmetry fixes the order of operations.

**E-A (the deciding measurement):** compose the split with live member solves on 3–5 recorded macro
intervals spanning quiet and episode regimes, with *exact full-M coupling* per micro step (expensive, but
it's a few intervals). Record: n_micro per macro step by regime; error **in J-units** against the tight
reference; and — pin down a discrepancy between rounds — whether the ≈11 setup is per-(member, u) or
cacheable per-(member, leg) (last round's settled facts said the heavy part is u-independent and memoized;
this round's recap charges 11 per u-change; the factor ~3 sits directly in the verdict). Decision rule:
with `cost ≈ n_micro × M × c_eval` against the floor `≈ M × 21`, if the ratio is ≲ 2–3, **ship Lever 1
alone and never build Lever 2** — exact coupling, zero bias, smallest tape, simplest adjoint story. If
n_micro stays large, it will be concentrated in episodes — which is exactly where J is most sensitive, so
the honest conclusion is that Lever 2 is needed precisely where it is riskiest; that is what the
monitor-carrying estimator of §2 is for, validated on episode windows in J-units.

Two composition details before E-A: arrange the split Strang-style (half-recession ∘ remainder ∘
half-recession, coupling evaluated at the half-recessed state) so the splitting error is second order —
the commutator involves κ′, which is huge at the high-u end, so measure the composed scheme's order in
J-units rather than assuming it; and keep the `u_min` floor inside the recession map as an active event
(the map is smooth except at the floor — same clamp/event treatment as established).

**Lever 1's polished endgame, worth one experiment if E-A is borderline:** with stiffness removed, the
per-leg fast problem is a *gentle* IVP, a natural target for collocation-in-time / spectral-deferred-
correction with 3–6 points per leg instead of an adaptive micro march. That caps n_micro by construction,
places the coupling evaluations at fixed nodes (which meshes cleanly with the anchor and the
frozen-schedule tape), and may make Lever 2 permanently moot.

## 4. What Probe D actually changes

It re-denominates, retroactively. The built skeleton was validated at "≈0.5% forward" — a u-norm number;
at ~10× amplification the same scheme may sit near ~5% in J, out of budget before any reduction is even
introduced. So the first action item is not about Lever 2 at all: **re-validate the existing composed
scheme directly on J** (and, per the standing footgun from two rounds ago, on dJ/dθ via
Richardson-in-the-knobs — now mandatory, since adjoint-vs-FD at 1e-8 certifies consistency with the scheme
as run and says nothing about reduction bias, which Probe D says is 10×-amplified into exactly the object
the outer loop consumes). The likely mechanism — `p*(u)` sweeping its range near `u_min`, flagged when
Probe A's Newton divergence first appeared — implies the amplification is episode-concentrated, so
tolerance control and validation should weight episode windows, and every knob (micro tolerance,
splitting order, k-lag, h, d, m) gets its budget set by its J-sensitivity, not its u-sensitivity.

## 5. Ranking (Q5) and the missing items (Q6)

**Load-bearing:** the solve-vs-arithmetic cost distinction (the single fact that dissolves Probe C's
apparent refutation); Probe D's amplification (the budget currency for everything); the exact-flow map
(exact, knob-free, tape-shrinking — and unmeasured in composition, hence the top experiment); the
smoothness of `c` and `p*` in ξ (unrefuted, the license for any reduction); the free full-M evaluation at
stage boundaries (anchor + meter). **Incidental:** Probe C's specific constants (an estimator artifact —
though its *lesson*, that ρ must be integrated exactly, is load-bearing); the members' placement-for-x(t)
(irrelevant once measure and integrand are separated); the NaNs (a symptom of interpolating the measure —
the rule is simply *never do that*); the skewness itself (an asset under peeling).

**Missing/quietly contradicted:** (i) the J-norm validation gap above — the framing "forward matches to
0.5%" was the wrong norm all along. (ii) The experiment sequence: run **E0** — a one-day offline shootout
on the saved mature state (uniform subsample vs peel+moment-quadrature vs recombination, each ± anchor,
over a u-excursion sweep, errors propagated to a J-proxy) — before E-A if you want the Lever-2 question
pre-answered in parallel; it needs no new solver code. (iii) The insertion schedule *could* be given a
mass-concentration cap so evolved sets stay quadrature-friendly, but that raises M and touches the model;
prefer the estimator fix. The extreme concentration of ρ does whisper a model-level question — whether the
x-resolution criterion is maintaining members that J never feels — but that is a science decision about
what M should be, not a numerics lever, so I flag it and stop. (iv) The skeleton stands: the step collapse
is solved by it, single-rate would re-import the collapse, and what remains is per-step cost — which is
Lever 1's job first, and the corrected Lever 2's only if the measurement says so.
