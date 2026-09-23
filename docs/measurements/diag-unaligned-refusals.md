# What an unaligned grid actually does: it drops 4.74% of the rain, and the error estimate reports zero

TF24 SCM, one species, `lma = 0.32`, `max_patch_lifetime = 40`, forcing
`long-drought` (the 41-year seasonal Markov-chain record of
`diag-long-drought.md`, 14 966 daily control points, 1095 mm/yr, 9.5% wet days,
three multi-year droughts), 108 introductions, `ode_tol_rel = ode_tol_abs =
1e-4`, `node_density_in_birth_date = TRUE`, optimised `-O2` build (already
current, not rebuilt), `TESTTHAT_PARALLEL = false`.
`J = sum(scm$offspring_production)`. The aligned arm is
`events(events_default(p), rainfall_pulse(time = knots, depth = 0))` at the
2931 active knots, as in `diag-long-drought.md`.

**No code under `plant/`, `odelia/` or `phylloptim/` was changed and nothing was
rebuilt.** This note was committed as `4e0859c` by another actor while it was
still being written; the work described here committed nothing and pushed
nothing. Both trees are clean at `plant 5321593a` /
`odelia be3e2cb`, and `plant/src/plant.so` was reused as found — mtime
`2026-09-22 12:52:40 UTC` at the start of this work and unchanged at the end,
with no `plant/src/*.o` newer than it. The clamp counts were read through the
already-exported `census_clamp_counts_tf24()` / `census_clamp_names_tf24()`, so
no instrumentation patch was needed. Everything below is scripts in the
scratchpad: `ur_common.R`, `ur1_driver.R`, `ur2_run.R`, `ur3_mre.R`,
`ur4_audit.R`, `ur5_tol.R`, `ur6_attr.R`, `ur7_growth.R`, `ur9_checks.R`,
`ur10_ladder.R`.

---

## The five numbers

| | |
|---|---|
| **Rain the unaligned run delivers** | `sum_rainfall = 114.566463` against the record's `120.266849` — **-4.74%**, and `J = 7.805`. |
| **Rain the aligned run delivers** | `sum_rainfall = 120.266849315` — the record's integral to **3.2e-12 relative**, and `J = 12.087`. |
| **Where the missing water goes** | **70 accepted steps of 11 319 (0.62%)** carry 100.05% of the deficit. 58 of them deliver **exactly zero** while their interval holds up to 0.345 of water, and on all 58 the Cash-Karp error term for rainfall is **exactly zero**. |
| **`CLAMP_RAINFALL`** | **0** on the unaligned run; **100** on the aligned one, and every negative the interpolant can produce anywhere in the record is **≤ 1.42e-14** — floating-point round-off at the control points, `4e-17` of the record's scale. |
| **The controlled test** | Capping `ode_step_size_max` at **5 days** on the *unaligned* grid — no events, no knots, no alignment — delivers the record to **+0.002%** and gives `J = 12.099`, **0.10% from the aligned answer**. Above 6.7 days nothing works; below it, everything does. |

## Verdict — neither candidate mechanism. It is a quadrature blind spot, and it is structural

**The interpolant does not overshoot.** `monotone_slopes` does what it says:
over 972 726 evaluation points on the 41-year record the driver never leaves
the range of the two control values bounding its span by more than 1.4e-14, and
its integral matches the control points to 3.5e-12 relative. **There is no C0
kink**, `std::max(0.0, rainfall_raw)` at `tf24_environment.h:585` is dead with
respect to the model's physics, and the comment above it, the `@details` block
of `check_driver_interpolation()` in `plant/R/drivers.R`, and
`plant/inst/include/plant/models/tf24_environment.h:562-580` all describe an
interpolant that no longer exists. That is candidate (1), refuted.

**The C1-not-C2 structure is real but is not an order barrier.** Cash-Karp's
5(4) pair, applied to a rate that is a function of `t` alone — which
`sum_rainfall`'s is, exactly (`tf24_environment.h:641`) — is a **four-node
quadrature** at `{0, 0.3, 0.6, 0.875}·h`, exact for polynomials to degree 4;
its embedded partner is a five-node rule at `{0, 0.3, 0.6, 0.875, 1}·h`, exact
to degree 3. **Their difference — the entire error estimate — is identically
zero on any cubic.** A step confined to one Hermite span therefore integrates
the forcing *exactly* and reports *exactly zero* error. There is nothing left
for a curvature jump to reduce the order of. That is candidate (2), refuted in
the form stated.

