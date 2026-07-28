# Differentiating the soil–plant coupling

**Provenance.** The measurements cited here were made on two branches and are not on
develop: plant `claude/tf24-forward-speed-n5audm` (the code: commits `5a48347b`,
`bcb9ed9f`, `99064255`) and plant-dev `claude/tf24-multi-rate-stepper-n5audm` /
`claude/multirate-stepper-review-r6dpwn` (the write-ups under `docs/`). Section 11
separates what is measured from what is inferred, because several conclusions in that
corpus are Oracle hypotheses that later measurement **refuted**, and two of them are
load-bearing here.

---

## 1. The proposal

TF24's cohorts and its soil column are coupled through one scalar per soil layer: every
cohort draws water, the summed draw drives soil moisture down, and soil moisture sets
every cohort's carbon gain. Soil water is ODE state, not a background, so
**the gradient of every census metric and of R0 runs through that coupling**. It is the
one channel in TF24 that no amount of care elsewhere can route around.

The coupling's derivative turns out not to be the hard part. It is already built and
validated. Three things are missing, and they are what this report proposes:

**1. Differentiate the operating point through the condition that defines it, not
through stationarity.** The collar operating point is presented in the code and in
earlier design work as the maximiser of carbon profit. Measured, it is not: the
objective has no interior stationary point, and `dprofit/dp = -8.8` at the operating
point. It is an **active constraint** — the last point on a surviving branch of the
inner assimilation solve. Every envelope-based treatment of it, including the one this
repository's report 2 proposes, is therefore first-order wrong. The replacement is a
bracketing root-find on the analytic profit gradient that plant already has, safeguarded
by the endpoint signs, with the derivative taken from whichever condition the solve
found active.

**2. Take the uptake Jacobian from the chain that already computes uptake.** The stand's
water draw is assembled by a density-weighted trapezium over cohorts, per layer. Its
derivative has exactly that shape, so it can be assembled by the same traversal with the
same weights, adding **no new concept a Strategy author has to learn**. This is the DX
argument and it is the reason to prefer this route over anything that introduces a
soil-specific adjoint vocabulary.

**3. State where the coupled gradient is an object at all.** Two measured facts bound
it, and neither is currently recorded anywhere a user would see: at production settings
TF24's offspring is **2.4× wrong** and does not converge under schedule refinement; and
near a cohort's survival threshold `dJ/dtheta` is a branch slope *plus a jump*, so the
AD-versus-finite-difference anchor is unsatisfiable there **by any method**. A gradient
delivered without that boundary is a number a user will over-trust.

---

## 2. State at develop: the loop, and where it is tight

Five soil layers by default, carried as ODE state (`ode_size() > 0`, 9 entries), so
`d/dtheta` needs no freezing decision and no recording — it is state, and the depletion
feedback comes for free with it.

One turn of the loop, per cohort per RHS evaluation:

```
psi_soil_[k]                     retention curve, from soil moisture state
  -> prepare_collar_solve         flips to psi_soil_inverted_, precomputes the
                                  soil-side integral lookups, and derives the
                                  feasible collar interval [bound_a, bound_b]
  -> find_root_collar_psi         golden_section_max over that interval at
                                  GSS_tol_abs = 1e-3
  -> opt_psi_stem_, profit_       the operating point
  -> E_from_Soil_to_Root_Collar   soil_consumption_[k] per layer, E_up_ total
  -> set_consumption_rate         per-cohort consumption_rate[k]
  -> Patch::resource_depletion    density-weighted trapezium over cohorts,
                                  summed over species, per patch area
  -> dtheta/dt                    and back to psi_soil_[k]
```

Two properties of this loop matter for everything below.

**The bracket is soil-derived.** `bound_a` and `bound_b` come from the soil state:
`bound_a` is the collar potential at which uptake vanishes, `bound_b` the potential at
which the stem reaches `psi_crit`. As the soil dries the interval shrinks toward
`psi_crit`. So soil moisture enters the operating point through the *bracket*, not only
through the objective — which is what makes the argmax's dependence on soil state
different in kind from its dependence on plant height.

