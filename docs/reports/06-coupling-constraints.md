# Constraints on any solution to the leaf–soil coupling

**What this is.** Data, not a design. Every line is something a solution must satisfy or
work around, with the measurement behind it. Collected from the multirate branches
(plant-dev `claude/tf24-multi-rate-stepper-n5audm` and
`claude/multirate-stepper-review-r6dpwn`; code on plant
`claude/tf24-forward-speed-n5audm`).

**Provenance discipline.** Those branches carry the *same* retention physics as develop but
a *different guard construction*, so their measured symptoms transfer and their attributed
mechanisms do not. One import already went wrong this way (§C1). Every line below is marked:

- **[M]** measured, with a script and numbers
- **[M/b]** measured on the branch, mechanism **not** verified against develop
- **[D]** derived or algebraic
- **[X]** a claim that later measurement **refuted** — recorded so it is not re-inherited

Where a document and a later measurement disagree, the measurement wins. Several Oracle
conclusions in that corpus were overturned by their own follow-up tests; §X lists them.

---

## A. The functional is not always an observable

**A1 [M] `J` is meaningful only at long horizon.** Offspring against patch lifetime, single
resident: 3 yr `1.1e-15`, 5 yr `4.1e-13`, 8 yr `5.4e-10`, 12 yr `2.7e-7`, 20 yr `1.4e-5`.
Below ~12 yr the run is pre-reproductive and `J` sits on the numerical noise floor.
**Any validation at short horizon is scientifically void**, however convenient. This
directly contradicts gating verification on `life >= 4`.

**A2 [M] Near extinction, the functional is ill-conditioned for every method while the
trajectory is fine.** Refining one method's *own* time discretisation moves offspring by
O(1)–O(10), **non-monotonically** (one trace: `8.2e-8 -> 1.5e-8 -> 4.7e-6`), while the soil
trajectory converges to `<= 5.5e-4` on the same refinement. So a trajectory-convergence
result is not a functional-convergence result, and a non-monotone tolerance sweep is a
signature of the regime rather than of a bug.

**A3 [M] The rainfall scenario bank is a speed and robustness vehicle, not an accuracy
vehicle.** All six bank traces give offspring `1e-8`–`1e-13` even at `birth_rate = 20`; an
lma sweep 0.04→1.0 is monotone-decreasing with a best case ~`2e-10`; scaling rainfall 1×→20×
never lifts one trace above ~`1e-9`. **The same species and birth rate give offspring 1.03
under constant rainfall.** The traces were built as soil-integrator stress tests and are
near-extinction by construction, so they sit permanently in A2's regime. Accuracy has to be
judged where the functional is well-conditioned — the model's own seasonal driver at the
sustaining rainfall mean with amplitude dialled up, where offspring is O(1).

**A4 [M] There is no global explicit reference on the hardest traces.** Cash–Karp fails with
"Detected non-finite contribution" on 3 of the 6 bank traces at converged tolerance, and the
failure is `birth_rate`-independent (swept 20→2000). It is the cohort-density blow-up, a
**model** divergence rather than a solver overflow. RODAS and IMEX are not available on the
SCM patch (no rebind hook, no active scalar). So on exactly the traces where the coupling is
hardest, **no reference exists** — and completing a trace that the reference cannot is not
evidence of being right: where a reference was obtainable, the alternative sat ~1400× away
from it, both values deep in A2's regime.

**A5 [M] plant has two tolerance families and converging one does not converge a reference.**
An entire accuracy table was invalidated because `ode_tol_rel/abs` were left at their `1e-4`
default while the inner tolerance was converged; the reference carried ~`4e-3` of its own
integration error, and one headline moved from `1.8e-4` to `3.5e-3`. Any FD reference must
state both families.

## B. What the coupling does, structurally

**B1 [M] The coupling's adjoint is ordered by the light field.** The per-cohort shadow price
of water `lambda_j = (dP_j/dtheta)/(dE_j/dtheta)` is monotone in cohort height, spread 2–4×
across the profile (CV 35.6% wet, **60.0% mid**, 20.0% dry). Taller, better-lit cohorts value
water 2–4× more. Consequence: the light interpolant's accuracy and the soil coupling's
accuracy are the same question, and **no single shared price is admissible** — a shared
`phi(theta)` misprices understory against canopy by up to 4×.

**B2 [D] There is an exact, cheap test for whether a future model admits the collapse.**
Sample the control across its feasible range at fixed state and regress `dP/du` on `E`; the
collapse holds only if that is affine with a member-independent slope. A dozen closed-form
evaluations, no re-solves. Worth running per new member model rather than reasoning about it.