**What is actually happening is the third thing.** The same estimate is also
exactly zero when every one of the five error abscissae lands where the
interpolant is zero — which is what happens when a step grown long in a dry
spell reaches across the first rain of the next event. The widest gap between
those abscissae is **0.3h**, so a two-span bump can fall wholly inside one once
the step passes 6.7 days. **The estimator cannot distinguish "zero because my
integrand was a cubic" from "zero because I sampled nothing", and both readings
are `yerr = 0` to the last bit.** The step is accepted, the water is gone, and
because the reported error is a true zero rather than a small number, **the
rainfall term can never object, at any tolerance** — the controller's response
to a zero ratio is to multiply the step by five. Tightening `ode_tol` does
eventually recover the water on the real model, but through the other
components shortening every step, not through the estimator finding what it
missed (§7).

That is why alignment works, and the reason is exact rather than statistical. A
span is non-zero only if one of its ends is non-zero, and both ends of such a
span are active knots by construction — so **stopping at every active knot
makes every water-carrying step a single-span step**, where the rule is exact.
Measured: of the aligned run's 3444 steps that cross a control point, **not one
carries any water** (2.4e-18 in total); all 120.267 is carried by steps lying
inside one span. Of the unaligned run's loss, **100% is on steps that cross a
control point** and
2.6e-12 on steps that do not.

**Refusals are a separate phenomenon, and the brief's premise for them does not
hold.** Rejections are only weakly associated with the knots — `P(reject)` is
0.423 on a step holding an active knot against 0.305 on one that does not, a
ratio of 1.38, and the median distance from a step's start to the nearest
active knot is 0.380 days on rejected steps against 0.368 on clean ones.
Alignment cuts the rejection count from 4540 to 2603 and the rate from 28.6% to
17.6% — it removes two fifths of them and leaves the rest. **The damaging steps
are the quiet ones**: only 12.9% of the 70 water-losing steps were preceded by
any rejection, against 33.3% of steps generally. Refusals are the controller
working, not the controller failing.

---

## 1. The driver is monotone, non-negative, and conserves its integral

`monotone_slopes` (`odelia/inst/include/odelia/interpolator.hpp:404`) is a
Fritsch-Carlson limiter with a turning-point rule and flat-pair pinning, and it
behaves as written. Measured on both records of the `long-drought` fixture, at
64 sub-samples per daily span (`ur1_driver.R`):

| | `long-drought` | `long-wet` |
|---|---|---|
| evaluation points | 972 726 | 972 726 |
| minimum evaluated | **-1.42e-14** | **-5.68e-14** |
| maximum excursion above its span's upper control value | 1.42e-14 | 8.53e-14 |
| maximum excursion below its span's lower control value | 1.42e-14 | 5.68e-14 |
| supplied range | [0, 338.3] | [0, 454.7] |
| integral of the interpolant vs trapezoid of the control points | **-3.5e-12 %** | **-3.7e-12 %** |

Every one of the 26 negative readings in the whole record is **at a control
point**, and the deepest is `-1.42e-14` — `4.2e-17` of the largest supplied
value. This is the round-off of evaluating a cubic whose coefficients are of
order 338, not an undershoot.

So the floor at `tf24_environment.h:585` can fire, but only on round-off.
**`CLAMP_RAINFALL` is 0 on the unaligned run and 100 on the aligned one** —
the aligned run is the one that stops *at* the knots, which is where the
round-off lives, and 100 firings against ~73 000 environment rate evaluations
is that and nothing else. The count read back through
`census_clamp_counts_tf24(scm)` with names from `census_clamp_names_tf24()`.

### `check_driver_interpolation()` documents an interpolant that is gone

Its `@details` block and the warning text at `plant/R/drivers.R:88-96` say the
drivers are "interpolated with a cubic spline" that "evaluates *negative* at
roughly 45% of points" and "overshoots pulse peaks several-fold". On this
record it reports, correctly, `negative at 0.0% of points` and
`integral +0.00%`. **The documentation is stale; the measurement is not.** The
same text appears at `tf24_environment.h:562-580` and in
`plant/R/drivers.R:1-8`, and `odelia/inst/include/odelia/drivers.hpp:16-20`
gives the reason: the overshooting fit is the one `monotone_slopes` replaced,
and the ~42% figure is a property of *it*.

One real defect underneath the stale prose. The default `n_eval = 20001` over a
41-year daily record is a grid spacing of **0.748 days**: 66.3% of the daily
spans receive exactly one sample point, so two-thirds of the interpolant's
interiors are never looked at, and the peak it reports is **3.0% low** (328.1
against 338.3). It happened to give the right answer here because the
interpolant really is non-negative. Resolving every span eight times over on
this record needs `n_eval = 119 721`.

