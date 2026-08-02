# The compression term is a change of variables the model undoes

`aornugent/plant#69` asks which of two stencils the compression term wants, and
[report 11](11-cohort-counts-and-the-meaning-of-density.md) argues the question is posed one level
too low. This report ran the measurements both named. The answer is one level lower again: the
compression term is not a modelling choice, it is the Jacobian of a change of variables the SCM
performs and then immediately undoes, and `develop` computes it wrongly — not imprecisely.

Everything below is measured on `plant` `develop` at `141dc8df` in an environment with R, which is
what reports 10 and 11 lacked. Probe scripts and raw outputs are in
[`probes/`](../../probes); the implementation is `plant` `claude/nsc-density-measurements-efiolz`.

---

## 1. What the measurements say

| question | answer |
|---|---|
| Is `develop`'s `dg/dh` under-resolved? | **No.** Converged to five decimals across five decades of `eps`, while sitting 8.5x the magnitude of the term it should be computing |
| Does the omitted term diverge like `1/g` at a stall? | **No.** `dg/dS` carries its own factor of `g`, which cancels exactly; measured drift at stalls is `1e-11` |
| Does the height density cease to exist? | **Not here.** Zero crossings in 3 459 interior pairs across 37 patch states, minimum gap `1.6e-5` m |
| Is the reserve-dilution term a separate defect? | **No.** It is the same single term seen from a different reference point |
| Which limit is right? | The one a density in birth date reaches, and it is verified against `develop` itself on K93 and FF16 |
| How big is the error? | TF24 offspring **42.14 against 395.4** at the production schedule, **59.06 against 400.9** at four times the resolution, and only the birth-date arm is converged |

## 2. The term the transport equation actually wants

Under a shared deterministic environment and a single birth state, every individual born at date `a`
follows the same trajectory `x(t;a)` in the full state space. The living population is therefore
supported on a **one-dimensional curve** parameterised by birth date — not spread over a
`k`-dimensional density. This is a property of the model, not of the solver: the SCM discretises
the birth-date axis, which is what "method of characteristics" means here.

Write `J(t;a) = dh(t;a)/da`. Then

    dJ/dt = d/da [ g(x(t;a)) ]  =  sum_k (dg/dx_k)(dx_k/da)

    d(log J)/dt = [ sum_k (dg/dx_k)(dx_k/da) ] / J  =  dg/dh along the cohort curve

so with `N` the number born per unit birth date and `n = N/J` the density in height,

    d(log N)/dt = -mortality                        (exact, no transport term)
    d(log n)/dt = -mortality - dg/dh|_curve

**The compression term is the total derivative of `g` with respect to `h` along the cohort curve.**
That is `#69`'s Reading A, and it is not a preference: Reading B's partial `dg/dh` at fixed
physiology is the correct answer only when `g` depends on height alone, because only then do the
two coincide.

**And the Jacobian cancels at the point of use.** `log_density` is consumed in exactly two places
(report 11 §1, re-verified: `node.h:98` and `node.h:235`), both integrals against the size
distribution:

    integral n(h) e(h) dh  =  integral (N/J) e J da  =  integral N e da

So the SCM computes `J` — at the cost of one extra full leaf solve per cohort per Runge-Kutta stage
— divides by it, and multiplies by it again in the quadrature. **No ecology passes through the
compression term.** The ecology is in who is alive and what state they are in, and neither is
touched by the coordinate choice.

## 3. `develop` computes an accurate derivative of the wrong quantity

`Node::growth_rate_gradient` perturbs height by `node_gradient_eps` and re-runs the rate
calculation, holding every other state — including the absolute storage pool — fixed. That is a
well-defined partial derivative. The question is whether it is *resolved*, because `#69`'s Reading B
proposes fixing the conservation defect with "a better derivative — analytic, or by automatic
differentiation".