**The dry end amplifies.** Measured, the coupled plant-plus-soil sensitivity near the
dry limit is **50–291×** the soil-hydrology-only sensitivity, and a disturbance to the
uptake field is amplified about **10×** through the feedback before it settles. The loop
is contractive — an Arnoldi spectrum of the coupled map never approaches the runaway
threshold, so a converged answer exists — but a small error in uptake is not a small
error in the answer.

---

## 3. The operating point is an active constraint, not a maximum

This is the load-bearing correction and it invalidates a proposal in this repository.

**Measured geometry.** Mapping the objective finely across its peak at fixed state: a
flat shelf on the wet side, a jump of about **1.5**, then a smooth monotone decline at
slope **−8.8**. The "argmax" is the corner at the top of the jump, roughly 0.01 MPa
above `bound_a`. Confirmed across wet-to-dry regimes; never a smooth interior stationary
point.

**What the jump is.** Reading the evaluator's internals either side:

| side of the corner | `opt_psi_stem` | `ci` | net assimilation |
|---|---|---|---|
| wet (shelf) | pinned | 4.331 | **−1.5** (the `−R_d` floor) |
| dry (live) | tracks the collar | 5.488 (**jumps**) | ~0, then productive |

The inner `ci` / assimilation solve has a productive branch and a non-productive
fallback. On the wet side the productive branch does not exist and the evaluator returns
the fallback. The operating point is **the last collar potential at which the productive
branch survives** — a constraint-activation locus, not an optimum.

**Three consequences, in order of severity.**

*The envelope theorem never applied.* At a true interior maximiser the objective's error
under a perturbed argmax is second order. Measured, the profit floor scales as
`O(eps)` — log-log slope **1.06** against a predicted 2 — because with no stationary
point `profit(p_hat) - profit(p*) ≈ -8.8 (p_hat - p*)`. The prediction of slope 2 was
the sharpest available test of the envelope framing and it failed.

*Any adjoint that freezes the operating point is first-order wrong.* With
`dprofit/dp ≠ 0` there, nothing downstream is stationary — not consumption, not growth,
not profit. An envelope-at-fixed-`p*` adjoint drops terms of size
`(dc/dp, -8.8) · dp*/dstate` in every cohort solve, into a functional that amplifies
about 10×. **This is untested on the reverse tape and it is the highest-value
correctness test outstanding.** It is the test that belongs on this branch.

*Report 2's polish has no root to find.* Report 2 proposes a Newton polish on
`dprofit/dp = 0` behind an implicit-function node. There is no interior point where that
holds, and the second derivative the node's denominator needs is undefined at a corner.
The measurement that made report 2's polish look successful — a residual of 4.541e-10,
flat across tolerances — was taken on a toy whose objective has a smooth interior
maximum by construction, so it never exercised this geometry. **Report 2 sections 1 and
5 need rewriting around the corner.**

**The primitive that does work, and it already ships.** A *bracketing* root-find on the
profit gradient, not a Newton iteration on it. `Leaf::dprofit_droot_collar_psi` already
exists as an exact analytic gradient (IFT plus forward AD). A bracketing method
converges to a **sign change**, which is precisely what a corner is, and needs only the
gradient — never the second derivative that is missing. Wired as
`control$newton_collar_solve` (off by default), with an endpoint-sign safeguard: gradient
positive at `bound_a` and negative at `bound_b` means an interior sign-change root;
one-signed across the bracket means the maximum is at the profit-increasing boundary, so
clamp there. Measured: **1.20×** faster whole-solve (111.0 s to 92.3 s), and the
`GSS_tol_abs` quantisation of the argmax removed. Offspring moves 8.2e-5 to 6.8e-4
across the scenario bank — that gap *is* the quantisation being removed.

**Two distinct objects, and they should not be conflated.** The corner above is a
`ci`-branch feasibility edge interior to the bracket. Separately, the operating point is
sometimes **pinned at `bound_b`** (the critical collar potential), where `dprofit ≠ 0`
for a different reason: the constraint is the bracket end itself. Both need
branch-specific derivatives; section 4's dispatch handles both. Earlier work located the
corner as a transport root-fold and proposed a bordered fold system for it; the
measurement says it is the assimilation branch instead, so the locator equation is
different even though the shape of the fix is the same.