## 2. Cash-Karp on a rate that is a function of `t` alone

`sum_rainfall` is soil state `soil_number_of_depths`, and its rate is set to
`rainfall` and nothing else. One RK step on it is therefore a pure quadrature,
and the order conditions decide everything (`Sigma b_i c_i^(k-1)` against
`1/k`):

| degree | 5th-order rule | 4th-order rule | difference (`yerr`) |
|---|---|---|---|
| 0 | 1 | 1 | +6.9e-18 |
| 1 | 0.5 | 0.5 | +8.7e-19 |
| 2 | 1/3 | 1/3 | -6.1e-18 |
| 3 | 0.25 | 0.25 | **-1.0e-17** |
| 4 | 0.2 | 0.20068 | -6.8e-04 |

- the 5th-order increment reads the driver at `{0, 0.3, 0.6, 0.875}·h`
  (`c1·k1 + c3·k3 + c4·k4 + c6·k6`, `ode_step.hpp:234`);
- `yerr` reads it at `{0, 0.3, 0.6, 0.875, 1}·h` (`ode_step.hpp:171`; the
  `1/5` abscissa carries weight exactly zero in both);
- gaps between consecutive `yerr` abscissae: **0.3, 0.3, 0.275, 0.125** — the
  widest is `0.3h`;
- **`yerr` vanishes identically on any integrand of degree <= 3.**

Both zeros — "the integrand was a cubic" and "every abscissa read zero" — are
the same number, and the controller branches on that number alone.

Measured on the real program, this partition is exact (`ur4.rds`):

| | steps crossing >= 1 control point | water they carry | water lost there | water lost on single-span steps |
|---|---|---|---|---|
| unaligned | 6177 of 11 319 (54.6%) | 31.43 of 120.27 (26.1%) | **5.70039** | **2.6e-12** |
| aligned | 3444 of 12 225 (28.2%) | **2.4e-18** | -9.9e-19 | 4.7e-13 |

`max |yerr_rain|` on single-span steps is 1.56e-14 in both arms — the round-off
zero — against 6.47e-05 on the unaligned run's multi-span steps.

## 3. Where the 4.74% goes: 70 steps, 58 of them delivering exactly nothing

Per-step audit of the recorded program (`store_trajectory()` rows, rainfall
recomputed with the tableau above and compared against Simpson per daily span,
which is exact for the cubic) — `ur4_audit.R`, `ur6_attr.R`:

| | unaligned | aligned |
|---|---|---|
| accepted steps | 11 319 | 12 225 |
| rainfall the program delivers (recomputed) | 114.566463 | 120.266849 |
| the run's own `sum_rainfall` | **114.566463** | **120.266849** |
| the record over the same span | 120.266849 | 120.266849 |
| deficit | **-5.70039 (-4.74%)** | -4.7e-13 (-3.9e-13 %) |
| steps delivering < 50% of their own interval's water | **70 (0.62%)** | **0** |
| deficit those steps account for | **100.05%** | — |
| of them, delivering exactly zero | **58** | 0 |
| of those 58, with `yerr_rain` exactly zero | **58** | 0 |
| their step sizes (days) | median **13.97**, range [0.43, 56.07] | — |

The recomputation agrees with the run's own accumulator to **7.4e-16** relative
(unaligned) and **3.3e-15** (aligned) — machine precision — so the audit is
demonstrably reading the same quadrature the solver ran, not a model of it.

The twelve worst, with the error ratio the controller acted on (`er`, tolerable
is 1.1) and the number of active knots inside the step:

| t_beg | t_end | h (days) | water in the interval | delivered | `er` | knots inside |
|---|---|---|---|---|---|---|
| 4.2971 | 4.3433 | 16.86 | 0.345342 | **0** | 0.0181 | 5 |
| 5.1287 | 5.1619 | 12.13 | 0.313397 | **0** | 0.0186 | 3 |
| 24.8674 | 24.9133 | 16.77 | 0.303068 | **0** | 0.2700 | 3 |
| 30.1022 | 30.1470 | 16.34 | 0.253726 | **0** | 0.0224 | 6 |
| 35.8773 | 35.9231 | 16.71 | 0.235096 | **0** | 0.0160 | 4 |
| 12.0000 | 12.0290 | 10.57 | 0.214219 | **0** | 0.2025 | 3 |
| 2.6874 | 2.7630 | 27.60 | 0.194630 | **0** | 0.0176 | 9 |
| 26.9106 | 26.9624 | 18.90 | 0.178630 | **0** | 0.0440 | 9 |
| 24.8358 | 24.8582 | 8.18 | 0.156904 | **0** | 0.0091 | 3 |
| 31.7876 | 31.8422 | 19.91 | 0.155945 | **0** | 0.0737 | 3 |
| 36.6815 | 36.7241 | 15.57 | 0.141151 | **0** | 0.0219 | 3 |
| 16.6460 | 16.6808 | 12.71 | 0.138055 | **0** | 0.1304 | 6 |