**B3 [M] Two stiffnesses, and the persistent one is the coupling itself.** Drainage
(`theta^16.14`) reaches `dK/dtheta ~ 4600/day` but only in a fully wet layer — episodic.
Uptake stress (retention `theta^-6.57`) dominates hydrology by **8×–291×** in a real
transpiring stand and appears as dry pockets even in wet runs. The divergence exponent is
measured at **−6.56 = −n_psi**: the coordinate the state is carried in is implicated, not
just the rate.

**B4 [D] The near-bound eigenvalue is chart-invariant.** `lambda = gamma·r/(d·delta*)` —
turnover is throughput over stock — and it diverges as inputs dry. No change of variables
removes it. It splits into a **fall** regime (input collapses, accuracy-limited, no method
enlarges those steps) and a **floor** regime (sitting at the depleted balance,
stability-limited, where implicit wins). A chart can remove a singularity and a clamp; it
cannot remove this.

**B5 [M] The soil block's Jacobian is lower-bidiagonal plus diagonal**, because the
inter-layer cascade is one-directional. Real spectrum, no oscillatory stiffness, and a
Rosenbrock solves it by forward substitution with better adjoint conditioning. At `L <= 5`
that is nearly free, and RODAS4(3) with `ode_jacobian.hpp` is already on odelia master.

**B6 [M] Switch-off keys on the *least* stressed accessible layer.** A cohort shuts down only
when **every** rooted layer is past the threshold, so one benign layer keeps it on — measured
with 4 of 5 layers at or past `psi_crit` and no shutdown. Combined with all-layer rooting, no
upward capillary flux, and a deep layer that asymptotes at `theta ~ 0.19` (`psi ~ 0.37 MPa`),
hydraulic shutdown is **structurally near-unreachable**: the stand starves on top-layer stress
while rooted into deep water. If TF24 is meant to represent hydraulic-failure mortality, the
current soil–root coupling suppresses it. That is a model-mechanism question, not a numerics
one.

## C. What is develop's, and what is not

**C1 [X] The dead drought-gradient channel is not develop's.** The branch attributes an
identically-zero `d(uptake)/d(theta)` below `theta ~ 0.11` to `soil_psi_max_ = 1e3`, a cap on
matric potential. **That member does not exist on develop**, which floors *theta* at
`soil_moist_residual = 1e-2` inside `psi_from_soil_moist` instead. On develop's own constants
(`retention-thresholds.py`):

| threshold | theta | on develop |
|---|---|---|
| collar pins at `psi_crit` ~ 5.9 MPa | **0.1246** | yes |
| the branch's 1e3 MPa ceiling | 0.0571 | **no** |
| develop's theta floor | 0.0100 | yes, 13× below the operating range |

So develop's flat-derivative severance is genuinely unreached. What is on develop is the
**pinning**, and since the retention curve is identical it bites at `theta = 0.1246` while the
measured driest layer reaches `0.133` (`psi = 3.85` against `psi_crit = 5.9`) — a margin of
2.05 MPa, or 6% in moisture.

**C2 [M/b] The measured anatomy of a hard moving boundary still applies.** A hard moving
regime boundary degrades adjoint-against-FD by **five to six orders**; smoothing at a declared
scale restores **~1e-9**. The mechanism is a Leibniz boundary term
`[jump] x d(location)/d(theta)`: a subgradient tape drops it entirely, an FD smears it over
the perturbation, and the ratio between missing and smeared is unbounded. This is a general
statement about differentiating a moving switch and does not depend on which construct creates
the switch.

**C3 [M] The operating point is an active constraint, not a maximiser.** Objective geometry at
fixed state: flat shelf, jump of ~1.5, then smooth decline at slope **−8.8**, with the
operating point at the corner. The jump is the inner assimilation solve falling to its
non-productive branch (`ci` 4.331 → 5.488 across it, net assimilation at the `−R_d` floor on
the wet side). So the envelope theorem never applied — the profit floor scales `O(eps)` with
measured log-log slope **1.06** against a predicted 2 — and any adjoint that freezes the
operating point drops first-order terms.

**C4 [M] The working primitive exists and is faster.** A *bracketing* root-find on the
existing analytic gradient `Leaf::dprofit_droot_collar_psi`, safeguarded by endpoint signs,
converges to the gradient's sign change, which is what a corner is, and needs no second
derivative. Measured 1.20× faster whole-solve, with the inner-tolerance quantisation of the
argmax removed.