Evaluated on one patch state at age 2, over 80 interior cohorts, with `C` the neighbour difference
(the total derivative's discretisation):

| `eps` | median `A` | `max abs(A(eps) - A(1e-6))` | median `abs(A - C)` |
|---|---|---|---|
| `1e-3` | -0.269644 | 5.5e-03 | 0.3015 |
| `1e-4` | -0.270122 | 5.5e-04 | 0.3019 |
| `1e-5` | -0.270173 | 5.0e-05 | 0.3020 |
| `1e-6` | -0.270178 | 0 | 0.3020 |
| `1e-7` | -0.270179 | 5.0e-06 | 0.3020 |
| `1e-8` | -0.270178 | 5.2e-06 | 0.3020 |

The probe is converged to five decimals across five decades. Its distance from the operator the
equation wants is `0.302` — **55x its own resolution spread** — and the correct operator's own
median magnitude is `0.0318`, so `A` is **8.5x too large, and at this patch age it carries the
opposite sign** (`C` is positive here, `A` is negative).

**Sharpening the derivative cannot help, and neither can AD.** This closes `#69`'s Reading B branch:
the remedy it proposes is already achieved and changes nothing.

## 4. The whole disagreement is one term, and it has a closed form

For TF24, `g = C(h) Ppos(h) G(r)` with `G` the logistic reserve gate on `r = S/S_max` and width
`w = 0.1`, so `dg/dS = g (1-G) / (w S_max)` and the omitted along-curve term is

    (dg/dS)(dS/dh)|_curve  =  (dg/dS)(f/g)  =  (1-G) f / (w S_max),     f = dS/dt

**The growth rate cancels.** Report 11 §4's claim that this "diverges like `1/g` wherever growth
stalls" is an algebra slip; `dg/dS` carries the factor of `g` that the `f/g` supplies.

Measured over the whole run. The per-cohort conservation drift rate is *identically* the difference
between the two stencils — `d(log N)/dt + mortality = (g_i - g_below)/dh - dg/dh|_S` — so the
operator disagreement is measurable from collected output with no instrumentation at all:

| `g` bin | n | median `abs(drift rate)` | median `abs((1-G) f / (w S_max))` |
|---|---|---|---|
| `<= 1e-8` (stalled) | 1 170 | **1.1e-11** | **0** |
| `1e-8 - 1e-4` | 163 | 2.1e-07 | 0 |
| `1e-4 - 1e-2` | 1 597 | 1.04e-04 | 8.6e-05 |
| `1e-2 - 1` | 4 593 | 4.24e-02 | 3.58e-02 |
| `> 1` | 2 032 | 5.21e-01 | 3.94e-01 |

Spearman correlation between the closed form and the measurement is **0.933**; the per-bin medians
agree within ~20%. At stalls both are zero: the divergence report 11 predicted is not there, and the
disagreement is concentrated in the *vigorous* cohorts, not the suppressed ones.

**The reserve-dilution reading is the same term from a different reference point.** Report 11 §2
frames `develop`'s probe as diluting the reserve fraction, and §8.1 asks how much of the
disagreement that accounts for. Adding a third probe `B` that rescales `S` to hold `r` fixed while
perturbing height, over 37 patch states and 3 459 interior pairs: `sum abs(A-C) = 623.7`,
`sum abs(A-B) = 541`, `sum abs(B-C) = 121`, so the dilution quantity accounts for **86.7%** of the
disagreement. In the recruitment window `B` tracks `C` in level, where `A` is displaced:

| patch age | median `A` | median `B` | median `C` |
|---|---|---|---|
| 0.5 - 1 | +0.198 | +0.7928 | +0.7877 |
| 1 - 2 | **-0.221** | +0.2405 | +0.2390 |
| 2 - 3 | **-0.209** | +0.0656 | +0.0634 |

All three correlate above 0.93 here; what `A` gets wrong is the level, and from patch age 1 the
sign. But `B` is not a separate error channel — it is close to `C` because `dS/dh` along a
trajectory happens to be near `r dS_max/dh`, i.e. because **the reserve fraction is quasi-stationary
along a growing cohort's path**. That is contingent on the parameterisation, not structural, so
"hold the fraction fixed" is the wrong repair even though it is the right diagnostic.

## 5. Conservation, and what the drift is really measuring

Interior intervals only (the lowest cohort's interval is bounded below by the fixed inflow node, so
plants flow into it and it is excluded):

| | summed drift | worst cohort | pairs |
|---|---|---|---|
| TF24 | **+245.8** | **158x** | 9 555 |
| FF16 | +7.94 | 1.59x | 9 870 |
| K93 | +1.41 | 3.02x | 9 050 |

Normalising by elapsed time to get a rate separates two explanations that the totals cannot:

| | slope of `log abs(rate)` on `log(dh)` | R² | slope on `log(g)` | R² |
|---|---|---|---|---|
| FF16 | **+0.78** | 0.81 | — | — |
| K93 | +0.16 (magnitudes `1e-9` to `1e-3`) | 0.01 | — | — |
| TF24 | **-1.02** | 0.24 | **+0.99** | **0.94** |

FF16's drift scales with the gap width: that is the `O(dh g'')` quadrature error report 04 §2.2
predicted, and it converges away. TF24's does not scale with the gap at all — it scales with the
growth rate, two to three orders of magnitude larger, which is the signature of a missing `O(1)`
term rather than a discretisation error.

## 6. The height density does not stop existing

Report 11 §4 argues that a carried state lets `J` reach zero and change sign, and reads report 10's
12 non-descending pairs as the Eulerian density ceasing to exist. Two things are against that here.

TF24's height rate is `dheight_darea_leaf * growth_flux * ...` with `growth_flux = Ppos * G`, and
`Ppos` is a smooth positive part and `G` a logistic, so **`g >= 0` strictly**: no plant shrinks, and
nothing can fall below the inflow boundary. Report 10's 12 pairs are all at the boundary pair, which
is `Species::new_node` pinned at `height_0` — not a characteristic.

Measured across 37 patch states, 3 459 interior pairs: **zero crossings**, minimum gap `1.6e-5` m,
14.2% of gaps below `1e-4` m. 46% of interior pairs are closing at any moment, but the closing rate
decays as the states converge — the earliest linear-extrapolated fold is 4.05 years away and none
occurs.

So the fold argument is not what carries the case. What carries it is §2 and §3.

## 7. The formulation: carry the density in birth date

Nothing moves an individual along the birth-date axis, so

    state:        log_density  becomes a density per unit birth date
    rate:         d(log density)/dt = -mortality
    birth:        log(birth_rate * pr_estab)           -- no division by g
    competition:  trapezium over introduction times instead of over heights
    soil draw:    the same substitution
    the probe:    not called

This is not the Escalator Boxcar Train's lumped counts (report 11 §6) but the density in the natural
variable, so the two resource integrals stay trapezia rather than becoming sums over lumped cohorts.
Report 11 §6.1 concedes a loss of formal order in moving to counts; keeping a density avoids having
to. Measured convergence is first order in both coordinates (§8: increments halve each level, in the
birth-date arm and in FF16's height arm alike), so the order is set by something else in the solver,
not by this choice.

Implemented behind `Control$node_density_in_birth_date` so both arms run from one build. With the
flag off, all three strategies reproduce `develop` **bit-identically** (`identical()` on the
offspring scalar, 0 ulps).

Two defects found while building it, both fixed on the branch:

- `SpeciesBase::control()` called `strategy->get_control()`, which does not exist. The member was
  never instantiated, so it had never been compiled.
- `stochastic_schedule()` passes `patch_area` into `stochastic_arrival_times()`'s third positional
  slot, which is `delta_t`. Arrival rates in the stochastic solver have never scaled with patch
  area. Worked around in the probes; not yet fixed in the package.

## 8. What it does to the forward model

Midpoint insertion into `node_schedule_times`, so both arms see byte-identical schedules at each
level.

| model | introductions | density in height | density in birth date |
|---|---|---|---|
| **TF24** | 141 | 42.1402 | 395.441 |
| | 281 | 54.7988 (**+30.0%**) | 399.085 (+0.92%) |
| | 561 | 59.0590 (**+7.8%**) | 400.917 (+0.46%) |
| **FF16** | 141 | 19.8244 | 20.0319 |
| | 281 | 19.9490 | 20.0352 |
| | 561 | 20.0122 | 20.0361 |
| **K93** | 141 | 0.0305466 | 0.0306275 |
| | 281 | 0.0305653 | 0.0305833 |
| | 561 | 0.0305692 | 0.0305736 |

Three things to read off.

**The two coordinate systems are the same model.** On K93, where growth is a function of size, they
agree to `1.5e-4` relative at the finest level. On FF16, where heartwood couples weakly, to
`1.2e-3`. The birth-date arm is not a different model that happens to be better behaved; it is
`develop` with the change of variables removed, and where `develop` is right it reproduces it.

**On TF24 only one arm is converged.** The height arm moves +30.0% then +7.8% and is still climbing
— reproducing report 10 §3.3's `42.13 -> 54.80 -> 58.75` on a different branch almost exactly. The
birth-date arm moves +0.92% then +0.46%, halving each level: first-order convergence to **≈401**.
Report 10's independent cohort-grid stencil reached ≈430 on `p2/phase-2`; the 7% gap is the
quadrature (trapezium in height against trapezium in birth date), and the two routes to the same
operator agree.

**It is cheaper.** TF24 at 561 introductions: 314.9 s against 659.1 s, and 6 143 accepted ODE steps
against 8 530. The saving is the deleted leaf solve plus a right-hand side without the stiff term.

## 9. Where the factor comes from

`log_density` reaches the demography only through the light profile and the soil draw, so the whole
effect must travel through the environment. It does, and it is over by patch age 5:

| patch age | leaf area, height arm | birth-date arm | ratio |
|---|---|---|---|
| 0.75 | 1.66e-03 | 1.15e-03 | 1.45 |
| 1.50 | 5.04e-02 | 2.49e-02 | 2.02 |
| 2.00 | 2.29e-01 | 9.74e-02 | 2.35 |
| 2.50 | 6.82e-01 | 2.71e-01 | **2.52** |
| 3.00 | 1.360 | 0.586 | 2.32 |
| 5.00 | 1.762 | 1.676 | 1.05 |
| >25 (mean) | | | **1.005** |

In the recruitment window the spurious compression term inflates the seedling density, `develop`
believes there is up to 2.5x more leaf area than there is, and the cohorts that go on to form the
canopy grow and reproduce under that shade. After canopy closure the two agree to half a percent —
which is why the error is invisible in every late-stand diagnostic.

## 10. The oracle

The individual-based solver counts plants and has no compression term, so it cannot prefer either
arm. Both solvers divide leaf area by patch area in `Patch::compute_competition`, so the stand
structures are directly comparable. Poisson arrivals at the same birth rate, establishment as a
Bernoulli draw on the same `pr_estab`, three patch areas to check that the finite-population bias
has flattened, run to the same `max_patch_lifetime`.

Leaf area above ground level, in the window where the two arms differ:

| patch age | IBM area 4 | IBM area 16 | IBM area 64 | sd (area 64) | height arm | birth-date arm |
|---|---|---|---|---|---|---|
| 1.0 | 0.00381 | 0.00347 | 0.00327 | 0.00100 | 0.00628 | 0.00383 |
| 1.5 | 0.02370 | 0.02262 | 0.02027 | 0.00476 | 0.05035 | 0.02488 |
| 2.0 | 0.08553 | 0.08777 | 0.07713 | 0.01310 | **0.22926** | 0.09738 |
| 2.5 | 0.22713 | 0.24357 | 0.21221 | 0.03042 | **0.68229** | 0.27117 |
| 3.0 | 0.46026 | 0.52081 | 0.45887 | 0.05268 | **1.35999** | 0.58568 |
| 4.0 | 1.21874 | 1.30022 | 1.21852 | 0.05040 | 1.75845 | 1.44494 |
| 5.0 | 1.57245 | 1.66668 | 1.66303 | 0.02183 | 1.76160 | 1.67564 |

As a ratio to the area-64 mean:

| patch age | 1.0 | 1.5 | 2.0 | 2.5 | 3.0 | 4.0 | 5.0 |
|---|---|---|---|---|---|---|---|
| height arm | 1.92 | 2.48 | **2.97** | **3.22** | **2.96** | 1.44 | 1.06 |
| birth-date arm | 1.17 | 1.23 | **1.26** | **1.28** | **1.28** | 1.19 | 1.01 |

The IBM is stable across a 16x range of patch area (at age 2: 0.0855, 0.0878, 0.0771), so this is
not a finite-population artefact; it carries 58 to 177 individuals through the window. The height
arm sits about twelve replicate standard deviations above it; the birth-date arm sits within two.

**The oracle rules out the height arm and is consistent with the birth-date arm.** This is the
measurement report 10 §10 and report 11 §8.2 both named as the only one that adjudicates from
outside both candidates, and it agrees with §8's refinement result and §3's resolution result.

The birth-date arm's residual 25% is not explained here. The schedule places 141 introductions over
105 years and the recruitment window is where the density is changing fastest, so schedule
resolution is the first thing to rule out; nonlinear averaging over a finite population is the
second.

**What the oracle cannot do is discriminate on the mature stand.** After canopy closure every
statistic agrees: leaf area to within the IBM's own replicate spread, tallest individual to within
1%, and living stems per m² so noisy (the IBM's own area-64 value moves 7.2 -> 5.1 -> 5.0 -> 6.3 ->
2.0 across ages 20 to 100) that the two arms cannot be separated by it at all. That is why an error
of this size survived: it is confined to the first five years and invisible in everything a mature
stand reports.

## 11. The boundary condition, and a state that leaves its domain

**The birth density divides by the growth rate.** `Node::compute_initial_conditions` sets
`log(birth_rate * pr_estab / g)`, and assigns zero density — deleting the recruit — when `g <= 0`.
At these parameters `g` at birth never goes non-positive (minimum 0.0959, median 0.821), so the
cliff is latent rather than active. It still costs conditioning: the newborn density spans **16.8x**
under the height arm against **3.03x** under the birth-date arm, and the maximum `log_density`
reached is 1.564 against -0.002 against a guard ceiling of 50
(`Patch::check_finite_node_densities`). Under birth-date coordinates `log density` is bounded above
by `log(birth_rate * pr_estab)` and that guard can never fire.

**TF24's storage state leaves `[0, S_max]`.** Minimum recorded value `-2.249e-3`, in 14.0% of
recorded cohort-times, affecting 65 of 142 nodes, from patch age 3.5 onward. The rate is gated by
`S/(S + 1e-3 S_max)` to vanish as `S -> 0`, but a finite step from a small positive `S` with a
negative rate carries the state below zero, where the gate pins the rate at zero. `compute_rates`
clamps on read, so the plant behaves as `r = 0` — gate at its floor 0.269, storage mortality at its
bounded maximum. This is independent of everything above and wants its own issue.

## 12. What it means for the ecology

**The fix does not touch the ecology.** No strategy code changes: storage dynamics, the reserve
gate, reserve-dependent mortality and the birth reserve fill are all untouched. What changes is the
coordinate the density bookkeeping is carried in.

That matters against report 10 §5.1's alternative, which report 11 §7 is right to close off. Making
storage an explicit function of size and environment would make the size-structured premise true by
construction — and would delete the memory that is the entire point. Stefaniak et al. (2026) find
the *variance* of stress duration shifts community composition more strongly than its mean
(`omega^2 = 0.25`, "large", for the Slow-Risky strategy against "very small" for the mean at almost
every level), and their four strategies are defined by a utilisation rate and a switch time —
properties of the pool's dynamics. A plant whose reserves are a function of its current size cannot
have come through a drought differently from one that has not.

**And the phenomenon the model exists to represent is the one `develop` handles worst.** Stefaniak
et al. attribute the Slow strategies' success to a "high carbon storage minimum, which facilitated
the survival of small saplings in the shade". That sapling bank is exactly the suppressed,
tightly-spaced, slow-growing part of the size distribution — where gaps fall below `1e-4` m, where
the density in height is largest and worst conditioned, and where §9 shows the error is generated.
Under birth-date coordinates a stalled cohort is an ordinary quadrature point carrying an ordinary
density per unit birth date.

**The size distribution becomes an output rather than a state.** `n = N/J` is computed when a run is
reported, not integrated. That is the difference that makes the memory representable: a stand where
many birth dates map to nearly one height has a height density that is legitimately very large
there, and possibly multivalued if the ordering ever fails. As a reported quantity that is a
description of a sapling bank. As an ODE state carried for a cohort's whole life it is a stiff term
in the right-hand side, a `1e-6` divisor, a `log_density_ceiling = 50` guard, and an ordering
requirement — none of which is biology.

Their own NSC model never met this problem because they ran the individual-based solver: 100-year
runs on 100 m² patches with individual trees, at roughly three days per simulation. An IBM counts
plants and has no compression term. The group's NSC work is already in count coordinates; the
question is specific to the SCM's density variable, not to the biology — which is why §10's oracle
is the right arbiter and why it agrees.

**Nothing about the resolution is TF24-specific.** The condition that breaks `∂g/∂h` is that growth
reads any state other than size. TF24 reads storage today; the calibration factor Stefaniak et al.
need (their Eqs 2-3), which makes each component mass an independent state because the gate breaks
the pipe-model balance, would add four more. A treatment that sites the storage term explicitly —
report 10 §5.1's `∂g/∂h + (∂g/∂s)(∂s/∂h)` with analytic partials — has to be extended once per
carried state. Removing the change of variables does not.

## 13. What this means for `#554` and `#69`

`#554` reports single-species offspring moving `227.9 -> 25.4` on adding reserve gating and reads it
as a defensible consequence. Report 11 §9 flagged the comparison as unsafe; it is now measured.
Before storage the two coordinate systems agree to `1e-3`; after storage they differ 6.8x at the
finest refinement level, and the post-storage number is the one computed with the broken operator.
**The direction of that result is not established** and `TF24_Strategy::scientific_version` was
bumped to 3 on the strength of it. Re-run before relying on it.

For `#69`: Reading A is correct, Reading B is not a coherent alternative for a multi-state plant,
the conservation defect is real but is a symptom, and the neighbour-difference stencil reaches the
right limit by the wrong route — it still divides by a cohort gap whose measured minimum is
`1.6e-5` m and still carries a density that needs the ordering to hold. Carrying the density in
birth date needs neither.

## 14. Measured, read, derived

**Measured on `develop` at `141dc8df`, `-O2 -DNDEBUG`:** every figure in §3, §4, §5, §6, §8, §9,
§10, §11. Baselines reproduce report 10's to the digits it printed (TF24 42.1402 against 42.13). The
default arm is `identical()` to the pre-change build on all three strategies.

**Read from the tree:** the two density consumers; `growth_rate_given_height`'s body; the reserve
gate and `storage_capacity`'s height dependence; the birth density and its `g <= 0` branch;
`g >= 0` for TF24; `SpeciesBase::control()`'s broken accessor; `stochastic_schedule()`'s argument
slip.

**Read from the paper:** §12's `omega^2` values, the individual-based methodology, the sapling-bank
attribution.

**Derived:** §2's Jacobian identity and the cancellation of `J` in the two integrals; §4's closed
form for `dg/dS`.

**Not claimed:** that ≈401 is the right number in an absolute sense — it is the converged value of
the operator the transport equation specifies, verified against `develop` itself on the two models
where `develop` is correct, and consistent with report 10's independent implementation. Nor anything
about a multi-species stand, nor about `plant` under an `ExtrinsicDrivers` regime with the seasonal
stress period Stefaniak et al. simulate.

## 15. What is left

- **Interior folds across the drought envelope.** §6 is one parameter set. `#554`'s sweep
  (`mpl` in {20,30,50,70} x amplitude 0.30-0.40) has not been instrumented.
- **Schedule refinement in the new coordinate.** `SCM::refine_schedule`'s error metric is written
  against the height grid and has not been re-derived.
- **Re-blessing, if the coordinate becomes the default.** The suite passes unchanged with the flag
  off (2 353 assertions, one snapshot of `Control`'s field names updated). Turning it on moves every
  TF24 baseline, and moves FF16 and K93 by `1.2e-3` and `1.4e-4` — small, but the FF16 reference
  comparison is a bit-identity tripwire, so it would need regenerating.
- **A production change would delete the old path**, not keep the flag: `Node::growth_rate_gradient`,
  `Individual::growth_rate_given_height` and the four `node_gradient_*` `Control` fields all become
  dead. The flag exists so both arms run from one build while the question is open.

## References

de Roos, A. M. (1988). Numerical methods for structured population models: the Escalator Boxcar
Train. *Numerical Methods for Partial Differential Equations* 4(3), 173-195.

Falster, D. S., FitzJohn, R. G., Brannstrom, A., Dieckmann, U., Westoby, M. (2016). plant: A package
for modelling forest trait ecology and evolution. *Methods in Ecology and Evolution* 7, 136-146.

Stefaniak, E. Z., Tissue, D. T., Falster, D. S., Medlyn, B. E. (2026). Greater variability in
environmental stress favours trees that prioritise storage of carbohydrate reserves over growth: a
modelling analysis. EGUsphere preprint, https://doi.org/10.5194/egusphere-2026-1474. Local copy:
[`docs/reference/stefaniak-et-al-2026-storage-strategies-egusphere-2026-1474.pdf`](../reference/stefaniak-et-al-2026-storage-strategies-egusphere-2026-1474.pdf)
(CC BY 4.0).