Not one of these is near the rejection threshold. The largest error ratio
across all 70 is 1.071, and on every one of them the *binding* component is a
soil layer or a node state — **`sum_rainfall` binds not one of the 11 319
accepted steps in either arm.** It cannot: its own error contribution on these
steps is exactly zero.

**They are the first rain after a dry spell.** Days of consecutive dry control
points immediately before each losing step: median **18**, mean 22, max 127;
**62 of the 70 (89%) follow seven or more dry days**. The mechanism is the
controller's own growth rule running unopposed through a dry stretch — 81.9% of
accepted steps take the `rmax < 0.5` branch — until the step is long enough to
straddle the next event's onset.

## 4. Which component binds, and what the refusals are

Binding component on accepted steps, from `error_index` mapped through the node
count at that time (the state vector grows as nodes are introduced, so the raw
index means nothing without it):

| | all steps | steps accepted after >= 1 rejection | steps with no rejection before them |
|---|---|---|---|
| soil layer 5 | 26.8% | **6.3%** | **37.1%** |
| soil layer 1 | 24.4% | **44.5%** | **14.3%** |
| soil layer 3 | 13.5% | 9.6% | 15.4% |
| soil layer 2 | 12.7% | 14.0% | 12.1% |
| soil layer 4 | 8.4% | 3.6% | 10.8% |
| node states | 14.2% | 22.1% | 10.3% |
| `sum_rainfall` | **0%** | **0%** | **0%** |
| environment block, total | 85.8% | 77.9% | 89.7% |

**It is not the same component.** On a step nothing objected to, the deepest
soil layer binds (37.1%); on a step that had to be retried, **the top layer
binds (44.5%)** — the one rainfall enters, whose rate carries `infiltration =
rainfall * max(0, excess)`. The environment share, 85.8%, reproduces
`diag-error-norm.md`'s 69-84%.

Rejections were located by replaying the controller's own suggestion rule over
the recorded `(h, error_ratio)` pairs and asking which accepted steps came in
under the size it would have proposed. That names 3770 steps against a counted
4540 rejections, the difference being steps rejected more than once, which this
cannot separate. It gives the *where*, not the count; the counts below are
`ode_step_attempts`'.

| | unaligned | aligned |
|---|---|---|
| attempts | 15 859 | 14 828 |
| accepted | 11 319 | 12 225 |
| accuracy rejections | 3471 | 2384 |
| domain throws | **1069** | **219** |
| refused by `ode_state_valid` | 0 | 0 |
| rejections / attempts | **28.6%** | **17.6%** |
| steps carrying >= 1 rejection (reconstructed) | 33.3% | 20.0% |

And the association with the knots, which is the question the brief asks:

| | unaligned |
|---|---|
| `P(reject)` when an active knot lies inside the step | 0.423 |
| `P(reject)` when none does | 0.305 |
| ratio | **1.38** |
| share of rejections on knot-holding steps | 30.0% |
| share of steps that hold a knot | 23.6% |
| median days from step start to nearest active knot, rejected | 0.380 |
| median days from step start to nearest active knot, clean | 0.368 |

**Refusals are close to uniformly distributed over the record.** Two further
cuts say the same thing. `P(reject)` is 0.358 on a step holding water against
0.292 on a dry one — and the contrast is *sharper after alignment* (0.268
against 0.089), because alignment is what stops the wet steps being skipped
past. And it is 0.331 after a step that grew against 0.343 after one that held,
so the x5 growth rule is not the refusal generator either.

## 5. The isolated reproduction

`sum_rainfall`'s rate depends on nothing but `t`, so the mechanism can be run
with no plants and no soil: odelia's controller and tableau, transcribed into
R, integrating `y' = rainfall(t)` over the same 40 years with plant's own
`control()` values (`ode_step_size_max = 5`, `ode_step_size_min = 1e-6`,
`a_y = 1`, `a_dydt = 0`) — `ur3_mre.R`:

| `ode_tol` | unaligned integral | error | steps | rejections | aligned integral | error | steps | rejections |
|---|---|---|---|---|---|---|---|---|
| 1e-2 | 4.8012 | **-96.0%** | 38 | 26 | 120.26685 | +4.1e-12 % | 3939 | **0** |
| 1e-3 | 5.3087 | **-95.6%** | 75 | 65 | 120.26685 | +4.1e-12 % | 3939 | **0** |
| 1e-4 | 3.4375 | **-97.1%** | 83 | 72 | 120.26685 | +4.1e-12 % | 3939 | **0** |
| 1e-5 | 11.9351 | **-90.1%** | 308 | 338 | 120.26685 | +4.1e-12 % | 3939 | **0** |
| 1e-6 | 6.0285 | **-95.0%** | 239 | 272 | 120.26685 | +4.1e-12 % | 3939 | **0** |
| 1e-7 | 7.8691 | **-93.5%** | 454 | 602 | 120.26685 | +4.1e-12 % | 3939 | **0** |
| 1e-8 | 1.7693 | **-98.5%** | 135 | 167 | 120.26685 | +4.1e-12 % | 3939 | **0** |

**Seven decades of tolerance and the error does not move, and is not monotone.**
Aligned, the same integrator is exact to 4e-12 at every tolerance and rejects
nothing at all, because on a single cubic span the error estimate is a true
zero. On the dropped steps the reported ratio is literally `0`, which is the
controller's cue to multiply the step by five — the step size runs to
`step_size_max` and stays there. Isolated, 28.9% of steps exceed 6.7 days at
`ode_tol = 1e-4`; in the real system the other ~870 state components hold it
down, which is why the real deficit is 4.74% rather than 97%.

This is the same shape `diag-knot-alignment.md` measured on `J` — "there is no
order to report, in either arm" — arriving here with its cause attached.

## 6. The whole water budget is short, not just the diagnostic

`sum_rainfall` is an accumulator, but `infiltration = rainfall * max(0, excess)`
reads the driver at the *same* abscissae, so a step that samples no rain also
gives soil layer 0 no water. The water is physically absent, not merely
unrecorded. Cumulative fluxes at `t = 40`:

| | unaligned | aligned | difference |
|---|---|---|---|
| `sum_rainfall` | 114.566 | 120.267 | **-4.74%** |
| `sum_infiltration` | 70.930 | 74.954 | -5.37% |
| `sum_drainage` | 60.599 | 63.645 | -4.79% |
| `sum_uptake` | 10.207 | 11.187 | **-8.76%** |
| `sum_pulse_runoff` | 0 | 0 | — |
| `J` | 7.805 | 12.087 | **-35.4%** |

Uptake falls by nearly twice the rainfall deficit, which is what the timing
predicts: the water that goes missing is the first rain after a dry spell (§3),
which is the water a water-limited stand is most sensitive to.

**The operating-point census does not follow, and that is a correction.**
`hydraulic-shutdown` is 0.379% on the unaligned run against 0.025% aligned,
with domain throws 1069 against 219 — which is what `diag-knot-alignment.md`
measured and read as "the branch the two trajectories disagree about". But §7's
5-day step cap has the **highest** shutdown share of any run here, **0.424%**,
and gets `J` right to 0.10%; the 2-day cap has 0.212% and is right to 0.30%.
**Shutdown share does not predict `J`.** It is a second, independent
consequence of where the steps land, not the channel the error travels down.
The channel is the water.

## 7. Tolerance does not find it; the step length does

`ode_tol` swept over five decades at `lma = 0.32`, lifetime 40, both arms, no
step cap (`ur5_tol.R`). `J` is against the aligned arm's 12.08.

| `ode_tol` | arm | `J` | steps | rain delivered | vs the record | rejections | throws |
|---|---|---|---|---|---|---|---|
| 1e-2 | unaligned | 3.699 | 6 900 | 104.605 | **-13.02%** | 37.6% | 1835 |
| 1e-3 | unaligned | 5.249 | 8 522 | 108.766 | **-9.56%** | 31.6% | 1433 |
| 1e-4 | unaligned | 7.805 | 11 320 | 114.566 | **-4.74%** | 28.6% | 1069 |
| 1e-5 | unaligned | 9.378 | 15 961 | 116.927 | **-2.78%** | 26.9% | 775 |
| 1e-6 | unaligned | 10.203 | 23 656 | 119.139 | **-0.94%** | 26.1% | 473 |
| 1e-2 | aligned | **12.115** | 8 683 | 120.2668493 | **+7.8e-12** | 24.5% | 916 |
| 1e-3 | aligned | **12.053** | 9 931 | 120.2668493 | +1.2e-11 | 19.9% | 580 |
| 1e-4 | aligned | **12.087** | 12 226 | 120.2668493 | +3.2e-12 | 17.6% | 219 |
| 1e-5 | aligned | **12.078** | 16 391 | 120.2668493 | +2.9e-12 | 17.2% | 31 |
| 1e-6 | aligned | **12.079** | 23 116 | 120.2668493 | +2.1e-12 | 16.9% | 5 |