---

## 4. The uptake Jacobian, and the dispatch rule that makes it work

What the coupling needs is `d(consumption_rate[i])/d(theta_k)` per cohort, aggregated to
the stand. Built and validated as `Leaf::compute_duptake_dpsi_soil`, filling a row-major
`i*n + k` block. Every partial is a difference of a **closed-form** leaf function at the
**fixed** operating point — no re-solve, and no finite difference through a search.

Two branches, and both are required:

- **interior optimum** — IFT on the stationarity condition:
  `dP*/dpsi_k = -g_k / g_P`, then
  `dc_i/dpsi_k = [dc_i/dpsi_k]_{P* fixed} + (dc_i/dP*)(dP*/dpsi_k)`.
- **boundary-pinned** — the operating point tracks the active bound, so the response
  comes from IFT on *that bound's* defining continuity condition
  (`E_column_zero = 0` at `bound_a`, `E_column(·, psi_crit) = 0` at `bound_b`).

**Validated** against a finite difference of a full operating-point re-solve, 45 soil
states, driest layer 0.2–4.6 MPa, inner tolerance 1e-12:

| | median | p90 | max |
|---|---|---|---|
| all states | 4.2e-5 | 1.4e-4 | 6.1e-4 |
| dry tercile | 4.0e-5 | 2.0e-4 | 6.1e-4 |
| wet tercile | 5.4e-5 | — | 8.6e-5 |

**The dispatch rule is the transferable finding, and it was found the hard way.**
Interior-IFT-only was ~4.5e-2 in the dry tercile — a real error, not FD noise: it did not
shrink when tolerance and step were tightened. Adding a boundary branch dispatched by a
**residual threshold** (which of the two continuity residuals is near zero at the
operating point) fixed most states but left three at **30–50%** error, because the
threshold mis-selected. Dispatching instead on the **`g_a`/`g_b` endpoint signs — the
same test the solve itself used to choose the operating point** — drove the worst case
from 5.0e-1 to 6.1e-4.

> **Key the derivative branch off the same test the solver used to pick the operating
> point, never off a re-derived proxy for it.**

The error correlates with boundary-pinning (Spearman 0.71 against the stationarity
residual), not with dryness as such; dryness matters only because it makes pinning more
frequent as the feasible interval shrinks. The in-run frequency of pinning on a real
trajectory is **not yet measured** — the 40% above is over a deliberately dry-weighted
sample — and it sets how much the boundary branch actually matters.

**Aggregation adds no vocabulary.** The stand Jacobian is assembled by the same
density-weighted trapezium over cohorts, summed over species and divided by patch area,
that already assembles the depletion itself — the same traversal, the same weights, with
the retention factor folded in per layer so everything above stays environment-agnostic.
Gated behind a control flag; **bit-identical when off**, verified to the last bit on SCM
offspring (20.74297971123531, absolute difference 0.0).

The retention chain closing the loop back to soil state,
`dpsi_inverted_k/dtheta_k = n_psi · psi / theta`, is **exact** — checked against a
numerical derivative of the retention curve to full precision — and correctly **zero**
where the curve is floored at residual or capped at its maximum potential.

One caveat carried from the validation: the interior branch's operating-point response
is itself a finite difference of the analytic gradient, and that gradient contains inner
root-finds. The validation used inner tolerance 1e-12. At production inner tolerances
this differencing is not clean, which is a real constraint on where the branch may be
used.

---

## 5. What the soil never does, and what that licenses

Four non-smooth constructs in the soil rate — a runoff floor, a conductivity floor, a
retention floor, and a drying guard — plus the leaf's shut-down discontinuity, have all
been treated as things a gradient design must handle. Measured on production runs, none
of them is reached.

**Why the dry end is unreachable.** Drainage conductivity goes as
`K(theta) ∝ theta^p` with `p = 2 n_psi + 3 ≈ 16.14`. A sixteenth power collapses:

| theta | K (mm/day) | psi_soil (MPa) |
|---|---|---|
| 0.428 (saturation) | 1.6e+2 | 0.002 |
| 0.150 | 7.3e-6 | 1.75 |
| 0.120 | 2.0e-7 | 7.6 |
| 0.010 (residual) | 3.5e-24 | capped |

By `theta ≈ 0.12` a bare column at half saturation loses **0.015 over ten years**.
Drainage cannot carry the soil into the deep-dry band, and root uptake shuts off
smoothly as potential saturates. So residual moisture is an **asymptote approached in
infinite time, not a floor hit in finite time**. Measured minimum over every scenario:
**theta = 0.133**, against residual 0.010 — never within a factor of ten.

**And the guards are measured never to fire.** Instrumented over the scenario bank
including a 30-year extended drought: soil clamp and runoff signatures **never** fire;
the collapsed-bracket branch **never** fires; about **99.8%** of cohort solves take the
ordinary search branch; the only discrete event that occurs at all fires on **under
0.5%** of steps.

**Leaf shutdown is structurally hard to reach, and the mechanism is specific.** Shutdown
requires the *wettest accessible* layer to be drier than `psi_crit`. Every cohort roots
to 1.5 m, and in a 12-year zero-rain drydown the top two layers reach 5.13–5.34 MPa
against `psi_crit ≈ 5.6` while the bottom layer stays at **0.37 MPa**. The margin never
reaches zero; its closest approach across the whole bank is 0.79. The stand dies of
carbon starvation from the drying topsoil while still rooted into deep water it never
exploits — 38% of rainfall over 16 years leaves as deep drainage, and there is no upward
capillary flux between layers.

**What this licenses, and what it does not.** It upholds the existing decision not to
smooth the soil kinks: a zero derivative is what the model means at a kink, and these
kinks are not on the sampled path anyway. It does **not** license removing them. The
floor is held by the physiology, not by any choice of state variable: with the
vulnerability shutoff disabled, raw moisture runs to **−17.85** and a log-depletion
chart gives **NaN**. A re-charting of the soil state is not a substitute for the
shutoff.

It also does not license calling the kinks unreachable in general. This is a statement
about a sampled envelope of rainfall scenarios and one trait set, not a theorem. The
drydown run came within 0.79 MPa of shutdown; a shallower-rooted strategy would come
closer.

---

## 6. Where the value is wrong before the gradient is

Two measured facts about TF24's offspring bound what a gradient of it can mean. Neither
is recorded anywhere a user of a gradient would encounter it.

**At the production inner tolerance, offspring is 2.4× wrong, non-monotonically.**

| `GSS_tol_abs` | offspring (whiplash, 12 yr) |
|---|---|
| **1e-3 (production default)** | **1.412e-7** |
| 1e-4 | 5.90e-8 |
| 1e-5 | 1.413e-7 |
| 1e-6 | 5.871e-8 |
| 1e-8 | 5.868e-8 |

Converged only at 1e-6 and below. A marginal cohort's survival flips with the sub-1e-3
argmax floor, so tightening does not monotonically improve it. Section 3's exact locator
removes this at the source, which is the strongest argument for building it: it is
simultaneously the speed fix, the gradient fix, and the fix for a wrong value.

**Offspring does not converge under schedule refinement, and the soil coupling is the
entire reason.** Refining the cohort schedule moves offspring from 2.7e-7 to 8.5e-8
(94 to ~140 cohorts) on one scenario and 2.1e-6 to 3.3e-7 on another; two different
refined schedules disagree by 9–45%. Three experiments locate it:

1. Freeze the soil trajectory and add 1.5× more cohorts without letting them feed back:
   offspring changes by **~0%** (6e-10). The reproduction quadrature is already
   converged.
2. Let the same denser cohorts feed back into soil water: offspring drops **69–84%** —
   **100% of the non-convergence.**
3. The shift is diffuse across the productive early cohorts; the three largest-changing
   points carry 2–3% of the total change. It is **not** a spike at a cohort crossing the
   survival threshold.