**C5 [M] The derivative branch must be keyed off the solver's own test.** The two-branch
uptake Jacobian validates to median `4.2e-5` / max `6.1e-4` including the dry tercile — but
only when interior-versus-boundary is dispatched on the same endpoint-sign test the solve used.
Interior-only was `4.5e-2` wrong in the dry tercile; dispatching on a *residual threshold*
instead still left states at **30–50%**; the sign test drove worst case `5.0e-1 -> 6.1e-4`.
Error correlates with boundary-pinning (Spearman 0.71), not with dryness as such.

## D. What the numerics can and cannot buy

**D1 [M] The continuum functional exists and is a stable observable.** Arnoldi on the
self-consistency map: `rho(T') ~ 7–8`, **nothing at +1**, nearest real mode 0.05–0.2 away, so
`||(I-T')^-1|| ~ 5–22`. Non-convergence under mesh refinement is a discretisation-protocol
artefact, not ill-posedness. The ~23% inter-scheme spread reads as conditioning (5–20) × an
O(1–5%) discretisation error. *(This verifies a previously quarantined claim about the
resolvent.)*

**D2 [M] Mesh non-convergence is 100% field-shift, ~0% quadrature, and diffuse.** On a common
frozen field, putting a 1.5× denser measure on the *same* field moves `J` by ~0% (`6.3e-10`,
`2.1e-9`); letting it feed back moves `J` by 69–84% — **100% of the change**, spread across
the axis (top 3 of 4000 bins carry 2–3%), concentrated where `J`'s mass is. **So `J`'s own
integrand is already converged at the production mesh and the error lives in the coupling
field.** This is why a refinement indicator aimed at reproduction anti-correlated with the
true error: it targeted the converged thing. The correct indicator targets the field's
convergence weighted through the feedback resolvent.

**D3 [X] Model-side mollification is not what blocks convergence.** D2 overturns the earlier
verdict that an intrinsic survival-boundary discontinuity drives mesh non-convergence. It does
not. **Keep this separate from C2**: mollification is off the critical path for *convergence*
and remains on it for *differentiability*. Those were being treated as one question.

**D4 [X] There is no heavy atom to split.** The heaviest cohort carries **~1.6%** of the mass
at the default mesh, halving on each doubling (clean `1/M`). An Oracle claim of ~40% came from
misreading a whole second species' share of two-strategy `J` as one cohort's share within one
species — about 25× apart. Measure-splitting machinery was designed on that premise and is
dead.

**D5 [M] The functional needs only the weekly-and-slower envelope of soil moisture.**
Low-passing the soil trajectory: removing all texture below ~2 days changes `J` by ~3%, weekly
by +14%, monthly 2.3×, seasonal 15×. The knee is between weekly and monthly, while the shared
step is sub-daily (0.07–0.26 day) — so the O(M) cohort block is integrated **30–100× finer than
the functional requires**. Caveats: open-loop, one sequence; a burst-dominated trace could move
the knee finer.

**D6 [X] Waveform relaxation is dead, and damping cannot save it.** One Picard sweep amplifies
a coupling perturbation by `kappa ~ 10`, consistently across step sizes and across every 2-yr
window (5–12). For an expansive positive round-trip gain, the damped iteration has spectral
radius `|1 + 9w| > 1` for **every** `w > 0`. The coupling that makes the problem hard is exactly
what makes relaxation expansive.

**D7 [M] Down-weighting the step-limiting members is a modest lever, because they overlap the
members `J` needs.** ~30% of accepted steps are limited by the reservoir block, which a
member-weighted norm cannot touch; of the member-limited remainder, 14–21% are dominant
members; and within the marginal rest, **a third to a half are dying** — heading to the
absorbing boundary, which is precisely what `J` is sensitive to. Cleanly reclaimable: roughly
**10–20%** of accepted steps. A member crossing the threshold has fast local dynamics *and* is
`J`-critical, so the two populations are not separable by weight alone.

**D8 [M] The forcing driver is a C² cubic spline through daily knots, and it is a real but
minor lever.** Size-matched, a step crossing a knot rejects **+12 to +36 pp** more than an
identically-sized step between knots — a genuine third-derivative-jump effect that no prior
instrument had looked for. But only **1.3–3.9 pp** of the 27–31% total rejection is
knot-attributable. Flat dry-spell knots are harmless, because a cubic spline through equal
values is exactly constant. So the sub-order-2 cost wall is *not* the forcing representation.