**The aligned arm delivers the record exactly at every tolerance** — to 2e-12
and better across four decades, because exactness on a single cubic span does
not depend on `h` — and `J` holds inside 0.3% of 12.08 the whole way, already
right at `ode_tol = 1e-2` with 8683 steps. That is `diag-knot-alignment.md`'s
"already at its floor at 1e-2" with the reason attached.

**The unaligned arm converges, but only by shortening every step.** Nothing in
the estimator found the missing water: the rainfall term reported zero on every
one of those steps at every tolerance. What tightening `ode_tol` does is make
the *other* 860-odd components demand shorter steps everywhere, which leaves
fewer of them long enough to straddle an event. At `ode_tol = 1e-6` the
unaligned run takes **23 656 steps, nearly twice the aligned run's at 1e-4, and is
still 0.94% short of the water and 15.6% low on `J`**, while the aligned run at
1e-2 takes 8683 and is right. That is the whole economics of the thing: more
steps in the wrong places lose to fewer steps in the right ones.

### The controlled test: cap the step, align nothing

The widest gap between the five error abscissae is `0.3h`, so a bump `w` wide
is *guaranteed* to be sampled once `h < w/0.3`. A single wet day between two
dry ones is a bump two daily spans wide, which puts the threshold at **6.67
days**. Capping `ode_step_size_max` on the *unaligned* run, at the shipped
`ode_tol = 1e-4`, with `empty_events()` and no knots anywhere in it
(`ur10_ladder.R`):

| `ode_step_size_max` | `J` | steps | rain delivered | vs the record | rejections | throws | shutdown |
|---|---|---|---|---|---|---|---|
| none (the shipped 5 yr) | 7.805 | 11 320 | 114.566 | **-4.74%** | 28.6% | 1069 | 0.379% |
| 30 days | 7.349 | 11 205 | 113.201 | **-5.88%** | 28.7% | 1037 | 0.382% |
| 10 days | 8.285 | 11 685 | 117.503 | **-2.30%** | 27.7% | 998 | 0.397% |
| **5 days** | **12.099** | 12 427 | 120.2692 | **+0.0020%** | 25.6% | 685 | 0.424% |
| **2 days** | **12.051** | 14 710 | 120.2624 | **-0.0037%** | 18.3% | 143 | 0.212% |
| *aligned, no cap, for comparison* | *12.087* | *12 226* | *120.2668493* | *+3.2e-12* | *17.6%* | *219* | *0.025%* |

**The threshold lands where the tableau says it should, and it is sharp.**
Above 6.67 days nothing improves: a 30-day cap is *worse* than no cap at all
(-5.88% against -4.74%), which is what "a discrete event flipping" means — a
different cap is a different draw from the same distribution, not a better one.
At 10 days the widest abscissa gap is 3 days, still wide enough to hide a
two-day bump, and 2.30% of the water is still lost. At **5 days the gap is 1.5
days, nothing two days wide can fall in it**, the run delivers the record to
**0.002%**, and `J` comes out at **12.099 — 0.10% from the aligned answer, and
inside the aligned arm's own 0.5% spread across tolerances** — with no event, no
stop time and no alignment in it. At 2 days, 120.2624 and `J = 12.051`.

That is the experiment the causal claim needed, and it settles it: **restore
the water by any means and `J` comes back.** Landing exactly on the breakpoints
buys the last three decimal places of the quadrature (3e-12 against 0.002%) and
a much lower rejection rate (17.6% against 25.6%), not the answer. It is a
controlled experiment and not a recommendation — a global cap is paid for on
every dry stretch in the record, where there is nothing to resolve.