So the schedule is under-resolving the *water-uptake field over time*, and the existing
refinement heuristic — which flags cohorts by their contribution to reproduction —
chases a signal that is already resolved, and has been measured to anti-correlate with
the true error. **The refinement criterion should target where adding a cohort most
changes total uptake.** That is a concrete, actionable change and it is the prerequisite
for a converged R0 to differentiate at all.

**Two consequences for the goal, stated plainly.**

*A gradient of R0 is meaningful only where R0 is converged, and at production settings
it is not.* This is a precondition on the whole R0 deliverable and it is upstream of
every AD concern. It is also not a reason to stop: census metrics are integrals over the
live population and are not implicated by the same mechanism, and K93 and FF16 have no
soil coupling at all.

*Near a survival threshold, the AD-versus-FD anchor is unsatisfiable in principle.*
`dJ/dtheta` there is a branch slope plus a jump. The adjoint computes the branch slope;
a finite difference straddling the flip measures the jump; no method computes both, so
the requirement "the gradient must match a finite difference of the solver as run"
cannot be met. This does not weaken the anchor where it applies — it means the anchor
needs a stated domain, and a run near a threshold must be detected rather than trusted.
Whether to smooth the survival entry into the functional is a model-owner decision, not
a numerics one; it should be flagged to them, not decided here. Note that it is a
separate question from offspring *convergence*, which experiment 3 above shows the
survival threshold does **not** drive.

---

## 7. Constraints

**C1. Soil water is ODE state, and must stay that way.** Nine entries with
`ode_size() > 0`. Treating it as a background driver would drop the depletion feedback,
which section 6 shows is the dominant term in offspring's own convergence.

**C2. The bracket is soil-derived, so soil enters the operating point twice.** Through
the objective and through `[bound_a, bound_b]`. A treatment that captures only the
objective channel is incomplete in a way that is invisible at fixed soil state.

**C3. The interior branch's response is a finite difference of an analytic gradient
containing inner root-finds.** Validated at inner tolerance 1e-12. Production tolerances
do not obviously support it, and this is unmeasured.

**C4. The in-run frequency of boundary-pinning is unknown.** 40% on a dry-weighted
sample; unknown on a real trajectory. It sets how much the boundary branch matters and
therefore how much of section 4 is load-bearing.

**C5. Values change.** Replacing the search with the locator moves offspring by
8.2e-5 to 6.8e-4 across the bank — and that is the *correct* direction, since the
production value is 2.4× wrong in the bifurcation-prone case. Baselines need
re-blessing, and the re-blessing needs the converged reference, not the current one.

**C6. The unreachability results are an envelope, not a theorem.** Section 5's closest
approach to shutdown is 0.79 MPa. A different trait set or rooting depth is a different
statement.

**C7. `Leaf` is shared through the Strategy pointer**, so the operating point,
`soil_consumption_`, `E_up_` and the soil caches are per-solve scratch on an object
several cohorts see in turn. A shut-down cohort left `soil_consumption_` and `E_up_`
stale, feeding a previous cohort's draw into the balance — fixed on the branch by zeroing
both at shutdown. The general hazard is that any *new* per-solve field on `Leaf` has the
same shape, and nothing structural marks which fields are transient.

---

## 8. What this asks of a Strategy author

1. **If your model chooses an operating point, say which condition defines it.** Not
   "the maximum of profit" but the equation that holds there — a stationarity condition,
   a branch-existence condition, or an active bound. The derivative is taken from that
   equation.
2. **Dispatch the derivative on the same test the solve used.** If the solve chose a
   branch by comparing endpoint gradient signs, the derivative must branch on those same
   signs. A re-derived proxy — a residual threshold, a dryness threshold — measured
   30–50% wrong.
3. **Don't smooth a kink to make it differentiable.** A zero derivative is what the model
   means there. Measure whether the kink is on the sampled path before designing around
   it; four of TF24's soil kinks are never reached.
4. **Don't replace a physiological floor with a state chart.** The chart cannot hold a
   bound the physics does not.