**D9 [M] Frozen-field replay is faithful exactly in the rare limit.** The error is
O(mass fraction) and vanishes as the probe's weight does: relative `J` gap 63.4 at mass
fraction 0.388, 0.036 at 0.0064, 0.003 at 0.0006. So the mutant path is valid where it is
used — marginal members and rare invaders — and invalid for a heavy probe.

**D10 [M] A replay cache should store the field, not the builder.** Caching a full environment
copy per RK sub-step included the light spline's *adaptive builder* and the band-solve
workspace — build-only state a replay never reads. Storing only knots, values and the
environment ODE state, and rebuilding through the existing initialiser, is a **bit-identical**
reconstruction and took a 12-yr run from **>15 GB to 1.14 GB**. Every dependent number
reproduced to the printed digit.

**D11 [M] Order matters more than step size on the slow block, and the fix costs no
vocabulary.** A first-order slow advance left a **12%** offspring bias at a weekly leg
(8.4% at 3.5 d, 1.2% at 1.75 d — the first-order signature). Raising the coupling order fixed
it at the same leg while keeping the cohort-solve reduction, and it was taken as an outright
swap rather than a control key on the explicit grounds that a key would be "a permanent concept
every user must learn". Reverse replay stays safe because the stage count is deterministic, so
record and replay take identical structure.

## E. What this rules in and out, without designing anything

Reading the constraints together, without proposing a build:

- Any verification plan has to name a **well-conditioned regime** (A2, A3), a **horizon >= 12 yr**
  (A1), and **both tolerance families** (A5) — and cannot lean on the scenario bank for accuracy
  or on a global explicit reference for the hard traces (A4).
- Any convergence work targets the **coupling field**, not the functional's integrand and not
  the model (D2, D3, D4).
- Any differentiability work targets the **moving switch** (C2) and the **operating-point
  branch** (C3, C4, C5) — and must not be justified by the convergence argument, which D2
  removed.
- Relaxation (D6), heavy-atom splitting (D4), norm re-weighting beyond ~10–20% (D7), and
  forcing-knot avoidance (D8) are all measured out as primary levers.
- The largest untaken arbitrage is temporal (D5), and it is gated on a cheap refresh of the
  coupling — which C4 and C5 are.
- Two things are free or nearly so and independent of everything above: the implicit treatment
  of an `L <= 5` bidiagonal block (B5), and storing the field rather than the builder (D10).

## X. Overturned claims, recorded so they are not re-inherited

| claim | refuted by |
|---|---|
| the inner argmax floor drives the ~30% step rejection | rejection fraction invariant to a 1000× change in inner tolerance |
| a minimum-step clamp was binding, forcing uncontrolled accepts | one step at the floor (0.0%); the apparent floor is the *initial* step size |
| a Newton polish on stationarity is the fix | no interior root exists (C3) |
| drainage is the dominant stiffness | uptake stress dominates 8–291× in a transpiring stand (B3) |
| an intrinsic survival discontinuity blocks convergence | 100% field-shift, diffuse (D2) |
| the measure is granularity-limited by a heavy atom | max fraction ~1.6%, `∝1/M` (D4) |
| the forcing lattice explains the cost wall | 1.3–3.9 pp of 27–31% (D8) |
| envelope smoothness in the adjoint is safe | the corner: nothing is stationary (C3) |
| the dead drought channel is a develop defect | `soil_psi_max_` is branch-only (C1) |

Two of these were **our own**: the last, and the earlier reading of the never-firing soil
guards as licence.

## What is worth measuring next, ranked by what it would settle

1. **Whether the current adjoint is first-order wrong at the corner** (C3 predicts yes; it is
   inferred, not measured). A reverse sweep against an FD that *re-solves* the inner problem, on
   a transpiring state, at a horizon and regime satisfying A1–A3. Everything in C4/C5 is
   conditional on this.
2. **The in-run boundary-pinning fraction** (C5). Cheap, and it sizes how much of the two-branch
   machinery is load-bearing.
3. **Whether the interior branch survives production inner tolerance** (C5 validated at 1e-12).
4. **A multi-level field-shift sequence** (D2 measured one refinement step). Confirms the field's
   convergence rate and licenses an extrapolated reference.
5. **The pinning margin under a shallower rooting depth or a drier driver** (C1, B6). The 2.05 MPa
   margin is one trait set on one sampled envelope.