**The two track each other all the way to zero, but not in proportion.** Over
the unaligned tolerance ladder the water deficit and the error in `J` fall
together, monotonically — 13.02% / -69.4%, 9.56% / -56.6%, 4.74% / -35.4%,
2.78% / -22.4%, 0.94% / -15.6% — and the 5-day cap carries the pair to 0.002% /
+0.10%. But a 0.94% deficit still costs 15.6% of `J`, and two runs with similar
deficits disagree: the 10-day cap is 2.30% short and 31.4% low, the
`ode_tol = 1e-5` run is 2.78% short and 22.4% low, and the 30-day cap is 5.88%
short and 39.2% low against the uncapped run's 4.74% and 35.4%. **The mass is the channel;
*which* events go missing sets the size.** That is what the timing in §3
predicts — the water at risk is the first rain after a dry spell.

The `rainfall` clamp count across the same ladder is **0 on every unaligned run
and 100-112 on every aligned one**, unchanged by tolerance — which is what a
round-off counter that fires only when a step lands exactly on a knot looks
like.

## 8. Is the alignment requirement self-inflicted? Partly — and the alternative is a different model

The reading in the brief is sound on the numerics and wrong on the cost.

**Sound.** If each wet day's depth were delivered as a `rainfall_pulse` and the
continuous `rainfall` driver set to zero, the failure in §2-3 would be gone by
construction rather than by tuning. `sum_rainfall`'s rate would be identically
zero, so there would be no forcing quadrature to get wrong; water would enter
as an exact state increment applied between legs (`add_water_pulse_to_layer`,
`tf24_environment.h:819`); and every input would be a step boundary because
`SCM::run_next` takes one leg per schedule entry. It is also *cheaper in stops*
than alignment: the record has **1387 wet days in
`(0, 40)` against 2931 active knots**, and 814 rain events.

**But it is a different model, not a different discretisation.** Three
differences, all of them in the pulse path itself and none of them
discretisation-sized:

1. **A pulse bypasses the saturation-excess infiltration term.** The continuous
   path applies `rainfall * max(0, 1 - a_infil*(theta_0/theta_sat)^b_infil)`;
   the pulse path applies `min(depth, capacity)` against the layer's free
   porosity, and the header says so and calls it "the first open question on
   this action".
2. **A pulse is instantaneous.** The top layer's peak `theta` is higher than
   under a day-long ramp of the same depth, so more of the water meets the
   capacity cap and is shed to `sum_pulse_runoff`, and the post-onset drainage
   transient is faster. The handover's own scaling —
   `|lambda_1| ~ q*kappa_1^(1/q)*s^(1-1/q)` — is exactly the quantity a delta
   pushes hardest.
3. **A pulse has no error estimate and no rejection behind it**; the capacity
   cap is the whole of its domain protection, as the header states.

So the water budget, the runoff partition and the top-layer transient would all
move, and whether they move toward the intended physics is a modelling question
this measurement cannot answer.

**And it would not buy the refusals back.** The soil block binds 85.8% of
accepted steps and 77.9% of the steps that followed a rejection, the rejections
are close to uniform over the record (§4), and the aligned arm still rejects
17.6% of attempts with a forcing that is integrated exactly. Replacing a
one-day ramp with a discontinuity makes the first step after each event meet a
stiffer top layer than it does now, so the refusal count is at least as likely
to rise.

The existing recipe — `rainfall_pulse(time = knots, depth = 0)` as a pure
stop-forcer while the water still arrives through the interpolant — is not a
workaround standing in for this. Given §2 it is the *right* shape: the water
has to come through the interpolant for the quadrature to be exact on a span,
and the event is doing nothing but making the span a leg.

## 9. What the error norm cannot do about it

Worth stating because the handover names `ode_a_dydt` as "the knob that most
directly changes which component sets the step size". It cannot reach this.
`errlevel = tol_rel*(a_y*|y| + a_dydt*|h*dydt|) + tol_abs` is the *denominator*
of the test, and on a blind step the numerator `|yerr_i|` is exactly zero for
both `sum_rainfall` and — through `infiltration` — for the water that soil
layer 0 did not receive. **No choice of `a_y`, `a_dydt`, `tol_rel` or `tol_abs`
divides a zero into something a threshold can see.** `ode_step_size_min` is on
the wrong side. Of the controls that ship, only `ode_step_size_max` and forced
stop times touch the quantity that matters, which is the step's length measured
against the width of the feature it spans.