5. **Assemble a derivative with the traversal that assembles the quantity.** If uptake is
   a density-weighted trapezium over cohorts, so is its Jacobian, with the same weights.
   This is what keeps the concept count flat.
6. **Declare any new per-solve field on a shared object, and clear it on every exit
   path** — including the early ones. A field left stale by one exit is a previous
   cohort's value entering this cohort's balance.
7. **If your functional can threshold a member's existence, say so.** It is then not
   differentiable there, and no engine can make it so.

---

## 9. Implementation order

1. **Test whether the current adjoint is first-order wrong at the corner.** Reverse-mode
   `dJ/dtheta` against a finite difference that re-solves the inner problem, on a
   transpiring state. This is cheap, it is the highest-value outstanding correctness
   test, and section 3 predicts it fails. Do it **before** building any locator — if it
   passes, section 3's severity assessment is wrong and the order changes.
2. **Turn on the shipped locator** (`newton_collar_solve`) and confirm the acceptance
   test that was tabulated in advance: offspring flat at 5.87e-8 across `GSS_tol_abs`.
3. **Measure the in-run boundary-pinning fraction** (C4). It decides how much of step 4
   matters.
4. **Turn on the gated uptake Jacobian** and re-validate the two branches at production
   inner tolerance rather than 1e-12 (C3).
5. **Change the schedule refinement criterion to target uptake**, and only then quote a
   converged R0 (section 6).
6. **Take the survival-threshold question to the model owners** with the numbers, not a
   proposed smoothing.

---

## 10. What would falsify this

- **The adjoint matches the re-solving finite difference at the corner.** Then the
  envelope-at-fixed-operating-point channel is somehow adequate, section 3's severity is
  overstated, and only the value error in section 6 survives.
- **The locator does not flatten offspring across `GSS_tol_abs`.** Then the flip is not
  driven by the argmax floor and something else moves it; the 2.4× stands unexplained.
- **Boundary-pinning is rare in run** (C4). Then section 4's boundary branch is
  near-dead weight and the interior IFT alone is enough — which would be good news, and
  it is measurable before any build.
- **The interior branch degrades at production inner tolerance** (C3). Then the cheap
  operating-point response is unavailable where it is wanted and the Jacobian needs a
  different construction.
- **A trait set reaches leaf shutdown or a soil clamp with non-negligible frequency.**
  Then section 5's licence lapses for that region and the discontinuity has to be
  handled rather than noted.

---

## 11. Measured, versus inferred

Given how much of the surrounding corpus is Oracle correspondence, and that several of
its confident claims were later refuted by measurement, this separation is explicit.

**Measured, with a script and numbers behind it:** the objective's corner geometry and
the `ci` jump either side; the profit floor's slope 1.06; the 1.20× locator speed-up and
the 8.2e-5..6.8e-4 offspring move; the two-branch Jacobian's 4.2e-5 median / 6.1e-4 max
and the 30–50% residual-dispatch failure; the exact retention factor; bit-identity when
gated off; the 2.4× offspring error and its non-monotone tolerance table; the three
freeze/feed-back convergence experiments; the sixteenth-power conductivity table and
theta_min = 0.133; the never-firing clamps and the 0.79 MPa closest shutdown approach;
the vulnerability-shutoff floor test.

**Inferred here, not measured:** that the corner makes the *current* reverse-mode
adjoint first-order wrong. The mechanism is sound and two independent reasoners
converged on it, but it is an argument, and step 1 of section 9 exists to test it rather
than assume it.

**Oracle claims that measurement refuted, recorded so they are not re-inherited:** that
the inner argmax floor drives the ~30% step rejection (refuted — the rejection fraction
is invariant to a 1000× change in inner tolerance); that a minimum-step-size clamp was
binding and producing uncontrolled forced accepts (refuted — one step at the floor,
0.0%, and the apparent floor is the *initial* step size, not a wall); that a Newton
polish on stationarity is the fix (refuted — no root exists). The first of these was
also stated in an intermediate write-up as "min-h equals `ode_step_size_min`"; the later
measurement corrects it to `ode_step_size_initial`. Where documents disagree, the
measurement wins.