That also disposes of a reading the earlier notes left open.
`diag-knot-alignment.md` found "no order to report, in either arm" and named
the failure "a discrete event flipping, not a truncation error growing". Both
halves are right and this says why: **the discrete event is whether a given
event's rain falls in an abscissa gap**, and that is a property of where the
step boundaries happen to land, not of `h`. It also explains the one quantity
that note left unexplained — why stops a quarter or half a day off the knots
hold the answer to 2.6-2.8% while stops on the knots hold it to 0.21%. Off the
knots, every step is short enough that nothing is skipped, but a step still
crosses control points — and the exactness in §2 needs the integrand to be a
*single* polynomial over the step, which a piecewise cubic is not. On the knots
it is one, and the rule is exact. The size of that residual is not derived
here; only which of the two arms carries one.

---

## What is measured and what is inferred

**Measured.** Every number in §1-§7 and §9, from the runs and scripts named.
The interpolant's range and integral; the clamp counts; both runs' `J`, step
counts, attempt census and cumulative fluxes; the per-step rainfall audit and
its agreement with the run's own accumulator to machine precision; the
binding-component tables; the isolated quadrature ladder; the order conditions
of the tableau. §8's stop counts (1387 wet days, 2931 active knots, 814 events)
are measured on the record.

**Measured — and this is what carries the causal claim.** That the water deficit is
what makes `J` wrong, rather than a correlate of it. §7's step cap restores the
record to 0.002% on a grid with no alignment in it at all and brings `J` back
to within 0.10% of the aligned answer, so the knots are not carrying anything
the water is not.

**Inferred.** That the residual after the water is restored is negligible: the
5-day cap lands 0.10% above the aligned answer, inside the aligned arm's own
0.5% spread across tolerances, so nothing separates them here. A tighter
statement would need the two grids compared at one tolerance apiece with a
converged reference, which this does not have.

**Inferred.** §8's account of what pulse forcing would cost. It is read off
`add_water_pulse_to_layer` and the header's own notes, not run.

## What could not be settled

- **The binding component on the rejected attempt itself.** `OdeControl::error_index`
  and `error_ratio` are overwritten by the retry, and nothing records them at the
  moment of rejection — `step_record` carries only the attempt that was accepted.
  §4 therefore reports the component that bound the *retry*, which is one step
  removed from the one that forced the shrink. Settling it is a small addition to
  the retry loop in `ode_solver_internal.hpp` — `(time, step_size, error_index,
  error_ratio, outcome)` per attempt — deliberately not made here, since this was
  to be an investigation and not a change.
- **One record, one trait, one horizon.** `long-drought` at `lma = 0.32`,
  lifetime 40. `diag-knot-alignment.md`'s `mixed-ordinary` at lifetime 5 has the
  same geometry (0.24 active knots per step against 0.26 here) and the same
  shape of failure, so the mechanism is unlikely to be fixture-specific, but the
  4.74% is one draw.
- **Why a given event costs what it costs.** The mass deficit sets the sign and
  the order of magnitude of the `J` error but not its size: 2.30% short costs
  31.4% of `J` under a 10-day cap and 2.78% short costs 22.4% at
  `ode_tol = 1e-5`. Which events are skipped matters more than how much of the
  record's total they held, and nothing here attributes the error event by
  event.
- **The other drivers.** The blindness is a property of the quadrature, so any
  driver with a feature narrower than `0.3h` can be skipped the same way. Only
  `rainfall` has an accumulator to measure it on, and only `rainfall` enters a
  rate additively enough that missing it is pure mass loss; PPFD, VPD, CO2 and
  leaf temperature reach the rates through the leaf model and are constants on
  this fixture. Untested.
- **Whether a genuinely arid site behaves the same.** Unchanged from
  `diag-long-drought.md`, and the mechanism here suggests it would be worse: a
  drier record means longer dry spells, hence longer grown steps, hence more of
  the record's water in a skippable position.

## Files

* `ur_common.R` — the fixture, carried over from `ld_common.R`
* `ur1_driver.R` — the interpolant's range and integral (§1)
* `ur2_run.R` — the two lifetime-40 runs, clamp counts, fluxes, trajectory (§1, §3, §6)
* `ur3_mre.R` — the isolated adaptive quadrature (§5)
* `ur4_audit.R` — the per-step rainfall audit and the rejection reconstruction (§3, §4)
* `ur6_attr.R` — binding-component attribution through the growing state vector (§4)
* `ur7_growth.R` — the refusal cuts and the dry-spell context of the losing steps (§3, §4)
* `ur5_tol.R` — the tolerance ladder on the real model (§7)
* `ur9_checks.R` — round-off negatives and `check_driver_interpolation`'s resolution (§1)
* `ur10_ladder.R` / `ur10_run.sh` — the step-cap ladder, one run per process
  into `ladder.csv` (§7)
